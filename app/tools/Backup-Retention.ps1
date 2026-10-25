# Windows PowerShell 5.1 / PowerShell 7. Only verified, recognised routine ZIPs are eligible.
function Get-RetentionProtectedPaths([string]$ProgramDataRoot) {
    $protected=@{}
    $history=Join-Path $ProgramDataRoot 'restore-recovery'
    if (Test-Path -LiteralPath $history) {
        Assert-NoPathAlias $history
        foreach ($directory in @(Get-ChildItem -LiteralPath $history -Directory -Force)) {
            Assert-NoPathAlias $directory.FullName
            $recordPath=Join-Path $directory.FullName 'recovery.json'
            if (-not (Test-Path -LiteralPath $recordPath)) { continue }
            Assert-NoPathAlias $recordPath
            $record=Read-BackupJsonObject $recordPath
            foreach ($field in @('originalInput','preservedInput')) {
                if ($record.$field -isnot [string] -or [string]::IsNullOrWhiteSpace($record.$field)) { throw 'Incomplete restore history; retention cannot identify all recovery inputs.' }
                $protected[(Get-FullLocalPath $record.$field)]=$true
            }
            if ($null -ne $record.safetyBackup) {
                if ($record.safetyBackup -isnot [string]) { throw 'Invalid safety backup path in restore history.' }
                $protected[(Get-FullLocalPath $record.safetyBackup)]=$true
            }
        }
    }
    $migrationPath=Join-Path $ProgramDataRoot 'migration-state.json'
    if (Test-Path -LiteralPath $migrationPath) {
        Assert-NoPathAlias $migrationPath
        $migration=Read-BackupJsonObject $migrationPath
        if ($migration.SchemaVersion -notin @(1,2) -or $migration.PreUpgradeBackupPath -isnot [string] -or [string]::IsNullOrWhiteSpace($migration.PreUpgradeBackupPath)) {
            throw 'Incomplete migration state; retention cannot identify its safety backup.'
        }
        $protected[(Get-FullLocalPath $migration.PreUpgradeBackupPath)]=$true
    }
    $protected
}

