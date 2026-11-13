"""Package only reviewed Block 1 sources, examples, tests and guide; no credentials."""
import hashlib
import io
import json
from pathlib import Path
import subprocess
import tarfile

repo = Path(__file__).resolve().parents[1]
files = [
    'infrastructure/backups/orchid_backup.py',
    'infrastructure/backups/nightly_backup.py',
    'infrastructure/backups/configure_nightly_secrets.py',
    'infrastructure/backups/nightly.example.json',
    'infrastructure/backups/nightly.logrotate',
    'infrastructure/backups/orchidapp-nightly.service',
    'infrastructure/backups/orchidapp-nightly.timer',
    'infrastructure/backups/orchidapp-nightly-monitor.service',
    'infrastructure/backups/orchidapp-nightly-monitor.timer',
    'tests/LinuxBackup.Checks/nightly_checks.py',
    'docs/user-guides/linux/nightly-multi-database-backup.md',
]
out = repo.parent / 'backup-delivery'
out.mkdir(exist_ok=True)
archive = out / 'orchidapp-block1-candidate.tar.gz'
payload = {name: (repo / name).read_bytes().replace(b'\r\n', b'\n') for name in files}
hashes = ''.join(hashlib.sha256(data).hexdigest() + '  ' + name + '\n' for name, data in payload.items())
payload['SHA256SUMS'] = hashes.encode()
payload['SOURCE.json'] = json.dumps({'base_commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=repo).decode().strip(),
                                   'status': 'Uncommitted Block 1 candidate; not deployed; use SHA256SUMS for exact payload identity'}, indent=2).encode()
with tarfile.open(archive, 'w:gz') as tar:
    for name, data in payload.items():
        info = tarfile.TarInfo(name)
        info.size, info.mode = len(data), 0o644
        tar.addfile(info, io.BytesIO(data))
with tarfile.open(archive, 'r:gz') as tar:
    assert {m.name for m in tar} == set(payload)
    for name, data in payload.items():
        assert tar.extractfile(name).read() == data
checksum = hashlib.sha256(archive.read_bytes()).hexdigest()
(out / (archive.name + '.sha256')).write_text(checksum + '  ' + archive.name + '\n')
print(archive)
print('SHA256:', checksum)
