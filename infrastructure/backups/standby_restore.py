"""Block 2 phase 1: discover, validate and privately stage a candidate.

PREPARED is not RESTORED or ACCEPTED. This command never imports SQL, activates
settings, starts services, sends restore-success email or writes to cloud storage.
"""
import argparse
import configparser
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
import threading
import uuid

import nightly_backup as n
import orchid_backup as b

STATE_FORMAT = 'orchidapp-standby-prepare-v1'


def private_directory(path):
    path = b.absolute(str(path))
    path.mkdir(mode=0o700, parents=True, exist_ok=True)
    if os.name == 'posix':
        info = path.stat()
        b.require(info.st_uid in (0, os.geteuid()) and not info.st_mode & 0o077,
                  'State directories must be owned by root/operator and mode 700')
    return path


def load_config(filename):
    filename = b.absolute(filename)
    b.protected_file(filename)
    c = json.loads(filename.read_text())
    b.require(isinstance(c, dict), 'Configuration must be an object')
    c['collection_id'] = str(uuid.UUID(c['collection_id']))
    names = c['databases']
    b.require(isinstance(names, list) and names and all(isinstance(v, str) for v in names)
              and len(set(names)) == len(names) and all(re.fullmatch(r'[A-Za-z][A-Za-z0-9_]*', v)
              and v.lower() not in ('mysql', 'sys', 'information_schema', 'performance_schema') for v in names),
              'Explicit unique application databases required')
    b.require(c['photo_database'] in names and re.fullmatch(r'[a-z][a-z0-9_-]*', c['uploads_source']),
              'Explicit photo database/uploads source required')
    c['rclone_config'] = b.absolute(c['rclone_config'])
    b.protected_file(c['rclone_config'])
    remote = c['remote']
    b.require(re.fullmatch(r'[A-Za-z0-9_-]+:[A-Za-z0-9_-][A-Za-z0-9_./-]*', remote)
              and not {'.', '..'} & set(remote.split(':', 1)[1].split('/')), 'Use a dedicated named crypt remote')
    parser = configparser.RawConfigParser()
    parser.read(c['rclone_config'])
    b.require(parser.get(remote.split(':')[0], 'type', fallback='') == 'crypt', 'Configured remote must be crypt')
    c['remote'] = remote.rstrip('/') + '/' + c['collection_id']
    root = b.absolute(c['state_root'])
    b.require(root.parent != root and len(root.parts) >= 3 and not b.overlaps(root, filename)
              and not b.overlaps(root, c['rclone_config']), 'State root must be separate from protected configuration')
    c['state_root'] = private_directory(root)
    c['backup_root'] = root  # Shared tool runner stores private diagnostics here.
    for key, default in (('timeout_seconds', 1800), ('reserve_bytes', 1024**3),
                         ('max_archive_bytes', 5 * 1024**3), ('max_unpack_bytes', 20 * 1024**3),
                         ('max_record_bytes', 65536), ('max_listing_bytes', 1024**2),
                         ('max_ready_records', 1000), ('max_age_hours', 30), ('max_generations', 3)):
        c[key] = c.get(key, default)
        b.require(type(c[key]) is int and c[key] >= 1, 'Invalid positive setting: ' + key)
    return c


def command(c, operation, name=None, count=None):
    """Closed cloud-read interface: cannot construct upload, sync or deletion argv."""
    args = ['rclone', '--config', str(c['rclone_config'])]
    if operation == 'list':
        b.require(name is None and count is None, 'Invalid listing request')
        return args + ['lsf', c['remote'], '--files-only', '--max-depth', '1',
                       '--include', '/orchidset-*.ready.json']
    b.require(operation == 'read' and isinstance(name, str)
              and (name.endswith('.ready.json') and n.NAME.fullmatch(name[:-11])
                   or name.endswith('.tar.gz') and n.NAME.fullmatch(name[:-7])), 'Invalid exact cloud object')
    b.require(type(count) is int and count > 0, 'Bounded cloud reads required')
    return args + ['cat', c['remote'] + '/' + name, '--count', str(count)]


def bounded_output(c, args, limit):
    """Bound stdout in memory and kill oversized/hung tools; never expose stderr."""
    chunks, size, too_large = [], [0], [False]
    with tempfile.TemporaryFile() as errors:
        p = subprocess.Popen(args, stdout=subprocess.PIPE, stderr=errors)
        def read():
            while True:
                chunk = p.stdout.read(65536)
                if not chunk:
                    return
                size[0] += len(chunk)
                if size[0] > limit:
                    too_large[0] = True
                    p.kill()
                    return
                chunks.append(chunk)
        worker = threading.Thread(target=read, daemon=True)
        worker.start()
        try:
            try:
                p.wait(timeout=c['timeout_seconds'])
            except subprocess.TimeoutExpired:
                raise b.BackupError('Cloud read timed out')
            worker.join(timeout=5)
            b.require(not worker.is_alive() and not too_large[0], 'Cloud response exceeds configured limit')
            b.require(p.returncode == 0, 'Cloud read failed; no candidate accepted')
            return b''.join(chunks)
        finally:
            if p.poll() is None:
                p.kill()
            p.wait(timeout=10)
            worker.join(timeout=5)
            p.stdout.close()


