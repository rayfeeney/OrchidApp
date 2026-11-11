"""Operational adoption policy, interruption and audit checks; no live endpoint."""
import copy
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('live_adoption', ROOT/'database/scripts/adopt_pi130.py')
a = importlib.util.module_from_spec(spec)
spec.loader.exec_module(a)


class Model:
    def __init__(self):
        self.history = ''.join(f'{i}\t616263\t646566\t2026-06-01 12:00:00\n' for i in range(1, 246))
        self.objects = {'schemaversion'}
        self.ddl = []
        self.fail = None
        self.ledger = a.MARKER+'\t'+a.CONTRACT_SHA+'\n'
        self.metadata = {key: [] for key in a.review()['schemaIdentity']}
        self.metadata.update(tables=['plant\tInnoDB\tutf8mb4_unicode_ci\t\t',
                                     'schemaversion\tInnoDB\tutf8mb4_unicode_ci\t\t'],
                             columns=['plant\t1\tid', 'schemaversion\t1\tversionId', 'schemaversion\t2\tscriptName'],
                             indexes=['schemaversion\tPRIMARY'])
        self.contract = {'schemaIdentity': a.schema.identity(self.metadata),
                         'schemaSha256': a.schema.checksum(self.metadata),
                         'originalHistorySha256': hashlib.sha256(self.history.encode()).hexdigest()}

    def snapshot(self, query):
        result = copy.deepcopy(self.metadata)
        for key in ('tables', 'columns', 'indexes'):
            ledger_rows = [r for r in result[key] if r.startswith('schemaversion\t')]
            if a.ARCHIVE in self.objects:
                result[key] += [r.replace('schemaversion\t', a.ARCHIVE+'\t', 1) for r in ledger_rows]
                if key == 'tables':
                    result[key] = [r+'Pi 1 adoption '+a.CONTRACT_SHA if r.startswith('schemaversion\t') else r
                                   for r in result[key]]
            if a.STAGING in self.objects:
                result[key] += [r.replace('schemaversion\t', a.STAGING+'\t', 1) for r in ledger_rows]
            result[key].sort()
        return result

    def query(self, sql):
        if sql == a.OBJECTS:
            return ''.join(name+'\n' for name in sorted(self.objects))
        if sql.startswith('SELECT GET_LOCK'):
            return '1\n'
        if sql.startswith('SELECT versionId'):
            return self.history
        if sql.startswith('SELECT scriptName,checksum'):
            return self.ledger
        if sql.startswith(('CREATE TABLE', 'ALTER TABLE', 'INSERT INTO', 'RENAME TABLE')):
            self.ddl.append(sql)
            # Inject a lost response AFTER the server-side change as well as before.
            if self.fail == ('before', len(self.ddl)):
                raise RuntimeError('injected failure')
            if sql.startswith('CREATE TABLE'):
                self.objects.add(a.STAGING)
            if sql.startswith('RENAME TABLE'):
                self.objects.remove(a.STAGING)
                self.objects.add(a.ARCHIVE)
            if self.fail == ('after', len(self.ddl)):
                raise RuntimeError('injected lost response')
            return ''
        raise AssertionError(sql)


