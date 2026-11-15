"""Synthetic publication capture/validation; no app, database, network or service."""
import json
import os
from pathlib import Path
import shutil
import sys
import tarfile
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'infrastructure/backups'))
import standby_publication as p


class Publication(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.source = self.root / 'publish'
        self.source.mkdir()
        (self.source / 'OrchidApp.Web.dll').write_bytes(b'synthetic-dll-bytes')
        (self.source / 'OrchidApp.Web.deps.json').write_text('{}')
        (self.source / 'OrchidApp.Web.runtimeconfig.json').write_text(json.dumps({'runtimeOptions': {'tfm': 'net8.0'}}))
        (self.source / '.hidden').write_text('synthetic hidden bytes')
        (self.source / 'empty').mkdir()
        self.expected = p.b.digest(self.source / 'OrchidApp.Web.dll')
        self.destination = self.root / 'private-export/publication.tar.gz'

    def tearDown(self):
        self.temp.cleanup()

    def capture(self):
        with patch.object(p.platform, 'machine', return_value='aarch64'):
            return p.capture(self.source, self.destination, self.expected, reserve=1)

    def test_capture_verify_and_unchanged_source(self):
        original = p.b.inventory(self.source)
        result = self.capture()
        manifest = p.verify(self.destination, self.expected)
        self.assertEqual(result['result'], 'PUBLICATION_CAPTURED')
        self.assertEqual(p.b.inventory(self.source), original)
        self.assertIn('publication/.hidden', manifest['inventory'])
        self.assertEqual(manifest['inventory']['publication/empty'], {'directory': True})
        if os.name == 'posix':
            self.assertEqual(self.destination.stat().st_mode & 0o777, 0o600)

    def test_wrong_expected_fingerprint_refuses_capture(self):
        with patch.object(p.platform, 'machine', return_value='aarch64'):
            with self.assertRaises(p.b.BackupError):
                p.capture(self.source, self.destination, '0' * 64, reserve=1)
        self.assertFalse(self.destination.exists())

    def test_existing_archive_never_overwritten(self):
        self.capture()
        before = self.destination.read_bytes()
        with self.assertRaises(p.b.BackupError):
            self.capture()
        self.assertEqual(self.destination.read_bytes(), before)

    def test_capture_change_rejected(self):
        original = shutil.copytree
        def changed(*args, **kwargs):
            result = original(*args, **kwargs)
            (self.source / 'OrchidApp.Web.dll').write_bytes(b'changed during copy')
            return result
        with patch.object(p.shutil, 'copytree', changed):
            with self.assertRaises(p.b.BackupError):
                self.capture()
        self.assertFalse(self.destination.exists())

    def test_low_space_refuses_capture(self):
        with patch.object(p.shutil, 'disk_usage', return_value=SimpleNamespace(free=0)):
            with self.assertRaises(p.b.BackupError):
                self.capture()
        self.assertFalse(self.destination.exists())

    def test_bad_inventory_or_expected_dll_rejected(self):
        self.capture()
        with self.assertRaises(p.b.BackupError):
            p.verify(self.destination, '0' * 64)
        with tarfile.open(self.destination, 'r:gz') as tar:
            payloads = [(member, tar.extractfile(member).read() if member.isfile() else None) for member in tar]
        import io
        with tarfile.open(self.destination, 'w:gz') as tar:
            for member, data in payloads:
                if member.name == 'publication/OrchidApp.Web.dll':
                    data = b'different-dll'
                    member.size = len(data)
                tar.addfile(member, io.BytesIO(data) if data is not None else None)
        with self.assertRaises(p.b.BackupError):
            p.verify(self.destination, self.expected)

    def test_wrong_capture_architecture_refused(self):
        with patch.object(p.platform, 'machine', return_value='x86_64'):
            with self.assertRaises(p.b.BackupError):
                p.capture(self.source, self.destination, self.expected, reserve=1)
        self.assertFalse(self.destination.exists())

    def test_unsafe_link_and_duplicate_members_refused(self):
        import io
        for kind in ('traversal', 'link', 'duplicate'):
            path = self.root / (kind + '.tar.gz')
            with tarfile.open(path, 'w:gz') as tar:
                name = '../outside' if kind == 'traversal' else 'publication/test'
                info = tarfile.TarInfo(name)
                if kind == 'link':
                    info.type, info.linkname = tarfile.SYMTYPE, '/outside'
                    tar.addfile(info)
                else:
                    info.size = 1
                    tar.addfile(info, io.BytesIO(b'x'))
                    if kind == 'duplicate':
                        tar.addfile(info, io.BytesIO(b'x'))
            with self.assertRaises(p.b.BackupError):
                p.verify(path, self.expected)


if __name__ == '__main__':
    unittest.main()
