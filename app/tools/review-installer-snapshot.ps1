param(
    [Parameter(Mandatory=$true)][string]$Archive,
    [string]$ExtractTo
)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Installer-Snapshot.ps1')
if ($ExtractTo) { Expand-InstallerSnapshot $Archive $ExtractTo }
else { Read-InstallerSnapshot $Archive | Select-Object formatVersion,kind,createdUtc,applicationRoot,persistentRoot,@{Name='fileCount';Expression={@($_.files).Count}} | ConvertTo-Json }
