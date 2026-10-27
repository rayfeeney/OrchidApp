param(
    [string]$RepoRoot=(Join-Path $PSScriptRoot '../..'),
    [string]$MariaDbRuntimeRoot=(Join-Path $env:ProgramW6432 'MariaDB 10.11'),
    [int]$Port=53342,
    [string]$FixtureParent=[IO.Path]::GetTempPath()
)
$ErrorActionPreference='Stop';$PSNativeCommandUseErrorActionPreference=$false
$RepoRoot=(Resolve-Path -LiteralPath $RepoRoot).Path
$MariaDbRuntimeRoot=(Resolve-Path -LiteralPath $MariaDbRuntimeRoot).Path
if (Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue) { throw 'Disposable port occupied; no database was touched.' }
. (Join-Path $RepoRoot 'app/tools/Installer-Snapshot.ps1')
# Controlled inventory is confined to this test, avoiding unrelated host services.
# The actual running fixture database must still be rejected by native file locks.
function Get-CimInstance { @() }
$root=Join-Path (Resolve-Path -LiteralPath $FixtureParent).Path ('orchids-c18-'+[guid]::NewGuid().ToString('N').Substring(0,12))
$app=Join-Path $root 'old app';$persistent=Join-Path $root 'persistent';$data=Join-Path $persistent 'data/mariadb'
$database='orchids_c18_'+[guid]::NewGuid().ToString('N');$process=$null;$activeData=$null;$checks=0
$null=New-Item -ItemType Directory -Path $app,(Split-Path -Parent $data) -Force
$prior=@{};foreach ($name in @('MARIADB_HOST','MARIADB_PORT','MARIADB_DATABASE','MARIADB_USER','MARIADB_PASSWORD','MARIADB_CHARSET','MARIADB_COLLATION','MYSQL_PWD')) { $prior[$name]=[Environment]::GetEnvironmentVariable($name) }
$client=Join-Path $MariaDbRuntimeRoot 'bin/mariadb.exe';$admin=Join-Path $MariaDbRuntimeRoot 'bin/mariadb-admin.exe'
function Check([string]$Name,[bool]$Pass) { if (-not $Pass) { throw "Check failed: $Name" };$script:checks++ }
function Query([string]$Sql) {
    $result=& $client --no-defaults --protocol=TCP --host=127.0.0.1 "--port=$Port" --user=root --connect-timeout=2 --default-character-set=utf8mb4 --batch --skip-column-names "--execute=$Sql" 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Disposable query failed: $($result -join ' ')" };$result
}
function Start-Fixture([string]$Directory) {
    if (-not (Test-InstallerChild $Directory $root)) { throw 'Fixture data path escaped its generated root.' }
    $script:process=Start-Process -FilePath (Join-Path $MariaDbRuntimeRoot 'bin/mariadbd.exe') -ArgumentList "--no-defaults --basedir=`"$MariaDbRuntimeRoot`" --datadir=`"$Directory`" --port=$Port --bind-address=127.0.0.1 --event-scheduler=OFF --console" -PassThru -WindowStyle Hidden -RedirectStandardOutput (Join-Path $root ('server-'+[guid]::NewGuid().ToString('N')+'.log')) -RedirectStandardError (Join-Path $root ('server-error-'+[guid]::NewGuid().ToString('N')+'.log'))
    $null=$process.Handle;$script:activeData=$Directory
    for ($attempt=0;$attempt -lt 25;$attempt++) {
        if ($process.HasExited) { throw 'Disposable database exited; inspect retained logs.' }
        try {
            $actual=[string](Query 'SELECT @@datadir;')
            if ((Get-InstallerFullPath $actual) -ine (Get-InstallerFullPath $Directory)) { throw 'Disposable database identity mismatch.' }
            return
        } catch { Start-Sleep -Seconds 1 }
    }
    throw 'Disposable database did not become ready.'
}
function Stop-Fixture {
    if ($process -and -not $process.HasExited) {
        if ((Get-InstallerFullPath ([string](Query 'SELECT @@datadir;'))) -ine (Get-InstallerFullPath $activeData)) { throw 'Shutdown refused: fixture identity mismatch.' }
        & $admin --no-defaults --protocol=TCP --host=127.0.0.1 "--port=$Port" --user=root shutdown | Out-Null
        if ($LASTEXITCODE -ne 0 -or -not $process.WaitForExit(30000) -or $process.ExitCode -ne 0) { throw 'Disposable database did not stop cleanly.' }
    }
}
try {
    $env:MYSQL_PWD='isolated-c18-test'
    & (Join-Path $MariaDbRuntimeRoot 'bin/mariadb-install-db.exe') "--datadir=$data" --password=isolated-c18-test "--port=$Port" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Disposable database initialization failed.' }
    Start-Fixture $data
    $env:MARIADB_HOST='127.0.0.1';$env:MARIADB_PORT=[string]$Port;$env:MARIADB_DATABASE=$database;$env:MARIADB_USER='root';$env:MARIADB_PASSWORD='isolated-c18-test';$env:MARIADB_CHARSET='utf8mb4';$env:MARIADB_COLLATION='utf8mb4_unicode_ci'
    & (Join-Path $RepoRoot 'database/scripts/rebuild.ps1') -ConfirmDatabase $database | Out-Null
    Query "CALL $database.spAddGenus('C18 synthetic','fixture'); SET @taxon=(SELECT MIN(taxonId) FROM $database.taxon); CALL $database.spAddPlant(@taxon,'2020-01-01','fixture','Before upgrade','snapshot recovery');" | Out-Null
    $ledger=[string]::Join("`n",@(Query "SELECT CONCAT(scriptName,':',checksum) FROM $database.schemaversion ORDER BY scriptName;"))
    $null=New-Item -ItemType Directory -Path (Join-Path $persistent 'uploads/plants/1') -Force
    Copy-Item -LiteralPath (Join-Path $RepoRoot 'tests/DevelopmentNative.Checks/fixtures/orientation-6.jpg') -Destination (Join-Path $persistent 'uploads/plants/1/main.jpg')
    '{"synthetic":"before upgrade"}' | Set-Content (Join-Path $persistent 'launcher-settings.json')
    'old application version' | Set-Content (Join-Path $app 'version.txt')
    $rejected=$false;try { New-InstallerSnapshot $app $persistent 0 | Out-Null }catch{$rejected=$true}
    Check 'Native running database file locks prevent capture' $rejected
    Stop-Fixture
    $archive=New-InstallerSnapshot $app $persistent 0
    Check 'Stopped real MariaDB snapshot verifies' ($null -ne (Read-InstallerSnapshot $archive))
    Start-Fixture $data
    Query "UPDATE $database.plant SET plantName='Partial failed upgrade'; CREATE TABLE $database.c18_partial_ddl(id INT);" | Out-Null
    Stop-Fixture
    'changed photo' | Set-Content (Join-Path $persistent 'uploads/plants/1/main.jpg')
    '{"synthetic":"partial"}' | Set-Content (Join-Path $persistent 'launcher-settings.json')
    'new partial application version' | Set-Content (Join-Path $app 'version.txt')
    $destination=Join-Path $root 'recovered';$null=Expand-InstallerSnapshot $archive $destination
    Start-Fixture (Join-Path $destination 'persistent/data/mariadb')
    Check 'Recovered database restores pre-upgrade row' (([string](Query "SELECT plantName FROM $database.plant LIMIT 1;")).Trim() -eq 'Before upgrade')
    Check 'Partial later DDL absent from recovered database' ([int](Query "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA='$database' AND TABLE_NAME='c18_partial_ddl';") -eq 0)
    Check 'Recovered schema ledger retains original identity' ([string]::Join("`n",@(Query "SELECT CONCAT(scriptName,':',checksum) FROM $database.schemaversion ORDER BY scriptName;")) -ceq $ledger)
    Check 'Recovered photo matches original paired image' ((Get-FileHash (Join-Path $destination 'persistent/uploads/plants/1/main.jpg')).Hash -eq (Get-FileHash (Join-Path $RepoRoot 'tests/DevelopmentNative.Checks/fixtures/orientation-6.jpg')).Hash)
    Check 'Recovered settings are from same snapshot' ((Get-Content (Join-Path $destination 'persistent/launcher-settings.json') -Raw).Trim() -eq '{"synthetic":"before upgrade"}')
    Check 'Recovered application is previous version' ((Get-Content (Join-Path $destination 'application/version.txt') -Raw).Trim() -eq 'old application version')
    Check 'Failed installation evidence was not overwritten' ((Get-Content (Join-Path $app 'version.txt') -Raw).Trim() -eq 'new partial application version')
    Stop-Fixture
    Write-Host "$checks real MariaDB installer snapshot recovery checks passed. Fixture: $root"
}
finally {
    try { Stop-Fixture } finally { foreach ($name in $prior.Keys) { [Environment]::SetEnvironmentVariable($name,$prior[$name]) };Write-Host "Disposable C18 fixture retained: $root" }
}
