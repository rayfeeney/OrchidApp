"""Source/tests/operator notes only for the Pi 1 kernel-lock correction."""
import hashlib
import io
import json
from pathlib import Path
import subprocess
import tarfile

repo = Path(__file__).resolve().parents[1]
names = [
    'infrastructure/backups/orchid_backup.py',
    'infrastructure/backups/nightly_backup.py',
    'tests/LinuxBackup.Checks/nightly_checks.py',
    'docs/user-guides/linux/nightly-multi-database-backup.md',
    'docs/maintenance/pi1-nightly-lock-recovery.md',
]
payload = {name: (repo / name).read_bytes().replace(b'\r\n', b'\n') for name in names}
payload['SOURCE.json'] = json.dumps({'commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=repo).decode().strip(),
                                   'purpose': 'Pi 1 nightly kernel lock and SIGHUP cleanup correction'}, indent=2).encode()
payload['SHA256SUMS'] = ''.join(hashlib.sha256(data).hexdigest() + '  ' + name + '\n'
                              for name, data in payload.items()).encode()
output = repo.parent / 'backup-delivery' / 'orchidapp-nightly-lock-fix.tar.gz'
output.parent.mkdir(exist_ok=True)
with tarfile.open(output, 'w:gz') as archive:
    for name, data in payload.items():
        entry = tarfile.TarInfo(name)
        entry.size, entry.mode = len(data), 0o644
        archive.addfile(entry, io.BytesIO(data))
with tarfile.open(output, 'r:gz') as archive:
    assert {m.name for m in archive} == set(payload)
    for name, data in payload.items():
        assert archive.extractfile(name).read() == data
print(output)
print('SHA256:', hashlib.sha256(output.read_bytes()).hexdigest())
