# Records the Desktop backup invocation without touching a real backup directory.
param(
    [ValidateSet('Normal')][string]$BackupType,
    [Parameter(Mandatory=$true)][string]$BackupsRoot,
    [switch]$SkipOldBackupPruning
)
$ErrorActionPreference='Stop'
if (-not $SkipOldBackupPruning -or -not $BackupsRoot.Replace('\','/').EndsWith('/OrchidApp/backups/pre-migration',[StringComparison]::OrdinalIgnoreCase)) {
    throw 'Desktop migration safety backup must use its protected directory and disable pruning.'
}
'synthetic' | Add-Content -LiteralPath (Join-Path $PSScriptRoot '../backup-count.txt')
@{BackupType=$BackupType;BackupsRoot=$BackupsRoot;SkipOldBackupPruning=[bool]$SkipOldBackupPruning} |
    ConvertTo-Json | Set-Content -LiteralPath (Join-Path $PSScriptRoot '../backup-arguments.json') -Encoding UTF8
