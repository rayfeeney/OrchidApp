"""Exact MariaDB schema metadata for the reviewed historical fixture.

No SQL literal/whitespace/collation/index-name normalisation is accepted here.
Data, auto-increment counters and object creation times are intentionally not schema.
"""
import hashlib
import json

def snapshot(query):
    result = {}
    queries = {
        'database': "SELECT DEFAULT_CHARACTER_SET_NAME,DEFAULT_COLLATION_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME='orchids'",
        'tables': "SELECT TABLE_NAME,ENGINE,TABLE_COLLATION,CREATE_OPTIONS,TABLE_COMMENT FROM information_schema.TABLES WHERE TABLE_SCHEMA='orchids' AND TABLE_TYPE='BASE TABLE' ORDER BY TABLE_NAME",
        'columns': "SELECT TABLE_NAME,ORDINAL_POSITION,COLUMN_NAME,COLUMN_TYPE,IS_NULLABLE,IFNULL(HEX(COLUMN_DEFAULT),'NULL'),EXTRA,IFNULL(CHARACTER_SET_NAME,''),IFNULL(COLLATION_NAME,''),HEX(COLUMN_COMMENT),IFNULL(HEX(GENERATION_EXPRESSION),'') FROM information_schema.COLUMNS WHERE TABLE_SCHEMA='orchids' ORDER BY TABLE_NAME,ORDINAL_POSITION",
        'indexes': "SELECT TABLE_NAME,INDEX_NAME,NON_UNIQUE,SEQ_IN_INDEX,IFNULL(COLUMN_NAME,''),IFNULL(SUB_PART,0),IFNULL(COLLATION,''),INDEX_TYPE,INDEX_COMMENT FROM information_schema.STATISTICS WHERE TABLE_SCHEMA='orchids' ORDER BY TABLE_NAME,INDEX_NAME,SEQ_IN_INDEX",
        'foreignKeys': "SELECT TABLE_NAME,CONSTRAINT_NAME,COLUMN_NAME,ORDINAL_POSITION,REFERENCED_TABLE_NAME,REFERENCED_COLUMN_NAME FROM information_schema.KEY_COLUMN_USAGE WHERE TABLE_SCHEMA='orchids' AND REFERENCED_TABLE_NAME IS NOT NULL ORDER BY TABLE_NAME,CONSTRAINT_NAME,ORDINAL_POSITION",
        'referentialRules': "SELECT TABLE_NAME,CONSTRAINT_NAME,MATCH_OPTION,UPDATE_RULE,DELETE_RULE FROM information_schema.REFERENTIAL_CONSTRAINTS WHERE CONSTRAINT_SCHEMA='orchids' ORDER BY TABLE_NAME,CONSTRAINT_NAME",
        'checks': "SELECT TABLE_NAME,CONSTRAINT_NAME,HEX(CHECK_CLAUSE) FROM information_schema.CHECK_CONSTRAINTS WHERE CONSTRAINT_SCHEMA='orchids' ORDER BY TABLE_NAME,CONSTRAINT_NAME",
        'views': "SELECT TABLE_NAME,HEX(VIEW_DEFINITION),CHECK_OPTION,IS_UPDATABLE,SECURITY_TYPE,CHARACTER_SET_CLIENT,COLLATION_CONNECTION,ALGORITHM,DEFINER FROM information_schema.VIEWS WHERE TABLE_SCHEMA='orchids' ORDER BY TABLE_NAME",
        'routines': "SELECT ROUTINE_NAME,ROUTINE_TYPE,DTD_IDENTIFIER,HEX(ROUTINE_DEFINITION),IS_DETERMINISTIC,SQL_DATA_ACCESS,SECURITY_TYPE,SQL_MODE,CHARACTER_SET_CLIENT,COLLATION_CONNECTION,DATABASE_COLLATION,DEFINER FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA='orchids' ORDER BY ROUTINE_NAME",
        'parameters': "SELECT SPECIFIC_NAME,ORDINAL_POSITION,IFNULL(PARAMETER_MODE,''),IFNULL(PARAMETER_NAME,''),DTD_IDENTIFIER,IFNULL(CHARACTER_SET_NAME,''),IFNULL(COLLATION_NAME,'') FROM information_schema.PARAMETERS WHERE SPECIFIC_SCHEMA='orchids' ORDER BY SPECIFIC_NAME,ORDINAL_POSITION",
        'triggers': "SELECT TRIGGER_NAME,EVENT_MANIPULATION,EVENT_OBJECT_TABLE,ACTION_ORDER,HEX(ACTION_STATEMENT),ACTION_ORIENTATION,ACTION_TIMING,SQL_MODE,CHARACTER_SET_CLIENT,COLLATION_CONNECTION,DATABASE_COLLATION,DEFINER FROM information_schema.TRIGGERS WHERE TRIGGER_SCHEMA='orchids' ORDER BY TRIGGER_NAME",
        'partitions': "SELECT TABLE_NAME,IFNULL(PARTITION_NAME,''),IFNULL(SUBPARTITION_NAME,''),IFNULL(PARTITION_METHOD,''),IFNULL(SUBPARTITION_METHOD,''),IFNULL(PARTITION_EXPRESSION,''),IFNULL(SUBPARTITION_EXPRESSION,''),IFNULL(PARTITION_DESCRIPTION,'') FROM information_schema.PARTITIONS WHERE TABLE_SCHEMA='orchids' ORDER BY TABLE_NAME,PARTITION_ORDINAL_POSITION,SUBPARTITION_ORDINAL_POSITION",
        'events': "SELECT EVENT_NAME,HEX(EVENT_DEFINITION),EVENT_TYPE,IFNULL(INTERVAL_VALUE,''),IFNULL(INTERVAL_FIELD,''),STATUS,SQL_MODE FROM information_schema.EVENTS WHERE EVENT_SCHEMA='orchids' ORDER BY EVENT_NAME",
    }
    for key, sql in queries.items():
        result[key] = query(sql+';').splitlines()
    return result


def checksum(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(',', ':'), ensure_ascii=True).encode()).hexdigest()


def identity(value):
    return {key: {'rows': len(rows), 'sha256': checksum(rows)} for key, rows in value.items()}


def require_schema(value, expected):
    actual = identity(value)
    if actual != expected:
        changed = sorted(k for k in set(actual) | set(expected) if actual.get(k) != expected.get(k))
        raise ValueError('Historical schema differs from reviewed contract: '+', '.join(changed))
    return checksum(value)


def application_schema(value):
    # Ledger retention/marker contents have their own exact verification. Only
    # their table metadata is excluded from the post-upgrade application schema.
    ledger_tables = {'schemaversion', 'schemaversion_legacy_pi_130'}
    table_categories = {'tables', 'columns', 'indexes', 'foreignKeys', 'referentialRules', 'checks', 'partitions'}
    return {key: [row for row in rows if key not in table_categories or
                  row.split('\t')[0] not in ledger_tables] for key, rows in value.items()}
