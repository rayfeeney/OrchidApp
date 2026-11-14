"""One locked Pi 2 refresh: discover, restore, check, accept, retain and report.

Never writes cloud storage, activates collectors or replaces system MariaDB.
Failed/unknown generations are retained for operator review.
"""
import argparse
import json
import os
from pathlib import Path
import shutil
import signal
import sys
import uuid

import standby_acceptance as acceptance
import standby_reporting as reporting

s, d, a = acceptance.s, acceptance.d, acceptance.a
b, n = s.b, s.n


def configure(config, email_config):
    c = s.load_config(config)
    mail = reporting.load_config(email_config)
    b.require(c['state_root'] == mail['backup_root'] and c['collection_id'] == mail['collection_id']
              and c['databases'] == mail['databases'], 'Restore and email settings must identify the same standby')
    for key in ('publication_archive', 'dotnet', 'application_root'):
        c[key] = b.absolute(c[key])
    root = c['application_root']
    b.require(root.name.startswith('orchidapp-standby-app') and len(root.parts) >= 3
              and not b.overlaps(root, c['state_root']) and not b.overlaps(root, b.absolute(c['database_root'])),
              'Separate owned application root required')
    b.protected_file(c['publication_archive'])
    b.require(c.get('view_definer_policy') == 'energy-six-v1', 'Use the reviewed six-view policy')
    # Two accepted generations, one older diagnostic generation and a new attempt.
    c['max_generations'] = max(c['max_generations'], 5)
    return c, mail


def read(path):
    return acceptance.read_private(path)


def removal_paths(c, generation, value):
    """Preflight every exact path before deleting any part of a generation."""
    snapshot = value['record']['snapshot']
    b.require(n.NAME.fullmatch(snapshot) and generation == c['state_root'] / 'generations' / snapshot,
              'Retention generation escaped state root')
    s.check_record(c, value['record'], freshness=False)
    b.require(value.get('format') == 'orchidapp-standby-accepted-v1'
              and value.get('services_started') is False, 'Only stopped accepted generations can expire')
    token = value['application_token']
    b.require(uuid.UUID(token).hex == token, 'Invalid retained application token')
    # Manual failed attempts are diagnostics, not automatically discarded.
    b.require({p.name for p in generation.glob('application-probe-*')}
              == {'application-probe-' + token}, 'Extra rehearsal evidence: retain for manual review')
    state = read(generation / 'state.json')
    clone = generation / ('application-probe-' + token) / 'generations' / snapshot
    clone_state = read(clone / 'state.json')
    b.require(state['record'] == clone_state['record'] == value['record']
              and clone_state['candidate'] == value['candidate'], 'Retention ownership records differ')
    paths = []
    for state_value, root in ((state, generation), (clone_state, clone)):
        native = state_value['candidate']
        target = d.owned_target(c, native)
        b.require(native['owner_token'] == state_value['owner_token']
                  and Path(native['admin_defaults']) == root / 'candidate-admin.cnf',
                  'Retention candidate ownership differs')
        b.require(not Path(native['socket']).exists() and not Path(native['pid_file']).exists(),
                  'Retention candidate may be running')
        paths.append(target)
    workspace = b.absolute(value['workspace'])
    b.require(workspace == c['application_root'] / ('probe-' + token)
              and workspace.stat().st_uid == c['server_uid'] and not workspace.stat().st_mode & 0o077,
              'Retention workspace escaped owned application root')
    b.require(len(set(paths)) == 2 and all(not b.overlaps(p, workspace) for p in paths),
              'Retention targets overlap')
    return paths + [workspace, b.absolute(str(generation))]


def retain(c):
    """Keep current plus previous; delete only earlier accepted owned sets."""
    pointer = read(c['state_root'] / 'last-accepted.json')
    current = pointer['record']['snapshot']
    values = []
    for path in (c['state_root'] / 'generations').iterdir():
        if path.is_symlink() or not path.is_dir() or not (path / 'acceptance.json').is_file():
            continue
        value = read(path / 'acceptance.json')
        b.require(value['record']['snapshot'] == path.name, 'Retained acceptance name differs')
        s.check_record(c, value['record'], freshness=False)
        values.append((path, value))
    values.sort(key=lambda item: s.timestamp(item[1]['record']['recovery_point']), reverse=True)
    b.require(values and values[0][0].name == current and values[0][1] == pointer,
              'Current accepted pointer and retained evidence differ')
    protected = {path.name for path, _ in values[:2]}
    if pointer.get('previous_snapshot'):
        protected.add(pointer['previous_snapshot'])
    plans, deferred = [], []
    protected_paths = set()
    for path, value in values:
        if path.name in protected:
            state = read(path / 'state.json')
            protected_paths.update((b.absolute(value['candidate']['target']), b.absolute(value['workspace']),
                                    b.absolute(state['candidate']['target']), b.absolute(str(path))))
    for path, value in values:
        if path.name in protected:
            continue
        try:
            paths = removal_paths(c, path, value)
            b.require(not any(b.overlaps(p, keep) for p in paths for keep in protected_paths),
                      'Retention would affect a protected standby')
            plans.append((path.name, paths))
        except b.BackupError:
            deferred.append(path.name)
    removed = []
    for snapshot, paths in plans:
        for path in paths:
            # All resolved paths were checked above; rmtree does not follow links.
            shutil.rmtree(path)
        removed.append(snapshot)
    return {'removed': removed, 'retained_for_review': deferred}


