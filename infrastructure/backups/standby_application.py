"""Private application rehearsal on a fresh SQL/uploads clone; never acceptance.

Does not activate source configuration, schedules or the pristine data candidate.
All probe files/databases are retained on failure for explicit operator review.
"""
from contextlib import contextmanager
import hashlib
import http.client
import json
import os
from pathlib import Path
import platform
import re
import secrets
import shutil
import socket
import subprocess
import tarfile
import time
import uuid
from urllib.parse import quote

import standby_database as d
import standby_publication as p
import standby_restore as s

b, n = s.b, s.n
CHECKS = {'database', 'uploadRoot', 'nativePhotos', 'photoFiles', 'photoRecovery'}


def expected_dll(identity):
    matches = re.findall(r'OrchidApp[.]Web[.]dll SHA256=([0-9a-f]{64})(?![0-9a-f])', identity)
    b.require(len(matches) == 1, 'Backup must identify exactly one compatible publication DLL')
    return matches[0]


def copy_publication(archive, target, expected):
    """Verify everything, but never activate captured settings or uploads."""
    manifest = p.verify(archive, expected)
    b.require(not target.exists(), 'Application workspace already exists')
    target.mkdir(mode=0o700)
    with tarfile.open(archive, 'r:gz') as tar:
        for member in tar:
            b.safe_path(member.name)
            b.require(member.isfile() or member.isdir(), 'Unsafe publication member during extraction')
            if not member.name.startswith('publication/'):
                continue
            entry = manifest['inventory'].get(member.name)
            b.require(entry is not None and ((member.isdir() and entry == {'directory': True})
                      or (member.isfile() and entry.get('size') == member.size)), 'Publication changed during extraction')
            parts = member.name.split('/')[1:]
            # Source JSON settings, environment files and upload copies are inert.
            if any(part.lower().startswith(('appsettings', '.env'))
                   or part.lower() in ('web.config', 'uploads') for part in parts):
                continue
            path = target.joinpath(*parts)
            if member.isdir():
                path.mkdir(mode=0o700, parents=True, exist_ok=True)
            else:
                path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
                with path.open('xb') as out, tar.extractfile(member) as source:
                    shutil.copyfileobj(source, out)
                b.require(path.stat().st_size == entry['size'] and b.digest(path) == entry['sha256'],
                          'Publication changed during extraction')
                path.chmod(0o600)
    b.require(b.digest(target / 'OrchidApp.Web.dll') == expected, 'Extracted DLL mismatch')
    n.atomic_json(target / 'appsettings.json', {'Monitoring': {'Enabled': False},
                                             'AllowedHosts': '127.0.0.1;localhost'})


def environment(runtime, workspace, native, database, password, port):
    b.require(re.fullmatch(r'[A-Za-z][A-Za-z0-9_]*', database), 'Unsafe database name')
    b.require(re.fullmatch(r'[0-9a-f]{64}', password), 'Use a fresh generated target password')
    b.require(';' not in native['socket'] and '"' not in native['socket'], 'Unsafe socket path')
    # Deliberately do not inherit SMTP, .NET hooks, source DB credentials or feeds.
    return {'PATH': '/usr/bin:/bin', 'HOME': str(workspace), 'TMPDIR': str(workspace / 'tmp'),
            'DOTNET_ROOT': str(runtime.parent), 'DOTNET_MULTILEVEL_LOOKUP': '0',
            'DOTNET_ROLL_FORWARD': 'LatestPatch', 'DOTNET_CLI_TELEMETRY_OPTOUT': '1',
            'DOTNET_NOLOGO': '1', 'ASPNETCORE_ENVIRONMENT': 'Production',
            'DOTNET_ENVIRONMENT': 'Production', 'ASPNETCORE_URLS': 'http://127.0.0.1:' + str(port),
            'ConnectionStrings__OrchidDb': 'Server=' + native['socket'] + ';Database=' + database
            + ';User ID=standby_probe;Password=' + password + ';Connection Timeout=3;Default Command Timeout=10;',
            'Storage__UploadRoot': str(workspace / 'uploads'), 'Monitoring__Enabled': 'false'}


