# Embedded only by InstallerFixture builds with an unrelated product identity.
# Never included or called in a production installer build.
param([string]$AppRoot,[string]$PersistentRoot,[string]$ResultFile,[int]$InstallerProcessId)
# CIM policy itself is exercised with controlled rows in Policy.Checks.ps1.
# Installer integration runs against synthetic files, including real sharing locks.
function Get-CimInstance { @() }
& (Join-Path $PSScriptRoot 'prepare-installer-upgrade.ps1') @PSBoundParameters
exit $LASTEXITCODE
