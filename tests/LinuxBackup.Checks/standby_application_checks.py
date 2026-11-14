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
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'infrastructure/backups'))
import standby_application as a


class Application(unittest.TestCase):
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
