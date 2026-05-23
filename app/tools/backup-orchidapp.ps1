param(
    [ValidateSet("Normal", "PreUpgrade")]
    [string]$BackupType = "Normal",

    [string]$BackupsRoot,

    [int]$MariaDbPort = 3308,

    [int]$BackupsToKeep = 3,

    [switch]$SkipOldBackupPruning
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)

    Write-Host ""
    Write-Host "==> $Message"
}

function Test-PortListening {
    param([int]$Port)

    $listener = Get-NetTCPConnection `
        -LocalPort $Port `
        -State Listen `
        -ErrorAction SilentlyContinue

    return $null -ne $listener
}

function Wait-ForMariaDb {
    param(
        [string]$MariaDbClient,
        [int]$Port,
        [int]$TimeoutSeconds = 30
    )

    for ($i = 0; $i -lt $TimeoutSeconds; $i++) {
        & $MariaDbClient `
            -h 127.0.0.1 `
            -P $Port `
            -u orchid `
            -porchid `
            -e "SELECT 1;" `
            2>$null | Out-Null

        if ($LASTEXITCODE -eq 0) {
            return
        }

        Start-Sleep -Seconds 1
    }

    throw "MariaDB did not become ready within $TimeoutSeconds seconds."
}

function Write-Log {
    param([string]$Message)

    $Line = "[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message

    Add-Content `
        -Path $BackupLogPath `
        -Value $Line `
        -Encoding UTF8
}

function Write-UserAndLog {
    param([string]$Message)

    Write-Host $Message
    Write-Log $Message
}

