# Dot-source in the terminal used for app, schema scripts and Git hooks.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '../../database/scripts/Database-Environment.ps1')
$developmentTarget = Get-ExplicitDatabaseEnvironment
if (-not $env:Storage__UploadRoot -or -not [IO.Path]::IsPathFullyQualified($env:Storage__UploadRoot)) {
    throw 'Storage__UploadRoot must be an explicit absolute directory for disposable development photos.'
}
# A builder quotes semicolons, quotes and other special characters in credentials.
$developmentConnection = [System.Data.Common.DbConnectionStringBuilder]::new()
$developmentConnection['Server'] = $developmentTarget.HostName
$developmentConnection['Port'] = $developmentTarget.Port
$developmentConnection['Database'] = $developmentTarget.Database
$developmentConnection['User ID'] = $developmentTarget.User
$developmentConnection['Password'] = $developmentTarget.Password
$env:ConnectionStrings__OrchidDb = $developmentConnection.ConnectionString
$env:ASPNETCORE_ENVIRONMENT = 'Development'
$env:Monitoring__Enabled = 'false'
$env:MARIADB_CHARSET = 'utf8mb4'
$env:MARIADB_COLLATION = 'utf8mb4_unicode_ci'
# Do not emit configuration objects containing secrets to the pipeline.
Remove-Variable developmentConnection,developmentTarget
Write-Host 'Development app and scripts now share the explicit MARIADB target. Monitoring is disabled.'
