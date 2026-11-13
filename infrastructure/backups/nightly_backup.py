"""Block 1: multi-database capture, verified crypt upload and durable email outbox.

Separate archive format from orchid_backup.py; never feed it to the old restore CLI.
"""
import argparse
import configparser
from datetime import datetime, timezone
from email.message import EmailMessage
from email.utils import formatdate, make_msgid
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import signal
import smtplib
import ssl
import sys
import tarfile
import tempfile
import threading
import time
import urllib.request
import uuid

import orchid_backup as b

FORMAT = 'orchidapp-mariadb-set-v1'
NAME = re.compile(r'orchidset-[0-9]{8}T[0-9]{6}Z-[0-9a-f]{32}')


def now():
    return datetime.now(timezone.utc).isoformat()


def atomic_json(path, value):
    temp = path.with_name(path.name + '.' + uuid.uuid4().hex + '.tmp')
    try:
        # Callers may import this helper without main()'s private umask.
        # Set the creation mode explicitly, before writing any configuration.
        fd = os.open(temp, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(fd, 'w', encoding='utf-8') as out:
            json.dump(value, out, indent=2)
            out.flush()
            os.fsync(out.fileno())
        temp.replace(path)
        if os.name == 'posix':
            fd = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY)
            try:
                os.fsync(fd)
            finally:
                os.close(fd)
    finally:
        temp.unlink(missing_ok=True)


def load_config(filename):
    path = b.absolute(filename)
    b.protected_file(path)
    c = json.loads(path.read_text(encoding='utf-8'))
    b.require(isinstance(c, dict), 'Configuration must be an object')
    c['collection_id'] = str(uuid.UUID(c['collection_id']))
    names = c['databases']
    b.require(isinstance(names, list) and names and all(isinstance(n, str) for n in names) and len(set(names)) == len(names)
              and all(isinstance(n, str) and re.fullmatch(r'[A-Za-z][A-Za-z0-9_]*', n)
                      and n.lower() not in ('mysql', 'sys', 'performance_schema', 'information_schema')
                      for n in names), 'Explicit unique application database names required')
    b.require(c['photo_database'] in names, 'Photo database must be included')
    c['database'] = c['photo_database']
    for key in ('backup_root', 'client_defaults_file', 'rclone_config', 'smtp_password_file'):
        c[key] = b.absolute(c[key])
    for key in ('client_defaults_file', 'rclone_config', 'smtp_password_file'):
        b.protected_file(c[key])
    root = c['backup_root']
    root.mkdir(mode=0o700, parents=True, exist_ok=True)
    if os.name == 'posix':
        st = root.stat()
        b.require(st.st_uid in (0, os.geteuid()) and not st.st_mode & 0o077, 'Backup root must be private')
    c['log_file'] = root / 'nightly.log'
    b.require(not c['log_file'].is_symlink(), 'Log must not be a symlink')
    if c['log_file'].exists():
        b.protected_file(c['log_file'])
    c['sources'] = {name: b.absolute(value) for name, value in c['sources'].items()}
    b.require(c['sources'] and c['uploads_source'] in c['sources'], 'Uploads source required')
    for name, src in c['sources'].items():
        b.require(re.fullmatch(r'[a-z][a-z0-9_-]*', name) and (src.is_file() or src.is_dir()), 'Invalid source')
        b.require(not b.overlaps(src, root), 'Sources and backup storage must be separate')
    b.require(c['sources'][c['uploads_source']].is_dir(), 'Uploads must be a directory')
    b.require(isinstance(c['writer_units'], list) and c['writer_units']
              and len(set(c['writer_units'])) == len(c['writer_units'])
              and all(re.fullmatch(r'[A-Za-z0-9_.@:-]+\.(service|timer)', u) for u in c['writer_units']),
              'Explicit unique writer services/timers required')
    for key, default in (('keep_local', 1), ('keep_remote', 7), ('timeout_seconds', 1800),
                         ('max_unpack_bytes', 20 * 1024**3), ('reserve_bytes', 1024**3),
                         ('max_age_hours', 30)):
        c[key] = c.get(key, default)
        b.require(type(c[key]) is int and c[key] >= 1, 'Invalid positive setting: ' + key)
    remote = c['remote']
    b.require(re.fullmatch(r'[A-Za-z0-9_-]+:[A-Za-z0-9_-][A-Za-z0-9_./-]*', remote)
              and not {'.', '..'} & set(remote.split(':', 1)[1].split('/')), 'Dedicated remote directory required')
    rc = configparser.RawConfigParser()
    rc.read(c['rclone_config'])
    b.require(rc.get(remote.split(':')[0], 'type', fallback='') == 'crypt', 'Remote must be rclone crypt')
    c['remote'] = remote.rstrip('/') + '/' + c['collection_id']
    mail = c['email']
    for key in ('sender', 'recipient'):
        b.require(isinstance(mail[key], str) and re.fullmatch(r'[^\s<>@]+@[^\s<>@]+', mail[key]), 'Invalid email address')
    b.require(mail['host'] and type(mail['port']) is int and mail['port'] in (465, 587), 'TLS SMTP configuration required')
    url = c['readiness_url']
    b.require(re.fullmatch(r'http://(127\.0\.0\.1|localhost):[0-9]+/health/ready', url), 'Use local readiness URL')
    b.require(isinstance(c.get('software_identity'), str) and c['software_identity'].strip(), 'Record compatible software identity')
    return c


