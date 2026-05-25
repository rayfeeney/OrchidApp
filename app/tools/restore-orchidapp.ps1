param(
    [Parameter(Mandatory = $true)]
    [string]$BackupZip,

    [int]$MariaDbPort = 3308
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

function Stop-LocalMariaDb {
    if (-not $StartedMariaDb) {
        Write-Host "MariaDB was already running before restore. Leaving it running."
        return
    }

    if ($null -eq $MariaDbProcess) {
        return
    }

    if ($MariaDbProcess.HasExited) {
        return
    }

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
    }
    else {
        Stop-Process -Id $MariaDbProcess.Id -Force
        Write-Host "MariaDB had to be force-stopped." -ForegroundColor Red
    }
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$AppRoot = Resolve-Path (Join-Path $ScriptDir "..")

$MariaDbRoot = Join-Path $AppRoot "runtime\mariadb\win-x64"
$MariaDbBin = Join-Path $MariaDbRoot "bin"

$MariaDbServer = Join-Path $MariaDbBin "mariadbd.exe"
$MariaDbClient = Join-Path $MariaDbBin "mariadb.exe"
$MariaDbAdmin = Join-Path $MariaDbBin "mariadb-admin.exe"

$ProgramDataRoot = Join-Path $env:ProgramData "OrchidApp"

$ProgramDataDataRoot = Join-Path $ProgramDataRoot "data"
$MariaDbData = Join-Path $ProgramDataDataRoot "mariadb"
$UploadsRoot = Join-Path $ProgramDataRoot "uploads"
$RestoreRoot = Join-Path $ProgramDataRoot "restore-temp"

$LogsRoot = Join-Path $ProgramDataRoot "logs"
$LauncherSettingsPath = Join-Path $ProgramDataRoot "launcher-settings.json"

$MariaDbServerLogPath = Join-Path $LogsRoot "restore-mariadb-server.log"
$MariaDbServerErrorLogPath = Join-Path $LogsRoot "restore-mariadb-server-error.log"

New-Item -ItemType Directory -Path $ProgramDataRoot -Force | Out-Null
New-Item -ItemType Directory -Path $ProgramDataDataRoot -Force | Out-Null
New-Item -ItemType Directory -Path $MariaDbData -Force | Out-Null
New-Item -ItemType Directory -Path $LogsRoot -Force | Out-Null
New-Item -ItemType Directory -Path $UploadsRoot -Force | Out-Null

$StartedMariaDb = $false
$MariaDbProcess = $null
$RestoreUploads = $false

Write-Step "Checking restore prerequisites"

if (-not (Test-Path $BackupZip)) {
    throw "Backup ZIP not found: $BackupZip"
}

$BackupZip = Resolve-Path $BackupZip

$RequiredPaths = @(
    $MariaDbServer,
    $MariaDbClient,
    $MariaDbAdmin,
    $MariaDbData
)

foreach ($RequiredPath in $RequiredPaths) {
    if (-not (Test-Path $RequiredPath)) {
        throw "Required restore item missing: $RequiredPath"
    }

    Write-Host "OK: $RequiredPath" -ForegroundColor Green
}

try {
    Write-Step "Extracting backup"

    if (Test-Path $RestoreRoot) {
        Remove-Item $RestoreRoot -Recurse -Force
    }

    New-Item -ItemType Directory -Path $RestoreRoot -Force | Out-Null

    Expand-Archive `
        -Path $BackupZip `
        -DestinationPath $RestoreRoot `
        -Force

    $ManifestPath = Join-Path $RestoreRoot "manifest.json"
    $DatabaseBackupPath = Join-Path $RestoreRoot "orchids.sql"
    $UploadsBackupPath = Join-Path $RestoreRoot "uploads"
    $LauncherSettingsBackupPath = Join-Path $RestoreRoot "launcher-settings.json"

    if (-not (Test-Path $ManifestPath)) {
        throw "Backup is invalid. manifest.json was not found."
    }

    if (-not (Test-Path $DatabaseBackupPath)) {
        throw "Backup is invalid. orchids.sql was not found."
    }

    if (Test-Path $UploadsBackupPath) {
        $RestoreUploads = $true
        Write-Host "OK: uploads folder found." -ForegroundColor Green
    }
    else {
        $RestoreUploads = $false
        Write-Host "WARNING: uploads folder was not found in backup. This is valid if no photos have been uploaded." -ForegroundColor Yellow
    }

    Write-Host "OK: Backup contents validated." -ForegroundColor Green

    Write-Step "Starting local database if needed"

    if (Test-PortListening -Port $MariaDbPort) {
        Write-Host "MariaDB already appears to be running on port $MariaDbPort."
        $StartedMariaDb = $false
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

    Write-Step "Restoring plant database"

    $RestoreCommand = "`"$MariaDbClient`" -h 127.0.0.1 -P $MariaDbPort -u orchid -porchid < `"$DatabaseBackupPath`""

    cmd.exe /c $RestoreCommand

    if ($LASTEXITCODE -ne 0) {
        throw "Database restore failed."
    }

    Write-Host "OK: Plant database restored." -ForegroundColor Green

    if ($RestoreUploads) {
        Write-Step "Restoring uploaded files"

        if (Test-Path $UploadsRoot) {
            Remove-Item $UploadsRoot -Recurse -Force
        }

        New-Item -ItemType Directory -Path $UploadsRoot -Force | Out-Null

        $UploadItems = Get-ChildItem `
            -Path $UploadsBackupPath `
            -Force `
            -ErrorAction SilentlyContinue

        if ($UploadItems) {
            Copy-Item `
                -Path $UploadItems.FullName `
                -Destination $UploadsRoot `
                -Recurse `
                -Force
        }

        Write-Host "OK: Uploaded files restored." -ForegroundColor Green
    }
    else {
        Write-Step "Skipping uploaded files"

        Write-Host "No uploads folder was present in the backup." -ForegroundColor Yellow
        Write-Host "This is valid for OrchidApp installations with no uploaded photos." -ForegroundColor Yellow

        if (-not (Test-Path $UploadsRoot)) {
            New-Item -ItemType Directory -Path $UploadsRoot -Force | Out-Null
            Write-Host "OK: Created empty uploads folder." -ForegroundColor Green
        }
    }

    Write-Step "Restore complete"

    Write-Step "Restoring launcher settings"

    if (Test-Path $LauncherSettingsBackupPath) {
        Copy-Item `
            -Path $LauncherSettingsBackupPath `
            -Destination $LauncherSettingsPath `
            -Force

        Write-Host "OK: Launcher settings restored." -ForegroundColor Green
    }
    else {
        Write-Host "No launcher settings file was present in the backup." -ForegroundColor Yellow
        Write-Host "This is valid if no launcher settings had been configured." -ForegroundColor Yellow
    }

    Write-Host "Restore completed successfully." -ForegroundColor Green
    Write-Host "Start OrchidApp again to use the restored data." -ForegroundColor Green
}
finally {
    Stop-LocalMariaDb

    if (Test-Path $RestoreRoot) {
        Remove-Item $RestoreRoot -Recurse -Force
    }
}