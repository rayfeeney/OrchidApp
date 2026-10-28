"""Exercise evidence failures and optional-mode isolation without a database."""
import importlib.util
import json
import hashlib
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
TEMP_ROOT = ROOT/'artifacts/feature-checks'
TEMP_ROOT.mkdir(parents=True, exist_ok=True)
spec = importlib.util.spec_from_file_location('feature_evidence', ROOT/'scripts/run-feature-checks.py')
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


class EvidenceChecks(unittest.TestCase):
    def test_isolated_environment_removes_optional_modes(self):
        with patch.dict(os.environ, {'GREENHOUSE_TEST_CONNECTION': 'private', 'GREENHOUSE_BENCHMARK': '1',
                                     'GREENHOUSE_DISPOSABLE_INSTANCE': '1', 'MARIADB_PASSWORD': 'private'}):
            env = runner.child_environment('isolated')
            self.assertFalse(any(k.upper().startswith(('GREENHOUSE_', 'MARIADB_')) for k in env))

    def test_database_requires_explicit_confirmation(self):
        with patch.dict(os.environ, {}, clear=True):
            with self.assertRaises(ValueError):
                runner.child_environment('greenhouse-db')

    def test_failures_retained_and_other_checks_continue(self):
        with tempfile.TemporaryDirectory(prefix='evidence-test-', dir=TEMP_ROOT) as folder:
            output = Path(folder)/'evidence'
            calls = []
            def fake(command, **kwargs):
                calls.append(command)
                kwargs['stdout'].write('synthetic check output\n')
                return type('Result', (), {'returncode': 7 if len(calls) == 1 else 0})()
            with patch.object(runner, 'metadata', return_value='fixture'), patch.object(runner, 'ISOLATED', ('One', 'Two')), \
                    patch.object(runner.platform, 'platform', return_value='fixture OS'), \
                    patch.object(runner.platform, 'machine', return_value='fixture CPU'), \
                    patch.object(runner.subprocess, 'run', side_effect=fake):
                self.assertEqual(runner.run(ROOT, output, 'isolated', 5), 1)
            report = json.loads((output/'report.json').read_text())
            self.assertEqual([c['status'] for c in report['checks']], ['failed', 'passed'])
            self.assertEqual(report['checks'][0]['exitCode'], 7)
            self.assertTrue(all((output/c['log']).is_file() for c in report['checks']))
            for check in report['checks']:
                self.assertEqual(check['logSha256'], hashlib.sha256((output/check['log']).read_bytes()).hexdigest())
            self.assertEqual(report['status'], 'failed')

    def test_invalid_database_configuration_writes_failed_report(self):
        with tempfile.TemporaryDirectory(prefix='evidence-test-', dir=TEMP_ROOT) as folder, patch.dict(os.environ, {}, clear=True), \
                patch.object(runner, 'metadata', return_value='fixture'):
            output = Path(folder)/'evidence'
            self.assertEqual(runner.run(ROOT, output, 'greenhouse-db', 5), 1)
            report = json.loads((output/'report.json').read_text())
            self.assertEqual(report['checks'], [])
            self.assertIn('configurationError', report)

    def test_source_fingerprint_ignores_private_settings_but_tracks_code(self):
        with tempfile.TemporaryDirectory(prefix='evidence-test-', dir=TEMP_ROOT) as folder:
            root = Path(folder)
            (root/'src').mkdir()
            code = root/'src/feature.cs'
            code.write_text('original')
            first = runner.source_identity(root)
            (root/'src/appsettings.Production.json').write_text('private fixture')
            (root/'.env').write_text('private fixture')
            self.assertEqual(first, runner.source_identity(root))
            code.write_text('changed')
            self.assertNotEqual(first['sha256'], runner.source_identity(root)['sha256'])

    def test_launch_errors_and_timeouts_are_failed_evidence(self):
        for error in (FileNotFoundError(), runner.subprocess.TimeoutExpired('fixture', 1)):
            with self.subTest(error=type(error).__name__), tempfile.TemporaryDirectory(prefix='evidence-test-', dir=TEMP_ROOT) as folder:
                output = Path(folder)/'evidence'
                with patch.object(runner, 'metadata', return_value='unavailable'), patch.object(runner, 'ISOLATED', ('One',)), \
                        patch.object(runner.platform, 'platform', return_value='fixture OS'), \
                        patch.object(runner.platform, 'machine', return_value='fixture CPU'), \
                        patch.object(runner.subprocess, 'run', side_effect=error):
                    self.assertEqual(runner.run(ROOT, output, 'isolated', 1), 1)
                check = json.loads((output/'report.json').read_text())['checks'][0]
                self.assertEqual(check['status'], 'failed')
                self.assertIsNone(check['exitCode'])
                self.assertEqual(check['runnerError'], type(error).__name__)


if __name__ == '__main__':
    unittest.main()
