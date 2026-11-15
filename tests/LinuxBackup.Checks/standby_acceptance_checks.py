"""Acceptance gates and atomic pointer preservation; disposable files only."""
import copy
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'infrastructure/backups'))
import standby_acceptance as x


class Acceptance(unittest.TestCase):
    def test_failed_commit_preserves_previous_pointer(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            generation = root / 'generation'
            generation.mkdir()
            previous = {'record': {'snapshot': 'old', 'recovery_point': '2026-11-13T00:00:00+00:00'}}
            x.n.atomic_json(root / 'last-accepted.json', previous)
            incoming = {'record': {'snapshot': 'new', 'recovery_point': '2026-11-14T00:00:00+00:00'}}
            real = x.n.atomic_json
            def fail_pointer(path, data):
                if path.name == 'last-accepted.json':
                    raise OSError('fixture disk failure')
                real(path, data)
            with patch.object(x.n, 'atomic_json', side_effect=fail_pointer):
                with self.assertRaises(OSError):
                    x.promote({'state_root': root}, generation, incoming)
            self.assertEqual(json.loads((root / 'last-accepted.json').read_text()), previous)

    def test_promotion_retains_previous_identity_and_never_rolls_back(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            x.n.atomic_json(root / 'last-accepted.json', {'record': {
                'snapshot': 'old', 'recovery_point': '2026-11-13T00:00:00+00:00'}})
            accepted = {'record': {'snapshot': 'new', 'recovery_point': '2026-11-14T00:00:00+00:00'}}
            x.promote({'state_root': root}, root, accepted)
            self.assertEqual(x.read_private(root / 'last-accepted.json')['previous_snapshot'], 'old')
            with self.assertRaises(x.b.BackupError):
                x.promote({'state_root': root}, root, accepted)

    def report(self):
        manifest = {'software_identity': 'OrchidApp.Web.dll SHA256=' + 'a' * 64, 'required_photos': ['one']}
        state = {'record': {'snapshot': 'snapshot', 'sha256': 'b' * 64}}
        report = {'result': 'APPLICATION_PROBE_PASSED_ACCEPTANCE_PENDING', 'snapshot': 'snapshot',
                  'archive_sha256': 'b' * 64, 'web_dll_sha256': 'a' * 64,
                  'application_starts': 2, 'photo_files_checked': 1, 'token': 'c' * 32,
                  'readiness': {'ready': True, 'checks': dict.fromkeys(x.a.CHECKS, True)}}
        return report, state, manifest

    def test_wrong_failed_partial_or_unready_evidence_refused(self):
        report, state, manifest = self.report()
        x.verify_report(report, state, manifest)
        for key, value in [('result', 'APPLICATION_PROBE_FAILED'), ('snapshot', 'other'),
                           ('archive_sha256', 'd' * 64), ('web_dll_sha256', 'd' * 64),
                           ('application_starts', 1), ('photo_files_checked', 0)]:
            with self.subTest(key=key), self.assertRaises(x.b.BackupError):
                x.verify_report(dict(report, **{key: value}), state, manifest)
        changed = copy.deepcopy(report)
        changed['readiness']['checks']['database'] = False
        with self.assertRaises(x.b.BackupError):
            x.verify_report(changed, state, manifest)

    def test_null_checksum_refused_and_identifier_quoted(self):
        c, native = {}, {}
        with patch.object(x.d, 'inventory', return_value={'base_table_rows': {'orchids': {'a`b': 3}}}), \
             patch.object(x.d, 'query', return_value=['orchids.a`b\tNULL']) as query:
            with self.assertRaises(x.b.BackupError):
                x.table_checksums(c, native)
            self.assertEqual(query.call_args.args[2], 'CHECKSUM TABLE `orchids`.`a``b` EXTENDED;')

    def test_table_comparison_includes_counts_and_checksum(self):
        with patch.object(x.d, 'inventory', return_value={'base_table_rows': {'orchids': {'plant': 3}}}), \
             patch.object(x.d, 'query', return_value=['orchids.plant\t42']):
            self.assertEqual(x.table_checksums({}, {}), {'orchids.plant': {'rows': 3, 'checksum': '42'}})

    @unittest.skipUnless(os.name == 'posix', 'POSIX workspace owner check')
    def test_changed_upload_and_publication_refused(self):
        with tempfile.TemporaryDirectory() as tmp:
            workspace = Path(tmp)
            workspace.chmod(0o700)
            (workspace / 'uploads').mkdir()
            (workspace / 'uploads/photo').write_text('original')
            (workspace / 'publication').mkdir()
            (workspace / 'publication/OrchidApp.Web.dll').write_text('dll')
            x.n.atomic_json(workspace / 'publication/appsettings.json', {
                'Monitoring': {'Enabled': False}, 'AllowedHosts': '127.0.0.1;localhost'})
            manifest = {'inventory': {'sources/photos/' + key: value for key, value in
                                     x.b.inventory(workspace / 'uploads').items()}}
            publication = {'inventory': {'publication/OrchidApp.Web.dll': {
                'size': 3, 'sha256': x.b.digest(workspace / 'publication/OrchidApp.Web.dll')}}}
            c = {'server_uid': os.geteuid(), 'uploads_source': 'photos'}
            x.verify_workspace(c, workspace, manifest, publication)
            (workspace / 'uploads/photo').write_text('changed')
            with self.assertRaises(x.b.BackupError):
                x.verify_workspace(c, workspace, manifest, publication)
            (workspace / 'uploads/photo').write_text('original')
            (workspace / 'publication/OrchidApp.Web.dll').write_text('changed')
            with self.assertRaises(x.b.BackupError):
                x.verify_workspace(c, workspace, manifest, publication)


if __name__ == '__main__':
    unittest.main()
