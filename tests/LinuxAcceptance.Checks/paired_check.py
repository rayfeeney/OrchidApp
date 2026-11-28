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

from deploy import APP, CONFIG, DATABASE, OWNER, UNIT, query, run, wait_ready

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


def main(source):
    if os.geteuid() != 0 or socket.gethostname() != "orchidapp-debian12":
        raise RuntimeError("Run only on the designated disposable Debian guest as root.")
    if set(query("SHOW DATABASES;").splitlines()) - SCHEMAS:
        raise RuntimeError("Unexpected database on the source server; refusing a server-wide read lock.")
    if query(f"SELECT COUNT(*) FROM {DATABASE}.plantphoto WHERE isActive=1;") != "2":
        raise RuntimeError("Expected the two active browser-witness photos before backup.")
    state = run("systemctl", "show", UNIT, "--property=User,ActiveState", capture_output=True).stdout.splitlines()
    if f"User={OWNER}" not in state or "ActiveState=active" not in state:
        raise RuntimeError("Expected the running Activity 08 service.")
    tools = source / "infrastructure/backups"
    if not all((tools / name).is_file() for name in ("backup_orchids.sh", "restore_orchids.sh", "orchid_backup.py")):
        raise RuntimeError("Reviewed paired-backup tools are missing.")

    os.umask(0o077)
    root = Path(tempfile.mkdtemp(prefix="orchidapp-activity08-paired-", dir="/var/lib"))
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
    common = dict(collection_id=collection, database=DATABASE, writer_units=[UNIT], timeout_seconds=90)
    source_config = private / "source.json"
    target_config = private / "target.json"
    private_file(source_config, json.dumps(dict(common, client_defaults_file=str(source_defaults),
        uploads_root=str(APP / "uploads"), configuration_root=str(CONFIG), rclone_config=str(crypt),
        remote="fixturecrypt:paired", backup_root=str(private / "archives"), log_file=str(private / "backup.log"))))
    private_file(target_config, json.dumps(dict(common, client_defaults_file=str(target_defaults),
        backup_root=str(private / "scratch"), log_file=str(private / "restore.log"))))

    run("mariadb-install-db", "--no-defaults", "--user=mysql", "--auth-root-authentication-method=socket",
        "--skip-test-db", f"--datadir={target}", stdout=subprocess.DEVNULL)
    process = None
    try:
        run("systemctl", "stop", UNIT)
        readings = (f"SELECT plantId,plantName FROM {DATABASE}.plant ORDER BY plantId;"
                    f"SELECT plantId,fileName,thumbnailFileName FROM {DATABASE}.plantphoto ORDER BY plantPhotoId;")
        records = query(readings)
        media = inventory(APP / "uploads")
        settings = inventory(CONFIG)
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
        # The schema loader created views and routines with this definer.
        # Recreate its identity without restoring source credentials or permitting login.
        target_query(target_socket,
                     f"CREATE DATABASE {DATABASE} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
                     "CREATE USER 'orchid08_setup'@'127.0.0.1' ACCOUNT LOCK;"
                     f"GRANT ALL PRIVILEGES ON {DATABASE}.* TO 'orchid08_setup'@'127.0.0.1';")
        destination = private / "restored"
        run("bash", str(tools / "restore_orchids.sh"), "--config", str(target_config), "--archive", str(archive),
            "--destination", str(destination), "--confirm-isolated", "--confirm-database", DATABASE)
        if (target_query(target_socket, readings) != records or inventory(destination / "uploads") != media
                or inventory(destination / "configuration") != settings):
            raise RuntimeError("Restored record, media or configuration evidence differs.")
        if not (destination / "RESTORED-VERIFY-APPLICATION.json").is_file():
            raise RuntimeError("Expected staged recovery marker is missing.")
        print(json.dumps({"archive": archive.name, "sha256": digest(archive), "mediaFiles": len(media),
                          "configurationFiles": len(settings), "recordAndFileWitnessesMatch": True,
                          "restoreServer": "separate socket-only MariaDB process", "restoredApplicationStarted": False},
                         indent=2))
    finally:
        if process and process.poll() is None:
            process.terminate()
            process.wait(timeout=30)
        run("systemctl", "start", UNIT)
        wait_ready()
        print("Source service restarted and healthy.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    main(parser.parse_args().source.resolve(strict=True))
