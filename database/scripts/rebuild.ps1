# Creates an absent database or fills an existing EMPTY database. Never drops it.
param(
    [Parameter(Mandatory)][string]$ConfirmDatabase,
    [string]$SchemaRoot = (Join-Path $PSScriptRoot '../schema'),
    [string]$MariaDbExe = $env:MARIADB_EXE
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Schema-Baseline.ps1')
foreach ($name in @('MARIADB_HOST', 'MARIADB_PORT', 'MARIADB_USER', 'MARIADB_PASSWORD', 'MARIADB_DATABASE', 'MARIADB_CHARSET', 'MARIADB_COLLATION')) {
    if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($name))) { throw "Required environment variable '$name' is not set." }
}
$db = $env:MARIADB_DATABASE
if ($db -cnotmatch '^[A-Za-z0-9_]{1,64}$' -or $ConfirmDatabase -cne $db) {
    throw 'ConfirmDatabase must exactly match the explicit MARIADB_DATABASE identifier.'
}
if ($env:MARIADB_CHARSET -cne 'utf8mb4' -or $env:MARIADB_COLLATION -cne 'utf8mb4_unicode_ci') {
    throw 'Schema creation requires utf8mb4 and utf8mb4_unicode_ci.'
}
$portNumber = 0
if (-not [int]::TryParse($env:MARIADB_PORT, [ref]$portNumber) -or $portNumber -lt 1 -or $portNumber -gt 65535) { throw 'Invalid MARIADB_PORT.' }
$MariaDbExe = Resolve-MariaDbTool -Override $MariaDbExe
$SchemaRoot = (Resolve-Path -LiteralPath $SchemaRoot).Path
$plan = Read-SchemaManifest $SchemaRoot
$clientArgs = @('--protocol=TCP', "--host=$env:MARIADB_HOST", "--port=$portNumber", "--user=$env:MARIADB_USER",
    '--connect-timeout=5', '--default-character-set=utf8mb4', '--batch', '--skip-column-names', '--abort-source-on-error')
$previousPassword = $env:MYSQL_PWD
try {
    $env:MYSQL_PWD = $env:MARIADB_PASSWORD
    function Invoke-SchemaSql([string]$Sql, [switch]$UseDatabase) {
        $arguments = $clientArgs
        if ($UseDatabase) { $arguments += "--database=$db" }
        $output = $Sql | & $MariaDbExe @arguments 2>&1
        if ($LASTEXITCODE -ne 0) { throw "Schema command failed (exit $LASTEXITCODE): $($output -join "`n")" }
        $output
    }
    $exists = @(Invoke-SchemaSql "SELECT SCHEMA_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME='$db';")
    if ($exists.Count) {
        $count = @(Invoke-SchemaSql "SELECT (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA='$db') + (SELECT COUNT(*) FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA='$db');")
        if ($count.Count -ne 1 -or [int]$count[0] -ne 0) { throw 'Target database is not empty. Creation does not overwrite, repair or upgrade existing data.' }
        $collation = @(Invoke-SchemaSql "SELECT DEFAULT_COLLATION_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME='$db';")
        if ($collation.Count -ne 1 -or $collation[0] -cne 'utf8mb4_unicode_ci') { throw 'Existing empty target has an incompatible collation.' }
    }
    else {
        Invoke-SchemaSql "CREATE DATABASE ``$db`` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" | Out-Null
    }
    Write-Host "Creating schema on $($env:MARIADB_HOST):$portNumber/$db (no DROP and no migration replay)."
    foreach ($item in $plan.files) {
        Write-Host "Importing $($item.path)"
        $sql = Get-Content -LiteralPath (Join-Path $SchemaRoot $item.path) -Raw -Encoding utf8
        Invoke-SchemaSql ("SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;`n" + $sql + "`n") -UseDatabase | Out-Null
    }
    # Completion marker is last: partial DDL must never look like completed setup.
    Invoke-SchemaSql "INSERT INTO schemaversion (scriptName, checksum) VALUES ('baseline:v1:$($plan.throughMigration)', '$($plan.manifestChecksum)');" -UseDatabase | Out-Null
    Write-Host 'Schema creation completed, including required seeds and baseline.'
}
finally { $env:MYSQL_PWD = $previousPassword }
