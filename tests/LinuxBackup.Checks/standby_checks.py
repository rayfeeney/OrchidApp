"""Block 2 phase 1: synthetic records/cloud/archive; never imports a database."""
from datetime import datetime, timedelta, timezone
import io
import json
import os
import shutil
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile
import unittest
from unittest.mock import patch
import uuid

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'infrastructure/backups'))
import standby_restore as s


class Standby(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        state = self.root / 'standby'
        state.mkdir()
        self.c = {'collection_id': str(uuid.uuid4()), 'databases': ['orchids', 'EnergyMonitoring'],
                  'photo_database': 'orchids', 'uploads_source': 'orchid-uploads',
                  'state_root': state, 'backup_root': state, 'rclone_config': self.root / 'crypt.conf',
                  'remote': 'fixturecrypt:sets/collection', 'timeout_seconds': 5, 'reserve_bytes': 100,
                  'max_archive_bytes': 1024**2, 'max_unpack_bytes': 1024**2,
                  'max_record_bytes': 65536, 'max_listing_bytes': 1024**2,
                  'max_ready_records': 100, 'max_age_hours': 30, 'max_generations': 3}
        self.recovery = datetime.now(timezone.utc) - timedelta(hours=1)
        self.snapshot = 'orchidset-' + self.recovery.strftime('%Y%m%dT%H%M%SZ') + '-' + uuid.uuid4().hex
        self.payload = self.root / 'payload'
        (self.payload / 'databases').mkdir(parents=True)
        (self.payload / 'sources/orchid-uploads/plants/1').mkdir(parents=True)
        (self.payload / 'sources/settings').mkdir()
        (self.payload / 'sources/orchid-uploads/plants/1/photo.jpg').write_bytes(b'synthetic photo')
        (self.payload / 'sources/orchid-uploads/.hidden').write_bytes(b'synthetic journal')
        (self.payload / 'sources/orchid-uploads/empty').mkdir()
        (self.payload / 'sources/settings/private.env').write_text('synthetic=secret')
        for name in self.c['databases']:
            (self.payload / 'databases' / (name + '.sql')).write_text('SELECT 1;')
        (self.payload / 'accounts.sql').write_text('-- synthetic account reference')
        self.manifest = {'format': s.n.FORMAT, 'collection_id': self.c['collection_id'],
                         'snapshot': self.snapshot, 'captured_at': self.recovery.isoformat(),
                         'databases': self.c['databases'], 'photo_database': 'orchids',
                         'uploads_source': 'orchid-uploads', 'required_photos': ['plants/1/photo.jpg'],
                         'source_paths': {'orchid-uploads': '/synthetic/uploads', 'settings': '/synthetic/settings'},
                         'software_identity': 'synthetic-publication', 'inventory': s.b.inventory(self.payload)}
        (self.payload / 'manifest.json').write_text(json.dumps(self.manifest))
        self.archive = self.root / (self.snapshot + '.tar.gz')
        self.pack()
        self.record = {'format': s.n.FORMAT, 'collection_id': self.c['collection_id'], 'snapshot': self.snapshot,
                       'archive': self.archive.name, 'sha256': s.b.digest(self.archive),
                       'databases': self.c['databases'], 'recovery_point': self.recovery.isoformat(),
                       'completed_at': (self.recovery + timedelta(minutes=2)).isoformat(),
                       'size_bytes': self.archive.stat().st_size}

    def tearDown(self):
        self.temp.cleanup()

    def pack(self):
        with tarfile.open(self.archive, 'w:gz') as tar:
            for child in self.payload.iterdir():
                tar.add(child, arcname=child.name)

    def output(self, c, args, limit):
        if 'lsf' in args:
            return (self.snapshot + '.ready.json\n').encode()
        self.assertIn('cat', args)
        return json.dumps(self.record).encode()

    def run_tool(self, c, args, **kwargs):
        self.assertIn('cat', args)
        self.assertNotIn('copyto', args)
        kwargs['stdout'].write(self.archive.read_bytes())

    def prepare(self):
        with patch.object(s, 'bounded_output', self.output), patch.object(s.b, 'run', self.run_tool):
            return s.prepare(self.c)

    def test_prepare_checks_and_stages_without_accepting_or_importing(self):
        result = self.prepare()
        self.assertEqual(result['result'], 'PREPARED_RESTORE_PENDING')
        generation = Path(result['generation'])
        self.assertEqual((generation / 'payload/sources/orchid-uploads/plants/1/photo.jpg').read_bytes(), b'synthetic photo')
        self.assertTrue((generation / 'payload/sources/orchid-uploads/.hidden').exists())
        self.assertTrue((generation / 'payload/sources/orchid-uploads/empty').is_dir())
        self.assertFalse((self.c['state_root'] / 'last-accepted.json').exists())
        state = json.loads((generation / 'state.json').read_text())
        self.assertFalse(state['accepted'])
        self.assertEqual(state['phase'], 'PREPARED_RESTORE_PENDING')

    def test_cloud_interface_refuses_all_mutating_operations(self):
        for operation in ('copyto', 'sync', 'deletefile', 'mkdir', 'rcat', 'upload'):
            with self.assertRaises(s.b.BackupError):
                s.command(self.c, operation, self.record['archive'], 10)
        self.assertIn('lsf', s.command(self.c, 'list'))
        self.assertIn('cat', s.command(self.c, 'read', self.record['archive'], 100))

    def test_cloud_object_must_be_exact_safe_name(self):
        for name in ('../outside.tar.gz', self.snapshot + '.tar.gz/other', 'other:secret', '*.ready.json'):
            with self.assertRaises(s.b.BackupError):
                s.command(self.c, 'read', name, 100)

    def test_record_wrong_collection_database_hash_size_and_name(self):
        cases = [('collection_id', str(uuid.uuid4())), ('databases', ['orchids']),
                 ('sha256', 'bad'), ('size_bytes', 0), ('size_bytes', True),
                 ('size_bytes', 2 * 1024**2), ('archive', '../outside')]
        for key, value in cases:
            with self.subTest(key=key, value=value):
                record = dict(self.record, **{key: value})
                with self.assertRaises(s.b.BackupError):
                    s.check_record(self.c, record)

    def test_record_requires_timezone_and_consistent_times(self):
        for value in (datetime.now().isoformat(), (datetime.now(timezone.utc) + timedelta(days=1)).isoformat()):
            with self.assertRaises(s.b.BackupError):
                s.check_record(self.c, dict(self.record, completed_at=value))
        with self.assertRaises(s.b.BackupError):
            s.check_record(self.c, dict(self.record, completed_at=(self.recovery - timedelta(seconds=1)).isoformat()))

    def test_stale_latest_cannot_fall_back_to_older(self):
        with self.assertRaises(s.b.BackupError):
            s.check_record(self.c, self.record, clock=self.recovery + timedelta(hours=31))

    def test_accepted_same_snapshot_is_noop_and_rewrite_refused(self):
        self.assertIsNone(s.select_record(self.c, [self.record], self.record))
        changed = dict(self.record, sha256='0' * 64)
        with self.assertRaises(s.b.BackupError):
            s.select_record(self.c, [changed], self.record)

    def test_older_than_accepted_is_refused(self):
        later = self.recovery + timedelta(minutes=10)
        newer = dict(self.record, recovery_point=later.isoformat(), completed_at=later.isoformat(),
                     snapshot='orchidset-' + later.strftime('%Y%m%dT%H%M%SZ') + '-' + uuid.uuid4().hex)
        newer['archive'] = newer['snapshot'] + '.tar.gz'
        with self.assertRaises(s.b.BackupError):
            s.select_record(self.c, [self.record], newer)

    def test_bad_record_prevents_discovery_fallback(self):
        with self.assertRaises(s.b.BackupError):
            s.select_record(self.c, [self.record, dict(self.record, sha256='bad')])

    def test_download_hash_mismatch_keeps_failed_state(self):
        with patch.object(s, 'bounded_output', self.output), \
             patch.object(s.b, 'run', lambda c, args, **kw: kw['stdout'].write(b'corrupt')):
            with self.assertRaises(s.b.BackupError):
                s.prepare(self.c)
        state = json.loads(next((self.c['state_root'] / 'generations').glob('*/state.json')).read_text())
        self.assertEqual(state['phase'], 'FAILED')
        self.assertFalse((self.c['state_root'] / 'last-prepared.json').exists())

    def test_existing_generation_never_reused_or_overwritten(self):
        result = self.prepare()
        before = (Path(result['generation']) / 'state.json').read_bytes()
        with self.assertRaises(s.b.BackupError):
            self.prepare()
        self.assertEqual((Path(result['generation']) / 'state.json').read_bytes(), before)

    def test_capacity_limit_preserves_existing_generation(self):
        generations = self.c['state_root'] / 'generations'
        generations.mkdir()
        (generations / 'unknown-input').mkdir()
        self.c['max_generations'] = 1
        with self.assertRaises(s.b.BackupError):
            self.prepare()
        self.assertTrue((generations / 'unknown-input').exists())

    def test_low_space_never_downloads(self):
        usage = type('Usage', (), {'free': 0})()
        with patch.object(s.shutil, 'disk_usage', return_value=usage), patch.object(s, 'download') as download:
            with self.assertRaises(s.b.BackupError):
                self.prepare()
            download.assert_not_called()

    def test_archive_snapshot_must_match_ready_record(self):
        with self.assertRaises(s.b.BackupError):
            s.check_manifest(self.c, self.archive, dict(self.record, snapshot=self.snapshot[:-1] + ('1' if self.snapshot[-1] == '0' else '0')))

    def test_corrupt_payload_fails_before_extraction(self):
        (self.payload / 'sources/orchid-uploads/plants/1/photo.jpg').write_bytes(b'changed')
        self.pack()
        self.record.update(sha256=s.b.digest(self.archive), size_bytes=self.archive.stat().st_size)
        with patch.object(s, 'extract_private') as extract:
            with self.assertRaises(s.b.BackupError):
                self.prepare()
            extract.assert_not_called()

    def test_missing_photo_even_with_updated_inventory_is_rejected(self):
        (self.payload / 'sources/orchid-uploads/plants/1/photo.jpg').unlink()
        self.manifest['inventory'].pop('sources/orchid-uploads/plants/1/photo.jpg')
        (self.payload / 'manifest.json').write_text(json.dumps(self.manifest))
        self.pack()
        with self.assertRaises(s.b.BackupError):
            s.check_manifest(self.c, self.archive, self.record)

    def test_extraction_uses_private_modes_under_normal_umask(self):
        previous = os.umask(0o022)
        try:
            result = self.prepare()
        finally:
            os.umask(previous)
        if os.name == 'posix':
            for file in Path(result['generation']).rglob('*'):
                self.assertEqual(file.stat().st_mode & 0o077, 0)

    def test_bounded_subprocess_stops_oversized_output(self):
        with self.assertRaises(s.b.BackupError):
            s.bounded_output(self.c, [sys.executable, '-c', 'import sys;sys.stdout.write("x"*100000)'], 100)

    def test_bounded_subprocess_hides_error_text(self):
        with self.assertRaises(s.b.BackupError) as error:
            s.bounded_output(self.c, [sys.executable, '-c', 'import sys;sys.stderr.write("secret");sys.exit(1)'], 100)
        self.assertNotIn('secret', str(error.exception))

    def test_empty_cloud_has_no_candidate(self):
        with patch.object(s, 'bounded_output', return_value=b''):
            with self.assertRaises(s.b.BackupError):
                s.discover(self.c)

    def test_duplicate_listing_is_rejected(self):
        listing = ((self.snapshot + '.ready.json\n') * 2).encode()
        with patch.object(s, 'bounded_output', return_value=listing):
            with self.assertRaises(s.b.BackupError):
                s.discover(self.c)

    def test_member_changed_to_oversized_file_refused_during_extraction(self):
        (self.payload / 'sources/settings/private.env').write_bytes(b'changed size, not original')
        self.pack()
        with self.assertRaises(s.b.BackupError):
            s.extract_private(self.archive, self.root / 'new-staging', self.manifest)

    @unittest.skipUnless(shutil.which('rclone'), 'Actual crypt backend requires rclone')
    def test_actual_rclone_crypt_discovery_download_and_staging(self):
        store = self.root / 'encrypted-store'
        store.mkdir()
        config = self.c['rclone_config']
        password = subprocess.check_output(['rclone', 'obscure', 'synthetic-standby-fixture']).decode().strip()
        config.write_text('[fixturecrypt]\ntype=crypt\nremote=' + store.as_posix() + '\npassword=' + password + '\n')
        config.chmod(0o600)
        prefix = ['rclone', '--config', str(config)]
        # Fixture provisioning alone uploads; production module has only list/cat.
        subprocess.run(prefix + ['mkdir', self.c['remote']], check=True, capture_output=True)
        record_file = self.root / 'fixture.ready.json'
        record_file.write_text(json.dumps(self.record))
        subprocess.run(prefix + ['copyto', str(self.archive), self.c['remote'] + '/' + self.record['archive']],
                       check=True, capture_output=True)
        subprocess.run(prefix + ['copyto', str(record_file), self.c['remote'] + '/' + self.snapshot + '.ready.json'],
                       check=True, capture_output=True)
        result = s.prepare(self.c)
        self.assertEqual(result['result'], 'PREPARED_RESTORE_PENDING')
        self.assertEqual((Path(result['generation']) / 'payload/sources/orchid-uploads/plants/1/photo.jpg').read_bytes(), b'synthetic photo')


if __name__ == '__main__':
    unittest.main()