def source_inventory(path):
    if path.is_dir():
        return {'kind': 'directory', 'entries': b.inventory(path)}
    b.require(not path.is_symlink() and path.is_file(), 'Source must be a regular file')
    return {'kind': 'file', 'size': path.stat().st_size, 'sha256': b.digest(path)}


def bytes_in(inv):
    return inv['size'] if inv['kind'] == 'file' else sum(v.get('size', 0) for v in inv['entries'].values())


def preflight(c):
    b.rclone(c, 'mkdir', c['remote'])
    b.rclone(c, 'lsf', c['remote'], '--max-depth', '1')
    # Query existence and size without emitting connection settings or SQL.
    selected = ','.join("'" + n + "'" for n in c['databases'])
    rows = b.query(c, 'SELECT SCHEMA_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME IN (' + selected + ');')
    b.require(set(rows) == set(c['databases']), 'One or more selected databases are absent')
    size = b.query(c, 'SELECT COALESCE(SUM(DATA_LENGTH+INDEX_LENGTH),0) FROM information_schema.TABLES '
                   'WHERE TABLE_SCHEMA IN (' + selected + ');')
    source_size = sum(bytes_in(source_inventory(p)) for p in c['sources'].values())
    # Conservative estimate: staging, archive, verification download plus reserve.
    needed = 4 * (source_size + 2 * int(size[0])) + c['reserve_bytes']
    free = shutil.disk_usage(c['backup_root']).free
    b.require(free >= needed, 'Insufficient free space before capture')
    # Verify the application is already healthy before stopping anything.
    readiness(c)
    return {'free_before': free, 'estimated_required': needed}


def readiness(c):
    # No proxies/redirects: only the configured local application can pass.
    class NoRedirect(urllib.request.HTTPRedirectHandler):
        def redirect_request(self, *args, **kwargs):
            return None
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect())
    for _ in range(12):
        try:
            with opener.open(c['readiness_url'], timeout=5) as response:
                if response.status == 200:
                    return
        except Exception:
            pass
        time.sleep(5)
    raise b.BackupError('Application readiness failed after capture')


