"""Package Block 2 candidate source/examples/tests only; never live data."""
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
    'infrastructure/backups/standby_restore.py',
    'infrastructure/backups/standby_database.py',
    'infrastructure/backups/standby_publication.py',
    'infrastructure/backups/standby_application.py',
    'infrastructure/backups/standby_definers.py',
    'infrastructure/backups/standby_acceptance.py',
    'infrastructure/backups/standby_reporting.py',
    'infrastructure/backups/standby_job.py',
    'infrastructure/backups/orchidapp-standby.service',
    'infrastructure/backups/orchidapp-standby.timer',
    'infrastructure/backups/orchidapp-standby-monitor.service',
    'infrastructure/backups/orchidapp-standby-monitor.timer',
    'infrastructure/backups/standby.logrotate',
    'infrastructure/backups/standby-email.example.json',
    'infrastructure/backups/standby.example.json',
    'tests/LinuxBackup.Checks/standby_checks.py',
    'tests/LinuxBackup.Checks/standby_database_checks.py',
    'tests/LinuxBackup.Checks/standby_publication_checks.py',
    'tests/LinuxBackup.Checks/standby_application_checks.py',
    'tests/LinuxBackup.Checks/standby_acceptance_checks.py',
    'tests/LinuxBackup.Checks/standby_reporting_checks.py',
    'tests/LinuxBackup.Checks/standby_job_checks.py',
    'tests/LinuxBackup.Checks/standby_native_linux.py',
    'docs/user-guides/linux/nightly-standby-restore.md',
    'docs/maintenance/pi2-standby-preparation.md',
]
out = repo.parent / 'standby-delivery'
out.mkdir(exist_ok=True)
archive = out / 'orchidapp-block2-candidate.tar.gz'
payload = {name: (repo / name).read_bytes().replace(b'\r\n', b'\n') for name in files}
payload['SHA256SUMS'] = ''.join(hashlib.sha256(data).hexdigest() + '  ' + name + '\n'
                              for name, data in payload.items()).encode()
payload['SOURCE.json'] = json.dumps({'base_commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=repo).decode().strip(),
                                   'stage': 'Block 2 candidate: coordinated restore/acceptance/retention/email and inactive timer templates; installed full-cycle acceptance pending'}, indent=2).encode()
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
