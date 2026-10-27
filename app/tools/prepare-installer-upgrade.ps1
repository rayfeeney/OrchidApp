param(
    [Parameter(Mandatory=$true)][string]$AppRoot,
    [Parameter(Mandatory=$true)][string]$PersistentRoot,
    [Parameter(Mandatory=$true)][string]$ResultFile,
    [int]$InstallerProcessId=0
)
$ErrorActionPreference='Stop'
try {
    . (Join-Path $PSScriptRoot 'Installer-Snapshot.ps1')
    $archive=New-InstallerSnapshot $AppRoot $PersistentRoot $InstallerProcessId
    $message=if ($archive) { 'Verified pre-install recovery snapshot: '+$archive } else { 'New installation: no existing application or persistent files.' }
    [IO.File]::WriteAllText($ResultFile,$message,(New-Object Text.UTF8Encoding($false)))
    exit 0
}
catch {
    [IO.File]::WriteAllText($ResultFile,('Installation stopped before file replacement: '+$_.Exception.Message),(New-Object Text.UTF8Encoding($false)))
    exit 1
}