function Stop-LocalMariaDb {
    if ($StartedMariaDb -and $MariaDbProcess -and -not $MariaDbProcess.HasExited) {
        Write-Step "Stopping local database"

        & $MariaDbAdmin `
            -h 127.0.0.1 `
            -P $MariaDbPort `
            -u orchid_shutdown `
            -porchid_shutdown `
            shutdown

        if ($LASTEXITCODE -eq 0) {
            $MariaDbProcess.WaitForExit(30000) | Out-Null
            Write-Host "MariaDB stopped." -ForegroundColor Green
            Write-Log "MariaDB stopped cleanly."
        }
        else {
            Stop-Process -Id $MariaDbProcess.Id -Force
            Write-Host "MariaDB had to be force-stopped." -ForegroundColor Red
            Write-Log "MariaDB had to be force-stopped."
        }
    }
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$AppRoot = Resolve-Path (Join-Path $ScriptDir "..")

$MariaDbRoot = Join-Path $AppRoot "runtime\mariadb\win-x64"
$MariaDbBin = Join-Path $MariaDbRoot "bin"

$MariaDbServer = Join-Path $MariaDbBin "mariadbd.exe"
$MariaDbClient = Join-Path $MariaDbBin "mariadb.exe"
$MariaDbDump = Join-Path $MariaDbBin "mariadb-dump.exe"
$MariaDbAdmin = Join-Path $MariaDbBin "mariadb-admin.exe"

$MariaDbData = Join-Path $AppRoot "data\mariadb"
$UploadsRoot = Join-Path $AppRoot "wwwroot\uploads"
if ([string]::IsNullOrWhiteSpace($BackupsRoot)) {
    $BackupsRoot = Join-Path $AppRoot "backups"
}
if ($BackupType -eq "PreUpgrade") {
    $ResolvedBackupsRootParent = Split-Path -Parent $BackupsRoot

    if (-not (Test-Path $ResolvedBackupsRootParent)) {
        New-Item `
            -Path $ResolvedBackupsRootParent `
            -ItemType Directory `
            -Force | Out-Null
    }

    $ResolvedBackupsRoot = Resolve-Path `
        -Path $BackupsRoot `
        -ErrorAction SilentlyContinue

    if ($ResolvedBackupsRoot -and
        $ResolvedBackupsRoot.Path.StartsWith($AppRoot.Path, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Pre-upgrade backup destination must not be inside the source app root."
    }
}

$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
if ($BackupType -eq "PreUpgrade") {
    $BackupName = "OrchidAppPreUpgradeBackup_$Timestamp"
}
else {
    $BackupName = "OrchidAppBackup_$Timestamp"
}
$BackupWorkingRoot = Join-Path $BackupsRoot $BackupName
$BackupLogPath = Join-Path $BackupWorkingRoot "backup.log"
$MariaDbServerLogPath = Join-Path $BackupWorkingRoot "mariadb-server.log"
$MariaDbServerErrorLogPath = Join-Path $BackupWorkingRoot "mariadb-server-error.log"
$BackupZip = Join-Path $BackupsRoot "$BackupName.zip"
$MariaDbDataRoot = Join-Path $AppRoot "data\mariadb"

$StartedMariaDb = $false
$MariaDbProcess = $null

Write-Step "Checking backup prerequisites"

$RequiredPaths = @(
    $MariaDbServer,
    $MariaDbClient,
    $MariaDbDump,
    $MariaDbAdmin,
    $MariaDbData
)

foreach ($RequiredPath in $RequiredPaths) {
    if (-not (Test-Path $RequiredPath)) {
        throw "Required backup item missing: $RequiredPath"
    }

    Write-Host "OK: $RequiredPath" -ForegroundColor Green
}

New-Item -ItemType Directory -Path $BackupsRoot -Force | Out-Null
New-Item -ItemType Directory -Path $BackupWorkingRoot -Force | Out-Null

Set-Content `
    -Path $BackupLogPath `
    -Value ("[{0}] Backup started." -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss")) `
    -Encoding UTF8

try {
    Write-Step "Starting local database if needed"

    if (Test-PortListening -Port $MariaDbPort) {
        Write-Host "MariaDB already appears to be running on port $MariaDbPort."
    }
    else {
        $MariaDbProcess = Start-Process `
            -FilePath $MariaDbServer `
            -ArgumentList "--datadir=`"$MariaDbData`" --port=$MariaDbPort --bind-address=127.0.0.1 --console" `
            -WorkingDirectory $AppRoot `
            -RedirectStandardOutput $MariaDbServerLogPath `
            -RedirectStandardError $MariaDbServerErrorLogPath `
            -PassThru `
            -WindowStyle Hidden

        $StartedMariaDb = $true

        Write-Host "Waiting for MariaDB to become ready..."
        Wait-ForMariaDb `
            -MariaDbClient $MariaDbClient `
            -Port $MariaDbPort
    }

    Write-Step "Checking plant database exists"

    $DatabaseExists = & $MariaDbClient `
        -h 127.0.0.1 `
        -P $MariaDbPort `
        -u orchid `
        -porchid `
        -N `
        -B `
        -e "SELECT COUNT(*) FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = 'orchids';"

    if ($LASTEXITCODE -ne 0) {
        throw "Unable to check whether the OrchidApp database exists."
    }

    if ([int]$DatabaseExists -ne 1) {
        if ($BackupType -eq "PreUpgrade") {
            throw "Pre-upgrade backup was not required because no existing OrchidApp database was found in the detected source layout."
        }

        throw "No OrchidApp database was found. Start OrchidApp once before creating a backup."
    }

    Write-Host "OK: OrchidApp database found." -ForegroundColor Green

    Write-Step "Preparing backup files"

    Write-Log "Backup working folder: $BackupWorkingRoot"

    $DatabaseBackupPath = Join-Path $BackupWorkingRoot "orchids.sql"

    Write-Step "Backing up plant database"

    & $MariaDbDump `
        -h 127.0.0.1 `
        -P $MariaDbPort `
        -u orchid `
        -porchid `
        --databases orchids `
        --single-transaction `
        --routines `
        --triggers `
        --events `
        --add-drop-database `
        --add-drop-table `
        --result-file="$DatabaseBackupPath"

    if ($LASTEXITCODE -ne 0) {
        throw "Database backup failed."
    }

    Write-Host "OK: Database backup created." -ForegroundColor Green

    Write-Step "Backing up uploaded files"

    $UploadsBackupPath = Join-Path $BackupWorkingRoot "uploads"

    # Always include an uploads folder in the backup, even when there are no photos yet.
    New-Item -ItemType Directory -Path $UploadsBackupPath -Force | Out-Null

    $UploadsFileCount = 0

    if (Test-Path $UploadsRoot) {
        $UploadsFileCount = @(
            Get-ChildItem `
                -Path $UploadsRoot `
                -File `
                -Recurse `
                -ErrorAction SilentlyContinue
        ).Count

        $UploadItems = Get-ChildItem `
            -Path $UploadsRoot `
            -Force `
            -ErrorAction SilentlyContinue

        if ($UploadItems) {
            Copy-Item `
                -Path $UploadItems.FullName `
                -Destination $UploadsBackupPath `
                -Recurse `
                -Force

            Write-Host "OK: Uploaded files copied. Files included: $UploadsFileCount" -ForegroundColor Green
            Write-Log "Uploaded files copied. Files included: $UploadsFileCount"
        }
        else {
            Write-Host "OK: No uploaded files found yet. Empty uploads folder included." -ForegroundColor Green
            Write-Log "No uploaded files found. Empty uploads folder included."
        }
    }
    else {
        Write-Host "OK: Uploads folder has not been created yet. Empty uploads folder included." -ForegroundColor Green
        Write-Log "Uploads folder not found. Empty uploads folder included."
    }

    Write-Step "Backing up launcher settings"

    $LauncherSettingsPath = Join-Path $AppRoot "launcher-settings.json"
    $LauncherSettingsBackupPath = Join-Path $BackupWorkingRoot "launcher-settings"

    New-Item `
        -Path $LauncherSettingsBackupPath `
        -ItemType Directory `
        -Force | Out-Null

    if (Test-Path $LauncherSettingsPath) {
        Copy-Item `
            -Path $LauncherSettingsPath `
            -Destination $LauncherSettingsBackupPath `
            -Force

        Write-Host "OK: Launcher settings backed up." -ForegroundColor Green
    }
    else {
        Write-Host "OK: Launcher settings file not found. Empty launcher-settings folder included." -ForegroundColor Green
    }

    Write-Step "Writing backup manifest"

    $SchemaVersionPath = Join-Path $BackupWorkingRoot "schemaversion.txt"

    & $MariaDbClient `
        -h 127.0.0.1 `
        -P $MariaDbPort `
        -u orchid `
        -porchid `
        -e "SELECT scriptName, appliedAt, checksum FROM orchids.schemaversion ORDER BY appliedAt, scriptName;" `
        > $SchemaVersionPath

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to export schema version information."
    }

    if ($BackupType -eq "PreUpgrade") {
        $BackupReason = "Upgrade safety backup before an upgrade-sensitive operation."
    }
    else {
        $BackupReason = "Manual OrchidApp backup."
    }

    Write-Log "Uploads file count: $UploadsFileCount"

    $Manifest = [ordered]@{
        backupName = $BackupName
        backupType = $BackupType
        backupReason = $BackupReason
        createdAt = (Get-Date).ToString("o")
        appRoot = $AppRoot.Path
        database = "orchids"
        databaseBackup = "orchids.sql"
        uploadsIncluded = (Test-Path $UploadsRoot)
        uploadsFileCount = $UploadsFileCount
        schemaVersionFile = "schemaversion.txt"
        mariaDbPort = $MariaDbPort
        backupsToKeep = $BackupsToKeep
        backupsRoot = $BackupsRoot
        mariaDbDataRoot = $MariaDbDataRoot
        uploadsRoot = $UploadsRoot
        launcherSettingsPath = $LauncherSettingsPath
    }

    $ManifestPath = Join-Path $BackupWorkingRoot "manifest.json"

    $Manifest |
        ConvertTo-Json -Depth 5 |
        Set-Content -Path $ManifestPath -Encoding UTF8

    Write-Host "OK: Manifest created." -ForegroundColor Green

    Stop-LocalMariaDb

    Write-Step "Creating backup ZIP"

    if (Test-Path $BackupZip) {
        Remove-Item $BackupZip -Force
    }

    Compress-Archive `
        -Path (Join-Path $BackupWorkingRoot "*") `
        -DestinationPath $BackupZip `
        -Force

    Write-Host ""
    Write-Host "Backup created:" -ForegroundColor Green
    Write-Host $BackupZip -ForegroundColor Green
    Write-Log "Backup ZIP created: $BackupZip"
    Write-Log "Backup completed successfully."
    Write-Log "Temporary backup folder will be removed: $BackupWorkingRoot"

    Write-Step "Cleaning temporary backup files"

    Remove-Item `
        -Path $BackupWorkingRoot `
        -Recurse `
        -Force

    Write-Host "Temporary backup files removed." -ForegroundColor Green

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
catch {
    try {
        Write-Log "ERROR: $($_.Exception.Message)"
    }
    catch {
        # ignore logging failure
    }

    throw
}
finally {
    Stop-LocalMariaDb
}