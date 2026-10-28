"""ARM64 application and real paired-backup acceptance inside a private fixture.

Invoked only by application_stage.py after container/DB ownership checks. No
production endpoint, cloud credential, systemd service or host path is accepted.
"""
import hashlib
import errno
import json
import os
from pathlib import Path
import re
import shutil
import signal
import stat
import subprocess
import sys
import time
import zipfile

ROOT = Path('/specimen')
ownership_file=Path('/checks/ownership.json')
token=os.environ.get('ORCHID_APPLICATION_FIXTURE_TOKEN','')
if (not re.fullmatch('[a-f0-9]{32}',token) or not ownership_file.is_file() or
        json.loads(ownership_file.read_text()).get('token')!=token or ROOT.is_symlink()):
    raise RuntimeError('Owned-container acceptance context is required; no live/standalone execution')
OUT = ROOT/'results'
OUT.mkdir(exist_ok=True)
os.environ['ORCHID_ACTION_OUTPUT'] = str(OUT)
from http_support import fetch, get_form, save
from schema_contract import snapshot, checksum
from package_contract import validate_package, paired_failure_message

APP = None
LOG = None


def run(args, *, data=None, timeout=900):
    result = subprocess.run(args, input=data, capture_output=True, timeout=timeout)
    if result.returncode:
        (OUT/'private-command-error.log').write_bytes(result.stdout+result.stderr)
        public=paired_failure_message(args,result.stdout,result.stderr)
        raise RuntimeError('Paired '+args[2]+' failed: '+public if public else 'Fixture command failed: '+Path(args[0]).name)
    return result.stdout


def sql(statement):
    return run(['mariadb','--defaults-extra-file=/specimen/admin.cnf',
        '--batch','--skip-column-names','--raw'], data=statement.encode()).decode()


def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for part in iter(lambda: stream.read(1024*1024),b''): h.update(part)
    return h.hexdigest()


def inventory(path):
    if path.is_symlink(): raise ValueError('Symlink root refused')
    result = {}
    for item in sorted(path.rglob('*')):
        if item.is_symlink(): raise ValueError('Symlink fixture file refused')
        if item.is_file(): result[item.relative_to(path).as_posix()] = digest(item)
    return result


def data_fingerprint():
    tables = sql("SELECT TABLE_NAME FROM information_schema.TABLES WHERE TABLE_SCHEMA='orchids' "
                 "AND TABLE_TYPE='BASE TABLE' ORDER BY TABLE_NAME;").splitlines()
    value = hashlib.sha256()
    with subprocess.Popen(['mariadb-dump','--defaults-extra-file=/specimen/admin.cnf',
        '--single-transaction','--no-create-info','--skip-comments','--skip-dump-date',
        '--skip-add-locks','--skip-disable-keys','--skip-extended-insert','--order-by-primary',
        '--hex-blob','orchids',*tables],stdout=subprocess.PIPE,stderr=subprocess.DEVNULL) as process:
        for part in iter(lambda: process.stdout.read(1024*1024),b''): value.update(part)
        if process.wait(timeout=900): raise RuntimeError('Data fingerprint failed')
    return value.hexdigest()


def state():
    return {'data':data_fingerprint(),'schema':checksum(snapshot(sql)),
        'uploads':inventory(ROOT/'uploads'),'configuration':inventory(ROOT/'configuration')}


def require_equal(actual, expected, label):
    if actual != expected: raise ValueError(label+' differs')


def stop():
    global APP, LOG
    if APP is not None:
        if APP.poll() is None:
            APP.terminate()
            try: APP.wait(timeout=30)
            except subprocess.TimeoutExpired: APP.kill();APP.wait()
        APP = None
    (ROOT/'writer.pid').unlink(missing_ok=True)
    if LOG is not None: LOG.close();LOG=None


def start(label, expect_failure=False):
    global APP, LOG
    stop()
    environment = dict(os.environ)
    environment.update(json.loads((ROOT/'configuration/runtime.json').read_text()))
    environment['HOME']='/tmp/orchid-fixture-user'
    home=Path(environment['HOME']);home.mkdir(exist_ok=True);os.chown(home,1654,1654)
    LOG=(OUT/('private-app-'+label+'.log')).open('wb')
    def user(): os.setgroups([]);os.setgid(1654);os.setuid(1654)
    APP=subprocess.Popen(['dotnet','OrchidApp.Web.dll'],cwd=ROOT/'publish',env=environment,
        stdout=LOG,stderr=subprocess.STDOUT,preexec_fn=user)
    (ROOT/'writer.pid').write_text(str(APP.pid))
    for _ in range(90):
        if APP.poll() is not None:
            if expect_failure: stop();return
            raise RuntimeError('Application exited during '+label)
        try:
            if fetch('/')['status']==200:
                if expect_failure: raise ValueError('Broken package unexpectedly became ready')
                return
        except (OSError,TimeoutError): pass
        time.sleep(1)
    if expect_failure: raise ValueError('Broken package did not terminate')
    raise RuntimeError('Application readiness timed out: '+label)