def timestamp(value):
    b.require(isinstance(value, str), 'Missing timestamp')
    result = datetime.fromisoformat(value)
    b.require(result.tzinfo is not None, 'Timestamps must include timezone')
    return result.astimezone(timezone.utc)


def check_record(c, record, filename=None, clock=None, freshness=True):
    n.ready_record(c, record)
    b.require(type(record.get('size_bytes')) is int and 0 < record['size_bytes'] <= c['max_archive_bytes'],
              'Invalid or oversized declared archive')
    if filename is not None:
        b.require(filename == record['snapshot'] + '.ready.json', 'Record/object identity mismatch')
    recovery = timestamp(record['recovery_point'])
    completed = timestamp(record['completed_at'])
    clock = clock or datetime.now(timezone.utc)
    b.require(recovery <= completed <= clock, 'Future or inconsistent completion times')
    stamp = recovery.strftime('%Y%m%dT%H%M%SZ')
    b.require(record['snapshot'].split('-')[1] == stamp, 'Snapshot/recovery time mismatch')
    if freshness:
        b.require((clock - recovery).total_seconds() <= c['max_age_hours'] * 3600, 'Backup recovery point is overdue')
    return record


def read_record(c, name):
    raw = bounded_output(c, command(c, 'read', name, c['max_record_bytes'] + 1), c['max_record_bytes'])
    return check_record(c, json.loads(raw), name)


def select_record(c, records, accepted=None):
    b.require(records, 'No completed backup records found')
    # Validate all before choosing; a bad newer record cannot cause an old fallback.
    validated = [check_record(c, r, freshness=False) for r in records]
    validated.sort(key=lambda r: (timestamp(r['recovery_point']), r['snapshot']), reverse=True)
    latest = check_record(c, validated[0])
    if accepted is not None:
        accepted = check_record(c, accepted, freshness=False)
        if latest['snapshot'] == accepted['snapshot']:
            b.require(latest == accepted, 'Accepted snapshot identity was rewritten')
            return None
        b.require(timestamp(latest['recovery_point']) > timestamp(accepted['recovery_point']),
                  'Cloud contains no recovery point newer than accepted state; rollback refused')
    return latest


def discover(c):
    raw = bounded_output(c, command(c, 'list'), c['max_listing_bytes'])
    names = raw.decode('utf-8').splitlines()
    b.require(len(names) <= c['max_ready_records'] and len(names) == len(set(names)), 'Too many or duplicate completion records')
    records = []
    for name in names:
        b.require(name.endswith('.ready.json') and n.NAME.fullmatch(name[:-11]), 'Unexpected discovery filename')
        # Older records may be stale; freshness applies to the latest selection only.
        raw_record = bounded_output(c, command(c, 'read', name, c['max_record_bytes'] + 1), c['max_record_bytes'])
        records.append(check_record(c, json.loads(raw_record), name, freshness=False))
    accepted_path = c['state_root'] / 'last-accepted.json'
    accepted = None
    if accepted_path.exists():
        b.protected_file(accepted_path)
        accepted = json.loads(accepted_path.read_text())['record']
    return select_record(c, records, accepted)


def check_manifest(c, archive, record):
    manifest = n.validate(archive, c)
    b.require(manifest['snapshot'] == record['snapshot'], 'Archive snapshot differs from completion record')
    b.require(timestamp(manifest['captured_at']) == timestamp(record['recovery_point']), 'Archive recovery point differs')
    b.require(manifest['photo_database'] == c['photo_database'] and manifest['uploads_source'] == c['uploads_source'],
              'Wrong photo database or uploads source')
    b.require(isinstance(manifest['source_paths'], dict) and c['uploads_source'] in manifest['source_paths'], 'Missing source metadata')
    for name in manifest['source_paths']:
        b.require(re.fullmatch(r'[a-z][a-z0-9_-]*', name) and 'sources/' + name in manifest['inventory'], 'Invalid or missing source')
    for name in manifest['inventory']:
        b.require(name == 'accounts.sql' or name.split('/')[0] in ('databases', 'sources'), 'Unexpected payload root')
    expected_sql = {'databases/' + name + '.sql' for name in c['databases']}
    b.require({name for name in manifest['inventory'] if name.startswith('databases/')} == expected_sql, 'Unexpected database payload')
    b.require(isinstance(manifest.get('software_identity'), str) and manifest['software_identity'].strip(), 'Missing software identity')
    return manifest


