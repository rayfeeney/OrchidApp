"""Owned-container orchestration for real ARM64 packages, actions and recovery."""
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tarfile
import zipfile

import preflight as p
from package_contract import validate_package

HERE=Path(__file__).resolve().parent


class ApplicationStage:
    def __init__(self, database, token, image, package_a, package_b, output, specimen, manifest):
        self.database=database;self.token=token;self.output=output
        self.container=None;self.report={'scope':'isolated Linux ARM64 package/application/recovery',
            'status':'failed','databasePlatform':manifest['preflightDatabasePlatform'],
            'applicationPlatform':'linux/arm64','realSystemd':False,'cloudProvider':'private local rclone crypt'}
        self.output.mkdir()
        p.owned(database,token)
        image_info=json.loads(p.docker('image','inspect',image))[0]
        if image_info['Architecture']!='arm64':raise ValueError('ARM64 application image required')
        self.report['runtimeImageId']=image_info['Id']
        self.report['runtimeDockerfileSha256']=p.digest(HERE/'Runtime.Dockerfile')
        self.packages=[Path(package_a).resolve(),Path(package_b).resolve()]
        self.report['packages']=[]
        for package in self.packages:
            with zipfile.ZipFile(package) as archive:
                validate_package(archive)
                for name in ('OrchidApp/app/OrchidApp.Web.dll','OrchidApp/infrastructure/backups/orchid_backup.py'):
                    if name not in archive.namelist():raise ValueError('Complete Linux package required')
                for name in json.loads((HERE/'legacy-adoption.json').read_text())['expectedForwardMigrations']:
                    if archive.read('OrchidApp/database/migrations/'+name)!=(p.REPO/'database/migrations'/name).read_bytes():
                        raise ValueError('Package migration bytes differ from tested source')
                if archive.read('OrchidApp/infrastructure/backups/orchid_backup.py')!=(p.REPO/'infrastructure/backups/orchid_backup.py').read_bytes():
                    raise ValueError('Packaged backup tool differs from current source')
            self.report['packages'].append({'name':package.name,'bytes':package.stat().st_size,'sha256':p.digest(package)})
        runtime=self.output/'runtime-input';runtime.mkdir()
        # The exact input has already passed all outer/member/inner checks in
        # preflight. Recheck outer identity before reading runtime files.
        if p.digest(specimen)!=manifest['sha256']:raise ValueError('Specimen changed before runtime staging')
        with tarfile.open(specimen,'r:gz') as archive:
            for member in archive.getmembers():
                name=p.safe_relative(member.name)
                if name.parts[0]!=manifest['root'] or not member.isfile():raise ValueError('Unexpected runtime member')
                relative=Path(*name.parts[1:])
                if relative.parts[0] not in ('publish','uploads'):continue
                target=runtime/relative;target.parent.mkdir(parents=True,exist_ok=True)
                with target.open('xb') as stream:
                    source=archive.extractfile(member)
                    for part in iter(lambda:source.read(1024*1024),b''):stream.write(part)
        try:
            self.container=p.docker('create','--platform','linux/arm64',
                '--label','org.orchidapp.fixture-token='+token,'--network','container:'+database,
                image).decode().strip()
            self.owned()
            p.docker('cp',str(runtime/'publish'),self.container+':/specimen/publish-old')
            p.docker('cp',str(runtime/'uploads')+'/.',self.container+':/specimen/uploads/')
            for index,package in zip(('a','b'),self.packages):
                p.docker('cp',str(package),self.container+':/specimen/package-'+index+'.zip')
            for name in ('container_driver.py','plant_actions.py','http_support.py','schema_contract.py','package_contract.py'):
                p.docker('cp',str(HERE/name),self.container+':/checks/'+name)
            ownership=runtime/'ownership.json';ownership.write_text(json.dumps({'token':token,'databaseContainerId':database,
                'package_a_sha256':p.digest(self.packages[0]),'package_b_sha256':p.digest(self.packages[1])}))
            p.docker('cp',str(ownership),self.container+':/checks/ownership.json')
            with zipfile.ZipFile(self.packages[0]) as archive:
                backup=runtime/'orchid_backup.py';backup.write_bytes(archive.read('OrchidApp/infrastructure/backups/orchid_backup.py'))
            p.docker('cp',str(backup),self.container+':/checks/orchid_backup.py')
            client=runtime/'admin.cnf'
            client.write_text('[client]\nhost=127.0.0.1\nport=3306\nprotocol=tcp\nuser=root\npassword='+p.PASSWORD+'\ndefault-character-set=utf8mb4\n')
            p.docker('cp',str(client),self.container+':/specimen/admin.cnf')
            p.docker('start',self.container)
            self.command(['chmod','600','/specimen/admin.cnf'])
            p.query(database,"CREATE USER 'specimen'@'%' IDENTIFIED BY 'specimen-only-not-production'; "
                "GRANT SELECT,INSERT,UPDATE,DELETE,EXECUTE ON orchids.* TO 'specimen'@'%';")
            self.report['nativeVersions']=self.command(['dpkg-query','-W','libvips42','mariadb-client','python3','rclone']).decode().splitlines()
            self.report['dotnetRuntime']=self.command(['dotnet','--list-runtimes']).decode().splitlines()
            self.report['containerId']=self.container
            self.save()
        except Exception:
            self.close();raise

    def owned(self):
        p.owned(self.database,self.token)
        state=json.loads(p.docker('inspect',self.container))[0]
        host=state['HostConfig']
        if (state['Id']!=self.container or state['Config']['Labels'].get('org.orchidapp.fixture-token')!=self.token or
            host['NetworkMode']!='container:'+self.database or host.get('Binds') or host.get('PortBindings') or
                any(m.get('Type')=='bind' for m in state.get('Mounts',[]))):
            raise ValueError('Application fixture identity/isolation mismatch')
        return state

    def command(self, arguments, timeout=1800):
        self.owned()
        result=subprocess.run(['docker','exec',self.container,*arguments],capture_output=True,timeout=timeout)
        if result.returncode:
            (self.output/'private-command-error.log').write_bytes(result.stdout+result.stderr)
            raise RuntimeError('ARM64 acceptance command failed: '+arguments[0])
        return result.stdout

    def phase(self,name):
        self.owned()
        result=subprocess.run(['docker','exec','--env','ORCHID_APPLICATION_FIXTURE_TOKEN='+self.token,
            self.container,'python3','/checks/container_driver.py',name],
            capture_output=True,timeout=2400)
        (self.output/(name+'.log')).write_bytes(result.stdout+result.stderr)
        self.collect()
        path=self.output/'reports'/(name+'-report.json')
        if path.exists():self.report[name]=json.loads(path.read_text())
        self.save()
        if result.returncode:raise RuntimeError('ARM64 application phase failed: '+name)
        if self.report.get(name,{}).get('status')!='passed':raise ValueError('Missing application success evidence')
        print('ARM64 application acceptance phase passed: '+name,flush=True)

    def fail_migration(self, proxy, env):
        folder=self.output/'failing-migrations';folder.mkdir()
        for path in (p.REPO/'database/migrations').glob('*.sql'):
            (folder/path.name).write_bytes(path.read_bytes())
        name='202610281200_CiIntentionalFailure.sql'
        (folder/name).write_text("CREATE TABLE ci_partial_upgrade_witness(id INT PRIMARY KEY);\n"
            "SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='CI intentional upgrade failure';\n")
        command=['pwsh','-NoProfile','-File',str(p.REPO/'database/scripts/Apply-Migrations.ps1'),
            '-MariaDbExe',str(proxy),'-MigrationFolder',str(folder)]
        attempt=subprocess.run(command,env=env,cwd=p.REPO,capture_output=True,timeout=180)
        (self.output/'injected-migration.log').write_bytes(attempt.stdout+attempt.stderr)
        if not attempt.returncode:raise ValueError('Injected failing migration unexpectedly passed')
        marker=p.query(self.database,"SELECT checksum FROM orchids.schemaversion WHERE scriptName='migration:pending';").strip()
        if marker!=p.digest(folder/name):raise ValueError('Failed migration marker not retained')
        if p.query(self.database,"SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA='orchids' AND TABLE_NAME='ci_partial_upgrade_witness';").strip()!='1':
            raise ValueError('Partial DDL witness missing')
        retry=subprocess.run(command+['-PlanOnly'],env=env,cwd=p.REPO,capture_output=True,timeout=180)
        (self.output/'blocked-retry.log').write_bytes(retry.stdout+retry.stderr)
        log=re.sub(r'\s+',' ',(retry.stdout+retry.stderr).decode('utf-8','replace'))
        if not retry.returncode or 'incomplete or running migration' not in log:
            raise ValueError('Incomplete migration did not block retry')
        self.report['failedMigration']={'actualCanonicalFailure':True,'durablePendingMarker':True,
            'partialDdlPersisted':True,'retryRejected':True,'pendingMarkerDeletedToRetry':False}
        self.save()

    def collect(self):
        if not self.container:return
        self.owned()
        destination=self.output/'reports';destination.mkdir(exist_ok=True)
        # Local diagnostics may contain synthetic rows. CI upload uses an
        # explicit report/log allowlist and excludes all private logs/data.
        result=subprocess.run(['docker','cp',self.container+':/specimen/results/.',str(destination)],capture_output=True)
        if result.returncode:(self.output/'collect-error.log').write_bytes(result.stderr)

    def save(self):
        (self.output/'application-report.json').write_text(json.dumps(self.report,indent=2))

    def finish(self):
        self.report['status']='passed';self.save()

    def close(self):
        if self.container:
            self.collect();self.owned();p.docker('rm','-f','-v',self.container)
            self.report['cleanup']='owned application container removed';self.container=None
        self.save()
