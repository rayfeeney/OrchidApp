"""Block 2 data stage: restore only into a newly owned, socket-only candidate.

Never connects to the system MariaDB endpoint, applies accounts.sql, accepts a
standby, starts application jobs or changes cloud storage. Linux entry only.
"""
from contextlib import contextmanager
import json
import os
from pathlib import Path
import re
import secrets
import shutil
import subprocess
import time
import uuid

import standby_restore as s

b, n = s.b, s.n
CHARACTER_OPTIONS = ('--character-set-server=utf8mb4', '--collation-server=utf8mb4_general_ci',
                     '--character-set-collations=utf8mb4=utf8mb4_general_ci')


def check_character_settings(c, native):
    rows = query(c, native, 'SELECT @@character_set_server,@@collation_server,@@character_set_collations;')
    b.require(len(rows) == 1, 'Unexpected candidate character settings response')
    values = rows[0].split('\t')
    b.require(len(values) == 3 and values[:2] == ['utf8mb4', 'utf8mb4_general_ci']
              and 'utf8mb4=utf8mb4_general_ci' in values[2].split(','),
              'Candidate must use the reviewed utf8mb4/general_ci source defaults')


def private_text(path, content):
    temp = path.with_name(path.name + '.' + uuid.uuid4().hex + '.tmp')
    try:
        fd = os.open(temp, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(fd, 'w', encoding='utf-8') as out:
            out.write(content)
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


def option(value):
    return '"' + str(value).replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n').replace('\r', '\\r') + '"'


def write_client(path, socket, password):
    private_text(path, '[client]\nprotocol=socket\nsocket=' + option(socket)
                 + '\nuser=root\npassword=' + option(password) + '\n')


def client(c, native):
    # No caller-provided host, port or client credential file is accepted.
    path = b.absolute(native['admin_defaults'])
    b.protected_file(path)
    return [c['tools']['mariadb'], '--defaults-file=' + str(path), '--protocol=socket',
            '--socket=' + native['socket'], '--user=root', '--connect-timeout=3',
            '--batch', '--skip-column-names', '--default-character-set=utf8mb4']


def query(c, native, sql):
    return b.run(c, client(c, native), stdin=sql.encode()).decode('utf-8').splitlines()


def identity(c, native, process):
    b.require(process.poll() is None, 'Owned candidate server exited')
    rows = query(c, native, 'SELECT @@datadir,@@socket,@@skip_networking,@@event_scheduler,@@server_id,@@version;')
    b.require(len(rows) == 1, 'Unexpected candidate identity response')
    values = rows[0].split('\t')
    b.require(len(values) == 6, 'Unexpected candidate identity fields')
    b.require(Path(values[0]).resolve() == Path(native['datadir']).resolve()
              and values[1] == native['socket'] and values[2] == '1' and values[3] == 'OFF'
              and values[4] == str(native['server_id']) and values[5].startswith(c['required_server_series'] + '.'),
              'Candidate endpoint, data directory, isolation or version mismatch')
    b.require(process.poll() is None, 'Owned candidate server exited during identity check')
    return values[5]


def configure(c):
    import pwd  # POSIX only; keep policy tests importable elsewhere.
    b.require(os.name == 'posix', 'Native candidate restoration requires Linux')
    username = c.get('server_user', '')
    b.require(isinstance(username, str) and re.fullmatch(r'[a-z_][a-z0-9_-]*', username), 'Explicit candidate system user required')
    account = pwd.getpwnam(username)
    b.require(account.pw_uid != 0, 'Candidate MariaDB must not run as root')
    b.require(os.geteuid() in (0, account.pw_uid), 'Cannot run as configured candidate user')
    root = b.absolute(c['database_root'])
    b.require(root.is_dir() and root != root.parent and len(root.parts) >= 3
              and root.name.startswith('orchidapp-standby-db')
              and not b.overlaps(root, c['state_root']), 'Use a separate prepared candidate database root')
    info = root.stat()
    b.require(info.st_uid == account.pw_uid and not info.st_mode & 0o077, 'Database root must be candidate-user owned mode 700')
    c = dict(c, database_root=root, server_uid=account.pw_uid, server_gid=account.pw_gid)
    b.require(c.get('required_server_series') == '11.8', 'This candidate contract requires the reviewed MariaDB 11.8 series')
    c['tools'] = {}
    for tool in ('mariadb', 'mariadbd', 'mariadb-install-db'):
        path = shutil.which(tool)
        b.require(path, 'Required native tool missing: ' + tool)
        c['tools'][tool] = path
    version = b.run(c, [c['tools']['mariadbd'], '--no-defaults', '--version']).decode()
    b.require(re.search(r'\b11[.]8[.]', version), 'Installed server is not MariaDB 11.8')
    return c


def make_target(c, generation, state):
    token = uuid.uuid4().hex
    target = c['database_root'] / ('candidate-' + token)
    b.require(not target.exists(), 'Candidate target already exists')
    socket = target / 'server.sock'
    if os.name == 'posix':
        b.require(len(os.fsencode(socket)) < 100, 'Candidate socket path is too long')
    target.mkdir(mode=0o700)
    if os.geteuid() == 0:
        os.chown(target, c['server_uid'], c['server_gid'])
    native = {'owner_token': state['owner_token'], 'target_token': token, 'target': str(target),
              'datadir': str(target / 'data'), 'socket': str(socket),
              'pid_file': str(target / 'server.pid'), 'server_log': str(target / 'server.log'),
              'admin_defaults': str(generation / 'candidate-admin.cnf'),
              'server_id': secrets.randbelow(2**31 - 2) + 1}
    write_client(Path(native['admin_defaults']), socket, '')
    return native


def owned_target(c, native):
    target = b.absolute(native['target'])
    token = uuid.UUID(native['target_token']).hex
    b.require(target.parent == c['database_root'] and target.name == 'candidate-' + token,
              'Unrecognised candidate target')
    b.require(Path(native['datadir']) == target / 'data' and Path(native['socket']) == target / 'server.sock'
              and Path(native['pid_file']) == target / 'server.pid' and Path(native['server_log']) == target / 'server.log',
              'Candidate paths escaped owned target')
    b.require(target.stat().st_uid == c['server_uid'] and not target.stat().st_mode & 0o077,
              'Candidate ownership or permissions changed')
    return target


def initialise(c, native):
    owned_target(c, native)
    b.require(not Path(native['datadir']).exists(), 'Refusing to initialise an existing data directory')
    args = [c['tools']['mariadb-install-db'], '--no-defaults', '--datadir=' + native['datadir'],
            '--auth-root-authentication-method=normal', '--skip-test-db', '--skip-name-resolve']
    if os.geteuid() == 0:
        args.append('--user=' + c['server_user'])
    b.run(c, args)


@contextmanager
def running_candidate(c, native):
    owned_target(c, native)
    args = [c['tools']['mariadbd'], '--no-defaults', '--datadir=' + native['datadir'],
            '--socket=' + native['socket'], '--pid-file=' + native['pid_file'],
            '--log-error=' + native['server_log'], '--skip-networking', '--skip-log-bin',
            '--skip-slave-start', '--event-scheduler=OFF', '--server-id=' + str(native['server_id']),
            '--innodb-buffer-pool-size=128M', '--max-connections=20']
    args.extend(CHARACTER_OPTIONS)
    if os.geteuid() == 0:
        args.append('--user=' + c['server_user'])
    log_fd = os.open(Path(native['admin_defaults']).parent / 'candidate-start.log',
                     os.O_WRONLY | os.O_CREAT | os.O_APPEND, 0o600)
    log = os.fdopen(log_fd, 'ab')
    process = subprocess.Popen(args, stdin=subprocess.DEVNULL, stdout=log, stderr=log)
    try:
        # No SQL writes before the exact owned server identifies itself.
        for _ in range(60):
            b.require(process.poll() is None, 'Candidate failed to start; inspect private candidate logs')
            if Path(native['socket']).exists():
                try:
                    identity(c, native, process)
                    break
                except b.BackupError as ex:
                    # Socket creation can precede readiness; actual identity
                    # mismatches must never be retried or ignored.
                    if not str(ex).startswith('Tool failed: mariadb;'):
                        raise
            time.sleep(0.5)
        else:
            raise b.BackupError('Timed out waiting for owned candidate socket')
        check_character_settings(c, native)
        yield process
    finally:
        try:
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=60)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=10)
                    raise b.BackupError('Owned candidate needed forced shutdown; inspect recovery state')
        finally:
            log.close()


