"""Run only through Database.Checks.ps1 against its generated canonical-schema DB."""
from datetime import date, timedelta
import html
import http.cookiejar
import json
import os
from pathlib import Path
import re
import subprocess
import unittest
import urllib.parse
import urllib.request

DATABASE = os.environ['C11_TEST_DATABASE']
if not re.fullmatch(r'orchids_c11_[0-9a-f]{32}', DATABASE):
    raise RuntimeError('Generated lifecycle fixture database required')
DEFAULTS = os.environ['C11_TEST_DEFAULTS']


def sql(statement, error=None, force=False):
    args = ['mariadb', '--defaults-extra-file='+DEFAULTS, '--batch', '--skip-column-names',
            '--default-character-set=utf8mb4', DATABASE]
    if force:
        args.append('--force')
    p = subprocess.run(args, input=statement.encode('utf-8'), stdout=subprocess.PIPE,
                       stderr=subprocess.PIPE, timeout=20)
    text = p.stdout.decode('utf-8').strip()
    if error is not None:
        if error not in p.stderr.decode('utf-8'):
            raise AssertionError('Expected fixture SQL rejection: '+error+'; '+p.stderr.decode('utf-8'))
    elif p.returncode:
        raise AssertionError('Fixture SQL failed: '+p.stderr.decode('utf-8'))
    return text.splitlines() if text else []


