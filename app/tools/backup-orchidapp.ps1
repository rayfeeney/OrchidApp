param(
    [ValidateSet('Normal','PreUpgrade')][string]$BackupType = 'Normal',
    [string]$BackupsRoot,
    [ValidateRange(1,65535)][int]$MariaDbPort = 3308,
    [int]$BackupsToKeep = 3,
    [switch]$SkipOldBackupPruning,
    [string]$LegacySourceRoot
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Backup-Contract.ps1')
$AppRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$MariaDbRoot = Join-Path $AppRoot 'runtime/mariadb/win-x64'
$MariaDbServer = Join-Path $MariaDbRoot 'bin/mariadbd.exe'
$MariaDbClient = Join-Path $MariaDbRoot 'bin/mariadb.exe'
$MariaDbDump = Join-Path $MariaDbRoot 'bin/mariadb-dump.exe'
$MariaDbAdmin = Join-Path $MariaDbRoot 'bin/mariadb-admin.exe'
$ProgramDataRoot = Join-Path $env:ProgramData 'OrchidApp'
if ($BackupType -eq 'Normal' -and (Test-Path -LiteralPath (Join-Path $ProgramDataRoot 'restore-pending.json'))) {
    throw 'An interrupted restore requires recovery. Normal backups are blocked to avoid preserving partial data as a successful backup.'
}
if ($BackupType -eq 'PreUpgrade') {
    if ([string]::IsNullOrWhiteSpace($LegacySourceRoot)) { throw 'PreUpgrade requires an explicit LegacySourceRoot captured from the detected installation.' }
    $SourceRoot = (Resolve-Path -LiteralPath $LegacySourceRoot).Path
    $MariaDbData = Join-Path $SourceRoot 'data/mariadb'
    $UploadsRoot = Join-Path $SourceRoot 'wwwroot/uploads'
    $LauncherSettingsPath = Join-Path $SourceRoot 'launcher-settings.json'
    if (-not $BackupsRoot) { $BackupsRoot = Join-Path $ProgramDataRoot 'backups/pre-upgrade' }
    $capture = Join-Path $SourceRoot 'source-capture.json'
    if (-not (Test-Path -LiteralPath $capture -PathType Leaf)) { throw 'PreUpgrade requires a quiescent captured source, not a live legacy directory.' }
    $OriginalLegacyRoot = (Get-Content -LiteralPath $capture -Raw -Encoding UTF8 | ConvertFrom-Json).originalRoot
}
else {
    if ($LegacySourceRoot) { throw 'LegacySourceRoot is valid only for PreUpgrade.' }
    $SourceRoot=$ProgramDataRoot
    $MariaDbData=Join-Path $SourceRoot 'data/mariadb'
    $UploadsRoot=Join-Path $SourceRoot 'uploads'
    $LauncherSettingsPath=Join-Path $SourceRoot 'launcher-settings.json'
    if (-not $BackupsRoot) { $BackupsRoot=Join-Path $SourceRoot 'backups' }
}
foreach ($path in @($MariaDbServer,$MariaDbClient,$MariaDbDump,$MariaDbAdmin,$MariaDbData)) {
    if (-not (Test-Path -LiteralPath $path)) { throw "Required backup item missing: $path" }
}
Assert-NoPathAlias $MariaDbData
if ($BackupType -eq 'PreUpgrade') {
    foreach ($source in @($SourceRoot,$OriginalLegacyRoot)) {
        $destination=Get-FullLocalPath $BackupsRoot; $prefix=(Get-FullLocalPath $source)+'\'
        if ($destination -ieq (Get-FullLocalPath $source) -or $destination.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)) { throw 'Pre-upgrade backups must be outside captured and original legacy roots.' }
    }
}
New-Item -ItemType Directory -Path $BackupsRoot -Force | Out-Null
Assert-NoPathAlias $BackupsRoot
$name='OrchidAppBackup_'
if ($BackupType -eq 'PreUpgrade') { $name='OrchidAppPreUpgradeBackup_' }
$name += (Get-Date -Format 'yyyyMMdd_HHmmss_fff')+'_'+[guid]::NewGuid().ToString('N').Substring(0,8)
# Keep native MariaDB result-file paths below legacy Windows path limits.
$BackupWorkingRoot=Join-Path $BackupsRoot ('w-'+[guid]::NewGuid().ToString('N').Substring(0,16))
New-Item -ItemType Directory -Path $BackupWorkingRoot | Out-Null
$BackupZip=Join-Path $BackupsRoot ($name+'.zip')
$PayloadRoot=Join-Path $BackupWorkingRoot 'payload'
New-Item -ItemType Directory -Path $PayloadRoot | Out-Null
$BackupLogPath=Join-Path $BackupWorkingRoot 'backup.log'
$MariaDbServerLogPath=Join-Path $BackupWorkingRoot 'mariadb-server.log'
$MariaDbServerErrorLogPath=Join-Path $BackupWorkingRoot 'mariadb-server-error.log'
$StartedMariaDb=$false; $MariaDbProcess=$null
$previousPassword=$env:MYSQL_PWD
function Write-Step([string]$Message) { Write-Host $Message }
function Write-Log([string]$Message) { Add-Content -LiteralPath $BackupLogPath -Value $Message -Encoding UTF8 }
try {
    $env:MYSQL_PWD='orchid'
    Start-OrchidDatabase
    if ([int](Invoke-OrchidQuery "SELECT COUNT(*) FROM information_schema.SCHEMATA WHERE SCHEMA_NAME='orchids';") -ne 1) { throw 'Selected source has no orchids database.' }
    Assert-PhotoFiles $UploadsRoot
    $DatabaseBackupPath=Join-Path $PayloadRoot 'orchids.sql'
    & $MariaDbDump --no-defaults --protocol=TCP --host=127.0.0.1 "--port=$MariaDbPort" --user=orchid --default-character-set=utf8mb4 --single-transaction --routines --triggers --events --databases orchids --add-drop-database --add-drop-table "--result-file=$DatabaseBackupPath"
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $DatabaseBackupPath) -or (Get-Item -LiteralPath $DatabaseBackupPath).Length -eq 0) { throw 'Database backup failed.' }
    $UploadsBackupPath=Join-Path $PayloadRoot 'uploads'
    $SettingsBackupRoot=Join-Path $PayloadRoot 'launcher-settings'
    New-Item -ItemType Directory -Path $UploadsBackupPath,$SettingsBackupRoot | Out-Null
    if (Test-Path -LiteralPath $UploadsRoot) {
        Assert-NoPathAlias $UploadsRoot
        $items=@(Get-ChildItem -LiteralPath $UploadsRoot -Force)
        if ($items.Count) { Copy-Item -LiteralPath $items.FullName -Destination $UploadsBackupPath -Recurse -Force }
    }
    $settingsIncluded=Test-Path -LiteralPath $LauncherSettingsPath -PathType Leaf
    if ($settingsIncluded) { Copy-Item -LiteralPath $LauncherSettingsPath -Destination $SettingsBackupRoot }
    Invoke-OrchidQuery 'SELECT scriptName, appliedAt, checksum FROM orchids.schemaversion ORDER BY appliedAt,scriptName;' | Set-Content -LiteralPath (Join-Path $PayloadRoot 'schemaversion.txt') -Encoding UTF8
    $inventory=@(Get-PayloadFiles $PayloadRoot | ForEach-Object {
        Assert-NoPathAlias $_.FullName
        [ordered]@{ path=$_.FullName.Substring($PayloadRoot.Length+1).Replace('\','/'); length=$_.Length; sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant() }
    })
    $manifest=[ordered]@{
        formatVersion=2; backupName=$name; backupType=$BackupType; createdAt=(Get-Date).ToString('o')
        appRoot=$AppRoot; sourceRoot=$SourceRoot; originalLegacyRoot=$OriginalLegacyRoot
        database='orchids'; databaseBackup='orchids.sql'; schemaVersionFile='schemaversion.txt'
        mariaDbPort=$MariaDbPort; mariaDbDataRoot=$MariaDbData; uploadsRoot=$UploadsRoot
        uploadsIncluded=$true; sourceUploadsPresent=(Test-Path -LiteralPath $UploadsRoot)
        uploadsFileCount=@(Get-ChildItem -LiteralPath $UploadsBackupPath -Recurse -File -Force).Count
        launcherSettingsIncluded=[bool]$settingsIncluded; launcherSettingsPath=$LauncherSettingsPath; files=$inventory
    }
    $manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $PayloadRoot 'manifest.json') -Encoding UTF8
    Read-BackupPayload $PayloadRoot | Out-Null
    Stop-OrchidDatabase
    # Archive only payload, not logs that may still be appended after hashing.
    [string[]]$archiveInputs=@('orchids.sql','schemaversion.txt','uploads','launcher-settings','manifest.json') | ForEach-Object { Join-Path $PayloadRoot $_ }
    Compress-Archive -LiteralPath $archiveInputs -DestinationPath $BackupZip
    $verify=Join-Path $BackupWorkingRoot 'verify'
    Expand-CheckedBackup $BackupZip $verify
    Read-BackupPayload $verify | Out-Null
    Write-Host 'Backup created:'
    Write-Host $BackupZip
    Write-Log "Verified backup: $BackupZip"
    Assert-ChildPath $BackupWorkingRoot $BackupsRoot
    Remove-Item -LiteralPath $BackupWorkingRoot -Recurse -Force
    if ($PruneOldBackups) {
        Write-Step "Removing old backups"

        $OldBackups = Get-ChildItem `
            -Path $BackupsRoot `
            -Filter "OrchidAppBackup_*.zip" `
            -File `
            -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -Skip $BackupsToKeep

        if ($OldBackups) {
            foreach ($OldBackup in $OldBackups) {
                Remove-Item `
                    -Path $OldBackup.FullName `
                    -Force

                Write-Host "Removed old backup: $($OldBackup.Name)" -ForegroundColor Yellow
            }
        }
        else {
            Write-Host "No old backups to remove." -ForegroundColor Green
        }
    }
    else {
        Write-Step "Skipping old backup pruning"
        Write-Host "Old backup pruning disabled for this backup run." -ForegroundColor Green
    }
}
finally {
    try { Stop-OrchidDatabase } finally { $env:MYSQL_PWD=$previousPassword }
}
