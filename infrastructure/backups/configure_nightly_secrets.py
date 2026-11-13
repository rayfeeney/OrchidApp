"""Run interactively on Pi 1 as root. No service, schedule or authentication changes."""
import getpass
import os
from pathlib import Path
import sys


def quoted(value):
    # MariaDB option file string escaping; never source shell text.
    return '"' + value.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n').replace('\r', '\\r').replace('\t', '\\t') + '"'


def main():
    if not sys.platform.startswith('linux') or os.geteuid() != 0 or not sys.stdin.isatty():
        raise SystemExit('Run using sudo python3 from an interactive Pi terminal')
    os.umask(0o077)
    root = Path('/etc/orchidapp')
    targets = [root / 'nightly-client.cnf', root / 'nightly-smtp-password']
    if not root.is_dir() or any(p.exists() or p.is_symlink() for p in targets):
        raise SystemExit('Settings directory missing or secret files already exist; no files changed')
    database_user = input('Existing MariaDB backup/admin user [root]: ').strip() or 'root'
    database_password = getpass.getpass('MariaDB password (hidden): ')
    smtp_password = getpass.getpass('GMX SMTP/app password (hidden): ')
    if not database_password or not smtp_password:
        raise SystemExit('Empty password refused; no files changed')
    contents = ['[client]\nprotocol=tcp\nhost=127.0.0.1\nport=3306\nuser=' + quoted(database_user)
                + '\npassword=' + quoted(database_password) + '\n', smtp_password + '\n']
    for path, content in zip(targets, contents):
        with path.open('x', encoding='utf-8') as out:
            out.write(content)
            out.flush()
            os.fsync(out.fileno())
    print('Two private credential files created. No grants, services or schedules changed.')


if __name__ == '__main__':
    main()
