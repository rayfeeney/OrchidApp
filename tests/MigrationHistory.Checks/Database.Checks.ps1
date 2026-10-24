param([string]$RepoRoot = (Join-Path $PSScriptRoot '../..'))
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
. (Join-Path $RepoRoot 'database/scripts/Migration-History.ps1')
foreach ($name in @('MARIADB_HOST','MARIADB_PORT','MARIADB_USER','MARIADB_PASSWORD')) {
    if (-not [Environment]::GetEnvironmentVariable($name)) { throw "Explicit $name required for an isolated test server." }
}
$client = Resolve-MariaDbTool -Override $env:MARIADB_EXE
$pwsh = (Get-Command pwsh -CommandType Application | Select-Object -First 1).Source
$db = 'orchids_migrations_' + [guid]::NewGuid().ToString('N')
$temporary = Join-Path ([IO.Path]::GetTempPath()) $db
New-Item -ItemType Directory -Path $temporary | Out-Null
$prior = @{}
foreach ($name in @('MARIADB_DATABASE','MARIADB_CHARSET','MARIADB_COLLATION','MYSQL_PWD')) { $prior[$name] = [Environment]::GetEnvironmentVariable($name) }
$checks = 0; $caseNumber = 0
function Check([string]$Name,[bool]$Pass) { if (-not $Pass) { throw "Check failed: $Name" }; $script:checks++ }
function Query([string]$Sql,[switch]$Global) {
    [string[]]$arguments = @('--no-defaults','--protocol=TCP',"--host=$env:MARIADB_HOST","--port=$env:MARIADB_PORT","--user=$env:MARIADB_USER",'--batch','--skip-column-names')
    if (-not $Global) { $arguments += "--database=$db" }
    $output = $Sql | & $client @arguments 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Fixture query failed: $($output -join "`n")" }
    $output
}
function Reset-Fixture {
    if ($db -cnotmatch '^orchids_migrations_[a-f0-9]{32}$') { throw 'Unsafe fixture target.' }
    Query "DROP DATABASE IF EXISTS ``$db``; CREATE DATABASE ``$db`` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" -Global | Out-Null
    Query (Get-Content -LiteralPath (Join-Path $RepoRoot 'database/schema/tables/schemaversion.sql') -Raw -Encoding utf8) | Out-Null
    Query "INSERT INTO schemaversion(scriptName,checksum) VALUES ('baseline:v1:202606041820','$('a'*64)'); CREATE TABLE witness(id INT PRIMARY KEY);" | Out-Null
    $script:caseNumber++
    $folder = Join-Path $temporary ("case $caseNumber")
    New-Item -ItemType Directory -Path $folder | Out-Null
    $folder
}
function SqlFile([string]$Folder,[string]$Name,[string]$Sql) {
    $path = Join-Path $Folder $Name
    [IO.File]::WriteAllText($path,$Sql,[Text.UTF8Encoding]::new($false))
    $path
}
function Run([string]$Script,[string[]]$Arguments,[string]$ErrorText = '') {
    $output = & $pwsh -NoProfile -File $Script @Arguments 2>&1
    $code = $LASTEXITCODE
    $text = $output -join "`n"
    if ($ErrorText) {
        if ($code -eq 0 -or $text.IndexOf($ErrorText,[StringComparison]::OrdinalIgnoreCase) -lt 0) { throw "Expected '$ErrorText'; exit=$code; $text" }
    }
    elseif ($code -ne 0) { throw "Unexpected failure (exit $code): $text" }
    $script:checks++
}
try {
    $env:MARIADB_DATABASE=$db; $env:MARIADB_CHARSET='utf8mb4'; $env:MARIADB_COLLATION='utf8mb4_unicode_ci'; $env:MYSQL_PWD=$env:MARIADB_PASSWORD
    foreach ($route in @('Apply-Migrations.ps1','Apply-MariaDBMigrations.ps1')) {
        $scriptPath=Join-Path $RepoRoot "database/scripts/$route"
        $folder=Reset-Fixture
        $null=SqlFile $folder '202604010000_Historic.sql' "SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Historical SQL must not execute';"
        $future=SqlFile $folder '209901010000_Future.sql' 'INSERT INTO witness VALUES(1);'
        Run $scriptPath @('-MigrationFolder',$folder,'-PlanOnly')
        Check 'PlanOnly writes neither SQL nor marker' (([int](Query 'SELECT COUNT(*) FROM witness;')) -eq 0 -and ([int](Query "SELECT COUNT(*) FROM schemaversion WHERE scriptName='migration:pending';")) -eq 0)
        Run $scriptPath @('-MigrationFolder',$folder)
        Run $scriptPath @('-MigrationFolder',$folder)
        Check 'Future applied once' (([int](Query 'SELECT COUNT(*) FROM witness;')) -eq 1)
        Check 'Baseline preserved and no pending marker remains' (([int](Query "SELECT COUNT(*) FROM schemaversion WHERE scriptName='baseline:v1:202606041820';")) -eq 1 -and ([int](Query "SELECT COUNT(*) FROM schemaversion WHERE scriptName='migration:pending';")) -eq 0)
        [IO.File]::AppendAllText($future,'-- changed')
        $null=SqlFile $folder '209902010000_Later.sql' 'INSERT INTO witness VALUES(2);'
        Run $scriptPath @('-MigrationFolder',$folder) 'checksum changed'
        Check 'Full validation prevents later SQL' (([int](Query 'SELECT COUNT(*) FROM witness;')) -eq 1)

        $folder=Reset-Fixture
        $null=SqlFile $folder '209901010000_First.sql' 'INSERT INTO witness VALUES(1);'
        $null=SqlFile $folder '209901010000_Duplicate.sql' 'INSERT INTO witness VALUES(2);'
        Run $scriptPath @('-MigrationFolder',$folder) 'Duplicate migration timestamp'
        Check 'Duplicate preflight has no SQL side effects' (([int](Query 'SELECT COUNT(*) FROM witness;')) -eq 0)

        $folder=Reset-Fixture
        $earlier=SqlFile $folder '209901010000_Backdated.sql' 'INSERT INTO witness VALUES(1);'
        $applied=SqlFile $folder '209902010000_Applied.sql' 'SELECT 1;'
        $digest=Get-MigrationFileChecksum $applied
        Query "INSERT INTO schemaversion(scriptName,checksum) VALUES ('209902010000_Applied.sql','$digest');" | Out-Null
        Run $scriptPath @('-MigrationFolder',$folder) 'Backdated or out-of-order'
        Remove-Item -LiteralPath $applied
        Run $scriptPath @('-MigrationFolder',$folder) 'file is missing'
        Check 'Backdated/missing history does not write SQL' (([int](Query 'SELECT COUNT(*) FROM witness;')) -eq 0)

        $folder=Reset-Fixture
        $historic=SqlFile $folder '202604010000_Historic.sql' 'SELECT 1;'
        $digest=Get-MigrationFileChecksum $historic
        Query "DELETE FROM schemaversion; INSERT INTO schemaversion(scriptName,checksum) VALUES ('baseline','baseline'),('202604010000_Historic.sql','$digest');" | Out-Null
        $null=SqlFile $folder '209901010000_Future.sql' 'INSERT INTO witness VALUES(1);'
        Run $scriptPath @('-MigrationFolder',$folder)
        Check 'Legacy row preserved' ((Query "SELECT checksum FROM schemaversion WHERE scriptName='baseline';") -eq 'baseline')

        $folder=Reset-Fixture
        $failed=SqlFile $folder '209901010000_Fails.sql' "CREATE TABLE partial_ddl(id INT); INSERT INTO witness VALUES(1); SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Intentional test failure'; INSERT INTO witness VALUES(2);"
        Run $scriptPath @('-MigrationFolder',$folder) 'SQL may be partially applied'
        Check 'DDL can persist before failure; later statements stop' (([int](Query "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='partial_ddl';")) -eq 1 -and ([int](Query 'SELECT COUNT(*) FROM witness;')) -eq 1)
        Check 'Failure leaves pending marker and no applied row' ((Query "SELECT checksum FROM schemaversion WHERE scriptName='migration:pending';") -eq (Get-MigrationFileChecksum $failed) -and ([int](Query "SELECT COUNT(*) FROM schemaversion WHERE scriptName='209901010000_Fails.sql';")) -eq 0)
        Run $scriptPath @('-MigrationFolder',$folder) 'incomplete or running migration'
        Run $scriptPath @('-MigrationFolder',$folder,'-PlanOnly') 'incomplete or running migration'
        Check 'Blocked retry preserves partial state' (([int](Query 'SELECT COUNT(*) FROM witness;')) -eq 1)
    }

    # The last route left a pending marker. Export must fail before changing
    # canonical files, even when the partial database has incompatible objects.
    $partialSource=Join-Path $temporary 'partial export source'
    New-Item -ItemType Directory -Path (Join-Path $partialSource 'database') | Out-Null
    foreach ($directory in @('scripts','schema','checksums')) { Copy-Item -LiteralPath (Join-Path $RepoRoot "database/$directory") -Destination (Join-Path $partialSource "database/$directory") -Recurse }
    $before=@(Get-ChildItem (Join-Path $partialSource 'database/schema') -Recurse -File | Sort-Object FullName | Get-FileHash -Algorithm SHA256 | ForEach-Object Hash) -join '|'
    Run (Join-Path $partialSource 'database/scripts/Export-MariaDBSchema.ps1') @() 'incomplete or running migration'
    $after=@(Get-ChildItem (Join-Path $partialSource 'database/schema') -Recurse -File | Sort-Object FullName | Get-FileHash -Algorithm SHA256 | ForEach-Object Hash) -join '|'
    Check 'Pending migration blocks export before source changes' ($before -eq $after)

    # Both cooperating processes race the same preflight. Exactly one SQL INSERT
    # may occur even if the other runner starts from a stale plan.
    $folder=Reset-Fixture
    Query 'ALTER TABLE schemaversion ENGINE=MyISAM;' | Out-Null
    Run (Join-Path $RepoRoot 'database/scripts/Apply-Migrations.ps1') @('-MigrationFolder',$folder,'-PlanOnly') 'schemaversion must use InnoDB'
    $folder=Reset-Fixture
    $null=SqlFile $folder '209901010000_Concurrent.sql' 'SELECT SLEEP(2); INSERT INTO witness VALUES(1);'
    $processes=@()
    foreach ($route in @('Apply-Migrations.ps1','Apply-MariaDBMigrations.ps1')) {
        $start=[Diagnostics.ProcessStartInfo]::new($pwsh)
        $start.UseShellExecute=$false; $start.CreateNoWindow=$true; $start.RedirectStandardOutput=$true; $start.RedirectStandardError=$true
        foreach ($argument in @('-NoProfile','-File',(Join-Path $RepoRoot "database/scripts/$route"),'-MigrationFolder',$folder)) { $start.ArgumentList.Add($argument) }
        $process=[Diagnostics.Process]::Start($start)
        $processes+=@{ Process=$process; Output=$process.StandardOutput.ReadToEndAsync(); Error=$process.StandardError.ReadToEndAsync() }
    }
    foreach ($entry in $processes) { $entry.Process.WaitForExit(); $null=$entry.Output.GetAwaiter().GetResult(); $null=$entry.Error.GetAwaiter().GetResult() }
    Check 'At least one concurrent runner succeeds' (@($processes | Where-Object { $_.Process.ExitCode -eq 0 }).Count -ge 1)
    Check 'Concurrent execution has one applied row and no pending marker' (([int](Query 'SELECT COUNT(*) FROM witness;')) -eq 1 -and ([int](Query "SELECT COUNT(*) FROM schemaversion WHERE scriptName='migration:pending';")) -eq 0 -and ([int](Query "SELECT COUNT(*) FROM schemaversion WHERE scriptName='209901010000_Concurrent.sql';")) -eq 1)

    # Developer export must run only in a disposable SOURCE copy, never rewrite
    # the caller's canonical schema during integration checks.
    $folder=Reset-Fixture
    Query "DROP DATABASE ``$db``;" -Global | Out-Null
    $fixtureRepo=Join-Path $temporary 'developer source'
    New-Item -ItemType Directory -Path (Join-Path $fixtureRepo 'database') | Out-Null
    foreach ($directory in @('scripts','schema','checksums')) { Copy-Item -LiteralPath (Join-Path $RepoRoot "database/$directory") -Destination (Join-Path $fixtureRepo "database/$directory") -Recurse }
    Run (Join-Path $fixtureRepo 'database/scripts/rebuild.ps1') @('-ConfirmDatabase',$db)
    $null=SqlFile $folder '209901010000_Developer.sql' 'CREATE TABLE developer_export_fixture(id INT);'
    Run (Join-Path $fixtureRepo 'database/scripts/dev-runner.ps1') @('-MigrationFolder',$folder,'-PlanOnly')
    Check 'Developer plan does not export or execute' (([int](Query "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='developer_export_fixture';")) -eq 0)
    Run (Join-Path $fixtureRepo 'database/scripts/dev-runner.ps1') @('-MigrationFolder',$folder)
    $exported=Read-SchemaManifest (Join-Path $fixtureRepo 'database/schema')
    Check 'Developer wrapper exports after successful migration' ($exported.throughMigration -eq '209901010000' -and (Test-Path (Join-Path $fixtureRepo 'database/schema/tables/developer_export_fixture.sql')))
    $previousPort=$env:MARIADB_PORT
    try {
        $env:MARIADB_PORT=''
        Run (Join-Path $RepoRoot 'database/scripts/Apply-Migrations.ps1') @('-MigrationFolder',$folder) 'Explicit MARIADB_PORT'
    }
    finally { $env:MARIADB_PORT=$previousPort }
    Write-Host "$checks migration database checks passed."
}
finally {
    if ($db -cnotmatch '^orchids_migrations_[a-f0-9]{32}$') { throw 'Unsafe fixture target.' }
    Query "DROP DATABASE IF EXISTS ``$db``;" -Global | Out-Null
    foreach ($name in $prior.Keys) { [Environment]::SetEnvironmentVariable($name,$prior[$name]) }
    # Retain uniquely named fixtures for diagnosis, not in the returned ZIP.
}
