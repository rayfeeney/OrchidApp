"""Read-only preflight for the designated Debian baseline and target guests."""
import argparse
import json
import platform
import re
import shlex
import socket
import subprocess
from pathlib import Path


BASELINE = ("orchidapp-debian12", "12.15", "10.11.19")
TARGET = ("orchidapp-debian13", "13.8", "11.8.9")


def command(*arguments):
    return subprocess.run(arguments, check=True, capture_output=True, text=True, timeout=15).stdout.strip()


def preflight(target=False):
    expected_host, expected_os, expected_mariadb = TARGET if target else BASELINE
    if platform.system() != "Linux" or socket.gethostname().lower() != expected_host:
        raise RuntimeError(f"Run only on the isolated {expected_host} VM.")
    if platform.machine() != "x86_64":
        raise RuntimeError("Expected the designated x86_64 Debian guest.")
    release = dict(
        (name, shlex.split(value)[0])
        for line in Path("/etc/os-release").read_text().splitlines()
        if line and not line.startswith("#")
        for name, value in [line.split("=", 1)]
        if value
    )
    version = Path("/etc/debian_version").read_text().strip()
    if release.get("ID") != "debian" or version != expected_os:
        raise RuntimeError(f"Expected Debian {expected_os}, observed {release.get('ID')} {version}.")
    if Path("/proc/1/comm").read_text().strip() != "systemd":
        raise RuntimeError("The preflight requires real systemd as PID 1.")
    if command("systemctl", "is-active", "mariadb.service") != "active":
        raise RuntimeError("Expected an active guest MariaDB service.")
    listeners = command("ss", "-H", "-ltn", "sport = :3306")
    addresses = {line.split()[3] for line in listeners.splitlines()}
    if addresses != {"127.0.0.1:3306"}:
        raise RuntimeError(f"MariaDB listener differs from the recorded loopback configuration: {sorted(addresses)}.")

    server = command("mariadb", "--no-defaults", "--protocol=SOCKET", "--batch",
                     "--skip-column-names", "--execute",
                     "SELECT VERSION(), @@character_set_server, @@collation_server;")
    version, charset, collation = server.split("\t")
    if not version.startswith(expected_mariadb + "-") or (charset, collation) != ("utf8mb4", "utf8mb4_unicode_ci"):
        raise RuntimeError(f"MariaDB version or server defaults differ: {server}.")
    client_version = command("mariadb", "--no-defaults", "--version")
    if target and not re.search(rf"\b{re.escape(expected_mariadb)}-MariaDB\b", client_version):
        raise RuntimeError(f"MariaDB client does not match the target: {client_version}.")

    databases = command("mariadb", "--no-defaults", "--protocol=SOCKET", "--batch",
                        "--skip-column-names", "--execute", "SHOW DATABASES;").splitlines()
    unexpected = set(databases) - {"information_schema", "mysql", "performance_schema", "sys"}
    if unexpected:
        raise RuntimeError(f"Expected only system databases; found {len(unexpected)} application schemas.")
    installation_paths = ("/opt/orchidapp", "/etc/systemd/system/orchidapp.service",
                          "/opt/orchidapp-activity08", "/etc/systemd/system/orchidapp-activity08.service",
                          "/opt/orchidapp-activity10", "/etc/systemd/system/orchidapp-activity10.service")
    if any(Path(path).exists() for path in installation_paths):
        raise RuntimeError("OrchidApp installation state already exists on the selected guest.")
    dotnet = command("dotnet", "--version")
    if not dotnet.startswith("8.0."):
        raise RuntimeError(f"Expected .NET 8, observed {dotnet}.")
    return {
        "hostname": expected_host,
        "architecture": platform.machine(),
        "debian": expected_os,
        "mariadb": version,
        "mariadbClient": client_version,
        "charset": charset,
        "collation": collation,
        "dotnetSdk": dotnet,
        "listener": sorted(addresses),
        "systemd": "PID 1",
        "applicationDatabases": 0,
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--target", action="store_true", help="Check the designated Debian 13/MariaDB 11.8 guest.")
    print(json.dumps(preflight(target=parser.parse_args().target), indent=2))
