"""C14 actual MariaDB/Details-page ordering; run only in the owned lifecycle fixture."""
from checks import sql
from html.parser import HTMLParser
import html
import http.cookiejar
import os
import re
import unittest
import urllib.parse
import urllib.request


class Summaries(HTMLParser):
    def __init__(self):
        super().__init__();self.depth=0;self.current=[];self.items=[]

    def handle_starttag(self, tag, attrs):
        if self.depth:self.depth+=1
        elif 'event-summary' in dict(attrs).get('class','').split():
            self.depth=1;self.current=[]

    def handle_data(self, text):
        if self.depth:self.current.append(text)

    def handle_endtag(self, tag):
        if self.depth:
            self.depth-=1
            if not self.depth:self.items.append(''.join(self.current).strip())


class HistoryOrdering(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.base=os.environ['C11_TEST_WEB_URL']
        sql("CALL spAddGenus('C14 fixture','Synthetic'); INSERT INTO location(locationName) VALUES('C14 fixture'); INSERT INTO growthmedium(name) VALUES('C14 fixture');")
        cls.taxon=int(sql('SELECT MIN(taxonId) FROM taxon;')[0])
        cls.location=int(sql("SELECT locationId FROM location WHERE locationName='C14 fixture';")[0])
        cls.medium=int(sql("SELECT growthMediumId FROM growthmedium WHERE name='C14 fixture';")[0])

    def setUp(self):
        sql(f"CALL spAddPlant({self.taxon},'2020-01-01','fixture','C14 plant','fixture');")
        self.p=int(sql('SELECT MAX(plantId) FROM plant;')[0])
        self.id=max(int(sql(f'SELECT COALESCE(MAX({key}),0) FROM {table};')[0]) for table,key in
            [('flowering','floweringId'),('plantlocationhistory','plantLocationHistoryId'),('plantevent','plantEventId'),('repotting','repottingId')])+100
        # Equal IDs in separate tables are intentional: SourceId is table-local.
        sql(f"INSERT INTO flowering(floweringId,plantId,startDate,endDate,floweringNotes) VALUES({self.id},{self.p},'2020-06-01 12:34:56','2020-06-02 12:34:56','C14_F'); "
            f"INSERT INTO plantlocationhistory(plantLocationHistoryId,plantId,locationId,startDateTime,endDateTime,moveReasonNotes) VALUES({self.id},{self.p},{self.location},'2020-06-01 12:34:56','2020-06-02 12:34:56','C14_M'); "
            f"INSERT INTO plantevent(plantEventId,plantId,eventDateTime,observationTypeId,eventDetails) VALUES({self.id},{self.p},'2020-06-01 12:34:56',(SELECT Id FROM observationtype WHERE typeCode='OBS_PHOTO'),'C14_O'); "
            f"INSERT INTO repotting(repottingId,plantId,repotDate,newGrowthMediumId,repottingNotes) VALUES({self.id},{self.p},'2020-06-01 12:34:56',{self.medium},'C14_R');")

    def page(self):
        with urllib.request.urlopen(self.base+f'/Plants/Details/{self.p}',timeout=20) as response:
            self.assertEqual(response.status,200)
            parser=Summaries();parser.feed(response.read().decode())
        return [re.search(r'C14_[A-Z0-9_]+',text).group() for text in parser.items]

    def snapshot(self):
        return {table:sql(f'SELECT * FROM {table} WHERE plantId={self.p} ORDER BY 1;') for table in
            ['plant','flowering','plantlocationhistory','plantevent','repotting']}

    def observation(self, offset, marker):
        sql(f"INSERT INTO plantevent(plantEventId,plantId,eventDateTime,observationTypeId,eventDetails) VALUES({self.id+offset},{self.p},'2020-06-01 12:34:56',(SELECT Id FROM observationtype WHERE typeCode='OBS_PHOTO'),'{marker}');")

    def test_equal_timestamps_and_equal_ids_sort_by_type(self):
        self.assertEqual(self.page(),['C14_F','C14_M','C14_O','C14_R'])

    def test_event_type_precedes_a_higher_cross_table_id(self):
        self.observation(100,'C14_O2')
        self.assertEqual(self.page(),['C14_F','C14_M','C14_O2','C14_O','C14_R'])

    def test_newest_timestamp_precedes_event_type(self):
        sql(f"UPDATE repotting SET repotDate='2020-06-01 12:34:57' WHERE plantId={self.p};")
        self.assertEqual(self.page(),['C14_R','C14_F','C14_M','C14_O'])
        sql(f"UPDATE flowering SET startDate='2020-05-31 12:34:56' WHERE plantId={self.p};")
        self.assertEqual(self.page(),['C14_R','C14_M','C14_O','C14_F'])

    def test_same_date_different_times_are_not_grouped_by_type(self):
        sql(f"UPDATE repotting SET repotDate='2020-06-01 18:00:00' WHERE plantId={self.p}; UPDATE flowering SET startDate='2020-06-01 08:00:00' WHERE plantId={self.p};")
        self.assertEqual(self.page(),['C14_R','C14_M','C14_O','C14_F'])

    def test_same_type_uses_descending_record_id(self):
        self.observation(1,'C14_O2');self.observation(2,'C14_O3')
        self.assertEqual(self.page(),['C14_F','C14_M','C14_O3','C14_O2','C14_O','C14_R'])

    def test_repeated_reads_keep_order_and_do_not_rewrite_rows(self):
        before=self.snapshot()
        for _ in range(3):self.assertEqual(self.page(),['C14_F','C14_M','C14_O','C14_R'])
        self.assertEqual(self.snapshot(),before)

    def test_actual_date_correction_repositions_card_and_preserves_time(self):
        opener=urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
        path=f'/Plants/Events/Edit/{self.p}/{self.id}?eventType=Observation'
        page=opener.open(self.base+path).read().decode()
        token=html.unescape(re.search(r'name="__RequestVerificationToken"[^>]*value="([^"]+)"',page).group(1))
        for when,expected in [('2020-06-02',['C14_O','C14_F','C14_M','C14_R']),('2020-06-01',['C14_F','C14_M','C14_O','C14_R'])]:
            data=urllib.parse.urlencode({'__RequestVerificationToken':token,'EventDate':when,'EventDetails':'C14_O'}).encode()
            with opener.open(self.base+path,data,timeout=20) as response:self.assertEqual(response.status,200)
            self.assertEqual(self.page(),expected)
            self.assertEqual(sql(f'SELECT TIME(eventDateTime) FROM plantevent WHERE plantEventId={self.id};'),['12:34:56'])

    def test_repeated_clock_hour_uses_stored_wall_time_and_type(self):
        # DATETIME has no UTC offset/fold. Equal stored values must use the
        # agreed display tie-breaker; no absolute chronology can be reconstructed.
        sql(f"UPDATE flowering SET startDate='2025-10-26 01:30:00',endDate='2025-10-27 01:30:00' WHERE plantId={self.p}; "
            f"UPDATE plantlocationhistory SET startDateTime='2025-10-26 01:30:00',endDateTime='2025-10-27 01:30:00' WHERE plantId={self.p}; "
            f"UPDATE plantevent SET eventDateTime='2025-10-26 01:30:00' WHERE plantId={self.p}; "
            f"UPDATE repotting SET repotDate='2025-10-26 01:30:00' WHERE plantId={self.p};")
        before=self.snapshot();self.assertEqual(self.page(),['C14_F','C14_M','C14_O','C14_R'])
        self.assertEqual(self.snapshot(),before)

    def test_ended_history_has_the_same_display_order(self):
        sql(f"CALL spUpdatePlantDetails({self.p},{self.taxon},'C14 plant','2020-01-01','fixture','2021-03-01','end','fixture');")
        before=self.snapshot();self.assertEqual(self.page(),['C14_F','C14_M','C14_O','C14_R'])
        self.assertEqual(self.snapshot(),before)

    def test_inactive_records_and_other_plants_do_not_enter_the_order(self):
        self.observation(1,'C14_HIDDEN')
        sql(f"UPDATE plantevent SET isActive=0 WHERE plantEventId={self.id+1}; CALL spAddPlant({self.taxon},'2020-01-01','fixture','C14 other','fixture'); "
            "INSERT INTO plantevent(plantId,eventDateTime,observationTypeId,eventDetails) VALUES((SELECT MAX(plantId) FROM plant),'2020-06-01 12:34:56',(SELECT Id FROM observationtype WHERE typeCode='OBS_PHOTO'),'C14_OTHER');")
        self.assertEqual(self.page(),['C14_F','C14_M','C14_O','C14_R'])


if __name__=='__main__':unittest.main(verbosity=2)
