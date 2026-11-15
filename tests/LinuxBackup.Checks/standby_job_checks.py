"""Coordinator failure boundaries and exact-path retention; no deployed targets."""
from contextlib import ExitStack
from datetime import datetime, timedelta, timezone
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
import uuid

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'infrastructure/backups'))
import standby_job as j


class Job(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.c = {'state_root': self.root / 'state', 'application_root': self.root / 'apps',
                  'database_root': self.root / 'db', 'server_uid': getattr(os, 'geteuid', lambda: 0)(),
                  'publication_archive': self.root / 'publication.tar.gz', 'dotnet': self.root / 'dotnet',
                  'view_definer_policy': 'energy-six-v1'}
        for key in ('state_root', 'application_root', 'database_root'):
            self.c[key].mkdir(mode=0o700)
        (self.c['state_root'] / 'generations').mkdir()
        self.mail = {'backup_root': self.c['state_root']}

    def refresh_mocks(self, record):
        stack = ExitStack()
        self.addCleanup(stack.close)
        objects = {}
        for module, name, value in ((j.s, 'discover', record), (j.s, 'prepare', {'snapshot': 'new'}),
                                    (j.d, 'restore_data', {}), (j.a, 'probe', {}),
                                    (j.acceptance, 'accept', {}), (j, 'retain', {'removed': []}),
                                    (j.d, 'configure', self.c), (j, 'notify', True),
                                    (j.reporting, 'accepted', None)):
            objects[name] = stack.enter_context(patch.object(module, name, return_value=value))
        return objects

    def test_complete_run_accepts_before_retention_and_success(self):
        mocks = self.refresh_mocks({'snapshot': 'new'})
        order = []
        for name in ('prepare', 'restore_data', 'probe', 'accept', 'retain', 'notify'):
            value = mocks[name].return_value
            mocks[name].side_effect = lambda *args, _name=name, _value=value, **kw: (order.append(_name), _value)[1]
        result, code = j.refresh(self.c, self.mail)
        self.assertEqual(code, 0)
        self.assertEqual(result['result'], 'SUCCESS')
        self.assertEqual(order, ['prepare', 'restore_data', 'probe', 'accept', 'retain', 'notify'])
        self.assertEqual(j.read(self.c['state_root'] / 'last-restore-success.json')['result'], 'SUCCESS')

    def test_probe_failure_never_accepts_or_cleans_and_reports_failure(self):
        mocks = self.refresh_mocks({'snapshot': 'new'})
        mocks['probe'].side_effect = j.b.BackupError('fixture application failure')
        result, code = j.refresh(self.c, self.mail)
        self.assertEqual((result['result'], code), ('FAILED', 1))
        mocks['accept'].assert_not_called()
        mocks['retain'].assert_not_called()
        mocks['notify'].assert_called_once_with(self.mail, 'failure', 'probe-application')

    def test_no_new_backup_never_reimports(self):
        mocks = self.refresh_mocks(None)
        success_path = self.c['state_root'] / 'last-restore-success.json'
        success_path.write_text('retained successful run evidence')
        result, code = j.refresh(self.c, self.mail)
        self.assertEqual((result['result'], code), ('NO_NEW_BACKUP', 0))
        for name in ('prepare', 'restore_data', 'probe', 'accept', 'retain'):
            mocks[name].assert_not_called()
        self.assertEqual(success_path.read_text(), 'retained successful run evidence')

    def test_pending_email_does_not_invalidate_success(self):
        mocks = self.refresh_mocks({'snapshot': 'new'})
        mocks['notify'].return_value = False
        result, code = j.refresh(self.c, self.mail)
        self.assertEqual((result['result'], code), ('SUCCESS', 2))
        self.assertTrue(result['email_pending'])
        mocks['accept'].assert_called_once()

    def test_failure_after_acceptance_is_not_false_restore_failure(self):
        mocks = self.refresh_mocks({'snapshot': 'new'})
        mocks['notify'].side_effect = OSError('fixture mail-state failure')
        mocks['accepted'].return_value = {'record': {'snapshot': 'new'}}
        result, code = j.refresh(self.c, self.mail)
        self.assertEqual((result['result'], code), ('ACCEPTED_REPORT_PENDING', 2))
        self.assertTrue(all(call.args[1] == 'success' for call in mocks['notify'].call_args_list))

    def test_test_failure_preserves_pointer_and_uses_real_failure_path(self):
        mocks = self.refresh_mocks(None)
        pointer = self.c['state_root'] / 'last-accepted.json'
        pointer.write_text('synthetic prior pointer')
        before = pointer.read_bytes()
        result, code = j.refresh(self.c, self.mail, fail_test=True)
        self.assertEqual((result['result'], code), ('FAILED', 1))
        self.assertEqual(pointer.read_bytes(), before)
        mocks['discover'].assert_not_called()
        mocks['notify'].assert_called_once_with(self.mail, 'failure', 'discover')

    def test_existing_unaccepted_generation_is_not_reused(self):
        mocks = self.refresh_mocks({'snapshot': 'new'})
        (self.c['state_root'] / 'generations/new').mkdir()
        _, code = j.refresh(self.c, self.mail)
        self.assertEqual(code, 1)
        mocks['prepare'].assert_not_called()

    def generation(self, age):
        stamp = datetime.now(timezone.utc) - timedelta(days=age)
        snapshot = 'orchidset-' + stamp.strftime('%Y%m%dT%H%M%SZ') + '-' + uuid.uuid4().hex
        token = uuid.uuid4().hex
        root = self.c['state_root'] / 'generations' / snapshot
        clone = root / ('application-probe-' + token) / 'generations' / snapshot
        clone.mkdir(parents=True)
        record = {'snapshot': snapshot, 'recovery_point': stamp.isoformat()}
        def native(directory):
            target = self.c['database_root'] / ('candidate-' + uuid.uuid4().hex)
            target.mkdir(mode=0o700)
            return {'target': str(target), 'socket': str(target / 'server.sock'),
                    'pid_file': str(target / 'server.pid'), 'owner_token': 'owner',
                    'admin_defaults': str(directory / 'candidate-admin.cnf')}
        original, candidate = native(root), native(clone)
        for directory, sql in ((root, original), (clone, candidate)):
            j.n.atomic_json(directory / 'state.json', {'record': record, 'owner_token': 'owner', 'candidate': sql})
        workspace = self.c['application_root'] / ('probe-' + token)
        workspace.mkdir(mode=0o700)
        value = {'format': 'orchidapp-standby-accepted-v1', 'record': record, 'candidate': candidate,
                 'application_token': token, 'workspace': str(workspace), 'services_started': False}
        j.n.atomic_json(root / 'acceptance.json', value)
        return root, value

    @unittest.skipUnless(os.name == 'posix', 'Production retention requires POSIX ownership/modes')
    def test_retention_keeps_two_and_unknown_diagnostics(self):
        oldest, old_value = self.generation(3)
        previous, previous_value = self.generation(2)
        current, current_value = self.generation(1)
        current_value['previous_snapshot'] = previous.name
        j.n.atomic_json(current / 'acceptance.json', current_value)
        j.n.atomic_json(self.c['state_root'] / 'last-accepted.json', current_value)
        diagnostic = self.c['state_root'] / 'generations/unknown-failed'
        diagnostic.mkdir()
        real_delete = j.shutil.rmtree
        def delete_fixture(path):
            self.assertIn(self.root.resolve(), path.resolve().parents)
            real_delete(path)
        with patch.object(j.s, 'check_record'), \
             patch.object(j.d, 'owned_target', side_effect=lambda c, native: Path(native['target'])), \
             patch.object(j.shutil, 'rmtree', side_effect=delete_fixture) as delete:
            result = j.retain(self.c)
        self.assertEqual(result['removed'], [oldest.name])
        self.assertEqual(len(delete.call_args_list), 4)
        deleted = [call.args[0] for call in delete.call_args_list]
        self.assertIn(oldest, deleted)
        self.assertNotIn(previous, deleted)
        self.assertNotIn(current, deleted)
        self.assertFalse(oldest.exists())
        self.assertTrue(previous.exists() and current.exists())
        self.assertTrue(diagnostic.exists())

    @unittest.skipUnless(os.name == 'posix', 'Production retention requires POSIX ownership/modes')
    def test_retention_refuses_extra_attempts_and_running_candidate(self):
        oldest, value = self.generation(3)
        self.generation(2)
        current, current_value = self.generation(1)
        j.n.atomic_json(self.c['state_root'] / 'last-accepted.json', current_value)
        extra = oldest / ('application-probe-' + uuid.uuid4().hex)
        extra.mkdir()
        with patch.object(j.s, 'check_record'), \
             patch.object(j.d, 'owned_target', side_effect=lambda c, native: Path(native['target'])), \
             patch.object(j.shutil, 'rmtree') as delete:
            self.assertEqual(j.retain(self.c)['retained_for_review'], [oldest.name])
            delete.assert_not_called()
            extra.rmdir()
            Path(value['candidate']['socket']).touch()
            self.assertEqual(j.retain(self.c)['retained_for_review'], [oldest.name])
            delete.assert_not_called()


if __name__ == '__main__':
    unittest.main()
