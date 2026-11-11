"""Explicit Linux maintenance operation for the single reviewed Pi 1 ledger.

No migration execution, credential discovery, service control or automatic retry.
The fixture-only adoption tool is never imported or invoked.
"""
import argparse
from contextlib import contextmanager
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import queue
import re
import signal
import stat
import subprocess
import sys
import threading
import uuid

ROOT = Path(__file__).resolve().parents[2]
# Share the exact metadata validator, without importing fixture execution code.
spec = importlib.util.spec_from_file_location(
    'historical_schema_contract', ROOT/'tests/HistoricalUpgrade.Checks/schema_contract.py')
schema = importlib.util.module_from_spec(spec)
spec.loader.exec_module(schema)
REVIEW_SHA = 'df128c98d01f60129251c3d38e04edb6ae6c5a1faa4ebcb460f6baf5c17c3fb6'
CONTRACT = {'formatVersion': 1, 'scope': 'pi1-live-ledger-adoption',
            'reviewedFixtureContractSha256': REVIEW_SHA, 'originalRows': 245}
CONTRACT_SHA = schema.checksum(CONTRACT)
ARCHIVE = 'schemaversion_legacy_pi_130'
STAGING = '_schemaversion_adopting_pi130'
MARKER = 'baseline:v1:202606041820'
REQUIRED_WRITERS = {'orchidapp.service', 'orchidapp-environment-importer.service',
                    'orchidapp-environment-importer.timer'}
HISTORY = ('SELECT versionId,HEX(scriptName),HEX(checksum),appliedAt '
           'FROM orchids.`{table}` ORDER BY versionId;')
OBJECTS = ("SELECT TABLE_NAME FROM information_schema.TABLES WHERE TABLE_SCHEMA='orchids' "
           f"AND TABLE_NAME IN ('schemaversion','{ARCHIVE}','{STAGING}') ORDER BY TABLE_NAME;")


def require(ok, message):
    if not ok:
        raise ValueError(message)


def digest(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024*1024), b''):
            h.update(chunk)
    return h.hexdigest()


def review():
    value = json.loads((ROOT/'tests/HistoricalUpgrade.Checks/legacy-adoption.json').read_text())
    require(schema.checksum(value) == REVIEW_SHA, 'Reviewed contract changed; new review required')
    return value


def forward_inventory(contract):
    folder = ROOT/'database/migrations'
    names = sorted(p.name for p in folder.glob('*.sql') if p.name[:12] > '202606041820')
    require(names == contract['expectedForwardMigrations'], 'Forward migration inventory changed')
    return {name: digest(folder/name) for name in names}


class Client:
    """One non-reconnecting native session holds the advisory lock across DDL.

    No --force: a SQL error terminates the batch before its success sentinel.
    Native diagnostics stay private; they can include account/configuration data.
    """
    def __init__(self, socket, *, popen=subprocess.Popen):
        self.process = popen([
            'mariadb', '--no-defaults', '--protocol=SOCKET', '--socket='+socket,
            '--user=root', '--database=orchids', '--skip-reconnect', '--batch',
            '--skip-column-names', '--raw', '--unbuffered',
            '--default-character-set=utf8mb4', '--connect-timeout=5'],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
            env={k: v for k, v in os.environ.items()
                 if not k.upper().startswith(('MYSQL_', 'MARIADB_'))})
        self.lines = queue.Queue()
        def read():
            for line in self.process.stdout:
                self.lines.put(line)
            self.lines.put(None)
        self.reader = threading.Thread(target=read, daemon=True)
        self.reader.start()

    def query(self, sql):
        token = 'orchid_'+uuid.uuid4().hex
        require(self.process.poll() is None, 'Database session lost; inspect state before any retry')
        self.process.stdin.write((sql+"\nSELECT '"+token+"';\n").encode())
        self.process.stdin.flush()
        rows = []
        while True:
            try:
                line = self.lines.get(timeout=60)
            except queue.Empty:
                raise RuntimeError('Database command timed out; inspect state before any retry') from None
            require(line is not None, 'Database command failed; inspect state before any retry')
            if line.rstrip(b'\r\n') == token.encode():
                return b''.join(rows).decode('utf-8')
            rows.append(line)

    def close(self):
        if self.process.poll() is None:
            self.process.terminate()
        try:
            self.process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            self.process.kill()
            self.process.wait()
        self.process.stdin.close()
        self.reader.join(timeout=10)
        self.process.stdout.close()


