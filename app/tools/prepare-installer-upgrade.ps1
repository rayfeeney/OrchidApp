param(
    [Parameter(Mandatory=$true)][string]$AppRoot,
    [Parameter(Mandatory=$true)][string]$PersistentRoot,
    [Parameter(Mandatory=$true)][string]$ResultFile,
    [int]$InstallerProcessId=0,
    [string]$MariaDbTargetVersion
)
$ErrorActionPreference='Stop'
try {
    . (Join-Path $PSScriptRoot 'Installer-Snapshot.ps1')
    $archive=New-InstallerSnapshot $AppRoot $PersistentRoot $InstallerProcessId
    if ($MariaDbTargetVersion) {
        $legacyDatabase=Join-Path $AppRoot 'data/mariadb/orchids'
        if (Test-Path -LiteralPath $legacyDatabase) { throw 'Resolve legacy application-folder data before the MariaDB engine upgrade.' }
        $data=Join-Path $PersistentRoot 'data/mariadb'
        if ((Test-Path -LiteralPath $data) -and @(Get-ChildItem -LiteralPath $data -Force).Count) {
            if (-not (Test-Path -LiteralPath (Join-Path $data 'mysql') -PathType Container)) {
                throw 'Existing database directory has no identifiable MariaDB system tables.'
            }
            $oldServer=Join-Path $AppRoot 'runtime/mariadb/win-x64/bin/mariadbd.exe'
            Assert-InstallerPath $oldServer
            if (-not (Test-Path -LiteralPath $oldServer -PathType Leaf)) { throw 'The matching installed MariaDB runtime is required.' }
            $version=& $oldServer --no-defaults --version
            if ($LASTEXITCODE -ne 0 -or $version -notmatch '\b(\d+\.\d+\.\d+)-MariaDB\b') { throw 'Cannot identify the installed MariaDB version.' }
            $sourceVersion=$Matches[1]
            if ($sourceVersion -match '^10\.11\.') {
                $null=New-InstallerMariaDbUpgradeRecord $AppRoot $PersistentRoot $archive $sourceVersion $MariaDbTargetVersion
            } elseif ($sourceVersion -ne $MariaDbTargetVersion) {
                throw "Unsupported installed MariaDB version: $sourceVersion."
            }
        }
    }
    $message=if ($archive) { 'Verified pre-install recovery snapshot: '+$archive } else { 'New installation: no existing application or persistent files.' }
    [IO.File]::WriteAllText($ResultFile,$message,(New-Object Text.UTF8Encoding($false)))
    exit 0
}
catch {
    [IO.File]::WriteAllText($ResultFile,('Installation stopped before file replacement: '+$_.Exception.Message),(New-Object Text.UTF8Encoding($false)))
    exit 1
}