def extract_private(archive, payload, manifest):
    b.require(not payload.exists() and payload.parent.is_dir(), 'Use an absent staging destination')
    payload.mkdir(mode=0o700)
    with tarfile.open(archive, 'r:gz') as tar:
        for member in tar:
            b.safe_path(member.name)
            b.require(member.isfile() or member.isdir(), 'Unsafe extraction entry')
            if member.name == 'manifest.json':
                b.require(member.isfile() and 0 <= member.size <= 16 * 1024**2, 'Invalid manifest during extraction')
            else:
                expected = manifest['inventory'].get(member.name)
                b.require(expected is not None, 'Unexpected member during extraction')
                b.require((member.isdir() and expected == {'directory': True}) or
                          (member.isfile() and expected.get('size') == member.size),
                          'Archive member changed before extraction')
            target = payload.joinpath(*member.name.split('/'))
            if member.isdir():
                target.mkdir(mode=0o700, parents=True, exist_ok=True)
            else:
                target.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
                fd = os.open(target, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
                with os.fdopen(fd, 'wb') as out, tar.extractfile(member) as src:
                    shutil.copyfileobj(src, out)
    actual = b.inventory(payload)
    del actual['manifest.json']
    b.require(actual == manifest['inventory'], 'Staged payload differs from verified archive')


def download(c, record, destination):
    b.require(not destination.exists(), 'Download destination already exists')
    fd = os.open(destination, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, 'wb') as out:
        b.run(c, command(c, 'read', record['archive'], record['size_bytes'] + 1), stdout=out)
        out.flush()
        os.fsync(out.fileno())
    b.require(destination.stat().st_size == record['size_bytes'], 'Downloaded archive length mismatch')
    b.require(b.digest(destination) == record['sha256'], 'Downloaded archive SHA-256 mismatch')


def prepare(c):
    record = discover(c)
    if record is None:
        return {'result': 'NO_NEW_BACKUP', 'accepted_state_unchanged': True}
    generations = private_directory(c['state_root'] / 'generations')
    generation = generations / record['snapshot']
    b.require(not generation.exists(), 'Generation already exists; inspect its durable state before reuse')
    b.require(len(list(generations.iterdir())) < c['max_generations'], 'Generation capacity reached; preserve inputs and review cleanup')
    free = shutil.disk_usage(c['state_root']).free
    b.require(free >= record['size_bytes'] + c['reserve_bytes'], 'Insufficient space before download')
    generation.mkdir(mode=0o700)
    state = {'format': STATE_FORMAT, 'owner_token': uuid.uuid4().hex, 'record': record,
             'phase': 'DOWNLOADING', 'started_at': n.now(), 'accepted': False}
    state_file = generation / 'state.json'
    n.atomic_json(state_file, state)
    n.atomic_json(generation / 'ready.json', record)
    archive = generation / record['archive']
    try:
        download(c, record, archive)
        state['phase'] = 'VALIDATING'
        n.atomic_json(state_file, state)
        manifest = check_manifest(c, archive, record)
        unpack_size = sum(entry.get('size', 0) for entry in manifest['inventory'].values())
        b.require(shutil.disk_usage(c['state_root']).free >= unpack_size + c['reserve_bytes'], 'Insufficient space before extraction')
        checksum = b.digest(archive)
        state['phase'] = 'EXTRACTING'
        n.atomic_json(state_file, state)
        extract_private(archive, generation / 'payload', manifest)
        b.require(b.digest(archive) == checksum == record['sha256'], 'Archive changed during staging')
        b.check_photos(manifest['required_photos'], generation / 'payload/sources' / c['uploads_source'])
        state.update(phase='PREPARED_RESTORE_PENDING', prepared_at=n.now(),
                     software_identity=manifest['software_identity'],
                     note='No database imported; settings inert; application/restore acceptance pending')
        n.atomic_json(state_file, state)
        n.atomic_json(c['state_root'] / 'last-prepared.json', state)
        return {'result': 'PREPARED_RESTORE_PENDING', 'snapshot': record['snapshot'],
                'generation': str(generation), 'accepted_state_unchanged': True}
    except Exception as ex:
        state.update(phase='FAILED', failed_at=n.now(),
                     error=str(ex) if isinstance(ex, b.BackupError) else 'Preparation failed; inspect private diagnostics')
        n.atomic_json(state_file, state)
        raise


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('operation', choices=('discover', 'prepare'))
    parser.add_argument('--config', required=True)
    args = parser.parse_args()
    os.umask(0o077)
    try:
        b.require(sys.platform.startswith('linux'), 'Production entry point requires Linux')
        c = load_config(args.config)
        with b.operation_lock(c['state_root']):
            result = discover(c) if args.operation == 'discover' else prepare(c)
            print(json.dumps(result, indent=2))
        return 0
    except Exception as ex:
        print('ERROR: ' + (str(ex) if isinstance(ex, b.BackupError) else 'Preparation failed; inspect private configuration/state'), file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