def owns_listener(process, port):
    """Do not send HTTP probes to another service that won a port race."""
    b.require(process.poll() is None, 'Owned application exited; inspect private application log')
    inodes = set()
    for fd in Path('/proc/' + str(process.pid) + '/fd').iterdir():
        try:
            link = os.readlink(fd)
        except FileNotFoundError:
            continue
        if link.startswith('socket:['):
            inodes.add(link[8:-1])
    listeners = []
    for table in ('tcp', 'tcp6'):
        for row in Path('/proc/net/' + table).read_text().splitlines()[1:]:
            fields = row.split()
            if fields[3] == '0A' and fields[9] in inodes:
                listeners.append((table, fields[1]))
    expected = ('tcp', '0100007F:' + format(port, '04X'))
    b.require(all(value == expected for value in listeners), 'Application opened an unexpected network listener')
    return expected in listeners


def get(process, port, path, maximum, expected_hash=None):
    b.require(owns_listener(process, port), 'Owned loopback application listener missing')
    connection = http.client.HTTPConnection('127.0.0.1', port, timeout=20)
    try:
        connection.request('GET', path)
        response = connection.getresponse()
        b.require(response.status == 200, 'Application HTTP check failed: ' + str(response.status))
        if expected_hash is None:
            content = response.read(maximum + 1)
            b.require(len(content) <= maximum and process.poll() is None, 'Oversized response or application exited')
            return content
        digest, size = hashlib.sha256(), 0
        while True:
            chunk = response.read(min(65536, maximum - size + 1))
            if not chunk:
                break
            size += len(chunk)
            b.require(size <= maximum and process.poll() is None, 'Oversized photo response or application exited')
            digest.update(chunk)
        b.require(size == maximum and digest.hexdigest() == expected_hash, 'HTTP photo/thumbnail differs from backup')
        return None
    finally:
        connection.close()


def readiness(raw):
    result = json.loads(raw)
    b.require(result.get('ready') is True and isinstance(result.get('checks'), dict)
              and CHECKS <= result['checks'].keys()
              and all(value is True for value in result['checks'].values()), 'Application readiness failed')
    return result


@contextmanager
def running_app(c, runtime, workspace, native, password, evidence):
    with socket.socket() as reservation:
        reservation.bind(('127.0.0.1', 0))
        port = reservation.getsockname()[1]
    env = environment(runtime, workspace, native, c['photo_database'], password, port)
    with evidence.open('ab') as log:
        process = subprocess.Popen([str(runtime), str(workspace / 'publication/OrchidApp.Web.dll')],
                                   cwd=workspace / 'publication', env=env, stdin=subprocess.DEVNULL,
                                   stdout=log, stderr=log, user=c['server_uid'], group=c['server_gid'],
                                   extra_groups=[], umask=0o077)
        try:
            for _ in range(120):
                if owns_listener(process, port):
                    break
                time.sleep(0.5)
            else:
                raise b.BackupError('Timed out waiting for owned application listener')
            yield process, port
        finally:
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=30)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=10)
                    raise b.BackupError('Owned application required forced shutdown')


def provision(c, native, process, report=None):
    d.identity(c, native, process)
    database = c['photo_database']
    if c.get('view_definer_policy'):
        import standby_definers
        b.require(c['view_definer_policy'] == standby_definers.POLICY, 'Unknown view definer policy')
        zones = standby_definers.timezones(c, native, process)
        mapping = standby_definers.apply(c, native, process, c['view_definer_policy'])
        if report is not None:
            report['timezones'] = zones
            report['view_definer_mapping'] = mapping
    # Fail on missing definers rather than silently rewriting restored objects.
    selected = ','.join("'" + name + "'" for name in c['databases'])
    rows = d.query(c, native, 'SELECT DISTINCT DEFINER FROM (SELECT DEFINER FROM information_schema.VIEWS '
                   'WHERE TABLE_SCHEMA IN (' + selected + ') UNION SELECT DEFINER FROM information_schema.ROUTINES '
                   'WHERE ROUTINE_SCHEMA IN (' + selected + ') UNION SELECT DEFINER FROM information_schema.TRIGGERS '
                   'WHERE TRIGGER_SCHEMA IN (' + selected + ')) AS definitions;')
    accounts = set(d.query(c, native, "SELECT CONCAT(User,'@',Host) FROM mysql.user;"))
    b.require(set(rows) <= accounts, 'Restored objects have unresolved SQL definers; explicit review required')
    password = secrets.token_hex(32)
    d.query(c, native, "CREATE USER 'standby_probe'@'localhost' IDENTIFIED BY '" + password + "';"
            + 'GRANT SELECT,INSERT,UPDATE,DELETE,EXECUTE ON `' + database + "`.* TO 'standby_probe'@'localhost';")
    return password


