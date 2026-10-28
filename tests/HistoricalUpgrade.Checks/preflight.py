"""Verify the pinned specimen and test canonical migration compatibility.

Default: genuine read-only preflight. Optional --adopt-and-migrate: require the
exact reviewed schema/history, preserve the original ledger and test the actual
forward migrations ONLY on this newly created, owned isolated fixture restore.
Neither mode deploys an app or represents complete upgrade/recovery acceptance.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import subprocess
import tarfile
import time
import uuid

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
PASSWORD = 'historical-disposable-only'


def digest(path):
    value = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024*1024), b''):
            value.update(chunk)
    return value.hexdigest()


def safe_relative(name):
    path = PurePosixPath(name)
    if (path.is_absolute() or not path.parts or '\\' in name or ':' in name or
            any(part in ('', '.', '..', '.git') or part.startswith('.env') for part in name.split('/'))):
        raise ValueError('Unsafe or private fixture member')
    return path


def verify_fixture(package, manifest, stage):
    if package.stat().st_size != manifest['bytes'] or digest(package) != manifest['sha256']:
        raise ValueError('Pinned specimen size/hash mismatch; never use the private capture')
    with tarfile.open(package, 'r:gz') as archive:
        items = archive.getmembers()
        if len(items) > manifest['maxMembers'] or sum(m.size for m in items) > manifest['maxUncompressedBytes']:
            raise ValueError('Fixture resource limits exceeded')
        members = {}
        for item in items:
            path = safe_relative(item.name)
            if not item.isfile() or path.parts[0] != manifest['root'] or len(path.parts) < 2:
                raise ValueError('Unexpected fixture root/type; links are prohibited')
            relative = PurePosixPath(*path.parts[1:]).as_posix()
            if relative in members:
                raise ValueError('Duplicate fixture member')
            members[relative] = item
        if 'SHA256SUMS' not in members or members['SHA256SUMS'].size > 1024*1024:
            raise ValueError('Missing/oversized inner checksum inventory')
        expected = {}
        for line in archive.extractfile(members['SHA256SUMS']).read().decode('utf-8').splitlines():
            value, relative = line.split('  ', 1)
            safe_relative(relative)
            if not re.fullmatch('[a-f0-9]{64}', value) or relative in expected:
                raise ValueError('Invalid/duplicate checksum inventory entry')
            expected[relative] = value
        if set(members) != set(expected) | {'SHA256SUMS'}:
            raise ValueError('Fixture inventory does not match its file set')
        for relative, value in expected.items():
            stream = archive.extractfile(members[relative])
            actual = hashlib.sha256()
            for chunk in iter(lambda: stream.read(1024*1024), b''):
                actual.update(chunk)
            if actual.hexdigest() != value:
                raise ValueError('Fixture member checksum mismatch')
        if any('appsettings' in Path(p).name.lower() and p != 'publish/appsettings.json' for p in members):
            raise ValueError('Unexpected published private/alternate application settings')
        settings = json.load(archive.extractfile(members['publish/appsettings.json']))
        expected_connection = ('Server=127.0.0.1;Port=3306;Database=orchids;'
                               'User=specimen;Password=specimen-only-not-production')
        if settings.get('ConnectionStrings') != {'OrchidDb': expected_connection}:
            raise ValueError('Unexpected specimen runtime connection')
        if settings.get('Storage', {}).get('UploadRoot') != '/specimen/uploads':
            raise ValueError('Unexpected specimen upload root')
        photo_manifest = json.load(archive.extractfile(members['photo-manifest.json']))
        photos = {'uploads/'+p['path']: p['sha256'] for p in photo_manifest}
        if set(photos) != {p for p in members if p.startswith('uploads/')}:
            raise ValueError('Synthetic photo inventory differs')
        if any(expected.get(p) != value for p, value in photos.items()):
            raise ValueError('Synthetic photo hashes differ')
        sql_path = stage/'orchids.sql'
        with sql_path.open('xb') as output, archive.extractfile(members['orchids.sql']) as source:
            for chunk in iter(lambda: source.read(1024*1024), b''):
                output.write(chunk)
    return {'filesVerified': len(members), 'syntheticPhotosVerified': len(photos),
            'sqlSha256': expected['orchids.sql']}


def ledger_review(history, folder):
    rows = []
    for name, checksum in sorted(history.items()):
        if name.startswith('baseline'):
            continue
        if not re.fullmatch(r'[0-9]{12}_[A-Za-z0-9_]+\.sql', name):
            rows.append({'name': name, 'status': 'invalid-name'})
            continue
        path = folder/name
        if not path.is_file():
            rows.append({'name': name, 'status': 'missing', 'recordedSha256': checksum})
            continue
        data = path.read_bytes()
        raw = hashlib.sha256(data).hexdigest()
        # Diagnostic only. These bytes are NEVER substituted for the runner input.
        lf = hashlib.sha256(data.removeprefix(b'\xef\xbb\xbf').replace(b'\r\n', b'\n')).hexdigest()
        rows.append({'name': name, 'status': 'matches' if raw == checksum else 'checksum-mismatch',
                     'recordedSha256': checksum, 'fileSha256': raw,
                     'lfDiagnosticMatches': lf == checksum})
    return rows


def plan_status(exit_code, log):
    if exit_code == 0:
        return 'passed'
    plain = re.sub(r'\x1b\[[0-9;]*m', '', log)
    plain = re.sub(r'\s+', ' ', plain)
    policy = ('Applied migration checksum changed:', 'Applied migration file is missing:',
              'Invalid recorded migration checksum:', 'Legacy baseline has no recorded migration ledger',
              'Unrecognised database baseline marker', 'Multiple database baseline markers',
              'incomplete or running migration requires review', 'Backdated or out-of-order pending migration:',
              'Duplicate migration timestamp', 'Malformed or duplicate migration history row',
              'schemaversion must use InnoDB')
    return 'blocked' if any(value in plain for value in policy) else 'failed'


def docker(*args, env=None, timeout=600):
    result = subprocess.run(['docker', *args], env=env, capture_output=True, timeout=timeout)
    if result.returncode:
        raise RuntimeError('Docker operation failed: '+args[0])
    return result.stdout


def owned(container, token):
    item = json.loads(docker('inspect', container))[0]
    if (item['Id'] != container or item['Config']['Labels'].get('org.orchidapp.fixture-token') != token or
            item['HostConfig']['NetworkMode'] != 'none' or item['HostConfig'].get('Binds') or
            item['HostConfig'].get('PortBindings') or
            any(m.get('Type') == 'bind' for m in item.get('Mounts', []))):
        raise RuntimeError('Owned isolated container identity mismatch')
    return item


def query(container, statement):
    result = subprocess.run(['docker', 'exec', '-i', '--env', 'MYSQL_PWD='+PASSWORD,
        container, 'mariadb', '--user=root', '--batch', '--skip-column-names', '--raw',
        '--default-character-set=utf8mb4'], input=statement.encode(), capture_output=True, timeout=90)
    if result.returncode:
        raise RuntimeError('Owned specimen SQL query failed')
    return result.stdout.decode('utf-8')


def data_checksum(container, tables):
    """Hash deterministic data-only dump bytes without retaining/logging row data."""
    command = ['docker', 'exec', '--env', 'MYSQL_PWD='+PASSWORD, container,
        'mariadb-dump', '--user=root', '--default-character-set=utf8mb4',
        '--single-transaction', '--no-create-info', '--skip-comments', '--skip-dump-date',
        '--skip-add-locks', '--skip-disable-keys', '--skip-extended-insert',
        '--order-by-primary', '--hex-blob', 'orchids', *sorted(tables)]
    value = hashlib.sha256()
    with subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE) as process:
        for chunk in iter(lambda: process.stdout.read(1024*1024), b''):
            value.update(chunk)
        errors = process.stderr.read()
        code = process.wait(timeout=120)
        if code:
            raise RuntimeError('Owned specimen data fingerprint failed')
    return value.hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--specimen', type=Path, required=True)
    parser.add_argument('--output', type=Path, default=REPO/'artifacts/historical-upgrade')
    parser.add_argument('--adopt-and-migrate', action='store_true',
        help='Verify the exact reviewed historical schema, archive its ledger and test actual forward migrations ONLY in this new disposable restore')
    args = parser.parse_args()
    manifest = json.loads((HERE/'fixture.json').read_text())
    token = uuid.uuid4().hex
    output = args.output.resolve()/(datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')+'-'+token[:8])
    output.mkdir(parents=True, exist_ok=False)
    stage = output/'stage'
    stage.mkdir()
    report = {'formatVersion': 1, 'fixtureId': manifest['id'], 'fixtureSha256': manifest['sha256'],
        'startedUtc': datetime.now(timezone.utc).isoformat(), 'status': 'failed',
        'applicationExecuted': False, 'migrationApplicationAttempted': False,
        'phase': 'read-only migration preflight', 'fullUpgradeAcceptance': 'not performed',
        'specimenPlatform': manifest['platform'], 'databasePlatform': manifest['preflightDatabasePlatform']}
    container = None
    try:
        report['fixtureVerification'] = verify_fixture(args.specimen.resolve(), manifest, stage)
        print('Pinned sanitised specimen and inner files verified.', flush=True)
        container = docker('run', '-d', '--name', 'orchids-historical-'+token[:12],
            '--label', 'org.orchidapp.fixture-token='+token, '--network', 'none',
            '--platform', manifest['preflightDatabasePlatform'], '-e', 'MARIADB_ROOT_PASSWORD='+PASSWORD,
            manifest['mariadbImage'], '--event-scheduler=OFF', '--max-allowed-packet=268435456').decode().strip()
        info = owned(container, token)
        report['databaseImageId'] = info['Image']
        for attempt in range(60):
            ping = subprocess.run(['docker', 'exec', '--env', 'MYSQL_PWD='+PASSWORD, container,
                'mariadb', '--protocol=tcp', '--host=127.0.0.1', '--user=root', '--execute=SELECT 1'],
                capture_output=True)
            if ping.returncode == 0:
                break
            time.sleep(1)
        else:
            raise RuntimeError('Final MariaDB TCP server did not become ready')
        docker('cp', str(stage/'orchids.sql'), container+':/tmp/specimen.sql')
        docker('exec', '--env', 'MYSQL_PWD='+PASSWORD, container, 'sh', '-c',
               'mariadb --user=root --max-allowed-packet=256M < /tmp/specimen.sql > /tmp/import.log 2>&1')
        history_sql = ('SELECT versionId,HEX(scriptName),HEX(checksum),appliedAt '
                       'FROM orchids.schemaversion ORDER BY versionId;')
        history_before = query(container, history_sql)
        if hashlib.sha256(history_before.encode()).hexdigest() != manifest['historySha256']:
            raise ValueError('Restored historical ledger differs from the reviewed specimen')
        counts_before = {name: int(query(container, f'SELECT COUNT(*) FROM orchids.`{name}`;'))
                         for name in manifest['rowCounts']}
        if counts_before != manifest['rowCounts']:
            raise ValueError('Restored specimen row counts differ')
        history = {bytes.fromhex(line.split('\t')[0]).decode(): line.split('\t')[1]
                   for line in query(container, 'SELECT HEX(scriptName),checksum FROM orchids.schemaversion;').splitlines()}
        review = ledger_review(history, REPO/'database/migrations')
        (output/'ledger-review.json').write_text(json.dumps(review, indent=2))
        report['ledgerReview'] = {'rows': len(history),
            'missingAppliedFiles': sum(r['status'] == 'missing' for r in review),
            'rawChecksumMismatches': sum(r['status'] == 'checksum-mismatch' for r in review),
            'lfDiagnosticMismatches': sum(r.get('lfDiagnosticMatches') is False for r in review),
            'normalizationApplied': False}
        print('Historical database restored; running canonical PlanOnly with unchanged history.', flush=True)
        proxy_output = stage/'client-proxy'
        build = subprocess.run(['dotnet', 'publish', str(HERE/'ClientProxy/ClientProxy.csproj'),
            '--configuration', 'Release', '--output', str(proxy_output)], capture_output=True, timeout=240)
        (output/'proxy-build.log').write_bytes(build.stdout+build.stderr)
        if build.returncode:
            raise RuntimeError('Native owned-container client proxy build failed')
        proxy = proxy_output/('ClientProxy.exe' if os.name == 'nt' else 'ClientProxy')
        env = {k: v for k, v in os.environ.items() if not k.upper().startswith(('MARIADB_', 'MYSQL_'))}
        env.update(MARIADB_HOST='127.0.0.1', MARIADB_PORT='3306', MARIADB_USER='root',
            MARIADB_PASSWORD=PASSWORD, MARIADB_DATABASE='orchids',
            ORCHID_FIXTURE_CONTAINER_ID=container, ORCHID_FIXTURE_TOKEN=token)
        plan = subprocess.run(['pwsh', '-NoProfile', '-File', str(REPO/'database/scripts/Apply-Migrations.ps1'),
            '-MariaDbExe', str(proxy), '-PlanOnly'], env=env, cwd=REPO, capture_output=True, timeout=180)
        (output/'migration-preflight.log').write_bytes(plan.stdout+plan.stderr)
        report['canonicalRunnerExitCode'] = plan.returncode
        report['historyUnchanged'] = query(container, history_sql) == history_before
        report['rowCountsUnchanged'] = all(int(query(container, f'SELECT COUNT(*) FROM orchids.`{name}`;')) == count
                                            for name, count in counts_before.items())
        if not report['historyUnchanged'] or not report['rowCountsUnchanged']:
            raise RuntimeError('Read-only preflight unexpectedly changed the specimen')
        report['status'] = plan_status(plan.returncode, (plan.stdout+plan.stderr).decode('utf-8', 'replace'))
        if report['status'] == 'blocked':
            report['blocker'] = 'Canonical migration policy rejects this historical ledger; review exact log/ledger evidence. No SQL/history repair or upgrade was attempted.'
        elif report['status'] == 'failed':
            report['error'] = 'Canonical preflight execution failed; inspect log before attributing this to migration compatibility.'
        if args.adopt_and_migrate:
            from schema_contract import snapshot, identity, require_schema, application_schema
            from legacy_adoption import adopt, ARCHIVE, HISTORY_SQL
            if report['status'] != 'blocked':
                raise ValueError('Reviewed legacy path requires the expected original policy refusal')
            report['originalCanonicalRunnerExitCode'] = report.pop('canonicalRunnerExitCode')
            report['originalReadOnlyHistoryUnchanged'] = report.pop('historyUnchanged')
            report['originalReadOnlyRowCountsUnchanged'] = report.pop('rowCountsUnchanged')
            report['status'] = 'failed'
            report['phase'] = 'reviewed fixture adoption and actual database migrations'
            contract = json.loads((HERE/'legacy-adoption.json').read_text())
            schema_before = snapshot(lambda sql: query(container, sql))
            require_schema(schema_before, contract['schemaIdentity'])
            (output/'schema-identity.json').write_text(json.dumps(
                identity(schema_before), indent=2))
            # Real-server negative acceptance check. This view exists only in
            # our new private fixture; no history/data mutation is needed.
            owned(container, token)
            query(container, 'CREATE VIEW orchids.ci_unreviewed_adoption_probe AS SELECT 1 AS witness;')
            try:
                try:
                    adopt(lambda sql: query(container, sql), snapshot(lambda sql: query(container, sql)),
                        contract, manifest, lambda: owned(container, token))
                except ValueError as rejection:
                    if 'schema differs' not in str(rejection):
                        raise
                else:
                    raise ValueError('Adoption incorrectly accepted unreviewed schema')
                if query(container, history_sql) != history_before:
                    raise ValueError('Rejected adoption changed original history')
                report['unreviewedSchemaRejectedWithHistoryUnchanged'] = True
            finally:
                owned(container, token)
                query(container, 'DROP VIEW orchids.ci_unreviewed_adoption_probe;')
            schema_before = snapshot(lambda sql: query(container, sql))
            require_schema(schema_before, contract['schemaIdentity'])
            data_tables = [name for name in manifest['rowCounts'] if name != 'schemaversion']
            data_before = data_checksum(container, data_tables)
            report['applicationDataSha256Before'] = data_before
            report['adoption'] = adopt(lambda sql: query(container, sql), schema_before, contract,
                manifest, lambda: owned(container, token))
            print('Reviewed schema accepted; original ledger archived unchanged. Testing actual forward migrations.', flush=True)
            runner = ['pwsh', '-NoProfile', '-File', str(REPO/'database/scripts/Apply-Migrations.ps1'),
                      '-MariaDbExe', str(proxy)]
            runs = []
            for label, options in [('adopted-plan', ['-PlanOnly']), ('apply', []), ('second-apply', [])]:
                owned(container, token)
                if label == 'apply':
                    report['migrationApplicationAttempted'] = True
                run = subprocess.run(runner+options, env=env, cwd=REPO, capture_output=True, timeout=240)
                log = (run.stdout+run.stderr).decode('utf-8', 'replace')
                (output/(label+'.log')).write_bytes(run.stdout+run.stderr)
                runs.append({'step': label, 'exitCode': run.returncode})
                if run.returncode:
                    raise RuntimeError('Canonical migration '+label+' failed; inspect preserved log')
                plain = re.sub(r'\x1b\[[0-9;]*m', '', log)
                prefix = 'Pending: ' if label == 'adopted-plan' else 'Applied: '
                names = [line[len(prefix):].split(' [')[0].strip() for line in plain.splitlines()
                         if line.startswith(prefix)]
                expected = contract['expectedForwardMigrations'] if label != 'second-apply' else []
                if names != expected:
                    raise ValueError('Unexpected canonical migration inventory for '+label)
            report['adoptedCanonicalRuns'] = runs
            schema_after = snapshot(lambda sql: query(container, sql))
            (output/'schema-after.json').write_text(json.dumps(schema_after, indent=2))
            report['postUpgradeSchemaSha256'] = require_schema(application_schema(schema_after),
                contract['postUpgradeSchemaIdentity'])
            if report['postUpgradeSchemaSha256'] != contract['postUpgradeSchemaSha256']:
                raise ValueError('Post-upgrade schema hash differs')
            archived = query(container, HISTORY_SQL.replace('orchids.schemaversion', f'orchids.`{ARCHIVE}`'))
            report['archivedHistoryUnchanged'] = archived == history_before
            data_after = data_checksum(container, data_tables)
            report['applicationDataSha256After'] = data_after
            report['applicationDataUnchanged'] = data_after == data_before
            report['applicationRowCountsUnchanged'] = all(int(query(container,
                f'SELECT COUNT(*) FROM orchids.`{name}`;')) == manifest['rowCounts'][name] for name in data_tables)
            new_history = query(container, 'SELECT scriptName,checksum FROM orchids.schemaversion ORDER BY scriptName;')
            expected_history = {report['adoption']['marker']: report['adoption']['contractSha256']}
            expected_history.update({name: digest(REPO/'database/migrations'/name)
                                     for name in contract['expectedForwardMigrations']})
            actual_history = dict(line.split('\t') for line in new_history.splitlines())
            report['activeLedgerExact'] = actual_history == expected_history
            if not all(report[key] for key in ('archivedHistoryUnchanged', 'applicationDataUnchanged',
                                               'applicationRowCountsUnchanged', 'activeLedgerExact')):
                raise ValueError('Historical retention or active ledger verification failed')
            report['databaseMigrationAcceptance'] = 'passed: four actual migrations; second apply does nothing'
            report['fullUpgradeAcceptance'] = 'not performed: application package, app-only update and recovery still required'
            report['status'] = 'passed'
            report.pop('blocker', None)
    except Exception as error:
        report['status'] = 'failed'
        report['error'] = str(error)
    finally:
        if container:
            try:
                owned(container, token)
                docker('rm', '-f', '-v', container)
                report['cleanup'] = 'owned container and anonymous volume removed'
            except Exception as error:
                report['cleanupError'] = str(error)
                report['status'] = 'failed'
        report['finishedUtc'] = datetime.now(timezone.utc).isoformat()
        (output/'report.json').write_text(json.dumps(report, indent=2))
    print('Historical preflight: '+report['status']+'; evidence: '+str(output/'report.json'), flush=True)
    return 0 if report['status'] == 'passed' else 2


if __name__ == '__main__':
    raise SystemExit(main())
