"""Disposable archive/service policy checks; optional native MariaDB integration."""
from contextlib import contextmanager
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile
import time
import unittest
from unittest.mock import patch
import uuid

REPO = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('orchid_backup', REPO / 'infrastructure/backups/orchid_backup.py')
b = importlib.util.module_from_spec(spec)
spec.loader.exec_module(b)


class Policy(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='orchid-c17-')
        self.root = Path(self.temp.name)
        self.payload = self.root / 'payload'
        self.payload.mkdir()
        for name in ('uploads', 'configuration', 'uploads/empty', 'uploads/plants', 'uploads/plants/1'):
            (self.payload / name).mkdir()
        (self.payload / 'uploads/plants/1/photo.jpg').write_bytes(b'old photo\x00')
        (self.payload / 'uploads/.hidden').write_bytes(b'hidden')
        (self.payload / 'configuration/app.env').write_text('synthetic settings')
        (self.payload / 'database.sql').write_text('SELECT 1;')
        self.identity = str(uuid.uuid4())
        self.manifest = {'format': 'orchidapp-linux-pair-v1', 'collection_id': self.identity,
                         'snapshot': 'fixture', 'database': 'orchids',
                         'required_photos': ['plants/1/photo.jpg'], 'inventory': b.inventory(self.payload)}
        self.c = {'collection_id': self.identity, 'database': 'orchids', 'backup_root': self.root,
                  'log_file': self.root / 'log', 'keep_local': 1, 'max_unpack_bytes': 1024**2,
                  'timeout_seconds': 5, 'writer_units': ['orchid.service', 'orchid.timer']}

    def tearDown(self):
        self.temp.cleanup()

    def archive(self, name=None, manifest=None):
        (self.payload / 'manifest.json').write_text(json.dumps(manifest or self.manifest))
        dest = self.root / (name or 'selected.tar.gz')
        with tarfile.open(dest, 'w:gz') as t:
            for p in sorted(self.payload.iterdir()):
                t.add(p, arcname=p.name)
        return dest

    def validate(self, archive):
        with tempfile.TemporaryDirectory(dir=self.root) as temp:
            return b.validate_archive(archive, Path(temp), self.c['max_unpack_bytes'])

    def test_pair_roundtrip_hidden_empty_and_settings(self):
        with tempfile.TemporaryDirectory(dir=self.root) as temp:
            b.validate_archive(self.archive(), Path(temp), 1024**2)
            self.assertEqual(b.inventory(Path(temp) / 'uploads'), b.inventory(self.payload / 'uploads'))
            self.assertEqual((Path(temp) / 'configuration/app.env').read_text(), 'synthetic settings')

    def test_old_snapshot_keeps_old_photo_bytes(self):
        archive = self.archive()
        (self.payload / 'uploads/plants/1/photo.jpg').write_bytes(b'new image')
        with tempfile.TemporaryDirectory(dir=self.root) as temp:
            b.validate_archive(archive, Path(temp), 1024**2)
            self.assertEqual((Path(temp) / 'uploads/plants/1/photo.jpg').read_bytes(), b'old photo\x00')

    def test_modified_payload_fails(self):
        (self.payload / 'uploads/plants/1/photo.jpg').write_bytes(b'changed')
        with self.assertRaisesRegex(b.BackupError, 'mismatch'):
            self.validate(self.archive())

    def test_missing_referenced_photo_fails_even_with_matching_inventory(self):
        (self.payload / 'uploads/plants/1/photo.jpg').unlink()
        self.manifest['inventory'] = b.inventory(self.payload)
        with self.assertRaisesRegex(b.BackupError, 'missing'):
            self.validate(self.archive())

    def test_invalid_format_fails(self):
        self.manifest['format'] = 'unknown'
        with self.assertRaisesRegex(b.BackupError, 'Unsupported'):
            self.validate(self.archive())

    def test_archive_size_limit(self):
        self.c['max_unpack_bytes'] = 1
        with self.assertRaisesRegex(b.BackupError, 'limit'):
            self.validate(self.archive())

    def test_unsafe_members_links_and_duplicates(self):
        for name, kind in (('../outside', tarfile.REGTYPE), ('/absolute', tarfile.REGTYPE),
                           ('uploads/link', tarfile.SYMTYPE), ('uploads/hard', tarfile.LNKTYPE),
                           ('uploads/fifo', tarfile.FIFOTYPE), ('uploads/../escape', tarfile.REGTYPE),
                           ('uploads\\escape', tarfile.REGTYPE), ('database.sql', 'duplicate')):
            with self.subTest(name=name):
                archive = self.archive()
                # Rebuild with one bad entry; duplicate uses an already present member name.
                copy = self.root / 'bad.tar.gz'
                with tarfile.open(archive, 'r:gz') as src, tarfile.open(copy, 'w:gz') as out:
                    for m in src.getmembers():
                        out.addfile(m, src.extractfile(m) if m.isfile() else None)
                    m = tarfile.TarInfo(name)
                    m.type = tarfile.REGTYPE if kind == 'duplicate' else kind
                    out.addfile(m, io.BytesIO(b'') if m.isfile() else None)
                with self.assertRaises((b.BackupError, FileExistsError)):
                    self.validate(copy)
                self.assertFalse((self.root / 'outside').exists())

    def test_incomplete_archive(self):
        (self.payload / 'database.sql').unlink()
        with self.assertRaisesRegex(b.BackupError, 'Incomplete'):
            self.validate(self.archive())

    def test_empty_dump_fails(self):
        (self.payload / 'database.sql').write_bytes(b'')
        self.manifest['inventory'] = b.inventory(self.payload)
        with self.assertRaisesRegex(b.BackupError, 'Empty'):
            self.validate(self.archive())

    def test_source_symlink_rejected(self):
        try:
            (self.payload / 'uploads/link').symlink_to(self.payload / 'database.sql')
        except OSError:
            self.skipTest('Creating symlinks requires OS permission')
        with self.assertRaisesRegex(b.BackupError, 'symlink'):
            b.inventory(self.payload)

    def test_operation_lock_and_stale_lock(self):
        with b.operation_lock(self.root):
            with self.assertRaisesRegex(b.BackupError, 'stale lock'):
                with b.operation_lock(self.root):
                    pass
        self.assertFalse((self.root / '.paired-operation.lock').exists())

    def test_retention_preserves_unknown_foreign_pinned_and_corrupt(self):
        def name(n):
            return 'orchidpair-20000101T00000' + str(n) + 'Z-' + uuid.uuid4().hex + '.tar.gz'
        old = self.archive(name(1))
        pin = self.archive(name(2)); Path(str(pin) + '.keep').write_text('retain')
        foreign_manifest = dict(self.manifest, collection_id=str(uuid.uuid4()))
        foreign = self.archive(name(3), foreign_manifest)
        corrupt = self.root / name(4); corrupt.write_bytes(b'not an archive')
        unknown = self.archive('old.sql.tar.gz')
        current = self.archive(name(5))
        b.prune_local(self.c, current)
        self.assertFalse(old.exists())
        self.assertTrue(all(p.exists() for p in (pin, foreign, corrupt, unknown, current)))

    def test_writer_states_must_be_stable_loaded_and_stopped(self):
        for load, active, sub in (('not-found','inactive','dead'), ('loaded','active','running'),
                                  ('loaded','activating','start'), ('loaded','inactive','waiting')):
            with self.subTest(active=active), patch.object(b, 'run', return_value=(
                    f'LoadState={load}\nActiveState={active}\nSubState={sub}\n').encode()):
                with self.assertRaises(b.BackupError):
                    b.writers_stopped(self.c)

    def test_scheduled_stop_order_and_restart_on_capture_failure(self):
        calls = []
        def command(c, args, **kwargs):
            calls.append(args)
            return b'LoadState=loaded\nActiveState=active\n'
        with patch.object(b, 'run', side_effect=command), patch.object(b, 'writers_stopped'):
            with self.assertRaisesRegex(RuntimeError, 'capture failure'):
                with b.stop_writers(self.c):
                    raise RuntimeError('capture failure')
        actions = [a[1:] for a in calls if a[1] in ('stop', 'start')]
        self.assertEqual(actions, [['stop','orchid.timer'], ['stop','orchid.service'],
                                   ['start','orchid.service'], ['start','orchid.timer']])

    def test_scheduled_inactive_units_stay_inactive(self):
        with patch.object(b, 'run', return_value=b'LoadState=loaded\nActiveState=inactive\n') as run, \
                patch.object(b, 'writers_stopped'):
            with b.stop_writers(self.c):
                pass
        self.assertTrue(all(a.args[1][1] == 'show' for a in run.call_args_list))

    def test_restart_failure_is_visible(self):
        def command(c, args, **kwargs):
            if args[1] == 'start':
                raise b.BackupError('failed')
            return b'LoadState=loaded\nActiveState=active\n'
        with patch.object(b, 'run', side_effect=command), patch.object(b, 'writers_stopped'):
            with self.assertRaisesRegex(b.BackupError, 'restart failed'):
                with b.stop_writers(self.c):
                    pass

    def test_explicit_backup_acknowledgement(self):
        with self.assertRaisesRegex(b.BackupError, 'writers stopped'):
            b.backup(self.c, False)

    def test_explicit_restore_confirmation(self):
        with self.assertRaisesRegex(b.BackupError, 'confirm-isolated'):
            b.restore(self.c, self.archive(), self.root/'recovery', False, 'orchids')

    def test_restore_rejects_nonempty_database_without_mutation(self):
        with patch.object(b, 'writers_stopped'), patch.object(b, 'query', return_value=['1']):
            with self.assertRaisesRegex(b.BackupError, 'empty database'):
                b.restore(self.c, self.archive(), self.root.parent / (self.root.name+'-recovery'), True, 'orchids')

    def test_restore_wrong_collection_rejected(self):
        self.c['collection_id'] = str(uuid.uuid4())
        with patch.object(b, 'writers_stopped'):
            with self.assertRaisesRegex(b.BackupError, 'collection'):
                b.restore(self.c, self.archive(), self.root.parent / (self.root.name+'-recovery'), True, 'orchids')

    def test_tool_failure_does_not_echo_private_stderr(self):
        with patch.object(b.subprocess, 'run', return_value=subprocess.CompletedProcess([], 1, b'', b'secret password')):
            with self.assertRaisesRegex(b.BackupError, 'Tool failed: example; exit=1') as error:
                b.run(self.c, ['example'])
        self.assertNotIn('secret', str(error.exception))

    def config_file(self, **changes):
        for name in ('client.cnf', 'rclone.conf'):
            p = self.root/name; p.write_text('synthetic only'); p.chmod(0o600)
        cfg = dict(self.c, client_defaults_file=str(self.root/'client.cnf'),
                   rclone_config=str(self.root/'rclone.conf'), remote='fixture:paired',
                   backup_root=str(self.root/'backups'), log_file=str(self.root/'logs/backup.log'),
                   uploads_root=str(self.payload/'uploads'), configuration_root=str(self.payload/'configuration'))
        cfg.update(changes)
        cfg = {k: str(v) if isinstance(v, Path) else v for k,v in cfg.items()}
        path = self.root/'backup.json'; path.write_text(json.dumps(cfg)); path.chmod(0o600)
        return path

    def test_portable_explicit_config_creates_log_before_use(self):
        cfg = b.load_config(str(self.config_file()), 'backup')
        self.assertTrue(cfg['backup_root'].is_dir())
        self.assertTrue(cfg['log_file'].is_file())
        self.assertEqual(cfg['rclone_config'], self.root/'rclone.conf')

    def test_invalid_counts_paths_identity_and_remotes(self):
        for key, value in (('keep_local',0), ('keep_local',-1), ('keep_local',True),
                           ('timeout_seconds',0), ('max_unpack_bytes',0), ('database','bad;sql'),
                           ('uploads_root','relative'), ('collection_id','REPLACE'),
                           ('remote','fixture:'), ('remote','fixture:../other'),
                           ('writer_units',[]), ('writer_units',['--bad'])):
            with self.subTest(key=key,value=value):
                with self.assertRaises((b.BackupError, ValueError)):
                    b.load_config(str(self.config_file(**{key:value})), 'backup')

    def test_overlapping_source_backup_paths_rejected(self):
        with self.assertRaisesRegex(b.BackupError, 'overlap'):
            b.load_config(str(self.config_file(backup_root=str(self.payload/'uploads/backups'))), 'backup')

    @unittest.skipUnless(os.name == 'posix', 'POSIX permission check requires Linux')
    def test_public_config_rejected(self):
        path = self.config_file(); path.chmod(0o644)
        with self.assertRaisesRegex(b.BackupError, 'mode 600'):
            b.load_config(str(path), 'backup')

    @contextmanager
    def capture_fixture(self, mutate=False, remote_failure=False, remote_corrupt=False):
        c = b.load_config(str(self.config_file()), 'backup')
        @contextmanager
        def locked(cfg):
            yield lambda: None
        def command(cfg, args, **kwargs):
            if args[0] == 'mariadb-dump':
                kwargs['stdout'].write(b'SELECT 1;')
                if mutate:
                    (c['uploads_root']/'plants/1/photo.jpg').write_bytes(b'concurrent write')
            return b''
        def cloud(cfg, *args):
            if remote_failure:
                raise b.BackupError('Intentional remote failure')
            if args[0] == 'copyto' and args[1].startswith('fixture:'):
                target = Path(args[2])
                if remote_corrupt:
                    target.write_bytes(b'bad remote bytes')
                else:
                    archive = c['backup_root']/args[1].split('/')[-1]
                    shutil.copyfile(archive, target)
            return b''
        with patch.object(b, 'writers_stopped'), patch.object(b, 'remote_preflight'), \
                patch.object(b, 'database_read_lock', side_effect=locked), \
                patch.object(b, 'photo_paths', return_value=['plants/1/photo.jpg']), \
                patch.object(b, 'run', side_effect=command), patch.object(b, 'rclone', side_effect=cloud):
            yield c

    def test_file_mutation_during_capture_fails_without_archive(self):
        with self.capture_fixture(mutate=True) as c:
            with self.assertRaisesRegex(b.BackupError, 'Source changed'):
                b.backup(c, True)
            self.assertFalse(list(c['backup_root'].glob('*.tar.gz')))

    def test_failed_upload_and_bad_readback_keep_local_without_pruning(self):
        for failure, corrupt in ((True,False), (False,True)):
            with self.subTest(failure=failure,corrupt=corrupt), \
                    self.capture_fixture(remote_failure=failure,remote_corrupt=corrupt) as c, \
                    patch.object(b, 'prune_local') as prune:
                with self.assertRaises(b.BackupError):
                    b.backup(c, True)
                self.assertTrue(list(c['backup_root'].glob('*.tar.gz')))
                prune.assert_not_called()

    def test_retention_only_after_verified_readback(self):
        with self.capture_fixture() as c, patch.object(b, 'prune_local') as prune:
            archive = b.backup(c, True)
            prune.assert_called_once_with(c, archive)

    def test_remote_and_explicit_config_required_before_capture(self):
        c = dict(self.c, remote='fixture:paired', rclone_config=self.root/'rclone.conf')
        with patch.object(b, 'rclone', return_value=b'other:\n'):
            with self.assertRaisesRegex(b.BackupError, 'absent'):
                b.remote_preflight(c)

    @unittest.skipUnless(shutil.which('rclone'), 'Actual crypt backend check requires rclone')
    def test_actual_rclone_crypt_readback(self):
        storage = self.root/'encrypted-store'; storage.mkdir()
        config = self.root/'crypt.conf'
        key = subprocess.check_output(['rclone','obscure','synthetic-c17-fixture-key']).decode().strip()
        config.write_text('[fixturecrypt]\ntype = crypt\nremote = '+storage.as_posix()+'\npassword = '+key+'\n')
        config.chmod(0o600)
        c = dict(self.c, rclone_config=config, remote='fixturecrypt:paired')
        b.rclone(c, 'mkdir', c['remote'])
        b.remote_preflight(c)
        archive = self.archive()
        remote = c['remote']+'/snapshot.tar.gz'
        b.rclone(c, 'copyto', str(archive), remote, '--immutable')
        downloaded = self.root/'downloaded.tar.gz'
        b.rclone(c, 'copyto', remote, str(downloaded))
        self.assertEqual(b.digest(archive), b.digest(downloaded))
        self.assertFalse(any(p.name == 'snapshot.tar.gz' for p in storage.rglob('*')))


