param(
    [Parameter(Mandatory=$true)][string]$BackupZip,
    [ValidateRange(1,65535)][int]$MariaDbPort=3308
)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Backup-Contract.ps1')
$AppRoot=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$MariaDbRoot=Join-Path $AppRoot 'runtime/mariadb/win-x64'
$MariaDbServer=Join-Path $MariaDbRoot 'bin/mariadbd.exe'
$MariaDbClient=Join-Path $MariaDbRoot 'bin/mariadb.exe'
$MariaDbAdmin=Join-Path $MariaDbRoot 'bin/mariadb-admin.exe'
$ProgramDataRoot=Join-Path $env:ProgramData 'OrchidApp'
$MariaDbData=Join-Path $ProgramDataRoot 'data/mariadb'
$UploadsRoot=Join-Path $ProgramDataRoot 'uploads'
$LauncherSettingsPath=Join-Path $ProgramDataRoot 'launcher-settings.json'
$BackupZip=(Resolve-Path -LiteralPath $BackupZip).Path
foreach ($path in @($MariaDbServer,$MariaDbClient,$MariaDbAdmin,$MariaDbData)) {
    if (-not (Test-Path -LiteralPath $path)) { throw "Required restore item missing: $path" }
}
Assert-NoPathAlias $MariaDbData
New-Item -ItemType Directory -Path $ProgramDataRoot -Force | Out-Null
Assert-NoPathAlias $ProgramDataRoot
$RestoreRoot=Join-Path $ProgramDataRoot ('restore-temp/'+[guid]::NewGuid().ToString('N'))
$MariaDbServerLogPath=Join-Path $RestoreRoot 'mariadb-server.log'
$MariaDbServerErrorLogPath=Join-Path $RestoreRoot 'mariadb-server-error.log'
$PayloadRoot=Join-Path $RestoreRoot 'payload'
New-Item -ItemType Directory -Path $PayloadRoot -Force | Out-Null
$StartedMariaDb=$false; $MariaDbProcess=$null
$previousPassword=$env:MYSQL_PWD
try {
    # All structural, settings and component validation precedes database import.
    Expand-CheckedBackup $BackupZip $PayloadRoot
    $payload=Read-BackupPayload $PayloadRoot
    $uploadsPrefix=(Get-FullLocalPath $UploadsRoot)+'\'
    if ($BackupZip.StartsWith($uploadsPrefix,[StringComparison]::OrdinalIgnoreCase)) { throw 'Keep the selected recovery ZIP outside the uploads directory being replaced.' }
    $env:MYSQL_PWD='orchid'
    Start-OrchidDatabase
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
        $stdout=$import.StandardOutput.ReadToEndAsync(); $stderr=$import.StandardError.ReadToEndAsync()
        $stream=[IO.File]::OpenRead((Join-Path $PayloadRoot 'orchids.sql'))
        try { $stream.CopyTo($import.StandardInput.BaseStream) } finally { $stream.Dispose(); $import.StandardInput.Close() }
        $import.WaitForExit()
        if ($import.ExitCode -ne 0) { throw "Database restore failed; SQL may be partially applied. Retain backup and inspect logs. $($stderr.Result)" }
    }
    finally { $import.Dispose() }
    # An older archive may explicitly omit empty uploads, but DB references must agree.
    Assert-PhotoFiles $payload.Uploads
    Assert-ChildPath $UploadsRoot $ProgramDataRoot
    if (Test-Path -LiteralPath $UploadsRoot) { Remove-Item -LiteralPath $UploadsRoot -Recurse -Force }
    New-Item -ItemType Directory -Path $UploadsRoot | Out-Null
    if ($payload.HasUploads) {
        $items=@(Get-ChildItem -LiteralPath $payload.Uploads -Force)
        if ($items.Count) { Copy-Item -LiteralPath $items.FullName -Destination $UploadsRoot -Recurse -Force }
    }
    Assert-ChildPath $LauncherSettingsPath $ProgramDataRoot
    if ($payload.Settings) { Copy-Item -LiteralPath $payload.Settings -Destination $LauncherSettingsPath -Force }
    elseif (Test-Path -LiteralPath $LauncherSettingsPath) { Remove-Item -LiteralPath $LauncherSettingsPath -Force }
    Stop-OrchidDatabase
    Write-Host 'Restore completed successfully: database, referenced photos and settings verified.'
    Write-Host 'Start OrchidApp again to verify the restored collection.'
}
finally {
    try { Stop-OrchidDatabase } finally { $env:MYSQL_PWD=$previousPassword }
    # Keep unique extracted input/logs for diagnosis; recovery orchestration is C08.
}
