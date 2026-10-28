"""Run a curated feature-check set and retain bounded, revision-aware evidence.

No .env is read. Database mode requires a new dedicated disposable server.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import platform
import subprocess
import sys
import time
import uuid

ISOLATED = (
    'RichNotes', 'Navigation', 'NameSearch', 'EnvironmentSummary',
    'GreenhouseCharts', 'SchemaBaseline', 'MigrationHistory',
    'DevelopmentConfiguration',
)


def metadata(command, root):
    try:
        result = subprocess.run(command, cwd=root, capture_output=True, text=True, timeout=30)
        return result.stdout.strip() if result.returncode == 0 else 'unavailable'
    except (OSError, subprocess.TimeoutExpired):
        return 'unavailable'


def source_identity(root):
    digest = hashlib.sha256()
    count = 0
    # Deliberately enumerate source owners, never private configuration or build outputs.
    for folder in ('src', 'tests', 'scripts', 'database', '.github'):
        for path in sorted((root / folder).rglob('*')):
            relative = path.relative_to(root)
            if not path.is_file() or any(p in ('bin', 'obj', '__pycache__') for p in relative.parts):
                continue
            if path.suffix.lower() not in ('.cs', '.csproj', '.cshtml', '.js', '.css', '.sql', '.ps1', '.py', '.yml', '.json', '.props', '.targets'):
                continue
            if 'appsettings' in path.name.lower() or path.name.startswith('.env'):
                continue
            digest.update(relative.as_posix().encode() + b'\0' + hashlib.sha256(path.read_bytes()).digest())
            count += 1
    for name in ('Directory.Build.props', 'Directory.Build.targets', 'global.json', 'NuGet.Config', 'nuget.config', 'OrchidApp.sln'):
        path = root/name
        if path.is_file():
            digest.update(name.encode() + b'\0' + hashlib.sha256(path.read_bytes()).digest())
            count += 1
    return {'sha256': digest.hexdigest(), 'files': count,
            'scope': 'selected source extensions under src/tests/scripts/database/.github plus root build metadata; excludes private configuration and build outputs'}


def child_environment(mode):
    env = os.environ.copy()
    # Optional database, benchmark and native-probe modes must never leak into isolated runs.
    for key in list(env):
        if key.upper().startswith(('GREENHOUSE_', 'PHOTO_TEST_', 'MARIADB_', 'MYSQL_')):
            env.pop(key)
    if mode == 'greenhouse-db':
        if os.environ.get('GREENHOUSE_DISPOSABLE_INSTANCE') != '1' or not os.environ.get('GREENHOUSE_TEST_CONNECTION'):
            raise ValueError('Database mode requires explicit disposable-instance confirmation and connection environment variables; no .env is read.')
        env['GREENHOUSE_DISPOSABLE_INSTANCE'] = '1'
        env['GREENHOUSE_TEST_CONNECTION'] = os.environ['GREENHOUSE_TEST_CONNECTION']
    return env


def run(root, output, mode, timeout):
    output.mkdir(parents=True, exist_ok=False)
    top = metadata(['git', 'rev-parse', '--show-toplevel'], root)
    own_checkout = top != 'unavailable' and Path(top).resolve() == root.resolve()
    report = {'formatVersion': 1, 'startedUtc': datetime.now(timezone.utc).isoformat(),
              'mode': mode, 'revision': metadata(['git', 'rev-parse', 'HEAD'], root) if own_checkout else 'unavailable',
              'workingTree': metadata(['git', 'status', '--porcelain', '--untracked-files=no'], root) if own_checkout else 'unavailable',
              'source': source_identity(root),
              'environment': {'os': platform.platform(), 'architecture': platform.machine(),
                              'python': platform.python_version(), 'dotnetSdk': metadata(['dotnet', '--version'], root),
                              'dotnetRuntimes': metadata(['dotnet', '--list-runtimes'], root)},
              'checks': [], 'notRun': [
                  {'category': 'benchmark', 'reason': 'Dense synthetic benchmark is opt-in and is not enabled by this runner.'},
                  {'category': 'device', 'reason': 'No hardware, production, native photo, service, installer or older-release acceptance is implied.'},
                  {'category': 'other-integration', 'reason': 'Lifecycle, migration, backup and installer jobs retain their separate reports/logs.'}]}
    try:
        env = child_environment(mode)
        names = ISOLATED if mode == 'isolated' else ('GreenhouseCharts',)
        if mode == 'isolated':
            report['notRun'].append({'category': 'database', 'reason': 'No database fixture was selected.'})
        for name in names:
            command = ['dotnet', 'run', '--configuration', 'Release', '--project', f'tests/{name}.Checks/{name}.Checks.csproj']
            started = time.monotonic()
            log = output / f'{name}.log'
            code = None
            error = None
            print(f'Running {name} ({mode})', flush=True)
            with log.open('w', encoding='utf-8') as stream:
                try:
                    result = subprocess.run(command, cwd=root, env=env, stdout=stream, stderr=subprocess.STDOUT,
                                            timeout=timeout)
                    code = result.returncode
                except (OSError, subprocess.TimeoutExpired) as exc:
                    error = type(exc).__name__
                    stream.write(f'\nRunner failure: {error}\n')
            report['checks'].append({'name': name, 'category': mode, 'command': command,
                                     'exitCode': code, 'status': 'passed' if code == 0 else 'failed',
                                     'runnerError': error, 'seconds': round(time.monotonic()-started, 3),
                                     'log': log.name, 'logSha256': hashlib.sha256(log.read_bytes()).hexdigest()})
            print(f'{name}: {report["checks"][-1]["status"]}', flush=True)
    except ValueError as exc:
        report['configurationError'] = str(exc)
    finally:
        report['finishedUtc'] = datetime.now(timezone.utc).isoformat()
        report['status'] = ('passed' if report['checks'] and all(c['status'] == 'passed' for c in report['checks'])
                            and 'configurationError' not in report else 'failed')
        (output/'report.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    print(f'Evidence: {output / "report.json"}', flush=True)
    return 0 if report['status'] == 'passed' else 1


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--mode', choices=('isolated', 'greenhouse-db'), default='isolated')
    parser.add_argument('--output', type=Path, default=Path('artifacts/feature-checks'))
    parser.add_argument('--timeout', type=int, default=600, help='Maximum seconds per check executable')
    args = parser.parse_args()
    if args.timeout < 1:
        parser.error('--timeout must be positive')
    root = Path(__file__).resolve().parent.parent
    folder = args.output.resolve() / (datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')+'-'+uuid.uuid4().hex[:8])
    sys.exit(run(root, folder, args.mode, args.timeout))
