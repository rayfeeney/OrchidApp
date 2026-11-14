"""Owned Linux 10.11.14 dump -> 11.8 candidate fixture; no live endpoint args.

Creates its own network-none source Docker container and private host candidate
directories. Retains private local evidence and removes only its labelled container.
"""
from datetime import datetime, timedelta, timezone
import json
import os
from pathlib import Path
import pwd
import shutil
import subprocess
import sys
import tarfile
import tempfile
import time
from unittest.mock import patch
import uuid

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'infrastructure/backups'))
import standby_restore as s
import standby_database as d
import standby_application as a
import standby_definers as f


def main():
    if not sys.platform.startswith('linux') or os.geteuid() == 0:
        raise SystemExit('Use a non-root isolated Linux test runner with Docker and MariaDB 11.8 tools')
    for tool in ('docker', 'mariadbd', 'mariadb', 'mariadb-install-db'):
        if not shutil.which(tool):
            raise SystemExit('Missing fixture tool: ' + tool)
    root = Path(tempfile.mkdtemp(prefix='sbn-'))
    root.chmod(0o700)
    token = uuid.uuid4().hex
    name = 'orchid-standby-source-' + token
    label = 'orchid.standby.fixture'
    (root / 'owner-token').write_text(token)
    password = 'synthetic-' + token
    def docker(*args):
        p = subprocess.run(['docker', *args], stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=180)
        if p.returncode:
            (root / ('docker-error-' + uuid.uuid4().hex + '.log')).write_bytes(p.stderr)
            raise RuntimeError('Owned Docker fixture operation failed; private logs retained at ' + str(root))
        return p.stdout
    def owned():
        metadata = json.loads(docker('inspect', name))[0]
        if metadata['Config']['Labels'].get(label) != token or metadata['HostConfig']['NetworkMode'] != 'none':
            raise RuntimeError('Source container ownership/isolation mismatch')
    def source(sql):
        owned()
        return docker('exec', name, 'mariadb', '--no-defaults', '--user=root', '--password=' + password,
                      '--batch', '--skip-column-names', '--execute=' + sql).decode().strip()
    created = False
    try:
        docker('run', '--detach', '--name', name, '--network', 'none', '--label', label + '=' + token,
               '--env', 'MARIADB_ROOT_PASSWORD=' + password, 'mariadb:10.11.14')
        created = True
        for _ in range(120):
            try:
                if source('SELECT 1;') == '1':
                    break
            except RuntimeError:
                pass
            time.sleep(0.5)
        else:
            raise RuntimeError('Owned source server did not become ready')
        if not source('SELECT @@version;').startswith('10.11.14'):
            raise RuntimeError('Wrong source server series')
        source("CREATE DATABASE orchids; CREATE DATABASE EnergyMonitoring; "
               "CREATE TABLE orchids.witness(id INT PRIMARY KEY,value VARCHAR(40)) ENGINE=InnoDB; "
               "INSERT INTO orchids.witness VALUES(1,'original orchid'); "
               "CREATE TABLE orchids.plantphoto(plantId INT,fileName VARCHAR(100),thumbnailFileName VARCHAR(100),isActive INT) ENGINE=InnoDB; "
               "CREATE TABLE orchids.taxonphoto(taxonId INT,fileName VARCHAR(100),thumbnailFileName VARCHAR(100),isActive INT) ENGINE=InnoDB; "
               "INSERT INTO orchids.plantphoto VALUES(1,'photo.jpg','thumb.jpg',1); "
               "CREATE VIEW orchids.fixture_view AS SELECT * FROM orchids.witness; "
               "CREATE FUNCTION orchids.fixture_value() RETURNS INT DETERMINISTIC RETURN 7; "
               "CREATE PROCEDURE orchids.fixture_get() SELECT value FROM orchids.witness; "
               "CREATE TRIGGER orchids.fixture_trigger BEFORE UPDATE ON orchids.witness FOR EACH ROW SET NEW.value=NEW.value; "
               "CREATE EVENT orchids.fixture_event ON SCHEDULE AT CURRENT_TIMESTAMP + INTERVAL 1 DAY DISABLE DO SELECT 1; "
               "CREATE TABLE EnergyMonitoring.witness(id INT PRIMARY KEY,value VARCHAR(40)) ENGINE=InnoDB; "
               "INSERT INTO EnergyMonitoring.witness VALUES(1,'original energy');")
        source("CREATE USER 'root'@'192.168.7.153' IDENTIFIED BY 'synthetic-source-only'; "
               "GRANT SELECT ON EnergyMonitoring.* TO 'root'@'192.168.7.153';")
        source("CREATE TABLE EnergyMonitoring.EnphaseInterval (IntervalEndUtc DATETIME, ProducedWh INT, "
               "ConsumedWh INT, ImportedWh INT, ExportedWh INT, ChargedWh INT, DischargedWh INT, BatterySocPct DECIMAL(5,2)); "
               "INSERT INTO EnergyMonitoring.EnphaseInterval VALUES('2026-07-15 12:15:00',100,80,20,40,10,5,75); "
               "CREATE TABLE EnergyMonitoring.Tariff (TariffId INT, EffectiveFromDate DATE, EffectiveToDate DATE, "
               "ImportRatePencePerKWh DECIMAL(8,3), ExportEffectiveFromDate DATE, ExportRatePencePerKWh DECIMAL(8,3)); "
               "INSERT INTO EnergyMonitoring.Tariff VALUES(1,'2026-01-01',NULL,25,'2026-01-01',15);")
        for view in sorted(f.VIEWS):
            if view == 'vw_EnphaseHourly':
                # Synthetic rows, but the observed query structures matter: date
                # grouping, battery aggregate and a named-zone tariff-date join.
                hour = "CAST(DATE_FORMAT(IntervalEndUtc - INTERVAL 1 SECOND,'%Y-%m-%d %H:00:00') AS DATETIME)"
                local = "CONVERT_TZ(h.IntervalStartUtc,'UTC','Europe/London')"
                export = 't.ExportEffectiveFromDate IS NOT NULL AND CAST(' + local + ' AS DATE)>=t.ExportEffectiveFromDate'
                body = 'SELECT h.IntervalStartUtc,' + local + ' AS IntervalStart,'
                body += ','.join('h.' + name for name in f.ENPHASE_COLUMNS[2:10])
                body += ',t.TariffId,t.ImportRatePencePerKWh,CAST(h.ImportedWh/1000.0*t.ImportRatePencePerKWh/100.0 AS DECIMAL(10,4)) AS ImportCostGBP,'
                body += 'CASE WHEN ' + export + ' THEN t.ExportRatePencePerKWh ELSE NULL END AS ExportRatePencePerKWh,'
                body += 'CASE WHEN ' + export + ' AND t.ExportRatePencePerKWh IS NOT NULL THEN '
                body += 'CAST(h.ExportedWh/1000.0*t.ExportRatePencePerKWh/100.0 AS DECIMAL(10,4)) ELSE NULL END AS ExportIncomeGBP '
                body += 'FROM (SELECT ' + hour + ' AS IntervalStartUtc,'
                body += ','.join('SUM(' + name + ') AS ' + name for name in f.ENPHASE_COLUMNS[2:8])
                body += ",CAST(SUBSTRING_INDEX(GROUP_CONCAT(BatterySocPct ORDER BY IntervalEndUtc DESC SEPARATOR ','),',',1) AS DECIMAL(5,2)) AS BatterySocPct,"
                body += 'COUNT(*) AS IntervalCount FROM EnergyMonitoring.EnphaseInterval GROUP BY ' + hour + ') h '
                body += 'LEFT JOIN EnergyMonitoring.Tariff t ON CAST(' + local + " AS DATE) BETWEEN t.EffectiveFromDate AND COALESCE(t.EffectiveToDate,'9999-12-31')"
            else:
                body = 'SELECT value FROM EnergyMonitoring.witness'
            source("CREATE DEFINER='root'@'192.168.7.153' SQL SECURITY DEFINER VIEW EnergyMonitoring.`"
                   + view + '` AS ' + body + ';')
        dumps = {}
        for database in ('orchids', 'EnergyMonitoring'):
            owned()
            dumps[database] = docker('exec', name, 'mariadb-dump', '--no-defaults', '--user=root',
                                      '--password=' + password, '--skip-lock-tables', '--routines', '--triggers',
                                      '--events', '--hex-blob', '--databases', database)
        state_root = root / 'state'
        state_root.mkdir(mode=0o700)
        database_root = root / 'orchidapp-standby-db'
        database_root.mkdir(mode=0o700)
        c = {'collection_id': str(uuid.uuid4()), 'databases': ['orchids', 'EnergyMonitoring'],
             'photo_database': 'orchids', 'uploads_source': 'uploads', 'state_root': state_root,
             'backup_root': state_root, 'rclone_config': root / 'unused-crypt.conf', 'remote': 'fixture:read-only',
             'timeout_seconds': 120, 'reserve_bytes': 1024**2, 'max_archive_bytes': 10 * 1024**2,
             'max_unpack_bytes': 20 * 1024**2, 'max_record_bytes': 65536, 'max_listing_bytes': 1024**2,
             'max_ready_records': 100, 'max_age_hours': 30, 'max_generations': 3,
             'server_user': pwd.getpwuid(os.geteuid()).pw_name, 'database_root': database_root,
             'required_server_series': '11.8'}
        recovery = datetime.now(timezone.utc) - timedelta(hours=1)
        def prepared(failing=False):
            captured = recovery + timedelta(minutes=1 if failing else 0)
            snapshot = 'orchidset-' + captured.strftime('%Y%m%dT%H%M%SZ') + '-' + uuid.uuid4().hex
            payload = root / ('input-' + uuid.uuid4().hex)
            (payload / 'databases').mkdir(parents=True)
            (payload / 'sources/uploads/plants/1').mkdir(parents=True)
            (payload / 'sources/uploads/plants/1/photo.jpg').write_bytes(b'synthetic-photo-bytes')
            (payload / 'sources/uploads/plants/1/thumb.jpg').write_bytes(b'synthetic-thumbnail-bytes')
            for database, sql in dumps.items():
                if failing and database == 'EnergyMonitoring':
                    sql += b"\nUSE EnergyMonitoring; CREATE TABLE restore_partial(id INT); SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='intentional fixture failure';\n"
                (payload / 'databases' / (database + '.sql')).write_bytes(sql)
            (payload / 'accounts.sql').write_text('CREATE DATABASE MUST_NOT_BE_IMPORTED;')
            manifest = {'format': s.n.FORMAT, 'collection_id': c['collection_id'], 'snapshot': snapshot,
                        'captured_at': captured.isoformat(), 'databases': c['databases'], 'photo_database': 'orchids',
                        'uploads_source': 'uploads', 'source_paths': {'uploads': '/synthetic/uploads'},
                        'required_photos': ['plants/1/photo.jpg', 'plants/1/thumb.jpg'],
                        'software_identity': 'native-fixture-no-application', 'inventory': s.b.inventory(payload)}
            s.n.atomic_json(payload / 'manifest.json', manifest)
            archive = root / (snapshot + '.tar.gz')
            with tarfile.open(archive, 'w:gz') as tar:
                for child in payload.iterdir():
                    tar.add(child, arcname=child.name)
            record = {'format': s.n.FORMAT, 'collection_id': c['collection_id'], 'snapshot': snapshot,
                      'archive': archive.name, 'sha256': s.b.digest(archive), 'databases': c['databases'],
                      'recovery_point': captured.isoformat(), 'completed_at': captured.isoformat(),
                      'size_bytes': archive.stat().st_size}
            def output(cfg, args, limit):
                return (snapshot + '.ready.json\n').encode() if 'lsf' in args else json.dumps(record).encode()
            def download(cfg, rec, destination):
                shutil.copyfile(archive, destination)
                destination.chmod(0o600)
            with patch.object(s, 'bounded_output', output), patch.object(s, 'download', download):
                result = s.prepare(c)
            return snapshot, Path(result['generation']), record
        snapshot, generation, record = prepared()
        result = d.restore_data(c, snapshot)
        assert result['result'] == 'DATA_RESTORED_APPLICATION_PENDING'
        good = json.loads((generation / 'state.json').read_text())
        configured = d.configure(c)
        with d.running_candidate(configured, good['candidate']) as process:
            d.identity(configured, good['candidate'], process)
            assert d.query(configured, good['candidate'], 'SELECT value FROM orchids.witness;') == ['original orchid']
            assert d.query(configured, good['candidate'], 'SELECT value FROM EnergyMonitoring.witness;') == ['original energy']
            assert d.query(configured, good['candidate'], 'SELECT orchids.fixture_value();') == ['7']
            assert d.query(configured, good['candidate'], 'CALL orchids.fixture_get();') == ['original orchid']
            assert d.query(configured, good['candidate'], 'SELECT value FROM orchids.fixture_view;') == ['original orchid']
            assert 'MUST_NOT_BE_IMPORTED' not in d.query(configured, good['candidate'], 'SHOW DATABASES;')
            assert d.query(configured, good['candidate'], "SELECT COUNT(*) FROM information_schema.TRIGGERS WHERE TRIGGER_SCHEMA='orchids';") == ['1']
            assert d.query(configured, good['candidate'], 'SELECT @@event_scheduler;') == ['OFF']
            # Prove target-only grants on the owned fixture, not a source account.
            try:
                a.provision(configured, good['candidate'], process)
            except s.b.BackupError as ex:
                assert 'unresolved SQL definers' in str(ex)
            else:
                raise AssertionError('Unapproved remote definer was accepted')
            policy_config = dict(configured, view_definer_policy=f.POLICY)
            report = {}
            assert f.columns(configured, good['candidate'], 'vw_EnphaseHourly') == []
            probe_password = a.provision(policy_config, good['candidate'], process, report)
            assert report['timezones']['winter_summer_checks']
            assert report['view_definer_mapping']['definition_and_attributes_preserved']
            assert d.query(configured, good['candidate'], "SELECT JSON_UNQUOTE(JSON_EXTRACT(Priv,'$.account_locked')) FROM mysql.global_priv "
                           "WHERE User='standby_energy_views' AND Host='localhost';") == ['true']
            grants = d.query(configured, good['candidate'], "SHOW GRANTS FOR 'standby_energy_views'@'localhost';")
            assert len(grants) == 2 and any('GRANT SELECT ON `EnergyMonitoring`.*' in row for row in grants)
            assert all('GRANT ALL' not in row for row in grants)
            for view in sorted(f.VIEWS):
                values = d.query(configured, good['candidate'], 'SELECT * FROM EnergyMonitoring.`' + view + '`;')
                if view == 'vw_EnphaseHourly':
                    assert values[0].split('\t')[:2] == ['2026-07-15 12:00:00', '2026-07-15 13:00:00']
                    assert f.columns(configured, good['candidate'], view) == list(f.ENPHASE_COLUMNS)
                else:
                    assert values == ['original energy']
            probe_defaults = generation / 'fixture-probe.cnf'
            d.private_text(probe_defaults, '[client]\nprotocol=socket\nsocket='
                           + d.option(good['candidate']['socket'])
                           + '\nuser=standby_probe\npassword=' + d.option(probe_password) + '\n')
            probe_args = [configured['tools']['mariadb'], '--defaults-file=' + str(probe_defaults),
                          '--protocol=socket', '--batch', '--skip-column-names']
            assert s.b.run(configured, probe_args, stdin=b'CALL orchids.fixture_get();').decode().strip() == 'original orchid'
            refused = subprocess.run(probe_args, input=b'CREATE DATABASE forbidden_probe;', stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            assert refused.returncode != 0
            assert 'forbidden_probe' not in d.query(configured, good['candidate'], 'SHOW DATABASES;')
        with d.running_candidate(configured, good['candidate']) as restarted:
            d.identity(configured, good['candidate'], restarted)
            assert f.timezone_values(configured, good['candidate']) == ['2026-01-15 12:00:00\t2026-07-15 13:00:00']
        assert (generation / 'payload/sources/uploads/plants/1/photo.jpg').read_bytes() == b'synthetic-photo-bytes'
        # Synthetic prior acceptance marker proves preservation, not app acceptance.
        s.n.atomic_json(state_root / 'last-accepted.json', {'record': record, 'synthetic_fixture': True})
        accepted_before = (state_root / 'last-accepted.json').read_bytes()
        bad_snapshot, bad_generation, _ = prepared(failing=True)
        try:
            d.restore_data(c, bad_snapshot)
        except s.b.BackupError:
            pass
        else:
            raise AssertionError('Intentional SQL failure was accepted')
        bad = json.loads((bad_generation / 'state.json').read_text())
        assert bad['phase'] == 'DATABASE_FAILED'
        with d.running_candidate(configured, bad['candidate']):
            assert d.query(configured, bad['candidate'], "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA='EnergyMonitoring' AND TABLE_NAME='restore_partial';") == ['1']
        try:
            d.restore_data(c, bad_snapshot)
        except s.b.BackupError:
            pass
        else:
            raise AssertionError('Partial candidate was retried')
        assert (state_root / 'last-accepted.json').read_bytes() == accepted_before
        assert json.loads((generation / 'state.json').read_text())['phase'] == 'DATA_RESTORED_APPLICATION_PENDING'
        print('PASS: native 10.11.14 -> 11.8 logical restore, both databases, views/routines/triggers/events-off, photos')
        print('PASS: accounts.sql excluded, partial DDL marker retained, retry refused, prior marker preserved')
        print('Private fixture evidence retained:', root)
    finally:
        if created:
            owned()
            docker('rm', '--force', name)


if __name__ == '__main__':
    main()
