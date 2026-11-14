"""Manual loopback takeover or an isolated writable rehearsal; never failover automatically."""
import argparse
import json
import os
from pathlib import Path
import shutil
import signal
import sys
import time
import uuid
from urllib.parse import quote

import standby_job as j

b, n, s, d, a = j.b, j.n, j.s, j.d, j.a


def selected(c, snapshot):
    b.require(n.NAME.fullmatch(snapshot), 'Use an exact accepted snapshot identity')
    pointer = c['state_root'] / 'last-accepted.json'
    value = j.read(pointer)
    b.require(value.get('format') == 'orchidapp-standby-accepted-v1'
              and value['record']['snapshot'] == snapshot, 'Name the exact current accepted snapshot')
    generation = c['state_root'] / 'generations' / snapshot
    b.require(j.read(generation / 'acceptance.json') == value, 'Accepted evidence and pointer differ')
    token = value['application_token']
    b.require(uuid.UUID(token).hex == token, 'Invalid accepted application token')
    clone = generation / ('application-probe-' + token) / 'generations' / snapshot
    state = j.read(clone / 'state.json')
    native = value['candidate']
    b.require(state['record'] == value['record'] and state['candidate'] == native
              and native['owner_token'] == state['owner_token']
              and Path(native['admin_defaults']) == clone / 'candidate-admin.cnf', 'Accepted endpoint identity differs')
    d.owned_target(c, native)
    workspace = b.absolute(value['workspace'])
    b.require(workspace == c['application_root'] / ('probe-' + token), 'Accepted workspace path differs')
    b.require(Path(value['password_file']) == generation / 'application-password', 'Accepted credential path differs')
    b.protected_file(Path(value['password_file']))
    b.require(not Path(native['socket']).exists() and not Path(native['pid_file']).exists(), 'Accepted database must be stopped')
    return value, generation, pointer.read_bytes()


def checks(c, native, workspace, password, evidence, runtime):
    """Return a running owned application only after readiness/home checks."""
    return a.running_app(c, runtime, workspace, native, password, evidence, port=5010)


def release_unchanged(c, snapshot, primary):
    """Resume backup refresh only if activation left NO business/media changes."""
    b.require(primary, 'Explicit --pi1-primary acknowledgement required before resuming refresh')
    value, generation, _ = selected(c, snapshot)
    marker = c['state_root'] / 'active-takeover.json'
    b.require(marker.exists() and j.read(marker)['snapshot'] == snapshot, 'Matching active takeover marker required')
    archive = generation / value['record']['archive']
    b.require(b.digest(archive) == value['record']['sha256'], 'Accepted archive changed')
    manifest = s.check_manifest(c, archive, value['record'])
    publication = a.p.verify(c['publication_archive'], value['web_dll_sha256'])
    j.acceptance.verify_workspace(c, Path(value['workspace']), manifest, publication)
    with d.running_candidate(c, value['candidate']):
        b.require(j.acceptance.table_checksums(c, value['candidate']) == value['business_tables'],
                  'Pi 2 has new writes: preserve and reconcile them before any refresh or switch-back')
    n.atomic_json(generation / 'takeover-released.json', {'snapshot': snapshot, 'released_at': n.now(),
                                                        'business_data_and_uploads_unchanged': True})
    marker.unlink()
    return {'result': 'UNCHANGED_TAKEOVER_RELEASED', 'snapshot': snapshot}


def cleanup_rehearsal(c, snapshot):
    scratch = b.absolute(str(c['state_root'] / 'takeover-rehearsal'))
    report = j.read(scratch / 'report.json')
    b.require(report.get('result') == 'REHEARSAL_STOPPED' and report.get('snapshot') == snapshot,
              'Only a stopped matching rehearsal can be cleaned automatically')
    token = report['token']
    b.require(uuid.UUID(token).hex == token and n.NAME.fullmatch(snapshot), 'Invalid rehearsal identity')
    native = report['candidate']
    target = d.owned_target(c, native)
    state = j.read(scratch / 'generations' / snapshot / 'state.json')
    b.require(state['candidate'] == native and native['owner_token'] == state['owner_token']
              and Path(native['admin_defaults']) == scratch / 'generations' / snapshot / 'candidate-admin.cnf',
              'Rehearsal database ownership differs')
    workspace = b.absolute(report['workspace'])
    b.require(workspace == c['application_root'] / ('rehearsal-' + token), 'Rehearsal workspace escaped owned root')
    b.require(not Path(native['socket']).exists() and not Path(native['pid_file']).exists(), 'Rehearsal may be running')
    current = j.read(c['state_root'] / 'last-accepted.json')
    b.require(not b.overlaps(target, b.absolute(current['candidate']['target']))
              and not b.overlaps(workspace, b.absolute(current['workspace'])), 'Cannot clean an accepted standby')
    n.atomic_json(c['state_root'] / 'takeover-rehearsal-last.json', report)
    for path in (target, workspace, scratch):
        shutil.rmtree(path)
    return {'result': 'REHEARSAL_CLEANED', 'snapshot': snapshot}