def notify(mail, operation, phase=None):
    root = s.private_directory(mail['backup_root'] / 'reporting-lock')
    with b.operation_lock(root):
        if operation == 'success':
            reporting.report_success(mail)
        elif operation == 'failure':
            reporting.failure(mail, phase)
        return n.flush_email(mail)


def refresh(c, mail, fail_test=False):
    b.require(not (c['state_root'] / 'active-takeover.json').exists(),
              'Pi 2 takeover is active; automated restore is blocked to preserve new writes')
    run_path = c['state_root'] / 'restore-run.json'
    run = {'result': 'RUNNING', 'started_at': n.now(), 'phase': 'discover'}
    n.atomic_json(run_path, run)
    try:
        if fail_test:
            raise b.BackupError('Explicit coordinator failure test; accepted data unchanged')
        record = s.discover(c)
        if record is None:
            # Recover a missed post-acceptance notification without rerunning SQL.
            delivered = notify(mail, 'success')
            run.update(result='NO_NEW_BACKUP', finished_at=n.now(), email_pending=not delivered)
            n.atomic_json(run_path, run)
            return run, 0 if delivered else 2
        snapshot = record['snapshot']
        run['snapshot'] = snapshot
        # Never blindly resume a failed or partial import on the next timer tick.
        b.require(not (c['state_root'] / 'generations' / snapshot).exists(),
                  'Latest generation already exists without acceptance; review retained evidence')
        for phase in ('prepare', 'restore-data', 'probe-application', 'accept'):
            run['phase'] = phase
            n.atomic_json(run_path, run)
            if phase == 'prepare':
                prepared = s.prepare(c)
                b.require(prepared.get('snapshot') == snapshot, 'Cloud selection changed; retained new input needs review')
            elif phase == 'restore-data':
                d.restore_data(c, snapshot)
            elif phase == 'probe-application':
                a.probe(c, snapshot, str(c['publication_archive']), str(c['dotnet']),
                        str(c['application_root']), c['view_definer_policy'])
            else:
                acceptance.accept(c, snapshot, str(c['publication_archive']), str(c['application_root']))
        # Acceptance is already committed: a retention/email problem cannot undo it.
        run.update(result='SUCCESS', phase='retention')
        n.atomic_json(run_path, run)
        try:
            run['retention'] = retain(d.configure(c))
        except Exception:
            run['retention'] = {'warning': 'Cleanup deferred; accepted restore preserved; inspect private state'}
        if run['retention'].get('warning') or run['retention'].get('retained_for_review'):
            n.queue_email(mail, '[Pi 2 restore] RETENTION WARNING',
                          'A new restore was accepted, but some older files require manual cleanup review.\n'
                          'The current and previous accepted restores were preserved.\n')
        run['phase'] = 'report'
        n.atomic_json(run_path, run)
        delivered = notify(mail, 'success')
        run.update(phase='complete', finished_at=n.now(), email_pending=not delivered)
        n.atomic_json(run_path, run)
        n.atomic_json(c['state_root'] / 'last-restore-success.json', run)
        return run, 0 if delivered else 2
    except Exception as ex:
        # A crash after pointer commit must not falsely describe the restore as failed.
        try:
            accepted = reporting.accepted(mail)
        except Exception:
            accepted = None
        committed = accepted is not None and run.get('snapshot') == accepted['record']['snapshot']
        run.update(result='ACCEPTED_REPORT_PENDING' if committed else 'FAILED', finished_at=n.now(),
                   error=str(ex) if isinstance(ex, b.BackupError) else 'Inspect private restore diagnostics')
        n.atomic_json(run_path, run)
        try:
            notify(mail, 'success' if committed else 'failure', run['phase'])
        except Exception:
            pass  # Original durable failure remains; independent monitor can alert/retry.
        return run, 2 if committed else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('operation', choices=('refresh', 'test-failure', 'retention'))
    parser.add_argument('--config', required=True)
    parser.add_argument('--email-config', required=True)
    args = parser.parse_args()
    os.umask(0o077)
    def interrupted(*_):
        raise b.BackupError('Restore job interrupted; inspect retained state before retry')
    signal.signal(signal.SIGTERM, interrupted)
    signal.signal(signal.SIGINT, interrupted)
    try:
        b.require(sys.platform.startswith('linux') and os.geteuid() == 0, 'Run the restore job as root on Pi 2')
        c, mail = configure(args.config, args.email_config)
        with b.operation_lock(c['state_root']):
            if args.operation == 'retention':
                result, code = retain(d.configure(c)), 0
            else:
                result, code = refresh(c, mail, args.operation == 'test-failure')
            print(json.dumps(result, indent=2))
            return code
    except Exception as ex:
        try:
            notify(reporting.load_config(args.email_config), 'failure', 'job-setup')
        except Exception:
            pass  # Invalid SMTP settings cannot report themselves; retain journal error.
        print('ERROR: ' + (str(ex) if isinstance(ex, b.BackupError) else 'Restore job setup failed; inspect private configuration'), file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
