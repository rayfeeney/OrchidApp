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

from deploy import query, run

CSV = "timestamp,temperature,humidity\n2026-11-28 09:00,21.50,55.25\n2026-11-28 09:10,22.00,54.75\n"


def worker(repeat_target):
    activity, host = ("11", "orchidapp-debian13") if repeat_target else ("08", "orchidapp-debian12")
    root = Path(f"/opt/orchidapp-activity{activity}/importer-fixture")
    database, db_user = f"orchids_activity{activity}_import", f"orchid{activity}_import"
    if socket.gethostname() != host or os.geteuid() == 0:
        raise RuntimeError("Run the importer worker only as the fixture service account.")
    logging.basicConfig(level=logging.INFO)
    script = root / "import-environment-email.py"
    spec = importlib.util.spec_from_file_location("orchid_fixture_importer", script)
    importer = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(importer)
    config = {"databaseHost": "127.0.0.1", "databasePort": 3306,
              "databaseName": database, "databaseUser": db_user}
    if importer.import_existing_csv_files(config, root / "downloads", root / "processed", root / "failed") != 1:
        raise RuntimeError("Exactly one synthetic CSV must have been imported.")


def setup(source, python, repeat_target):
    activity, host = ("11", "orchidapp-debian13") if repeat_target else ("08", "orchidapp-debian12")
    app, owner = Path(f"/opt/orchidapp-activity{activity}"), f"orchid{activity}"
    unit = f"orchidapp-activity{activity}.service"
    root = app / "importer-fixture"
    import_unit = f"orchidapp-activity{activity}-import.service"
    timer = f"orchidapp-activity{activity}-import.timer"
    database, db_user = f"orchids_activity{activity}_import", f"orchid{activity}_import"
    setup_user = f"orchid{activity}_imp_setup"
    name = f"Activity{activity}Sensor_export_202611280900.csv"
    worker_options = " --repeat-target" if repeat_target else ""
    if socket.gethostname() != host or os.geteuid() != 0 or not app.is_dir():
        raise RuntimeError("Run only on the designated deployed disposable Debian fixture.")
    if repeat_target and not query("SELECT VERSION();").startswith("11.8.9-MariaDB"):
        raise RuntimeError("Expected MariaDB 11.8.9 on the Activity 11 guest.")
    run(str(python), "-c", "import mariadb; print('MariaDB Python connector', mariadb.__version__)")
    status = run("systemctl", "show", unit, "--property=User,ActiveState",
                 capture_output=True).stdout.splitlines()
    if f"User={owner}" not in status or "ActiveState=active" not in status:
        raise RuntimeError(f"Expected the running fixture {unit}.")
    service_dir = Path("/etc/systemd/system")
    if any(path.exists() for path in (root, service_dir / import_unit, service_dir / timer)):
        raise RuntimeError("Importer fixture already exists.")
    if query(f"SELECT COUNT(*) FROM information_schema.SCHEMATA WHERE SCHEMA_NAME='{database}';") != "0":
        raise RuntimeError("Refusing to reuse an existing importer database.")
    bootstrap, runtime = secrets.token_hex(24), secrets.token_hex(24)
    query(f"CREATE USER '{setup_user}'@'127.0.0.1' IDENTIFIED BY '{bootstrap}';"
          f"GRANT ALL PRIVILEGES ON {database}.* TO '{setup_user}'@'127.0.0.1';")
    env = dict(os.environ, MARIADB_HOST="127.0.0.1", MARIADB_PORT="3306",
               MARIADB_DATABASE=database, MARIADB_USER=setup_user, MARIADB_PASSWORD=bootstrap,
               MARIADB_CHARSET="utf8mb4", MARIADB_COLLATION="utf8mb4_unicode_ci")
    run("pwsh", "-NoProfile", "-File", str(source / "database/scripts/rebuild.ps1"),
        "-ConfirmDatabase", database, env=env)
    query(f"ALTER USER '{setup_user}'@'127.0.0.1' ACCOUNT LOCK;"
          f"CREATE USER '{db_user}'@'127.0.0.1' IDENTIFIED BY '{runtime}';"
          f"GRANT SELECT, INSERT, UPDATE, DELETE, EXECUTE ON {database}.* TO '{db_user}'@'127.0.0.1';")
    root.mkdir(mode=0o755)
    for folder_name in ("downloads", "processed", "failed"):
        folder = root / folder_name
        folder.mkdir(mode=0o750)
        shutil.chown(folder, user=owner, group=owner)
    shutil.copyfile(__file__, root / "importer_check.py")
    shutil.copyfile(Path(__file__).with_name("deploy.py"), root / "deploy.py")
    shutil.copyfile(Path(__file__).with_name("preflight.py"), root / "preflight.py")
    importer = source / "infrastructure/environment-importer"
    shutil.copyfile(importer / "import-environment-email.py", root / "import-environment-email.py")
    fd = os.open(root / "importer.env", os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, "w") as stream:
        stream.write(f"ORCHIDAPP_DATABASE_PASSWORD={runtime}\n")
    with (service_dir / import_unit).open("x") as stream:
        stream.write(f"[Unit]\nDescription=Disposable OrchidApp importer CSV fixture\nAfter=mariadb.service\n"
                     f"[Service]\nType=oneshot\nUser={owner}\nEnvironmentFile={root}/importer.env\n"
                     f"ExecStart={python} {root}/importer_check.py --worker{worker_options}\n"
                     "IPAddressDeny=any\nIPAddressAllow=localhost\n")
    original_timer = (importer / "systemd/orchidapp-environment-importer.timer").read_text()
    with (service_dir / timer).open("x") as stream:
        stream.write(original_timer.replace("[Timer]", f"[Timer]\nUnit={import_unit}").replace("Persistent=true", "Persistent=false"))
    run("systemctl", "daemon-reload")
    try:
        run("systemctl", "start", timer)
        timer_state = run("systemctl", "show", timer, "--property=ActiveState,Triggers,NextElapseUSecRealtime",
                          capture_output=True).stdout.strip()
        if "ActiveState=active" not in timer_state or f"Triggers={import_unit}" not in timer_state:
            raise RuntimeError("Fixture timer did not target the importer service.")
    finally:
        run("systemctl", "stop", timer)

    reading_sql = (f"SELECT environmentReadingId,readingDateTime,temperatureCelsius,relativeHumidity "
                   f"FROM {database}.environmentreading ORDER BY readingDateTime;")
    history_sql = f"SELECT COUNT(*),COUNT(DISTINCT fileHash) FROM {database}.environmentimportfile WHERE status='Completed';"
    outcomes = []
    for expected_imports in (1, 2):
        input_file = root / "downloads" / name
        input_file.write_text(CSV)
        shutil.chown(input_file, user=owner, group=owner)
        run("systemctl", "start", import_unit)
        readings = [row.split("\t") for row in query(reading_sql).splitlines()]
        if [row[1:] for row in readings] != [
            ["2026-11-28 09:00:00", "21.50", "55.25"],
            ["2026-11-28 09:10:00", "22.00", "54.75"],
        ]:
            raise RuntimeError("Stored readings differ from the synthetic CSV.")
        if query(history_sql) != f"{expected_imports}\t1":
            raise RuntimeError("Importer audit history did not record the repeated input correctly.")
        if input_file.exists() or len(list((root / "processed").glob("*.csv"))) != expected_imports or any((root / "failed").iterdir()):
            raise RuntimeError("Importer did not move the CSV to the processed directory.")
        outcomes.append(readings)
    if outcomes[0] != outcomes[1]:
        raise RuntimeError("Repeat input duplicated or replaced existing reading identities.")
    print(json.dumps({"database": database, "unit": import_unit, "timer": timer_state,
                      "storedReadings": outcomes[-1], "completedImports": 2, "distinctInputHashes": 1,
                      "transport": "local CSV; no IMAP or SMTP"}, indent=2))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--worker", action="store_true")
    parser.add_argument("--source", type=Path)
    parser.add_argument("--python", type=Path)
    parser.add_argument("--repeat-target", action="store_true", help="Use the Activity 11 Debian 13 fixture.")
    args = parser.parse_args()
    if args.worker:
        worker(args.repeat_target)
    elif args.source and args.python:
        setup(args.source.resolve(strict=True), args.python.absolute(), args.repeat_target)
    else:
        parser.error("Supply --source and --python for provisioning.")