def capture(c, payload, status):
    capture_started = time.monotonic()
    status['phase'] = 'capture/restart'
    atomic_json(c['backup_root'] / 'run.json', status)
    (payload / 'databases').mkdir()
    (payload / 'sources').mkdir()
    with b.stop_writers(c):
        with b.database_read_lock(c) as locked:
            before = {name: source_inventory(src) for name, src in c['sources'].items()}
            photos = b.photo_paths(c)
            b.check_photos(photos, c['sources'][c['uploads_source']])
            for name, src in c['sources'].items():
                dst = payload / 'sources' / name
                if src.is_dir():
                    shutil.copytree(src, dst)
                else:
                    shutil.copyfile(src, dst)
                b.require(source_inventory(dst) == before[name], 'Copied source differs')
            for name in c['databases']:
                with (payload / 'databases' / (name + '.sql')).open('xb') as out:
                    b.run(c, ['mariadb-dump', '--defaults-extra-file=' + str(c['client_defaults_file']),
                              '--skip-lock-tables', '--routines', '--triggers', '--events', '--hex-blob',
                              '--default-character-set=utf8mb4', '--databases', name], stdout=out)
                b.require((payload / 'databases' / (name + '.sql')).stat().st_size > 0, 'Empty database dump')
            with (payload / 'accounts.sql').open('xb') as out:
                b.run(c, ['mariadb-dump', '--defaults-extra-file=' + str(c['client_defaults_file']),
                          '--skip-lock-tables', '--system=users', 'mysql'], stdout=out)
            b.require((payload / 'accounts.sql').stat().st_size > 0, 'Empty account recovery dump')
            b.require(all(source_inventory(c['sources'][n]) == inv for n, inv in before.items()), 'Source changed during capture')
            b.require(b.photo_paths(c) == photos, 'Photo references changed')
            b.writers_stopped(c)
            locked()
    # Capture errors still pass through stop_writers' restart handler.
    readiness(c)
    status['services'] = 'Previously active units restarted; application ready'
    status['capture_and_restart_seconds'] = round(time.monotonic() - capture_started, 1)
    manifest = {'format': FORMAT, 'collection_id': c['collection_id'], 'snapshot': status['snapshot'],
                'captured_at': status['started_at'], 'databases': c['databases'],
                'photo_database': c['photo_database'], 'uploads_source': c['uploads_source'],
                'required_photos': photos, 'source_paths': {n: str(p) for n, p in c['sources'].items()},
                'software_identity': c['software_identity'], 'inventory': b.inventory(payload)}
    atomic_json(payload / 'manifest.json', manifest)
    return manifest


def validate(archive, c):
    """Check every archive member by streaming; no extra extraction copy required."""
    actual, manifest, total = {}, None, 0
    with tarfile.open(archive, 'r:gz') as tar:
        for member in tar:
            b.safe_path(member.name)
            b.require(member.name not in actual and (member.isfile() or member.isdir()), 'Unsafe or duplicate archive member')
            total += member.size
            b.require(total <= c['max_unpack_bytes'] and len(actual) < 1000000, 'Archive limit exceeded')
            if member.isdir():
                actual[member.name] = {'directory': True}
            else:
                with tar.extractfile(member) as stream:
                    if member.name == 'manifest.json':
                        b.require(member.size <= 16 * 1024**2, 'Oversized manifest')
                        manifest = json.load(stream)
                        actual[member.name] = {}
                    else:
                        h = hashlib.sha256()
                        length = 0
                        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
                            h.update(chunk)
                            length += len(chunk)
                        b.require(length == member.size, 'Truncated payload')
                        actual[member.name] = {'size': length, 'sha256': h.hexdigest()}
    b.require(isinstance(manifest, dict) and manifest.get('format') == FORMAT, 'Unsupported backup format')
    b.require(manifest['collection_id'] == c['collection_id'] and manifest['databases'] == c['databases'], 'Wrong database set or collection')
    b.require(NAME.fullmatch(manifest['snapshot']), 'Invalid snapshot identity')
    actual.pop('manifest.json', None)
    b.require(actual == manifest['inventory'], 'Archive hash/inventory mismatch')
    for name in c['databases']:
        b.require(actual.get('databases/' + name + '.sql', {}).get('size', 0) > 0, 'Missing SQL payload')
    b.require(actual.get('accounts.sql', {}).get('size', 0) > 0, 'Missing account recovery payload')
    for photo in manifest['required_photos']:
        b.safe_path(photo)
        b.require('size' in actual.get('sources/' + manifest['uploads_source'] + '/' + photo, {}), 'Missing required photo')
    return manifest


