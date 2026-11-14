"""Accept an already successful, stopped application rehearsal; no cloud writes.

Business tables and uploads must still match the untouched data restore. Only
the isolated application's generated password is changed. No services are enabled.
"""
import argparse
import json
import os
from pathlib import Path
import secrets
import sys
import uuid

import standby_application as a

b, n, s, d = a.b, a.n, a.s, a.d


def read_private(path):
    b.protected_file(path)
    return json.loads(path.read_text())


def table_checksums(c, native):
    """Compare two imports on the SAME server version, not 10.11 against 11.8."""
    counts = d.inventory(c, native)['base_table_rows']
    result = {}
    for database, tables in sorted(counts.items()):
        for table, count in sorted(tables.items()):
            name = '`' + database + '`.`' + table.replace('`', '``') + '`'
            rows = d.query(c, native, 'CHECKSUM TABLE ' + name + ' EXTENDED;')
            b.require(len(rows) == 1, 'Missing business-table checksum')
            fields = rows[0].split('\t')
            b.require(len(fields) == 2 and fields[1].isdigit(), 'Business-table checksum unavailable')
            result[database + '.' + table] = {'rows': count, 'checksum': fields[1]}
    return result


def verify_report(report, state, manifest):
    b.require(report.get('result') == 'APPLICATION_PROBE_PASSED_ACCEPTANCE_PENDING'
              and report.get('snapshot') == state['record']['snapshot']
              and report.get('archive_sha256') == state['record']['sha256']
              and report.get('web_dll_sha256') == a.expected_dll(manifest['software_identity'])
              and report.get('application_starts') == 2
              and report.get('photo_files_checked') == len(manifest['required_photos']),
              'Successful application evidence does not match this backup')
    b.require(uuid.UUID(report['token']).hex == report['token'], 'Invalid application attempt identity')
    a.readiness(json.dumps(report.get('readiness')).encode())


def verify_workspace(c, workspace, manifest, publication):
    workspace = b.absolute(str(workspace))
    info = workspace.stat()
    b.require(info.st_uid == c['server_uid'] and not info.st_mode & 0o077,
              'Application workspace ownership or mode changed')
    uploads = b.inventory(workspace / 'uploads')
    prefix = 'sources/' + c['uploads_source'] + '/'
    expected = {key[len(prefix):]: value for key, value in manifest['inventory'].items()
                if key.startswith(prefix)}
    b.require(uploads == expected, 'Application uploads differ from the backup')
    expected_publication = {}
    for name, entry in publication['inventory'].items():
        if not name.startswith('publication/'):
            continue
        parts = name.split('/')[1:]
        if any(part.lower().startswith(('appsettings', '.env'))
               or part.lower() in ('web.config', 'uploads') for part in parts):
            continue
        expected_publication['/'.join(parts)] = entry
    actual = b.inventory(workspace / 'publication')
    actual.pop('appsettings.json', None)
    b.require(actual == expected_publication, 'Application publication changed after rehearsal')
    settings = json.loads((workspace / 'publication/appsettings.json').read_text())
    b.require(settings == {'Monitoring': {'Enabled': False}, 'AllowedHosts': '127.0.0.1;localhost'},
              'Application settings changed after rehearsal')


def promote(c, generation, acceptance):
    """The single atomic pointer is the commit point, after stopped checks."""
    pointer = c['state_root'] / 'last-accepted.json'
    if pointer.exists():
        previous = read_private(pointer)
        old = previous['record']
        b.require(s.timestamp(acceptance['record']['recovery_point']) > s.timestamp(old['recovery_point']),
                  'Acceptance must advance the recovery point')
        acceptance['previous_snapshot'] = old['snapshot']
    n.atomic_json(generation / 'acceptance.json', acceptance)
    n.atomic_json(pointer, acceptance)


