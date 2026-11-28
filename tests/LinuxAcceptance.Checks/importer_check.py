"""Exercise the deployed importer CSV path using an isolated database and systemd."""
import argparse
import importlib.util
import json
import logging
import os
from pathlib import Path
import secrets
import shutil
import socket
import sys

from deploy import APP, OWNER, UNIT, query, run

ROOT = APP / "importer-fixture"
IMPORT_UNIT = "orchidapp-activity08-import.service"
TIMER = "orchidapp-activity08-import.timer"
DATABASE = "orchids_activity08_import"
DB_USER = "orchid08_import"
NAME = "Activity08Sensor_export_202611280900.csv"
CSV = "timestamp,temperature,humidity\n2026-11-28 09:00,21.50,55.25\n2026-11-28 09:10,22.00,54.75\n"


def worker():
    if socket.gethostname() != "orchidapp-debian12" or os.geteuid() == 0:
        raise RuntimeError("Run the importer worker only as the fixture service account.")
    logging.basicConfig(level=logging.INFO)
    script = ROOT / "import-environment-email.py"
    spec = importlib.util.spec_from_file_location("activity08_importer", script)
    importer = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(importer)
    config = {"databaseHost": "127.0.0.1", "databasePort": 3306,
              "databaseName": DATABASE, "databaseUser": DB_USER}
    if importer.import_existing_csv_files(config, ROOT / "downloads", ROOT / "processed", ROOT / "failed") != 1:
        raise RuntimeError("Exactly one synthetic CSV must have been imported.")