def identity(query):
    parts = query('SELECT @@hostname,@@server_id,@@version,@@socket,DATABASE(),CURRENT_USER();').strip().split('\t')
    require(len(parts) == 6 and 'MariaDB' in parts[2] and parts[2].startswith('10.11.') and
            parts[4:] == ['orchids', 'root@localhost'], 'Unsupported server/database/account')
    return dict(zip(('hostname', 'serverId', 'version', 'socket', 'database', 'account'), parts))


def original(query, table, contract):
    value = query(HISTORY.format(table=table))
    require(len(value.splitlines()) == 245 and
            hashlib.sha256(value.encode()).hexdigest() == contract['originalHistorySha256'],
            'Original 245-row ledger differs')
    return value


def starting_schema(query, contract):
    value = schema.snapshot(query)
    require(schema.require_schema(value, contract['schemaIdentity']) == contract['schemaSha256'],
            'Historical schema hash differs')
    return value


def inspect(query, contract):
    """Read-only classification; staged/ambiguous states are never repaired."""
    objects = set(query(OBJECTS).splitlines())
    if STAGING in objects:
        return {'state': 'interrupted-staging', 'action': 'Keep writers stopped; review or restore. Do not retry.'}
    if objects == {'schemaversion'}:
        original(query, 'schemaversion', contract)
        starting_schema(query, contract)
        return {'state': 'original', 'originalRowsPreserved': 245}
    if objects == {'schemaversion', ARCHIVE}:
        original(query, ARCHIVE, contract)
        active = query('SELECT scriptName,checksum FROM orchids.schemaversion ORDER BY scriptName;').splitlines()
        require(active == [MARKER+'\t'+CONTRACT_SHA],
                'Active ledger changed (possibly forward migrations/pending marker); use canonical plan and review')
        # Archive metadata is exactly the original ledger metadata after rename.
        value = schema.snapshot(query)
        categories = {'tables', 'columns', 'indexes', 'foreignKeys', 'referentialRules', 'checks', 'partitions'}
        historical = {k: [r.replace(ARCHIVE+'\t', 'schemaversion\t', 1)
                          for r in rows if k not in categories or r.split('\t')[0] != 'schemaversion']
                      for k, rows in value.items()}
        # Lexical ordering changes when the archived table is renamed back in memory.
        for k in categories:
            # Preserve original within-table ordering (ordinal positions are numeric).
            groups = {}
            for row in historical[k]:
                groups.setdefault(row.split('\t')[0], []).append(row)
            historical[k] = [r for name in sorted(groups) for r in groups[name]]
        require(schema.require_schema(historical, contract['schemaIdentity']) == contract['schemaSha256'],
                'Archived/historical structure differs')
        active_schema = {k: [r for r in rows if k not in categories or r.split('\t')[0] != ARCHIVE]
                         for k, rows in value.items()}
        archive_table = next(r.split('\t') for r in value['tables'] if r.split('\t')[0] == ARCHIVE)
        for i, row in enumerate(active_schema['tables']):
            parts = row.split('\t')
            if parts[0] == 'schemaversion':
                require(parts[-1] == 'Pi 1 adoption '+CONTRACT_SHA, 'Active ledger contract comment differs')
                parts[-1] = archive_table[-1]
                active_schema['tables'][i] = '\t'.join(parts)
        require(schema.require_schema(active_schema, contract['schemaIdentity']) == contract['schemaSha256'],
                'Active ledger structure differs')
        return {'state': 'adopted', 'originalRowsPreserved': 245, 'contractSha256': CONTRACT_SHA}
    raise ValueError('Missing or ambiguous adoption objects; keep writers stopped and review')


