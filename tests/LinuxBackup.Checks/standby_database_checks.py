"""Data-stage refusal/failure policy using synthetic SQL and process adapters."""
from contextlib import contextmanager
import json
import os
from pathlib import Path
import sys
from types import SimpleNamespace
import unittest
from unittest.mock import MagicMock, patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'infrastructure/backups'))
import standby_database as d
import standby_checks as fixtures


class DatabasePolicy(unittest.TestCase):
    def test_character_profile_requires_source_defaults_not_new_uca_defaults(self):
        valid = 'utf8mb4\tutf8mb4_general_ci\tutf8mb4=utf8mb4_general_ci'
        with patch.object(d, 'query', return_value=[valid]):
            d.check_character_settings({}, {})
        for response in ([], [valid, valid], ['utf8mb4\tutf8mb4_uca1400_ai_ci\tutf8mb4=utf8mb4_general_ci'],
                         ['utf8mb4\tutf8mb4_general_ci\tutf8mb4=utf8mb4_uca1400_ai_ci']):
            with patch.object(d, 'query', return_value=response):
                with self.assertRaises(d.b.BackupError):
                    d.check_character_settings({}, {})

    def setUp(self):
        self.fixture = fixtures.Standby('test_prepare_checks_and_stages_without_accepting_or_importing')
        self.fixture.setUp()
        self.c = self.fixture.c
        self.generation = Path(self.fixture.prepare()['generation'])
        self.snapshot = self.fixture.snapshot
        database_root = self.fixture.root / 'orchidapp-standby-db-test'
        database_root.mkdir(mode=0o700)
        self.c.update(database_root=database_root, server_uid=database_root.stat().st_uid,
                      server_gid=database_root.stat().st_gid, server_user='synthetic',
                      required_server_series='11.8', tools={'mariadb': 'never-connect-live'})
        self.process = MagicMock()
        self.process.poll.return_value = None
        self.imports = []
        self.events = []
        # Windows needs the POSIX API adapter, but on Linux retain the real UID
        # so real protected-file ownership checks continue to exercise correctly.
        self.invoking_uid = os.geteuid() if hasattr(os, 'geteuid') else 123

    def tearDown(self):
        self.fixture.tearDown()

    @contextmanager
    def running(self, c, native):
        self.events.append('start-owned')
        try:
            yield self.process
        finally:
            self.events.append('stop-owned')

    def query(self, c, native, sql):
        if sql.startswith('SELECT @@datadir'):
            return ['\t'.join([native['datadir'] + '/', native['socket'], '1', 'OFF', str(native['server_id']), '11.8.6-fixture'])]
        if sql == 'SHOW DATABASES;':
            return ['mysql', 'sys', 'information_schema', 'performance_schema']
        if sql.startswith('ALTER USER'):
            return []
        if sql.startswith("SELECT CONCAT('plants/'"):
            return self.fixture.manifest['required_photos']
        raise AssertionError('Unexpected fixture query')

    def imported(self, args, **kw):
        self.imports.append(kw['stdin'].name)
        self.assertIn('--protocol=socket', args)
        self.assertFalse(any(a.startswith('--host=') or a.startswith('--port=') for a in args))
        return SimpleNamespace(returncode=0, stderr=b'')

    def restore(self):
        with patch.object(d, 'configure', return_value=self.c), patch.object(d, 'initialise'), \
             patch.object(d, 'running_candidate', self.running), patch.object(d, 'query', self.query), \
             patch.object(d, 'inventory', return_value={'base_table_rows': {'orchids': {'witness': 1}, 'EnergyMonitoring': {'witness': 1}}}), \
             patch.object(d.subprocess, 'run', self.imported), patch.object(d.os, 'geteuid', return_value=self.invoking_uid, create=True):
            return d.restore_data(self.c, self.snapshot)

    def test_restores_only_selected_sql_and_stops_before_pending_result(self):
        result = self.restore()
        self.assertEqual(result['result'], 'DATA_RESTORED_APPLICATION_PENDING')
        self.assertEqual([Path(p).name for p in self.imports], ['orchids.sql', 'EnergyMonitoring.sql'])
        self.assertNotIn('accounts.sql', str(self.imports))
        self.assertEqual(self.events[-1], 'stop-owned')
        self.assertFalse((self.c['state_root'] / 'last-accepted.json').exists())
        state = json.loads((self.generation / 'state.json').read_text())
        self.assertFalse(state['accepted'])
        self.assertEqual(state['phase'], 'DATA_RESTORED_APPLICATION_PENDING')

    def test_data_stage_cannot_be_retried_on_existing_generation(self):
        self.restore()
        with self.assertRaises(d.b.BackupError):
            self.restore()
        self.assertEqual(len(self.imports), 2)

    def test_payload_changed_refuses_sql(self):
        (self.generation / 'payload/databases/orchids.sql').write_text('tampered')
        with self.assertRaises(d.b.BackupError):
            self.restore()
        self.assertEqual(self.imports, [])

    def test_low_database_space_refuses_initialisation(self):
        with patch.object(d.shutil, 'disk_usage', return_value=SimpleNamespace(free=0)):
            with self.assertRaises(d.b.BackupError):
                self.restore()
        self.assertFalse(list(self.c['database_root'].iterdir()))

    def test_running_server_identity_mismatch_refuses_sql_and_stops(self):
        with patch.object(d, 'identity', side_effect=d.b.BackupError('wrong endpoint')):
            with self.assertRaises(d.b.BackupError):
                self.restore()
        self.assertEqual(self.imports, [])
        self.assertEqual(self.events[-1], 'stop-owned')
        state = json.loads((self.generation / 'state.json').read_text())
        self.assertEqual(state['phase'], 'DATABASE_FAILED')

    def test_partial_import_keeps_private_diagnostic_and_failure_marker(self):
        def failed(args, **kw):
            self.imports.append(kw['stdin'].name)
            return SimpleNamespace(returncode=1, stderr=b'synthetic secret SQL diagnostic')
        with patch.object(d, 'configure', return_value=self.c), patch.object(d, 'initialise'), \
             patch.object(d, 'running_candidate', self.running), patch.object(d, 'query', self.query), \
             patch.object(d.subprocess, 'run', failed), patch.object(d.os, 'geteuid', return_value=self.invoking_uid, create=True):
            with self.assertRaises(d.b.BackupError):
                d.restore_data(self.c, self.snapshot)
        state = json.loads((self.generation / 'state.json').read_text())
        self.assertEqual(state['phase'], 'DATABASE_FAILED')
        self.assertNotIn('synthetic secret', state['error'])
        self.assertIn('synthetic secret', (self.generation / 'import-orchids-error.log').read_text())
        self.assertEqual(self.events[-1], 'stop-owned')

    def test_previous_accepted_pointer_is_unchanged(self):
        pointer = self.c['state_root'] / 'last-accepted.json'
        pointer.write_text('synthetic previously accepted state')
        before = pointer.read_bytes()
        self.restore()
        self.assertEqual(pointer.read_bytes(), before)

    def test_identity_checks_all_isolation_fields(self):
        native = {'datadir': str(self.fixture.root / 'isolated-data'), 'socket': '/synthetic/only.sock', 'server_id': 321}
        valid = [native['datadir'], native['socket'], '1', 'OFF', '321', '11.8.6-test']
        for index, value in ((0, '/var/lib/mysql'), (1, '/run/mysqld/mysqld.sock'), (2, '0'),
                             (3, 'ON'), (4, '999'), (5, '10.11.14-test')):
            changed = list(valid)
            changed[index] = value
            with patch.object(d, 'query', return_value=['\t'.join(changed)]):
                with self.assertRaises(d.b.BackupError):
                    d.identity(self.c, native, self.process)

    def test_dead_candidate_refused_before_query(self):
        self.process.poll.return_value = 1
        with patch.object(d, 'query') as query:
            with self.assertRaises(d.b.BackupError):
                d.identity(self.c, {}, self.process)
            query.assert_not_called()

    def test_private_target_password_not_in_client_arguments(self):
        path = self.generation / 'test.cnf'
        d.write_client(path, '/synthetic/socket', 'synthetic-private-password')
        args = d.client(self.c, {'admin_defaults': str(path), 'socket': '/synthetic/socket'})
        self.assertNotIn('synthetic-private-password', str(args))
        self.assertTrue(args[1].startswith('--defaults-file='))
        self.assertIn('synthetic-private-password', path.read_text())


if __name__ == '__main__':
    unittest.main()