def preserve_failed_report(path, retry_token, snapshot, archive_hash):
    if not path.exists():
        b.require(retry_token is None, 'No failed rehearsal matches the requested retry')
        return None
    b.require(retry_token is not None, 'Application rehearsal already attempted; inspect its evidence before retry')
    b.protected_file(path)
    previous = json.loads(path.read_text())
    b.require(previous.get('result') == 'APPLICATION_PROBE_FAILED' and previous.get('token') == retry_token
              and previous.get('snapshot') == snapshot and previous.get('archive_sha256') == archive_hash,
              'Retry must name the exact failed attempt for this archive')
    b.require(uuid.UUID(retry_token).hex == retry_token, 'Invalid retry token')
    history = path.with_name('application-probe-failed-' + retry_token + '.json')
    if history.exists():
        b.protected_file(history)
        b.require(history.read_bytes() == path.read_bytes(), 'Retry history differs; inspect retained evidence')
    else:
        # No-overwrite link retains the old report when atomic_json replaces path.
        os.link(path, history)
    b.require(len(list(path.parent.glob('application-probe-failed-*.json'))) <= 3,
              'Rehearsal retry capacity reached; review retained candidates and space')
    return previous


def probe(config, snapshot, publication, runtime, app_root, view_definer_policy=None, retry_token=None):
    c = d.configure(config)
    if view_definer_policy is not None:
        import standby_definers
        b.require(view_definer_policy == standby_definers.POLICY, 'Unknown view definer policy')
        c['view_definer_policy'] = view_definer_policy
    b.require(os.geteuid() == 0 and platform.machine().lower() in ('aarch64', 'arm64'),
              'Installed application rehearsal requires root on the ARM64 target')
    b.require(n.NAME.fullmatch(snapshot), 'Use an exact restored snapshot identity')
    generation = c['state_root'] / 'generations' / snapshot
    state_file = generation / 'state.json'
    b.protected_file(state_file)
    state_before = state_file.read_bytes()
    state = json.loads(state_before)
    b.require(state.get('format') == s.STATE_FORMAT and state.get('accepted') is False
              and state.get('phase') == 'DATA_RESTORED_APPLICATION_PENDING'
              and state.get('record', {}).get('snapshot') == snapshot, 'Data-stage candidate required')
    uuid.UUID(state['owner_token'])
    s.check_record(c, state['record'])
    archive = generation / state['record']['archive']
    b.require(b.digest(archive) == state['record']['sha256'], 'Backup archive changed')
    manifest = s.check_manifest(c, archive, state['record'])
    expected = expected_dll(manifest['software_identity'])
    publication, runtime, app_root = (b.absolute(str(value)) for value in (publication, runtime, app_root))
    b.protected_file(publication)
    publication_manifest = p.verify(publication, expected)
    # The root-owned runtime must not be writable by the application account.
    for path in (runtime, *runtime.parents):
        info = path.stat()
        b.require(info.st_uid == 0 and not info.st_mode & 0o022, 'Runtime path must be root owned and not group/world writable')
    versions = b.run(c, [str(runtime), '--list-runtimes']).decode()
    b.require(all(re.search(r'^' + re.escape(name) + r' 8[.]0[.]\d+ ', versions, re.M)
                  for name in ('Microsoft.NETCore.App', 'Microsoft.AspNetCore.App')), 'Both .NET 8 runtimes required')
    b.require(app_root.name.startswith('orchidapp-standby-app') and len(app_root.parts) >= 3
              and not b.overlaps(app_root, c['state_root']) and not b.overlaps(app_root, c['database_root']),
              'Use a separate prepared application root')
    info = app_root.stat()
    b.require(info.st_uid == c['server_uid'] and not info.st_mode & 0o077, 'Application root must be candidate-user owned mode 700')
    size = sum(v.get('size', 0) for v in manifest['inventory'].values())
    size += sum(v.get('size', 0) for v in publication_manifest['inventory'].values())
    b.require(shutil.disk_usage(app_root).free >= 4 * size + c['reserve_bytes'], 'Insufficient application rehearsal space')
    # Retain failed evidence; an explicit token authorizes a NEW clone only.
    report_path = generation / 'application-probe.json'
    previous = preserve_failed_report(report_path, retry_token, snapshot, state['record']['sha256'])
    token = uuid.uuid4().hex
    report = {'result': 'APPLICATION_PROBE_PENDING', 'snapshot': snapshot, 'started_at': n.now(),
              'token': token, 'archive_sha256': state['record']['sha256'],
              'web_dll_sha256': expected, 'runtimes': versions.splitlines(), 'accepted_state_unchanged': True}
    if previous is not None:
        report['retry_of'] = previous['token']
    n.atomic_json(report_path, report)
    try:
        scratch = s.private_directory(generation / ('application-probe-' + token))
        clone_config = dict(c, state_root=scratch, backup_root=scratch)
        clone = s.private_directory(scratch / 'generations' / snapshot)
        shutil.copyfile(archive, clone / archive.name)
        (clone / archive.name).chmod(0o600)
        s.extract_private(clone / archive.name, clone / 'payload', manifest)
        n.atomic_json(clone / 'state.json', {'format': s.STATE_FORMAT, 'owner_token': uuid.uuid4().hex,
                      'phase': 'PREPARED_RESTORE_PENDING', 'accepted': False, 'record': state['record']})
        d.restore_data(clone_config, snapshot)
        native = json.loads((clone / 'state.json').read_text())['candidate']
        workspace = app_root / ('probe-' + token)
        workspace.mkdir(mode=0o700)
        copy_publication(publication, workspace / 'publication', expected)
        shutil.copytree(clone / 'payload/sources' / c['uploads_source'], workspace / 'uploads')
        (workspace / 'tmp').mkdir(mode=0o700)
        for path in [workspace, *workspace.rglob('*')]:
            b.require(not path.is_symlink(), 'Unexpected workspace link')
            os.chown(path, c['server_uid'], c['server_gid'])
            path.chmod(0o700 if path.is_dir() else 0o600)
        with d.running_candidate(c, native) as server:
            password = provision(c, native, server, report)
            for restart in range(2):
                with running_app(c, runtime, workspace, native, password, scratch / 'application.log') as (process, port):
                    report['readiness'] = readiness(get(process, port, '/health/ready', 65536))
                    get(process, port, '/', 4 * 1024**2)
                    for relative in manifest['required_photos']:
                        entry = manifest['inventory']['sources/' + c['uploads_source'] + '/' + relative]
                        get(process, port, '/uploads/' + quote(relative, safe='/'), entry['size'], entry['sha256'])
                d.identity(c, native, server)
        b.require(state_file.read_bytes() == state_before, 'Pristine generation state changed during rehearsal')
        report.update(result='APPLICATION_PROBE_PASSED_ACCEPTANCE_PENDING', finished_at=n.now(),
                      photo_files_checked=len(manifest['required_photos']), application_starts=2,
                      note='Disposable SQL/uploads clone only; CRUD, pristine acceptance, promotion and reporting remain pending')
        n.atomic_json(report_path, report)
        return report
    except Exception as ex:
        report.update(result='APPLICATION_PROBE_FAILED', finished_at=n.now(),
                      error=str(ex) if isinstance(ex, b.BackupError) else 'Application rehearsal failed; inspect private logs')
        n.atomic_json(report_path, report)
        raise
