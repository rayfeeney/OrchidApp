"""Fixture validation/policy evidence checks; no Docker or database required."""
import hashlib
import io
import json
from pathlib import Path
import tarfile
import tempfile
import unittest
import zipfile
import warnings
from types import SimpleNamespace
from unittest.mock import patch
from preflight import verify_fixture, ledger_review, plan_status, owned
from schema_contract import checksum, identity, require_schema, application_schema
from legacy_adoption import adopt, HISTORY_SQL, ARCHIVE
from package_contract import validate_package
from application_stage import ApplicationStage


TEMP_ROOT = Path(__file__).resolve().parents[2]/'artifacts/historical-upgrade/unit-tests'
if not TEMP_ROOT.resolve().is_relative_to(Path(__file__).resolve().parents[2]):
    raise RuntimeError('Unit fixture directory must stay in the repository workspace')
TEMP_ROOT.mkdir(parents=True, exist_ok=True)


class HistoricalPreflightChecks(unittest.TestCase):
    def test_complete_linux_package_inventory(self):
        stream=io.BytesIO()
        with zipfile.ZipFile(stream,'w') as archive:
            archive.writestr('OrchidApp/app/OrchidApp.Web.dll',b'synthetic package inventory only')
            archive.writestr('OrchidApp/infrastructure/backups/orchid_backup.py',b'not executed')
        with zipfile.ZipFile(stream) as archive:self.assertEqual(validate_package(archive),2)

    def test_linux_package_rejects_unsafe_missing_or_duplicate_members(self):
        for unsafe in ('../escape','OrchidApp/app/../../escape','OrchidApp/.env','/OrchidApp/absolute',
                       'OrchidApp/app/back\\slash','OtherRoot/file','OrchidApp/app//double'):
            with self.subTest(unsafe=unsafe):
                stream=io.BytesIO()
                with zipfile.ZipFile(stream,'w') as archive:archive.writestr(unsafe,b'x')
                with zipfile.ZipFile(stream) as archive:
                    with self.assertRaises(ValueError):validate_package(archive)
        for special in ('duplicate','link','missing'):
            with self.subTest(special=special):
                stream=io.BytesIO()
                with warnings.catch_warnings():
                    warnings.simplefilter('ignore',UserWarning)
                    with zipfile.ZipFile(stream,'w') as archive:
                        item=zipfile.ZipInfo('OrchidApp/app/item')
                        if special=='link':item.external_attr=0o120777<<16
                        archive.writestr(item,b'not executable')
                        if special=='duplicate':archive.writestr(item,b'again')
                with zipfile.ZipFile(stream) as archive:
                    with self.assertRaises(ValueError):validate_package(archive)

    def test_linux_package_resource_limits(self):
        for members in ([SimpleNamespace(file_size=3*1024**3)], [SimpleNamespace(file_size=0)]*15001):
            archive=SimpleNamespace(infolist=lambda:members)
            with self.assertRaisesRegex(ValueError,'resource'):validate_package(archive)

    def test_application_container_rejects_wrong_namespace_exposure_or_identity(self):
        app=ApplicationStage.__new__(ApplicationStage)
        app.container='c'*64;app.database='a'*64;app.token='b'*32
        state={'Id':app.container,'Config':{'Labels':{'org.orchidapp.fixture-token':app.token}},
               'HostConfig':{'NetworkMode':'container:'+app.database,'Binds':None,'PortBindings':{}},'Mounts':[]}
        with patch('application_stage.p.owned'),patch('application_stage.p.docker',return_value=json.dumps([state]).encode()):
            self.assertEqual(app.owned()['Id'],app.container)
        for change in ('namespace','identity','bind','ports','mount','label'):
            bad=json.loads(json.dumps(state))
            if change=='namespace':bad['HostConfig']['NetworkMode']='host'
            elif change=='identity':bad['Id']='d'*64
            elif change=='bind':bad['HostConfig']['Binds']=['/host:/specimen']
            elif change=='ports':bad['HostConfig']['PortBindings']={'5080/tcp':[{}]}
            elif change=='mount':bad['Mounts']=[{'Type':'bind'}]
            else:bad['Config']['Labels']['org.orchidapp.fixture-token']='other'
            with self.subTest(change=change),patch('application_stage.p.owned'),patch('application_stage.p.docker',return_value=json.dumps([bad]).encode()):
                with self.assertRaises(ValueError):app.owned()

    def adoption_fixture(self):
        schema = {'tables': ['plant\tInnoDB'], 'columns': ['plant\t1\tplantId'],
                  'views': ['history\tdefinition\tutf8mb4_unicode_ci'], 'events': []}
        history = '1\t616263\t646566\t2026-06-01 12:00:00\n'
        manifest = {'sha256': 'a'*64, 'historySha256': hashlib.sha256(history.encode()).hexdigest()}
        contract = {'formatVersion': 1, 'scope': 'owned-disposable-fixture-only',
            'fixtureSha256': manifest['sha256'], 'originalHistorySha256': manifest['historySha256'],
            'throughMigration': '202606041820', 'schemaIdentity': identity(schema),
            'schemaSha256': checksum(schema), 'retiredLocalEntry': {'name': 'local-test'}}
        calls = []
        state = {'renamed': False, 'original': history}
        def query(sql):
            calls.append(sql)
            if sql == HISTORY_SQL: return state['original']
            if sql.startswith('SELECT COUNT(*)'): return '0\n'
            if sql.startswith('RENAME TABLE'): state['renamed'] = True; return ''
            if f'FROM orchids.`{ARCHIVE}`' in sql:
                return state['original'] if state['renamed'] else ''
            if sql == 'SELECT scriptName,checksum FROM orchids.schemaversion;':
                return 'baseline:v1:202606041820\t'+checksum(contract)+'\n'
            if sql.startswith(('CREATE TABLE', 'ALTER TABLE', 'INSERT INTO')): return ''
            raise AssertionError('Unexpected query')
        return schema, history, manifest, contract, calls, state, query

    def test_adoption_rejects_unreviewed_schema_before_any_write(self):
        for category in ('tables', 'columns', 'views', 'events', 'unexpected'):
            with self.subTest(category=category):
                schema, _, manifest, contract, calls, _, query = self.adoption_fixture()
                schema.setdefault(category, []).append('unexpected or modified metadata')
                with self.assertRaisesRegex(ValueError, 'schema differs'):
                    adopt(query, schema, contract, manifest, lambda: None)
                self.assertFalse(calls)

    def test_adoption_preserves_original_ledger_with_one_atomic_rename(self):
        schema, history, manifest, contract, calls, state, query = self.adoption_fixture()
        proofs = []
        result = adopt(query, schema, contract, manifest, lambda: proofs.append(True))
        self.assertEqual(state['original'], history)
        self.assertEqual(len(proofs), 3)
        self.assertEqual(len([sql for sql in calls if sql.startswith('RENAME TABLE')]), 1)
        self.assertFalse(any(sql.startswith(('DELETE', 'UPDATE', 'DROP')) for sql in calls))
        self.assertTrue(result['originalLedgerUnchanged'])
        self.assertEqual(result['originalRowsPreserved'], 1)

    def test_adoption_refuses_wrong_history_or_scope_before_writes(self):
        for change in ('history', 'scope', 'fixture'):
            with self.subTest(change=change):
                schema, _, manifest, contract, calls, state, query = self.adoption_fixture()
                if change == 'history': state['original'] += 'unexpected\n'
                elif change == 'scope': contract['scope'] = 'any-database'
                else: manifest['sha256'] = 'b'*64
                with self.assertRaises(ValueError): adopt(query, schema, contract, manifest, lambda: None)
                self.assertFalse(any(sql.startswith(('CREATE', 'ALTER', 'INSERT', 'RENAME')) for sql in calls))

    def test_adoption_refuses_existing_or_partial_rollover(self):
        schema, _, manifest, contract, calls, _, query = self.adoption_fixture()
        def existing(sql):
            if sql.startswith('SELECT COUNT(*)'): return '1\n'
            return query(sql)
        with self.assertRaisesRegex(ValueError, 'Previous/partial'):
            adopt(existing, schema, contract, manifest, lambda: None)
        self.assertFalse(any(sql.startswith(('CREATE', 'ALTER', 'INSERT', 'RENAME')) for sql in calls))

    def test_adoption_ownership_failure_prevents_all_database_access(self):
        schema, _, manifest, contract, calls, _, query = self.adoption_fixture()
        def refuse(): raise RuntimeError('Not owned')
        with self.assertRaisesRegex(RuntimeError, 'Not owned'):
            adopt(query, schema, contract, manifest, refuse)
        self.assertFalse(calls)

    def test_application_schema_keeps_unexpected_security_objects(self):
        schema = {'tables': ['plant\tInnoDB', 'schemaversion\tInnoDB', ARCHIVE+'\tInnoDB'],
            'routines': ['schemaversion\tunexpected definition'], 'events': ['unexpected event']}
        application = application_schema(schema)
        self.assertEqual(application['tables'], ['plant\tInnoDB'])
        self.assertEqual(application['routines'], schema['routines'])
        self.assertEqual(application['events'], schema['events'])

    def test_schema_fingerprint_does_not_ignore_collation_definer_or_index_names(self):
        schema = {'views': ['history\tutf8mb4_unicode_ci\troot@localhost'],
                  'indexes': ['plant\tixPlant\tplantId']}
        expected = identity(schema)
        for category, replacement in [('views', 'history\tutf8mb3_general_ci\troot@localhost'),
                                      ('views', 'history\tutf8mb4_unicode_ci\tother@host'),
                                      ('indexes', 'plant\tunreviewedName\tplantId')]:
            changed = {k: list(v) for k, v in schema.items()}
            changed[category] = [replacement]
            with self.assertRaises(ValueError): require_schema(changed, expected)

    def test_owned_container_rejects_exposure_or_wrong_identity(self):
        state = {'Id': 'a'*64, 'Config': {'Labels': {'org.orchidapp.fixture-token': 'b'*32}},
                 'HostConfig': {'NetworkMode': 'none', 'Binds': None, 'PortBindings': {}},
                 'Mounts': [{'Type': 'volume'}]}
        with patch('preflight.docker', return_value=json.dumps([state]).encode()):
            self.assertEqual(owned('a'*64, 'b'*32)['Id'], 'a'*64)
        for field, value in [('NetworkMode', 'bridge'), ('Binds', ['/host:/data']),
                             ('PortBindings', {'3306/tcp': [{}]}), ('mount', 'bind'), ('identity', 'wrong')]:
            with self.subTest(field=field):
                bad = json.loads(json.dumps(state))
                if field == 'mount':
                    bad['Mounts'][0]['Type'] = value
                elif field == 'identity':
                    bad['Id'] = value
                else:
                    bad['HostConfig'][field] = value
                with patch('preflight.docker', return_value=json.dumps([bad]).encode()):
                    with self.assertRaises(RuntimeError):
                        owned('a'*64, 'b'*32)

    def package(self, root, extra=None, corrupt=False, connection=None):
        settings = {'ConnectionStrings': {'OrchidDb': connection or
            'Server=127.0.0.1;Port=3306;Database=orchids;User=specimen;Password=specimen-only-not-production'},
            'Storage': {'UploadRoot': '/specimen/uploads'}}
        files = {'publish/appsettings.json': json.dumps(settings).encode(),
                 'photo-manifest.json': b'[]', 'orchids.sql': b'Synthetic input; never executed.'}
        inventory = '\n'.join(hashlib.sha256(value).hexdigest()+'  '+name for name, value in files.items())
        files['SHA256SUMS'] = (inventory+'\n').encode()
        if corrupt:
            files['orchids.sql'] += b'changed'
        path = root/'fixture.tar.gz'
        with tarfile.open(path, 'w:gz') as archive:
            for name, value in files.items():
                item = tarfile.TarInfo('specimen/'+name)
                item.size = len(value)
                archive.addfile(item, io.BytesIO(value))
            if extra:
                archive.addfile(extra, io.BytesIO(b'x') if extra.size else None)
        manifest = {'root': 'specimen', 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                    'bytes': path.stat().st_size, 'maxMembers': 20, 'maxUncompressedBytes': 10000}
        stage = root/'stage';stage.mkdir()
        return path, manifest, stage

    def test_valid_fixture_extracts_only_sql(self):
        with tempfile.TemporaryDirectory(dir=TEMP_ROOT) as folder:
            path, manifest, stage = self.package(Path(folder))
            result = verify_fixture(path, manifest, stage)
            self.assertEqual(result['filesVerified'], 4)
            self.assertEqual([p.name for p in stage.iterdir()], ['orchids.sql'])

    def test_wrong_outer_hash_is_refused(self):
        with tempfile.TemporaryDirectory(dir=TEMP_ROOT) as folder:
            path, manifest, stage = self.package(Path(folder))
            manifest['sha256'] = '0'*64
            with self.assertRaisesRegex(ValueError, 'Pinned specimen'):
                verify_fixture(path, manifest, stage)
            self.assertEqual(list(stage.iterdir()), [])

    def test_unsafe_member_paths_are_refused(self):
        for name in ['specimen/../../outside', '/outside', 'specimen/.env', 'C:/outside',
                     'specimen/dir\\outside', 'specimen/.git/config', 'wrong-root/file']:
            with self.subTest(name=name), tempfile.TemporaryDirectory(dir=TEMP_ROOT) as folder:
                extra = tarfile.TarInfo(name);extra.size = 1
                path, manifest, stage = self.package(Path(folder), extra=extra)
                with self.assertRaises(ValueError):
                    verify_fixture(path, manifest, stage)
                self.assertEqual(list(stage.iterdir()), [])

    def test_links_and_duplicate_members_are_refused(self):
        for link in [True, False]:
            with self.subTest(link=link), tempfile.TemporaryDirectory(dir=TEMP_ROOT) as folder:
                extra = tarfile.TarInfo('specimen/orchids.sql')
                if link:
                    extra.type = tarfile.SYMTYPE;extra.linkname = '/etc/passwd'
                else:
                    extra.size = 1
                path, manifest, stage = self.package(Path(folder), extra=extra)
                with self.assertRaises(ValueError):
                    verify_fixture(path, manifest, stage)

    def test_inner_hash_failure_is_refused(self):
        with tempfile.TemporaryDirectory(dir=TEMP_ROOT) as folder:
            path, manifest, stage = self.package(Path(folder), corrupt=True)
            with self.assertRaisesRegex(ValueError, 'member checksum'):
                verify_fixture(path, manifest, stage)
            self.assertEqual(list(stage.iterdir()), [])

    def test_resource_limits_are_enforced(self):
        for key in ['maxMembers', 'maxUncompressedBytes']:
            with self.subTest(key=key), tempfile.TemporaryDirectory(dir=TEMP_ROOT) as folder:
                path, manifest, stage = self.package(Path(folder));manifest[key] = 1
                with self.assertRaisesRegex(ValueError, 'resource limits'):
                    verify_fixture(path, manifest, stage)

    def test_non_specimen_connection_is_refused(self):
        with tempfile.TemporaryDirectory(dir=TEMP_ROOT) as folder:
            path, manifest, stage = self.package(Path(folder), connection='synthetic wrong target')
            with self.assertRaisesRegex(ValueError, 'runtime connection'):
                verify_fixture(path, manifest, stage)

    def test_ledger_line_ending_diagnostic_does_not_rewrite_sql(self):
        with tempfile.TemporaryDirectory(dir=TEMP_ROOT) as folder:
            root = Path(folder);name = '202601010000_Witness.sql';data = b'SELECT 1;\r\n'
            (root/name).write_bytes(data)
            history = {name: hashlib.sha256(b'SELECT 1;\n').hexdigest(),
                       '202601020000_Missing.sql': 'a'*64, '../private': 'b'*64}
            rows = {r['name']: r for r in ledger_review(history, root)}
            self.assertEqual(rows[name]['status'], 'checksum-mismatch')
            self.assertTrue(rows[name]['lfDiagnosticMatches'])
            self.assertEqual(rows['202601020000_Missing.sql']['status'], 'missing')
            self.assertEqual(rows['../private']['status'], 'invalid-name')
            self.assertEqual((root/name).read_bytes(), data)

    def test_policy_refusal_is_not_transport_failure_or_green_upgrade(self):
        self.assertEqual(plan_status(0, 'Migration target'), 'passed')
        self.assertEqual(plan_status(1, '\x1b[31mApplied migration\nchecksum changed: witness.sql\x1b[0m'), 'blocked')
        self.assertEqual(plan_status(1, 'Fixture client could not verify its container'), 'failed')


if __name__ == '__main__':
    unittest.main(verbosity=2)
