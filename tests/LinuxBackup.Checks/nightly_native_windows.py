"""Owned, pipe-only Windows MariaDB fixture; no live endpoint argument is accepted.

Exercises actual multi-database capture and manual SQL round trip, not Block 2.
Service/readiness adapters are synthetic. Fixture files are retained for inspection.
"""
from contextlib import contextmanager
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
from unittest.mock import patch
import uuid

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'infrastructure/backups'))
import nightly_backup as n


def main():
    if sys.platform != 'win32':
        raise SystemExit('This owned fixture requires Windows MariaDB 10.11')
    base = Path(os.environ.get('ProgramW6432', r'C:\Program Files')) / 'MariaDB 10.11'
    for name in ('mariadb-install-db.exe', 'mariadbd.exe', 'mariadb.exe', 'mariadb-dump.exe'):
        if not (base / 'bin' / name).is_file():
            raise SystemExit('Required fixture executable missing')
    evidence = Path(__file__).resolve().parents[2] / 'artifacts/feature-checks'
    evidence.mkdir(parents=True, exist_ok=True)
    root = Path(tempfile.mkdtemp(prefix='orchid-nightly-native-', dir=evidence))
    token = uuid.uuid4().hex
    (root / 'owner-token').write_text(token)
    data = root / 'data'
    pipe = 'orchid-nightly-' + token
    env = dict(os.environ)
    env.pop('MYSQL_PWD', None)
    env['PATH'] = str(base / 'bin') + os.pathsep + env.get('PATH', '')
    password = 'synthetic-fixture-' + token
    init = subprocess.run([str(base / 'bin/mariadb-install-db.exe'), '--datadir=' + str(data),
                           '--password=' + password], stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                          timeout=120, env=env, creationflags=subprocess.CREATE_NO_WINDOW)
    if init.returncode:
        (root / 'init-error.txt').write_bytes(init.stdout + init.stderr)
        raise RuntimeError('Owned initialization failed; see retained fixture ' + str(root))
    defaults = root / 'fixture.cnf'
    defaults.write_text('[client]\nprotocol=pipe\nsocket=' + pipe + '\nuser=root\npassword=' + password + '\n')
    logs = (root / 'server.log').open('wb')
    server = subprocess.Popen([str(base / 'bin/mariadbd.exe'), '--no-defaults', '--basedir=' + str(base),
                               '--datadir=' + str(data), '--skip-networking', '--enable-named-pipe',
                               '--socket=' + pipe, '--console'], stdout=logs, stderr=logs, env=env,
                              creationflags=subprocess.CREATE_NO_WINDOW)
    c = {'client_defaults_file': defaults, 'backup_root': root, 'timeout_seconds': 30, 'database': 'orchids'}
    original_env_path = os.environ.get('PATH', '')
    original_pwd = os.environ.pop('MYSQL_PWD', None)
    os.environ['PATH'] = env['PATH']
    try:
        def sql(command, database=None):
            args = n.b.client(c)
            if database:
                args.append(database)
            return n.b.run(c, args, stdin=command.encode()).decode().strip()
        for _ in range(60):
            if server.poll() is not None:
                raise RuntimeError('Owned server exited; see ' + str(root))
            try:
                identity = sql('SELECT @@datadir, @@socket, @@skip_networking;').split('\t')
                break
            except Exception:
                time.sleep(0.5)
        else:
            raise RuntimeError('Owned server did not become ready')
        if Path(identity[0]).resolve() != data.resolve() or identity[1] != pipe or identity[2] != '1':
            raise RuntimeError('Owned fixture identity mismatch; no SQL setup permitted')
        sql('CREATE DATABASE orchids; CREATE DATABASE EnergyMonitoring;')
        sql('CREATE TABLE witness(id INT PRIMARY KEY,value VARCHAR(30)) ENGINE=InnoDB; '
            "INSERT INTO witness VALUES(1,'old orchid'); "
            'CREATE TABLE plantphoto(plantId INT,fileName VARCHAR(100),thumbnailFileName VARCHAR(100),isActive INT); '
            'CREATE TABLE taxonphoto(taxonId INT,fileName VARCHAR(100),thumbnailFileName VARCHAR(100),isActive INT); '
            "INSERT INTO plantphoto VALUES(1,'photo.jpg','thumb.jpg',1);", 'orchids')
        sql('CREATE TABLE witness(id INT PRIMARY KEY,value VARCHAR(30)) ENGINE=InnoDB; '
            "INSERT INTO witness VALUES(1,'old energy');", 'EnergyMonitoring')
        uploads = root / 'uploads'
        (uploads / 'plants/1').mkdir(parents=True)
        (uploads / 'plants/1/photo.jpg').write_bytes(b'synthetic original photo')
        (uploads / 'plants/1/thumb.jpg').write_bytes(b'synthetic original thumbnail')
        payload = root / 'payload'
        payload.mkdir()
        c.update(collection_id=str(uuid.uuid4()), databases=['orchids', 'EnergyMonitoring'],
                 photo_database='orchids', sources={'uploads': uploads}, uploads_source='uploads',
                 software_identity='synthetic native fixture', max_unpack_bytes=10 * 1024**2)
        @contextmanager
        def stopped(_):
            yield
        status = {'snapshot': 'orchidset-20261113T020000Z-' + token, 'started_at': n.now()}
        with patch.object(n.b, 'stop_writers', stopped), patch.object(n.b, 'writers_stopped'), patch.object(n, 'readiness'):
            n.capture(c, payload, status)
        archive = root / (status['snapshot'] + '.tar.gz')
        with n.tarfile.open(archive, 'w:gz') as tar:
            for child in payload.iterdir():
                tar.add(child, arcname=child.name)
        n.validate(archive, c)
        # A real second SQL writer must fail to write while the lock is held.
        with n.b.database_read_lock(c):
            try:
                sql("SET lock_wait_timeout=1; UPDATE witness SET value='blocked' WHERE id=1;", 'EnergyMonitoring')
            except n.b.BackupError:
                pass
            else:
                raise AssertionError('Concurrent write was not blocked')
        # Guard destructive fixture reset immediately before its use.
        if server.poll() is not None or (root / 'owner-token').read_text() != token:
            raise RuntimeError('Lost fixture ownership')
        again = sql('SELECT @@datadir, @@socket, @@skip_networking;').split('\t')
        if again != identity:
            raise RuntimeError('Fixture identity changed')
        sql('DROP DATABASE orchids; DROP DATABASE EnergyMonitoring;')
        for name in c['databases']:
            n.b.run(c, n.b.client(c), stdin=(payload / 'databases' / (name + '.sql')).read_bytes())
        assert sql('SELECT value FROM witness;', 'orchids') == 'old orchid'
        assert sql('SELECT value FROM witness;', 'EnergyMonitoring') == 'old energy'
        assert n.b.photo_paths(c) == ['plants/1/photo.jpg', 'plants/1/thumb.jpg']
        assert (payload / 'sources/uploads/plants/1/photo.jpg').read_bytes() == b'synthetic original photo'
        assert (payload / 'accounts.sql').stat().st_size > 0
        print('PASS: native two-database capture, held read lock, SQL round trip, photo bytes and account export')
        print('Fixture retained:', root)
    finally:
        # Only terminate the exact process created above; no endpoint-based shutdown.
        if server.poll() is None:
            server.terminate()
            server.wait(timeout=30)
        logs.close()
        os.environ['PATH'] = original_env_path
        if original_pwd is not None:
            os.environ['MYSQL_PWD'] = original_pwd


if __name__ == '__main__':
    main()