@unittest.skipUnless(os.environ.get('C17_TEST_DEFAULTS'), 'Native integration not requested')
class Database(unittest.TestCase):
    def test_native_roundtrip_old_pair_read_lock_and_failed_ddl(self):
        database = os.environ['C17_TEST_DATABASE']
        b.require(__import__('re').fullmatch(r'orchids_c17_[0-9a-f]{32}', database), 'Generated database required')
        with tempfile.TemporaryDirectory(prefix='orchid-c17-native-') as temp:
            root = Path(temp)
            for directory in ('uploads', 'configuration', 'backups', 'remote'):
                (root / directory).mkdir(mode=0o700)
            c = {'collection_id': str(uuid.uuid4()), 'database': database,
                 'client_defaults_file': Path(os.environ['C17_TEST_DEFAULTS']),
                 'uploads_root': root/'uploads', 'configuration_root': root/'configuration',
                 'backup_root': root/'backups', 'log_file': root/'log', 'writer_units': ['fixture.service'],
                 'rclone_config': root/'rclone.conf', 'remote': 'fixture:paired',
                 'keep_local': 14, 'timeout_seconds': 30, 'max_unpack_bytes': 1024**3}
            # Database.Checks.ps1 creates the canonical schema/seeds through the production creator.
            b.query(c, "CALL spAddGenus('Linux backup fixture','fixture'); SET @taxon=(SELECT MIN(taxonId) FROM taxon); "
                    "CALL spAddPlant(@taxon,NOW(),'fixture','Linux plant','Old snapshot café'); "
                    "INSERT INTO plantevent(plantId,eventDateTime,eventDetails,observationTypeId) "
                    "SELECT MIN(plantId),NOW(),'Photo',(SELECT Id FROM observationtype WHERE typeCode='OBS_PHOTO') FROM plant; "
                    "INSERT INTO plantphoto(plantEventId,plantId,fileName,thumbnailFileName,mimeType) "
                    "SELECT MIN(plantEventId),MIN(plantId),'photo.jpg','thumb.jpg','image/jpeg' FROM plantevent; "
                    "INSERT INTO taxonphoto(taxonId,fileName,thumbnailFileName,mimeType) "
                    "SELECT MIN(taxonId),'taxon.jpg','taxon-thumb.jpg','image/jpeg' FROM taxon;")
            for name in b.photo_paths(c):
                p = c['uploads_root'] / name; p.parent.mkdir(parents=True, exist_ok=True); p.write_bytes(b'old photo '+name.encode())
            (c['uploads_root']/'.hidden').write_bytes(b'hidden upload')
            (c['configuration_root']/'app.env').write_text('synthetic configuration')
            original = b.inventory(c['uploads_root'])
            calls = []
            def remote(cfg, *args):
                calls.append(args)
                if args[0] == 'copyto':
                    source, dest = args[1:3]
                    source = root/'remote'/source.split('/')[-1] if source.startswith('fixture:') else Path(source)
                    dest = root/'remote'/dest.split('/')[-1] if dest.startswith('fixture:') else Path(dest)
                    shutil.copyfile(source, dest)
                return b''
            with patch.object(b, 'writers_stopped'), patch.object(b, 'remote_preflight'), patch.object(b, 'rclone', side_effect=remote):
                try:
                    archive = b.backup(c, True)
                except b.BackupError as error:
                    # This server/database and all contents were generated by this test.
                    diagnostics = '\n'.join(p.read_text(errors='replace') for p in c['backup_root'].glob('.tool-error-*.log'))
                    raise AssertionError('Generated-fixture diagnostic: ' + diagnostics) from error
                self.assertEqual(b.digest(archive), b.digest(root/'remote'/archive.name))
                # A concurrent SQL writer must remain blocked while the capture lock is held.
                with b.database_read_lock(c):
                    writer = subprocess.Popen(b.client(c)+[database], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                    writer.stdin.write(b"UPDATE plant SET plantNotes='New current snapshot';\n"); writer.stdin.close()
                    time.sleep(0.5)
                    self.assertIsNone(writer.poll(), 'Concurrent SQL write escaped the read lock')
                writer.wait(timeout=10); self.assertEqual(writer.returncode, 0)
                writer.stdout.close(); writer.stderr.close()
                for name in b.photo_paths(c):
                    (c['uploads_root']/name).write_bytes(b'new current photo')
                # Reset only the explicitly generated fixture database, then restore the OLD pair.
                b.run(c, b.client(c), stdin=f'DROP DATABASE `{database}`; CREATE DATABASE `{database}` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;'.encode())
                recovery = root/'recovery'
                b.restore(c, archive, recovery, True, database)
                self.assertEqual(b.query(c, 'SELECT plantNotes FROM plant;'), ['Old snapshot café'])
                self.assertEqual(b.inventory(recovery/'uploads'), original)
                self.assertEqual((recovery/'configuration/app.env').read_text(), 'synthetic configuration')
                self.assertTrue((recovery/'RESTORED-VERIFY-APPLICATION.json').exists())
                self.assertTrue(Path(str(archive)+'.keep').exists())
                # Missing active photo fails before producing any new completed archive.
                missing = c['uploads_root']/b.photo_paths(c)[0]; missing.unlink()
                count = len(list(c['backup_root'].glob('*.tar.gz')))
                with self.assertRaisesRegex(b.BackupError, 'missing'):
                    b.backup(c, True)
                self.assertEqual(len(list(c['backup_root'].glob('*.tar.gz'))), count)
                # A rehashed fixture intentionally fails after DDL; no rollback claim or success marker.
                bad_payload = root/'bad-payload'; bad_payload.mkdir()
                m = b.validate_archive(archive, bad_payload, 1024**3)
                (bad_payload/'database.sql').write_text("CREATE TABLE partial_fixture(id INT); SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Intentional fixture failure';")
                (bad_payload/'manifest.json').unlink(); m['inventory'] = b.inventory(bad_payload)
                (bad_payload/'manifest.json').write_text(json.dumps(m))
                bad_archive = root/'intentional-failure.tar.gz'
                with tarfile.open(bad_archive, 'w:gz') as t:
                    for p in bad_payload.iterdir(): t.add(p, arcname=p.name)
                b.run(c, b.client(c), stdin=f'DROP DATABASE `{database}`; CREATE DATABASE `{database}`;'.encode())
                with self.assertRaisesRegex(b.BackupError, 'SQL may be partially applied'):
                    b.restore(c, bad_archive, root/'failed-recovery', True, database)
                self.assertEqual(b.query(c, 'SHOW TABLES;'), ['partial_fixture'])
                self.assertTrue((root/'failed-recovery/RESTORE-PENDING.json').exists())
                self.assertTrue(bad_archive.exists())


if __name__ == '__main__':
    os.umask(0o077)
    unittest.main(verbosity=2)
