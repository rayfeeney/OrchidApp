"""Linux paired snapshots. See the maintained Linux backup/restore runbook."""
import argparse
from contextlib import contextmanager
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import queue
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
import threading
import uuid


class BackupError(RuntimeError):
    pass


def require(ok, message):
    if not ok:
        raise BackupError(message)


def safe_path(value):
    require(isinstance(value, str) and value and '\\' not in value and '\x00' not in value,
            'Invalid archive-relative path')
    path = PurePosixPath(value)
    require(not path.is_absolute() and all(p not in ('', '.', '..') for p in value.split('/'))
            and ':' not in value, 'Unsafe archive-relative path')
    return path


def absolute(value):
    path = Path(value)
    require(path.is_absolute(), 'Configuration paths must be absolute')
    for part in (path, *path.parents):
        require(not part.is_symlink(), 'Symlink paths are not supported')
    return path.resolve()


def overlaps(a, b):
    return a == b or a in b.parents or b in a.parents


def protected_file(path):
    require(path.is_file(), 'Required protected configuration file is missing')
    if os.name == 'posix':
        info = path.stat()
        require(info.st_uid in (0, os.geteuid()) and not info.st_mode & 0o077,
                'Configuration files must be owned by root/operator and mode 600 or stricter')


def load_config(filename, mode):
    path = absolute(filename)
    protected_file(path)
    c = json.loads(path.read_text(encoding='utf-8'))
    require(isinstance(c, dict), 'Configuration must be a JSON object')
    require(re.fullmatch(r'[A-Za-z][A-Za-z0-9_]*', c.get('database', '')),
            'Database must be a simple explicit identifier')
    c['collection_id'] = str(uuid.UUID(c['collection_id']))
    for name in ('backup_root', 'log_file', 'client_defaults_file'):
        c[name] = absolute(c[name])
    protected_file(c['client_defaults_file'])
    require(isinstance(c.get('writer_units'), list) and c['writer_units'] and
            all(isinstance(u, str) and re.fullmatch(r'[A-Za-z0-9_.@:-]+\.(service|timer)', u)
                for u in c['writer_units']), 'List every application writer service/timer explicitly')
    for key, default in (('keep_local', 14), ('timeout_seconds', 600), ('max_unpack_bytes', 20 * 1024**3)):
        c[key] = c.get(key, default)
        require(type(c[key]) is int and c[key] >= 1, key + ' must be a positive integer')
    if mode == 'backup':
        for name in ('uploads_root', 'configuration_root', 'rclone_config'):
            c[name] = absolute(c[name])
        protected_file(c['rclone_config'])
        for name in ('uploads_root', 'configuration_root'):
            require(c[name].is_dir(), name + ' must exist')
            require(not overlaps(c[name], c['backup_root']), 'Backup/source paths must not overlap')
            require(not overlaps(c[name], c['log_file']), 'Log/source paths must not overlap')
        require(not overlaps(c['uploads_root'], c['configuration_root']), 'Source trees must be separate')
        remote = c.get('remote', '')
        require(isinstance(remote, str) and re.fullmatch(r'[A-Za-z0-9_-]+:[A-Za-z0-9_-][A-Za-z0-9_./-]*', remote)
                and not {'.', '..'} & set(remote.split(':', 1)[1].split('/')), 'Use a named remote and dedicated directory')
    c['backup_root'].mkdir(mode=0o700, parents=True, exist_ok=True)
    c['log_file'].parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    require(not c['log_file'].is_symlink(), 'Log must not be a symlink')
    with c['log_file'].open('a', encoding='utf-8'):
        pass
    protected_file(c['log_file'])
    if os.name == 'posix':
        info = c['backup_root'].stat()
        require(info.st_uid in (0, os.geteuid()) and not info.st_mode & 0o077,
                'Backup directory must be owned by root/operator and mode 700')
    return c


def log(c, message):
    line = datetime.now(timezone.utc).isoformat() + ' | ' + message
    with c['log_file'].open('a', encoding='utf-8') as f:
        f.write(line + '\n')
    print(line, flush=True)


