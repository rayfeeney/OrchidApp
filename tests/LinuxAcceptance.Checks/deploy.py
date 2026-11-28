"""Provision and exercise one disposable systemd installation."""
import argparse
import json
import os
from pathlib import Path
import secrets
import shutil
import socket
import subprocess
import time
import urllib.error
import urllib.request

from preflight import preflight


APP = Path("/opt/orchidapp-activity08")
CONFIG = Path("/etc/orchidapp-activity08")
UNIT = "orchidapp-activity08.service"
UNIT_PATH = Path("/etc/systemd/system") / UNIT
DATABASE = "orchids_activity08"
OWNER = "orchid08"
PORT = 55308


def run(*args, **kwargs):
    return subprocess.run(args, check=True, text=True, timeout=180, **kwargs)


def query(sql):
    return run("mariadb", "--no-defaults", "--protocol=SOCKET", "--batch",
               "--skip-column-names", input=sql, capture_output=True).stdout.strip()


def wait_ready(port=PORT, unit=UNIT):
    url = f"http://127.0.0.1:{port}/health/ready"
    for _ in range(60):
        try:
            with urllib.request.urlopen(url, timeout=4) as stream:
                body = json.load(stream)
            if body.get("ready") and body.get("checks") and all(body["checks"].values()):
                return body
        except (urllib.error.URLError, TimeoutError):
            pass
        time.sleep(1)
    raise RuntimeError(f"Fixture did not become ready. Inspect journalctl -u {unit}.")


def service_state(unit=UNIT):
    return run("systemctl", "show", unit, "--property=ActiveState,User,MainPID",
               capture_output=True).stdout.strip()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--publish", type=Path, required=True)
    profile = parser.add_mutually_exclusive_group()
    profile.add_argument("--target", action="store_true", help="Deploy to the clean Debian 13 target.")
    profile.add_argument("--repeat-target", action="store_true", help="Deploy independently beside the Activity 10 target fixture.")
    args = parser.parse_args()
    if os.geteuid() != 0:
        parser.error("Run as root on the designated disposable guest.")
    is_target = args.target or args.repeat_target
    environment_report = preflight(target=is_target, repeat_target=args.repeat_target)
    activity = "11" if args.repeat_target else ("10" if args.target else "08")
    app, config, unit, database, owner, port = (
        Path(f"/opt/orchidapp-activity{activity}"), Path(f"/etc/orchidapp-activity{activity}"),
        f"orchidapp-activity{activity}.service", f"orchids_activity{activity}",
        f"orchid{activity}", 55300 + int(activity)
    ) if is_target else (APP, CONFIG, UNIT, DATABASE, OWNER, PORT)
    unit_path = UNIT_PATH.with_name(unit)
    setup_user = f"{owner}_setup"
    source, published = args.source.resolve(strict=True), args.publish.resolve(strict=True)
    rebuild = source / "database/scripts/rebuild.ps1"
    if not rebuild.is_file() or not (published / "OrchidApp.Web.dll").is_file():
        parser.error("Supply the reviewed source and completed x64 publish directories.")
    dotnet, pwsh = shutil.which("dotnet"), shutil.which("pwsh")
    if not dotnet or not pwsh:
        parser.error(".NET 8 and PowerShell are required.")
    for path in (app, config, unit_path):
        if os.path.lexists(path):
            raise RuntimeError(f"Refusing to overwrite fixture state at {path}.")
    with socket.socket() as listener:
        listener.bind(("127.0.0.1", port))
    if subprocess.run(("getent", "passwd", owner), stdout=subprocess.DEVNULL).returncode != 2:
        raise RuntimeError("The intended fixture service account is already present.")
    if query(f"SELECT COUNT(*) FROM mysql.user WHERE User IN ('{owner}','{setup_user}');") != "0":
        raise RuntimeError("The intended fixture database accounts are already present.")

    setup_secret, runtime_secret = secrets.token_hex(24), secrets.token_hex(24)
    query(f"CREATE USER '{setup_user}'@'127.0.0.1' IDENTIFIED BY '{setup_secret}';"
          f"GRANT ALL PRIVILEGES ON {database}.* TO '{setup_user}'@'127.0.0.1';")
    setup_env = dict(os.environ, MARIADB_HOST="127.0.0.1", MARIADB_PORT="3306",
                     MARIADB_DATABASE=database, MARIADB_USER=setup_user,
                     MARIADB_PASSWORD=setup_secret, MARIADB_CHARSET="utf8mb4",
                     MARIADB_COLLATION="utf8mb4_unicode_ci")
    run(pwsh, "-NoProfile", "-File", str(rebuild), "-ConfirmDatabase", database, env=setup_env)

    query(f"ALTER USER '{setup_user}'@'127.0.0.1' ACCOUNT LOCK;"
          f"CREATE USER '{owner}'@'127.0.0.1' IDENTIFIED BY '{runtime_secret}';"
          f"GRANT SELECT, INSERT, UPDATE, DELETE, EXECUTE ON {database}.* TO '{owner}'@'127.0.0.1';")
    ledger = query(f"SELECT scriptName FROM {database}.schemaversion ORDER BY scriptName;")
    if not ledger.startswith("baseline:v1:") or len(ledger.splitlines()) != 1:
        raise RuntimeError("Expected exactly one schema-only baseline ledger entry.")
    query(f"CALL {database}.spAddGenus('Activity {activity} synthetic', 'Disposable browser fixture');")

    run("useradd", "--system", "--user-group", "--no-create-home", "--shell", "/usr/sbin/nologin", owner)
    app.mkdir(mode=0o755)
    shutil.copytree(published, app / "publish")
    uploads = app / "uploads"
    uploads.mkdir(mode=0o750)
    shutil.chown(uploads, user=owner, group=owner)
    config.mkdir(mode=0o700)
    environment = config / "orchidapp.env"
    fd = os.open(environment, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, "w") as stream:
        stream.write(f'ConnectionStrings__OrchidDb="Server=127.0.0.1;Port=3306;Database={database};'
                     f'User={owner};Password={runtime_secret}"\nStorage__UploadRoot={uploads}\n'
                     "Monitoring__Enabled=false\n")
    with unit_path.open("x") as stream:
        stream.write(f"[Unit]\nDescription=OrchidApp isolated acceptance fixture\nAfter=mariadb.service\n"
                     f"[Service]\nUser={owner}\nWorkingDirectory={app}/publish\n"
                     f"Environment=ASPNETCORE_ENVIRONMENT=Production\nEnvironmentFile={environment}\n"
                     f"ExecStart={dotnet} {app}/publish/OrchidApp.Web.dll --urls http://127.0.0.1:{port}\n"
                     "Restart=on-failure\nRestartSec=2\n")
    run("systemctl", "daemon-reload")
    run("systemctl", "start", unit)
    ready = wait_ready(port, unit)
    started = service_state(unit)
    run("systemctl", "stop", unit)
    stopped = service_state(unit)
    if "ActiveState=inactive" not in stopped or "MainPID=0" not in stopped:
        raise RuntimeError("systemd did not stop the owned fixture.")
    run("systemctl", "start", unit)
    restarted = wait_ready(port, unit)
    print(json.dumps({("target" if is_target else "baseline"): environment_report, "ledger": ledger, "unit": unit, "initialState": started,
                      "stoppedState": stopped, "restartedState": service_state(unit),
                      "initialReadiness": ready, "restartReadiness": restarted}, indent=2))


if __name__ == "__main__":
    main()