class LiveAdoptionChecks(unittest.TestCase):
    def run_apply(self, model, folder):
        with patch.object(a.schema, 'snapshot', model.snapshot), patch.object(a, 'prerequisites'):
            return a.apply(model.query, model.contract, {'target': {'hostname': 'test'}}, folder/'journal')

    def test_pinned_review_and_exact_four_forward_files(self):
        contract = a.review()
        self.assertEqual(len(a.forward_inventory(contract)), 4)
        self.assertEqual(contract['scope'], 'owned-disposable-fixture-only')
        self.assertNotEqual(a.CONTRACT_SHA, a.REVIEW_SHA)

    def test_preserves_all_245_records_and_uses_one_swap(self):
        model = Model()
        before = model.history
        with tempfile.TemporaryDirectory() as temp:
            result = self.run_apply(model, Path(temp))
            self.assertEqual(result['state'], 'adopted')
            self.assertEqual(result['originalRowsPreserved'], 245)
            self.assertTrue((Path(temp)/'journal/verified.json').is_file())
        self.assertEqual(model.history, before)
        self.assertEqual(len([s for s in model.ddl if s.startswith('RENAME TABLE')]), 1)
        self.assertFalse(any(s.startswith(('UPDATE', 'DELETE', 'DROP')) for s in model.ddl))

    def test_every_write_interruption_preserves_original_and_blocks_retry(self):
        for timing in ('before', 'after'):
            for step in range(1, 5):
                with self.subTest(timing=timing, step=step), tempfile.TemporaryDirectory() as temp:
                    model = Model()
                    before = model.history
                    model.fail = (timing, step)
                    folder = Path(temp)
                    with self.assertRaises(RuntimeError):
                        self.run_apply(model, folder)
                    self.assertEqual(model.history, before)
                    self.assertTrue((folder/'journal/intent.json').exists())
                    self.assertFalse((folder/'journal/verified.json').exists())
                    model.fail = None
                    count = len(model.ddl)
                    with self.assertRaises((ValueError, FileExistsError)):
                        self.run_apply(model, folder)
                    self.assertEqual(len(model.ddl), count)
                    with patch.object(a.schema, 'snapshot', model.snapshot):
                        state = a.inspect(model.query, model.contract)['state']
                    self.assertEqual(state, 'adopted' if step == 4 and timing == 'after' else
                                     'original' if step == 1 and timing == 'before' else 'interrupted-staging')

    def test_wrong_history_count_hash_schema_and_prior_objects_refused_before_write(self):
        for change in ('row', 'hash', 'schema', 'archive', 'staging'):
            with self.subTest(change=change), tempfile.TemporaryDirectory() as temp:
                model = Model()
                if change == 'row': model.history += 'extra\n'
                if change == 'hash': model.history = model.history.replace('616263', '616264', 1)
                if change == 'schema': model.metadata['events'].append('unreviewed event')
                if change == 'archive': model.objects.add(a.ARCHIVE)
                if change == 'staging': model.objects.add(a.STAGING)
                with self.assertRaises(ValueError):
                    self.run_apply(model, Path(temp))
                self.assertEqual(model.ddl, [])

    def test_prerequisite_failure_before_staging_and_again_before_swap(self):
        for failure in (1, 2):
            model = Model()
            with tempfile.TemporaryDirectory() as temp, patch.object(a.schema, 'snapshot', model.snapshot), \
                    patch.object(a, 'prerequisites', side_effect=[ValueError('blocked')] if failure == 1 else [None, ValueError('changed')]):
                with self.assertRaises(ValueError):
                    a.apply(model.query, model.contract, {'target': {}}, Path(temp)/'journal')
            self.assertEqual(len(model.ddl), 0 if failure == 1 else 3)
            self.assertNotIn(a.ARCHIVE, model.objects)

    def test_marker_change_after_swap_is_not_certified(self):
        model = Model()
        model.ledger = 'migration:pending\t'+'a'*64+'\n'
        # Also refuses malformed staged content before swap.
        with tempfile.TemporaryDirectory() as temp:
            with self.assertRaises(ValueError): self.run_apply(model, Path(temp))
            self.assertFalse((Path(temp)/'journal/verified.json').exists())

    def test_no_other_adoption_session_can_write(self):
        model = Model()
        with tempfile.TemporaryDirectory() as temp:
            with self.assertRaises(ValueError):
                a.apply(lambda sql: '0\n', model.contract, {}, Path(temp)/'journal')
            self.assertFalse((Path(temp)/'journal').exists())

    def evidence(self, archive):
        value = dict(formatVersion=1, contractSha256=a.CONTRACT_SHA, target={'server': 'test'},
                     forwardMigrations={'migration.sql': 'b'*64}, recoveryArchive=str(archive),
                     recoverySha256=a.digest(archive), writerUnits=sorted(a.REQUIRED_WRITERS),
                     approvedBy='isolated unit test', restoreTestEvidence='test receipt', offDeviceEvidence='test receipt')
        for key in ('implementationApproved', 'allWritersIdentified', 'schedulersDisabled',
                    'administrativeAccessIsolated', 'recoverySetConsistent', 'restoreTestPassed', 'offDeviceCopyVerified'):
            value[key] = True
        return value

    def test_all_explicit_recovery_approval_target_and_inventory_gates(self):
        with tempfile.TemporaryDirectory() as temp:
            archive = Path(temp)/'backup.tar.gz'
            archive.write_bytes(b'unit test only')
            valid = self.evidence(archive)
            def query(sql):
                if sql.startswith('SHOW GRANTS'): return 'GRANT ALL PRIVILEGES ON *.* TO root@localhost\n'
                return '1\tOFF\n' if 'read_only' in sql else '0\n'
            with patch.object(a, 'identity', return_value=valid['target']), \
                    patch.object(a, 'forward_inventory', return_value=valid['forwardMigrations']), \
                    patch.object(a, 'unit_stopped_masked') as units:
                a.prerequisites(query, valid, {})
                self.assertEqual(units.call_count, 3)
                for key in valid:
                    bad = copy.deepcopy(valid)
                    bad[key] = False if isinstance(bad[key], bool) else ''
                    with self.subTest(key=key), self.assertRaises((ValueError, KeyError, TypeError)):
                        a.prerequisites(query, bad, {})

    def test_server_read_only_scheduler_and_other_sessions(self):
        with tempfile.TemporaryDirectory() as temp:
            archive = Path(temp)/'backup'; archive.write_bytes(b'test')
            evidence = self.evidence(archive)
            with patch.object(a, 'identity', return_value=evidence['target']), \
                    patch.object(a, 'forward_inventory', return_value=evidence['forwardMigrations']), \
                    patch.object(a, 'unit_stopped_masked'):
                for mode in ('0\tOFF\n', '1\tON\n', '1\tOFF\n', 'no-privileges'):
                    with self.subTest(mode=mode), self.assertRaises(ValueError):
                        def query(sql):
                            if sql.startswith('SHOW GRANTS'):
                                return 'GRANT SELECT ON orchids.* TO root@localhost\n' if mode == 'no-privileges' else 'GRANT ALL PRIVILEGES ON *.* TO root@localhost\n'
                            return mode if 'read_only' in sql else '1\n'
                        a.prerequisites(query, evidence, {})

    def test_systemd_requires_inactive_dead_and_masked(self):
        good = 'LoadState=masked\nActiveState=inactive\nSubState=dead\nUnitFileState=masked-runtime\n'
        for value in (good, good.replace('inactive', 'active'), good.replace('dead', 'running'),
                      good.replace('LoadState=masked', 'LoadState=not-found'), good.replace('masked-runtime', 'enabled')):
            with patch.object(a.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0, value, '')):
                if value == good: a.unit_stopped_masked('orchidapp.service')
                else:
                    with self.assertRaises(ValueError): a.unit_stopped_masked('orchidapp.service')
        with self.assertRaises(ValueError): a.unit_stopped_masked('--bad')

    def test_identity_rejects_wrong_version_account_or_database(self):
        good = 'fixture\t1\t10.11.14-MariaDB\t/run/mysqld/mysqld.sock\torchids\troot@localhost\n'
        self.assertEqual(a.identity(lambda sql: good)['database'], 'orchids')
        for value in (good.replace('10.11.', '10.6.'), good.replace('orchids', 'other'),
                      good.replace('root@localhost', 'app@localhost'), good.replace('MariaDB', 'MySQL')):
            with self.assertRaises(ValueError): a.identity(lambda sql: value)

    def test_post_swap_archive_marker_and_active_metadata_are_all_checked(self):
        for change in ('archive', 'marker', 'active-structure'):
            with self.subTest(change=change), tempfile.TemporaryDirectory() as temp:
                model = Model()
                self.run_apply(model, Path(temp))
                snapshot = model.snapshot
                def modified_snapshot(query):
                    value = snapshot(query)
                    if change == 'active-structure':
                        value['columns'].append('schemaversion\t3\tunreviewed')
                    return value
                if change == 'archive': model.history = model.history.replace('616263', '616264', 1)
                if change == 'marker': model.ledger = 'migration:pending\t'+'b'*64+'\n'
                with patch.object(a.schema, 'snapshot', modified_snapshot), self.assertRaises(ValueError):
                    a.inspect(model.query, model.contract)

    def test_transport_frames_success_and_refuses_eof_without_reconnecting(self):
        for succeeds in (True, False):
            with self.subTest(succeeds=succeeds):
                token = 'orchid_'+'a'*32
                process = SimpleNamespace(stdin=io.BytesIO(),
                    stdout=io.BytesIO(b'value\n'+(token+'\n').encode() if succeeds else b''),
                    poll=lambda: None, terminate=lambda: None, wait=lambda **kwargs: None)
                commands = []
                def popen(command, **kwargs):
                    commands.append((command, kwargs))
                    return process
                with patch.object(a.uuid, 'uuid4', return_value=SimpleNamespace(hex='a'*32)):
                    client = a.Client('/test/socket', popen=popen)
                    try:
                        if succeeds: self.assertEqual(client.query('SELECT 1;'), 'value\n')
                        else:
                            with self.assertRaisesRegex(ValueError, 'command failed'): client.query('SELECT 1;')
                        self.assertEqual(len(commands), 1)
                        self.assertIn('--skip-reconnect', commands[0][0])
                        self.assertIn('--protocol=SOCKET', commands[0][0])
                        self.assertNotIn('--force', commands[0][0])
                        self.assertFalse(any(k.startswith(('MYSQL_', 'MARIADB_')) for k in commands[0][1]['env']))
                    finally:
                        client.close()


if __name__ == '__main__':
    unittest.main()