class Closure(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        sql("CALL spAddGenus('C11 fixture','Synthetic'); CREATE TABLE c11_witness(id INT PRIMARY KEY,value INT); INSERT INTO c11_witness VALUES (1,0);")
        cls.taxon = int(sql('SELECT MIN(taxonId) FROM taxon;')[0])
        cls.genus = int(sql(f'SELECT genusId FROM taxon WHERE taxonId={cls.taxon};')[0])
        sql("INSERT INTO location(locationName) VALUES ('C11 fixture');")
        cls.location = int(sql("SELECT locationId FROM location WHERE locationName='C11 fixture';")[0])

    def setUp(self):
        self.plant = self.new_plant()
        sql(f"INSERT INTO plantlocationhistory(plantId,locationId,startDateTime) VALUES ({self.plant},{self.location},'2020-02-01 08:00:00'); "
            f"INSERT INTO flowering(plantId,startDate) VALUES ({self.plant},'2020-02-02 09:00:00');")

    def tearDown(self):
        sql('DROP TRIGGER IF EXISTS c11_failure;')

    def new_plant(self, acquired="'2020-01-01'"):
        sql(f"CALL spAddPlant({self.taxon},{acquired},'fixture','Before','Before notes');")
        return int(sql('SELECT MAX(plantId) FROM plant;')[0])

    def call(self, *, plant=None, acquired="'2020-01-01'", ended="'2021-03-01'", name='After'):
        return (f"CALL spUpdatePlantDetails({plant or self.plant},{self.taxon},'{name}',{acquired},"
                f"'fixture',{ended},'End notes','After notes');")

    def state(self, plant=None):
        p = plant or self.plant
        return sql(f"SELECT plantName,IFNULL(acquisitionDate,'NULL'),IFNULL(endDate,'NULL'),IFNULL(endNotes,'NULL'),plantNotes FROM plant WHERE plantId={p}; "
                   f"SELECT startDateTime,IFNULL(endDateTime,'NULL') FROM plantlocationhistory WHERE plantId={p} ORDER BY plantLocationHistoryId; "
                   f"SELECT startDate,IFNULL(endDate,'NULL'),isActive FROM flowering WHERE plantId={p} ORDER BY floweringId;")

    def inject_failure(self, table):
        sql(f"CREATE TRIGGER c11_failure BEFORE UPDATE ON {table} FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Intentional C11 closure failure';")

    def test_closure_persists_all_components_with_same_timestamp(self):
        sql(self.call())
        self.assertEqual(sql(f"SELECT COUNT(*) FROM plant p JOIN plantlocationhistory l ON l.plantId=p.plantId JOIN flowering f ON f.plantId=p.plantId WHERE p.plantId={self.plant} AND p.endDate=l.endDateTime AND p.endDate=f.endDate AND DATE(p.endDate)='2021-03-01';"), ['1'])
        self.assertEqual(sql(f'SELECT plantName,plantNotes,endNotes FROM plant WHERE plantId={self.plant};'), ['After\tAfter notes\tEnd notes'])

    def test_flowering_failure_rolls_back_plant_and_location(self):
        before = self.state(); self.inject_failure('flowering')
        sql(self.call(), error='Intentional C11 closure failure')
        self.assertEqual(self.state(), before)

    def test_location_failure_rolls_back_plant(self):
        before = self.state(); self.inject_failure('plantlocationhistory')
        sql(self.call(), error='Intentional C11 closure failure')
        self.assertEqual(self.state(), before)

    def test_failed_own_transaction_is_closed_and_retry_can_succeed(self):
        self.inject_failure('flowering')
        output = sql(self.call()+'SELECT @@in_transaction;', error='Intentional C11 closure failure', force=True)
        self.assertEqual(output, ['0'])
        sql('DROP TRIGGER c11_failure;'+self.call())
        self.assertEqual(sql(f'SELECT COUNT(*) FROM flowering WHERE plantId={self.plant} AND endDate IS NULL;'), ['0'])

    def test_caller_transaction_success_is_not_committed(self):
        before = self.state()
        output = sql('START TRANSACTION; UPDATE c11_witness SET value=10;'+self.call()+
                     'SELECT @@in_transaction,value FROM c11_witness; ROLLBACK; SELECT value FROM c11_witness;')
        self.assertEqual(output, ['1\t10','0'])
        self.assertEqual(self.state(), before)

    def test_caller_transaction_failure_keeps_prior_work_and_original_error(self):
        before = self.state(); self.inject_failure('flowering')
        output = sql('START TRANSACTION; UPDATE c11_witness SET value=20;'+self.call()+
                     'SELECT @@in_transaction,value FROM c11_witness; ROLLBACK; SELECT value FROM c11_witness;',
                     error='Intentional C11 closure failure', force=True)
        self.assertEqual(output, ['1\t20','0'])
        self.assertEqual(self.state(), before)

    def test_unknown_acquisition_date_can_close(self):
        p = self.new_plant('NULL')
        sql(self.call(plant=p, acquired='NULL'))
        self.assertEqual(sql(f"SELECT acquisitionDate IS NULL,DATE(endDate) FROM plant WHERE plantId={p};"), ['1\t2021-03-01'])

    def test_missing_plant_rejected_without_changes(self):
        before = self.state()
        sql(self.call(plant=2147483647), error='Plant not found.')
        self.assertEqual(self.state(), before)

    def test_future_and_same_acquisition_day_rejected(self):
        before = self.state()
        future = (date.today()+timedelta(days=10)).isoformat()
        for args, message in (({'acquired':f"'{future}'"},'Acquisition date cannot be in the future.'),
                              ({'ended':f"'{future}'"},'End date cannot be in the future.'),
                              ({'ended':"'2020-01-01'"},'End date must be after acquisition date.')):
            with self.subTest(message=message):
                sql(self.call(**args), error=message)
                self.assertEqual(self.state(), before)

    def test_open_flowering_after_closure_is_rejected(self):
        sql(f"UPDATE flowering SET startDate='2022-01-01' WHERE plantId={self.plant};")
        before = self.state()
        sql(self.call(), error='End date cannot be before an open flowering start.')
        self.assertEqual(self.state(), before)

    def test_open_location_after_closure_rejects_without_partial_plant_save(self):
        sql(f"UPDATE plantlocationhistory SET startDateTime='2022-01-01' WHERE plantId={self.plant};")
        before = self.state()
        sql(self.call(), error='End date must be after an open location start.')
        self.assertEqual(self.state(), before)

    def test_closed_intervals_unchanged_and_multiple_open_rows_close(self):
        sql(f"INSERT INTO flowering(plantId,startDate,endDate) VALUES ({self.plant},'2020-01-02','2020-01-03'); "
            f"INSERT INTO flowering(plantId,startDate,isActive) VALUES ({self.plant},'2020-02-03',0); "
            f"INSERT INTO plantlocationhistory(plantId,locationId,startDateTime,endDateTime) VALUES ({self.plant},{self.location},'2020-01-02','2020-01-03');")
        sql(self.call())
        self.assertEqual(sql(f"SELECT COUNT(*) FROM flowering WHERE plantId={self.plant} AND endDate='2020-01-03';"), ['1'])
        self.assertEqual(sql(f"SELECT COUNT(*) FROM flowering f JOIN plant p ON p.plantId=f.plantId WHERE p.plantId={self.plant} AND f.endDate=p.endDate;"), ['2'])
        self.assertEqual(sql(f"SELECT COUNT(*) FROM plantlocationhistory WHERE plantId={self.plant} AND endDateTime='2020-01-03';"), ['1'])

    def test_existing_time_preserved_and_nonclosure_edit_does_not_end_intervals(self):
        sql(f"UPDATE plant SET acquisitionDate='2020-01-01 12:34:56' WHERE plantId={self.plant};")
        sql(self.call(ended='NULL', acquired="'2020-01-02'"))
        self.assertEqual(sql(f"SELECT acquisitionDate,endDate IS NULL FROM plant WHERE plantId={self.plant};"), ['2020-01-02 12:34:56\t1'])
        self.assertEqual(sql(f'SELECT COUNT(*) FROM flowering WHERE plantId={self.plant} AND endDate IS NULL;'), ['1'])

    def test_ended_details_and_reactivation_are_refused(self):
        sql(self.call())
        before = self.state()
        sql(self.call(ended="'2021-03-02'"), error='Ended plants are read-only.')
        sql(self.call(ended='NULL'), error='Ended plants are read-only.')
        self.assertEqual(self.state(), before)
        self.assertEqual(sql(f'SELECT COUNT(*) FROM flowering WHERE plantId={self.plant} AND endDate IS NULL;'), ['0'])

    def test_split_parent_and_child_boundaries_remain_protected(self):
        child = self.new_plant("'2020-08-01'")
        sql(f"INSERT INTO plantsplit(parentPlantId,splitDateTime) VALUES ({self.plant},'2020-08-01 10:00:00'); "
            f"INSERT INTO plantsplitchild(plantSplitId,childPlantId) SELECT plantSplitId,{child} FROM plantsplit WHERE parentPlantId={self.plant}; "
            f"UPDATE plant SET endDate='2020-08-01 10:00:00' WHERE plantId={self.plant};")
        before = self.state()
        sql(self.call(), error='Ended plants are read-only.')
        self.assertEqual(self.state(), before)
        sql(self.call(plant=child, acquired="'2020-08-02'"), error='Cannot modify acquisition date: plant was created via split.')
        self.assertEqual(sql(f'SELECT acquisitionDate FROM plant WHERE plantId={child};')[0][:10], '2020-08-01')

    def test_actual_edit_page_save_reopen_and_failure_stays_editable(self):
        base = os.environ.get('C11_TEST_WEB_URL')
        if not base:
            self.skipTest('Actual web host not supplied')
        opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
        url = base+'/Plants/Edit/'+str(self.plant)
        def submit():
            page = opener.open(url, timeout=15).read().decode('utf-8')
            token = html.unescape(re.search(r'name="__RequestVerificationToken"[^>]*value="([^"]+)"',page).group(1))
            values = {'__RequestVerificationToken':token, 'PlantId':self.plant, 'GenusId':self.genus,
                      'TaxonId':self.taxon, 'PlantName':'HTTP closed café', 'AcquisitionDate':'2020-01-01',
                      'AcquisitionSource':'fixture', 'EndDate':'2021-03-01', 'EndNotes':'HTTP end notes', 'PlantNotes':'HTTP saved notes'}
            return opener.open(url, urllib.parse.urlencode(values).encode(), timeout=15)
        before = self.state(); self.inject_failure('flowering')
        response = submit(); page = response.read().decode('utf-8')
        self.assertEqual(response.status, 200)
        self.assertIn('Intentional C11 closure failure', page)
        self.assertNotIn('This plant has ended and cannot be edited.', page)
        self.assertEqual(self.state(), before)
        sql('DROP TRIGGER c11_failure;')
        response = submit(); page = response.read().decode('utf-8')
        self.assertEqual(response.status, 200)
        self.assertIn('/Plants/Details', response.url)
        self.assertEqual(sql(f'SELECT plantName,plantNotes FROM plant WHERE plantId={self.plant};'), ['HTTP closed café\tHTTP saved notes'])
        reopened = opener.open(url, timeout=15).read().decode('utf-8')
        self.assertIn('This plant has ended and cannot be edited.', reopened)
        self.assertEqual(sql(f"SELECT COUNT(*) FROM plant p JOIN flowering f ON f.plantId=p.plantId JOIN plantlocationhistory l ON l.plantId=p.plantId WHERE p.plantId={self.plant} AND f.endDate=p.endDate AND l.endDateTime=p.endDate;"), ['1'])


if __name__ == '__main__':
    unittest.main(verbosity=2)