def workspace_from_backup(c, generation, manifest, token):
    workspace = c['application_root'] / ('rehearsal-' + token)
    workspace.mkdir(mode=0o700)
    a.copy_publication(c['publication_archive'], workspace / 'publication', a.expected_dll(manifest['software_identity']))
    shutil.copytree(generation / 'payload/sources' / c['uploads_source'], workspace / 'uploads')
    (workspace / 'tmp').mkdir(mode=0o700)
    for path in [workspace, *workspace.rglob('*')]:
        b.require(not path.is_symlink(), 'Unexpected rehearsal workspace link')
        os.chown(path, c['server_uid'], c['server_gid'])
        path.chmod(0o700 if path.is_dir() else 0o600)
    return workspace


def rehearse(c, snapshot):
    value, source, pointer_before = selected(c, snapshot)
    token = uuid.uuid4().hex
    scratch = s.private_directory(c['state_root'] / 'takeover-rehearsal')
    report_path = scratch / 'report.json'
    b.require(not report_path.exists(), 'Rehearsal already exists; retain/review it before another attempt')
    record = value['record']
    archive = source / record['archive']
    b.require(b.digest(archive) == record['sha256'], 'Accepted archive changed')
    manifest = s.check_manifest(c, archive, record)
    generation = s.private_directory(scratch / 'generations' / snapshot)
    needed = 4 * sum(v.get('size', 0) for v in manifest['inventory'].values()) + record['size_bytes'] + c['reserve_bytes']
    b.require(shutil.disk_usage(c['state_root']).free >= needed, 'Insufficient space for isolated takeover rehearsal')
    report = {'result': 'REHEARSAL_PENDING', 'snapshot': snapshot, 'token': token, 'started_at': n.now()}
    n.atomic_json(report_path, report)
    clone_config = dict(c, state_root=scratch, backup_root=scratch)
    try:
        shutil.copyfile(archive, generation / archive.name)
        (generation / archive.name).chmod(0o600)
        s.extract_private(generation / archive.name, generation / 'payload', manifest)
        n.atomic_json(generation / 'state.json', {'format': s.STATE_FORMAT, 'owner_token': uuid.uuid4().hex,
                      'record': record, 'phase': 'PREPARED_RESTORE_PENDING', 'accepted': False})
        d.restore_data(clone_config, snapshot)
        native = j.read(generation / 'state.json')['candidate']
        report['candidate'] = native
        workspace = workspace_from_backup(c, generation, manifest, token)
        report['workspace'] = str(workspace)
        n.atomic_json(report_path, report)
        with d.running_candidate(c, native) as server:
            password = a.provision(c, native, server)
            before = j.acceptance.table_checksums(c, native)
            photos_before = b.inventory(workspace / 'uploads')
            with checks(c, native, workspace, password, scratch / 'application.log', c['dotnet']) as (process, port):
                a.readiness(a.get(process, port, '/health/ready', 65536))
                a.get(process, port, '/', 4 * 1024**2)
                print('REHEARSAL_READY: http://127.0.0.1:5010 — disposable copy; Ctrl+C after browser checks.', flush=True)
                try:
                    while process.poll() is None:
                        time.sleep(1)
                except KeyboardInterrupt:
                    pass
                b.require(process.poll() is None, 'Rehearsal application exited unexpectedly')
            after = j.acceptance.table_checksums(c, native)
            photos_after = b.inventory(workspace / 'uploads')
            # Restart after the owner's writes and verify every active media byte.
            with checks(c, native, workspace, password, scratch / 'application.log', c['dotnet']) as (process, port):
                a.readiness(a.get(process, port, '/health/ready', 65536))
                a.get(process, port, '/', 4 * 1024**2)
                references = d.photo_paths(c, native)
                for relative in references:
                    b.safe_path(relative)
                    entry = photos_after[relative]
                    a.get(process, port, '/uploads/' + quote(relative, safe='/'), entry['size'], entry['sha256'])
        b.require((c['state_root'] / 'last-accepted.json').read_bytes() == pointer_before,
                  'Accepted pointer changed during rehearsal')
        report.update(result='REHEARSAL_STOPPED', finished_at=n.now(),
                      business_data_changed=before != after, upload_files_changed=photos_before != photos_after,
                      accepted_pointer_unchanged=True, application_starts=2,
                      post_write_photo_files_checked=len(references))
        n.atomic_json(report_path, report)
        return report
    except BaseException:
        report.update(result='REHEARSAL_FAILED', finished_at=n.now())
        n.atomic_json(report_path, report)
        raise


