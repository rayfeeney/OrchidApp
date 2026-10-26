"""Actual MariaDB sessions and HTTP requests; generated fixture DBs only."""
from checks import sql, DEFAULTS, DATABASE
from datetime import date, timedelta
from concurrent.futures import ThreadPoolExecutor
import html
import http.cookiejar
import os
from pathlib import Path
import queue
import re
import subprocess
import threading
import time
import unittest
import urllib.error
import urllib.parse
import urllib.request


class Session:
    """A persistent CLI connection, including caller-owned transactions."""
    def __init__(self):
        self.process = subprocess.Popen(['mariadb', '--defaults-extra-file='+DEFAULTS,
            '--batch', '--skip-column-names', '--unbuffered', '--force', DATABASE],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            text=True, encoding='utf-8')
        self.lines = queue.Queue()
        self.errors = []
        def read():
            for line in self.process.stdout:
                self.lines.put(line.rstrip('\n'))
        def errors():
            self.errors.extend(self.process.stderr)
        self.reader = threading.Thread(target=read, daemon=True); self.reader.start()
        self.err_reader = threading.Thread(target=errors, daemon=True); self.err_reader.start()
        self.id = int(self.run('SELECT CONNECTION_ID();')[0])

    def run(self, statement):
        marker = 'C13_'+os.urandom(8).hex()
        self.process.stdin.write(statement+f"\nSELECT '{marker}';\n")
        self.process.stdin.flush()
        rows=[]
        while True:
            line=self.lines.get(timeout=20)
            if line == marker:return rows
            rows.append(line)

    def close(self):
        if self.process.poll() is None:
            self.process.stdin.close()
            self.process.wait(timeout=20)
        self.reader.join(timeout=2);self.err_reader.join(timeout=2)
        self.process.stdout.close();self.process.stderr.close()

    def __enter__(self):return self
    def __exit__(self,*args):self.close()