def replace_tree(source, target):
    # All inputs live under this container's owned /specimen tree. Only whole
    # fixture directories are retired; no user/host directory is reachable.
    for path in (source,target):
        if not path.resolve().is_relative_to(ROOT) or path.is_symlink():
            raise ValueError('Unsafe fixture replacement')
    staging=target.with_name(target.name+'-staging')
    retired=target.with_name(target.name+'-retired')
    if staging.exists() or retired.exists(): raise ValueError('Partial replacement requires review')
    shutil.copytree(source,staging)
    require_equal(inventory(staging),inventory(source),'Staged files')
    # Docker overlay lower-layer empty placeholders cannot always be renamed
    # into the upper layer. Remove only an empty placeholder before first use.
    if target.is_dir() and not any(target.iterdir()):target.rmdir()
    if target.exists():
        try: target.rename(retired)
        except OSError as error:
            if error.errno!=errno.EXDEV:raise
            # Docker overlay can refuse renaming a nonempty lower-layer
            # directory too. Preserve/verify it before removing that fixture
            # tree; staged replacement is already complete, with writers off.
            shutil.copytree(target,retired)
            require_equal(inventory(retired),inventory(target),'Retired fixture files')
            shutil.rmtree(target)
    staging.rename(target)
    if retired.exists(): shutil.rmtree(retired)


def package(name):
    destination=ROOT/('unpacked-'+name)
    destination.mkdir()
    expected=json.loads(ownership_file.read_text())['package_'+name+'_sha256']
    require_equal(digest(ROOT/('package-'+name+'.zip')),expected,'Package bytes')
    with zipfile.ZipFile(ROOT/('package-'+name+'.zip')) as archive:
        validate_package(archive);archive.extractall(destination)
    app=destination/'OrchidApp/app'
    if not (app/'OrchidApp.Web.dll').is_file():raise ValueError('Package app missing')
    return app


def smoke(label, require_ready=True):
    plant=int(sql('SELECT plantId FROM orchids.plant WHERE isActive=1 ORDER BY plantId LIMIT 1;'))
    for path in ('/','/Plants','/Reports/Flowering','/Reports/FloweringHistory',f'/Plants/Details/{plant}'):
        if fetch(path)['status']!=200: raise ValueError('Smoke page failed: '+path)
    photo=sql('SELECT plantId,fileName FROM orchids.plantphoto WHERE isActive=1 ORDER BY plantPhotoId LIMIT 1;').strip().split('\t')
    response=fetch('/uploads/plants/'+photo[0]+'/'+photo[1])
    if response['status']!=200 or hashlib.sha256(response['bytes']).hexdigest()!=digest(ROOT/'uploads/plants'/photo[0]/photo[1]):
        raise ValueError('Existing specimen photo failed')
    if require_ready:
        ready=fetch('/health/ready')
        if ready['status']!=200:raise ValueError('Current package readiness check failed')
    return {'label':label,'pages':5,'existingPhotoBytesVerified':True,'currentReadinessVerified':require_ready}


def save_note(label):
    # Writes only a dedicated CI-created plant, never an original collection row.
    from datetime import date,timedelta
    taxon=int(sql('SELECT taxonId FROM orchids.taxon WHERE isActive=1 AND isSystemManaged=0 ORDER BY taxonId LIMIT 1;'))
    name='CI '+label
    path=f'/Plants/Add/Create/{taxon}'
    form=get_form(path,field='Input.PlantName')
    day=(date.fromisoformat(sql('SELECT CURRENT_DATE();').strip())-timedelta(days=2)).isoformat()
    save(path,form,{'Input.PlantName':name,'Input.AcquisitionDate':day,'Input.AcquisitionSource':'CI recovery'})
    plant=int(sql("SELECT plantId FROM orchids.plant WHERE plantName='"+name+"';"))
    path=f'/Plants/Events/Add/{plant}/Observation';form=get_form(path,field='EventDetails')
    save(path,form,{'EventDate':day,'EventDetails':name+' note'})
    response=fetch(f'/Plants/Details/{plant}')
    if response['status']!=200 or name+' note' not in response['body']:raise ValueError('Save/reopen failed')
    if int(sql(f"SELECT COUNT(*) FROM orchids.plantevent WHERE plantId={plant} AND eventDetails LIKE '%{name} note%';"))!=1:
        raise ValueError('Saved note missing')
    return {'plantId':plant,'saveAndReopen':True}


