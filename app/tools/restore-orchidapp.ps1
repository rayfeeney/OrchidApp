param(
    [string]$BackupZip,
    [ValidateSet('RestoreInput','RestoreSafety')][string]$RecoveryAction,
    [ValidateRange(1,65535)][int]$MariaDbPort=3308
)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Backup-Contract.ps1')
. (Join-Path $PSScriptRoot 'Restore-Recovery.ps1')
$AppRoot=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$MariaDbRoot=Join-Path $AppRoot 'runtime/mariadb/win-x64'
$MariaDbServer=Join-Path $MariaDbRoot 'bin/mariadbd.exe'
$MariaDbClient=Join-Path $MariaDbRoot 'bin/mariadb.exe'
$MariaDbAdmin=Join-Path $MariaDbRoot 'bin/mariadb-admin.exe'
$ProgramDataRoot=Join-Path $env:ProgramData 'OrchidApp'
$MariaDbData=Join-Path $ProgramDataRoot 'data/mariadb'
$UploadsRoot=Join-Path $ProgramDataRoot 'uploads'
$LauncherSettingsPath=Join-Path $ProgramDataRoot 'launcher-settings.json'
foreach ($path in @($MariaDbServer,$MariaDbClient,$MariaDbAdmin,$MariaDbData)) {
    if (-not (Test-Path -LiteralPath $path)) { throw "Required restore item missing: $path" }
}
Assert-NoPathAlias $MariaDbData
New-Item -ItemType Directory -Path $ProgramDataRoot -Force | Out-Null
Assert-NoPathAlias $ProgramDataRoot
$historyRoot=Join-Path $ProgramDataRoot 'restore-recovery'
if (Test-Path -LiteralPath $historyRoot) { Assert-NoPathAlias $historyRoot }
New-Item -ItemType Directory -Path $historyRoot -Force | Out-Null
Assert-NoPathAlias $historyRoot
$lockPath=Join-Path $ProgramDataRoot 'restore.lock'
Assert-ChildPath $lockPath $ProgramDataRoot
$restoreLock=[IO.File]::Open($lockPath,[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
$RecoveryMarker=Join-Path $ProgramDataRoot 'restore-pending.json'
$RestoreRoot=Join-Path $historyRoot ([guid]::NewGuid().ToString('N'))
$MariaDbServerLogPath=Join-Path $RestoreRoot 'mariadb-server.log'
$MariaDbServerErrorLogPath=Join-Path $RestoreRoot 'mariadb-server-error.log'
$PayloadRoot=Join-Path $RestoreRoot 'payload'
$StartedMariaDb=$false; $MariaDbProcess=$null
$RestoreHasStarted=$false
$RecoveryRecord=$null
$previousPassword=$env:MYSQL_PWD
try {
    Assert-ChildPath $RecoveryMarker $ProgramDataRoot
    $previousRecovery=$null
    if (Test-Path -LiteralPath $RecoveryMarker) {
        if (-not $RecoveryAction -or $BackupZip) { throw 'An interrupted restore requires an explicit RecoveryAction: RestoreInput or RestoreSafety. Do not retry an ordinary restore.' }
        $previousRecovery=Read-BackupJsonObject $RecoveryMarker
        if ($previousRecovery.importProcessId) {
            $previousImporter=Get-Process -Id $previousRecovery.importProcessId -ErrorAction SilentlyContinue
            if ($previousImporter -and $previousImporter.StartTime.ToUniversalTime().ToString('o') -eq $previousRecovery.importStartedUtc) {
                throw 'The previous database import process is still running. No recovery is authorised until it has exited; contact support rather than starting a competing restore.'
            }
        }
        if ($RecoveryAction -eq 'RestoreInput') { $BackupZip=$previousRecovery.preservedInput }
        else { $BackupZip=$previousRecovery.safetyBackup }
    }
    elseif ($RecoveryAction) { throw 'No interrupted restore is recorded. Select a normal backup instead.' }
    if ([string]::IsNullOrWhiteSpace($BackupZip)) { throw 'Select a BackupZip.' }
    $BackupZip=(Resolve-Path -LiteralPath $BackupZip).Path
    Assert-NoPathAlias $BackupZip
    Assert-ChildPath $RestoreRoot $ProgramDataRoot
    New-Item -ItemType Directory -Path $PayloadRoot -Force | Out-Null
    # Hold a read handle denying writers/deletion until a verified local copy exists.
    $preservedInput=Join-Path $RestoreRoot 'recovery-input.zip'
    $sourceStream=[IO.File]::Open($BackupZip,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
    try {
        $copyStream=[IO.File]::Create($preservedInput)
        try { $sourceStream.CopyTo($copyStream) } finally { $copyStream.Dispose() }
    } finally { $sourceStream.Dispose() }
    # All structural, settings and component validation precedes database import.
    Expand-CheckedBackup $preservedInput $PayloadRoot
    $payload=Read-BackupPayload $PayloadRoot
    $uploadsPrefix=(Get-FullLocalPath $UploadsRoot)+'\'
    if ($BackupZip.StartsWith($uploadsPrefix,[StringComparison]::OrdinalIgnoreCase)) { throw 'Keep the selected recovery ZIP outside the uploads directory being replaced.' }
    $safetyBackup=$null
    $RecoveryRecord=[ordered]@{version=1;status='Prepared';phase='CreatingSafetyBackup';updatedUtc=[DateTime]::UtcNow.ToString('o');originalInput=$BackupZip;preservedInput=$preservedInput;safetyBackup=$null;operationRoot=$RestoreRoot;error=$null;importProcessId=$null;importStartedUtc=$null}
    Save-RestorePhase 'CreatingSafetyBackup'
    if ($previousRecovery) {
        # Never replace the original safety copy with a dump of partially restored data.
        $safetyBackup=$previousRecovery.safetyBackup
        Copy-Item -LiteralPath $RecoveryMarker -Destination (Join-Path $RestoreRoot 'previous-recovery.json')
    }
    else {
        $safetyRoot=Join-Path $RestoreRoot 'safety'
        Write-Host 'Creating a verified safety backup of the current collection before replacement...'
        & (Join-Path $PSScriptRoot 'backup-orchidapp.ps1') -BackupsRoot $safetyRoot -MariaDbPort $MariaDbPort -SkipOldBackupPruning
        $safetyFiles=@(Get-ChildItem -LiteralPath $safetyRoot -Filter '*.zip' -File)
        if ($safetyFiles.Count -ne 1) { throw 'A unique safety backup was not produced; restore is not authorised.' }
        $safetyBackup=$safetyFiles[0].FullName
    }
    $RecoveryRecord.safetyBackup=$safetyBackup
    Save-RestorePhase 'Validated'
    Write-Host "Retained recovery input: $preservedInput"
    Write-Host "Original safety backup: $safetyBackup"
    $env:MYSQL_PWD='orchid'
    Start-OrchidDatabase
    # Persist before the first potentially destructive SQL statement, including crashes.
    $RestoreHasStarted=$true
    $RecoveryRecord.status='Pending'
    Save-RestorePhase 'ImportingDatabase'
    $import=[Diagnostics.Process]::new()
    $import.StartInfo=[Diagnostics.ProcessStartInfo]::new()
    $import.StartInfo.FileName=$MariaDbClient
    $import.StartInfo.Arguments="--no-defaults --protocol=TCP --host=127.0.0.1 --port=$MariaDbPort --user=orchid --connect-timeout=5 --default-character-set=utf8mb4 --abort-source-on-error"
    $import.StartInfo.UseShellExecute=$false
    $import.StartInfo.CreateNoWindow=$true
    $import.StartInfo.RedirectStandardInput=$true
    $import.StartInfo.RedirectStandardOutput=$true
    $import.StartInfo.RedirectStandardError=$true
    try {
        $import.Start() | Out-Null
        $RecoveryRecord.importProcessId=$import.Id
        $RecoveryRecord.importStartedUtc=$import.StartTime.ToUniversalTime().ToString('o')
        Save-RestorePhase 'ImportingDatabase'
        $stdout=$import.StandardOutput.ReadToEndAsync(); $stderr=$import.StandardError.ReadToEndAsync()
        $stream=[IO.File]::OpenRead((Join-Path $PayloadRoot 'orchids.sql'))
        try { $stream.CopyTo($import.StandardInput.BaseStream) } finally { $stream.Dispose(); $import.StandardInput.Close() }
        $import.WaitForExit()
        if ($import.ExitCode -ne 0) { throw "Database restore failed; SQL may be partially applied. Retain backup and inspect logs. $($stderr.Result)" }
    }
    finally { $import.Dispose() }
    Save-RestorePhase 'VerifyingPhotos'
    # An older archive may explicitly omit empty uploads, but DB references must agree.
    Assert-PhotoFiles $payload.Uploads
    Save-RestorePhase 'ReplacingUploads'
    Assert-ChildPath $UploadsRoot $ProgramDataRoot
    if (Test-Path -LiteralPath $UploadsRoot) { Remove-Item -LiteralPath $UploadsRoot -Recurse -Force }
    New-Item -ItemType Directory -Path $UploadsRoot | Out-Null
    if ($payload.HasUploads) {
        $items=@(Get-ChildItem -LiteralPath $payload.Uploads -Force)
        if ($items.Count) { Copy-Item -LiteralPath $items.FullName -Destination $UploadsRoot -Recurse -Force }
    }
    Save-RestorePhase 'ReplacingSettings'
    Assert-ChildPath $LauncherSettingsPath $ProgramDataRoot
    if ($payload.Settings) { Copy-Item -LiteralPath $payload.Settings -Destination $LauncherSettingsPath -Force }
    elseif (Test-Path -LiteralPath $LauncherSettingsPath) { Remove-Item -LiteralPath $LauncherSettingsPath -Force }
    Save-RestorePhase 'StoppingDatabase'
    Stop-OrchidDatabase
    $RecoveryRecord.status='Completed'
    Save-RestorePhase 'Completed'
    Assert-ChildPath $RecoveryMarker $ProgramDataRoot
    Remove-Item -LiteralPath $RecoveryMarker -Force
    $RestoreHasStarted=$false
    Write-Host 'Restore completed successfully: database, referenced photos and settings verified.'
    Write-Host 'Start OrchidApp again to verify the restored collection.'
}
catch {
    $failure=$_.Exception.Message
    if ($RestoreHasStarted) {
        $RecoveryRecord.status='Failed'
        $RecoveryRecord.error=$failure
        try { Save-RestorePhase $RecoveryRecord.phase } catch { Write-Warning "Recovery journal update failed; pending marker must be retained: $_" }
        throw "Restore stopped during $($RecoveryRecord.phase). SQL/files may be partially replaced. Normal startup is blocked. Retained input: $preservedInput. Safety copy: $safetyBackup. Use the launcher's recovery choice, or seek support with $RestoreRoot. Do not delete restore-pending.json or retry blindly. Cause: $failure"
    }
    if ($RecoveryRecord) {
        $RecoveryRecord.status='PreflightFailed'; $RecoveryRecord.error=$failure
        try { Save-RestorePhase $RecoveryRecord.phase } catch { Write-Warning 'Could not update retained preflight history.' }
        throw "Restore stopped before replacement. Retained input: $preservedInput. No restore SQL was started. Cause: $failure"
    }
    throw
}
finally {
    try { Stop-OrchidDatabase } finally { $env:MYSQL_PWD=$previousPassword; $restoreLock.Dispose() }
    # Retain input, safety archive, journal and extracted payload across restarts.
}
