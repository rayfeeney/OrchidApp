# Prerequisite check and local Git hook activation; never creates or migrates a DB.
$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSVersion.Major -lt 7) { throw 'Run setup with PowerShell 7 (pwsh).' }
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
. (Join-Path $repositoryRoot 'database/scripts/Schema-Baseline.ps1')
. (Join-Path $PSScriptRoot 'configure.ps1')
foreach ($command in @('git','dotnet','pwsh')) {
    Get-Command $command -CommandType Application -ErrorAction Stop | Select-Object -First 1 | Out-Null
}
$sdkVersions = & dotnet --list-sdks
if ($LASTEXITCODE -ne 0 -or -not ($sdkVersions -match '^(8|9|[1-9][0-9])\.')) { throw '.NET SDK 8 or newer is required (dotnet --list-sdks).' }
$runtimeVersions = & dotnet --list-runtimes
foreach ($runtime in @('Microsoft.NETCore.App','Microsoft.AspNetCore.App')) {
    if (-not ($runtimeVersions -match ('^' + [regex]::Escape($runtime) + ' 8\.'))) { throw "The .NET 8 runtime $runtime is required." }
}
$client = Resolve-MariaDbTool -Override $env:MARIADB_EXE
$dump = Resolve-MariaDbTool -Name 'mariadb-dump' -Override $env:MARIADB_DUMP_EXE
foreach ($tool in @($client,$dump)) {
    $versionText = & $tool --no-defaults --version
    if ($LASTEXITCODE -ne 0 -or $versionText -notmatch '10\.11\..*MariaDB|MariaDB.*10\.11\.') { throw 'MariaDB 10.11 client and dump tools are required.' }
}
$previousPassword = $env:MYSQL_PWD
try {
    $env:MYSQL_PWD = $env:MARIADB_PASSWORD
    $serverVersion = & $client --no-defaults --protocol=TCP "--host=$env:MARIADB_HOST" "--port=$env:MARIADB_PORT" "--user=$env:MARIADB_USER" --connect-timeout=5 --batch --skip-column-names '--execute=SELECT VERSION();'
    if ($LASTEXITCODE -ne 0 -or $serverVersion -notmatch '^10\.11\..*MariaDB') { throw 'Could not verify the explicit target as MariaDB 10.11.' }
}
finally { $env:MYSQL_PWD = $previousPassword }
& git -C $repositoryRoot config --local core.hooksPath .githooks
if ($LASTEXITCODE -ne 0) { throw 'Could not configure hooks: use a Git checkout.' }
$hooks = & git -C $repositoryRoot config --local --get core.hooksPath
if ($LASTEXITCODE -ne 0 -or $hooks -ne '.githooks') { throw 'Git hook configuration failed.' }
Write-Host 'Prerequisites verified; repository hooks activated. No database objects changed.'
Write-Host 'Git commits read database credentials from the repository .env through the development export wrapper.'
