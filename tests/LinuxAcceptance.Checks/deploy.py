"""Provision and exercise one disposable Activity 08 systemd installation."""
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


def wait_ready():
    url = f"http://127.0.0.1:{PORT}/health/ready"
    for _ in range(60):
        try:
            with urllib.request.urlopen(url, timeout=4) as stream:
                body = json.load(stream)
            if body.get("ready") and body.get("checks") and all(body["checks"].values()):
                return body
        except (urllib.error.URLError, TimeoutError):
            pass
        time.sleep(1)
    raise RuntimeError(f"Fixture did not become ready. Inspect journalctl -u {UNIT}.")


def service_state():
    return run("systemctl", "show", UNIT, "--property=ActiveState,User,MainPID",
               capture_output=True).stdout.strip()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--publish", type=Path, required=True)
    args = parser.parse_args()
    if os.geteuid() != 0:
        parser.error("Run as root on the designated disposable guest.")
    baseline = preflight()
    source, published = args.source.resolve(strict=True), args.publish.resolve(strict=True)
    rebuild = source / "database/scripts/rebuild.ps1"
    if not rebuild.is_file() or not (published / "OrchidApp.Web.dll").is_file():
        parser.error("Supply the reviewed source and completed x64 publish directories.")
    dotnet, pwsh = shutil.which("dotnet"), shutil.which("pwsh")
    if not dotnet or not pwsh:
        parser.error(".NET 8 and PowerShell are required.")
    for path in (APP, CONFIG, UNIT_PATH):
        if os.path.lexists(path):
            raise RuntimeError(f"Refusing to overwrite fixture state at {path}.")
    with socket.socket() as listener:
        listener.bind(("127.0.0.1", PORT))
    if subprocess.run(("getent", "passwd", OWNER), stdout=subprocess.DEVNULL).returncode != 2:
        raise RuntimeError("The intended fixture service account is already present.")
    if query("SELECT COUNT(*) FROM mysql.user WHERE User IN ('orchid08','orchid08_setup');") != "0":
        raise RuntimeError("The intended fixture database accounts are already present.")

    setup_secret, runtime_secret = secrets.token_hex(24), secrets.token_hex(24)
    query(f"CREATE USER 'orchid08_setup'@'127.0.0.1' IDENTIFIED BY '{setup_secret}';"
          f"GRANT ALL PRIVILEGES ON {DATABASE}.* TO 'orchid08_setup'@'127.0.0.1';")
    setup_env = dict(os.environ, MARIADB_HOST="127.0.0.1", MARIADB_PORT="3306",
                     MARIADB_DATABASE=DATABASE, MARIADB_USER="orchid08_setup",
                     MARIADB_PASSWORD=setup_secret, MARIADB_CHARSET="utf8mb4",
                     MARIADB_COLLATION="utf8mb4_unicode_ci")
    run(pwsh, "-NoProfile", "-File", str(rebuild), "-ConfirmDatabase", DATABASE, env=setup_env)

    query("ALTER USER 'orchid08_setup'@'127.0.0.1' ACCOUNT LOCK;"
          f"CREATE USER '{OWNER}'@'127.0.0.1' IDENTIFIED BY '{runtime_secret}';"
          f"GRANT SELECT, INSERT, UPDATE, DELETE, EXECUTE ON {DATABASE}.* TO '{OWNER}'@'127.0.0.1';")
    ledger = query(f"SELECT scriptName FROM {DATABASE}.schemaversion ORDER BY scriptName;")
    if not ledger.startswith("baseline:v1:") or len(ledger.splitlines()) != 1:
        raise RuntimeError("Expected exactly one schema-only baseline ledger entry.")
    query(f"CALL {DATABASE}.spAddGenus('Activity 08 synthetic', 'Disposable browser fixture');")

    run("useradd", "--system", "--user-group", "--no-create-home", "--shell", "/usr/sbin/nologin", OWNER)
    APP.mkdir(mode=0o755)
    shutil.copytree(published, APP / "publish")
    uploads = APP / "uploads"
    uploads.mkdir(mode=0o750)
    shutil.chown(uploads, user=OWNER, group=OWNER)
    CONFIG.mkdir(mode=0o700)
    environment = CONFIG / "orchidapp.env"
    fd = os.open(environment, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, "w") as stream:
        stream.write(f'ConnectionStrings__OrchidDb="Server=127.0.0.1;Port=3306;Database={DATABASE};'
                     f'User={OWNER};Password={runtime_secret}"\nStorage__UploadRoot={uploads}\n'
                     "Monitoring__Enabled=false\n")
    with UNIT_PATH.open("x") as stream:
        stream.write(f"[Unit]\nDescription=OrchidApp Activity 08 fixture\nAfter=mariadb.service\n"
                     f"[Service]\nUser={OWNER}\nWorkingDirectory={APP}/publish\n"
                     f"Environment=ASPNETCORE_ENVIRONMENT=Production\nEnvironmentFile={environment}\n"
                     f"ExecStart={dotnet} {APP}/publish/OrchidApp.Web.dll --urls http://127.0.0.1:{PORT}\n"
                     "Restart=on-failure\nRestartSec=2\n")
    run("systemctl", "daemon-reload")
    run("systemctl", "start", UNIT)
    ready = wait_ready()
    started = service_state()
    run("systemctl", "stop", UNIT)
    stopped = service_state()
    if "ActiveState=inactive" not in stopped or "MainPID=0" not in stopped:
        raise RuntimeError("systemd did not stop the owned fixture.")
    run("systemctl", "start", UNIT)
    restarted = wait_ready()
    print(json.dumps({"baseline": baseline, "ledger": ledger, "unit": UNIT, "initialState": started,
                      "stoppedState": stopped, "restartedState": service_state(),
                      "initialReadiness": ready, "restartReadiness": restarted}, indent=2))


if __name__ == "__main__":
    main()
