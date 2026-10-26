$ErrorActionPreference='Stop'
$PSNativeCommandUseErrorActionPreference=$false
$repo=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
. (Join-Path $repo 'database/scripts/Schema-Baseline.ps1')
foreach($name in @('MARIADB_HOST','MARIADB_PORT','MARIADB_USER','MARIADB_PASSWORD')){if(-not [Environment]::GetEnvironmentVariable($name)){throw "Explicit $name required for disposable test server."}}
$hostValue=$env:MARIADB_HOST;$portValue=$env:MARIADB_PORT;$userValue=$env:MARIADB_USER;$passwordValue=$env:MARIADB_PASSWORD
$client=Resolve-MariaDbTool -Override $env:MARIADB_EXE
$database='orchids_env_'+[guid]::NewGuid().ToString('N')
$fixtureUser='orchid_env_'+[guid]::NewGuid().ToString('N')
$fixturePassword='env-fixture-'+[guid]::NewGuid().ToString('N')
$fixtureAccountCreated=$false
$root=Join-Path ([IO.Path]::GetTempPath()) $database
$stage=Join-Path $root 'source';$backups=Join-Path $root 'backups'
$null=New-Item -ItemType Directory -Path (Join-Path $stage 'database'),(Join-Path $stage 'scripts')
$previous=@{}
foreach($name in @('MARIADB_HOST','MARIADB_PORT','MARIADB_DATABASE','MARIADB_USER','MARIADB_PASSWORD','MARIADB_CHARSET','MARIADB_COLLATION','MYSQL_PWD','MARIADB_EXE','MARIADB_DUMP_EXE')){$previous[$name]=[Environment]::GetEnvironmentVariable($name)}
$checks=0
function Check([string]$Name,[bool]$Pass){if(-not $Pass){throw "Check failed: $Name"};$script:checks++}
function Query([string]$Statement,[switch]$Global){
    $before=$env:MYSQL_PWD;$env:MYSQL_PWD=$passwordValue
    try {
        $arguments=@('--no-defaults','--protocol=TCP',"--host=$hostValue","--port=$portValue","--user=$userValue",'--connect-timeout=5','--batch','--skip-column-names')
        if(-not $Global){$arguments+="--database=$database"}
        $output=$Statement | & $client @arguments 2>&1
        if($LASTEXITCODE -ne 0){throw 'Generated fixture query failed.'}
        $output
    }finally{$env:MYSQL_PWD=$before}
}
function Child([string[]]$Arguments){
    $output=& pwsh -NoProfile -File (Join-Path $stage 'scripts/DevSetup/update-database.ps1') -BackupRoot $backups @Arguments 2>&1
    $code=$LASTEXITCODE;$text=$output -join "`n"
    Check 'Credentials not printed by update command' (-not $text.Contains($fixturePassword) -and -not $text.Contains('wrong-ambient-secret'))
    @{code=$code;text=$text}
}
function Commit-Fixture {
    $output=& git -C $stage -c core.hooksPath=.githooks -c commit.gpgSign=false -c user.name=Fixture -c user.email=fixture@example.invalid commit --allow-empty -m 'Disposable env hook check' 2>&1
    $code=$LASTEXITCODE;$text=$output -join "`n"
    Check 'Credentials not printed by commit hook' (-not $text.Contains($fixturePassword) -and -not $text.Contains('wrong-ambient-secret'))
    @{code=$code;text=$text}
}
try {
    foreach($folder in @('scripts','schema','checksums','migrations')){Copy-Item -LiteralPath (Join-Path $repo "database/$folder") -Destination (Join-Path $stage 'database') -Recurse}
    Copy-Item -LiteralPath (Join-Path $repo 'scripts/DevSetup') -Destination (Join-Path $stage 'scripts') -Recurse
    Copy-Item -LiteralPath (Join-Path $repo '.githooks') -Destination $stage -Recurse
    if(-not $IsWindows){& chmod 700 -- (Join-Path $stage '.githooks/pre-commit');if($LASTEXITCODE -ne 0){throw 'Hook fixture permission failed.'}}
    $env:MARIADB_DATABASE=$database;$env:MARIADB_CHARSET='utf8mb4';$env:MARIADB_COLLATION='utf8mb4_unicode_ci'
    & (Join-Path $stage 'database/scripts/rebuild.ps1') -ConfirmDatabase $database
    # A common CI admin password such as "root" occurs in Git's "root-commit".
    # Test the wrappers with their own unique secret, not a generic substring.
    Query "CREATE USER '$fixtureUser'@'%' IDENTIFIED BY '$fixturePassword';" -Global | Out-Null
    $fixtureAccountCreated=$true
    Query "GRANT ALL PRIVILEGES ON ``$database``.* TO '$fixtureUser'@'%'; GRANT SELECT ON mysql.proc TO '$fixtureUser'@'%';" -Global | Out-Null
    Query 'CREATE TABLE before_update(id INT PRIMARY KEY); INSERT INTO before_update VALUES(1);' | Out-Null
    $migration=Join-Path $stage 'database/migrations/209901010000_EnvUpdateFixture.sql'
    [IO.File]::WriteAllText($migration,'CREATE TABLE env_update_witness(id INT PRIMARY KEY); INSERT INTO env_update_witness VALUES(42);',[Text.UTF8Encoding]::new($false))
    $envFile=Join-Path $stage '.env'
    [IO.File]::WriteAllLines($envFile,@("MARIADB_HOST=$hostValue","MARIADB_PORT=$portValue","MARIADB_DATABASE=$database","MARIADB_USER=$fixtureUser",("MARIADB_PASSWORD='"+$fixturePassword+"'")),[Text.UTF8Encoding]::new($false))
    if(-not $IsWindows){& chmod 600 -- $envFile}
    # A GUI's stale inherited credentials must not choose the target.
    $env:MARIADB_HOST='wrong-host';$env:MARIADB_PORT='1';$env:MARIADB_DATABASE='wrong_db';$env:MARIADB_USER='wrong-user';$env:MARIADB_PASSWORD='wrong-ambient-secret';$env:MYSQL_PWD='wrong-ambient-secret';$env:MARIADB_EXE=$client
    $init=& git -C $stage init 2>&1;if($LASTEXITCODE -ne 0){throw 'Fixture Git init failed.'}
    $failed=Commit-Fixture
    Check 'Unmigrated commit remains blocked' ($failed.code -ne 0 -and $failed.text.Contains('Pending database migrations'))
    $planned=Child @('-PlanOnly')
    Check 'One-command plan reads file credentials' ($planned.code -eq 0 -and $planned.text.Contains('209901010000_EnvUpdateFixture.sql'))
    Check 'Planning creates no backups' (-not (Test-Path -LiteralPath $backups))
    Check 'Planning applies no SQL' ([int](Query "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='env_update_witness';") -eq 0)
    # The client is deliberately an invalid dump tool; a failed backup must block migration.
    $env:MARIADB_DUMP_EXE=$client
    $failed=Child @()
    Check 'Failed backup blocks migration' ($failed.code -ne 0 -and $failed.text.Contains('No migrations were started'))
    Check 'No SQL after backup failure' ([int](Query "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='env_update_witness';") -eq 0)
    $env:MARIADB_DUMP_EXE=$null
    $updated=Child @()
    if($updated.code -ne 0){throw ('Generated-fixture update failed: '+$updated.text)}
    Check 'Update succeeds with .env credentials' ($updated.code -eq 0)
    Check 'Pending SQL applied once' ((Query 'SELECT id FROM env_update_witness;') -eq '42')
    Check 'Original rows retained' ((Query 'SELECT id FROM before_update;') -eq '1')
    $records=@(Get-ChildItem -LiteralPath $backups -Recurse -Filter backup.json -File)
    Check 'Completed backup recorded' ($records.Count -eq 1)
    $record=Get-Content -LiteralPath $records[0].FullName -Raw | ConvertFrom-Json
    $dumpFile=Join-Path $records[0].DirectoryName 'database.sql'
    Check 'Backup hash matches SQL bytes' ($record.sha256 -ceq (Get-FileHash -LiteralPath $dumpFile -Algorithm SHA256).Hash)
    Check 'Backup predates pending SQL' (-not ((Get-Content -LiteralPath $dumpFile -Raw).Contains('CREATE TABLE `env_update_witness`')))
    $again=Child @()
    Check 'Repeat update is a no-op' ($again.code -eq 0 -and $again.text.Contains('already up to date'))
    Check 'No extra completed backup without pending SQL' (@(Get-ChildItem -LiteralPath $backups -Recurse -Filter backup.json -File).Count -eq 1)
    $committed=Commit-Fixture
    Check 'Actual Git commit succeeds using .env despite stale ambient credentials' ($committed.code -eq 0)
    $cutoff=(Get-Content -LiteralPath (Join-Path $stage 'database/schema/bootstrap.json') -Raw | ConvertFrom-Json).throughMigration
    Check 'Hook exports migrated schema' ($cutoff -ceq '209901010000')
    $tracked=& git -C $stage ls-files
    Check 'Credentials and backup files not staged by hook' (-not ($tracked -match '(^|/)\.env$|database\.sql|backup\.json'))
    Check 'Parent environment not overwritten by child wrappers' ($env:MARIADB_HOST -ceq 'wrong-host' -and $env:MARIADB_PASSWORD -ceq 'wrong-ambient-secret')
    Write-Host "$checks development .env update/backup/Git-hook checks passed."
}
finally {
    if($database -cnotmatch '^orchids_env_[0-9a-f]{32}$'){throw 'Unsafe fixture cleanup.'}
    Query "DROP DATABASE IF EXISTS ``$database``;" -Global | Out-Null
    if($fixtureAccountCreated){
        if($fixtureUser -cnotmatch '^orchid_env_[0-9a-f]{32}$'){throw 'Unsafe fixture account cleanup.'}
        Query "DROP USER IF EXISTS '$fixtureUser'@'%';" -Global | Out-Null
    }
    $envFile=Join-Path $stage '.env'
    if(Test-Path -LiteralPath $envFile){Remove-Item -LiteralPath $envFile -Force}
    foreach($name in $previous.Keys){[Environment]::SetEnvironmentVariable($name,$previous[$name])}
    Write-Host "Disposable development fixture retained: $root"
}
