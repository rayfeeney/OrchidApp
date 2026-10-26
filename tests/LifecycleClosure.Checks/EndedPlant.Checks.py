"""C12 normal HTTP write policy and active-plant date corrections on native MariaDB."""
from checks import sql
from datetime import date,timedelta
import hashlib
import html
import http.cookiejar
import os
from pathlib import Path
import re
import unittest
import urllib.error
import urllib.parse
import urllib.request


class EndedPlant(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.base=os.environ['C11_TEST_WEB_URL']
        sql("CALL spAddGenus('C12 fixture','Synthetic'); INSERT INTO location(locationName) VALUES('C12 fixture'); INSERT INTO growthmedium(name) VALUES('C12 fixture');")
        cls.taxon=int(sql('SELECT MIN(taxonId) FROM taxon;')[0])
        cls.genus=int(sql(f'SELECT genusId FROM taxon WHERE taxonId={cls.taxon};')[0])
        cls.location=int(sql("SELECT locationId FROM location WHERE locationName='C12 fixture';")[0])
        cls.medium=int(sql("SELECT growthMediumId FROM growthmedium WHERE name='C12 fixture';")[0])

    def plant(self):
        sql(f"CALL spAddPlant({self.taxon},'2020-01-01','fixture','C12 plant','fixture');")
        return int(sql('SELECT MAX(plantId) FROM plant;')[0])

    def setUp(self):
        self.p=self.plant();self.other=self.plant()
        sql(f"INSERT INTO plantevent(plantId,eventDateTime,eventDetails,observationTypeId) VALUES({self.p},'2020-03-01 08:09:10','C12 observation',(SELECT Id FROM observationtype WHERE typeCode='OBS_PHOTO')); "
            f"INSERT INTO repotting(plantId,repotDate,newGrowthMediumId) VALUES({self.p},'2020-04-01 11:12:13',{self.medium}); "
            f"INSERT INTO flowering(plantId,startDate,endDate) VALUES({self.p},'2020-05-01 14:15:16','2020-05-03 17:18:19'); "
            f"INSERT INTO plantlocationhistory(plantId,locationId,startDateTime) VALUES({self.p},{self.location},'2020-02-01 19:20:21');")
        self.ids={kind:int(sql(f'SELECT MAX({key}) FROM {table} WHERE plantId={self.p};')[0]) for kind,table,key in
                  [('Observation','plantevent','plantEventId'),('Repotting','repotting','repottingId'),('Flowering','flowering','floweringId'),('LocationChange','plantlocationhistory','plantLocationHistoryId')]}
        sql(f"INSERT INTO plantphoto(plantId,plantEventId,fileName,thumbnailFileName,mimeType,isHero) VALUES({self.p},{self.ids['Observation']},'photo.jpg','thumb.jpg','image/jpeg',1);")
        self.photo=int(sql(f'SELECT MAX(plantPhotoId) FROM plantphoto WHERE plantId={self.p};')[0])
        self.folder=Path(os.environ['Storage__UploadRoot'])/'plants'/str(self.p)
        self.folder.mkdir(parents=True)
        for name in ('photo.jpg','thumb.jpg'):(self.folder/name).write_bytes(b'C12 synthetic photo')
        self.opener=urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
        page=self.opener.open(self.base+f'/Plants/Edit/{self.p}').read().decode()
        self.token=html.unescape(re.search(r'name="__RequestVerificationToken"[^>]*value="([^"]+)"',page).group(1))

    def close(self):
        sql(f"CALL spUpdatePlantDetails({self.p},{self.taxon},'C12 plant','2020-01-01','fixture','2021-03-01','end','fixture');")

    def snapshot(self):
        rows=[]
        for table,key in [('plant','plantId'),('plantevent','plantEventId'),('repotting','repottingId'),('flowering','floweringId'),('plantlocationhistory','plantLocationHistoryId'),('plantphoto','plantPhotoId')]:
            rows+=sql(f'SELECT * FROM {table} WHERE plantId={self.p} ORDER BY {key};')
        return rows,{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in self.folder.iterdir()}

    def post(self,path,values=None):
        data={'__RequestVerificationToken':self.token,**(values or {})}
        try:
            response=self.opener.open(self.base+path,urllib.parse.urlencode(data).encode(),timeout=15)
            return response.status,response.read().decode(),response.url
        except urllib.error.HTTPError as error:
            return error.code,error.read().decode(),error.url

    def event(self,action,kind,plant=None):
        return f'/Plants/Events/{action}/{plant or self.p}/{self.ids[kind]}?eventType={kind}'

    def test_all_event_add_types_refuse_ended_plant(self):
        self.close();before=self.snapshot()
        for kind in self.ids:
            with self.subTest(kind=kind):
                self.assertEqual(self.post(f'/Plants/Events/Add/{self.p}/{kind}',{'EventDate':'2020-06-01','EventDetails':'attempt'})[0],400)
                self.assertEqual(self.snapshot(),before)

    def test_all_event_edit_types_refuse_ended_plant(self):
        self.close();before=self.snapshot()
        for kind in self.ids:
            with self.subTest(kind=kind):
                self.assertEqual(self.post(self.event('Edit',kind),{'EventDate':'2020-06-01','EventDetails':'attempt'})[0],400)
                self.assertEqual(self.snapshot(),before)

    def test_all_event_remove_types_refuse_ended_plant(self):
        self.close();before=self.snapshot()
        for kind in self.ids:
            with self.subTest(kind=kind):
                self.assertEqual(self.post(self.event('Remove',kind))[0],400)
                self.assertEqual(self.snapshot(),before)

    def test_details_taxonomy_photo_posts_refuse_ended_plant(self):
        self.close();before=self.snapshot()
        paths=[f'/Plants/Edit/{self.p}',f'/Plants/Edit/{self.p}?handler=GenusChanged',f'/Plants/Edit/{self.p}?handler=TaxonChanged',
               f'/Plants/Photos/{self.p}?handler=SetHero',f'/Plants/Photos/{self.p}?handler=Upload']
        for path in paths:
            with self.subTest(path=path):
                self.assertEqual(self.post(path,{'PlantId':self.p,'GenusId':self.genus,'TaxonId':self.taxon,'photoId':self.photo})[0],400)
                self.assertEqual(self.snapshot(),before)

    def test_ended_details_and_photos_stay_viewable(self):
        self.close();before=self.snapshot()
        for path in (f'/Plants/Details/{self.p}',f'/Plants/Edit/{self.p}',f'/Plants/Photos/{self.p}'):
            with self.subTest(path=path):self.assertEqual(self.opener.open(self.base+path).status,200)
        for kind in self.ids:
            for action in ('Edit','Remove'):
                self.assertIn('/Plants/Details',self.opener.open(self.base+self.event(action,kind)).url)
            self.assertIn('/Plants/Details',self.opener.open(self.base+f'/Plants/Events/Add/{self.p}/{kind}').url)
        self.assertEqual(self.snapshot(),before)

    def test_ended_split_and_propagation_cannot_create_descendants(self):
        self.close();before=self.snapshot();count=sql('SELECT COUNT(*) FROM plant;')
        for path in (f'/Plants/Events/Split/{self.p}?handler=AddChild',f'/Plants/Events/Split/{self.p}?handler=Split',f'/Plants/Events/Propagate/{self.p}'):
            with self.subTest(path=path):
                status,page,_=self.post(path,{'ChildCount':2})
                self.assertIn(status,(200,400))
                self.assertTrue('read-only' in page or 'no longer' in page)
                self.assertEqual(self.snapshot(),before)
                self.assertEqual(sql('SELECT COUNT(*) FROM plant;'),count)

    def test_other_parent_id_cannot_bypass_edit_or_remove(self):
        self.close();before=self.snapshot()
        for kind in self.ids:
            for action in ('Edit','Remove'):
                with self.subTest(kind=kind,action=action):
                    status,_,_=self.post(self.event(action,kind,self.other),{'EventDate':'2020-06-01','EventDetails':'spoof'})
                    self.assertEqual(status,404)
                    self.assertEqual(self.snapshot(),before)

    def test_repotting_rejects_future_and_pre_acquisition_dates(self):
        before=self.snapshot()
        for day in ('2019-12-31',(date.today()+timedelta(days=10)).isoformat()):
            status,page,_=self.post(self.event('Edit','Repotting'),{'EventDate':day,'NewGrowthMediumId':self.medium})
            self.assertEqual(status,200)
            self.assertIn('date cannot be',page)
            self.assertEqual(self.snapshot(),before)

    def test_repotting_correction_preserves_time_and_persists(self):
        status,_,url=self.post(self.event('Edit','Repotting'),{'EventDate':'2020-04-02','NewGrowthMediumId':self.medium,'RepottingNotes':'corrected'})
        self.assertEqual(status,200);self.assertIn('/Plants/Details',url)
        self.assertEqual(sql(f'SELECT repotDate,repottingNotes FROM repotting WHERE repottingId={self.ids["Repotting"]};'),['2020-04-02 11:12:13\tcorrected'])

    def test_repotting_acquisition_calendar_day_is_allowed(self):
        status,_,url=self.post(self.event('Edit','Repotting'),{'EventDate':'2020-01-01','NewGrowthMediumId':self.medium})
        self.assertEqual(status,200);self.assertIn('/Plants/Details',url)
        self.assertEqual(sql(f'SELECT repotDate FROM repotting WHERE repottingId={self.ids["Repotting"]};'),['2020-01-01 11:12:13'])

    def test_unknown_acquisition_allows_past_repotting(self):
        sql(f'UPDATE plant SET acquisitionDate=NULL WHERE plantId={self.p};')
        status,_,url=self.post(self.event('Edit','Repotting'),{'EventDate':'1900-01-01','NewGrowthMediumId':self.medium})
        self.assertEqual(status,200);self.assertIn('/Plants/Details',url)
        self.assertEqual(sql(f'SELECT repotDate FROM repotting WHERE repottingId={self.ids["Repotting"]};'),['1900-01-01 11:12:13'])

    def test_flowering_correction_preserves_both_times(self):
        status,_,url=self.post(self.event('Edit','Flowering'),{'EventDate':'2020-05-02','EndDate':'2020-05-04','EventDetails':'corrected'})
        self.assertEqual(status,200);self.assertIn('/Plants/Details',url)
        self.assertEqual(sql(f'SELECT startDate,endDate FROM flowering WHERE floweringId={self.ids["Flowering"]};'),['2020-05-02 14:15:16\t2020-05-04 17:18:19'])

    def test_open_flowering_cannot_overlap_later_existing_period(self):
        before=self.snapshot()
        sql(f"INSERT INTO flowering(plantId,startDate,endDate) VALUES({self.p},'2020-08-01','2020-08-03');")
        status,page,_=self.post(self.event('Edit','Flowering'),{'EventDate':'2020-05-01','EndDate':''})
        self.assertEqual(status,200);self.assertIn('overlaps an existing',page)
        self.assertEqual(sql(f'SELECT endDate FROM flowering WHERE floweringId={self.ids["Flowering"]};'),['2020-05-03 17:18:19'])

    def test_location_correction_preserves_time(self):
        status,_,url=self.post(self.event('Edit','LocationChange'),{'EventDate':'2020-02-02','EventDetails':'corrected'})
        self.assertEqual(status,200);self.assertIn('/Plants/Details',url)
        self.assertEqual(sql(f'SELECT startDateTime FROM plantlocationhistory WHERE plantLocationHistoryId={self.ids["LocationChange"]};'),['2020-02-02 19:20:21'])

    def test_photo_upload_refuses_imported_future_acquisition(self):
        future=(date.today()+timedelta(days=10)).isoformat()
        sql(f"UPDATE plant SET acquisitionDate='{future}' WHERE plantId={self.p};")
        before=self.snapshot()
        status,_,_=self.post(f'/Plants/Photos/{self.p}?handler=Upload')
        self.assertEqual(status,400);self.assertEqual(self.snapshot(),before)

    def test_propagation_origin_date_cannot_change(self):
        sql(f"INSERT INTO plantpropagation(parentPlantId,childPlantId,propagationTypeId,propagationDateTime) VALUES({self.other},{self.p},(SELECT MIN(propagationTypeId) FROM propagationtype),'2020-01-01 10:11:12');")
        before=self.snapshot()
        sql(f"CALL spUpdatePlantDetails({self.p},{self.taxon},'C12','2020-01-02','fixture',NULL,NULL,NULL);",error='Cannot modify acquisition date: plant was created via propagation.')
        self.assertEqual(self.snapshot(),before)


if __name__=='__main__':unittest.main(verbosity=2)
