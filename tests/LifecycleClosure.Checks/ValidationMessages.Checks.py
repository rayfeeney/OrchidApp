"""Field errors must be readable after real rejected plant-event POSTs.

Run through Database.Checks.ps1 on its generated schema-only/upgraded databases.
No collection, private .env, or historical specimen is used.
"""
from checks import sql
from datetime import date, timedelta
import html
import http.cookiejar
import os
import re
import unittest
import urllib.parse
import urllib.request
import uuid


class ValidationMessages(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.base = os.environ['C11_TEST_WEB_URL']
        name = 'Validation messages ' + uuid.uuid4().hex[:10]
        sql(f"CALL spAddGenus('{name}','Synthetic HTTP fixture'); "
            f"INSERT INTO location(locationName) VALUES('{name}'); "
            f"INSERT INTO growthmedium(name) VALUES('{name}');")
        cls.taxon = int(sql(f"SELECT t.taxonId FROM taxon t JOIN genus g ON g.genusId=t.genusId WHERE g.genusName='{name}' AND t.isSystemManaged=1;")[0])
        cls.location = int(sql(f"SELECT locationId FROM location WHERE locationName='{name}';")[0])
        cls.medium = int(sql(f"SELECT growthMediumId FROM growthmedium WHERE name='{name}';")[0])

    def setUp(self):
        sql(f"CALL spAddPlant({self.taxon},'2020-01-01','fixture','Validation plant','fixture');")
        self.plant = int(sql('SELECT MAX(plantId) FROM plant;')[0])
        sql(f"CALL spMovePlantToLocation({self.plant},{self.location},'2020-02-01','fixture','fixture');")
        self.opener = urllib.request.build_opener(
            urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))

    def snapshot(self):
        result = []
        for table, key in [('plant', 'plantId'), ('plantevent', 'plantEventId'),
                           ('flowering', 'floweringId'), ('repotting', 'repottingId'),
                           ('plantlocationhistory', 'plantLocationHistoryId'),
                           ('plantphoto', 'plantPhotoId')]:
            result.extend(sql(f'SELECT * FROM {table} WHERE plantId={self.plant} ORDER BY {key};'))
        return result

    def post(self, kind, changes):
        path = self.base + f'/Plants/Events/Add/{self.plant}/{kind}'
        page = self.opener.open(path, timeout=20).read().decode()
        token = html.unescape(re.search(
            r'name="__RequestVerificationToken"[^>]*value="([^"]+)"', page).group(1))
        values = {'__RequestVerificationToken': token, 'EventDate': '2020-06-01',
                  'StartDate': '2020-06-01', 'EndDate': '', 'EventDetails': 'validation witness',
                  'LocationId': str(self.location), 'NewGrowthMediumId': str(self.medium),
                  'RepottingNotes': 'validation witness', **changes}
        response = self.opener.open(path, urllib.parse.urlencode(values).encode(), timeout=20)
        return response.status, response.read().decode(), response.url

    def field_error(self, page, field):
        match = re.search(r'<span\b[^>]*data-valmsg-for="' + re.escape(field) +
                          r'"[^>]*>(.*?)</span>', page, re.S)
        self.assertIsNotNone(match, 'Missing rendered field error for ' + field)
        return html.unescape(re.sub(r'<[^>]+>', '', match.group(1))).strip()

    def rejected(self, kind, values, field, message):
        before = self.snapshot()
        status, page, url = self.post(kind, values)
        self.assertEqual(status, 200)
        self.assertIn('/Plants/Events/Add/', url)
        self.assertEqual(self.snapshot(), before, 'Rejected input changed stored records')
        self.assertIn(message, self.field_error(page, field))

    def test_observation_date_messages(self):
        for value, message in [((date.today()+timedelta(days=1)).isoformat(), 'cannot be in the future'),
                               ('2019-12-31', 'before the plant was acquired')]:
            with self.subTest(value=value):
                self.rejected('Observation', {'EventDate': value}, 'EventDate', message)

    def test_move_date_messages(self):
        for value, message in [((date.today()+timedelta(days=1)).isoformat(), 'cannot be in the future'),
                               ('2019-12-31', 'before the plant was acquired')]:
            with self.subTest(value=value):
                self.rejected('LocationChange', {'EventDate': value}, 'EventDate', message)

    def test_flowering_start_messages(self):
        for value, message in [((date.today()+timedelta(days=1)).isoformat(), 'cannot be in the future'),
                               ('2019-12-31', 'before the plant was acquired')]:
            with self.subTest(value=value):
                self.rejected('Flowering', {'StartDate': value}, 'StartDate', message)

    def test_flowering_end_messages(self):
        for value, message in [('2020-05-31', 'before start date'),
                               ((date.today()+timedelta(days=1)).isoformat(), 'cannot be in the future')]:
            with self.subTest(value=value):
                self.rejected('Flowering', {'EndDate': value}, 'EndDate', message)

    def test_repotting_date_messages(self):
        for value, message in [((date.today()+timedelta(days=1)).isoformat(), 'cannot be in the future'),
                               ('2019-12-31', 'before the plant was acquired')]:
            with self.subTest(value=value):
                self.rejected('Repotting', {'EventDate': value}, 'EventDate', message)

    def test_repotting_missing_medium_message(self):
        self.rejected('Repotting', {'NewGrowthMediumId': ''}, 'NewGrowthMediumId',
                      'Please select a growth medium')

    def test_empty_observation_explains_what_to_enter(self):
        self.rejected('Observation', {'EventDetails': ''}, 'EventDetails',
                      'Please enter some notes or choose an observation type')

    def test_binding_error_is_visible_without_writes(self):
        before = self.snapshot()
        status, page, _ = self.post('Observation', {'EventDate': 'not-a-date'})
        self.assertEqual(status, 200)
        self.assertEqual(self.snapshot(), before)
        self.assertTrue(self.field_error(page, 'EventDate'))

    def test_correction_after_rejection_saves_and_reopens(self):
        cases = [('Observation', {'EventDate': (date.today()+timedelta(days=1)).isoformat()}, 'plantevent', 'eventDetails'),
                 ('Flowering', {'EndDate': '2020-05-31'}, 'flowering', 'floweringNotes'),
                 ('Repotting', {'NewGrowthMediumId': ''}, 'repotting', 'repottingNotes')]
        for kind, invalid, table, notes in cases:
            with self.subTest(kind=kind):
                before = self.snapshot()
                self.post(kind, invalid)
                self.assertEqual(self.snapshot(), before)
                status, _, url = self.post(kind, {})
                self.assertEqual(status, 200)
                self.assertIn(f'/Plants/Details/{self.plant}', url)
                self.assertEqual(sql(f"SELECT COUNT(*) FROM {table} WHERE plantId={self.plant} AND {notes}='validation witness';"), ['1'])
                self.assertEqual(self.opener.open(url, timeout=20).status, 200)


if __name__ == '__main__':
    unittest.main(verbosity=2)
