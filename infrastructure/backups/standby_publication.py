"""Capture/verify matching ARM64 application bytes without touching databases.

Publication archives may contain settings/secrets. Keep private; never commit or
upload them as CI diagnostics. Capturing is not application restore acceptance.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shutil
import sys
import tarfile
import tempfile

import orchid_backup as b
import nightly_backup as n

FORMAT = 'orchidapp-linux-publication-v1'
REQUIRED = ('OrchidApp.Web.dll', 'OrchidApp.Web.deps.json', 'OrchidApp.Web.runtimeconfig.json')


def fingerprint(value):
    b.require(isinstance(value, str) and re.fullmatch(r'[0-9a-f]{64}', value), 'Explicit expected DLL SHA-256 required')
    return value


def private_parent(path):
    path.mkdir(mode=0o700, parents=True, exist_ok=True)
    if os.name == 'posix':
        info = path.stat()
        b.require(info.st_uid in (0, os.geteuid()) and not info.st_mode & 0o077,
                  'Publication output directory must be owned by root/operator and mode 700')
    return path


def verify(archive, expected, limit=10 * 1024**3):
    expected = fingerprint(expected)
    actual, manifest, total = {}, None, 0
    with tarfile.open(archive, 'r:gz') as tar:
        for member in tar:
            b.safe_path(member.name)
            b.require(member.name not in actual and (member.isdir() or member.isfile()), 'Unsafe/duplicate publication member')
            b.require(member.name == 'manifest.json' or member.name == 'publication'
                      or member.name.startswith('publication/'), 'Unexpected publication payload')
            total += member.size
            b.require(total <= limit and len(actual) < 1000000, 'Publication extraction limit exceeded')
            if member.isdir():
                actual[member.name] = {'directory': True}
            else:
                with tar.extractfile(member) as src:
                    if member.name == 'manifest.json':
                        b.require(member.size <= 16 * 1024**2, 'Publication manifest too large')
                        manifest = json.load(src)
                        actual[member.name] = {}
                    else:
                        h, size = hashlib.sha256(), 0
                        for chunk in iter(lambda: src.read(1024 * 1024), b''):
                            size += len(chunk)
                            h.update(chunk)
                        b.require(size == member.size, 'Truncated publication member')
                        actual[member.name] = {'size': size, 'sha256': h.hexdigest()}
    b.require(isinstance(manifest, dict) and manifest.get('format') == FORMAT, 'Unsupported publication archive')
    actual.pop('manifest.json', None)
    b.require(actual == manifest.get('inventory'), 'Publication inventory/hash mismatch')
    b.require(actual.get('publication') == {'directory': True}, 'Publication root directory missing')
    b.require(manifest.get('architecture') in ('aarch64', 'arm64') and manifest.get('tfm') == 'net8.0', 'Expected ARM64 .NET 8 publication')
    b.require(manifest.get('web_dll_sha256') == expected
              and actual.get('publication/OrchidApp.Web.dll', {}).get('sha256') == expected, 'Publication DLL does not match backup')
    for name in REQUIRED:
        b.require(actual.get('publication/' + name, {}).get('size', 0) > 0, 'Required publication file missing')
    return manifest


def capture(source, destination, expected, reserve=1024**3):
    expected = fingerprint(expected)
    source, destination = b.absolute(str(source)), b.absolute(str(destination))
    b.require(source.is_dir() and source != source.parent and destination.name.endswith('.tar.gz'), 'Explicit publication directory/archive required')
    b.require(not b.overlaps(source, destination.parent), 'Publication output must be separate from source')
    b.require(not destination.exists(), 'Refusing to overwrite an existing publication archive')
    parent = private_parent(destination.parent)
    architecture = platform.machine().lower()
    b.require(architecture in ('aarch64', 'arm64'), 'Capture on the source ARM64 Pi')
    for name in REQUIRED:
        b.require((source / name).is_file(), 'Required publication file missing')
    b.require(b.digest(source / 'OrchidApp.Web.dll') == expected, 'Source publication differs from backup fingerprint')
    runtime = json.loads((source / 'OrchidApp.Web.runtimeconfig.json').read_text())['runtimeOptions']
    b.require(runtime.get('tfm') == 'net8.0', 'Source runtime contract is not .NET 8')
    before = b.inventory(source)
    size = sum(entry.get('size', 0) for entry in before.values())
    b.require(shutil.disk_usage(parent).free >= 3 * size + reserve, 'Insufficient publication capture space')
    with tempfile.TemporaryDirectory(dir=parent, prefix='.publication-') as temp:
        root = Path(temp)
        payload = root / 'payload'
        payload.mkdir(mode=0o700)
        shutil.copytree(source, payload / 'publication')
        b.require(b.inventory(payload / 'publication') == before and b.inventory(source) == before,
                  'Publication changed during capture; no completed archive')
        manifest = {'format': FORMAT, 'captured_at': n.now(), 'architecture': architecture,
                    'tfm': runtime['tfm'], 'web_dll_sha256': expected, 'source_path': str(source),
                    'inventory': b.inventory(payload),
                    'note': 'Captured bytes only; target configuration and application acceptance required'}
        n.atomic_json(payload / 'manifest.json', manifest)
        partial = root / 'publication.partial'
        fd = os.open(partial, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(fd, 'wb') as out:
            with tarfile.open(fileobj=out, mode='w:gz', dereference=False) as tar:
                for child in sorted(payload.iterdir()):
                    tar.add(child, arcname=child.name)
            out.flush()
            os.fsync(out.fileno())
        verify(partial, expected)
        # Atomic no-overwrite publication on the same filesystem.
        os.link(partial, destination)
        if os.name == 'posix':
            fd = os.open(parent, os.O_RDONLY | os.O_DIRECTORY)
            try:
                os.fsync(fd)
            finally:
                os.close(fd)
    return {'result': 'PUBLICATION_CAPTURED', 'archive': str(destination),
            'size_bytes': destination.stat().st_size, 'sha256': b.digest(destination),
            'web_dll_sha256': expected, 'source_changed': False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('operation', choices=('capture', 'verify'))
    parser.add_argument('--expected-web-sha256', required=True)
    parser.add_argument('--source')
    parser.add_argument('--destination')
    parser.add_argument('--archive')
    args = parser.parse_args()
    os.umask(0o077)
    try:
        b.require(sys.platform.startswith('linux'), 'Production publication command requires Linux')
        if args.operation == 'capture':
            b.require(args.source and args.destination, 'Explicit --source and --destination required')
            result = capture(Path(args.source), Path(args.destination), args.expected_web_sha256)
        else:
            b.require(args.archive, '--archive required')
            manifest = verify(b.absolute(args.archive), args.expected_web_sha256)
            result = {'result': 'PUBLICATION_VERIFIED', 'web_dll_sha256': manifest['web_dll_sha256'],
                      'architecture': manifest['architecture'], 'tfm': manifest['tfm']}
        print(json.dumps(result, indent=2))
        return 0
    except Exception as ex:
        print('ERROR: ' + (str(ex) if isinstance(ex, b.BackupError) else 'Publication operation failed; inspect private source/destination'), file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
