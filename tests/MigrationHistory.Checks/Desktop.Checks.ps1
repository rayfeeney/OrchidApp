# Windows packaged-path smoke checks. Requires a Release web build, installed
# MariaDB clients and explicit credentials for a DISPOSABLE test server.
param([string]$RepoRoot = (Join-Path $PSScriptRoot '../..'))
$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { throw 'These Desktop packaging checks require Windows; use Policy.Checks.ps1 and Database.Checks.ps1 on Linux.' }
$RepoRoot=(Resolve-Path -LiteralPath $RepoRoot).Path
. (Join-Path $RepoRoot 'database/scripts/Migration-History.ps1')
foreach ($name in @('MARIADB_HOST','MARIADB_PORT','MARIADB_USER','MARIADB_PASSWORD')) {
    if (-not [Environment]::GetEnvironmentVariable($name)) { throw "Explicit $name required for an isolated test server." }
}
$client=Resolve-MariaDbTool -Override $env:MARIADB_EXE
$db='orchids_desktop_' + [guid]::NewGuid().ToString('N')
$stage=Join-Path ([IO.Path]::GetTempPath()) $db
$build=Join-Path $RepoRoot 'src/OrchidApp.Web/bin/Release/net8.0'
if (-not (Test-Path (Join-Path $build 'OrchidApp.Web.dll'))) { throw 'Build the web app in Release first.' }
$prior=@{}
foreach ($name in @('MARIADB_DATABASE','MARIADB_CHARSET','MARIADB_COLLATION','MYSQL_PWD')) { $prior[$name]=[Environment]::GetEnvironmentVariable($name) }
$checks=0
function Check([string]$Name,[bool]$Pass) { if (-not $Pass) { throw "Check failed: $Name" }; $script:checks++ }
function Query([string]$Sql,[switch]$Global) {
    [string[]]$arguments=@('--no-defaults','--protocol=TCP',"--host=$env:MARIADB_HOST","--port=$env:MARIADB_PORT","--user=$env:MARIADB_USER",'--batch','--skip-column-names')
    if (-not $Global) { $arguments+="--database=$db" }
    $result=$Sql | & $client @arguments 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Fixture query failed: $($result -join "`n")" }; $result
}
function Start-StagedApp([string]$Expected,[bool]$ShouldFail=$false) {
    $start=[Diagnostics.ProcessStartInfo]::new('dotnet')
    $start.ArgumentList.Add((Join-Path $stage 'OrchidApp.Web.dll'))
    $start.WorkingDirectory=$stage; $start.UseShellExecute=$false; $start.CreateNoWindow=$true
    $start.RedirectStandardOutput=$true; $start.RedirectStandardError=$true
    $connection=[Data.Common.DbConnectionStringBuilder]::new()
    $connection['Server']=$env:MARIADB_HOST; $connection['Port']=$env:MARIADB_PORT; $connection['User']=$env:MARIADB_USER
    $connection['Password']=$env:MARIADB_PASSWORD; $connection['Database']=$db
    $start.Environment['ASPNETCORE_ENVIRONMENT']='Desktop'
    $start.Environment['ConnectionStrings__DefaultConnection']=$connection.ConnectionString
    $start.Environment['ConnectionStrings__OrchidDb']=$connection.ConnectionString
    $start.Environment['ORCHIDAPP_UPLOAD_ROOT']=(Join-Path $stage 'uploads')
    $start.Environment['ASPNETCORE_URLS']='http://127.0.0.1:0'
    $process=[Diagnostics.Process]::Start($start)
    $stdout=$process.StandardOutput.ReadToEndAsync(); $stderr=$process.StandardError.ReadToEndAsync()
    $exited=$process.WaitForExit(6000)
    if (-not $exited) { $process.Kill($true); $process.WaitForExit() }
    $text=$stdout.GetAwaiter().GetResult()+$stderr.GetAwaiter().GetResult()
    if ($text.IndexOf($Expected,[StringComparison]::OrdinalIgnoreCase) -lt 0 -or
        ($ShouldFail -and (-not $exited -or $process.ExitCode -eq 0)) -or (-not $ShouldFail -and $exited)) {
        throw "Unexpected Desktop outcome for '$Expected': $text"
    }
    $script:checks++
}
try {
    $env:MARIADB_DATABASE=$db; $env:MARIADB_CHARSET='utf8mb4'; $env:MARIADB_COLLATION='utf8mb4_unicode_ci'; $env:MYSQL_PWD=$env:MARIADB_PASSWORD
    New-Item -ItemType Directory -Path $stage | Out-Null
    Copy-Item -Path (Join-Path $build '*') -Destination $stage -Recurse
    $clientBin=Join-Path $stage 'runtime/mariadb/win-x64/bin'
    New-Item -ItemType Directory -Path $clientBin,(Join-Path $stage 'tools'),(Join-Path $stage 'database') | Out-Null
    Copy-Item -LiteralPath $client -Destination (Join-Path $clientBin 'mariadb.exe')
    Copy-Item -Path (Join-Path (Split-Path $client) '*.dll') -Destination $clientBin
    Copy-Item -LiteralPath (Join-Path $RepoRoot 'database/schema') -Destination (Join-Path $stage 'database/schema') -Recurse
    $setupOutput=& pwsh -NoProfile -File (Join-Path $RepoRoot 'database/scripts/rebuild.ps1') -ConfirmDatabase $db 2>&1
    if ($LASTEXITCODE -ne 0) { throw ($setupOutput -join "`n") }
    # Successful-backup simulation is isolated to this disposable test stage.
    # It does not certify operational backups and is never shipped as app code.
    [IO.File]::WriteAllText((Join-Path $stage 'tools/backup-orchidapp.ps1'), "'synthetic' | Add-Content (Join-Path `$PSScriptRoot '../backup-count.txt'); exit 0", [Text.UTF8Encoding]::new($false))
    Start-StagedApp 'Database is up to date.'
    Query 'ALTER TABLE schemaversion ENGINE=MyISAM;' | Out-Null
    Start-StagedApp 'schemaversion must use InnoDB' $true
    Query 'ALTER TABLE schemaversion ENGINE=InnoDB;' | Out-Null
    $folder=Join-Path $stage 'database/migrations'
    New-Item -ItemType Directory -Path $folder | Out-Null
    $first=Join-Path $folder '209901010000_Future.sql'
    $sql='CREATE TABLE desktop_witness(id INT PRIMARY KEY); INSERT INTO desktop_witness VALUES(1);'
    [IO.File]::WriteAllText($first,$sql,[Text.UTF8Encoding]::new($false))
    Start-StagedApp 'Database updates applied: 1'
    Start-StagedApp 'Database is up to date.'
    Check 'Once-only SQL and backup' (([int](Query 'SELECT COUNT(*) FROM desktop_witness;')) -eq 1 -and @(Get-Content (Join-Path $stage 'backup-count.txt')).Count -eq 1)
    foreach ($name in @('209902010000_One.sql','209902010000_Two.sql')) { [IO.File]::WriteAllText((Join-Path $folder $name),'SELECT 1;') }
    Start-StagedApp 'Duplicate migration timestamp' $true
    foreach ($name in @('209902010000_One.sql','209902010000_Two.sql')) { Remove-Item -LiteralPath (Join-Path $folder $name) }
    [IO.File]::AppendAllText($first,'-- tamper')
    Start-StagedApp 'checksum changed' $true
    Check 'Preflight rejects before backup' (@(Get-Content (Join-Path $stage 'backup-count.txt')).Count -eq 1)
    [IO.File]::WriteAllText($first,$sql,[Text.UTF8Encoding]::new($false))
    $failed=Join-Path $folder '209902010000_Failure.sql'
    [IO.File]::WriteAllText($failed,"CREATE TABLE desktop_partial(id INT); SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Intentional Desktop fixture failure';",[Text.UTF8Encoding]::new($false))
    Start-StagedApp 'SQL may be partially applied' $true
    Check 'Desktop failure retains pending marker, not success' ((Query "SELECT checksum FROM schemaversion WHERE scriptName='migration:pending';") -eq (Get-MigrationFileChecksum $failed) -and ([int](Query "SELECT COUNT(*) FROM schemaversion WHERE scriptName='209902010000_Failure.sql';")) -eq 0)
    Start-StagedApp 'incomplete or running migration' $true
    Check 'Blocked retry does not run another backup' (@(Get-Content (Join-Path $stage 'backup-count.txt')).Count -eq 2)
    Write-Host "$checks actual Desktop migration checks passed."
}
finally {
    if ($db -cnotmatch '^orchids_desktop_[a-f0-9]{32}$') { throw 'Unsafe fixture target.' }
    Query "DROP DATABASE IF EXISTS ``$db``;" -Global | Out-Null
    foreach ($name in $prior.Keys) { [Environment]::SetEnvironmentVariable($name,$prior[$name]) }
    # Retain the unique stage for inspection; it is excluded from deliveries.
}
