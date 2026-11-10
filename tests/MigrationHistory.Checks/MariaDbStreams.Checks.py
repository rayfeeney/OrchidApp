"""Check that MariaDB diagnostics cannot become migration query rows."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile


def main():
    runner = Path(__file__).resolve().parents[2] / "database/scripts/Apply-Migrations.ps1"
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        migrations = root / "migrations"
        migrations.mkdir()
        (migrations / "209901010000_Pending.sql").write_text("SELECT 1;\n")
        client = root / "client.py"
        client.write_text(r"""#!/usr/bin/env python3
import os
import sys
sql = sys.stdin.readline()
mode = os.environ["ORCHID_TEST_CLIENT_MODE"]
print("WARNING: SSL certificate verification is disabled", file=sys.stderr)
if mode == "fail":
    print("ERROR 1045: fixture access denied", file=sys.stderr)
    sys.exit(7)
if "SELECT ENGINE" in sql:
    print("MyISAM" if mode == "wrong-engine" else "InnoDB")
elif "SELECT scriptName, checksum" in sql:
    print("baseline:v1:202606041820", "a" * 64, sep="\t")
else:
    sys.exit(9)
""", newline="\n")
        if os.name == "nt":
            wrapper = root / "mariadb.cmd"
            wrapper.write_text(f'@echo off\n"{sys.executable}" "%~dp0client.py"\n')
            client = wrapper
        else:
            client.chmod(0o700)
        command = ["pwsh", "-NoProfile", "-File", str(runner), "-MariaDbExe",
                   str(client), "-MigrationFolder", str(migrations), "-PlanOnly"]
        env = dict(os.environ, MARIADB_HOST="127.0.0.1", MARIADB_PORT="3306",
                   MARIADB_USER="fixture", MARIADB_PASSWORD="fixture",
                   MARIADB_DATABASE="fixture")

        def run(mode):
            return subprocess.run(command, env=dict(env, ORCHID_TEST_CLIENT_MODE=mode),
                                  capture_output=True, text=True, timeout=30)

        warning = run("warn")
        assert warning.returncode == 0, warning.stderr
        assert "pending: 1" in warning.stdout, warning.stdout
        assert "WARNING: SSL" in warning.stderr and "WARNING: SSL" not in warning.stdout
        failure = run("fail")
        assert failure.returncode != 0 and "exit 7" in failure.stderr, failure.stderr
        assert "ERROR 1045" in failure.stderr, failure.stderr
        wrong_engine = run("wrong-engine")
        assert wrong_engine.returncode != 0 and "must use InnoDB" in wrong_engine.stderr, wrong_engine.stderr
    print("MariaDB warning, nonzero exit, and wrong-engine checks passed.")


if __name__ == "__main__":
    main()