def ready_record(c, value):
    b.require(isinstance(value, dict) and value.get('format') == FORMAT
              and value.get('collection_id') == c['collection_id']
              and NAME.fullmatch(value.get('snapshot', ''))
              and value.get('archive') == value['snapshot'] + '.tar.gz'
              and re.fullmatch(r'[0-9a-f]{64}', value.get('sha256', ''))
              and value.get('databases') == c['databases'], 'Invalid completion record')
    b.require(datetime.fromisoformat(value['completed_at']).tzinfo is not None, 'Completion time must include timezone')
    return value


def upload(c, archive, temp, status):
    status['phase'] = 'upload/read-back'
    atomic_json(c['backup_root'] / 'run.json', status)
    remote = c['remote'] + '/' + archive.name
    b.rclone(c, 'copyto', str(archive), remote, '--immutable')
    downloaded = temp / 'download.tar.gz'
    b.rclone(c, 'copyto', remote, str(downloaded))
    checksum = b.digest(archive)
    b.require(b.digest(downloaded) == checksum, 'Remote read-back mismatch; local archive retained')
    record = {'format': FORMAT, 'collection_id': c['collection_id'], 'snapshot': status['snapshot'],
              'archive': archive.name, 'sha256': checksum, 'databases': c['databases'],
              'recovery_point': status['started_at'], 'completed_at': now(), 'size_bytes': archive.stat().st_size}
    path = archive.with_name(status['snapshot'] + '.ready.json')
    atomic_json(path, record)
    b.rclone(c, 'copyto', str(path), c['remote'] + '/' + path.name, '--immutable')
    check = temp / 'ready.json'
    b.rclone(c, 'copyto', c['remote'] + '/' + path.name, str(check))
    b.require(check.read_bytes() == path.read_bytes(), 'Completion record read-back mismatch')
    return record


def retention(c, current, temp):
    # Only exact named records in this collection namespace authorize pruning.
    local = []
    for path in c['backup_root'].glob('orchidset-*.ready.json'):
        if path.is_symlink():
            continue
        try:
            record = ready_record(c, json.loads(path.read_text()))
            archive = c['backup_root'] / record['archive']
            b.require(path.name == record['snapshot'] + '.ready.json' and not archive.is_symlink(), 'Invalid local pair')
            if Path(str(archive) + '.keep').exists():
                continue
            b.require(b.digest(archive) == record['sha256'], 'Changed local archive retained')
            local.append((record['snapshot'], path, archive))
        except Exception:
            continue
    local.sort(key=lambda x: (x[0] == current['snapshot'], x[0]), reverse=True)
    for _, path, archive in local[c['keep_local']:]:
        path.unlink()
        archive.unlink()
    files = b.rclone(c, 'lsf', c['remote'], '--files-only', '--max-depth', '1').decode().splitlines()
    remote_records = []
    for name in files:
        if not name.endswith('.ready.json') or not NAME.fullmatch(name[:-11]):
            continue
        target = temp / 'retention-ready.json'
        b.rclone(c, 'copyto', c['remote'] + '/' + name, str(target))
        b.require(target.stat().st_size <= 65536, 'Oversized remote record')
        record = ready_record(c, json.loads(target.read_text()))
        b.require(name == record['snapshot'] + '.ready.json' and record['archive'] in files, 'Incomplete remote pair')
        remote_records.append(record)
    b.require(any(r['snapshot'] == current['snapshot'] for r in remote_records), 'Current completed backup absent; pruning refused')
    remote_records.sort(key=lambda r: (r['snapshot'] == current['snapshot'], r['snapshot']), reverse=True)
    for record in remote_records[c['keep_remote']:]:
        # Remove discovery record first; a failed archive deletion only leaves an orphan.
        b.rclone(c, 'deletefile', c['remote'] + '/' + record['snapshot'] + '.ready.json')
        b.rclone(c, 'deletefile', c['remote'] + '/' + record['archive'])


