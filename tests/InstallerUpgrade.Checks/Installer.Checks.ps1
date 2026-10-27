param(
    [string]$RepoRoot=(Join-Path $PSScriptRoot '../..'),
    [string]$InnoCompiler='C:\Program Files\Inno Setup 7\ISCC.exe',
    [string]$FixtureParent=[IO.Path]::GetTempPath()
)
$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path -LiteralPath $RepoRoot).Path
$FixtureParent=(Resolve-Path -LiteralPath $FixtureParent).Path
if (-not (Test-Path -LiteralPath $InnoCompiler)) { throw 'Install Inno Setup 7 or supply its compiler path.' }
. (Join-Path $RepoRoot 'app/tools/Installer-Snapshot.ps1')
# Policy.Checks tests actual process-decision logic. This isolated installer build
# substitutes only process enumeration to avoid inspecting unrelated host services.
# All file capture, verification, archive, installer and uninstall work is real.
$root=Join-Path $FixtureParent ('orchids-installer-'+[guid]::NewGuid().ToString('N'))
$package=Join-Path $root 'payload';$install=Join-Path $root 'installed app';$persistent=Join-Path $root 'persistent';$output=Join-Path $root 'output'
$null=New-Item -ItemType Directory -Path $root,$package,$output
$identity='OrchidApp-C18-Fixture-'+[guid]::NewGuid().ToString('N')
$checks=0
function Check([string]$Name,[bool]$Pass) { if (-not $Pass) { throw "Check failed: $Name" };$script:checks++ }
function Build([string]$Version,[string]$Value) {
    $Value | Set-Content -LiteralPath (Join-Path $package 'application.txt')
    $arguments=@('/Qp',"/DMyAppVersion=$Version","/DSourceDir=$package","/DOutputDir=$output",'/DInstallerFixture=1',"/DFixtureAppId=$identity","/DFixturePersistentRoot=$persistent",(Join-Path $RepoRoot 'installer/windows/OrchidApp.iss'))
    # Compiler progress belongs on the host stream, never in the returned path.
    # Inno 6 emits "Preprocessing" even with /Qp.
    & $InnoCompiler @arguments | Out-Host
    if ($LASTEXITCODE -ne 0) { throw 'Fixture installer compilation failed.' }
    $executable=Join-Path $output "OrchidAppSetup-$Version.exe"
    if (-not (Test-Path -LiteralPath $executable -PathType Leaf)) { throw "Fixture installer was not created: $executable" }
    return $executable
}
function Install([string]$Executable,[string]$LogName) {
    $log=Join-Path $root $LogName
    $arguments=@('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART','/SP-',('/DIR="'+$install+'"'),('/LOG="'+$log+'"'))
    $process=Start-Process -FilePath $Executable -ArgumentList $arguments -PassThru -WindowStyle Hidden
    if (-not $process.WaitForExit(120000)) { throw 'Fixture installer timed out; retain the fixture for review.' }
    $process.Refresh();[int]$process.ExitCode
}
function SnapshotCount { @(Get-ChildItem -LiteralPath (Join-Path $persistent 'backups/pre-install') -Filter '*.zip' -ErrorAction SilentlyContinue).Count }
try {
    # Deliberately ship mutable paths to prove Inno exclusions preserve them.
    $null=New-Item -ItemType Directory -Path (Join-Path $package 'uploads'),(Join-Path $package 'data'),(Join-Path $package 'backups')
    'must not install' | Set-Content (Join-Path $package 'uploads/private.jpg')
    'must not install' | Set-Content (Join-Path $package 'data/private.ibd')
    'must not install' | Set-Content (Join-Path $package 'backups/private.zip')
    'must not install' | Set-Content (Join-Path $package 'launcher-settings.json')
    $old=Build '1.0.0' 'old installed app'
    $new=Build '1.0.1' 'new app-only version'
    Check 'Actual clean installer succeeds' ((Install $old 'clean.log') -eq 0)
    Check 'Application file installed' ((Get-Content (Join-Path $install 'application.txt') -Raw).Trim() -eq 'old installed app')
    Check 'Mutable payload files excluded' (-not(Test-Path (Join-Path $install 'uploads/private.jpg')) -and -not(Test-Path (Join-Path $install 'data/private.ibd')) -and -not(Test-Path (Join-Path $install 'launcher-settings.json')))
    Check 'Clean install does not create persistent data' (-not(Test-Path $persistent))
    $null=New-Item -ItemType Directory -Path (Join-Path $persistent 'data/mariadb/orchids'),(Join-Path $persistent 'uploads/plants/1'),(Join-Path $persistent 'backups') -Force
    'raw database fixture' | Set-Content (Join-Path $persistent 'data/mariadb/orchids/plant.ibd')
    'photo fixture' | Set-Content (Join-Path $persistent 'uploads/plants/1/photo.jpg')
    '{"synthetic":true}' | Set-Content (Join-Path $persistent 'launcher-settings.json')
    'keep prior backup' | Set-Content (Join-Path $persistent 'backups/keep.zip')
    $dataHash=(Get-FileHash (Join-Path $persistent 'data/mariadb/orchids/plant.ibd')).Hash
    $photoHash=(Get-FileHash (Join-Path $persistent 'uploads/plants/1/photo.jpg')).Hash
    $settingsHash=(Get-FileHash (Join-Path $persistent 'launcher-settings.json')).Hash
    '{}' | Set-Content (Join-Path $persistent 'restore-pending.json')
    Check 'Actual installer blocks unresolved restore' ((Install $new 'blocked-restore.log') -ne 0)
    Check 'Blocked installer leaves prior app intact' ((Get-Content (Join-Path $install 'application.txt') -Raw).Trim() -eq 'old installed app')
    Remove-Item -LiteralPath (Join-Path $persistent 'restore-pending.json')
    $locked=[IO.File]::Open((Join-Path $persistent 'uploads/plants/1/photo.jpg'),[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::Read)
    try { Check 'Actual installer blocks a sharing writer' ((Install $new 'blocked-writer.log') -ne 0) } finally { $locked.Dispose() }
    Check 'Failed backup creates no verified recovery ZIP' ((SnapshotCount) -eq 0)
    Check 'App-only upgrade succeeds after successful backup' ((Install $new 'upgrade.log') -eq 0)
    Check 'App-only upgrade creates one new verified snapshot' ((SnapshotCount) -eq 1)
    Check 'Application replaced only after gate success' ((Get-Content (Join-Path $install 'application.txt') -Raw).Trim() -eq 'new app-only version')
    $archive=(Get-ChildItem -LiteralPath (Join-Path $persistent 'backups/pre-install') -Filter '*.zip' | Select-Object -First 1).FullName
    $manifest=Read-InstallerSnapshot $archive
    Check 'Snapshot contains old app and paired durable files' (@($manifest.files | Where-Object {$_.path -eq 'application/application.txt'}).Count -eq 1 -and @($manifest.files | Where-Object {$_.path -eq 'persistent/data/mariadb/orchids/plant.ibd'}).Count -eq 1)
    Check 'Database bytes preserved by upgrade' ((Get-FileHash (Join-Path $persistent 'data/mariadb/orchids/plant.ibd')).Hash -eq $dataHash)
    Check 'Photos preserved by upgrade' ((Get-FileHash (Join-Path $persistent 'uploads/plants/1/photo.jpg')).Hash -eq $photoHash)
    Check 'Settings preserved by upgrade' ((Get-FileHash (Join-Path $persistent 'launcher-settings.json')).Hash -eq $settingsHash)
    Check 'Existing backup history preserved' ((Get-Content (Join-Path $persistent 'backups/keep.zip') -Raw).Trim() -eq 'keep prior backup')
    $review=Join-Path $root 'recovery review';$null=Expand-InstallerSnapshot $archive $review
    Check 'Offline recovery gives previous application bytes' ((Get-Content (Join-Path $review 'application/application.txt') -Raw).Trim() -eq 'old installed app')
    Check 'Offline recovery gives matching prior database bytes' ((Get-FileHash (Join-Path $review 'persistent/data/mariadb/orchids/plant.ibd')).Hash -eq $dataHash)
    # Uninstall only this randomly identified, per-user fixture product.
    $uninstaller=Join-Path $install 'unins000.exe'
    Check 'Fixture uninstaller exists' (Test-Path -LiteralPath $uninstaller)
    $process=Start-Process -FilePath $uninstaller -ArgumentList '/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART' -PassThru -WindowStyle Hidden
    if (-not $process.WaitForExit(60000)) { throw 'Fixture uninstall timed out.' }
    $process.Refresh();Check 'Actual uninstall succeeds' ($process.ExitCode -eq 0)
    Check 'Uninstall removes managed app file' (-not(Test-Path (Join-Path $install 'application.txt')))
    Check 'Uninstall preserves database photos settings and backup snapshot' ((Get-FileHash (Join-Path $persistent 'data/mariadb/orchids/plant.ibd')).Hash -eq $dataHash -and (Get-FileHash (Join-Path $persistent 'uploads/plants/1/photo.jpg')).Hash -eq $photoHash -and (Get-FileHash (Join-Path $persistent 'launcher-settings.json')).Hash -eq $settingsHash -and (Test-Path -LiteralPath $archive))
    $signatures=@($old,$new) | ForEach-Object { [pscustomobject]@{artifact=[IO.Path]::GetFileName($_);sha256=(Get-FileHash -LiteralPath $_).Hash;signatureStatus=[string](Get-AuthenticodeSignature -LiteralPath $_).Status} }
    $signatures | ConvertTo-Json | Set-Content (Join-Path $root 'signature-evidence.json')
    Write-Host "$checks actual isolated installer checks passed. Fixture: $root"
} finally { Write-Host "Installer fixture retained: $root (identity $identity)." }
