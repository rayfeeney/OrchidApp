"""Explicit target-only policy for the owner's six EnergyMonitoring views.

Never rewrites dump bytes, imports source accounts or changes the source server.
Only call inside the newly owned disposable candidate after identity verification.
"""
import json
import re
import secrets
from pathlib import Path
import shutil

import standby_database as d

b = d.b
POLICY = 'energy-six-v1'
SOURCE = 'root@192.168.7.153'
TARGET = 'standby_energy_views@localhost'
VIEWS = frozenset(('vw_Tariff', 'vw_MonitoringDeviceLocation', 'vw_GoveeHourly',
                   'vw_EnphaseHourly', 'vw_TapoHourly', 'vw_WeatherHourly'))
ENPHASE_COLUMNS = ('IntervalStartUtc', 'IntervalStart', 'ProducedWh', 'ConsumedWh',
                   'ImportedWh', 'ExportedWh', 'ChargedWh', 'DischargedWh', 'BatterySocPct',
                   'IntervalCount', 'TariffId', 'ImportRatePencePerKWh', 'ImportCostGBP',
                   'ExportRatePencePerKWh', 'ExportIncomeGBP')


def columns(c, native, name):
    b.require(name in VIEWS, 'Unapproved view column request')
    rows = d.query(c, native, "SELECT HEX(COLUMN_NAME) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA="
                   "'EnergyMonitoring' AND TABLE_NAME='" + name + "' ORDER BY ORDINAL_POSITION;")
    return [bytes.fromhex(row).decode('utf-8') for row in rows]


def timezone_values(c, native):
    return d.query(c, native, "SELECT CONVERT_TZ('2026-01-15 12:00:00','UTC','Europe/London'),"
                   "CONVERT_TZ('2026-07-15 12:00:00','UTC','Europe/London');")


def timezones(c, native, process):
    expected = ['2026-01-15 12:00:00\t2026-07-15 13:00:00']
    d.identity(c, native, process)
    if timezone_values(c, native) == expected:
        return {'source': 'candidate tables already valid', 'winter_summer_checks': True}
    # Populate only this new candidate's two required IANA zones, not source mysql.
    tool = shutil.which('mariadb-tzinfo-to-sql')
    b.require(tool, 'Required MariaDB timezone import tool missing')
    inputs = {}
    for name, relative in (('UTC', 'Etc/UTC'), ('Europe/London', 'Europe/London')):
        path = Path('/usr/share/zoneinfo') / relative
        b.require(path.is_file(), 'Required target timezone data missing: ' + name)
        for part in (path.resolve(), *path.resolve().parents):
            info = part.stat()
            b.require(info.st_uid == 0 and not info.st_mode & 0o022, 'Timezone data must be root owned and not writable by other users')
        before = b.digest(path)
        sql = b.run(c, [tool, str(path), name])
        b.require(sql and len(sql) <= 1024**2 and b.digest(path) == before, 'Invalid/changed target timezone input')
        d.identity(c, native, process)
        b.run(c, d.client(c, native) + ['--database=mysql'], stdin=sql)
        inputs[name] = before
    b.require(timezone_values(c, native) == expected, 'Candidate UTC/London winter/summer conversion failed')
    return {'source': 'target IANA zoneinfo', 'sha256': inputs, 'winter_summer_checks': True}


def identifier(value):
    return '`' + value.replace('`', '``') + '`'


def metadata(c, native):
    rows = d.query(c, native, "SELECT HEX(JSON_OBJECT('name',TABLE_NAME,'definition',VIEW_DEFINITION,"
                   "'definer',DEFINER,'security',SECURITY_TYPE,'check',CHECK_OPTION,'algorithm',ALGORITHM,"
                   "'charset',CHARACTER_SET_CLIENT,'collation',COLLATION_CONNECTION)) "
                   "FROM information_schema.VIEWS WHERE TABLE_SCHEMA='EnergyMonitoring' ORDER BY TABLE_NAME;")
    return [json.loads(bytes.fromhex(row).decode('utf-8')) for row in rows]


def alter_statement(view, columns):
    b.require(view['name'] in VIEWS and view['definer'] == SOURCE, 'View is outside approved definer policy')
    b.require(view['security'] in ('DEFINER', 'INVOKER') and view['check'] in ('NONE', 'LOCAL', 'CASCADED')
              and view['algorithm'] in ('UNDEFINED', 'MERGE', 'TEMPTABLE'), 'Unsupported view attributes')
    b.require(all(re.fullmatch(r'[A-Za-z0-9_]+', view[key]) for key in ('charset', 'collation')),
              'Unsupported view character settings')
    b.require(columns and isinstance(view['definition'], str) and view['definition'], 'Missing view definition/columns')
    # Use the server's stored SELECT unchanged; no textual search/replace in SQL.
    return ('SET NAMES ' + view['charset'] + ' COLLATE ' + view['collation'] + ';\n'
            'ALTER ALGORITHM=' + view['algorithm'] + " DEFINER='standby_energy_views'@'localhost' SQL SECURITY "
            + view['security'] + ' VIEW `EnergyMonitoring`.' + identifier(view['name'])
            + '(' + ','.join(identifier(column) for column in columns) + ') AS ' + view['definition']
            + ('' if view['check'] == 'NONE' else ' WITH ' + view['check'] + ' CHECK OPTION') + ';')


def apply(c, native, process, policy):
    b.require(policy == POLICY and 'EnergyMonitoring' in c['databases'], 'Unknown/inapplicable definer policy')
    d.identity(c, native, process)
    before = metadata(c, native)
    selected = [view for view in before if view['name'] in VIEWS]
    b.require(len(selected) == len(VIEWS) and {view['name'] for view in selected} == VIEWS
              and all(view['definer'] == SOURCE for view in selected), 'Expected six source view definers do not match')
    b.require(not any(view['definer'] == SOURCE and view['name'] not in VIEWS for view in before),
              'Unexpected additional source-definer view; policy review required')
    statements, original_columns = [], {}
    for view in selected:
        names = columns(c, native, view['name'])
        if not names and view['name'] == 'vw_EnphaseHourly':
            # Missing definer can hide derived-view columns. Use only the exact
            # owner-reviewed 15-column contract; verify it after ALTER below.
            names = list(ENPHASE_COLUMNS)
        original_columns[view['name']] = names
        statements.append(alter_statement(view, names))
    # No IF NOT EXISTS: a pre-existing account must never inherit or hide grants.
    d.identity(c, native, process)
    d.query(c, native, "CREATE USER 'standby_energy_views'@'localhost' IDENTIFIED BY '"
            + secrets.token_hex(32) + "' ACCOUNT LOCK; GRANT SELECT ON `EnergyMonitoring`.* "
            "TO 'standby_energy_views'@'localhost';")
    for statement in statements:
        d.identity(c, native, process)
        d.query(c, native, statement)
    after = metadata(c, native)
    expected = [dict(view, definer=TARGET) if view['name'] in VIEWS else view for view in before]
    b.require(after == expected, 'View metadata changed beyond approved definer mapping; candidate retained')
    for view in selected:
        d.identity(c, native, process)
        b.require(columns(c, native, view['name']) == original_columns[view['name']],
                  'View column contract differs after definer mapping; candidate retained')
        d.query(c, native, 'SELECT * FROM `EnergyMonitoring`.' + identifier(view['name']) + ' LIMIT 1;')
    return {'policy': POLICY, 'source_definer': SOURCE, 'target_definer': TARGET,
            'views': sorted(VIEWS), 'privileges': 'SELECT on EnergyMonitoring.*; account locked',
            'definition_and_attributes_preserved': True}