def queue_email(c, subject, body):
    outbox = c['backup_root'] / 'outbox'
    outbox.mkdir(mode=0o700, exist_ok=True)
    path = outbox / (uuid.uuid4().hex + '.json')
    atomic_json(path, {'id': make_msgid(), 'subject': subject, 'body': body, 'attempts': 0})


def flush_email(c):
    outbox = c['backup_root'] / 'outbox'
    outbox.mkdir(mode=0o700, exist_ok=True)
    try:
        with b.operation_lock(outbox):
            return _flush_email(c)
    except b.BackupError:
        b.log(c, 'Email outbox busy or stale lock; delivery deferred')
        return False


def _flush_email(c):
    failures = 0
    outbox = c['backup_root'] / 'outbox'
    outbox.mkdir(mode=0o700, exist_ok=True)
    for path in sorted(outbox.glob('*.json')):
        item = json.loads(path.read_text())
        if item['attempts'] >= 12:
            failures += 1
            continue
        item['attempts'] += 1
        atomic_json(path, item)
        try:
            mail = c['email']
            msg = EmailMessage()
            msg['From'], msg['To'] = mail['sender'], mail['recipient']
            msg['Subject'], msg['Message-ID'], msg['Date'] = item['subject'], item['id'], formatdate(localtime=False)
            msg.set_content(item['body'])
            password = c['smtp_password_file'].read_text().rstrip('\r\n')
            context = ssl.create_default_context()
            if mail['port'] == 465:
                smtp = smtplib.SMTP_SSL(mail['host'], 465, timeout=30, context=context)
            else:
                smtp = smtplib.SMTP(mail['host'], 587, timeout=30)
            with smtp:
                smtp.ehlo()
                if mail['port'] == 587:
                    smtp.starttls(context=context)
                    smtp.ehlo()
                smtp.login(mail['sender'], password)
                refused = smtp.send_message(msg)
                b.require(not refused, 'Recipient refused')
            path.unlink()
        except Exception:
            failures += 1
            b.log(c, 'Email delivery failed; private outbox retained (maximum 12 attempts)')
    return failures == 0


def report(c, status):
    last = c['backup_root'] / 'last-success.json'
    previous = json.loads(last.read_text()) if last.exists() else None
    summary = {**status, 'last_verified_cloud_backup': previous,
               'free_bytes': shutil.disk_usage(c['backup_root']).free}
    queue_email(c, '[Pi 1 backup] ' + status['result'], json.dumps(summary, indent=2))


def run_backup(c):
    status = {'started_at': now(), 'snapshot': 'orchidset-' + datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')
              + '-' + uuid.uuid4().hex, 'phase': 'preflight', 'services': 'Not changed', 'result': 'FAILED'}
    atomic_json(c['backup_root'] / 'run.json', status)
    stop_sampling = threading.Event()
    minimum_free = [shutil.disk_usage(c['backup_root']).free]
    started = time.monotonic()
    def sample():
        while not stop_sampling.wait(0.5):
            minimum_free[0] = min(minimum_free[0], shutil.disk_usage(c['backup_root']).free)
    sampler = threading.Thread(target=sample, daemon=True)
    sampler.start()
    try:
        status.update(preflight(c))
        with tempfile.TemporaryDirectory(dir=c['backup_root'], prefix='.nightly-') as folder:
            temp = Path(folder)
            payload = temp / 'payload'
            payload.mkdir()
            capture(c, payload, status)
            status['phase'] = 'compression/validation'
            atomic_json(c['backup_root'] / 'run.json', status)
            partial = temp / 'partial.tar.gz'
            with tarfile.open(partial, 'w:gz', dereference=False) as tar:
                for child in sorted(payload.iterdir()):
                    tar.add(child, arcname=child.name)
            validate(partial, c)
            archive = c['backup_root'] / (status['snapshot'] + '.tar.gz')
            partial.rename(archive)
            record = upload(c, archive, temp, status)
            # Verified recovery point survives subsequent pruning/reporting failures.
            atomic_json(c['backup_root'] / 'last-success.json', record)
            status['phase'] = 'retention'
            retention(c, record, temp)
        status.update(result='SUCCESS', phase='complete')
    except Exception as ex:
        status['error'] = str(ex) if isinstance(ex, b.BackupError) else 'Operation failed; inspect private local diagnostics'
        if status['phase'] == 'capture/restart':
            status['services'] = 'Restart attempted; inspect service states and readiness'
    finally:
        stop_sampling.set()
        sampler.join(timeout=2)
    status['minimum_free_bytes_sampled'] = minimum_free[0]
    status['duration_seconds'] = round(time.monotonic() - started, 1)
    status['finished_at'] = now()
    atomic_json(c['backup_root'] / 'run.json', status)
    report(c, status)
    delivered = flush_email(c)
    return 0 if status['result'] == 'SUCCESS' and delivered else (2 if status['result'] == 'SUCCESS' else 1)


