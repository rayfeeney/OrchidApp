"""Takeover fencing/refresh protection and loopback policy; no live targets."""
from contextlib import contextmanager
import json
from pathlib import Path
import sys
import tempfile
import unittest
import uuid
from unittest.mock import patch, MagicMock

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'infrastructure/backups'))
import standby_takeover as t


class Takeover(unittest.TestCase):
    def test_activation_protects_writes_before_start_and_marker_survives_stop(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            secret = root / 'password'
            secret.write_text('a' * 64)
            c = {'state_root': root, 'publication_archive': root / 'archive', 'dotnet': root / 'dotnet'}
            value = {'record': {'archive': 'fixture.tar.gz', 'sha256': 'hash'},
                     'workspace': str(root / 'workspace'), 'web_dll_sha256': 'hash',
                     'candidate': {}, 'business_tables': {'table': 'original'}, 'password_file': str(secret)}
            @contextmanager
            def running(*_):
                yield object()
            @contextmanager
            def app(*_):
                self.assertTrue((root / 'active-takeover.json').exists())
                yield MagicMock(poll=lambda: None), 5010
            with patch.object(t, 'selected', return_value=(value, root, b'pointer')), \
                 patch.object(t.b, 'digest', return_value='hash'), \
                 patch.object(t.s, 'check_manifest', return_value={}), \
                 patch.object(t.a.p, 'verify', return_value={}), \
                 patch.object(t.j.acceptance, 'verify_workspace'), \
                 patch.object(t.d, 'running_candidate', side_effect=running), \
                 patch.object(t.j.acceptance, 'table_checksums', return_value={'table': 'original'}), \
                 patch.object(t, 'checks', side_effect=app), \
                 patch.object(t.a, 'get', return_value=b'fixture'), patch.object(t.a, 'readiness'), \
                 patch.object(t.time, 'sleep', side_effect=KeyboardInterrupt):
                result = t.activate(c, 'fixture', True)
            self.assertEqual(result['result'], 'TAKEOVER_STOPPED_RESTORE_BLOCKED')
            self.assertTrue((root / 'active-takeover.json').exists())

    def test_live_activation_requires_explicit_fencing_before_read_or_start(self):
        with patch.object(t, 'selected') as selected:
            with self.assertRaises(t.b.BackupError):
                t.activate({}, 'snapshot', False)
            selected.assert_not_called()

    def test_release_requires_primary_acknowledgement(self):
        with patch.object(t, 'selected') as selected:
            with self.assertRaises(t.b.BackupError):
                t.release_unchanged({}, 'snapshot', False)
            selected.assert_not_called()

    def test_active_marker_blocks_refresh_before_any_cloud_or_sql(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / 'active-takeover.json').write_text('{}')
            with patch.object(t.s, 'discover') as discover:
                with self.assertRaises(t.b.BackupError):
                    t.j.refresh({'state_root': root}, {})
                discover.assert_not_called()

    def test_snapshot_path_traversal_rejected_before_files(self):
        with patch.object(t.j, 'read') as read:
            with self.assertRaises(t.b.BackupError):
                t.selected({}, '../unsafe')
            read.assert_not_called()

    def test_takeover_uses_owned_loopback_application_helper(self):
        with patch.object(t.a, 'running_app') as app:
            t.checks({}, 'native', 'workspace', 'secret', 'evidence', 'runtime')
            app.assert_called_once_with({}, 'runtime', 'workspace', 'native', 'secret', 'evidence', port=5010)

    def test_unsupported_port_rejected_before_application_start(self):
        with patch.object(t.a.subprocess, 'Popen') as start:
            with self.assertRaises(t.b.BackupError):
                with t.a.running_app({}, None, None, None, None, None, port=80):
                    pass
            start.assert_not_called()

    def test_release_refuses_new_writes_and_preserves_marker(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            marker = root / 'active-takeover.json'
            marker.write_text(json.dumps({'snapshot': 'fixture'}))
            value = {'record': {'archive': 'fixture.tar.gz', 'sha256': 'hash'},
                     'workspace': str(root / 'workspace'), 'web_dll_sha256': 'hash',
                     'candidate': {}, 'business_tables': {'table': 'original'}}
            @contextmanager
            def running(*_):
                yield object()
            with patch.object(t, 'selected', return_value=(value, root, b'pointer')), \
                 patch.object(t.b, 'digest', return_value='hash'), \
                 patch.object(t.s, 'check_manifest', return_value={}), \
                 patch.object(t.a.p, 'verify', return_value={}), \
                 patch.object(t.j.acceptance, 'verify_workspace'), \
                 patch.object(t.d, 'running_candidate', side_effect=running), \
                 patch.object(t.j.acceptance, 'table_checksums', return_value={'table': 'new writes'}):
                with self.assertRaises(t.b.BackupError):
                    t.release_unchanged({'state_root': root, 'publication_archive': root / 'publication'}, 'fixture', True)
            self.assertTrue(marker.exists())

    def test_cleanup_refuses_workspace_outside_rehearsal_before_any_delete(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            token = uuid.uuid4().hex
            snapshot = 'orchidset-20261114T195324Z-' + uuid.uuid4().hex
            scratch = root / 'takeover-rehearsal'
            native = {'owner_token': 'owner', 'admin_defaults': str(scratch / 'generations' / snapshot / 'candidate-admin.cnf')}
            report = {'result': 'REHEARSAL_STOPPED', 'snapshot': snapshot, 'token': token,
                      'candidate': native, 'workspace': str(root / 'accepted-workspace')}
            with patch.object(t.j, 'read', side_effect=[report, {'candidate': native, 'owner_token': 'owner'}]), \
                 patch.object(t.d, 'owned_target', return_value=root / 'owned-db'), \
                 patch.object(t.shutil, 'rmtree') as delete:
                with self.assertRaises(t.b.BackupError):
                    t.cleanup_rehearsal({'state_root': root, 'application_root': root / 'apps'}, snapshot)
                delete.assert_not_called()


if __name__ == '__main__':
    unittest.main()