def accept(config, snapshot, publication, application_root):
    c = d.configure(config)
    b.require(n.NAME.fullmatch(snapshot), 'Use an exact restored snapshot identity')
    generation = c['state_root'] / 'generations' / snapshot
    state = read_private(generation / 'state.json')
    b.require(state.get('format') == s.STATE_FORMAT and state.get('accepted') is False
              and state.get('phase') == 'DATA_RESTORED_APPLICATION_PENDING'
              and state.get('record', {}).get('snapshot') == snapshot, 'Untouched restored generation required')
    pointer = c['state_root'] / 'last-accepted.json'
    if pointer.exists():
        prior = read_private(pointer)
        if prior['record']['snapshot'] == snapshot:
            b.require(prior['record'] == state['record'], 'Accepted backup identity changed')
            return {'result': 'ALREADY_ACCEPTED', 'snapshot': snapshot}
    s.check_record(c, state['record'])
    archive = generation / state['record']['archive']
    b.require(b.digest(archive) == state['record']['sha256'], 'Backup archive changed')
    manifest = s.check_manifest(c, archive, state['record'])
    report = read_private(generation / 'application-probe.json')
    verify_report(report, state, manifest)
    publication = b.absolute(publication)
    b.protected_file(publication)
    publication_manifest = a.p.verify(publication, a.expected_dll(manifest['software_identity']))
    app_root = b.absolute(application_root)
    b.require(app_root.name.startswith('orchidapp-standby-app') and len(app_root.parts) >= 3
              and not b.overlaps(app_root, c['state_root']) and not b.overlaps(app_root, c['database_root']),
              'Separate application root required')
    workspace = app_root / ('probe-' + report['token'])
    verify_workspace(c, workspace, manifest, publication_manifest)
    clone = generation / ('application-probe-' + report['token']) / 'generations' / snapshot
    clone_state = read_private(clone / 'state.json')
    b.require(clone_state.get('record') == state['record']
              and clone_state.get('phase') == 'DATA_RESTORED_APPLICATION_PENDING'
              and clone_state.get('accepted') is False, 'Application candidate identity differs')
    original, candidate = state['candidate'], clone_state['candidate']
    for native, owner, root in ((original, state['owner_token'], generation),
                                (candidate, clone_state['owner_token'], clone)):
        d.owned_target(c, native)
        b.require(native['owner_token'] == owner
                  and Path(native['admin_defaults']) == root / 'candidate-admin.cnf',
                  'Candidate ownership evidence differs')
        b.require(not Path(native['socket']).exists() and not Path(native['pid_file']).exists(),
                  'Candidate must be stopped before acceptance')
    b.require(original['target'] != candidate['target'], 'Independent data restore required')
    with d.running_candidate(c, original):
        expected = table_checksums(c, original)
    with d.running_candidate(c, candidate):
        b.require(table_checksums(c, candidate) == expected, 'Business data changed during application rehearsal')
        password = secrets.token_hex(32)
        # Retain the replacement before SQL, so a stopped failure can be retried.
        password_file = generation / 'application-password'
        d.private_text(password_file, password + '\n')
        d.query(c, candidate, "ALTER USER 'standby_probe'@'localhost' IDENTIFIED BY '" + password + "';")
    verify_workspace(c, workspace, manifest, publication_manifest)
    acceptance = {'format': 'orchidapp-standby-accepted-v1', 'record': state['record'],
                  'accepted_at': n.now(), 'application_token': report['token'],
                  'candidate': candidate, 'workspace': str(workspace),
                  'password_file': str(password_file), 'web_dll_sha256': report['web_dll_sha256'],
                  'business_tables': expected, 'photo_files_checked': report['photo_files_checked'],
                  'application_starts': 2, 'services_started': False}
    promote(c, generation, acceptance)
    return {'result': 'STANDBY_ACCEPTED_STOPPED', 'snapshot': snapshot,
            'photo_files_checked': report['photo_files_checked'], 'services_started': False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config', required=True)
    parser.add_argument('--generation', required=True)
    parser.add_argument('--publication', required=True)
    parser.add_argument('--application-root', required=True)
    args = parser.parse_args()
    os.umask(0o077)
    try:
        b.require(sys.platform.startswith('linux') and os.geteuid() == 0, 'Run acceptance as root on Pi 2')
        c = s.load_config(args.config)
        with b.operation_lock(c['state_root']):
            print(json.dumps(accept(c, args.generation, args.publication, args.application_root), indent=2))
        return 0
    except Exception as ex:
        print('ERROR: ' + (str(ex) if isinstance(ex, b.BackupError)
                          else 'Acceptance failed; inspect private state'), file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
