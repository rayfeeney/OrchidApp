"""Read-only preflight for the designated Activity 08 Debian baseline guest."""
import json
import platform
import shlex
import socket
import subprocess
from pathlib import Path


EXPECTED_HOST = "orchidapp-debian12"
EXPECTED_OS = "12.15"
EXPECTED_MARIADB = "10.11.19"


def command(*arguments):
    return subprocess.run(arguments, check=True, capture_output=True, text=True, timeout=15).stdout.strip()


def preflight():
    if platform.system() != "Linux" or socket.gethostname().lower() != EXPECTED_HOST:
        raise RuntimeError(f"Run only on the isolated {EXPECTED_HOST} baseline VM.")
    if platform.machine() != "x86_64":
        raise RuntimeError("Expected the designated x86_64 Debian baseline.")
    release = dict(
        (name, shlex.split(value)[0])
        for line in Path("/etc/os-release").read_text().splitlines()
        if line and not line.startswith("#")
        for name, value in [line.split("=", 1)]
        if value
    )
    version = Path("/etc/debian_version").read_text().strip()
    if release.get("ID") != "debian" or version != EXPECTED_OS:
        raise RuntimeError(f"Expected Debian {EXPECTED_OS}, observed {release.get('ID')} {version}.")
    if Path("/proc/1/comm").read_text().strip() != "systemd":
        raise RuntimeError("The baseline requires real systemd as PID 1.")
    if command("systemctl", "is-active", "mariadb.service") != "active":
        raise RuntimeError("Expected an active guest MariaDB service.")
    listeners = command("ss", "-H", "-ltn", "sport = :3306")
    addresses = {line.split()[3] for line in listeners.splitlines()}
    if addresses != {"127.0.0.1:3306"}:
        raise RuntimeError(f"MariaDB listener differs from the recorded loopback baseline: {sorted(addresses)}.")

    server = command("mariadb", "--no-defaults", "--protocol=SOCKET", "--batch",
                     "--skip-column-names", "--execute",
                     "SELECT VERSION(), @@character_set_server, @@collation_server;")
    version, charset, collation = server.split("\t")
    if not version.startswith(EXPECTED_MARIADB + "-") or (charset, collation) != ("utf8mb4", "utf8mb4_unicode_ci"):
        raise RuntimeError(f"MariaDB version or server defaults differ: {server}.")
    databases = command("mariadb", "--no-defaults", "--protocol=SOCKET", "--batch",
                        "--skip-column-names", "--execute", "SHOW DATABASES;").splitlines()
    unexpected = set(databases) - {"information_schema", "mysql", "performance_schema", "sys"}
    if unexpected:
        raise RuntimeError(f"Expected only system databases; found {len(unexpected)} application schemas.")
    if any(Path(path).exists() for path in ("/opt/orchidapp", "/etc/systemd/system/orchidapp.service")):
        raise RuntimeError("OrchidApp installation state already exists on the baseline guest.")
    dotnet = command("dotnet", "--version")
    if not dotnet.startswith("8.0."):
        raise RuntimeError(f"Expected .NET 8, observed {dotnet}.")
    return {
        "hostname": EXPECTED_HOST,
        "architecture": platform.machine(),
        "debian": EXPECTED_OS,
        "mariadb": version,
        "charset": charset,
        "collation": collation,
        "dotnetSdk": dotnet,
        "listener": sorted(addresses),
        "systemd": "PID 1",
        "applicationDatabases": 0,
    }


if __name__ == "__main__":
    print(json.dumps(preflight(), indent=2))