def photo_paths(c, native):
    database = '`' + c['photo_database'] + '`'
    sql = ("SELECT CONCAT('plants/',plantId,'/',fileName) FROM " + database + ".plantphoto WHERE isActive=1\n"
           "UNION SELECT CONCAT('plants/',plantId,'/',thumbnailFileName) FROM " + database + ".plantphoto WHERE isActive=1 AND thumbnailFileName IS NOT NULL AND thumbnailFileName<>''\n"
           "UNION SELECT CONCAT('taxa/',taxonId,'/',fileName) FROM " + database + ".taxonphoto WHERE isActive=1\n"
           "UNION SELECT CONCAT('taxa/',taxonId,'/',thumbnailFileName) FROM " + database + ".taxonphoto WHERE isActive=1 AND thumbnailFileName IS NOT NULL AND thumbnailFileName<>'';")
    return sorted(set(query(c, native, sql)))


def inventory(c, native):
    selected = ','.join("'" + name + "'" for name in c['databases'])
    rows = query(c, native, 'SELECT TABLE_SCHEMA,HEX(TABLE_NAME) FROM information_schema.TABLES '
                 'WHERE TABLE_SCHEMA IN (' + selected + ") AND TABLE_TYPE='BASE TABLE' ORDER BY TABLE_SCHEMA,TABLE_NAME;")
    b.require(rows and len(rows) <= 10000, 'Unexpected base-table inventory')
    counts = {}
    for row in rows:
        schema, encoded = row.split('\t')
        name = bytes.fromhex(encoded).decode('utf-8')
        b.require(schema in c['databases'], 'Unexpected restored database')
        identifier = '`' + name.replace('`', '``') + '`'
        count = query(c, native, 'SELECT COUNT(*) FROM `' + schema + '`.' + identifier + ';')
        b.require(len(count) == 1 and count[0].isdigit(), 'Unexpected table count')
        counts.setdefault(schema, {})[name] = int(count[0])
    b.require(set(counts) == set(c['databases']), 'One or more selected databases has no restored base tables')
    objects = query(c, native, 'SELECT TABLE_SCHEMA,TABLE_TYPE,COUNT(*) FROM information_schema.TABLES '
                    'WHERE TABLE_SCHEMA IN (' + selected + ') GROUP BY TABLE_SCHEMA,TABLE_TYPE ORDER BY TABLE_SCHEMA,TABLE_TYPE;')
    routines = query(c, native, 'SELECT ROUTINE_SCHEMA,HEX(ROUTINE_NAME),ROUTINE_TYPE,HEX(DEFINER) FROM information_schema.ROUTINES '
                     'WHERE ROUTINE_SCHEMA IN (' + selected + ') ORDER BY ROUTINE_SCHEMA,ROUTINE_NAME;')
    views = query(c, native, 'SELECT TABLE_SCHEMA,HEX(TABLE_NAME),HEX(DEFINER) FROM information_schema.VIEWS '
                  'WHERE TABLE_SCHEMA IN (' + selected + ') ORDER BY TABLE_SCHEMA,TABLE_NAME;')
    events = query(c, native, 'SELECT EVENT_SCHEMA,HEX(EVENT_NAME),STATUS FROM information_schema.EVENTS '
                   'WHERE EVENT_SCHEMA IN (' + selected + ') ORDER BY EVENT_SCHEMA,EVENT_NAME;')
    triggers = query(c, native, 'SELECT TRIGGER_SCHEMA,HEX(TRIGGER_NAME),ACTION_TIMING,EVENT_MANIPULATION,HEX(DEFINER) '
                     'FROM information_schema.TRIGGERS WHERE TRIGGER_SCHEMA IN (' + selected + ') ORDER BY TRIGGER_SCHEMA,TRIGGER_NAME;')
    return {'base_table_rows': counts, 'objects': objects, 'routines_and_definers': routines,
            'views_and_definers': views, 'events': events, 'triggers_and_definers': triggers}


