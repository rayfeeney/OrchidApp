param(
    [string]$MigrationFolder = (Join-Path $PSScriptRoot '../migrations'),
    [string]$MariaDbExe = $env:MARIADB_EXE,
    [switch]$PlanOnly
)
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
. (Join-Path $PSScriptRoot 'Migration-History.ps1')
foreach ($name in @('MARIADB_HOST','MARIADB_PORT','MARIADB_USER','MARIADB_PASSWORD','MARIADB_DATABASE')) {
    if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($name))) { throw "Explicit $name is required; migration runners do not choose an endpoint." }
}
$portNumber = 0
if (-not [int]::TryParse($env:MARIADB_PORT,[ref]$portNumber) -or $portNumber -lt 1 -or $portNumber -gt 65535) { throw 'Invalid MARIADB_PORT.' }
if ($env:MARIADB_DATABASE -cnotmatch '^[A-Za-z0-9_]{1,64}$') { throw 'Invalid MARIADB_DATABASE identifier.' }
$MariaDbExe = Resolve-MariaDbTool -Override $MariaDbExe
$MigrationFolder = (Resolve-Path -LiteralPath $MigrationFolder).Path
[string[]]$clientArguments = @('--no-defaults','--protocol=TCP',"--host=$env:MARIADB_HOST","--port=$portNumber",
    "--user=$env:MARIADB_USER","--database=$env:MARIADB_DATABASE",'--connect-timeout=5',
    '--default-character-set=utf8mb4','--batch','--skip-column-names','--abort-source-on-error')
$previousPassword = $env:MYSQL_PWD
try {
    $env:MYSQL_PWD = $env:MARIADB_PASSWORD
    function Invoke-MigrationSql([string]$Sql) {
        $output = $Sql | & $MariaDbExe @clientArguments 2>&1
        $exitCode = $LASTEXITCODE
        if ($exitCode -ne 0) { throw "MariaDB command failed (exit $exitCode): $($output -join "`n")" }
        $output
    }
    function Read-MigrationHistory {
        $engine = @(Invoke-MigrationSql "SELECT ENGINE FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='schemaversion';")
        if ($engine.Count -ne 1 -or $engine[0] -ne 'InnoDB') { throw 'schemaversion must use InnoDB and already exist; create from schema or review compatibility before upgrading.' }
        $rows = @(Invoke-MigrationSql 'SELECT scriptName, checksum FROM schemaversion ORDER BY scriptName;')
        $history = @{}
        foreach ($row in $rows) {
            if ([string]::IsNullOrWhiteSpace($row)) { continue }
            $parts = $row -split "`t"
            if ($parts.Count -ne 2 -or $history.ContainsKey($parts[0])) { throw 'Malformed or duplicate migration history row.' }
            $history[$parts[0]] = $parts[1]
        }
        $history
    }
    $files = @(Get-MigrationFiles $MigrationFolder)
    $plan = @(Get-MigrationPlan $files (Read-MigrationHistory))
    Write-Host "Migration target: $($env:MARIADB_HOST):$portNumber/$($env:MARIADB_DATABASE); pending: $($plan.Count)."
    if ($PlanOnly) {
        foreach ($item in $plan) { Write-Host "Pending: $($item.Name) [$($item.Checksum)]" }
        return
    }
    foreach ($item in $plan) {
        # A single durable marker serialises cooperating runners and survives a
        # crash. It is NOT an applied-history row or a claim of DDL rollback.
        $acquired = $false; $sqlStarted = $false
        try {
            Invoke-MigrationSql "INSERT INTO schemaversion(scriptName,checksum) VALUES ('migration:pending','$($item.Checksum)');" | Out-Null
            $acquired = $true
            $current = Read-MigrationHistory
            if ($current['migration:pending'] -ne $item.Checksum) { throw 'Migration ownership marker changed.' }
            $current.Remove('migration:pending')
            $rechecked = @(Get-MigrationPlan @(Get-MigrationFiles $MigrationFolder) $current)
            $selected = @($rechecked | Where-Object { $_.Name -ceq $item.Name })
            if (-not $selected.Count) {
                Invoke-MigrationSql "DELETE FROM schemaversion WHERE scriptName='migration:pending' AND checksum='$($item.Checksum)';" | Out-Null
                continue
            }
            if ($selected[0].Checksum -ne $item.Checksum) { throw "Migration changed after preflight: $($item.Name)" }
            Write-Host "Applying: $($item.Name)"
            $sqlStarted = $true
            Invoke-MigrationSql ("SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;`n" + $item.Sql + "`n") | Out-Null
            Invoke-MigrationSql @"
START TRANSACTION;
INSERT INTO schemaversion(scriptName,checksum) VALUES ('$($item.Name)','$($item.Checksum)');
DELETE FROM schemaversion WHERE scriptName='migration:pending' AND checksum='$($item.Checksum)';
COMMIT;
"@ | Out-Null
            $stored = @(Invoke-MigrationSql "SELECT checksum FROM schemaversion WHERE scriptName='$($item.Name)';")
            if ($stored.Count -ne 1 -or $stored[0] -ne $item.Checksum) { throw 'Recorded checksum verification failed.' }
            Write-Host "Applied: $($item.Name)"
        }
        catch {
            if ($acquired -and -not $sqlStarted) {
                Invoke-MigrationSql "DELETE FROM schemaversion WHERE scriptName='migration:pending' AND checksum='$($item.Checksum)';" | Out-Null
            }
            if ($acquired -and $sqlStarted) {
                throw "Migration '$($item.Name)' failed or could not be confirmed. SQL may be partially applied; no automatic DDL rollback is promised. Preserve the error and inspect migration:pending before any retry. $($_.Exception.Message)"
            }
            throw
        }
    }
    Write-Host 'Migration validation/application completed.'
}
finally { $env:MYSQL_PWD = $previousPassword }