def setup(source, python):
    if socket.gethostname() != "orchidapp-debian12" or os.geteuid() != 0 or not APP.is_dir():
        raise RuntimeError("Run only on the deployed disposable Debian 12 fixture.")
    run(str(python), "-c", "import mariadb; print('MariaDB Python connector', mariadb.__version__)")
    status = run("systemctl", "show", UNIT, "--property=User,ActiveState",
                 capture_output=True).stdout.splitlines()
    if f"User={OWNER}" not in status or "ActiveState=active" not in status:
        raise RuntimeError("Expected the running Activity 08 web fixture.")
    service_dir = Path("/etc/systemd/system")
    if any(path.exists() for path in (ROOT, service_dir / IMPORT_UNIT, service_dir / TIMER)):
        raise RuntimeError("Importer fixture already exists.")
    if query(f"SELECT COUNT(*) FROM information_schema.SCHEMATA WHERE SCHEMA_NAME='{DATABASE}';") != "0":
        raise RuntimeError("Refusing to reuse an existing importer database.")
    bootstrap, runtime = secrets.token_hex(24), secrets.token_hex(24)
    query(f"CREATE USER 'orchid08_imp_setup'@'127.0.0.1' IDENTIFIED BY '{bootstrap}';"
          f"GRANT ALL PRIVILEGES ON {DATABASE}.* TO 'orchid08_imp_setup'@'127.0.0.1';")
    env = dict(os.environ, MARIADB_HOST="127.0.0.1", MARIADB_PORT="3306",
               MARIADB_DATABASE=DATABASE, MARIADB_USER="orchid08_imp_setup", MARIADB_PASSWORD=bootstrap,
               MARIADB_CHARSET="utf8mb4", MARIADB_COLLATION="utf8mb4_unicode_ci")
    run("pwsh", "-NoProfile", "-File", str(source / "database/scripts/rebuild.ps1"),
        "-ConfirmDatabase", DATABASE, env=env)
    query("ALTER USER 'orchid08_imp_setup'@'127.0.0.1' ACCOUNT LOCK;"
          f"CREATE USER '{DB_USER}'@'127.0.0.1' IDENTIFIED BY '{runtime}';"
          f"GRANT SELECT, INSERT, UPDATE, DELETE, EXECUTE ON {DATABASE}.* TO '{DB_USER}'@'127.0.0.1';")
    ROOT.mkdir(mode=0o755)
    for name in ("downloads", "processed", "failed"):
        folder = ROOT / name
        folder.mkdir(mode=0o750)
        shutil.chown(folder, user=OWNER, group=OWNER)
    shutil.copyfile(__file__, ROOT / "importer_check.py")
    shutil.copyfile(Path(__file__).with_name("deploy.py"), ROOT / "deploy.py")
    shutil.copyfile(Path(__file__).with_name("preflight.py"), ROOT / "preflight.py")
    importer = source / "infrastructure/environment-importer"
    shutil.copyfile(importer / "import-environment-email.py", ROOT / "import-environment-email.py")
    fd = os.open(ROOT / "importer.env", os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, "w") as stream:
        stream.write(f"ORCHIDAPP_DATABASE_PASSWORD={runtime}\n")
    with (service_dir / IMPORT_UNIT).open("x") as stream:
        stream.write(f"[Unit]\nDescription=Disposable OrchidApp importer CSV fixture\nAfter=mariadb.service\n"
                     f"[Service]\nType=oneshot\nUser={OWNER}\nEnvironmentFile={ROOT}/importer.env\n"
                     f"ExecStart={python} {ROOT}/importer_check.py --worker\n"
                     "IPAddressDeny=any\nIPAddressAllow=localhost\n")
    original_timer = (importer / "systemd/orchidapp-environment-importer.timer").read_text()
    with (service_dir / TIMER).open("x") as stream:
        stream.write(original_timer.replace("[Timer]", f"[Timer]\nUnit={IMPORT_UNIT}").replace("Persistent=true", "Persistent=false"))
    run("systemctl", "daemon-reload")
    try:
        run("systemctl", "start", TIMER)
        timer_state = run("systemctl", "show", TIMER, "--property=ActiveState,Triggers,NextElapseUSecRealtime",
                          capture_output=True).stdout.strip()
        if "ActiveState=active" not in timer_state or f"Triggers={IMPORT_UNIT}" not in timer_state:
            raise RuntimeError("Fixture timer did not target the importer service.")
    finally:
        run("systemctl", "stop", TIMER)

    reading_sql = (f"SELECT environmentReadingId,readingDateTime,temperatureCelsius,relativeHumidity "
                   f"FROM {DATABASE}.environmentreading ORDER BY readingDateTime;")
    history_sql = f"SELECT COUNT(*),COUNT(DISTINCT fileHash) FROM {DATABASE}.environmentimportfile WHERE status='Completed';"
    outcomes = []
    for expected_imports in (1, 2):
        input_file = ROOT / "downloads" / NAME
        input_file.write_text(CSV)
        shutil.chown(input_file, user=OWNER, group=OWNER)
        run("systemctl", "start", IMPORT_UNIT)
        readings = [row.split("\t") for row in query(reading_sql).splitlines()]
        if [row[1:] for row in readings] != [
            ["2026-11-28 09:00:00", "21.50", "55.25"],
            ["2026-11-28 09:10:00", "22.00", "54.75"],
        ]:
            raise RuntimeError("Stored readings differ from the synthetic CSV.")
        if query(history_sql) != f"{expected_imports}\t1":
            raise RuntimeError("Importer audit history did not record the repeated input correctly.")
        if input_file.exists() or len(list((ROOT / "processed").glob("*.csv"))) != expected_imports or any((ROOT / "failed").iterdir()):
            raise RuntimeError("Importer did not move the CSV to the processed directory.")
        outcomes.append(readings)
    if outcomes[0] != outcomes[1]:
        raise RuntimeError("Repeat input duplicated or replaced existing reading identities.")
    print(json.dumps({"database": DATABASE, "unit": IMPORT_UNIT, "timer": timer_state,
                      "storedReadings": outcomes[-1], "completedImports": 2, "distinctInputHashes": 1,
                      "transport": "local CSV; no IMAP or SMTP"}, indent=2))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--worker", action="store_true")
    parser.add_argument("--source", type=Path)
    parser.add_argument("--python", type=Path)
    args = parser.parse_args()
    if args.worker:
        worker()
    elif args.source and args.python:
        setup(args.source.resolve(strict=True), args.python.absolute())
    else:
        parser.error("Supply --source and --python for provisioning.")