@contextmanager
def operation_lock(root):
    lock = root / '.paired-operation.lock'
    try:
        lock.mkdir(mode=0o700)
    except FileExistsError:
        raise BackupError('Another operation or a stale lock exists; inspect .paired-operation.lock')
    try:
        (lock / 'owner.json').write_text(json.dumps({'pid': os.getpid()}))
        yield
    finally:
        (lock / 'owner.json').unlink()
        lock.rmdir()


def run(c, args, *, stdin=None, stdout=None):
    # External error text can contain SQL/configuration secrets. Log tool/exit only.
    try:
        result = subprocess.run([str(x) for x in args], input=stdin, stdout=stdout or subprocess.PIPE,
                                stderr=subprocess.PIPE, timeout=c['timeout_seconds'], check=False)
    except (OSError, subprocess.TimeoutExpired) as ex:
        raise BackupError('Tool unavailable or timed out: ' + Path(str(args[0])).name) from ex
    if result.returncode != 0:
        diagnostic = c['backup_root'] / ('.tool-error-' + uuid.uuid4().hex + '.log')
        with diagnostic.open('xb') as f:
            f.write(result.stderr)
        diagnostic.chmod(0o600)
        raise BackupError('Tool failed: ' + Path(str(args[0])).name + '; exit=' + str(result.returncode)
                          + '; private diagnostic: ' + diagnostic.name)
    return result.stdout


def client(c):
    # This option must be first. Passwords never enter argv.
    return ['mariadb', '--defaults-extra-file=' + str(c['client_defaults_file']),
            '--batch', '--skip-column-names', '--unbuffered', '--default-character-set=utf8mb4']


def query(c, sql):
    return run(c, client(c) + [c['database']], stdin=sql.encode('utf-8')).decode('utf-8').splitlines()


def writers_stopped(c):
    for unit in c['writer_units']:
        values = run(c, ['systemctl', 'show', unit, '--property=LoadState,ActiveState,SubState']).decode().splitlines()
        state = dict(line.split('=', 1) for line in values if '=' in line)
        require(state.get('LoadState') == 'loaded' and state.get('ActiveState') == 'inactive'
                and state.get('SubState') == 'dead', 'Writer unit must be loaded and stopped: ' + unit)


@contextmanager
def stop_writers(c):
    active = []
    for unit in c['writer_units']:
        values = run(c, ['systemctl', 'show', unit, '--property=LoadState,ActiveState']).decode().splitlines()
        state = dict(line.split('=', 1) for line in values if '=' in line)
        require(state.get('LoadState') == 'loaded' and state.get('ActiveState') in ('active', 'inactive'),
                'Writer must be loaded and stable before scheduled backup: ' + unit)
        if state['ActiveState'] == 'active':
            active.append(unit)
    try:
        # Stop timers before services so they cannot launch new writers during capture.
        for unit in sorted(active, key=lambda u: not u.endswith('.timer')):
            run(c, ['systemctl', 'stop', unit])
        writers_stopped(c)
        yield
    finally:
        failures = []
        for unit in sorted(active, key=lambda u: u.endswith('.timer')):
            try:
                run(c, ['systemctl', 'start', unit])
            except Exception:
                failures.append(unit)
        require(not failures, 'Writer restart failed; inspect configured units: ' + ', '.join(failures))


@contextmanager
def database_read_lock(c):
    # One persistent connection holds the global database read lock through capture.
    with tempfile.TemporaryFile() as errors:
        p = subprocess.Popen(client(c), stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=errors)
        lines = queue.Queue()
        def read():
            for line in p.stdout:
                lines.put(line.strip())
            lines.put(None)
        worker = threading.Thread(target=read, daemon=True)
        worker.start()
        try:
            p.stdin.write(b"FLUSH TABLES WITH READ LOCK; SELECT 'orchidapp-lock-held';\n")
            p.stdin.flush()
            try:
                marker = lines.get(timeout=c['timeout_seconds'])
            except queue.Empty:
                raise BackupError('Timed out acquiring database read lock')
            require(marker == b'orchidapp-lock-held' and p.poll() is None, 'Database read lock failed')
            yield lambda: require(p.poll() is None, 'Database read lock connection was lost')
        finally:
            if p.poll() is None:
                p.terminate()
            try:
                p.wait(timeout=10)
            except subprocess.TimeoutExpired:
                p.kill()
                p.wait()
            p.stdin.close()
            worker.join(timeout=10)
            p.stdout.close()


def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()