def initialise():
    (ROOT/'configuration').mkdir(exist_ok=True)
    config={'ASPNETCORE_ENVIRONMENT':'Production','ASPNETCORE_URLS':'http://127.0.0.1:5080',
        'ConnectionStrings__OrchidDb':'Server=127.0.0.1;Port=3306;Database=orchids;User=specimen;Password=specimen-only-not-production',
        'Storage__UploadRoot':'/specimen/uploads','Monitoring__Enabled':'false'}
    (ROOT/'configuration/runtime.json').write_text(json.dumps(config));(ROOT/'configuration/runtime.json').chmod(0o600)
    os.chown(ROOT/'uploads',1654,1654)
    for p in (ROOT/'uploads').rglob('*'):os.chown(p,1654,1654)
    bin_dir=ROOT/'bin';bin_dir.mkdir()
    shim=bin_dir/'systemctl'
    shim.write_text('''#!/usr/bin/python3
import os,sys
from pathlib import Path
if len(sys.argv)<3 or sys.argv[1]!='show' or sys.argv[2]!='orchidapp-fixture.service':sys.exit(64)
active=False
try:os.kill(int(Path('/specimen/writer.pid').read_text()),0);active=True
except (OSError,ValueError):pass
print('LoadState=loaded\\nActiveState='+('active' if active else 'inactive')+'\\nSubState='+('running' if active else 'dead'))
''');shim.chmod(0o755)
    os.environ['PATH']=str(bin_dir)+':'+os.environ['PATH']
    password=run(['rclone','obscure','historical-fixture-local-crypt-only']).decode().strip()
    rc=ROOT/'rclone.conf';rc.write_text('[fixturecrypt]\ntype = crypt\nremote = /specimen/encrypted-store\npassword = '+password+'\n');rc.chmod(0o600)
    run(['rclone','--config',str(rc),'mkdir','fixturecrypt:paired'])
    c={'collection_id':'54a4fba5-f3d5-445e-ae30-d24f87ac6304','database':'orchids',
        'client_defaults_file':'/specimen/admin.cnf','uploads_root':'/specimen/uploads',
        'configuration_root':'/specimen/configuration','backup_root':'/specimen/backups',
        'log_file':'/specimen/backup.log','writer_units':['orchidapp-fixture.service'],
        'rclone_config':str(rc),'remote':'fixturecrypt:paired','keep_local':10,'timeout_seconds':900,
        'max_unpack_bytes':2*1024**3}
    cfg=ROOT/'backup-settings.json';cfg.write_text(json.dumps(c));cfg.chmod(0o600)


def backup(label):
    stop()
    before=set((ROOT/'backups').glob('orchidpair-*.tar.gz')) if (ROOT/'backups').exists() else set()
    run(['python3','/checks/orchid_backup.py','backup','--config','/specimen/backup-settings.json','--writers-stopped'])
    archives=set((ROOT/'backups').glob('orchidpair-*.tar.gz'))-before
    if len(archives)!=1:raise ValueError('One completed paired snapshot required')
    archive=archives.pop()
    return {'path':str(archive),'sha256':digest(archive),'tool':'production orchid_backup.py',
            'remote':'actual rclone crypt over private local storage','label':label}


def restore(saved, app, label):
    stop()
    require_equal(digest(Path(saved['archive']['path'])),saved['archive']['sha256'],'Recovery archive')
    # Explicitly disposable DB: production restore itself insists on an empty
    # same-name target. Never repair/replay migrations into the failed state.
    sql('DROP DATABASE orchids; CREATE DATABASE orchids CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;')
    target=ROOT/('restored-'+label)
    run(['python3','/checks/orchid_backup.py','restore','--config','/specimen/backup-settings.json',
        '--archive',saved['archive']['path'],'--destination',str(target),'--confirm-isolated','--confirm-database','orchids'])
    sql("GRANT SELECT,INSERT,UPDATE,DELETE,EXECUTE ON orchids.* TO 'specimen'@'%';")
    if (target/'RESTORE-PENDING.json').exists() or not (target/'RESTORED-VERIFY-APPLICATION.json').is_file():
        raise ValueError('Restore did not reach application verification')
    for tree in ('uploads','configuration'):replace_tree(target/tree,ROOT/tree)
    for p in [ROOT/'uploads',*(ROOT/'uploads').rglob('*')]:os.chown(p,1654,1654)
    replace_tree(app,ROOT/'publish')
    require_equal(inventory(ROOT/'publish'),inventory(app),'Recovered app files')
    require_equal(state(),saved['state'],'Recovered database/files/configuration')
    start('recovered-'+label)
    ready=smoke('recovered-'+label,require_ready=label!='old-version');written=save_note('recovery-'+label)
    stop()
    return {'exactSnapshotRestoredBeforeTestWrites':True,'compatibleApplication':ready,
            'writeAfterRestore':written,'pendingMarkerAbsent':True}


