"""Run production Linux paired backup and restore on an owned Debian fixture."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import secrets
import shutil
import socket
import subprocess
import tempfile
import time
import uuid

from deploy import APP, CONFIG, DATABASE, OWNER, PORT, UNIT, query, run, wait_ready

SCHEMAS = {"information_schema", "mysql", "performance_schema", "sys", DATABASE, "orchids_activity08_import"}


def private_file(path, content):
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, "w") as stream:
        stream.write(content)


def digest(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def inventory(root):
    return {p.relative_to(root).as_posix(): digest(p) for p in root.rglob("*") if p.is_file()}


def target_query(path, sql):
    return run("mariadb", "--no-defaults", "--protocol=SOCKET", f"--socket={path}",
               "--batch", "--skip-column-names", input=sql, capture_output=True).stdout.strip()


def main(source, repeat_target=False):
    expected_host = "orchidapp-debian13" if repeat_target else "orchidapp-debian12"
    if os.geteuid() != 0 or socket.gethostname() != expected_host:
        raise RuntimeError("Run only on the designated disposable Debian guest as root.")
    app, config, database, owner, unit, port = (
        Path("/opt/orchidapp-activity11"), Path("/etc/orchidapp-activity11"),
        "orchids_activity11", "orchid11", "orchidapp-activity11.service", 55311
    ) if repeat_target else (APP, CONFIG, DATABASE, OWNER, UNIT, PORT)
    setup_user = f"{owner}_setup"
    other_services = [("orchidapp-activity10.service", "orchid10", 55310)] if repeat_target else []
    services = [(unit, owner, port), *other_services]
    schemas = {"information_schema", "mysql", "performance_schema", "sys", "orchids_activity10", database} if repeat_target else SCHEMAS
    if set(query("SHOW DATABASES;").splitlines()) - schemas:
        raise RuntimeError("Unexpected database on the source server; refusing a server-wide read lock.")
    if repeat_target and not query("SELECT VERSION();").startswith("11.8.9-MariaDB"):
        raise RuntimeError("Expected the Activity 11 MariaDB 11.8.9 source.")
    if query(f"SELECT COUNT(*) FROM {database}.plantphoto WHERE isActive=1;") != "2":
        raise RuntimeError("Expected the two active browser-witness photos before backup.")
    for service, service_owner, _ in services:
        state = run("systemctl", "show", service, "--property=User,ActiveState",
                    capture_output=True).stdout.splitlines()
        if f"User={service_owner}" not in state or "ActiveState=active" not in state:
            raise RuntimeError(f"Expected the verified running test service {service}.")
    writer_units = [service for service, _, _ in services]
    tools = source / "infrastructure/backups"
    if not all((tools / name).is_file() for name in ("backup_orchids.sh", "restore_orchids.sh", "orchid_backup.py")):
        raise RuntimeError("Reviewed paired-backup tools are missing.")

    os.umask(0o077)
    root = Path(tempfile.mkdtemp(prefix=f"orchidapp-{owner}-paired-" if repeat_target else "orchidapp-activity08-paired-", dir="/var/lib"))
    root.chmod(0o711)  # The target daemon can traverse to its own private directory.
    private = root / "private"
    private.mkdir(mode=0o700)
    target = root / "database"
    target.mkdir(mode=0o700)
    shutil.chown(target, user="mysql", group="mysql")
    target_socket = target / "target.sock"
    source_defaults = private / "source.cnf"
    target_defaults = private / "target.cnf"
    source_socket = query("SELECT @@socket;")
    if not source_socket.startswith("/run/mysqld/") and not source_socket.startswith("/var/run/mysqld/"):
        raise RuntimeError("Unexpected source socket.")
    for defaults, database_socket in ((source_defaults, source_socket), (target_defaults, target_socket)):
        private_file(defaults, f"[client]\nprotocol=socket\nsocket={database_socket}\nuser=root\n")

    encrypted = private / "encrypted"
    encrypted.mkdir()
    key = run("rclone", "obscure", "-", input=secrets.token_hex(24) + "\n", capture_output=True).stdout.strip()
    crypt = private / "rclone.conf"
    private_file(crypt, f"[fixturecrypt]\ntype=crypt\nremote={encrypted}\npassword={key}\n")
    run("rclone", "--config", str(crypt), "mkdir", "fixturecrypt:paired")
    collection = str(uuid.uuid4())
    common = dict(collection_id=collection, database=database, writer_units=writer_units, timeout_seconds=90)
    source_config = private / "source.json"
    target_config = private / "target.json"
    private_file(source_config, json.dumps(dict(common, client_defaults_file=str(source_defaults),
        uploads_root=str(app / "uploads"), configuration_root=str(config), rclone_config=str(crypt),
        remote="fixturecrypt:paired", backup_root=str(private / "archives"), log_file=str(private / "backup.log"))))
    private_file(target_config, json.dumps(dict(common, client_defaults_file=str(target_defaults),
        backup_root=str(private / "scratch"), log_file=str(private / "restore.log"))))

    run("mariadb-install-db", "--no-defaults", "--user=mysql", "--auth-root-authentication-method=socket",
        "--skip-test-db", f"--datadir={target}", stdout=subprocess.DEVNULL)
    process = None
    try:
        run("systemctl", "stop", *writer_units)
        readings = (f"SELECT plantId,plantName FROM {database}.plant ORDER BY plantId;"
                    f"SELECT plantId,fileName,thumbnailFileName FROM {database}.plantphoto ORDER BY plantPhotoId;")
        records = query(readings)
        media = inventory(app / "uploads")
        settings = inventory(config)
        run("bash", str(tools / "backup_orchids.sh"), "--config", str(source_config), "--writers-stopped")
        archive, = (private / "archives").glob("orchidpair-*.tar.gz")
        with (private / "target-server.log").open("x") as log:
            process = subprocess.Popen(["/usr/sbin/mariadbd", "--no-defaults", "--user=mysql", f"--datadir={target}",
                                        f"--socket={target_socket}", f"--pid-file={target}/target.pid",
                                        "--skip-networking", "--event-scheduler=OFF", "--skip-log-bin"],
                                       stdout=log, stderr=subprocess.STDOUT)
        for _ in range(30):
            if process.poll() is not None:
                raise RuntimeError("Owned restore server failed to start.")
            try:
                if target_query(target_socket, "SELECT @@skip_networking, @@event_scheduler;") == "1\tOFF":
                    break
            except subprocess.CalledProcessError:
                pass
            time.sleep(1)
        else:
            raise RuntimeError("Owned restore server failed isolation or readiness checks.")
        target_version = target_query(target_socket, "SELECT VERSION();")
        if repeat_target and not target_version.startswith("11.8.9-MariaDB"):
            raise RuntimeError("Expected MariaDB 11.8.9 on the isolated restore target.")
        # The schema loader created views and routines with this definer.
        # Recreate its identity without restoring source credentials or permitting login.
        target_query(target_socket,
                     f"CREATE database {database} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
                     f"CREATE USER '{setup_user}'@'127.0.0.1' ACCOUNT LOCK;"
                     f"GRANT ALL PRIVILEGES ON {database}.* TO '{setup_user}'@'127.0.0.1';")
        destination = private / "restored"
        run("bash", str(tools / "restore_orchids.sh"), "--config", str(target_config), "--archive", str(archive),
            "--destination", str(destination), "--confirm-isolated", "--confirm-database", database)
        if (target_query(target_socket, readings) != records or inventory(destination / "uploads") != media
                or inventory(destination / "configuration") != settings):
            raise RuntimeError("Restored record, media or configuration evidence differs.")
        if not (destination / "RESTORED-VERIFY-APPLICATION.json").is_file():
            raise RuntimeError("Expected staged recovery marker is missing.")
        print(json.dumps({"fixtureRoot": str(root), "targetVersion": target_version, "archive": archive.name, "sha256": digest(archive), "mediaFiles": len(media),
                          "configurationFiles": len(settings), "recordAndFileWitnessesMatch": True,
                          "restoreServer": "separate socket-only MariaDB process", "restoredApplicationStarted": False},
                         indent=2))
    finally:
        if process and process.poll() is None:
            process.terminate()
            process.wait(timeout=30)
        run("systemctl", "start", *writer_units)
        for service, _, service_port in services:
            wait_ready(service_port, service)
        print("Source service restarted and healthy.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--repeat-target", action="store_true", help="Use the Activity 11 Debian 13 fixture.")
    args = parser.parse_args()
    main(args.source.resolve(strict=True), repeat_target=args.repeat_target)
