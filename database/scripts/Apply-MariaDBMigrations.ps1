# Compatibility entry point; all validation/execution lives in Apply-Migrations.
param(
    [string]$MigrationFolder = (Join-Path $PSScriptRoot '../migrations'),
    [string]$MariaDbExe = $env:MARIADB_EXE,
    [switch]$PlanOnly
)
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'Apply-Migrations.ps1') -MigrationFolder $MigrationFolder -MariaDbExe $MariaDbExe -PlanOnly:$PlanOnly