def inventory(root):
    result = {}
    for p in sorted(root.rglob('*')):
        require(not p.is_symlink(), 'Source/payload symlinks are not supported')
        name = p.relative_to(root).as_posix()
        safe_path(name)
        if p.is_dir():
            result[name] = {'directory': True}
        else:
            require(p.is_file(), 'Special files are not supported')
            before = p.stat()
            checksum = digest(p)
            after = p.stat()
            require((before.st_size, before.st_mtime_ns, before.st_ino) ==
                    (after.st_size, after.st_mtime_ns, after.st_ino), 'File changed during capture')
            result[name] = {'size': before.st_size, 'sha256': checksum}
    return result


def photo_paths(c):
    sql = """SELECT CONCAT('plants/',plantId,'/',fileName) FROM plantphoto WHERE isActive=1
UNION SELECT CONCAT('plants/',plantId,'/',thumbnailFileName) FROM plantphoto WHERE isActive=1 AND thumbnailFileName IS NOT NULL AND thumbnailFileName<>''
UNION SELECT CONCAT('taxa/',taxonId,'/',fileName) FROM taxonphoto WHERE isActive=1
UNION SELECT CONCAT('taxa/',taxonId,'/',thumbnailFileName) FROM taxonphoto WHERE isActive=1 AND thumbnailFileName IS NOT NULL AND thumbnailFileName<>'';"""
    paths = sorted(set(query(c, sql)))
    for p in paths:
        safe_path(p)
    return paths


def check_photos(paths, root):
    for name in paths:
        safe_path(name)
        p = root.joinpath(*PurePosixPath(name).parts)
        require(p.is_file() and not p.is_symlink(), 'A referenced active photo/thumbnail is missing')


def validate_archive(archive, destination, limit):
    require(not any(destination.iterdir()), 'Validation directory must be empty')
    with tarfile.open(archive, 'r:gz') as tar:
        members = []
        names = set()
        total = 0
        for m in tar:
            safe_path(m.name)
            require(m.name not in names and (m.isfile() or m.isdir()), 'Duplicate/link/special archive entry')
            names.add(m.name)
            require(m.size >= 0 and (m.name != 'manifest.json' or m.size <= 16 * 1024**2),
                    'Invalid/oversized archive metadata')
            total += m.size
            require(total <= limit and len(names) <= 1000000, 'Archive exceeds configured extraction limit')
            require(m.name == 'manifest.json' or m.name == 'database.sql' or
                    m.name.split('/')[0] in ('uploads', 'configuration'), 'Unknown payload entry')
            members.append(m)
        require({'manifest.json', 'database.sql', 'uploads', 'configuration'} <= names, 'Incomplete paired archive')
        for m in sorted(members, key=lambda x: (len(PurePosixPath(x.name).parts), x.name)):
            target = destination.joinpath(*PurePosixPath(m.name).parts)
            if m.isdir():
                target.mkdir(mode=0o700, parents=True, exist_ok=False)
            else:
                target.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
                with tar.extractfile(m) as src, target.open('xb') as out:
                    shutil.copyfileobj(src, out)
                target.chmod(0o600)
    manifest = json.loads((destination / 'manifest.json').read_text(encoding='utf-8'))
    require(manifest.get('format') == 'orchidapp-linux-pair-v1', 'Unsupported paired format')
    uuid.UUID(manifest['collection_id'])
    require(isinstance(manifest.get('required_photos'), list), 'Missing photo reference inventory')
    actual = inventory(destination)
    del actual['manifest.json']
    require(actual == manifest.get('inventory'), 'Payload inventory/hash mismatch')
    require((destination / 'database.sql').stat().st_size > 0, 'Empty SQL dump')
    check_photos(manifest['required_photos'], destination / 'uploads')
    return manifest


def rclone(c, *args):
    return run(c, ['rclone', '--config', c['rclone_config'], *args])


def remote_preflight(c):
    name = c['remote'].split(':', 1)[0] + ':'
    require(name in rclone(c, 'listremotes').decode().splitlines(), 'Configured rclone remote is absent')
    rclone(c, 'lsf', c['remote'], '--max-depth', '1')