def unit_stopped_masked(unit):
    require(re.fullmatch(r'[A-Za-z0-9_@.:-]+\.(service|timer)', unit), 'Invalid writer unit')
    p = subprocess.run(['systemctl', 'show', unit,
                        '--property=LoadState,ActiveState,SubState,UnitFileState'],
                       capture_output=True, text=True, timeout=15, check=True)
    values = dict(line.split('=', 1) for line in p.stdout.splitlines() if '=' in line)
    require(values.get('LoadState') == 'masked' and values.get('ActiveState') == 'inactive' and
            values.get('SubState') == 'dead' and values.get('UnitFileState') in ('masked', 'masked-runtime'),
            'Every declared writer service/timer must be stopped and masked')


def prerequisites(query, evidence, contract):
    require(evidence.get('formatVersion') == 1 and evidence.get('contractSha256') == CONTRACT_SHA,
            'Approval is not bound to this adoption contract')
    require(evidence.get('target') == identity(query), 'Target identity differs from approval')
    require(any(row.startswith('GRANT ALL PRIVILEGES ON *.* TO ') for row in
                query('SHOW GRANTS FOR CURRENT_USER;').splitlines()),
            'Reviewed administrative account must have global ALL PRIVILEGES')
    require(evidence.get('forwardMigrations') == forward_inventory(contract), 'Approved migration hashes differ')
    for key in ('implementationApproved', 'allWritersIdentified', 'schedulersDisabled',
                'administrativeAccessIsolated', 'recoverySetConsistent', 'restoreTestPassed', 'offDeviceCopyVerified'):
        require(evidence.get(key) is True, 'Required approval/recovery attestation missing: '+key)
    for key in ('approvedBy', 'restoreTestEvidence', 'offDeviceEvidence'):
        require(isinstance(evidence.get(key), str) and evidence[key].strip(), 'Missing evidence reference: '+key)
    archive = Path(evidence['recoveryArchive'])
    require(archive.is_absolute() and archive.is_file() and not archive.is_symlink(), 'Invalid recovery archive')
    require(re.fullmatch('[a-f0-9]{64}', evidence['recoverySha256']) and
            digest(archive) == evidence['recoverySha256'], 'Recovery archive hash differs')
    units = evidence.get('writerUnits', [])
    require(isinstance(units, list) and REQUIRED_WRITERS.issubset(units) and len(units) == len(set(units)),
            'Explicit complete writer unit inventory required')
    for unit in units:
        unit_stopped_masked(unit)
    require(query('SELECT @@GLOBAL.read_only,@@GLOBAL.event_scheduler;').strip() in ('1\tOFF', '1\tDISABLED'),
            'Server read_only must be ON and event_scheduler OFF/DISABLED; tool never changes them')
    require(query('SELECT COUNT(*) FROM information_schema.PROCESSLIST '
                  'WHERE ID<>CONNECTION_ID();').strip() == '0',
            'Other database sessions exist; isolate all clients including administrative users')


@contextmanager
def journal(path, evidence):
    """Exclusive durable local intent blocks both concurrent use and blind retries."""
    path.mkdir(mode=0o700, parents=False, exist_ok=False)
    sync_directory(path.parent)
    def record(name, value):
        with (path/name).open('x', encoding='utf-8') as f:
            json.dump(value, f, sort_keys=True, indent=2)
            f.flush()
            os.fsync(f.fileno())
        sync_directory(path)
    record('intent.json', {'contractSha256': CONTRACT_SHA, 'evidenceSha256': schema.checksum(evidence),
                           'target': evidence['target'], 'status': 'started'})
    yield record


def sync_directory(path):
    # Operational CLI is Linux-only. Windows can run pure/isolated SQL checks.
    if sys.platform == 'linux':
        fd = os.open(path, os.O_RDONLY | os.O_DIRECTORY)
        try:
            os.fsync(fd)
        finally:
            os.close(fd)


