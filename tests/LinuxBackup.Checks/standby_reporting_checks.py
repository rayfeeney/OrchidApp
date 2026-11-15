"""Durable Pi 2 reporting tests; no real SMTP, SQL, cloud or credentials."""
from datetime import datetime, timedelta, timezone
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch, MagicMock

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'infrastructure/backups'))
import standby_reporting as r


class Reporting(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        root = Path(self.temp.name)
        secret = root / 'password'
        secret.write_text('synthetic-only')
        self.c = {'backup_root': root, 'log_file': root / 'reporting.log',
                  'smtp_password_file': secret, 'max_age_hours': 30,
                  'email': {'host': 'smtp.invalid', 'port': 465,
                            'sender': 'sender@example.invalid', 'recipient': 'receiver@example.invalid'}}
        self.clock = datetime.now(timezone.utc)
        self.value = {'record': {'snapshot': 'fixture-snapshot',
                                'recovery_point': (self.clock - timedelta(hours=1)).isoformat(),
                                'databases': ['orchids', 'EnergyMonitoring']},
                      'accepted_at': self.clock.isoformat(), 'photo_files_checked': 756, 'application_starts': 2}

    def messages(self):
        return [json.loads(path.read_text()) for path in (self.c['backup_root'] / 'outbox').glob('*.json')]

    def test_success_requires_acceptance(self):
        with self.assertRaises(r.b.BackupError):
            r.report_success(self.c)
        self.assertEqual(self.messages(), [])

    def test_one_success_per_snapshot_without_changing_pointer(self):
        with patch.object(r, 'accepted', return_value=self.value):
            r.report_success(self.c)
            r.report_success(self.c)
        messages = self.messages()
        self.assertEqual(len(messages), 1)
        self.assertEqual(messages[0]['subject'], '[Pi 2 restore] SUCCESS')
        self.assertIn('756', messages[0]['body'])
        self.assertFalse((self.c['backup_root'] / 'last-accepted.json').exists())

    def test_smtp_failure_retains_message_and_retry_reuses_message_id(self):
        r.n.queue_email(self.c, 'fixture', 'synthetic-only')
        original_id = self.messages()[0]['id']
        with patch.object(r.n.smtplib, 'SMTP_SSL', side_effect=OSError('fixture unavailable')):
            self.assertFalse(r.n.flush_email(self.c))
        self.assertEqual(self.messages()[0]['id'], original_id)
        self.assertEqual(self.messages()[0]['attempts'], 1)
        smtp = MagicMock()
        smtp.send_message.return_value = {}
        with patch.object(r.n.smtplib, 'SMTP_SSL', return_value=smtp):
            self.assertTrue(r.n.flush_email(self.c))
        self.assertEqual(self.messages(), [])

    def test_current_restore_sends_no_overdue_message(self):
        with patch.object(r, 'accepted', return_value=self.value):
            self.assertEqual(r.monitor(self.c, self.clock)['result'], 'CURRENT')
        self.assertEqual(self.messages(), [])

    def test_overdue_uses_recovery_point_not_acceptance_time_and_daily_dedup(self):
        self.value['record']['recovery_point'] = (self.clock - timedelta(hours=31)).isoformat()
        with patch.object(r, 'accepted', return_value=self.value):
            self.assertEqual(r.monitor(self.c, self.clock)['result'], 'OVERDUE')
            r.monitor(self.c, self.clock)
            self.assertEqual(len(self.messages()), 1)
            r.monitor(self.c, self.clock + timedelta(days=1))
        self.assertEqual(len(self.messages()), 2)

    def test_failure_has_no_raw_diagnostics_and_rejects_untrusted_phase(self):
        r.failure(self.c, 'restore-data')
        self.assertEqual(self.messages()[0]['subject'], '[Pi 2 restore] FAILED')
        with self.assertRaises(r.b.BackupError):
            r.failure(self.c, 'SQL password=secret\n')
        self.assertEqual(len(self.messages()), 1)

    def test_missing_acceptance_is_overdue(self):
        self.assertEqual(r.monitor(self.c, self.clock)['result'], 'OVERDUE')
        self.assertEqual(len(self.messages()), 1)


if __name__ == '__main__':
    unittest.main()
