"""Block 1 synthetic failure-path tests; never connect to a collection server."""
from contextlib import contextmanager
from datetime import datetime, timedelta, timezone
import importlib.util
import io
import json
import os
from pathlib import Path
import sys
import tarfile
import tempfile
import unittest
from unittest.mock import patch, MagicMock
import uuid

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'infrastructure/backups'))
import nightly_backup as n


class Nightly(unittest.TestCase):
    def test_atomic_json_explicit_private_mode_without_private_umask(self):
        path = self.backups / 'configuration.json'
        prior = os.umask(0o022)
        try:
            for value in ('first', 'replacement'):
                with patch.object(n.os, 'open', wraps=os.open) as opened:
                    n.atomic_json(path, {'setting': value})
                creates = [call for call in opened.call_args_list if len(call.args) == 3]
                self.assertEqual(len(creates), 1)
                self.assertEqual(creates[0].args[2], 0o600)
                if os.name == 'posix':
                    self.assertEqual(path.stat().st_mode & 0o777, 0o600)
            self.assertEqual(json.loads(path.read_text()), {'setting': 'replacement'})
        finally:
            os.umask(prior)

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.backups = self.root / 'backups'
        self.backups.mkdir()
        self.uploads = self.root / 'uploads'
        self.uploads.mkdir()
        (self.uploads / '.hidden').write_bytes(b'fixture')
        self.c = {'collection_id': str(uuid.uuid4()), 'databases': ['orchids', 'EnergyMonitoring'],
                  'database': 'orchids', 'photo_database': 'orchids', 'sources': {'uploads': self.uploads},
                  'uploads_source': 'uploads', 'software_identity': 'fixture-app', 'backup_root': self.backups,
                  'log_file': self.backups / 'log', 'client_defaults_file': self.root / 'private.cnf',
                  'writer_units': ['fixture.service'], 'remote': 'fixture:sets', 'keep_local': 1,
                  'keep_remote': 2, 'max_unpack_bytes': 1024**2, 'timeout_seconds': 10,
                  'reserve_bytes': 100, 'max_age_hours': 30, 'email': {'host': 'example.invalid',
                  'port': 465, 'sender': 'source@example.invalid', 'recipient': 'target@example.invalid'},
                  'smtp_password_file': self.root / 'password'}
        self.c['smtp_password_file'].write_text('synthetic-secret')
        self.events = []

    def tearDown(self):
        self.temp.cleanup()

    @contextmanager
    def writers(self, c):
        self.events.append('stop')
        try:
            yield
        finally:
            self.events.append('restart')

    @contextmanager
    def lock(self, c):
        self.events.append('lock')
        try:
            yield lambda: self.events.append('lock-check')
        finally:
            self.events.append('unlock')

    def tool(self, c, args, **kw):
        self.events.append(args)
        kw['stdout'].write(b'-- synthetic SQL\nSELECT 1;')

    def capture(self):
        payload = self.root / ('payload-' + uuid.uuid4().hex)
        payload.mkdir()
        status = {'snapshot': 'orchidset-20261113T020000Z-' + uuid.uuid4().hex, 'started_at': n.now()}
        with patch.object(n.b, 'stop_writers', self.writers), patch.object(n.b, 'database_read_lock', self.lock), \
             patch.object(n.b, 'photo_paths', return_value=[]), patch.object(n.b, 'writers_stopped'), \
             patch.object(n.b, 'run', self.tool), patch.object(n, 'readiness', lambda _: self.events.append('ready')):
            manifest = n.capture(self.c, payload, status)
        archive = self.backups / (status['snapshot'] + '.tar.gz')
        self.pack(payload, archive)
        return payload, archive, status, manifest

    def pack(self, payload, archive):
        with tarfile.open(archive, 'w:gz') as tar:
            for child in payload.iterdir():
                tar.add(child, arcname=child.name)

    def test_two_database_capture_and_short_outage(self):
        payload, archive, status, manifest = self.capture()
        tools = [e for e in self.events if isinstance(e, list)]
        self.assertEqual([args[-1] for args in tools], ['orchids', 'EnergyMonitoring', 'mysql'])
        self.assertTrue(all('--skip-lock-tables' in args for args in tools))
        self.assertLess(self.events.index('unlock'), self.events.index('restart'))
        self.assertLess(self.events.index('restart'), self.events.index('ready'))
        self.assertEqual(n.validate(archive, self.c), manifest)
        self.assertIn('sources/uploads/.hidden', manifest['inventory'])

    def test_capture_failure_attempts_restart(self):
        payload = self.root / 'payload'
        payload.mkdir()
        status = {'snapshot': 'unused', 'started_at': n.now()}
        with patch.object(n.b, 'stop_writers', self.writers), patch.object(n.b, 'database_read_lock', self.lock), \
             patch.object(n.b, 'photo_paths', side_effect=n.b.BackupError('missing photo')):
            with self.assertRaises(n.b.BackupError):
                n.capture(self.c, payload, status)
        self.assertIn('restart', self.events)

    def test_corruption_and_wrong_database_set_rejected(self):
        payload, archive, status, manifest = self.capture()
        (payload / 'databases/orchids.sql').write_text('tampered')
        self.pack(payload, archive)
        with self.assertRaises(n.b.BackupError):
            n.validate(archive, self.c)
        self.c['databases'] = ['orchids']
        with self.assertRaises(n.b.BackupError):
            n.validate(archive, self.c)

    def test_unsafe_archive_entry_rejected(self):
        archive = self.root / 'unsafe.tar.gz'
        with tarfile.open(archive, 'w:gz') as tar:
            info = tarfile.TarInfo('../outside')
            info.size = 1
            tar.addfile(info, io.BytesIO(b'x'))
        with self.assertRaises(n.b.BackupError):
            n.validate(archive, self.c)

    def test_space_failure_precedes_writer_control(self):
        with patch.object(n.b, 'rclone'), patch.object(n.b, 'query', side_effect=[self.c['databases'], ['999999999999']]), \
             patch.object(n, 'capture') as capture, patch.object(n, 'report'), patch.object(n, 'flush_email', return_value=True):
            self.assertEqual(n.run_backup(self.c), 1)
            capture.assert_not_called()

    def test_readback_failure_never_publishes_ready(self):
        payload, archive, status, _ = self.capture()
        calls = []
        def rclone(c, *args):
            calls.append(args)
            if args[1].startswith('fixture:'):
                Path(args[2]).write_bytes(b'corrupt remote download')
        with tempfile.TemporaryDirectory() as folder, patch.object(n.b, 'rclone', rclone):
            with self.assertRaises(n.b.BackupError):
                n.upload(self.c, archive, Path(folder), status)
        self.assertTrue(archive.exists())
        self.assertFalse(list(self.backups.glob('*.ready.json')))
        self.assertEqual(len(calls), 2)

    def test_completion_published_only_after_archive_readback(self):
        payload, archive, status, _ = self.capture()
        objects, calls = {}, []
        def rclone(c, *args):
            calls.append(args)
            if args[1].startswith('fixture:'):
                Path(args[2]).write_bytes(objects[args[1]])
            else:
                objects[args[2]] = Path(args[1]).read_bytes()
        with tempfile.TemporaryDirectory() as folder, patch.object(n.b, 'rclone', rclone):
            record = n.upload(self.c, archive, Path(folder), status)
        self.assertEqual(len(calls), 4)
        self.assertTrue(calls[0][2].endswith('.tar.gz'))
        self.assertTrue(calls[2][2].endswith('.ready.json'))
        self.assertEqual(record['sha256'], n.b.digest(archive))

    def test_email_failure_keeps_outbox_and_hides_secret(self):
        n.queue_email(self.c, 'test', 'synthetic summary')
        with patch.object(n.smtplib, 'SMTP_SSL', side_effect=RuntimeError('synthetic-secret')), patch.object(n.b, 'log') as log:
            self.assertFalse(n.flush_email(self.c))
            self.assertNotIn('synthetic-secret', str(log.call_args_list))
        self.assertEqual(len(list((self.backups / 'outbox').glob('*.json'))), 1)

    def test_email_success_removes_outbox_and_uses_tls(self):
        n.queue_email(self.c, 'test', 'synthetic summary')
        smtp = MagicMock()
        smtp.__enter__.return_value = smtp
        smtp.send_message.return_value = {}
        with patch.object(n.smtplib, 'SMTP_SSL', return_value=smtp) as factory:
            self.assertTrue(n.flush_email(self.c))
            self.assertIsNotNone(factory.call_args.kwargs['context'])
        self.assertFalse(list((self.backups / 'outbox').glob('*.json')))

    def test_retry_is_bounded_and_does_not_run_backup(self):
        n.queue_email(self.c, 'test', 'synthetic summary')
        with patch.object(n.smtplib, 'SMTP_SSL', side_effect=RuntimeError()), patch.object(n.b, 'log'), \
             patch.object(n, 'run_backup') as backup:
            for _ in range(15):
                self.assertFalse(n.flush_email(self.c))
            backup.assert_not_called()
        record = json.loads(next((self.backups / 'outbox').glob('*.json')).read_text())
        self.assertEqual(record['attempts'], 12)

    def test_overdue_alert_is_daily_and_retries_email(self):
        with patch.object(n, 'flush_email', return_value=True):
            self.assertEqual(n.monitor(self.c), 1)
            self.assertEqual(n.monitor(self.c), 1)
        self.assertEqual(len(list((self.backups / 'outbox').glob('*.json'))), 1)

    def test_fresh_cloud_success_prevents_overdue(self):
        n.atomic_json(self.backups / 'last-success.json', {'recovery_point': n.now()})
        with patch.object(n, 'flush_email', return_value=True):
            self.assertEqual(n.monitor(self.c), 0)
        self.assertFalse(list((self.backups / 'outbox').glob('*.json')))

    def test_failed_backup_does_not_replace_last_success(self):
        prior = {'recovery_point': (datetime.now(timezone.utc) - timedelta(days=1)).isoformat()}
        n.atomic_json(self.backups / 'last-success.json', prior)
        with patch.object(n, 'preflight', side_effect=n.b.BackupError('remote unavailable')), \
             patch.object(n, 'flush_email', return_value=True):
            self.assertEqual(n.run_backup(self.c), 1)
        self.assertEqual(json.loads((self.backups / 'last-success.json').read_text()), prior)

    def test_starttls_precedes_authentication(self):
        self.c['email']['port'] = 587
        n.queue_email(self.c, 'test', 'summary')
        smtp = MagicMock()
        smtp.__enter__.return_value = smtp
        smtp.send_message.return_value = {}
        with patch.object(n.smtplib, 'SMTP', return_value=smtp):
            self.assertTrue(n.flush_email(self.c))
        calls = [str(call) for call in smtp.method_calls]
        self.assertLess(next(i for i, x in enumerate(calls) if x.startswith('call.starttls')),
                        next(i for i, x in enumerate(calls) if x.startswith('call.login')))

    def test_full_success_and_email_failure_do_not_repeat_capture(self):
        payload, archive, status, manifest = self.capture()
        record = {'snapshot': status['snapshot'], 'recovery_point': n.now()}
        def frozen(c, target, run):
            import shutil
            shutil.copytree(payload, target, dirs_exist_ok=True)
            m = json.loads((target / 'manifest.json').read_text())
            m['snapshot'] = run['snapshot']
            n.atomic_json(target / 'manifest.json', m)
        with patch.object(n, 'preflight', return_value={}), patch.object(n, 'capture', frozen), \
             patch.object(n, 'upload', return_value=record) as upload, patch.object(n, 'retention') as retention, \
             patch.object(n, 'flush_email', return_value=False):
            self.assertEqual(n.run_backup(self.c), 2)
            self.assertEqual(upload.call_count, 1)
            retention.assert_called_once()
        self.assertEqual(json.loads((self.backups / 'run.json').read_text())['result'], 'SUCCESS')
        self.assertEqual(json.loads((self.backups / 'last-success.json').read_text()), record)

    def test_foreign_completion_record_cannot_authorize_deletion(self):
        record = {'format': n.FORMAT, 'collection_id': str(uuid.uuid4()), 'snapshot': 'orchidset-20261113T020000Z-' + uuid.uuid4().hex}
        with self.assertRaises(n.b.BackupError):
            n.ready_record(self.c, record)

    def test_retention_keeps_current_and_pin_and_foreign_files(self):
        import shutil
        _, archive, status, _ = self.capture()
        records = []
        for day in (10, 11, 12):
            snapshot = 'orchidset-202611' + str(day) + 'T020000Z-' + uuid.uuid4().hex
            file = self.backups / (snapshot + '.tar.gz')
            shutil.copyfile(archive, file)
            record = {'format': n.FORMAT, 'collection_id': self.c['collection_id'], 'snapshot': snapshot,
                      'archive': file.name, 'sha256': n.b.digest(file), 'databases': self.c['databases'], 'completed_at': n.now()}
            n.atomic_json(self.backups / (snapshot + '.ready.json'), record)
            records.append(record)
        (self.backups / (records[0]['archive'] + '.keep')).touch()
        unknown = self.backups / 'manual-recovery.tar.gz'
        unknown.write_bytes(b'keep')
        current = records[2]
        objects = {r['archive']: b'synthetic' for r in records}
        objects.update({r['snapshot'] + '.ready.json': json.dumps(r).encode() for r in records})
        calls = []
        def remote(c, *args):
            calls.append(args)
            if args[0] == 'lsf':
                return '\n'.join(objects).encode()
            if args[0] == 'copyto':
                Path(args[2]).write_bytes(objects[args[1].split('/')[-1]])
            if args[0] == 'deletefile':
                del objects[args[1].split('/')[-1]]
        with tempfile.TemporaryDirectory() as folder, patch.object(n.b, 'rclone', remote):
            n.retention(self.c, current, Path(folder))
        self.assertTrue((self.backups / records[0]['archive']).exists())
        self.assertFalse((self.backups / records[1]['archive']).exists())
        self.assertTrue((self.backups / current['archive']).exists())
        self.assertTrue(unknown.exists())
        self.assertNotIn(records[0]['archive'], objects)
        self.assertIn(current['archive'], objects)
        deletes = [a[1] for a in calls if a[0] == 'deletefile']
        self.assertTrue(deletes[0].endswith('.ready.json'))

    def test_no_current_cloud_pair_no_remote_deletion(self):
        with tempfile.TemporaryDirectory() as folder, patch.object(n.b, 'rclone', return_value=b'') as remote:
            with self.assertRaises(n.b.BackupError):
                n.retention(self.c, {'snapshot': 'not-present'}, Path(folder))
        self.assertFalse(any(call.args[1] == 'deletefile' for call in remote.call_args_list))

    def test_stream_validator_rejects_links_and_duplicate_names(self):
        for kind in ('link', 'duplicate'):
            archive = self.root / (kind + '.tar.gz')
            with tarfile.open(archive, 'w:gz') as tar:
                info = tarfile.TarInfo('entry')
                if kind == 'link':
                    info.type, info.linkname = tarfile.SYMTYPE, '/outside'
                    tar.addfile(info)
                else:
                    info.size = 1
                    tar.addfile(info, io.BytesIO(b'x'))
                    tar.addfile(info, io.BytesIO(b'x'))
            with self.assertRaises(n.b.BackupError):
                n.validate(archive, self.c)

    def test_monitor_works_with_stale_backup_lock(self):
        (self.backups / '.paired-operation.lock').mkdir()
        with patch.object(n, 'flush_email', return_value=True):
            self.assertEqual(n.monitor(self.c), 1)
        self.assertEqual(len(list((self.backups / 'outbox').glob('*.json'))), 1)


if __name__ == '__main__':
    unittest.main()
