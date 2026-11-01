"""C15/C19 native HTTP uploads, durable recovery and health on owned fixture DBs."""
from checks import sql, DEFAULTS, DATABASE
from contextlib import contextmanager
from pathlib import Path
import hashlib,html,http.cookiejar,json,os,re,shutil,socket,subprocess,time,unittest,urllib.error,urllib.parse,urllib.request,uuid,zipfile


class Photos(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.base=os.environ['C11_TEST_WEB_URL'];cls.root=Path(os.environ['Storage__UploadRoot'])
        cls.repo=Path(__file__).resolve().parents[2]
        cls.image=(cls.repo/'tests/DevelopmentNative.Checks/fixtures/orientation-6.jpg').read_bytes()
        sql("CALL spAddGenus('C19 fixture','Synthetic');")
        cls.genus=int(sql("SELECT genusId FROM genus WHERE genusName='C19 fixture';")[0])

    def setUp(self):
        self.name='c19_'+uuid.uuid4().hex[:12]
        sql(f"CALL spAddTaxon({self.genus},'{self.name}',NULL,NULL,NULL);")
        self.t=int(sql('SELECT MAX(taxonId) FROM taxon;')[0])
        sql(f"CALL spAddPlant({self.t},'2020-01-01','fixture','C19 plant','fixture');")
        self.p=int(sql('SELECT MAX(plantId) FROM plant;')[0])
        self.opener=urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
        page=self.opener.open(self.base+f'/Plants/Edit/{self.p}').read().decode()
        self.token=html.unescape(re.search(r'name="__RequestVerificationToken"[^>]*value="([^"]+)"',page).group(1))

    def tearDown(self):sql('DROP TRIGGER IF EXISTS c19_failure;')

    def snapshot(self):
        rows=[]
        for table,key in [('plant','plantId'),('plantevent','plantId'),('plantphoto','plantId'),('taxon','taxonId'),('taxonphoto','taxonId')]:
            rows+=sql(f'SELECT * FROM {table} WHERE {key}={self.p if key=="plantId" else self.t} ORDER BY 1;')
        files={}
        for folder in [self.root/'plants'/str(self.p),self.root/'taxa'/str(self.t),self.root/'.photo-recovery']:
            if folder.is_dir():files.update({str(p.relative_to(self.root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in folder.rglob('*') if p.is_file()})
        return rows,files

    def post(self,path,fields=None,files=None):
        boundary='C19'+uuid.uuid4().hex;parts=[]
        for key,value in {'__RequestVerificationToken':self.token,**(fields or {})}.items():
            parts.append(f'--{boundary}\r\nContent-Disposition: form-data; name="{key}"\r\n\r\n{value}\r\n'.encode())
        for key,name,data in files or []:
            parts.append(f'--{boundary}\r\nContent-Disposition: form-data; name="{key}"; filename="{name}"\r\nContent-Type: image/jpeg\r\n\r\n'.encode()+data+b'\r\n')
        parts.append(f'--{boundary}--\r\n'.encode())
        request=urllib.request.Request(self.base+path,b''.join(parts),{'Content-Type':'multipart/form-data; boundary='+boundary})
        try:
            with self.opener.open(request,timeout=30) as r:return r.status,r.read().decode()
        except urllib.error.HTTPError as e:return e.code,e.read().decode()

    def ready(self,base=None):
        try:
            with urllib.request.urlopen((base or self.base)+'/health/ready',timeout=20) as r:return r.status,json.load(r)
        except urllib.error.HTTPError as e:return e.code,json.load(e)

    def upload(self,count=1):
        result=self.post(f'/Plants/Photos/{self.p}?handler=Upload',files=[('UploadFiles',f'{i}.jpg',self.image) for i in range(count)])
        self.assertEqual(result[0],200);return result

    def test_multi_photo_save_reopens_both_images_and_is_ready(self):
        self.upload(2)
        rows=sql(f'SELECT fileName,thumbnailFileName FROM plantphoto WHERE plantId={self.p};')
        self.assertEqual(len(rows),2)
        for row in rows:
            for name in row.split('\t'):
                with urllib.request.urlopen(self.base+f'/uploads/plants/{self.p}/{name}') as r:
                    self.assertEqual(r.status,200);self.assertTrue(r.read().startswith(b'\xff\xd8'))
        self.assertEqual(sql(f'SELECT COUNT(*) FROM plantevent WHERE plantId={self.p};'),['1'])
        self.assertEqual(sql(f'SELECT COUNT(*) FROM plantphoto WHERE plantId={self.p} AND isHero=1;'),['1'])
        self.assertEqual(self.ready()[0],200)

    def photo_rows(self):
        return [row.split('\t') for row in sql(f'SELECT plantPhotoId,fileName,thumbnailFileName FROM plantphoto WHERE plantId={self.p} ORDER BY isHero DESC,plantPhotoId;')]

    def test_delete_confirmation_cancel_and_antiforgery(self):
        self.upload();photo=self.photo_rows()[0];before=self.snapshot()
        page=self.opener.open(self.base+f'/Plants/Photos/{self.p}').read().decode()
        self.assertIn('Permanently delete this photo',page);self.assertIn('Cancel',page)
        self.assertEqual(self.snapshot(),before) # Opening confirmation is read-only.
        self.assertEqual(self.post(f'/Plants/Photos/{self.p}?handler=Delete',{'photoId':photo[0]})[0],200)
        self.assertEqual(self.snapshot(),before)
        request=urllib.request.Request(self.base+f'/Plants/Photos/{self.p}?handler=Delete',urllib.parse.urlencode({'photoId':photo[0],'confirmDelete':'true'}).encode())
        with self.assertRaises(urllib.error.HTTPError) as error:self.opener.open(request)
        self.assertEqual(error.exception.code,400);self.assertEqual(self.snapshot(),before)

    def test_delete_hero_then_last_photo_preserves_observation(self):
        self.upload(2);rows=self.photo_rows();folder=self.root/'plants'/str(self.p)
        self.assertEqual(self.post(f'/Plants/Photos/{self.p}?handler=Delete',{'photoId':rows[0][0],'confirmDelete':'true'})[0],200)
        self.assertEqual(sql(f'SELECT plantPhotoId FROM plantphoto WHERE plantId={self.p} AND isHero=1;'),[rows[1][0]])
        for name in rows[0][1:]:self.assertFalse((folder/name).exists())
        for name in rows[1][1:]:self.assertTrue((folder/name).exists())
        self.assertEqual(self.post(f'/Plants/Photos/{self.p}?handler=Delete',{'photoId':rows[1][0],'confirmDelete':'true'})[0],200)
        self.assertEqual(self.photo_rows(),[])
        self.assertEqual(sql(f'SELECT COUNT(*) FROM plantevent WHERE plantId={self.p};'),['1'])
        self.assertEqual(self.ready()[0],200)

    def test_delete_missing_files(self):
        self.upload();row=self.photo_rows()[0]
        for name in row[1:]:(self.root/'plants'/str(self.p)/name).unlink()
        status,text=self.post(f'/Plants/Photos/{self.p}?handler=Delete',{'photoId':row[0],'confirmDelete':'true'})
        self.assertEqual(status,200);self.assertIn('Photo deleted.',text);self.assertEqual(self.photo_rows(),[])

    def test_delete_wrong_plant_and_route_override(self):
        self.upload();row=self.photo_rows()[0];before=self.snapshot()
        self.assertEqual(self.post(f'/Plants/Photos/{self.p}?handler=Delete',{'photoId':int(row[0])+100000,'confirmDelete':'true'})[0],404)
        self.assertEqual(self.post(f'/Plants/Photos/{self.p}?handler=Delete',{'plantId':self.p+1,'photoId':row[0],'confirmDelete':'true'})[0],400)
        self.assertEqual(self.snapshot(),before)

    def test_delete_other_plant_photo_rejected(self):
        self.upload();row=self.photo_rows()[0]
        sql(f"CALL spAddPlant({self.t},'2020-01-01','fixture','other plant','fixture');")
        other=int(sql('SELECT MAX(plantId) FROM plant;')[0]);before=self.snapshot()
        self.assertEqual(self.post(f'/Plants/Photos/{other}?handler=Delete',{'photoId':row[0],'confirmDelete':'true'})[0],404)
        self.assertEqual(self.snapshot(),before)

    def test_delete_shared_and_unsafe_filenames_rejected(self):
        self.upload(2);rows=self.photo_rows()
        sql(f"UPDATE plantphoto SET thumbnailFileName='{rows[0][1]}' WHERE plantPhotoId={rows[1][0]};")
        before=self.snapshot()
        status,text=self.post(f'/Plants/Photos/{self.p}?handler=Delete',{'photoId':rows[0][0],'confirmDelete':'true'})
        self.assertEqual(status,200);self.assertIn('could not be deleted',text);self.assertEqual(self.snapshot(),before)
        sql(f"UPDATE plantphoto SET thumbnailFileName='{rows[1][2]}' WHERE plantPhotoId={rows[1][0]};")
        sql(f"UPDATE plantphoto SET fileName='../outside.jpg' WHERE plantPhotoId={rows[0][0]};")
        before=self.snapshot()
        status,text=self.post(f'/Plants/Photos/{self.p}?handler=Delete',{'photoId':rows[0][0],'confirmDelete':'true'})
        self.assertEqual(status,200);self.assertIn('could not be deleted',text);self.assertEqual(self.snapshot(),before)
        sql(f"UPDATE plantphoto SET fileName='{rows[0][1]}' WHERE plantPhotoId={rows[0][0]};")

    def test_delete_database_failure_retains_metadata_and_files(self):
        self.upload();row=self.photo_rows()[0];before=self.snapshot()
        sql("CREATE TRIGGER c19_failure BEFORE DELETE ON plantphoto FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='injected deletion failure';")
        status,text=self.post(f'/Plants/Photos/{self.p}?handler=Delete',{'photoId':row[0],'confirmDelete':'true'})
        self.assertEqual(status,200);self.assertIn('could not be deleted',text);self.assertEqual(self.snapshot(),before)

    def test_delete_ended_plant_rejected(self):
        self.upload();row=self.photo_rows()[0]
        sql(f"UPDATE plant SET endDate='2025-01-01' WHERE plantId={self.p};")
        before=self.snapshot()
        self.assertEqual(self.post(f'/Plants/Photos/{self.p}?handler=Delete',{'photoId':row[0],'confirmDelete':'true'})[0],400)
        self.assertEqual(self.snapshot(),before)

    def test_second_photo_failure_rolls_back_entire_batch(self):
        before=self.snapshot()
        status,text=self.post(f'/Plants/Photos/{self.p}?handler=Upload',files=[('UploadFiles','valid.jpg',self.image),('UploadFiles','bad.jpg',b'not an image')])
        self.assertEqual(status,200);self.assertIn('could not be processed',text)
        self.assertEqual(self.snapshot(),before)

    def test_observation_photo_failure_preserves_existing_upload(self):
        self.upload();before=self.snapshot()
        status,text=self.post(f'/Plants/Events/Add/{self.p}/Observation',{'EventDate':'2020-06-01'},[('UploadedFiles','valid.jpg',self.image),('UploadedFiles','bad.jpg',b'invalid')])
        self.assertEqual(status,200);self.assertIn('could not be processed',text)
        self.assertEqual(self.snapshot(),before)

    def test_observation_photo_save_commits_pair(self):
        self.assertEqual(self.post(f'/Plants/Events/Add/{self.p}/Observation',{'EventDate':'2020-06-01'},[('UploadedFiles','valid.jpg',self.image)])[0],200)
        self.assertEqual(sql(f'SELECT COUNT(*) FROM plantphoto WHERE plantId={self.p};'),['1'])
        self.assertEqual(self.ready()[0],200)

    def test_metadata_insert_failure_removes_new_files_and_observation(self):
        self.upload();before=self.snapshot()
        sql("CREATE TRIGGER c19_failure BEFORE INSERT ON plantphoto FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='C19 injected metadata failure';")
        self.post(f'/Plants/Photos/{self.p}?handler=Upload',files=[('UploadFiles','valid.jpg',self.image)])
        self.assertEqual(self.snapshot(),before)

    def test_taxon_add_invalid_photo_does_not_leave_duplicate_taxon(self):
        name='invalid_'+uuid.uuid4().hex[:12]
        self.assertEqual(self.post('/Setup/Taxa/Actions/Add',{'GenusId':self.genus,'SpeciesName':name},[('Photo','invalid.jpg',b'invalid')])[0],200)
        self.assertEqual(sql(f"SELECT COUNT(*) FROM taxon WHERE genusId={self.genus} AND speciesName='{name}';"),['0'])

    def test_taxon_add_valid_photo_saves_details_and_pair(self):
        name='valid_'+uuid.uuid4().hex[:12]
        self.assertEqual(self.post('/Setup/Taxa/Actions/Add',{'GenusId':self.genus,'SpeciesName':name},[('Photo','valid.jpg',self.image)])[0],200)
        self.assertEqual(sql(f"SELECT COUNT(*) FROM taxon t JOIN taxonphoto p ON t.taxonId=p.taxonId WHERE t.genusId={self.genus} AND t.speciesName='{name}' AND p.isPrimary=1 AND p.isActive=1;"),['1'])
        self.assertEqual(self.ready()[0],200)

    def taxon_photo(self):
        self.assertEqual(self.post(f'/Setup/Taxa/Actions/Edit/{self.t}',{'Taxon.SpeciesName':self.name,'Taxon.TaxonNotes':'before'},[('Photo','valid.jpg',self.image)])[0],200)
        self.assertEqual(sql(f'SELECT COUNT(*) FROM taxonphoto WHERE taxonId={self.t} AND isActive=1;'),['1'])

    def test_taxon_edit_failed_photo_rolls_back_details_and_retains_previous_photo(self):
        self.taxon_photo();before=self.snapshot()
        self.assertEqual(self.post(f'/Setup/Taxa/Actions/Edit/{self.t}',{'Taxon.SpeciesName':self.name,'Taxon.TaxonNotes':'after'},[('Photo','invalid.jpg',b'invalid')])[0],200)
        self.assertEqual(self.snapshot(),before)

    def test_taxon_replacement_metadata_failure_rolls_back_old_photo_flags(self):
        self.taxon_photo();before=self.snapshot()
        sql("CREATE TRIGGER c19_failure BEFORE INSERT ON taxonphoto FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='C19 injected taxon photo failure';")
        self.post(f'/Setup/Taxa/Actions/Edit/{self.t}',{'Taxon.SpeciesName':self.name,'Taxon.TaxonNotes':'after'},[('Photo','valid.jpg',self.image)])
        self.assertEqual(self.snapshot(),before)

    def test_taxon_replacement_keeps_previous_files_and_one_active_photo(self):
        self.taxon_photo();old_files=self.snapshot()[1]
        self.taxon_photo()
        self.assertEqual(sql(f'SELECT COUNT(*) FROM taxonphoto WHERE taxonId={self.t};'),['2'])
        self.assertEqual(sql(f'SELECT COUNT(*) FROM taxonphoto WHERE taxonId={self.t} AND isActive=1 AND isPrimary=1;'),['1'])
        for name,digest in old_files.items():self.assertEqual(hashlib.sha256((self.root/name).read_bytes()).hexdigest(),digest)
        self.assertEqual(self.ready()[0],200)

    def test_taxon_procedure_preserves_caller_transaction(self):
        before=self.snapshot()
        result=sql(f"START TRANSACTION; CALL spUpdateTaxonDetails({self.t},'{self.name}',NULL,NULL,NULL,'caller'); SELECT @@in_transaction; ROLLBACK;")
        self.assertEqual(result[-1],'1');self.assertEqual(self.snapshot(),before)
        result=sql(f"START TRANSACTION; CALL spUpdateTaxonDetails({self.t},NULL,NULL,NULL,NULL,'invalid'); SELECT @@in_transaction; ROLLBACK;",error='Taxon must have',force=True)
        self.assertEqual(result[-1],'1');self.assertEqual(self.snapshot(),before)

    def test_unwritable_entity_directory_rolls_back_without_deleting_blocker(self):
        folder=self.root/'plants'/str(self.p);folder.parent.mkdir(exist_ok=True);folder.write_bytes(b'owned blocker')
        before=self.snapshot()
        try:
            self.post(f'/Plants/Photos/{self.p}?handler=Upload',files=[('UploadFiles','valid.jpg',self.image)])
            self.assertEqual(self.snapshot(),before);self.assertEqual(folder.read_bytes(),b'owned blocker')
        finally:folder.unlink()

    def test_missing_thumbnail_is_unready_until_restored(self):
        self.upload();name=sql(f'SELECT thumbnailFileName FROM plantphoto WHERE plantId={self.p};')[0]
        path=self.root/'plants'/str(self.p)/name;data=path.read_bytes();path.unlink()
        try:
            code,result=self.ready();self.assertEqual(code,503);self.assertFalse(result['checks']['photoFiles'])
            with urllib.request.urlopen(self.base+'/health/live') as r:self.assertEqual(r.status,200)
        finally:path.write_bytes(data)
        self.assertEqual(self.ready()[0],200)

    def test_photo_schema_contract_and_incomplete_migration_block_readiness(self):
        migration='202610271200_PhotoTaxonTransaction.sql'
        rows=sql(f"SELECT checksum FROM schemaversion WHERE scriptName='{migration}';")
        if rows:
            sql(f"DELETE FROM schemaversion WHERE scriptName='{migration}';")
            restore=f"INSERT INTO schemaversion(scriptName,checksum) VALUES('{migration}','{rows[0]}');"
        else:
            marker,checksum=sql("SELECT scriptName,checksum FROM schemaversion WHERE scriptName LIKE 'baseline:v1:%';")[0].split('\t')
            sql(f"UPDATE schemaversion SET scriptName='baseline:v1:202610262000' WHERE scriptName='{marker}';")
            restore=f"UPDATE schemaversion SET scriptName='{marker}' WHERE scriptName='baseline:v1:202610262000';"
        try:
            code,result=self.ready();self.assertEqual(code,503);self.assertFalse(result['checks']['database'])
            before=self.snapshot()
            self.assertEqual(self.post(f'/Setup/Taxa/Actions/Edit/{self.t}',{'Taxon.SpeciesName':self.name,'Taxon.TaxonNotes':'must not persist'})[0],503)
            self.assertEqual(self.snapshot(),before)
        finally:sql(restore)
        self.assertEqual(self.ready()[0],200)
        sql("INSERT INTO schemaversion(scriptName,checksum) VALUES('migration:pending',REPEAT('0',64));")
        try:self.assertEqual(self.ready()[0],503)
        finally:sql("DELETE FROM schemaversion WHERE scriptName='migration:pending';")
        self.assertEqual(self.ready()[0],200)

    def test_orphan_commit_journal_is_retained_and_blocks_readiness(self):
        folder=self.root/'.photo-recovery';folder.mkdir(exist_ok=True)
        retained=self.root/'plants'/str(self.p)/(uuid.uuid4().hex+'.jpg');retained.parent.mkdir(parents=True,exist_ok=True);retained.write_bytes(self.image)
        path=folder/(uuid.uuid4().hex+'.json');record={'version':1,'state':'CommitOutcomeUnknown','files':[retained.relative_to(self.root).as_posix()]}
        path.write_text(json.dumps(record));before=path.read_bytes()
        try:
            code,result=self.ready();self.assertEqual(code,503);self.assertFalse(result['checks']['photoRecovery'])
            self.assertEqual(path.read_bytes(),before)
            with self.assertRaises(urllib.error.HTTPError) as private:urllib.request.urlopen(self.base+'/uploads/.photo-recovery/'+path.name)
            self.assertEqual(private.exception.code,404)
            snapshot=self.snapshot()
            self.post(f'/Plants/Photos/{self.p}?handler=Upload',files=[('UploadFiles','valid.jpg',self.image)])
            self.assertEqual(self.snapshot(),snapshot)
            review=subprocess.run(['pwsh','-NoProfile','-File',str(self.repo/'scripts/PhotoRecovery/review.ps1'),'-UploadsRoot',str(self.root)],capture_output=True,text=True,timeout=20)
            self.assertEqual(review.returncode,0,review.stderr)
            self.assertEqual(json.loads(review.stdout)[0]['status'],'UnreferencedPresent')
            self.assertEqual(path.read_bytes(),before);self.assertEqual(retained.read_bytes(),self.image)
        finally:path.unlink();retained.unlink()
        self.assertEqual(self.ready()[0],200)

    def test_recovery_report_preserves_referenced_files_and_identifies_missing_thumbnail(self):
        self.upload();main,thumb=sql(f'SELECT fileName,thumbnailFileName FROM plantphoto WHERE plantId={self.p};')[0].split('\t')
        folder=self.root/'plants'/str(self.p);main_bytes=(folder/main).read_bytes();thumb_bytes=(folder/thumb).read_bytes()
        journal_folder=self.root/'.photo-recovery';journal_folder.mkdir(exist_ok=True)
        journal=journal_folder/(uuid.uuid4().hex+'.json')
        journal.write_text(json.dumps({'version':1,'state':'CommitOutcomeUnknown','files':[f'plants/{self.p}/{main}',f'plants/{self.p}/{thumb}']}))
        (folder/thumb).unlink()
        try:
            review=subprocess.run(['pwsh','-NoProfile','-File',str(self.repo/'scripts/PhotoRecovery/review.ps1'),'-UploadsRoot',str(self.root)],capture_output=True,text=True,timeout=20)
            self.assertEqual(review.returncode,0,review.stderr)
            self.assertEqual([row['status'] for row in json.loads(review.stdout)],['ReferencedPresent','ReferencedMissing'])
            self.assertEqual((folder/main).read_bytes(),main_bytes);self.assertTrue(journal.exists())
            self.assertEqual(self.ready()[0],503)
        finally:(folder/thumb).write_bytes(thumb_bytes);journal.unlink()
        self.assertEqual(self.ready()[0],200)

    @contextmanager
    def alternate_host(self,changes):
        listener=socket.socket();listener.bind(('127.0.0.1',0));port=listener.getsockname()[1];listener.close()
        env={**os.environ,'ASPNETCORE_URLS':f'http://127.0.0.1:{port}',**changes}
        log=self.root.parent/('c19-host-'+uuid.uuid4().hex+'.log')
        with log.open('w') as output:
            process=subprocess.Popen([shutil.which('dotnet'),str(self.repo/'src/OrchidApp.Web/bin/Release/net8.0/OrchidApp.Web.dll')],env=env,cwd=self.repo/'src/OrchidApp.Web',stdout=output,stderr=output,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
            try:
                base=env['ASPNETCORE_URLS'];deadline=time.monotonic()+20
                while time.monotonic()<deadline:
                    if process.poll() is not None:self.fail('Alternate fixture host exited; inspect '+str(log))
                    try:
                        with urllib.request.urlopen(base+'/health/live',timeout=1) as r:
                            if r.status==200:break
                    except (OSError,urllib.error.URLError):time.sleep(.1)
                else:self.fail('Alternate host was not live')
                yield base
            finally:process.terminate();process.wait(timeout=15)

    def test_missing_database_is_503_without_disclosing_credentials(self):
        # Replace only the generated fixture database name, preserving literal
        # credential escaping in the existing connection string.
        original=os.environ['ConnectionStrings__OrchidDb'];database=os.environ['C11_TEST_DATABASE']
        with self.alternate_host({'ConnectionStrings__OrchidDb':original.replace(database,database+'_missing')}) as base:
            code,result=self.ready(base);self.assertEqual(code,503);self.assertFalse(result['checks']['database'])
            text=json.dumps(result);self.assertNotIn(database,text);self.assertNotIn('Password',text)

    def test_missing_upload_root_can_be_repaired_without_restarting_static_files(self):
        root=self.root.parent/('c19-root-'+uuid.uuid4().hex)
        with self.alternate_host({'Storage__UploadRoot':str(root)}) as base:
            code,result=self.ready(base);self.assertEqual(code,503);self.assertFalse(result['checks']['uploadRoot'])
            shutil.copytree(self.root,root)
            self.assertEqual(self.ready(base)[0],200)
            fixture=root/'plants'/'repaired';fixture.mkdir(parents=True);(fixture/'photo.jpg').write_bytes(self.image)
            with urllib.request.urlopen(base+'/uploads/plants/repaired/photo.jpg') as r:self.assertEqual(r.status,200)

    def test_paired_sql_photo_restore_retains_journal_and_detects_missing_restored_file(self):
        self.upload();main,thumb=sql(f'SELECT fileName,thumbnailFileName FROM plantphoto WHERE plantId={self.p};')[0].split('\t')
        journal_folder=self.root/'.photo-recovery';journal_folder.mkdir(exist_ok=True)
        journal=journal_folder/(uuid.uuid4().hex+'.json')
        journal.write_text(json.dumps({'version':1,'state':'CommitOutcomeUnknown','files':[f'plants/{self.p}/{main}']}))
        archive=self.root.parent/('c19-pair-'+uuid.uuid4().hex+'.zip')
        restore='orchids_c19_'+uuid.uuid4().hex;assert re.fullmatch(r'orchids_c19_[a-f0-9]{32}',restore)
        restored=self.root.parent/restore;restored.mkdir()
        try:
            dump=subprocess.run(['mariadb-dump','--defaults-extra-file='+DEFAULTS,'--single-transaction','--routines','--triggers',DATABASE],capture_output=True,timeout=30)
            self.assertEqual(dump.returncode,0,dump.stderr.decode())
            with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
                z.writestr('database.sql',dump.stdout)
                for file in self.root.rglob('*'):
                    if file.is_file():z.write(file,'uploads/'+file.relative_to(self.root).as_posix())
            sql(f'CREATE DATABASE `{restore}` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;')
            with zipfile.ZipFile(archive) as z:
                for name in z.namelist():
                    self.assertFalse(Path(name).is_absolute() or '..' in Path(name).parts)
                    destination=restored/name;destination.parent.mkdir(parents=True,exist_ok=True);destination.write_bytes(z.read(name))
                loaded=subprocess.run(['mariadb','--defaults-extra-file='+DEFAULTS,restore],input=z.read('database.sql'),capture_output=True,timeout=30)
                self.assertEqual(loaded.returncode,0,loaded.stderr.decode())
            upload=restored/'uploads'
            connection=os.environ['ConnectionStrings__OrchidDb'].replace(DATABASE,restore)
            with self.alternate_host({'Storage__UploadRoot':str(upload),'ConnectionStrings__OrchidDb':connection}) as base:
                code,result=self.ready(base);self.assertEqual(code,503);self.assertFalse(result['checks']['photoRecovery']);self.assertTrue(result['checks']['photoFiles'])
                restored_journal=upload/'.photo-recovery'/journal.name
                self.assertEqual(restored_journal.read_bytes(),journal.read_bytes())
                # The fixture knows this journal references committed rows and
                # the paired files; emulate the documented operator resolution.
                restored_journal.unlink();self.assertEqual(self.ready(base)[0],200)
                missing=upload/'plants'/str(self.p)/thumb;original=missing.read_bytes();missing.unlink()
                code,result=self.ready(base);self.assertEqual(code,503);self.assertFalse(result['checks']['photoFiles'])
                missing.write_bytes(original);self.assertEqual(self.ready(base)[0],200)
        finally:
            if journal.exists():journal.unlink()
            sql(f'DROP DATABASE IF EXISTS `{restore}`;')


if __name__=='__main__':unittest.main(verbosity=2)