def apply(query, contract, evidence, journal_path):
    require(query("SELECT GET_LOCK('orchidapp.pi130.adoption',0);").strip() == '1',
            'Another adoption session owns the lock')
    # No release/reconnect until session disposal, including ambiguous SQL failures.
    require(inspect(query, contract)['state'] == 'original', 'Already adopted or interrupted; no automatic retry')
    prerequisites(query, evidence, contract)
    before = original(query, 'schemaversion', contract)
    with journal(journal_path, evidence) as record:
        query(f'CREATE TABLE orchids.`{STAGING}` LIKE orchids.schemaversion;')
        query(f"ALTER TABLE orchids.`{STAGING}` COMMENT='Pi 1 adoption {CONTRACT_SHA}';")
        query(f"INSERT INTO orchids.`{STAGING}`(scriptName,checksum) VALUES ('{MARKER}','{CONTRACT_SHA}');")
        require(query(f'SELECT scriptName,checksum FROM orchids.`{STAGING}`;').strip() == MARKER+'\t'+CONTRACT_SHA,
                'Staged marker differs')
        # Recheck maintenance isolation, history and structure immediately before swap.
        prerequisites(query, evidence, contract)
        require(original(query, 'schemaversion', contract) == before, 'Ledger changed while staging')
        # Remove only our staging metadata from the snapshot; all other objects stay checked.
        value = schema.snapshot(query)
        categories = {'tables', 'columns', 'indexes', 'foreignKeys', 'referentialRules', 'checks', 'partitions'}
        value = {k: [r for r in rows if k not in categories or r.split('\t')[0] != STAGING]
                 for k, rows in value.items()}
        require(schema.require_schema(value, contract['schemaIdentity']) == contract['schemaSha256'],
                'Schema changed while staging')
        record('staged.json', {'status': 'staged', 'originalRows': 245})
        query(f'RENAME TABLE orchids.schemaversion TO orchids.`{ARCHIVE}`, '
              f'orchids.`{STAGING}` TO orchids.schemaversion;')
        result = inspect(query, contract)
        require(result['state'] == 'adopted', 'Post-swap verification failed')
        record('verified.json', result)
        return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=('inspect', 'apply'))
    parser.add_argument('--socket', required=True)
    parser.add_argument('--approval', type=Path)
    parser.add_argument('--journal', type=Path)
    args = parser.parse_args()
    require(sys.platform == 'linux' and os.geteuid() == 0, 'Linux root with local socket authentication required')
    require(Path(args.socket).is_absolute() and stat.S_ISSOCK(Path(args.socket).stat().st_mode), 'Local socket required')
    require(args.mode != 'apply' or (args.approval and args.journal and args.journal.is_absolute()),
            'Apply requires explicit approval file and new absolute journal directory')
    if args.mode == 'apply':
        parent = args.journal.parent
        require(parent.resolve() == parent and parent.stat().st_uid == 0 and parent.stat().st_mode & 0o022 == 0,
                'Journal parent must be a root-owned protected real directory')
    contract = review()
    client = Client(args.socket)
    # Termination unwinds the connection, preserves journal/DDL, never retries.
    def terminate(signum, frame):
        raise KeyboardInterrupt
    signal.signal(signal.SIGTERM, terminate)
    try:
        target = identity(client.query)
        if args.mode == 'inspect':
            result = inspect(client.query, contract)
            result.update(target=target, contractSha256=CONTRACT_SHA,
                          forwardMigrations=forward_inventory(contract))
        else:
            require(not args.approval.is_symlink() and args.approval.stat().st_uid == 0 and
                    args.approval.stat().st_mode & 0o077 == 0,
                    'Approval file must be private and not a symlink')
            result = apply(client.query, contract, json.loads(args.approval.read_text()), args.journal)
        print(json.dumps(result, sort_keys=True, indent=2))
    finally:
        client.close()


if __name__ == '__main__':
    try:
        main()
    except (Exception, KeyboardInterrupt) as error:
        # Never expose native commands/configuration or imply an unsuccessful DDL rolled back.
        print('Adoption stopped. Keep writers stopped; inspect database and journal before any further action.', file=sys.stderr)
        if isinstance(error, ValueError):
            print(str(error), file=sys.stderr)
        sys.exit(1)