def main():
    phase=sys.argv[1];report={'phase':phase,'status':'failed'}
    context=ROOT/'acceptance-state.json'
    try:
        if phase=='baseline':
            initialise();replace_tree(ROOT/'publish-old',ROOT/'publish')
            start('historical-baseline');report['historicalApplication']=smoke('historical-baseline',require_ready=False);stop()
            old_state=state();saved=ROOT/'saved-old-app';shutil.copytree(ROOT/'publish',saved)
            old={'state':old_state,'archive':backup('pre-upgrade'),'application':str(saved),'appFiles':inventory(saved)}
            context.write_text(json.dumps({'old':old}))
            report['preUpgradeRecoverySet']={'dataSnapshot':old['archive'],'applicationInventorySha256':checksum(old['appFiles']),
                'completeUploadsAndExternalConfiguration':True,'originalSchemaSha256':old_state['schema']}
        else:
            os.environ['PATH']='/specimen/bin:'+os.environ['PATH']
            c=json.loads(context.read_text())
            if phase=='upgraded':
                app_a=package('a');app_b=package('b')
                if digest(app_a/'OrchidApp.Web.dll')==digest(app_b/'OrchidApp.Web.dll'):
                    raise ValueError('App-only package must have a distinct compiled build identity')
                replace_tree(app_a,ROOT/'publish');start('upgraded-package-a');report['upgradedSmoke']=smoke('upgraded-package-a')
                startup_log=(OUT/'private-app-upgraded-package-a.log').read_text()
                if 'MonitoringDevice' in startup_log or 'TapoEnergyHourly' in startup_log:
                    raise ValueError('Current build attempted disabled owner monitoring')
                report['disabledOwnerMonitoringNotQueried']=True
                env=dict(os.environ,ORCHID_ACTION_OUTPUT=str(OUT/'actions'))
                result=subprocess.run(['python3','/checks/plant_actions.py'],env=env,capture_output=True,timeout=900)
                (OUT/'actions.log').write_bytes(result.stdout+result.stderr)
                actions=json.loads((OUT/'actions/actions-report.json').read_text())
                report['actions']={'passed':actions['passed'],'failed':actions['failed']}
                if result.returncode or actions['failed']:raise ValueError('Upgraded application actions failed')
                before=state();stop();start('restart-package-a');smoke('restart-package-a');require_equal(state(),before,'Restart persistence');stop()
                report['restartPersistence']=True
                saved=ROOT/'saved-current-app';shutil.copytree(ROOT/'publish',saved)
                current={'state':state(),'archive':backup('pre-app-only'),'application':str(saved),'appFiles':inventory(saved)}
                c['current']=current;context.write_text(json.dumps(c))
                replace_tree(app_b,ROOT/'publish');start('app-only-package-b');smoke('app-only-package-b')
                require_equal(state(),current['state'],'App-only database/photos/configuration')
                report['appOnly']={'differentAppBuild':True,'databaseSchemaHistoryDataAndFilesUnchanged':True,
                    'saveReopen':save_note('app-only-package-b')}
                stop();(ROOT/'publish/OrchidApp.Web.dll').rename(ROOT/'publish/OrchidApp.Web.dll.broken')
                start('injected-broken-app',expect_failure=True)
                report['appOnlyRecovery']=restore(current,saved,'app-only')
            elif phase=='rollback-old':
                report['preUpgradeRecovery']=restore(c['old'],Path(c['old']['application']),'old-version')
            else:raise ValueError('Unknown acceptance phase')
        report['status']='passed'
    except Exception as error:
        report['error']=str(error)
        raise
    finally:
        report['fixtureProtection']={'operatorUid':os.geteuid(),'files':{}}
        for name in ('admin.cnf','backup-settings.json','rclone.conf','backup.log'):
            path=ROOT/name
            if path.exists():
                info=path.stat()
                report['fixtureProtection']['files'][name]={'uid':info.st_uid,'gid':info.st_gid,
                    'mode':oct(stat.S_IMODE(info.st_mode))}
        stop();(OUT/(phase+'-report.json')).write_text(json.dumps(report,indent=2))
    print(json.dumps(report),flush=True)


if __name__=='__main__':main()
