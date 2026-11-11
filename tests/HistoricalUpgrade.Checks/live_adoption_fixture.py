"""Test the operational core ONLY inside preflight's new owned fixture.

The native session is transported into that guarded container. systemd is the
only prerequisite adapter; real service/mask acceptance remains a Pi/Linux task.
No target CLI and no changes to legacy_adoption's fixture-only guards.
"""
import importlib.util
import json
from pathlib import Path
import subprocess
from unittest.mock import patch

import preflight as p


def run(container, token, recovery_input, output):
    p.owned(container, token)
    spec = importlib.util.spec_from_file_location('operational_adoption', p.REPO/'database/scripts/adopt_pi130.py')
    a = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(a)
    contract = a.review()
    native_popen = subprocess.Popen

    def transport(command, **kwargs):
        p.owned(container, token)
        if command[0] != 'mariadb':
            raise ValueError('Unexpected fixture transport')
        return native_popen(['docker', 'exec', '-i', '--env', 'MYSQL_PWD='+p.PASSWORD,
                             container, *command], **kwargs)

    client = a.Client('/run/mysqld/mysqld.sock', popen=transport)
    def query(sql):
        p.owned(container, token)
        return client.query(sql)
    try:
        evidence = dict(formatVersion=1, contractSha256=a.CONTRACT_SHA, target=a.identity(query),
                        forwardMigrations=a.forward_inventory(contract), recoveryArchive=str(recovery_input.resolve()),
                        recoverySha256=a.digest(recovery_input), writerUnits=sorted(a.REQUIRED_WRITERS),
                        approvedBy='owned disposable fixture only', restoreTestEvidence='fixture input verified by preflight',
                        offDeviceEvidence='fixture input only; no production recovery assertion')
        for key in ('implementationApproved', 'allWritersIdentified', 'schedulersDisabled',
                    'administrativeAccessIsolated', 'recoverySetConsistent', 'restoreTestPassed', 'offDeviceCopyVerified'):
            evidence[key] = True
        query('CREATE VIEW orchids.ci_live_adoption_probe AS SELECT 1 AS witness;')
        try:
            a.inspect(query, contract)
        except ValueError as error:
            if 'schema differs' not in str(error): raise
        else:
            raise ValueError('Operational inspection accepted unreviewed schema')
        query('DROP VIEW orchids.ci_live_adoption_probe;')
        query('SET GLOBAL read_only=ON;')
        with patch.object(a, 'unit_stopped_masked'):
            # Actual lost connection after staging: tool must retain intent/staging,
            # classify interruption, and reject retry before any further write.
            def fail_after_create(sql):
                result = query(sql)
                if sql.startswith('CREATE TABLE'):
                    client.close()
                    raise RuntimeError('fixture injected lost response after CREATE')
                return result
            failed_journal = output/'operational-interrupted'
            try:
                a.apply(fail_after_create, contract, evidence, failed_journal)
            except RuntimeError as error:
                if 'fixture injected' not in str(error): raise
            else:
                raise ValueError('Interruption injection did not fail')
            # A new native session must observe the durable staging table; the
            # terminated session's advisory lock must not survive disconnect.
            client = a.Client('/run/mysqld/mysqld.sock', popen=transport)
            if query("SELECT GET_LOCK('orchidapp.pi130.adoption',0);").strip() != '1':
                raise ValueError('Disconnected adoption session retained its lock')
            competitor = a.Client('/run/mysqld/mysqld.sock', popen=transport)
            try:
                if competitor.query("SELECT GET_LOCK('orchidapp.pi130.adoption',0);").strip() != '0':
                    raise ValueError('Competing session acquired adoption lock')
            finally:
                competitor.close()
            if a.inspect(query, contract)['state'] != 'interrupted-staging':
                raise ValueError('Real staging interruption was not detected')
            try:
                a.apply(query, contract, evidence, output/'forbidden-retry')
            except ValueError:
                pass
            else:
                raise ValueError('Operational adoption allowed blind retry')
            # This is test-harness cleanup of its own disposable staging object,
            # never an operational recovery command or automatic live retry.
            p.owned(container, token)
            query(f'DROP TABLE orchids.`{a.STAGING}`;')
            result = a.apply(query, contract, evidence, output/'operational-verified')
        if result['state'] != 'adopted':
            raise ValueError('Operational post-swap inspection failed')
        result.update(marker=a.MARKER, scope=a.CONTRACT['scope'],
                      systemdAcceptance='not performed: unit adapter only',
                      realStagingInterruptionRejected=True, unreviewedSchemaRejected=True,
                      disconnectedSessionLockReleased=True, competingSessionLockRejected=True)
        (output/'operational-adoption.json').write_text(json.dumps(result, indent=2))
        return result
    finally:
        client.close()
        p.owned(container, token)
        p.query(container, 'SET GLOBAL read_only=OFF;')
