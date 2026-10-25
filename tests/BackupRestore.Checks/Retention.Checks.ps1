param([string]$RepoRoot=(Join-Path $PSScriptRoot '../..'))
$ErrorActionPreference='Stop'
. (Join-Path $RepoRoot 'app/tools/Backup-Contract.ps1')
. (Join-Path $RepoRoot 'app/tools/Backup-Retention.ps1')
$root=Join-Path ([IO.Path]::GetTempPath()) ('orchids-retention-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $root | Out-Null
$checks=0
function Check([string]$Name,[bool]$Pass) { if (-not $Pass) { throw "Check failed: $Name" }; $script:checks++ }
function Reject([string]$Name,[scriptblock]$Action) { $rejected=$false;try { & $Action | Out-Null } catch { $rejected=$true };Check $Name $rejected }
function Archive([string]$Destination,[string]$ProgramDataRoot,[string]$Type='Normal',[int]$Format=2,[bool]$HiddenFile=$false) {
    $payload=Join-Path $root ([guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path (Join-Path $payload 'uploads') -Force | Out-Null
    'SELECT 1;' | Set-Content -LiteralPath (Join-Path $payload 'orchids.sql')
    'baseline' | Set-Content -LiteralPath (Join-Path $payload 'schemaversion.txt')
    if ($HiddenFile) {
        $hiddenPath=Join-Path $payload 'uploads/hidden.txt'
        'hidden upload bytes' | Set-Content -LiteralPath $hiddenPath
        [IO.File]::SetAttributes($hiddenPath,[IO.FileAttributes]::Hidden)
    }
    $files=@(Get-PayloadFiles $payload | ForEach-Object { @{path=$_.FullName.Substring($payload.Length+1).Replace('\','/');length=$_.Length;sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash} })
    $manifest=@{backupType=$Type;backupName=[IO.Path]::GetFileNameWithoutExtension($Destination);formatVersion=$Format;database='orchids';databaseBackup='orchids.sql';uploadsIncluded=$true;uploadsFileCount=@(Get-ChildItem -LiteralPath (Join-Path $payload 'uploads') -Recurse -File -Force).Count;launcherSettingsIncluded=$false;sourceRoot=$ProgramDataRoot;files=$files}
    if ($Format -eq 1) { $manifest.Remove('formatVersion');$manifest.Remove('files') }
    $manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $payload 'manifest.json')
    Read-BackupPayload $payload | Out-Null
    New-OrchidBackupArchive $payload $Destination
}
function Fixture([string]$Folder='backups',[int]$Count=6) {
    $pd=Join-Path $root ([guid]::NewGuid().ToString('N'))
    $backups=Join-Path $pd $Folder
    New-Item -ItemType Directory -Path $backups -Force | Out-Null
    $files=@()
    for ($i=1;$i -le $Count;$i++) {
        $file=Join-Path $backups ('OrchidAppBackup_20200101_'+$i.ToString('000000')+'.zip')
        Archive $file $pd
        (Get-Item -LiteralPath $file).LastWriteTimeUtc=[DateTime]::UtcNow.Date.AddDays(-20+$i)
        $files+=$file
    }
    @{pd=$pd;backups=$backups;files=$files;current=$files[-1]}
}
function Run([hashtable]$Fixture,[int]$Keep=3,[switch]$Skip,[string]$Type='Normal') {
    Invoke-BackupRetention -BackupType $Type -BackupsRoot $Fixture.backups -CurrentBackup $Fixture.current -ProgramDataRoot $Fixture.pd -BackupsToKeep $Keep -SkipOldBackupPruning:$Skip
}
try {
    $f=Fixture;Run $f
    Check 'Default keeps three verified routine ZIPs' (@(Get-ChildItem -LiteralPath $f.backups -File -Filter '*.zip').Count -eq 3)
    Check 'Current verified ZIP is always retained' (Test-Path -LiteralPath $f.current)
    $f=Fixture;Run $f -Keep 1
    Check 'Minimum keep count preserves one current ZIP' (@(Get-ChildItem -LiteralPath $f.backups -File -Filter '*.zip').Count -eq 1 -and (Test-Path -LiteralPath $f.current))
    $f=Fixture;$PruneOldBackups=$true;Run $f -Keep 1 -Skip
    Check 'Skip switch overrides any obsolete ambient variable' (@(Get-ChildItem -LiteralPath $f.backups -File -Filter '*.zip').Count -eq 6)
    Run $f -Keep 1 -Type PreUpgrade
    Check 'PreUpgrade never prunes even without skip switch' (@(Get-ChildItem -LiteralPath $f.backups -File -Filter '*.zip').Count -eq 6)
    Reject 'Zero count rejected before retention' { Run $f -Keep 0 }
    Reject 'Negative count rejected before retention' { Run $f -Keep -1 }
    Reject 'Backup entry point rejects zero before database work' { & (Join-Path $RepoRoot 'app/tools/backup-orchidapp.ps1') -BackupsToKeep 0 }
    Reject 'Backup entry point rejects negative before database work' { & (Join-Path $RepoRoot 'app/tools/backup-orchidapp.ps1') -BackupsToKeep -1 }
    Check 'Invalid counts delete nothing' (@(Get-ChildItem -LiteralPath $f.backups -File -Filter '*.zip').Count -eq 6)
    $f=Fixture
    $unrelated=Join-Path $f.backups 'important.zip';'keep' | Set-Content -LiteralPath $unrelated
    $corrupt=Join-Path $f.backups 'OrchidAppBackup_19990101_000000.zip';'corrupt' | Set-Content -LiteralPath $corrupt
    $preUpgrade=Join-Path $f.backups 'OrchidAppPreUpgradeBackup_19990101_000000.zip';Copy-Item -LiteralPath $f.current -Destination $preUpgrade
    $nested=Join-Path $f.backups 'nested';New-Item -ItemType Directory -Path $nested | Out-Null
    $nestedZip=Join-Path $nested 'OrchidAppBackup_19990101_000000.zip';Archive $nestedZip $f.pd
    $foreign=Join-Path $f.backups 'OrchidAppBackup_19990101_000001.zip';Archive $foreign (Join-Path $root 'another collection')
    Run $f -Keep 1
    Check 'Unrelated names remain untouched' ((Get-Content -LiteralPath $unrelated -Raw).Trim() -eq 'keep')
    Check 'Corrupt matching ZIP is preserved for review' (Test-Path -LiteralPath $corrupt)
    Check 'Pre-upgrade ZIP prefix is never pruned' (Test-Path -LiteralPath $preUpgrade)
    Check 'Retention never recurses into child folders' (Test-Path -LiteralPath $nestedZip)
    Check 'Other collection archive is preserved' (Test-Path -LiteralPath $foreign)
    $f=Fixture
    $history=Join-Path $f.pd 'restore-recovery/attempt';New-Item -ItemType Directory -Path $history -Force | Out-Null
    @{originalInput=$f.files[0];preservedInput=$f.files[1];safetyBackup=$f.files[2]} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $history 'recovery.json')
    @{SchemaVersion=2;PreUpgradeBackupPath=$f.files[3]} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $f.pd 'migration-state.json')
    Run $f -Keep 1
    Check 'Restore original, retained input, safety and migration ZIPs are pinned' (@(Get-ChildItem -LiteralPath $f.backups -File -Filter '*.zip').Count -eq 5 -and -not (Test-Path -LiteralPath $f.files[4]))
    $f=Fixture;$history=Join-Path $f.pd 'restore-recovery/attempt';New-Item -ItemType Directory -Path $history -Force | Out-Null
    'broken' | Set-Content -LiteralPath (Join-Path $history 'recovery.json');Run $f -Keep 1
    Check 'Unreadable restore history stops all pruning' (@(Get-ChildItem -LiteralPath $f.backups -File -Filter '*.zip').Count -eq 6)
    $f=Fixture;'broken' | Set-Content -LiteralPath (Join-Path $f.pd 'migration-state.json');Run $f -Keep 1
    Check 'Unreadable migration history stops all pruning' (@(Get-ChildItem -LiteralPath $f.backups -File -Filter '*.zip').Count -eq 6)
    $f=Fixture;'{}' | Set-Content -LiteralPath (Join-Path $f.pd 'restore-pending.json');Run $f -Keep 1
    Check 'Pending restore stops all pruning' (@(Get-ChildItem -LiteralPath $f.backups -File -Filter '*.zip').Count -eq 6)
    foreach ($folder in @('backups/pre-upgrade','backups/pre-migration','restore-recovery/attempt/safety')) {
        $f=Fixture $folder;Run $f -Keep 1
        Check "Safety directory exempt: $folder" (@(Get-ChildItem -LiteralPath $f.backups -File -Filter '*.zip').Count -eq 6)
    }
    $f=Fixture;$f.current=$f.files[0];Run $f -Keep 1
    Check 'Old current timestamp cannot cause its removal' ((Test-Path -LiteralPath $f.current) -and @(Get-ChildItem -LiteralPath $f.backups -File -Filter '*.zip').Count -eq 1)
    $f=Fixture
    $held=[IO.File]::Open($f.files[0],[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
    try { Run $f -Keep 1 } finally { $held.Dispose() }
    Check 'Deletion failure preserves the locked ZIP and current backup' ((Test-Path -LiteralPath $f.files[0]) -and (Test-Path -LiteralPath $f.current))
    Run $f -Keep 1
    Check 'A later run can finish pruning after a lock is released' (@(Get-ChildItem -LiteralPath $f.backups -File -Filter '*.zip').Count -eq 1)
    $f=Fixture -Count 1;Run $f -Keep 1
    Check 'Single backup is never removed' (Test-Path -LiteralPath $f.current)
    $f=Fixture
    $modern=Join-Path $f.backups 'OrchidAppBackup_20200101_000007_123_deadbeef.zip';Archive $modern $f.pd;$f.current=$modern;Run $f -Keep 1
    Check 'Modern timestamp/GUID naming participates in retention' (@(Get-ChildItem -LiteralPath $f.backups -File -Filter '*.zip').Count -eq 1 -and (Test-Path -LiteralPath $modern))
    $f=Fixture
    $old=Join-Path $f.backups 'OrchidAppBackup_19990101_000001.zip';Archive $old $f.pd -Format 1;Run $f -Keep 1
    Check 'Known unversioned routine archive can be pruned' (-not (Test-Path -LiteralPath $old))
    $f=Fixture -Count 1
    $hidden=Join-Path $f.backups 'OrchidAppBackup_20200101_000002.zip';Archive $hidden $f.pd -HiddenFile $true
    $hiddenPayload=Join-Path $root 'hidden archive verification';Expand-CheckedBackup $hidden $hiddenPayload
    Read-BackupPayload $hiddenPayload | Out-Null
    Check 'Shared archive writer preserves hidden upload bytes' ((Get-Content -LiteralPath (Join-Path $hiddenPayload 'uploads/hidden.txt') -Raw).Trim() -eq 'hidden upload bytes')
    Write-Host "$checks backup retention checks passed."
}
finally {
    Assert-ChildPath $root ([IO.Path]::GetTempPath())
    Remove-Item -LiteralPath $root -Recurse -Force
}
