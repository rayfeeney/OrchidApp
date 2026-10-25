param([string]$RepoRoot=(Join-Path $PSScriptRoot '../..'))
$ErrorActionPreference='Stop'
. (Join-Path $RepoRoot 'app/tools/Backup-Contract.ps1')
$root=Join-Path ([IO.Path]::GetTempPath()) ('orchids-payload-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $root | Out-Null
$checks=0
function Check([string]$Name,[bool]$Pass) { if (-not $Pass) { throw "Check failed: $Name" }; $script:checks++ }
function Reject([string]$Name,[scriptblock]$Action) { $rejected=$false; try { & $Action | Out-Null } catch { $rejected=$true }; Check $Name $rejected }
function Fixture {
    $dir=Join-Path $root ([guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path (Join-Path $dir 'uploads/plants/1'),(Join-Path $dir 'launcher-settings') -Force | Out-Null
    'SELECT 1;' | Set-Content (Join-Path $dir 'orchids.sql')
    'baseline' | Set-Content (Join-Path $dir 'schemaversion.txt')
    'photo' | Set-Content (Join-Path $dir 'uploads/plants/1/photo.jpg')
    '{"CloudBackupFolderPath":"fixture"}' | Set-Content (Join-Path $dir 'launcher-settings/launcher-settings.json')
    $files=@(Get-PayloadFiles $dir | ForEach-Object { @{path=$_.FullName.Substring($dir.Length+1).Replace('\','/');length=$_.Length;sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash} })
    @{formatVersion=2;database='orchids';databaseBackup='orchids.sql';uploadsIncluded=$true;uploadsFileCount=1;launcherSettingsIncluded=$true;files=$files} | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $dir 'manifest.json')
    $dir
}
function Edit-Manifest([string]$Dir,[scriptblock]$Edit) {
    $m=Get-Content (Join-Path $Dir 'manifest.json') -Raw | ConvertFrom-Json
    & $Edit $m
    $m | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $Dir 'manifest.json')
}
try {
    $dir=Fixture; $payload=Read-BackupPayload $dir
    Check 'Version 2 nested settings read' ($payload.Settings -eq (Join-Path $dir 'launcher-settings/launcher-settings.json'))
    Check 'Version 2 uploads read' $payload.HasUploads
    $dir=Fixture; Add-Content (Join-Path $dir 'orchids.sql') '-- changed'
    Reject 'Changed SQL rejected' { Read-BackupPayload $dir }
    $dir=Fixture; Remove-Item (Join-Path $dir 'uploads/plants/1/photo.jpg')
    Reject 'Missing upload rejected' { Read-BackupPayload $dir }
    $dir=Fixture; Edit-Manifest $dir {param($m) $m.formatVersion=999}
    Reject 'Future format rejected' { Read-BackupPayload $dir }
    $dir=Fixture; Edit-Manifest $dir {param($m) $m.formatVersion=2.5}
    Reject 'Fractional format rejected' { Read-BackupPayload $dir }
    $dir=Fixture; Edit-Manifest $dir {param($m) $m.database='wrong'}
    Reject 'Wrong database rejected' { Read-BackupPayload $dir }
    $dir=Fixture; Edit-Manifest $dir {param($m) $m.files[0].path='../escape'}
    Reject 'Inventory escape rejected' { Read-BackupPayload $dir }
    $dir=Fixture; Edit-Manifest $dir {param($m) $m.files+=@($m.files[0])}
    Reject 'Duplicate inventory rejected' { Read-BackupPayload $dir }
    $dir=Fixture; 'unexpected' | Set-Content (Join-Path $dir 'extra.txt')
    Reject 'Unlisted payload rejected' { Read-BackupPayload $dir }
    $dir=Fixture; '{broken' | Set-Content (Join-Path $dir 'launcher-settings/launcher-settings.json')
    Reject 'Invalid settings rejected' { Read-BackupPayload $dir }
    $dir=Fixture; '[{"CloudBackupFolderPath":"fixture"}]' | Set-Content (Join-Path $dir 'launcher-settings/launcher-settings.json')
    Reject 'Settings arrays rejected' { Read-BackupPayload $dir }
    $dir=Fixture; '{"CloudBackupFolderPath":123}' | Set-Content (Join-Path $dir 'launcher-settings/launcher-settings.json')
    Reject 'Wrong settings property type rejected' { Read-BackupPayload $dir }
    $dir=Fixture; Remove-Item -LiteralPath (Join-Path $dir 'launcher-settings/launcher-settings.json')
    Reject 'Declared settings cannot be omitted' { Read-BackupPayload $dir }
    $dir=Fixture; Remove-Item -LiteralPath (Join-Path $dir 'launcher-settings/launcher-settings.json')
    Edit-Manifest $dir {param($m) $m.launcherSettingsIncluded=$false; $m.files=@($m.files | Where-Object path -ne 'launcher-settings/launcher-settings.json')}
    Check 'Explicit absent settings supported' (-not (Read-BackupPayload $dir).Settings)
    Edit-Manifest $dir {param($m) $m.PSObject.Properties.Remove('formatVersion'); $m.PSObject.Properties.Remove('launcherSettingsIncluded')}
    Reject 'Ambiguous missing old settings require review' { Read-BackupPayload $dir }
    $dir=Fixture; Edit-Manifest $dir {param($m) $m.uploadsFileCount=99}
    Reject 'Upload count mismatch rejected' { Read-BackupPayload $dir }
    $dir=Fixture; Edit-Manifest $dir {param($m) $m.PSObject.Properties.Remove('formatVersion'); $m.PSObject.Properties.Remove('files')}
    Check 'Unversioned nested settings supported' ([bool](Read-BackupPayload $dir).Settings)
    Copy-Item -LiteralPath (Join-Path $dir 'launcher-settings/launcher-settings.json') -Destination (Join-Path $dir 'launcher-settings.json')
    Remove-Item -LiteralPath (Join-Path $dir 'launcher-settings/launcher-settings.json')
    Check 'Legacy root settings supported' ((Read-BackupPayload $dir).Settings -eq (Join-Path $dir 'launcher-settings.json'))
    '{"different":true}' | Set-Content (Join-Path $dir 'launcher-settings/launcher-settings.json')
    Reject 'Conflicting settings layouts rejected' { Read-BackupPayload $dir }
    $dir=Fixture; Edit-Manifest $dir {param($m) $m.PSObject.Properties.Remove('formatVersion'); $m.PSObject.Properties.Remove('files');$m.uploadsIncluded=$false;$m.uploadsFileCount=0}
    $uploads=(Resolve-Path (Join-Path $dir 'uploads')).Path
    Assert-ChildPath $uploads $dir
    Remove-Item -LiteralPath $uploads -Recurse -Force
    Check 'Explicit old empty uploads supported' (-not (Read-BackupPayload $dir).HasUploads)
    Edit-Manifest $dir {param($m) $m.uploadsIncluded=$true}
    Reject 'Undeclared missing uploads rejected' { Read-BackupPayload $dir }
    $zip=Join-Path $root 'unsafe.zip'
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $z=[IO.Compression.ZipFile]::Open($zip,[IO.Compression.ZipArchiveMode]::Create)
    try { $entry=$z.CreateEntry('../escape.txt'); $stream=$entry.Open(); $stream.Dispose() } finally { $z.Dispose() }
    Reject 'ZIP traversal rejected before extraction' { Expand-CheckedBackup $zip (Join-Path $root 'extracted') }
    Check 'ZIP traversal wrote no file' (-not (Test-Path (Join-Path $root 'escape.txt')))
    Write-Host "$checks backup/restore payload policy checks passed."
}
finally {
    $parent=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\','/')+'\'
    if (-not (Get-FullLocalPath $root).StartsWith($parent,[StringComparison]::OrdinalIgnoreCase)) { throw 'Unexpected policy fixture path.' }
    Remove-Item -LiteralPath $root -Recurse -Force
}