function Invoke-BackupRetention {
    param(
        [ValidateSet('Normal','PreUpgrade')][string]$BackupType='Normal',
        [Parameter(Mandatory=$true)][string]$BackupsRoot,
        [Parameter(Mandatory=$true)][string]$CurrentBackup,
        [Parameter(Mandatory=$true)][string]$ProgramDataRoot,
        [ValidateRange(1,2147483647)][int]$BackupsToKeep=3,
        [switch]$SkipOldBackupPruning
    )
    $verificationRoot=$null
    try {
        if ($BackupType -ne 'Normal' -or $SkipOldBackupPruning) {
            Write-Host 'Old backup pruning disabled for this backup run.'
            return
        }
        $root=Get-FullLocalPath $BackupsRoot
        Assert-NoPathAlias $root
        foreach ($protectedRoot in @((Join-Path $ProgramDataRoot 'restore-recovery'),(Join-Path $ProgramDataRoot 'backups/pre-upgrade'),(Join-Path $ProgramDataRoot 'backups/pre-migration'))) {
            $protectedRoot=Get-FullLocalPath $protectedRoot
            if ($root -ieq $protectedRoot -or $root.StartsWith($protectedRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) {
                Write-Host 'Safety/recovery directory is exempt from routine backup pruning.'
                return
            }
        }
        if (Test-Path -LiteralPath (Join-Path $ProgramDataRoot 'restore-pending.json')) { throw 'Restore recovery is pending; no retention deletion is authorised.' }
        # Read every protection record before planning any deletion. Bad history fails closed.
        $protected=Get-RetentionProtectedPaths $ProgramDataRoot
        $current=Get-FullLocalPath $CurrentBackup
        Assert-ChildPath $current $root
        if ((Split-Path -Parent $current) -ine $root) { throw 'Current backup is not a direct member of the retention directory.' }
        $pattern='^OrchidAppBackup_[0-9]{8}_[0-9]{6}(?:_[0-9]{3}_[0-9a-fA-F]{8})?\.zip$'
        $files=@(Get-ChildItem -LiteralPath $root -File -Force | Where-Object { $_.Name -match $pattern -and $_.FullName -ine $current } |
            Sort-Object @{Expression={$_.LastWriteTimeUtc};Descending=$true},@{Expression={$_.Name};Descending=$true})
        $currentFile=Get-Item -LiteralPath $current -Force
        if ($currentFile.Name -notmatch $pattern) { throw 'Current backup has an unrecognised routine archive name.' }
        $verificationRoot=Join-Path ([IO.Path]::GetTempPath()) ('orchid-retention-'+[guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $verificationRoot | Out-Null
        $plan=@();$retained=0
        foreach ($file in @($currentFile)+$files) {
            if ($file.FullName -ine $current -and $protected.ContainsKey((Get-FullLocalPath $file.FullName))) { continue }
            $checkRoot=Join-Path $verificationRoot ([guid]::NewGuid().ToString('N'))
            try {
                Assert-ChildPath $file.FullName $root
                $hash=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
                Expand-CheckedBackup $file.FullName $checkRoot
                $payload=Read-BackupPayload $checkRoot
                if ($payload.Manifest.backupType -cne 'Normal' -or $payload.Manifest.backupName -cne $file.BaseName -or
                    ($payload.Manifest.sourceRoot -and (Get-FullLocalPath $payload.Manifest.sourceRoot) -ine (Get-FullLocalPath $ProgramDataRoot)) -or
                    ($payload.Manifest.mariaDbDataRoot -and (Get-FullLocalPath $payload.Manifest.mariaDbDataRoot) -ine (Get-FullLocalPath (Join-Path $ProgramDataRoot 'data/mariadb')))) {
                    throw 'Archive metadata does not identify this routine backup collection.'
                }
                if ($hash -ne (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash) { throw 'Archive changed while retention validated it.' }
                if ($retained -lt $BackupsToKeep) { $retained++; continue }
                $plan+=@{path=$file.FullName;hash=$hash}
            }
            catch {
                if ($file.FullName -ieq $current) { throw }
                Write-Warning "Retention preserved unrecognised, changed or unreadable archive '$($file.Name)': $($_.Exception.Message)"
            }
            finally {
                if (Test-Path -LiteralPath $checkRoot) {
                    Assert-ChildPath $checkRoot $verificationRoot
                    Remove-Item -LiteralPath $checkRoot -Recurse -Force
                }
            }
        }
        foreach ($entry in $plan) {
            try {
                Assert-ChildPath $entry.path $root
                if ((Test-Path -LiteralPath (Join-Path $ProgramDataRoot 'restore-pending.json')) -or (Get-RetentionProtectedPaths $ProgramDataRoot).ContainsKey((Get-FullLocalPath $entry.path))) {
                    Write-Host 'Retention preserved a newly protected recovery backup.'
                    continue
                }
                if ((Get-FileHash -LiteralPath $entry.path -Algorithm SHA256).Hash -ne $entry.hash) { throw 'Archive changed after retention planning.' }
                Remove-Item -LiteralPath $entry.path -Force
                Write-Host "Removed old routine backup: $([IO.Path]::GetFileName($entry.path))"
            }
            catch { Write-Warning "Retention kept '$($entry.path)': $($_.Exception.Message)" }
        }
        Write-Host "Routine retention completed: up to $BackupsToKeep unprotected verified backups, plus protected/unrecognised files."
    }
    catch { Write-Warning "Backup is retained; old backup pruning skipped: $($_.Exception.Message)" }
    finally {
        if ($verificationRoot -and (Test-Path -LiteralPath $verificationRoot)) {
            try {
                Assert-ChildPath $verificationRoot ([IO.Path]::GetTempPath())
                Remove-Item -LiteralPath $verificationRoot -Recurse -Force
            }
            catch { Write-Warning "Retention verification files retained for review: $verificationRoot" }
        }
    }
}
