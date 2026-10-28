"""Audited history rollover ONLY for the new, isolated reviewed specimen restore.

The canonical runner and its checksum policy are unchanged. This is not a live
database repair command; the caller must prove Docker ownership and exact input.
"""
from schema_contract import checksum, require_schema

ARCHIVE = 'schemaversion_legacy_pi_130'
STAGING = '_schemaversion_adopting_pi130'
HISTORY_SQL = ('SELECT versionId,HEX(scriptName),HEX(checksum),appliedAt '
               'FROM orchids.schemaversion ORDER BY versionId;')


def adopt(query, schema, contract, manifest, prove_owned):
    prove_owned()
    if (contract['formatVersion'] != 1 or contract['scope'] != 'owned-disposable-fixture-only' or
            contract['fixtureSha256'] != manifest['sha256'] or
            contract['originalHistorySha256'] != manifest['historySha256'] or
            contract['throughMigration'] != '202606041820'):
        raise ValueError('Unsupported historical adoption contract or input identity')
    schema_hash = require_schema(schema, contract['schemaIdentity'])
    if schema_hash != contract['schemaSha256']:
        raise ValueError('Historical schema hash differs')
    import hashlib
    before = query(HISTORY_SQL)
    if hashlib.sha256(before.encode()).hexdigest() != contract['originalHistorySha256']:
        raise ValueError('Historical ledger differs; adoption refused')
    # Prove the private restore has no earlier/partial adoption or added objects.
    if query("SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA='orchids' "
             f"AND TABLE_NAME IN ('{ARCHIVE}','{STAGING}');").strip() != '0':
        raise ValueError('Previous/partial adoption objects require review')
    contract_hash = checksum(contract)
    prove_owned()
    # DDL is deliberately staged before a single atomic table-name switch. The
    # original ledger table and all original IDs/checksums/timestamps survive.
    # A stopped/failed fixture is discarded, never automatically repaired/retried.
    query(f"CREATE TABLE orchids.`{STAGING}` LIKE orchids.schemaversion;")
    query(f"ALTER TABLE orchids.`{STAGING}` COMMENT='Reviewed fixture adoption {contract_hash}';")
    marker = 'baseline:v1:'+contract['throughMigration']
    query(f"INSERT INTO orchids.`{STAGING}`(scriptName,checksum) VALUES ('{marker}','{contract_hash}');")
    # Recheck immediately before retiring the old ledger. No application or
    # external client is permitted in this network-none unbound fixture.
    prove_owned()
    if query(HISTORY_SQL) != before:
        raise ValueError('Ledger changed while staging adoption')
    query(f"RENAME TABLE orchids.schemaversion TO orchids.`{ARCHIVE}`, "
          f"orchids.`{STAGING}` TO orchids.schemaversion;")
    archived = query(HISTORY_SQL.replace('orchids.schemaversion', f'orchids.`{ARCHIVE}`'))
    if archived != before:
        raise ValueError('Original ledger archive verification failed')
    if query('SELECT scriptName,checksum FROM orchids.schemaversion;').strip() != marker+'\t'+contract_hash:
        raise ValueError('Adoption marker verification failed')
    return {'status': 'adopted', 'contractSha256': contract_hash, 'schemaSha256': schema_hash,
            'marker': marker, 'originalHistorySha256': contract['originalHistorySha256'],
            'archiveTable': ARCHIVE, 'originalRowsPreserved': len(before.splitlines()),
            'originalLedgerUnchanged': True, 'retiredLocalEntry': contract['retiredLocalEntry'],
            'scope': contract['scope']}