def restore_data(config, snapshot):
    c = configure(config)
    b.require(n.NAME.fullmatch(snapshot), 'Use one exact prepared snapshot identity')
    generation = b.absolute(str(c['state_root'] / 'generations' / snapshot))
    b.require(generation.is_dir(), 'Prepared generation missing')
    state_file = generation / 'state.json'
    b.protected_file(state_file)
    state = json.loads(state_file.read_text())
    b.require(state.get('format') == s.STATE_FORMAT and state.get('phase') == 'PREPARED_RESTORE_PENDING'
              and state.get('accepted') is False and state.get('record', {}).get('snapshot') == snapshot,
              'Generation is not a pristine prepared input; inspect failed/pending state before retry')
    uuid.UUID(state['owner_token'])
    record = s.check_record(c, state['record'])
    archive = generation / record['archive']
    b.require(b.digest(archive) == record['sha256'] and archive.stat().st_size == record['size_bytes'], 'Prepared archive changed')
    manifest = s.check_manifest(c, archive, record)
    payload = generation / 'payload'
    actual = b.inventory(payload)
    del actual['manifest.json']
    b.require(actual == manifest['inventory'], 'Prepared payload changed; no SQL permitted')
    sql_bytes = sum((payload / 'databases' / (name + '.sql')).stat().st_size for name in c['databases'])
    b.require(shutil.disk_usage(c['database_root']).free >= 4 * sql_bytes + c['reserve_bytes'], 'Insufficient candidate database space')
    native = make_target(c, generation, state)
    state.update(phase='DATABASE_INITIALISING', candidate=native, database_started_at=n.now())
    n.atomic_json(state_file, state)
    try:
        initialise(c, native)
        with running_candidate(c, native) as process:
            identity(c, native, process)
            present = query(c, native, 'SHOW DATABASES;')
            b.require(not set(c['databases']) & set(present), 'Owned candidate is not empty')
            # Set a new private target password; never import source accounts.sql.
            password = secrets.token_hex(32)
            query(c, native, "ALTER USER 'root'@'localhost' IDENTIFIED BY '" + password + "';")
            write_client(Path(native['admin_defaults']), Path(native['socket']), password)
            identity(c, native, process)
            state['phase'] = 'DATABASE_IMPORT_PENDING'
            n.atomic_json(state_file, state)
            for database in c['databases']:
                identity(c, native, process)
                with (payload / 'databases' / (database + '.sql')).open('rb') as source:
                    b.require(process.poll() is None, 'Candidate stopped before import')
                    result = subprocess.run(client(c, native), stdin=source, stdout=subprocess.DEVNULL,
                                            stderr=subprocess.PIPE, timeout=c['timeout_seconds'])
                if result.returncode:
                    private_text(generation / ('import-' + database + '-error.log'), result.stderr.decode('utf-8', errors='replace'))
                b.require(result.returncode == 0, 'Candidate SQL import failed; partial state retained')
            identity(c, native, process)
            restored_photos = photo_paths(c, native)
            b.require(restored_photos == manifest['required_photos'], 'Restored SQL photo references differ')
            b.check_photos(restored_photos, payload / 'sources' / c['uploads_source'])
            restored = inventory(c, native)
            state['database_inventory'] = restored
            state['server_version'] = identity(c, native, process)
        # The owned server is stopped before recording successful data-stage exit.
        state.update(phase='DATA_RESTORED_APPLICATION_PENDING', database_finished_at=n.now(),
                     note='Owned database stopped; application/definer/grant/acceptance checks pending; no accepted pointer changed')
        n.atomic_json(state_file, state)
        return {'result': state['phase'], 'snapshot': snapshot, 'server_version': state['server_version'],
                'base_table_counts': {key: len(value) for key, value in restored['base_table_rows'].items()},
                'accepted_state_unchanged': True}
    except Exception as ex:
        state.update(phase='DATABASE_FAILED', database_failed_at=n.now(),
                     error=str(ex) if isinstance(ex, b.BackupError) else 'Candidate data restore failed; inspect private logs')
        n.atomic_json(state_file, state)
        raise