def activate(c, snapshot, fenced):
    b.require(fenced, 'Explicit --pi1-fenced acknowledgement required before live activation')
    value, generation, _ = selected(c, snapshot)
    marker = c['state_root'] / 'active-takeover.json'
    first_activation = not marker.exists()
    if marker.exists():
        existing = j.read(marker)
        b.require(existing['snapshot'] == snapshot, 'Another takeover snapshot is protected')
    else:
        archive = generation / value['record']['archive']
        b.require(b.digest(archive) == value['record']['sha256'], 'Accepted archive changed')
        manifest = s.check_manifest(c, archive, value['record'])
        publication = a.p.verify(c['publication_archive'], value['web_dll_sha256'])
        j.acceptance.verify_workspace(c, Path(value['workspace']), manifest, publication)
        n.atomic_json(marker, {'snapshot': snapshot, 'activated_at': n.now(),
                              'note': 'Do not resume restore until Pi 2 writes have been preserved and reconciled'})
    password = Path(value['password_file']).read_text().strip()
    with d.running_candidate(c, value['candidate']):
        if first_activation:
            b.require(j.acceptance.table_checksums(c, value['candidate']) == value['business_tables'],
                      'Accepted business data changed before initial takeover')
        with checks(c, value['candidate'], Path(value['workspace']), password,
                    generation / 'takeover.log', c['dotnet']) as (process, port):
            a.readiness(a.get(process, port, '/health/ready', 65536))
            print('TAKEOVER_READY: http://127.0.0.1:5010 — keep this session running. Ctrl+C stops it; restore stays blocked.', flush=True)
            try:
                while process.poll() is None:
                    time.sleep(1)
            except KeyboardInterrupt:
                pass
            b.require(process.poll() is None, 'Activated application exited unexpectedly')
    return {'result': 'TAKEOVER_STOPPED_RESTORE_BLOCKED', 'snapshot': snapshot}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('operation', choices=('rehearse', 'activate', 'release-unchanged', 'cleanup-rehearsal'))
    parser.add_argument('--config', required=True)
    parser.add_argument('--email-config', required=True)
    parser.add_argument('--snapshot', required=True)
    parser.add_argument('--pi1-fenced', action='store_true')
    parser.add_argument('--pi1-primary', action='store_true')
    args = parser.parse_args()
    os.umask(0o077)
    def interrupted(*_):
        raise KeyboardInterrupt()
    signal.signal(signal.SIGTERM, interrupted)
    if hasattr(signal, 'SIGHUP'):
        signal.signal(signal.SIGHUP, interrupted)
    try:
        b.require(sys.platform.startswith('linux') and os.geteuid() == 0, 'Run takeover commands as root on Pi 2')
        c, _ = j.configure(args.config, args.email_config)
        c = d.configure(c)
        for path in (c['dotnet'], *c['dotnet'].parents):
            info = path.stat()
            b.require(info.st_uid == 0 and not info.st_mode & 0o022, 'Runtime paths must remain root owned and protected')
        with b.operation_lock(c['state_root']):
            if args.operation == 'rehearse':
                result = rehearse(c, args.snapshot)
            elif args.operation == 'activate':
                result = activate(c, args.snapshot, args.pi1_fenced)
            elif args.operation == 'release-unchanged':
                result = release_unchanged(c, args.snapshot, args.pi1_primary)
            else:
                result = cleanup_rehearsal(c, args.snapshot)
            print(json.dumps(result, indent=2))
        return 0
    except (Exception, KeyboardInterrupt) as ex:
        print('ERROR: ' + (str(ex) if isinstance(ex, b.BackupError) else 'Takeover/rehearsal stopped; inspect private state'), file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