def prune_local(c, current):
    candidates = []
    for p in c['backup_root'].glob('orchidpair-*.tar.gz'):
        if not re.fullmatch(r'orchidpair-[0-9]{8}T[0-9]{6}Z-[0-9a-f]{32}\.tar\.gz', p.name):
            continue
        if p.is_symlink() or os.path.lexists(str(p) + '.keep'):
            continue
        try:
            before = digest(p)
            with tempfile.TemporaryDirectory(dir=c['backup_root'], prefix='.retention-') as folder:
                m = validate_archive(p, Path(folder), c['max_unpack_bytes'])
            if m['collection_id'] == c['collection_id']:
                candidates.append((p, before))
        except Exception:
            log(c, 'WARNING: Unrecognised/unreadable archive retained')
    candidates = [x for x in candidates if x[0] == current] + sorted(
        [x for x in candidates if x[0] != current], key=lambda x: x[0].name, reverse=True)
    for p, checksum in candidates[c['keep_local']:]:
        if not p.is_symlink() and not os.path.lexists(str(p) + '.keep') and digest(p) == checksum:
            p.unlink()


def backup(c, acknowledged):
    require(acknowledged, 'Confirm all writers stopped with --writers-stopped')
    writers_stopped(c)
    remote_preflight(c)
    snapshot = 'orchidpair-' + datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ') + '-' + uuid.uuid4().hex
    archive = c['backup_root'] / (snapshot + '.tar.gz')
    with tempfile.TemporaryDirectory(dir=c['backup_root'], prefix='.capture-') as temp:
        payload = Path(temp) / 'payload'
        payload.mkdir(mode=0o700)
        with database_read_lock(c) as locked:
            photos = photo_paths(c)
            check_photos(photos, c['uploads_root'])
            before = {k: inventory(c[k]) for k in ('uploads_root', 'configuration_root')}
            for source, target in (('uploads_root', 'uploads'), ('configuration_root', 'configuration')):
                shutil.copytree(c[source], payload / target)
                require(inventory(payload / target) == before[source], 'Copied files differ from source')
            with (payload / 'database.sql').open('xb') as sql:
                run(c, ['mariadb-dump', '--defaults-extra-file=' + str(c['client_defaults_file']),
                        '--skip-lock-tables', '--routines', '--triggers', '--events', '--hex-blob',
                        '--default-character-set=utf8mb4', c['database']], stdout=sql)
            require((payload / 'database.sql').stat().st_size > 0, 'Empty SQL dump')
            for key, expected in before.items():
                require(inventory(c[key]) == expected, 'Source changed during capture; no completed snapshot')
            require(photo_paths(c) == photos, 'Photo references changed during capture')
            writers_stopped(c)
            locked()
        manifest = {'format': 'orchidapp-linux-pair-v1', 'collection_id': c['collection_id'],
                    'snapshot': snapshot, 'database': c['database'], 'required_photos': photos,
                    'inventory': inventory(payload)}
        (payload / 'manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
        partial = Path(temp) / 'snapshot.partial'
        with tarfile.open(partial, 'w:gz', dereference=False) as tar:
            for child in sorted(payload.iterdir()):
                tar.add(child, arcname=child.name)
        verify = Path(temp) / 'verify'
        verify.mkdir()
        validate_archive(partial, verify, c['max_unpack_bytes'])
        partial.rename(archive)
        log(c, 'Verified local paired snapshot: ' + archive.name)
        remote = c['remote'].rstrip('/') + '/' + archive.name
        rclone(c, 'copyto', str(archive), remote, '--immutable')
        downloaded = Path(temp) / 'remote-verification.tar.gz'
        rclone(c, 'copyto', remote, str(downloaded))
        require(digest(downloaded) == digest(archive), 'Remote read-back differs; local archive retained')
    log(c, 'Remote read-back verified: ' + archive.name)
    try:
        prune_local(c, archive)
    except Exception:
        log(c, 'WARNING: Local retention incomplete; verified backup retained')
    log(c, 'Backup complete; service restart and application acceptance remain operator tasks')
    return archive


def restore(c, archive, destination, acknowledged, confirm_database):
    require(acknowledged and confirm_database == c['database'],
            'Restore requires --confirm-isolated and exact --confirm-database')
    writers_stopped(c)
    archive, destination = absolute(str(archive)), absolute(str(destination))
    require(archive.is_file() and not destination.exists(), 'Use one existing archive and an absent destination')
    require(not overlaps(destination, c['backup_root']) and not overlaps(destination, archive),
            'Recovery destination must be separate from backup storage/input')
    with tempfile.TemporaryDirectory(dir=c['backup_root'], prefix='.restore-') as temp:
        payload = Path(temp)
        archive_hash = digest(archive)
        m = validate_archive(archive, payload, c['max_unpack_bytes'])
        require(digest(archive) == archive_hash, 'Recovery input changed during validation')
        require(m['collection_id'] == c['collection_id'], 'Wrong collection identity')
        require(m['database'] == c['database'], 'Restore database name must match the source snapshot')
        counts = query(c, "SELECT (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema=DATABASE()) + "
                       "(SELECT COUNT(*) FROM information_schema.routines WHERE routine_schema=DATABASE()) + "
                       "(SELECT COUNT(*) FROM information_schema.events WHERE event_schema=DATABASE());")
        require(counts == ['0'], 'Restore requires an existing empty database on an isolated server')
        # Pin a local input before any SQL changes. Keep it until recovery is accepted manually.
        if archive.parent == c['backup_root']:
            pin = Path(str(archive) + '.keep')
            if not pin.exists():
                with pin.open('x', encoding='utf-8') as f:
                    f.write('Recovery input: retain until application acceptance is recorded.\n')
        destination.mkdir(mode=0o700, parents=False)
        marker = destination / 'RESTORE-PENDING.json'
        marker.write_text(json.dumps({'archive': str(archive), 'sha256': archive_hash, 'phase': 'sql-import'}))
        try:
            with (payload / 'database.sql').open('rb') as sql:
                result = subprocess.run(client(c) + [c['database']], stdin=sql, stdout=subprocess.DEVNULL,
                                        stderr=subprocess.PIPE, timeout=c['timeout_seconds'])
            if result.returncode != 0:
                diagnostic = c['backup_root'] / ('.tool-error-' + uuid.uuid4().hex + '.log')
                diagnostic.write_bytes(result.stderr)
                diagnostic.chmod(0o600)
            require(result.returncode == 0, 'MariaDB import failed')
            for name in ('uploads', 'configuration'):
                shutil.copytree(payload / name, destination / name)
                require(inventory(destination / name) == inventory(payload / name), 'Restored files differ')
            require(photo_paths(c) == m['required_photos'], 'Restored SQL/photo references differ')
            check_photos(m['required_photos'], destination / 'uploads')
            writers_stopped(c)
            marker.rename(destination / 'RESTORED-VERIFY-APPLICATION.json')
        except Exception as ex:
            raise BackupError('Restore failed. SQL may be partially applied; input and RESTORE-PENDING.json retained. '
                              'Inspect the disposable target before any retry.') from ex
    log(c, 'Data restored; external configuration is staged, not activated. Verify application before use')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('operation', choices=('backup', 'restore'))
    parser.add_argument('--config', required=True)
    parser.add_argument('--writers-stopped', action='store_true')
    parser.add_argument('--stop-writers', action='store_true')
    parser.add_argument('--archive')
    parser.add_argument('--destination')
    parser.add_argument('--confirm-isolated', action='store_true')
    parser.add_argument('--confirm-database')
    a = parser.parse_args()
    os.umask(0o077)
    c = None
    try:
        require(sys.platform.startswith('linux'), 'Production entry point requires Linux')
        c = load_config(a.config, a.operation)
        with operation_lock(c['backup_root']):
            if a.operation == 'backup':
                require(not (a.stop_writers and a.writers_stopped), 'Choose one writer control mode')
                if a.stop_writers:
                    with stop_writers(c):
                        backup(c, True)
                    log(c, 'Previously active writer units restarted; verify application readiness')
                else:
                    backup(c, a.writers_stopped)
            else:
                require(not a.stop_writers and not a.writers_stopped, 'Restore requires units already stopped')
                require(a.archive and a.destination, 'Restore requires --archive and --destination')
                restore(c, a.archive, a.destination, a.confirm_isolated, a.confirm_database)
    except Exception as ex:
        message = str(ex) if isinstance(ex, BackupError) else 'Operation failed; inspect configuration/tool access privately'
        if c:
            log(c, 'ERROR: ' + message)
        else:
            print('ERROR: ' + message, file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