class Structural(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.base=os.environ['C11_TEST_WEB_URL']
        sql("CALL spAddGenus('C13 fixture','Synthetic'); CREATE TABLE c13_witness(id INT PRIMARY KEY,value INT); INSERT INTO c13_witness VALUES(1,0); INSERT INTO location(locationName) VALUES('C13 A'),('C13 B'),('C13 C');")
        cls.taxon=int(sql('SELECT MIN(taxonId) FROM taxon;')[0])
        cls.locations=[int(x) for x in sql("SELECT locationId FROM location WHERE locationName LIKE 'C13 %' ORDER BY locationId;")]
        cls.propagation_type=int(sql('SELECT MIN(propagationTypeId) FROM propagationtype WHERE isActive=1;')[0])

    def setUp(self):
        self.p=self.plant()
        sql(f"INSERT INTO plantlocationhistory(plantId,locationId,startDateTime,endDateTime) VALUES({self.p},{self.locations[0]},'2020-02-01','2020-03-01'),({self.p},{self.locations[1]},'2020-03-01',NULL); INSERT INTO flowering(plantId,startDate) VALUES({self.p},'2020-02-02');")
        self.history=int(sql(f'SELECT MAX(plantLocationHistoryId) FROM plantlocationhistory WHERE plantId={self.p};')[0])

    def tearDown(self):
        sql('DROP TRIGGER IF EXISTS c13_failure;')

    def plant(self):
        sql(f"CALL spAddPlant({self.taxon},'2020-01-01','fixture','C13 plant','fixture');")
        return int(sql('SELECT MAX(plantId) FROM plant;')[0])

    def move(self, when='2020-06-01', location=None):
        return f"CALL spMovePlantToLocation({self.p},{location or self.locations[2]},'{when}','move','fixture');"

    def split(self):
        return f'''CALL spSplitPlant({self.p},'2021-01-01','[{{"plantName":"one"}},{{"plantName":"two"}}]','split','fixture');'''

    def propagate(self):
        return f"CALL spPropagatePlant({self.p},'2020-06-01',{self.propagation_type},'C13 child',NULL,'fixture');"

    def closure(self):
        return f"CALL spUpdatePlantDetails({self.p},{self.taxon},'C13 plant','2020-01-01','fixture','2021-03-01','end','fixture');"

    def snapshot(self):
        # This suite runs sequentially except for explicitly paired connections.
        return {table:sql(f'SELECT * FROM {table} ORDER BY 1;') for table in
                ['plant','plantlocationhistory','flowering','repotting','plantsplit','plantsplitchild','plantpropagation','plantevent','plantphoto']}

    def invariant(self):
        self.assertEqual(sql(f'SELECT COUNT(*) FROM plantlocationhistory WHERE plantId={self.p} AND isActive=1 AND endDateTime IS NULL;'),['1'])
        self.assertEqual(sql(f"SELECT COUNT(*) FROM plantlocationhistory a JOIN plantlocationhistory b ON a.plantId=b.plantId AND a.plantLocationHistoryId<b.plantLocationHistoryId WHERE a.plantId={self.p} AND a.isActive=1 AND b.isActive=1 AND a.startDateTime<COALESCE(b.endDateTime,'9999-12-31') AND b.startDateTime<COALESCE(a.endDateTime,'9999-12-31');"),['0'])

    def failure(self, statement, trigger):
        sql('DELIMITER //\n'+trigger.rstrip(';')+'//\nDELIMITER ;')
        before=self.snapshot()
        with Session() as session:
            rows=session.run(statement+' SELECT @@in_transaction;')
            self.assertEqual(rows[-1],'0')
            self.assertEqual(self.snapshot(),before)
            # A later, unrelated commit on this same connection must not retain
            # any earlier partial operation.
            session.run('START TRANSACTION; UPDATE c13_witness SET value=value+1; COMMIT;')
            self.assertEqual(self.snapshot(),before)
        self.assertIn('C13 injected failure',''.join(session.errors))
        with Session() as caller:
            rows=caller.run('START TRANSACTION; UPDATE c13_witness SET value=881; '+statement+' SELECT @@in_transaction,value FROM c13_witness; COMMIT; SELECT @@in_transaction;')
            self.assertEqual(rows[-2:],['1\t881','0'])
            self.assertEqual(self.snapshot(),before)
        self.assertIn('C13 injected failure',''.join(caller.errors))
        self.assertEqual(sql('SELECT value FROM c13_witness;'),['881'])

    def test_move_insert_failure_rolls_back_previous_interval(self):
        self.failure(self.move(), "CREATE TRIGGER c13_failure BEFORE INSERT ON plantlocationhistory FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='C13 injected failure';")

    def test_edit_failure_rolls_back_predecessor_adjustment(self):
        self.failure(f"CALL spEditPlantLocation({self.history},'2020-04-01','changed','changed');", f"CREATE TRIGGER c13_failure BEFORE UPDATE ON plantlocationhistory FOR EACH ROW BEGIN IF NEW.plantLocationHistoryId={self.history} THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='C13 injected failure'; END IF; END;")

    def test_remove_failure_rolls_back_soft_delete(self):
        self.failure(f'CALL spRemovePlantLocation({self.history});', f"CREATE TRIGGER c13_failure BEFORE UPDATE ON plantlocationhistory FOR EACH ROW BEGIN IF NEW.plantLocationHistoryId<>{self.history} THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='C13 injected failure'; END IF; END;")

    def test_split_failure_rolls_back_children_lineage_and_closure(self):
        self.failure(self.split(), "CREATE TRIGGER c13_failure BEFORE UPDATE ON flowering FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='C13 injected failure';")

    def test_propagation_failure_rolls_back_child(self):
        self.failure(self.propagate(), "CREATE TRIGGER c13_failure BEFORE INSERT ON plantpropagation FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='C13 injected failure';")

    def test_success_never_commits_callers_transaction(self):
        operations=[self.move(),f"CALL spEditPlantLocation({self.history},'2020-04-01','change','change');",f'CALL spRemovePlantLocation({self.history});',self.split(),self.propagate()]
        for operation in operations:
            with self.subTest(operation=operation):
                before=self.snapshot()
                with Session() as s:
                    rows=s.run('START TRANSACTION; UPDATE c13_witness SET value=771; '+operation+' SELECT @@in_transaction;')
                    self.assertEqual(rows[-1],'1')
                    self.assertNotEqual(sql('SELECT value FROM c13_witness;'),['771'])
                    s.run('ROLLBACK;')
                self.assertEqual(self.snapshot(),before)
                self.assertEqual(s.errors,[])

    def test_failure_preserves_callers_work_and_connection_reuse(self):
        operations=[self.move(),f"CALL spEditPlantLocation({self.history},'2020-04-01','change','change');",f'CALL spRemovePlantLocation({self.history});',self.split(),self.propagate()]
        # Ended validation fails inside the savepoint for every structural call.
        sql(self.closure());before=self.snapshot()
        for operation in operations:
            with self.subTest(operation=operation), Session() as s:
                rows=s.run('START TRANSACTION; UPDATE c13_witness SET value=991; '+operation+' SELECT @@in_transaction,value FROM c13_witness; COMMIT; SELECT @@in_transaction;')
                self.assertEqual(rows[-2:],['1\t991','0'])
                self.assertEqual(sql('SELECT value FROM c13_witness;'),['991'])
                self.assertEqual(self.snapshot(),before)

    def wait_blocked(self, session, future):
        deadline=time.monotonic()+10
        while time.monotonic()<deadline:
            if future.done():self.fail('Competing operation completed before parent lock was released')
            rows=sql(f'SELECT COUNT(*) FROM information_schema.INNODB_LOCK_WAITS w JOIN information_schema.INNODB_TRX t ON t.trx_id=w.requesting_trx_id WHERE t.trx_mysql_thread_id={session.id};')
            if rows==['1']:return
            time.sleep(.05)
        self.fail('Competing operation did not wait on the parent row lock')

    def race(self, first, second):
        with Session() as a, Session() as b, ThreadPoolExecutor(max_workers=1) as pool:
            a.run('START TRANSACTION; '+first)
            task=pool.submit(b.run,second+' SELECT @@in_transaction;')
            try:self.wait_blocked(b,task)
            finally:a.run('COMMIT;')
            rows=task.result(timeout=20)
            self.assertEqual(rows[-1],'0')
        return a.errors,b.errors

    def test_concurrent_moves_serialize_and_preserve_intervals(self):
        errors=self.race(self.move(),self.move('2020-07-01',self.locations[0]))
        self.assertEqual(errors,([],[]));self.invariant()

    def test_move_uses_current_rows_inside_older_caller_snapshot(self):
        with Session() as caller:
            caller.run('SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ; START TRANSACTION;')
            self.assertEqual(caller.run(f'SELECT COUNT(*) FROM plantlocationhistory WHERE plantId={self.p};'),['2'])
            sql(self.move())
            # The consistent snapshot still contains only the original rows.
            self.assertEqual(caller.run(f'SELECT COUNT(*) FROM plantlocationhistory WHERE plantId={self.p};'),['2'])
            self.assertEqual(caller.run(self.move('2020-07-01',self.locations[0])+' SELECT @@in_transaction;')[-1],'1')
            caller.run('COMMIT;')
        self.assertEqual(caller.errors,[]);self.invariant()
        self.assertEqual(sql(f'SELECT COUNT(*) FROM plantlocationhistory WHERE plantId={self.p};'),['4'])

    def test_concurrent_splits_create_one_lineage(self):
        errors=self.race(self.split(),self.split())
        self.assertEqual(errors[0],[]);self.assertIn('Ended plants are read-only',''.join(errors[1]))
        self.assertEqual(sql(f'SELECT COUNT(*) FROM plantsplit WHERE parentPlantId={self.p};'),['1'])
        self.assertEqual(sql(f'SELECT COUNT(*) FROM plantsplitchild c JOIN plantsplit s ON c.plantSplitId=s.plantSplitId WHERE s.parentPlantId={self.p};'),['2'])

    def test_concurrent_propagations_keep_distinct_children(self):
        self.assertEqual(self.race(self.propagate(),self.propagate()),([],[]))
        self.assertEqual(sql(f'SELECT COUNT(DISTINCT childPlantId) FROM plantpropagation WHERE parentPlantId={self.p};'),['2'])

    def test_rolled_back_closure_allows_waiting_structural_writes(self):
        operations=lambda:[self.move(),self.split(),self.propagate(),f'CALL spRemovePlantLocation({self.history});']
        for index in range(4):
            operation=operations()[index]
            with self.subTest(operation=operation):
                # Roll back the first closure so every subcase starts editable.
                with Session() as a,Session() as b,ThreadPoolExecutor(max_workers=1) as pool:
                    a.run('START TRANSACTION; '+self.closure())
                    task=pool.submit(b.run,operation)
                    try:self.wait_blocked(b,task)
                    finally:a.run('ROLLBACK;')
                    task.result(timeout=20)
                self.assertEqual(b.errors,[])
                # The operation may end/change this plant; use a fresh fixture.
                self.setUp()

    def test_committed_closure_refuses_waiting_structural_writes(self):
        operations=lambda:[self.move(),self.split(),self.propagate(),
            f'CALL spRemovePlantLocation({self.history});',
            f"CALL spEditPlantLocation({self.history},'2020-04-01','','');"]
        for index in range(5):
            operation=operations()[index]
            with self.subTest(operation=operation):
                errors=self.race(self.closure(),operation)
                self.assertEqual(errors[0],[])
                self.assertIn('Ended plants are read-only',''.join(errors[1]))
                self.setUp()

    def test_split_refuses_interval_inversion_and_invalid_children(self):
        before=self.snapshot()
        sql(self.split().replace('2021-01-01','2020-02-01'),error='Split cannot precede an open interval start')
        sql(f"CALL spSplitPlant({self.p},'2021-01-01',NULL,'','');",error='at least two')
        self.assertEqual(self.snapshot(),before)

    def opener(self):
        opener=urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
        page=opener.open(self.base+f'/Plants/Edit/{self.p}').read().decode()
        token=html.unescape(re.search(r'name="__RequestVerificationToken"[^>]*value="([^"]+)"',page).group(1))
        return opener,token

    def post(self, opener, token, path, values):
        try:
            r=opener.open(self.base+path,urllib.parse.urlencode({'__RequestVerificationToken':token,**values}).encode(),timeout=20)
            return r.status,r.read().decode()
        except urllib.error.HTTPError as e:return e.code,e.read().decode()

    def test_waiting_event_and_photo_posts_refuse_committed_closure(self):
        paths=lambda:[(f'/Plants/Events/Add/{self.p}/Observation',{'EventDate':'2020-06-01','EventDetails':'race'}),
               (f'/Plants/Photos/{self.p}?handler=Upload',{}),
               (f'/Plants/Photos/{self.p}?handler=SetHero',{'photoId':'0'})]
        for index in range(3):
            path,values=paths()[index]
            with self.subTest(path=path):
                opener,token=self.opener()
                with Session() as a,ThreadPoolExecutor(max_workers=1) as pool:
                    a.run('START TRANSACTION; '+self.closure());before=self.snapshot()
                    future=pool.submit(self.post,opener,token,path,values)
                    # Observe an actual server lock wait, not timing alone.
                    deadline=time.monotonic()+10
                    while time.monotonic()<deadline:
                        if future.done():self.fail('HTTP write bypassed closure lock')
                        if int(sql('SELECT COUNT(*) FROM information_schema.INNODB_LOCK_WAITS;')[0])>0:break
                        time.sleep(.05)
                    else:self.fail('HTTP write did not acquire a parent lock')
                    a.run('COMMIT;');self.assertEqual(future.result()[0],400)
                after=self.snapshot();before['plant']=after['plant'];before['plantlocationhistory']=after['plantlocationhistory'];before['flowering']=after['flowering']
                self.assertEqual(after,before)
                self.setUp()

    def test_route_id_override_cannot_lock_a_different_plant(self):
        opener,token=self.opener();other=self.plant();before=self.snapshot()
        self.assertEqual(self.post(opener,token,f'/Plants/Events/Add/{self.p}/Observation',{'PlantId':other,'EventDate':'2020-06-01','EventDetails':'attempt'})[0],400)
        self.assertEqual(self.snapshot(),before)

    def photos(self):
        sql(f"INSERT INTO plantevent(plantId,eventDateTime,eventDetails,observationTypeId) VALUES({self.p},'2020-06-01','photo fixture',(SELECT Id FROM observationtype WHERE typeCode='OBS_PHOTO')); SET @event=LAST_INSERT_ID(); INSERT INTO plantphoto(plantId,plantEventId,fileName,thumbnailFileName,mimeType,isHero) VALUES({self.p},@event,'first.jpg','first-thumb.jpg','image/jpeg',1),({self.p},@event,'second.jpg','second-thumb.jpg','image/jpeg',0);")
        return [int(x) for x in sql(f'SELECT plantPhotoId FROM plantphoto WHERE plantId={self.p} ORDER BY plantPhotoId;')]

    def test_hero_selection_rolls_back_and_uses_current_database(self):
        first,second=self.photos()
        self.failure(f'CALL spSetHeroPhoto({self.p},{second});', f"CREATE TRIGGER c13_failure BEFORE UPDATE ON plantphoto FOR EACH ROW BEGIN IF NEW.plantPhotoId={second} THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='C13 injected failure'; END IF; END;")
        sql('DROP TRIGGER c13_failure;')
        before=self.snapshot()
        with Session() as s:
            self.assertEqual(s.run(f'START TRANSACTION; CALL spSetHeroPhoto({self.p},{second}); SELECT @@in_transaction;')[-1],'1')
            s.run('ROLLBACK;')
        self.assertEqual(self.snapshot(),before)
        opener,token=self.opener()
        self.assertEqual(self.post(opener,token,f'/Plants/Photos/{self.p}?handler=SetHero',{'photoId':second})[0],200)
        self.assertEqual(sql(f'SELECT plantPhotoId FROM plantphoto WHERE plantId={self.p} AND isHero=1;'),[str(second)])

    def test_closure_waits_for_an_event_write_then_closes_new_flowering(self):
        # A synthetic trigger holds the HTTP writer after its parent lock. A
        # separate closure must wait until that event commits, then include it.
        sql(f'UPDATE flowering SET endDate=\'2020-03-01\' WHERE plantId={self.p};')
        lock='c13_event_'+str(self.p)
        sql(f"DELIMITER //\nCREATE TRIGGER c13_failure BEFORE INSERT ON flowering FOR EACH ROW BEGIN DO GET_LOCK('{lock}',15); DO RELEASE_LOCK('{lock}'); END//\nDELIMITER ;")
        opener,token=self.opener()
        with Session() as holder,Session() as closer,ThreadPoolExecutor(max_workers=2) as pool:
            self.assertEqual(holder.run(f"SELECT GET_LOCK('{lock}',0);"),['1'])
            event=pool.submit(self.post,opener,token,f'/Plants/Events/Add/{self.p}/Flowering',{'StartDate':'2020-06-01'})
            try:
                deadline=time.monotonic()+10
                while time.monotonic()<deadline:
                    if event.done():self.fail('Event did not reach the guarded write')
                    if int(sql("SELECT COUNT(*) FROM information_schema.PROCESSLIST WHERE STATE='User lock';")[0]):break
                    time.sleep(.05)
                else:self.fail('HTTP writer did not reach the synthetic trigger')
                closure=pool.submit(closer.run,self.closure()+' SELECT @@in_transaction;')
                self.wait_blocked(closer,closure)
            finally:holder.run(f"SELECT RELEASE_LOCK('{lock}');")
            self.assertEqual(event.result()[0],200)
            self.assertEqual(closure.result()[-1],'0')
        self.assertEqual(closer.errors,[])
        self.assertEqual(sql(f'SELECT COUNT(*) FROM flowering WHERE plantId={self.p} AND endDate IS NULL;'),['0'])
        self.assertEqual(sql(f'SELECT COUNT(*) FROM flowering f JOIN plant p ON f.plantId=p.plantId WHERE f.plantId={self.p} AND f.startDate LIKE \'2020-06-01%\' AND f.endDate=p.endDate;'),['1'])

    def test_failed_photo_processing_rolls_back_observation(self):
        opener,token=self.opener();before=self.snapshot()
        boundary='C13Boundary'
        body=(f'--{boundary}\r\nContent-Disposition: form-data; name="__RequestVerificationToken"\r\n\r\n{token}\r\n'
              f'--{boundary}\r\nContent-Disposition: form-data; name="UploadFiles"; filename="bad.jpg"\r\nContent-Type: image/jpeg\r\n\r\nnot an image\r\n--{boundary}--\r\n').encode()
        request=urllib.request.Request(self.base+f'/Plants/Photos/{self.p}?handler=Upload',body,{'Content-Type':'multipart/form-data; boundary='+boundary})
        response=opener.open(request,timeout=20)
        self.assertEqual(response.status,200)
        self.assertIn('could not be processed',response.read().decode())
        self.assertEqual(self.snapshot(),before)

    def test_http_structural_saves_enlist_and_persist(self):
        opener,token=self.opener()
        self.assertEqual(self.post(opener,token,f'/Plants/Events/Add/{self.p}/LocationChange',{'EventDate':'2020-06-01','LocationId':self.locations[2]})[0],200)
        self.invariant()
        self.assertEqual(sql(f'SELECT locationId FROM plantlocationhistory WHERE plantId={self.p} AND isActive=1 AND endDateTime IS NULL;'),[str(self.locations[2])])
        self.assertEqual(self.post(opener,token,f'/Plants/Events/Propagate/{self.p}',{'PropagationDate':'2020-07-01','PropagationTypeId':self.propagation_type,'PlantName':'HTTP child'})[0],200)
        self.assertEqual(sql(f'SELECT COUNT(*) FROM plantpropagation WHERE parentPlantId={self.p};'),['1'])
        self.assertEqual(self.post(opener,token,f'/Plants/Events/Split/{self.p}?handler=Split',{'SplitDateTime':'2021-01-01','Children[0].PlantName':'one','Children[1].PlantName':'two'})[0],200)
        self.assertEqual(sql(f'SELECT COUNT(*) FROM plantsplitchild c JOIN plantsplit s ON c.plantSplitId=s.plantSplitId WHERE s.parentPlantId={self.p};'),['2'])
        self.assertEqual(sql(f'SELECT COUNT(*) FROM plant WHERE plantId={self.p} AND endDate IS NOT NULL;'),['1'])

    def test_late_procedure_error_rolls_back_http_request(self):
        # Deliberately return a plausible first result before failing. The
        # executor must observe the trailing error, not report a saved child.
        definition=(Path(__file__).resolve().parents[2]/'database/schema/routines/spPropagatePlant.sql').read_text(encoding='utf-8')
        fake=f'''DELIMITER //
CREATE OR REPLACE PROCEDURE spPropagatePlant(IN pParentPlantId INT,IN pPropagationDate DATE,IN pPropagationTypeId INT,IN pChildPlantName VARCHAR(100),IN pMediumId INT,IN pPropagationNotes TEXT)
BEGIN
INSERT INTO plant(taxonId,plantTag,plantName,acquisitionDate) VALUES({self.taxon},fnGeneratePlantTag(),'late error fixture','2020-06-01');
SELECT LAST_INSERT_ID() AS childPlantId,'FAKE-TAG' AS childPlantTag;
SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='C13 late procedure failure';
END//
DELIMITER ;'''
        opener,token=self.opener();before=self.snapshot()
        try:
            sql(fake)
            status,text=self.post(opener,token,f'/Plants/Events/Propagate/{self.p}',{'PropagationDate':'2020-06-01','PropagationTypeId':self.propagation_type})
            self.assertEqual(status,200);self.assertIn('C13 late procedure failure',text)
            self.assertEqual(self.snapshot(),before)
        finally:sql(definition)


if __name__=='__main__':unittest.main(verbosity=2)
