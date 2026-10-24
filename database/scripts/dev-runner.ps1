# Maintainer workflow: apply with the canonical runner, then regenerate exports
# for review. Comparing an old DB to the newest schema before upgrading is invalid.
param(
    [string]$MigrationFolder = (Join-Path $PSScriptRoot '../migrations'),
    [string]$MariaDbExe = $env:MARIADB_EXE,
    [switch]$PlanOnly
)
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'Apply-Migrations.ps1') -MigrationFolder $MigrationFolder -MariaDbExe $MariaDbExe -PlanOnly:$PlanOnly
if (-not $PlanOnly) {
    $previousClient = $env:MARIADB_EXE
    try {
        $env:MARIADB_EXE = $MariaDbExe
        & (Join-Path $PSScriptRoot 'Export-MariaDBSchema.ps1')
    }
    finally { $env:MARIADB_EXE = $previousClient }
    Write-Host 'Migrations succeeded. Review generated schema, manifest and checksums before committing; generated changes are expected.'
}