def monitor(c):
    success = c['backup_root'] / 'last-success.json'
    record = json.loads(success.read_text()) if success.exists() else None
    age = ((datetime.now(timezone.utc) - datetime.fromisoformat(record['recovery_point'])).total_seconds()
           if record else float('inf'))
    alert = c['backup_root'] / 'overdue-alert.json'
    overdue = age > c['max_age_hours'] * 3600 or age < 0
    previous = json.loads(alert.read_text()) if alert.exists() else {}
    if overdue and (not previous or (datetime.now(timezone.utc) - datetime.fromisoformat(previous['sent_to_outbox'])).total_seconds() >= 86400):
        queue_email(c, '[Pi 1 backup] OVERDUE', json.dumps({'last_verified_backup': record,
                    'maximum_age_hours': c['max_age_hours'], 'checked_at': now()}, indent=2))
        atomic_json(alert, {'sent_to_outbox': now()})
    elif not overdue:
        alert.unlink(missing_ok=True)
    return 0 if flush_email(c) and not overdue else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('operation', choices=('backup', 'check', 'email-test', 'monitor', 'retry-email', 'verify'))
    parser.add_argument('--config', required=True)
    parser.add_argument('--archive')
    args = parser.parse_args()
    os.umask(0o077)
    def interrupted(*_):
        raise b.BackupError('Operation interrupted; inspect writer states')
    signal.signal(signal.SIGTERM, interrupted)
    signal.signal(signal.SIGINT, interrupted)
    c = None
    try:
        b.require(sys.platform.startswith('linux'), 'Production command requires Linux')
        c = load_config(args.config)
        lock_root = c['backup_root']
        if args.operation in ('monitor', 'retry-email', 'email-test'):
            # Monitoring must still run if a backup is stuck or its lock is stale.
            lock_root = c['backup_root'] / 'monitor'
            lock_root.mkdir(mode=0o700, exist_ok=True)
        with b.operation_lock(lock_root):
            if args.operation == 'backup':
                return run_backup(c)
            if args.operation == 'check':
                print(json.dumps(preflight(c), indent=2))
            elif args.operation == 'email-test':
                queue_email(c, '[Pi 1 backup] Email delivery test', 'Backup email delivery test only; no backup has run.')
                return 0 if flush_email(c) else 2
            elif args.operation == 'monitor':
                return monitor(c)
            elif args.operation == 'retry-email':
                return 0 if flush_email(c) else 2
            else:
                b.require(args.archive, '--archive required')
                validate(b.absolute(args.archive), c)
                print('Backup archive verified')
        return 0
    except Exception as ex:
        print('ERROR: ' + (str(ex) if isinstance(ex, b.BackupError) else 'Operation failed; inspect private configuration/diagnostics'), file=sys.stderr)
        if c and args.operation == 'backup':
            try:
                report(c, {'result': 'FAILED', 'phase': 'startup/reporting', 'checked_at': now(),
                           'error': 'Operation could not start or finish reporting; inspect local logs and locks'})
                flush_email(c)
            except Exception:
                print('ERROR: Email could not be queued or delivered; inspect local state', file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
