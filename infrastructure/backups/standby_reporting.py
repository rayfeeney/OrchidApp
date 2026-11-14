"""Pi 2 restore reports and durable email retries; no restore or cloud changes."""
import argparse
from datetime import datetime, timezone
import getpass
import json
import os
from pathlib import Path
import re
import sys
import uuid

import standby_restore as s

b, n = s.b, s.n


def load_config(filename, setup=False):
    path = b.absolute(filename)
    b.protected_file(path)
    c = json.loads(path.read_text())
    c['collection_id'] = str(uuid.UUID(c['collection_id']))
    b.require(c['databases'] == ['orchids', 'EnergyMonitoring'], 'Use the two reviewed standby databases')
    c['backup_root'] = s.private_directory(b.absolute(c['state_root']))
    b.require(c['backup_root'].name == 'orchidapp-standby', 'Use the existing standby state root')
    c['smtp_password_file'] = b.absolute(c['smtp_password_file'])
    b.require(c['smtp_password_file'].parent == path.parent
              and not b.overlaps(c['backup_root'], path.parent), 'Keep email credentials separate from state')
    if not setup:
        b.protected_file(c['smtp_password_file'])
    mail = c['email']
    b.require(mail['port'] in (465, 587) and re.fullmatch(r'[A-Za-z0-9.-]+', mail['host']), 'Invalid SMTP endpoint')
    for field in ('sender', 'recipient'):
        b.require(re.fullmatch(r'[^\s<>@]+@[^\s<>@]+', mail[field]), 'Invalid email address')
    c['max_age_hours'] = c.get('max_age_hours', 30)
    b.require(type(c['max_age_hours']) is int and c['max_age_hours'] > 0, 'Invalid freshness threshold')
    c['max_archive_bytes'] = 5 * 1024**3
    c['log_file'] = c['backup_root'] / 'standby-reporting.log'
    b.absolute(str(c['log_file']))
    if c['log_file'].exists():
        b.protected_file(c['log_file'])
    return c


def setup_secret(c):
    b.require(sys.stdin.isatty(), 'Run password setup in an interactive Pi terminal')
    path = c['smtp_password_file']
    b.require(not path.exists(), 'SMTP password already exists; no files changed')
    password = getpass.getpass('GMX SMTP/app password (hidden): ')
    confirmation = getpass.getpass('Repeat GMX password (hidden): ')
    b.require(password and password == confirmation and '\n' not in password and '\r' not in password,
              'Passwords empty, different or invalid; no files changed')
    with path.open('x', encoding='utf-8') as output:
        output.write(password + '\n')
        output.flush()
        os.fsync(output.fileno())
    return {'result': 'PRIVATE_SMTP_PASSWORD_CREATED'}


def accepted(c):
    path = c['backup_root'] / 'last-accepted.json'
    if not path.exists():
        return None
    b.protected_file(path)
    value = json.loads(path.read_text())
    b.require(value.get('format') == 'orchidapp-standby-accepted-v1'
              and value.get('services_started') is False, 'Recognised stopped acceptance record required')
    s.check_record(c, value['record'], freshness=False)
    return value


def enqueue_once(c, key, subject, body):
    """Queue before marking reported: a crash can duplicate mail, never lose it."""
    ledger = c['backup_root'] / 'email-reported.json'
    previous = {}
    if ledger.exists():
        b.protected_file(ledger)
        previous = json.loads(ledger.read_text())
    if previous.get(key.split(':', 1)[0]) == key:
        return False
    n.queue_email(c, subject, body)
    previous[key.split(':', 1)[0]] = key
    n.atomic_json(ledger, previous)
    return True


def report_success(c):
    value = accepted(c)
    b.require(value is not None, 'No accepted standby: success email refused')
    record = value['record']
    enqueue_once(c, 'success:' + record['snapshot'], '[Pi 2 restore] SUCCESS',
                 'Accepted restore on Pi 2 (standby stopped).\nSnapshot: ' + record['snapshot']
                 + '\nRecovery point: ' + record['recovery_point']
                 + '\nAccepted at: ' + value['accepted_at']
                 + '\nDatabases: ' + ', '.join(record['databases'])
                 + '\nPhotographs/thumbnails checked: ' + str(value['photo_files_checked'])
                 + '\nApplication starts checked: ' + str(value['application_starts'])
                 + '\nStandby application and collectors remain stopped; restore/monitor timers may run.\n')
    return {'result': 'SUCCESS_REPORT_QUEUED_OR_PREVIOUSLY_REPORTED', 'snapshot': record['snapshot']}


def monitor(c, clock=None):
    clock = clock or datetime.now(timezone.utc)
    value = accepted(c)
    overdue = value is None or (clock - s.timestamp(value['record']['recovery_point'])).total_seconds() > c['max_age_hours'] * 3600
    if overdue:
        recovery = value['record']['recovery_point'] if value else 'No accepted restore'
        enqueue_once(c, 'overdue:' + clock.strftime('%Y-%m-%d'), '[Pi 2 restore] OVERDUE',
                     'Pi 2 has no accepted restore within ' + str(c['max_age_hours'])
                     + ' hours.\nLast recovery point: ' + recovery + '\nCheck the restore process.\n')
    return {'result': 'OVERDUE' if overdue else 'CURRENT'}


def failure(c, phase):
    """Coordinator entry: no raw SQL, exception text or credentials in email."""
    b.require(re.fullmatch(r'[A-Za-z0-9_-]{1,64}', phase), 'Use a short failure phase identifier')
    n.queue_email(c, '[Pi 2 restore] FAILED',
                  'Pi 2 restore failed during: ' + phase
                  + '\nInspect private restore state/logs. No new success is reported.\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('operation', choices=('configure-secret', 'test-email', 'test-failure', 'success', 'monitor', 'retry-email'))
    parser.add_argument('--config', required=True)
    args = parser.parse_args()
    os.umask(0o077)
    try:
        b.require(sys.platform.startswith('linux') and os.geteuid() == 0, 'Run reporting as root on Pi 2')
        c = load_config(args.config, setup=args.operation == 'configure-secret')
        if args.operation == 'configure-secret':
            print(json.dumps(setup_secret(c)))
            return 0
        # Separate from the restore lock so email retry/freshness can run during a restore.
        root = s.private_directory(c['backup_root'] / 'reporting-lock')
        with b.operation_lock(root):
            result = {'result': 'EMAIL_RETRY'}
            if args.operation in ('test-email', 'test-failure'):
                label = 'FAILED' if args.operation == 'test-failure' else 'EMAIL'
                n.queue_email(c, '[Pi 2 restore] TEST ' + label,
                              'Pi 2 reporting test only. No restore or accepted state was changed.\n')
                result = {'result': 'TEST_' + label}
            elif args.operation == 'success':
                result = report_success(c)
            elif args.operation == 'monitor':
                result = monitor(c)
            delivered = n.flush_email(c)
            result['email_delivery'] = 'SMTP_ACCEPTED' if delivered else 'PENDING_RETRY'
            print(json.dumps(result, indent=2))
            return 2 if not delivered else (1 if result['result'] == 'OVERDUE' else 0)
    except Exception as ex:
        print('ERROR: ' + (str(ex) if isinstance(ex, b.BackupError) else 'Reporting failed; inspect private settings/state'), file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
