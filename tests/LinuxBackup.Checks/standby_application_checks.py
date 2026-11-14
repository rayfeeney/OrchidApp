"""Application isolation policy plus an owned real loopback HTTP fixture on Linux.

Synthetic data only. Never launches OrchidApp or connects to a database/cloud.
"""
import hashlib
import io
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import tarfile
import tempfile
import time
import uuid
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'infrastructure/backups'))
import standby_application as a
import standby_definers as f


class Application(unittest.TestCase):
    def view(self, name='vw_Tariff'):
        return dict(name=name, definition="select `EnergyMonitoring`.`witness`.`value` AS `value`",
                    definer=f.SOURCE, security='DEFINER', check='NONE', algorithm='UNDEFINED',
                    charset='utf8mb4', collation='utf8mb4_general_ci')

    def test_exact_definer_policy_preserves_query_and_locks_select_only_account(self):
        before = [self.view(name) for name in sorted(f.VIEWS)]
        after = [dict(view, definer=f.TARGET) for view in before]
        with patch.object(f.d, 'identity'), patch.object(f, 'metadata', side_effect=[before, after]), \
             patch.object(f.d, 'query', return_value=['76616c7565']) as query:
            result = f.apply({'databases': ['EnergyMonitoring']}, {}, object(), f.POLICY)
        sql = '\n'.join(call.args[2] for call in query.call_args_list)
        self.assertIn('ACCOUNT LOCK', sql)
        self.assertIn('GRANT SELECT ON `EnergyMonitoring`.*', sql)
        self.assertNotIn('GRANT ALL', sql)
        self.assertNotIn('IF NOT EXISTS', sql)
        self.assertEqual(sql.count('ALTER ALGORITHM='), 6)
        self.assertEqual(result['views'], sorted(f.VIEWS))

    def test_policy_rejects_unreviewed_objects_and_source_definers_before_writes(self):
        good = [self.view(name) for name in sorted(f.VIEWS)]
        for values in (good[:-1], good + [self.view('unreviewed')],
                       [dict(view, definer='other@localhost') for view in good]):
            with patch.object(f.d, 'identity'), patch.object(f, 'metadata', return_value=values), \
                 patch.object(f.d, 'query') as query:
                with self.assertRaises(a.b.BackupError):
                    f.apply({'databases': ['EnergyMonitoring']}, {}, object(), f.POLICY)
                query.assert_not_called()

    def test_policy_rejects_unknown_name_and_unsupported_view_attributes(self):
        with self.assertRaises(a.b.BackupError):
            f.apply({'databases': ['EnergyMonitoring']}, {}, object(), 'guess')
        for value in (dict(self.view(), algorithm='unexpected'), dict(self.view(), charset='unsafe;SQL'),
                      dict(self.view(), security='unexpected'), dict(self.view(), check='unexpected')):
            with self.assertRaises(a.b.BackupError):
                f.alter_statement(value, ['value'])
        view = dict(self.view(), check='CASCADED', security='INVOKER')
        sql = f.alter_statement(view, ['column`name'])
        self.assertIn(view['definition'], sql)
        self.assertIn('`column``name`', sql)
        self.assertIn('SQL SECURITY INVOKER', sql)
        self.assertTrue(sql.endswith('WITH CASCADED CHECK OPTION;'))

    def test_policy_detects_unapproved_post_alter_changes(self):
        before = [self.view(name) for name in sorted(f.VIEWS)]
        after = [dict(view, definer=f.TARGET, definition='select 0') for view in before]
        with patch.object(f.d, 'identity'), patch.object(f, 'metadata', side_effect=[before, after]), \
             patch.object(f.d, 'query', return_value=['76616c7565']):
            with self.assertRaises(a.b.BackupError):
                f.apply({'databases': ['EnergyMonitoring']}, {}, object(), f.POLICY)

    def test_retry_preserves_failed_report_and_refuses_wrong_or_successful_attempt(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / 'application-probe.json'
            token = uuid.uuid4().hex
            report = dict(result='APPLICATION_PROBE_FAILED', token=token, snapshot='fixture', archive_sha256='a' * 64)
            a.n.atomic_json(path, report)
            original = path.read_bytes()
            for supplied in (None, uuid.uuid4().hex):
                with self.assertRaises(a.b.BackupError):
                    a.preserve_failed_report(path, supplied, 'fixture', 'a' * 64)
            self.assertEqual(a.preserve_failed_report(path, token, 'fixture', 'a' * 64), report)
            history = path.with_name('application-probe-failed-' + token + '.json')
            self.assertEqual(history.read_bytes(), original)
            a.n.atomic_json(path, dict(report, result='APPLICATION_PROBE_PASSED_ACCEPTANCE_PENDING'))
            self.assertEqual(history.read_bytes(), original)
            with self.assertRaises(a.b.BackupError):
                a.preserve_failed_report(path, token, 'fixture', 'a' * 64)

    def test_retry_without_failed_attempt_is_refused(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / 'absent'
            self.assertIsNone(a.preserve_failed_report(path, None, 'fixture', 'a' * 64))
            with self.assertRaises(a.b.BackupError):
                a.preserve_failed_report(path, uuid.uuid4().hex, 'fixture', 'a' * 64)

    def test_software_identity_requires_unambiguous_backup_hash(self):
        expected = 'a' * 64
        self.assertEqual(a.expected_dll('OrchidApp.Web.dll SHA256=' + expected + '; energy captured'), expected)
        for value in ('unrecorded', 'OrchidApp.Web.dll SHA256=' + expected * 2,
                      ('OrchidApp.Web.dll SHA256=' + expected + ';') * 2):
            with self.assertRaises(a.b.BackupError):
                a.expected_dll(value)

    def test_clean_target_environment_and_unix_socket(self):
        with patch.dict(os.environ, {'SMTP_PASSWORD': 'source secret', 'DOTNET_STARTUP_HOOKS': '/unsafe'}, clear=True):
            env = a.environment(Path('/opt/dotnet/dotnet'), Path('/var/lib/probe'),
                                {'socket': '/var/lib/owned/server.sock'}, 'orchids', 'a' * 64, 5010)
        self.assertNotIn('SMTP_PASSWORD', env)
        self.assertNotIn('DOTNET_STARTUP_HOOKS', env)
        self.assertEqual(env['DOTNET_ENVIRONMENT'], 'Production')
        self.assertEqual(env['Monitoring__Enabled'], 'false')
        self.assertEqual(env['ASPNETCORE_URLS'], 'http://127.0.0.1:5010')
        self.assertIn('Server=/var/lib/owned/server.sock;', env['ConnectionStrings__OrchidDb'])
        self.assertNotIn('root', env['ConnectionStrings__OrchidDb'])

    def test_injection_and_non_generated_password_refused(self):
        for database, password, sock in [('orchids;Server=remote', 'a' * 64, '/safe'),
                                        ('orchids', 'captured password', '/safe'),
                                        ('orchids', 'a' * 64, '/unsafe;Host=remote')]:
            with self.assertRaises(a.b.BackupError):
                a.environment(Path('/runtime/dotnet'), Path('/probe'), {'socket': sock}, database, password, 5010)

    def test_readiness_requires_every_known_check_and_no_false_extras(self):
        good = {'ready': True, 'checks': dict.fromkeys(a.CHECKS, True)}
        self.assertEqual(a.readiness(json.dumps(good)), good)
        for value in ({'ready': True}, {'ready': True, 'checks': {}},
                      {'ready': True, 'checks': dict(good['checks'], nativePhotos=False)},
                      {'ready': True, 'checks': dict(good['checks'], futureCheck=False)},
                      {'ready': 1, 'checks': good['checks']}):
            with self.assertRaises(a.b.BackupError):
                a.readiness(json.dumps(value))

    def test_publication_config_and_uploads_are_not_activated(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            files = {'OrchidApp.Web.dll': b'synthetic DLL', 'OrchidApp.Web.deps.json': b'{}',
                     'OrchidApp.Web.runtimeconfig.json': b'{}', 'appsettings.Production.json': b'SECRET',
                     '.env': b'SECRET', 'nested/appsettings.json': b'SECRET',
                     'web.config': b'SECRET', 'wwwroot/uploads/old.jpg': b'SOURCE MEDIA',
                     'wwwroot/css/site.css': b'body{}'}
            inventory = {'publication': {'directory': True}}
            for name, data in files.items():
                inventory['publication/' + name] = {'size': len(data), 'sha256': hashlib.sha256(data).hexdigest()}
            expected = inventory['publication/OrchidApp.Web.dll']['sha256']
            manifest = {'format': a.p.FORMAT, 'architecture': 'aarch64', 'tfm': 'net8.0',
                        'web_dll_sha256': expected, 'inventory': inventory}
            archive = root / 'publication.tar.gz'
            with tarfile.open(archive, 'w:gz') as tar:
                directory = tarfile.TarInfo('publication')
                directory.type = tarfile.DIRTYPE
                tar.addfile(directory)
                for name, data in dict(files, **{'../manifest.json': json.dumps(manifest).encode()}).items():
                    info = tarfile.TarInfo('manifest.json' if name == '../manifest.json' else 'publication/' + name)
                    info.size = len(data)
                    tar.addfile(info, io.BytesIO(data))
            target = root / 'app'
            a.copy_publication(archive, target, expected)
            self.assertEqual((target / 'wwwroot/css/site.css').read_bytes(), b'body{}')
            self.assertFalse((target / 'appsettings.Production.json').exists())
            self.assertFalse((target / '.env').exists())
            self.assertFalse((target / 'wwwroot/uploads').exists())
            self.assertFalse((target / 'nested/appsettings.json').exists())
            self.assertFalse((target / 'web.config').exists())
            self.assertEqual(json.loads((target / 'appsettings.json').read_text())['Monitoring']['Enabled'], False)
            with self.assertRaises(a.b.BackupError):
                a.copy_publication(archive, target, expected)

    def test_missing_definer_fails_before_account_creation(self):
        with patch.object(a.d, 'identity'), patch.object(a.d, 'query', side_effect=[['missing@localhost'], ['root@localhost']]) as query:
            with self.assertRaises(a.b.BackupError):
                a.provision({'photo_database': 'orchids', 'databases': ['orchids']}, {}, object())
            self.assertEqual(query.call_count, 2)

    @unittest.skipUnless(sys.platform.startswith('linux'), '/proc listener ownership requires Linux')
    def test_real_loopback_listener_and_bounded_http(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / 'witness').write_bytes(b'fixture')
            with socket.socket() as reservation:
                reservation.bind(('127.0.0.1', 0))
                port = reservation.getsockname()[1]
            process = subprocess.Popen([sys.executable, '-m', 'http.server', str(port), '--bind', '127.0.0.1'],
                                       cwd=root, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            try:
                for _ in range(100):
                    if a.owns_listener(process, port):
                        break
                    time.sleep(.05)
                self.assertEqual(a.get(process, port, '/witness', 7), b'fixture')
                self.assertIsNone(a.get(process, port, '/witness', 7, hashlib.sha256(b'fixture').hexdigest()))
                with self.assertRaises(a.b.BackupError):
                    a.get(process, port, '/witness', 7, '0' * 64)
                with self.assertRaises(a.b.BackupError):
                    a.get(process, port, '/witness', 2)
                with self.assertRaises(a.b.BackupError):
                    a.get(process, port + 1, '/witness', 7)
            finally:
                process.terminate()
                process.wait(timeout=10)
            with self.assertRaises(a.b.BackupError):
                a.owns_listener(process, port)


if __name__ == '__main__':
    unittest.main()
