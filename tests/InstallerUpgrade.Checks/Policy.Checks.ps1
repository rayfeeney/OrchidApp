param([string]$RepoRoot=(Join-Path $PSScriptRoot '../..'))
$ErrorActionPreference='Stop'
. (Join-Path $RepoRoot 'app/tools/Installer-Snapshot.ps1')
# A controlled process inventory keeps these policy tests off unrelated host services.
# Production uses the actual CIM command; its unknown-process rule is tested below.
$script:processInventory=@()
function Get-CimInstance { $script:processInventory }
$root=Join-Path ([IO.Path]::GetTempPath()) ('orchids-installer-policy-'+[guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory -Path $root
$checks=0
function Check([string]$Name,[bool]$Pass) { if (-not $Pass) { throw "Check failed: $Name" };$script:checks++ }
function Reject([string]$Name,[scriptblock]$Action) { $rejected=$false;try { & $Action | Out-Null } catch { $rejected=$true };Check $Name $rejected }
function Fixture {
    $folder=Join-Path $root ([guid]::NewGuid().ToString('N'))
    $app=Join-Path $folder 'old app';$persistent=Join-Path $folder 'persistent'
    $null=New-Item -ItemType Directory -Path $app,(Join-Path $persistent 'uploads/plants/1'),(Join-Path $persistent 'data/mariadb/orchids'),(Join-Path $persistent 'backups') -Force
    'old binaries' | Set-Content (Join-Path $app 'OrchidApp.Web.dll')
    'offline database fixture' | Set-Content (Join-Path $persistent 'data/mariadb/orchids/plant.ibd')
    'photo' | Set-Content (Join-Path $persistent 'uploads/plants/1/photo.jpg')
    '{"CloudBackupFolderPath":"synthetic"}' | Set-Content (Join-Path $persistent 'launcher-settings.json')
    'prior backup' | Set-Content (Join-Path $persistent 'backups/keep.zip')
    [pscustomobject]@{root=$folder;app=$app;persistent=$persistent}
}
try {
    $f=Fixture
    $archive=New-InstallerSnapshot $f.app $f.persistent 0
    Check 'New verified snapshot exists' (Test-Path -LiteralPath $archive -PathType Leaf)
    $manifest=Read-InstallerSnapshot $archive
    Check 'App and matching durable files captured, backup history excluded' (@($manifest.files).Count -eq 4)
    Check 'Format is distinct from logical backup' ($manifest.kind -ceq 'OrchidAppOfflineInstallerRollback')
    $destination=Join-Path $f.root 'review extracted'
    $null=Expand-InstallerSnapshot $archive $destination
    foreach ($file in $manifest.files) { Check 'Extracted original bytes match' ((Get-FileHash -LiteralPath (Join-Path $destination $file.path)).Hash.ToLowerInvariant() -ceq $file.sha256) }
    Check 'Prior backup unchanged' ((Get-Content (Join-Path $f.persistent 'backups/keep.zip') -Raw).Trim() -eq 'prior backup')
    Reject 'Recovery never overwrites existing directory' { Expand-InstallerSnapshot $archive $destination }
    Reject 'Overlapping source roots refused' { New-InstallerSnapshot $f.app (Join-Path $f.app 'data') 0 }
    Reject 'Relative roots refused' { New-InstallerSnapshot 'relative' $f.persistent 0 }
    $f=Fixture
    '{}' | Set-Content (Join-Path $f.persistent 'restore-pending.json')
    Reject 'Unresolved restore blocks file replacement' { New-InstallerSnapshot $f.app $f.persistent 0 }
    $f=Fixture
    '{"SchemaVersion":2,"MigrationStatus":"Failed","Phase":"Copying"}' | Set-Content (Join-Path $f.persistent 'migration-state.json')
    Reject 'Unfinished migration blocks upgrade' { New-InstallerSnapshot $f.app $f.persistent 0 }
    $f=Fixture;$recovery=Join-Path $f.persistent 'uploads/.photo-recovery';$null=New-Item -ItemType Directory -Path $recovery
    '{}' | Set-Content (Join-Path $recovery 'keep.json')
    Reject 'Unresolved photo recovery blocks upgrade' { New-InstallerSnapshot $f.app $f.persistent 0 }
    $f=Fixture;$locked=Join-Path $f.persistent 'uploads/plants/1/photo.jpg'
    $handle=[IO.File]::Open($locked,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::Read)
    try { Reject 'Active writer sharing conflict blocks capture' { New-InstallerSnapshot $f.app $f.persistent 0 } } finally { $handle.Dispose() }
    Check 'Blocked capture leaves original photo intact' ((Get-Content -LiteralPath $locked -Raw).Trim() -eq 'photo')
    Check 'No verified archive advertised on capture failure' (@(Get-ChildItem (Join-Path $f.persistent 'backups') -Recurse -Filter 'OrchidAppUpgrade-*.zip').Count -eq 0)
    $f=Fixture;'blocked' | Set-Content (Join-Path $f.persistent 'backups/pre-install')
    Reject 'Unwritable backup destination blocks upgrade' { New-InstallerSnapshot $f.app $f.persistent 0 }
    $f=Fixture;$archive=New-InstallerSnapshot $f.app $f.persistent 0
    $zip=[IO.Compression.ZipFile]::Open($archive,[IO.Compression.ZipArchiveMode]::Update)
    try { $entry=$zip.GetEntry('application/OrchidApp.Web.dll');$entry.Delete();$entry=$zip.CreateEntry('application/OrchidApp.Web.dll');$writer=New-Object IO.StreamWriter($entry.Open());try {$writer.Write('tampered')}finally{$writer.Dispose()} }finally{$zip.Dispose()}
    Reject 'Corrupt archive is rejected' { Read-InstallerSnapshot $archive }
    $absent=Join-Path $f.root 'not created'
    Reject 'Corrupt archive is not extracted' { Expand-InstallerSnapshot $archive $absent }
    Check 'No recovery destination created for corrupt archive' (-not(Test-Path -LiteralPath $absent))
    $fresh=Join-Path $root 'fresh'
    Check 'Fresh installation does not create a fake backup' ($null -eq (New-InstallerSnapshot (Join-Path $fresh 'app') (Join-Path $fresh 'persistent') 0))
    Check 'Fresh check does not initialize persistent data' (-not(Test-Path (Join-Path $fresh 'persistent')))
    $single=Join-Path $root 'single persistent file';$null=New-Item -ItemType Directory -Path $single
    'one setting' | Set-Content -LiteralPath (Join-Path $single 'launcher-settings.json')
    $singleArchive=New-InstallerSnapshot (Join-Path $root 'absent app') $single 0
    Check 'One existing file still requires a snapshot' ($null -ne $singleArchive)
    Check 'Single-file manifest verifies' (@((Read-InstallerSnapshot $singleArchive).files).Count -eq 1)
    $script:processInventory=@([pscustomobject]@{ProcessId=999999;Name='mysqld.exe';ExecutablePath=$null;CommandLine=$null})
    Reject 'Unidentifiable database process blocks even an otherwise valid snapshot' { New-InstallerSnapshot $f.app $f.persistent 0 }
    $script:processInventory=@([pscustomobject]@{ProcessId=999999;Name='OrchidApp.Web.exe';ExecutablePath=(Join-Path $f.app 'OrchidApp.Web.exe');CommandLine=''})
    Reject 'Selected application process blocks snapshot' { New-InstallerSnapshot $f.app $f.persistent 0 }
    $script:processInventory=@([pscustomobject]@{ProcessId=999999;Name='mariadbd.exe';ExecutablePath='C:\unrelated-runtime\mariadbd.exe';CommandLine=('--datadir="'+$f.persistent+'\data\mariadb"')})
    Reject 'Database pointing at selected durable root blocks snapshot' { New-InstallerSnapshot $f.app $f.persistent 0 }
    Write-Host "$checks installer snapshot policy checks passed. Fixture: $root"
} finally { }
