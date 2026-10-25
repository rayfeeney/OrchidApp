param(
    [string]$RepoRoot=(Join-Path $PSScriptRoot '../..'),
    [string]$MariaDbRuntimeRoot,
    [string]$FixtureParent=[IO.Path]::GetTempPath(),
    [int]$SourcePort=53331,
    [int]$TargetPort=53332
)
$ErrorActionPreference='Stop'
$PSNativeCommandUseErrorActionPreference=$false
if (-not $IsWindows) { throw 'These packaged backup/restore checks require Windows.' }
$RepoRoot=(Resolve-Path -LiteralPath $RepoRoot).Path
if (-not $MariaDbRuntimeRoot) {
    $programFiles=$env:ProgramW6432
    if (-not $programFiles) { $programFiles=$env:ProgramFiles }
    $MariaDbRuntimeRoot=Join-Path $programFiles 'MariaDB 10.11'
}
$MariaDbRuntimeRoot=(Resolve-Path -LiteralPath $MariaDbRuntimeRoot).Path
$FixtureParent=(Resolve-Path -LiteralPath $FixtureParent).Path
$windowsPowerShell=Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe'
$client=Join-Path $MariaDbRuntimeRoot 'bin/mariadb.exe'
$admin=Join-Path $MariaDbRuntimeRoot 'bin/mariadb-admin.exe'
$server=Join-Path $MariaDbRuntimeRoot 'bin/mariadbd.exe'
$installer=Join-Path $MariaDbRuntimeRoot 'bin/mariadb-install-db.exe'
$cli=Join-Path $RepoRoot 'tests/BackupRestore.Checks/bin/Release/net8.0/BackupRestore.Checks.dll'
foreach ($file in @($client,$admin,$server,$installer,$cli)) { if (-not (Test-Path -LiteralPath $file)) { throw "Required fixture tool missing: $file" } }
foreach ($port in @($SourcePort,$TargetPort)) { if (Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue) { throw 'A test port is occupied; choose isolated unused ports.' } }
$root=Join-Path $FixtureParent ('orchids-backup-'+[guid]::NewGuid().ToString('N').Substring(0,12))
$installed=Join-Path $root 'installed package'
$legacy=Join-Path $root 'different legacy installation'
$legacyData=Join-Path $legacy 'data/mariadb'
$common=Join-Path $root 'pd'
$target=Join-Path $common 'OrchidApp'
$backups=Join-Path $root 'safety backups'
$prior=@{}
foreach ($name in @('ProgramData','MYSQL_PWD','MARIADB_HOST','MARIADB_PORT','MARIADB_USER','MARIADB_PASSWORD','MARIADB_DATABASE','MARIADB_CHARSET','MARIADB_COLLATION')) { $prior[$name]=[Environment]::GetEnvironmentVariable($name) }
$processes=[Collections.Generic.List[Diagnostics.Process]]::new()
$checks=0
function Check([string]$Name,[bool]$Pass) { if (-not $Pass) { throw "Check failed: $Name" }; $script:checks++ }
function Query([int]$Port,[string]$Sql) {
    $previous=$env:MYSQL_PWD; $env:MYSQL_PWD='isolated-backup-test'
    try {
        $result=& $client --no-defaults --protocol=TCP --host=127.0.0.1 "--port=$Port" --user=root --connect-timeout=5 --default-character-set=utf8mb4 --batch --skip-column-names "--execute=$Sql" 2>&1
        if ($LASTEXITCODE -ne 0) { throw "Fixture query failed: $($result -join "`n")" }
        $result
    } finally { $env:MYSQL_PWD=$previous }
}
function Start-Fixture([string]$Data,[int]$Port) {
    $p=Start-Process -FilePath $server -ArgumentList "--no-defaults --basedir=`"$MariaDbRuntimeRoot`" --datadir=`"$Data`" --port=$Port --bind-address=127.0.0.1 --console" -PassThru -WindowStyle Hidden -RedirectStandardOutput (Join-Path $root "server-$Port.log") -RedirectStandardError (Join-Path $root "server-$Port-error.log")
    $processes.Add($p)
    for ($attempt=0;$attempt -lt 30;$attempt++) {
        if ($p.HasExited) { throw 'Fixture server exited; inspect retained logs.' }
        try { Query $Port 'SELECT 1;' | Out-Null; return } catch { Start-Sleep -Seconds 1 }
    }
    throw 'Fixture server did not become ready.'
}
function Stop-Fixture([int]$Port) {
    $previous=$env:MYSQL_PWD; $env:MYSQL_PWD='isolated-backup-test'
    try { & $admin --no-defaults --protocol=TCP --host=127.0.0.1 "--port=$Port" --user=root shutdown | Out-Null; if ($LASTEXITCODE -ne 0) { throw 'Fixture shutdown failed.' } }
    finally { $env:MYSQL_PWD=$previous }
    foreach ($p in $processes) { if (-not $p.HasExited) { $p.WaitForExit(10000) | Out-Null } }
}
function Run-Tool([string]$Name,[string[]]$Arguments,[string]$ErrorText='') {
    $requestFile=Join-Path $root ('request-'+[guid]::NewGuid().ToString('N')+'.json')
    @{script=(Join-Path $installed "tools/$Name");arguments=@($Arguments)} | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $requestFile -Encoding UTF8
    $output=& $windowsPowerShell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'Run-Tool.ps1') -RequestFile $requestFile 2>&1
    $code=$LASTEXITCODE
    $records=@($output | ForEach-Object { [string]$_ } | Where-Object { $_.StartsWith('ORCHID_BACKUP_CHECK:') })
    if ($records.Count -ne 1) { throw "Child check protocol failed: $($output -join "`n")" }
    $result=$records[0].Substring('ORCHID_BACKUP_CHECK:'.Length) | ConvertFrom-Json
    if (($code -eq 0) -ne $result.success) { throw 'Child exit code/result disagree.' }
    if ($ErrorText) { Check "Rejected: $ErrorText" (-not $result.Success -and $result.Message.IndexOf($ErrorText,[StringComparison]::OrdinalIgnoreCase) -ge 0) }
    elseif (-not $result.Success) { throw ($output -join "`n") }
    else { $script:checks++ }
}
try {
    New-Item -ItemType Directory -Path (Join-Path $installed 'runtime/mariadb'),(Split-Path -Parent $legacyData),$backups -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $RepoRoot 'app/tools') -Destination $installed -Recurse
    # Executables only are shared; every database/upload/settings path is isolated.
    New-Item -ItemType Junction -Path (Join-Path $installed 'runtime/mariadb/win-x64') -Target $MariaDbRuntimeRoot | Out-Null
    & $installer "--datadir=$legacyData" --password=isolated-backup-test "--port=$SourcePort" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Disposable server initialization failed.' }
    Start-Fixture $legacyData $SourcePort
    $env:MARIADB_HOST='127.0.0.1';$env:MARIADB_PORT=[string]$SourcePort;$env:MARIADB_USER='root';$env:MARIADB_PASSWORD='isolated-backup-test';$env:MARIADB_DATABASE='orchids';$env:MARIADB_CHARSET='utf8mb4';$env:MARIADB_COLLATION='utf8mb4_unicode_ci'
    & (Join-Path $RepoRoot 'database/scripts/rebuild.ps1') -ConfirmDatabase orchids | Out-Null
    Query $SourcePort "CREATE USER 'orchid'@'127.0.0.1' IDENTIFIED BY 'orchid'; GRANT ALL PRIVILEGES ON *.* TO 'orchid'@'127.0.0.1'; CREATE USER 'orchid_shutdown'@'127.0.0.1' IDENTIFIED BY 'orchid_shutdown'; GRANT SHUTDOWN ON *.* TO 'orchid_shutdown'@'127.0.0.1';" | Out-Null
    Query $SourcePort "CALL orchids.spAddGenus('Backup fixture','fixture'); SET @taxon=(SELECT MIN(taxonId) FROM orchids.taxon); CALL orchids.spAddPlant(@taxon,NOW(),'fixture','Backup plant','Round trip café'); INSERT INTO orchids.plantevent(plantId,eventDateTime,eventDetails,observationTypeId) SELECT MIN(plantId),NOW(),'Photo fixture',(SELECT Id FROM orchids.observationtype WHERE typeCode='OBS_PHOTO') FROM orchids.plant; INSERT INTO orchids.plantphoto(plantEventId,plantId,fileName,thumbnailFileName,mimeType) SELECT MIN(plantEventId),MIN(plantId),'photo.jpg','thumb.jpg','image/jpeg' FROM orchids.plantevent; INSERT INTO orchids.taxonphoto(taxonId,fileName,thumbnailFileName,mimeType) SELECT MIN(taxonId),'taxon.jpg','taxon-thumb.jpg','image/jpeg' FROM orchids.taxon;" | Out-Null
    $plantId=[int](Query $SourcePort 'SELECT MIN(plantId) FROM orchids.plant;'); $taxonId=[int](Query $SourcePort 'SELECT MIN(taxonId) FROM orchids.taxon;')
    $uploads=Join-Path $legacy 'wwwroot/uploads'
    New-Item -ItemType Directory -Path (Join-Path $uploads "plants/$plantId"),(Join-Path $uploads "taxa/$taxonId") -Force | Out-Null
    foreach ($name in @("plants/$plantId/photo.jpg","plants/$plantId/thumb.jpg","taxa/$taxonId/taxon.jpg","taxa/$taxonId/taxon-thumb.jpg")) { [IO.File]::WriteAllText((Join-Path $uploads $name),"fixture-$name") }
    $settings=Join-Path $legacy 'launcher-settings.json'; '{"CloudBackupFolderPath":"C:\\Fixture cloud folder"}' | Set-Content -LiteralPath $settings -Encoding UTF8
    $busy=& dotnet $cli capture $legacy (Join-Path $root 'busy capture') 2>&1
    Check 'A running source database blocks capture' ($LASTEXITCODE -ne 0)
    Stop-Fixture $SourcePort
    $snapshot=& dotnet $cli capture $legacy (Join-Path $target 'migration-staging')
    if ($LASTEXITCODE -ne 0) { throw 'Source capture failed.' }
    $snapshot=[string]$snapshot
    Check 'Installed tools and captured legacy roots differ' ($installed -ne $snapshot)
    $env:ProgramData=$common
    Start-Fixture $legacyData $SourcePort
    Run-Tool 'backup-orchidapp.ps1' @('-BackupType','PreUpgrade','-LegacySourceRoot',$snapshot,'-BackupsRoot',$backups,'-MariaDbPort',"$SourcePort",'-SkipOldBackupPruning') 'identity mismatch'
    Check 'Unrelated listener creates no safety ZIP' (@(Get-ChildItem -LiteralPath $backups -Filter '*.zip').Count -eq 0)
    Check 'Unrelated listener remains intact' ([int](Query $SourcePort 'SELECT COUNT(*) FROM orchids.plant;') -eq 1)
    Stop-Fixture $SourcePort
    # That intentional original-server restart changed raw engine files. Capture its
    # new quiescent identity for the actual migration, rather than reusing old proof.
    $snapshot=& dotnet $cli capture $legacy (Join-Path $target 'migration-staging')
    if ($LASTEXITCODE -ne 0) { throw 'Post-listener-test source recapture failed.' }
    $snapshot=[string]$snapshot
    Run-Tool 'backup-orchidapp.ps1' @('-BackupType','PreUpgrade','-LegacySourceRoot',$snapshot,'-BackupsRoot',$backups,'-MariaDbPort',"$SourcePort",'-SkipOldBackupPruning')
    $zip=@(Get-ChildItem -LiteralPath $backups -Filter '*.zip')[0].FullName
    Check 'Source original files retained' (Test-Path -LiteralPath $settings)
    $interrupted=& dotnet $cli migrate-reconciled $snapshot $common $zip interrupt 2>&1
    Check 'Interrupted raw copy reports failure' ($LASTEXITCODE -ne 0)
    $migrationFile=Join-Path $target 'migration-state.json'
    Check 'Interrupted migration retains copying state' ((Get-Content -LiteralPath $migrationFile -Raw | ConvertFrom-Json).Phase -eq 'Copying')
    & dotnet $cli resume-migration $common
    if ($LASTEXITCODE -ne 0) { throw 'Recorded raw-file copy resume failed.' }
    $copied=Get-Content -LiteralPath $migrationFile -Raw | ConvertFrom-Json
    Check 'Raw copy completion still awaits readiness' ($copied.Phase -eq 'AwaitingReadiness' -and $copied.MigrationStatus -ne 'Completed')
    $failedStart=Start-Process -FilePath $server -ArgumentList "--no-defaults --basedir=`"$MariaDbRuntimeRoot`" --datadir=`"$(Join-Path $target 'data/mariadb')`" --port=$TargetPort --bind-address=127.0.0.1 --orchidapp-deliberately-invalid-option" -PassThru -WindowStyle Hidden -RedirectStandardOutput (Join-Path $root 'failed-start.log') -RedirectStandardError (Join-Path $root 'failed-start-error.log')
    $processes.Add($failedStart);$null=$failedStart.Handle
    if (-not $failedStart.WaitForExit(10000)) { $failedStart.Kill(); throw 'Disposable invalid-option server did not exit.' }
    Check 'Real migrated-database startup failure is reported' ($failedStart.ExitCode -ne 0)
    & dotnet $cli fail-migration-readiness $common
    if ($LASTEXITCODE -ne 0) { throw 'Could not record fixture readiness failure.' }
    $failedState=Get-Content -LiteralPath $migrationFile -Raw | ConvertFrom-Json
    Check 'Database startup failure retains readiness phase' ($failedState.Phase -eq 'AwaitingReadiness' -and $failedState.MigrationStatus -eq 'Failed')
    $rawWitness=(Get-ChildItem -LiteralPath (Join-Path $target 'data/mariadb/orchids') -File | Select-Object -First 1).FullName
    $rawHash=(Get-FileHash -LiteralPath $rawWitness).Hash
    & dotnet $cli resume-migration $common
    Check 'Next launch retries readiness without recopying raw database' ($LASTEXITCODE -eq 0 -and (Get-FileHash -LiteralPath $rawWitness).Hash -eq $rawHash)
    Start-Fixture (Join-Path $target 'data/mariadb') $TargetPort
    Check 'Migrated MariaDB starts with expected plant data' ((Query $TargetPort 'SELECT plantNotes FROM orchids.plant;') -ceq 'Round trip café')
    $actualData=[IO.Path]::GetFullPath([string](Query $TargetPort 'SELECT @@datadir;')).TrimEnd([char[]]@('\','/'))
    $expectedData=[IO.Path]::GetFullPath((Join-Path $target 'data/mariadb')).TrimEnd([char[]]@('\','/'))
    Check 'Migrated database listener has expected identity' ($actualData -ieq $expectedData)
    & dotnet $cli complete-migration $common
    if ($LASTEXITCODE -ne 0) { throw 'Migration completion state failed.' }
    Check 'Verified migration completion persisted' ((Get-Content -LiteralPath $migrationFile -Raw | ConvertFrom-Json).MigrationStatus -eq 'Completed')
    $resolved=& dotnet $cli migration-layout $common
    Check 'Next launch selects verified target with original retained' ($LASTEXITCODE -eq 0 -and $resolved -eq 'ProgramDataLayoutInPlace')
    Query $TargetPort "UPDATE orchids.plant SET plantNotes='changed';" | Out-Null
    'changed' | Set-Content (Join-Path $target "uploads/plants/$plantId/photo.jpg")
    '{"CloudBackupFolderPath":"wrong"}' | Set-Content (Join-Path $target 'launcher-settings.json')
    Run-Tool 'restore-orchidapp.ps1' @('-BackupZip',$zip,'-MariaDbPort',"$TargetPort")
    Check 'Restored plant record and Unicode notes' ((Query $TargetPort 'SELECT plantNotes FROM orchids.plant;') -ceq 'Round trip café')
    foreach ($relative in @("plants/$plantId/photo.jpg","plants/$plantId/thumb.jpg","taxa/$taxonId/taxon.jpg","taxa/$taxonId/taxon-thumb.jpg")) { Check "Restored $relative" ((Get-FileHash -LiteralPath (Join-Path $uploads $relative)).Hash -eq (Get-FileHash -LiteralPath (Join-Path $target "uploads/$relative")).Hash) }
    Check 'Nested settings restored exactly' ((Get-FileHash -LiteralPath $settings).Hash -eq (Get-FileHash -LiteralPath (Join-Path $target 'launcher-settings.json')).Hash)
    $legacyArchive=Join-Path $root 'old archive'; Expand-Archive -LiteralPath $zip -DestinationPath $legacyArchive
    $manifest=Get-Content (Join-Path $legacyArchive 'manifest.json') -Raw | ConvertFrom-Json
    foreach ($property in @('formatVersion','files','launcherSettingsIncluded')) { $manifest.PSObject.Properties.Remove($property) }
    $manifest | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $legacyArchive 'manifest.json')
    Copy-Item -LiteralPath (Join-Path $legacyArchive 'launcher-settings/launcher-settings.json') -Destination $legacyArchive
    Remove-Item -LiteralPath (Join-Path $legacyArchive 'launcher-settings/launcher-settings.json')
    $oldZip=Join-Path $root 'legacy-root-settings.zip'; Compress-Archive -Path (Join-Path $legacyArchive '*') -DestinationPath $oldZip
    Run-Tool 'restore-orchidapp.ps1' @('-BackupZip',$oldZip,'-MariaDbPort',"$TargetPort")
    Check 'Old root-settings archive round trip' ((Get-FileHash -LiteralPath $settings).Hash -eq (Get-FileHash -LiteralPath (Join-Path $target 'launcher-settings.json')).Hash)
    $bad=Join-Path $root 'corrupt archive'; Expand-Archive -LiteralPath $zip -DestinationPath $bad
    Add-Content -LiteralPath (Join-Path $bad 'orchids.sql') '-- changed'
    $badZip=Join-Path $root 'corrupt.zip'; Compress-Archive -Path (Join-Path $bad '*') -DestinationPath $badZip
    Query $TargetPort "UPDATE orchids.plant SET plantNotes='preserve validation witness';" | Out-Null
    Run-Tool 'restore-orchidapp.ps1' @('-BackupZip',$badZip,'-MariaDbPort',"$TargetPort") 'checksum changed'
    Check 'Corrupt payload rejected before SQL import' ((Query $TargetPort 'SELECT plantNotes FROM orchids.plant;') -ceq 'preserve validation witness')
    $normalBackups=Join-Path $root 'normal backups'
    Run-Tool 'backup-orchidapp.ps1' @('-BackupsRoot',$normalBackups,'-MariaDbPort',"$TargetPort",'-SkipOldBackupPruning')
    $normalZip=@(Get-ChildItem -LiteralPath $normalBackups -Filter '*.zip')[0].FullName
    Query $TargetPort "UPDATE orchids.plant SET plantNotes='normal restore witness';" | Out-Null
    Run-Tool 'restore-orchidapp.ps1' @('-BackupZip',$normalZip,'-MariaDbPort',"$TargetPort")
    Check 'Normal backup/restore round trip' ((Query $TargetPort 'SELECT plantNotes FROM orchids.plant;') -ceq 'preserve validation witness')
    $pendingPath=Join-Path $target 'restore-pending.json'
    $historyRoot=Join-Path $target 'restore-recovery'
    $preflightLock=[IO.File]::Open((Join-Path $target "uploads/plants/$plantId/photo.jpg"),[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::None)
    try { Run-Tool 'restore-orchidapp.ps1' @('-BackupZip',$zip,'-MariaDbPort',"$TargetPort") 'before replacement' }
    finally { $preflightLock.Dispose() }
    Check 'Safety-copy failure creates no pending destructive restore' (-not (Test-Path -LiteralPath $pendingPath))
    Check 'Safety-copy failure leaves current SQL untouched' ((Query $TargetPort 'SELECT plantNotes FROM orchids.plant;') -ceq 'preserve validation witness')
    $preflightRecords=@(Get-ChildItem -LiteralPath $historyRoot -Filter recovery.json -Recurse -File | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json } | Where-Object { $_.status -eq 'PreflightFailed' })
    Check 'Safety-copy failure retains input and protection history' ($preflightRecords.Count -eq 1 -and (Test-Path -LiteralPath $preflightRecords[0].preservedInput))
    $failedSqlRoot=Join-Path $root 'sql failure archive'
    Expand-Archive -LiteralPath $oldZip -DestinationPath $failedSqlRoot
    Add-Content -LiteralPath (Join-Path $failedSqlRoot 'orchids.sql') "SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Intentional restore failure';"
    $failedSqlZip=Join-Path $root 'sql failure.zip'
    Compress-Archive -Path (Join-Path $failedSqlRoot '*') -DestinationPath $failedSqlZip
    $originalHash=(Get-FileHash -LiteralPath $failedSqlZip).Hash
    Run-Tool 'restore-orchidapp.ps1' @('-BackupZip',$failedSqlZip,'-MariaDbPort',"$TargetPort") 'ImportingDatabase'
    $pending=Get-Content -LiteralPath $pendingPath -Raw | ConvertFrom-Json
    Check 'SQL failure persists failed phase' ($pending.status -eq 'Failed' -and $pending.phase -eq 'ImportingDatabase')
    Check 'Selected recovery ZIP preserved byte for byte' ((Get-FileHash -LiteralPath $pending.preservedInput).Hash -eq $originalHash -and (Get-FileHash -LiteralPath $failedSqlZip).Hash -eq $originalHash)
    Check 'Safety backup retained outside routine retention' ((Test-Path -LiteralPath $pending.safetyBackup) -and $pending.safetyBackup.StartsWith($historyRoot))
    Run-Tool 'restore-orchidapp.ps1' @('-BackupZip',$zip,'-MariaDbPort',"$TargetPort") 'explicit RecoveryAction'
    $recordBeforeGuard=Get-Content -LiteralPath $pendingPath -Raw
    $pending.importProcessId=$PID
    $pending.importStartedUtc=(Get-Process -Id $PID).StartTime.ToUniversalTime().ToString('o')
    $pending | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $pendingPath -Encoding UTF8
    Run-Tool 'restore-orchidapp.ps1' @('-RecoveryAction','RestoreSafety','-MariaDbPort',"$TargetPort") 'previous database import process is still running'
    $recordBeforeGuard | Set-Content -LiteralPath $pendingPath -Encoding UTF8
    Run-Tool 'backup-orchidapp.ps1' @('-BackupsRoot',$normalBackups,'-MariaDbPort',"$TargetPort",'-SkipOldBackupPruning') 'Normal backups are blocked'
    Run-Tool 'restore-orchidapp.ps1' @('-RecoveryAction','RestoreSafety','-MariaDbPort',"$TargetPort")
    Check 'Safety recovery clears pending marker' (-not (Test-Path -LiteralPath $pendingPath))
    Check 'Safety recovery restores pre-attempt SQL' ((Query $TargetPort 'SELECT plantNotes FROM orchids.plant;') -ceq 'preserve validation witness')
    Check 'Original retained input survives safety recovery' ((Get-FileHash -LiteralPath $pending.preservedInput).Hash -eq $originalHash)

    $missingRoot=Join-Path $root 'missing restored photo'
    Expand-Archive -LiteralPath $oldZip -DestinationPath $missingRoot
    Remove-Item -LiteralPath (Join-Path $missingRoot "uploads/plants/$plantId/photo.jpg")
    $missingManifest=Get-Content -LiteralPath (Join-Path $missingRoot 'manifest.json') -Raw | ConvertFrom-Json
    $missingManifest.uploadsFileCount=3
    $missingManifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $missingRoot 'manifest.json') -Encoding UTF8
    $missingZip=Join-Path $root 'missing referenced photo.zip'
    Compress-Archive -Path (Join-Path $missingRoot '*') -DestinationPath $missingZip
    Run-Tool 'restore-orchidapp.ps1' @('-BackupZip',$missingZip,'-MariaDbPort',"$TargetPort") 'VerifyingPhotos'
    $missingPending=Get-Content -LiteralPath $pendingPath -Raw | ConvertFrom-Json
    Check 'Post-import photo failure retains original uploads' (Test-Path -LiteralPath (Join-Path $target "uploads/plants/$plantId/photo.jpg"))
    Run-Tool 'restore-orchidapp.ps1' @('-RecoveryAction','RestoreSafety','-MariaDbPort',"$TargetPort")
    foreach ($phase in @('ReplacingUploads','ReplacingSettings')) {
        $lockedPath=Join-Path $target 'launcher-settings.json'
        if ($phase -eq 'ReplacingUploads') { $lockedPath=Join-Path $target "uploads/plants/$plantId/photo.jpg" }
        $held=[IO.File]::Open($lockedPath,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
        try { Run-Tool 'restore-orchidapp.ps1' @('-BackupZip',$zip,'-MariaDbPort',"$TargetPort") $phase }
        finally { $held.Dispose() }
        $lockedPending=Get-Content -LiteralPath $pendingPath -Raw | ConvertFrom-Json
        Check "$phase records persistent recovery state" ($lockedPending.phase -eq $phase -and (Test-Path -LiteralPath $lockedPending.safetyBackup))
        Run-Tool 'restore-orchidapp.ps1' @('-RecoveryAction','RestoreInput','-MariaDbPort',"$TargetPort")
        Check "$phase retained input recovery clears block" (-not (Test-Path -LiteralPath $pendingPath))
        Check "$phase recovers photo bytes" ((Get-FileHash -LiteralPath (Join-Path $uploads "plants/$plantId/photo.jpg")).Hash -eq (Get-FileHash -LiteralPath (Join-Path $target "uploads/plants/$plantId/photo.jpg")).Hash)
        Check "$phase recovers settings bytes" ((Get-FileHash -LiteralPath $settings).Hash -eq (Get-FileHash -LiteralPath (Join-Path $target 'launcher-settings.json')).Hash)
    }
    Check 'Completed attempt journals remain across subsequent restores' (@(Get-ChildItem -LiteralPath $historyRoot -Filter recovery.json -Recurse -File).Count -ge 8)
    Stop-Fixture $TargetPort
    Run-Tool 'restore-orchidapp.ps1' @('-BackupZip',$zip,'-MariaDbPort',"$TargetPort")
    Check 'Restore-owned MariaDB stops cleanly before success' (-not (Get-NetTCPConnection -LocalPort $TargetPort -State Listen -ErrorAction SilentlyContinue))
    Check 'Owned-process completion clears pending marker' (-not (Test-Path -LiteralPath $pendingPath))
    Start-Fixture (Join-Path $target 'data/mariadb') $TargetPort
    Check 'Restored database restarts with expected records' ((Query $TargetPort 'SELECT plantNotes FROM orchids.plant;') -ceq 'Round trip café')
    $retentionRoot=Join-Path $root 'routine retention'
    New-Item -ItemType Directory -Path $retentionRoot | Out-Null
    $retentionPayload=Join-Path $root 'retention payload'
    Expand-Archive -LiteralPath $normalZip -DestinationPath $retentionPayload
    . (Join-Path $RepoRoot 'app/tools/Backup-Contract.ps1')
    $oldRoutines=@()
    foreach ($number in @(1,2)) {
        $archiveName='OrchidAppBackup_20000101_'+$number.ToString('000000')
        $retentionManifest=Get-Content -LiteralPath (Join-Path $retentionPayload 'manifest.json') -Raw | ConvertFrom-Json
        $retentionManifest.backupName=$archiveName
        $retentionManifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $retentionPayload 'manifest.json') -Encoding UTF8
        $archive=Join-Path $retentionRoot ($archiveName+'.zip')
        New-OrchidBackupArchive $retentionPayload $archive
        $oldRoutines+=$archive
    }
    $unrelatedZip=Join-Path $retentionRoot 'trusted-separate-copy.zip';Copy-Item -LiteralPath $normalZip -Destination $unrelatedZip
    Run-Tool 'backup-orchidapp.ps1' @('-BackupsRoot',$retentionRoot,'-MariaDbPort',"$TargetPort",'-BackupsToKeep','1')
    Check 'Native normal backup prunes only old routine archives' (-not (Test-Path -LiteralPath $oldRoutines[0]) -and -not (Test-Path -LiteralPath $oldRoutines[1]))
    Check 'Native retention leaves unrelated recovery ZIP intact' ((Get-FileHash -LiteralPath $unrelatedZip).Hash -eq (Get-FileHash -LiteralPath $normalZip).Hash)
    $latestRoutine=@(Get-ChildItem -LiteralPath $retentionRoot -Filter 'OrchidAppBackup_*.zip' -File)
    Check 'Native minimum count retains the new verified archive' ($latestRoutine.Count -eq 1)
    Run-Tool 'backup-orchidapp.ps1' @('-BackupsRoot',$retentionRoot,'-MariaDbPort',"$TargetPort",'-BackupsToKeep','1','-SkipOldBackupPruning')
    Check 'Native skip switch preserves previous routine backup' (@(Get-ChildItem -LiteralPath $retentionRoot -Filter 'OrchidAppBackup_*.zip' -File).Count -eq 2 -and (Test-Path -LiteralPath $latestRoutine[0].FullName))
    $beforeFailure=@(Get-ChildItem -LiteralPath $retentionRoot -Filter '*.zip' -File).Count
    $retentionPhoto=Join-Path $target "uploads/plants/$plantId/photo.jpg"
    $retentionHeld=[IO.File]::Open($retentionPhoto,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::None)
    try { Run-Tool 'backup-orchidapp.ps1' @('-BackupsRoot',$retentionRoot,'-MariaDbPort',"$TargetPort",'-BackupsToKeep','1') 'another process' }
    finally { $retentionHeld.Dispose() }
    Check 'Failed new backup does not prune existing archives' (@(Get-ChildItem -LiteralPath $retentionRoot -Filter '*.zip' -File).Count -eq $beforeFailure)
    Run-Tool 'backup-orchidapp.ps1' @('-BackupType','PreUpgrade','-BackupsRoot',$backups,'-MariaDbPort',"$SourcePort") 'explicit LegacySourceRoot'
    Remove-Item -LiteralPath (Join-Path $snapshot "wwwroot/uploads/plants/$plantId/photo.jpg")
    Run-Tool 'backup-orchidapp.ps1' @('-BackupType','PreUpgrade','-LegacySourceRoot',$snapshot,'-BackupsRoot',$backups,'-MariaDbPort',"$SourcePort",'-SkipOldBackupPruning') 'photo is missing'
    Check 'Missing photo cannot create another safety ZIP' (@(Get-ChildItem -LiteralPath $backups -Filter '*.zip').Count -eq 1)
    Stop-Fixture $TargetPort
    Write-Host "$checks Windows packaged backup/restore database checks passed. Fixtures retained: $root"
}
finally {
    foreach ($port in @($SourcePort,$TargetPort)) {
        if (@($processes | Where-Object { -not $_.HasExited }).Count -and (Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue)) { Stop-Fixture $port }
    }
    foreach ($name in $prior.Keys) { [Environment]::SetEnvironmentVariable($name,$prior[$name]) }
}
