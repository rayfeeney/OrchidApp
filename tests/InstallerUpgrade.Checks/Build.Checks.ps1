param([string]$RepoRoot=(Join-Path $PSScriptRoot '../..'),[string]$InnoCompiler='C:\Program Files\Inno Setup 7\ISCC.exe')
$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path -LiteralPath $RepoRoot).Path
$root=Join-Path ([IO.Path]::GetTempPath()) ('orchids-installer-build-'+[guid]::NewGuid().ToString('N'))
$package=Join-Path $root 'dist/windows/OrchidApp'
foreach ($folder in @('scripts','installer/windows','app/tools','dist/windows/OrchidApp/tools')) { $null=New-Item -ItemType Directory -Path (Join-Path $root $folder) -Force }
Copy-Item -LiteralPath (Join-Path $RepoRoot 'scripts/build-windows-installer.ps1') -Destination (Join-Path $root 'scripts')
Copy-Item -LiteralPath (Join-Path $RepoRoot 'installer/windows/OrchidApp.iss') -Destination (Join-Path $root 'installer/windows')
$launcher=Join-Path $RepoRoot 'src/OrchidApp.Launcher/bin/Release/net8.0-windows/OrchidApp.Launcher.exe'
if (-not(Test-Path -LiteralPath $launcher)) { throw 'Build the Release launcher before the installer build checks.' }
Copy-Item -LiteralPath $launcher -Destination $package
foreach ($helper in @('Installer-Snapshot.ps1','prepare-installer-upgrade.ps1','review-installer-snapshot.ps1')) {
    Copy-Item -LiteralPath (Join-Path $RepoRoot "app/tools/$helper") -Destination (Join-Path $root 'app/tools')
    Copy-Item -LiteralPath (Join-Path $RepoRoot "app/tools/$helper") -Destination (Join-Path $package 'tools')
}
$builder=Join-Path $root 'scripts/build-windows-installer.ps1'
& $builder -InnoCompiler $InnoCompiler
$artifact=Get-ChildItem -LiteralPath (Join-Path $root 'dist/installer') -Filter '*.exe' | Select-Object -First 1
if (-not $artifact) { throw 'Production-identity compilation did not create an artifact.' }
$evidence=Get-Content -LiteralPath ($artifact.FullName+'.evidence.json') -Raw | ConvertFrom-Json
if ($evidence.sha256 -cne (Get-FileHash -LiteralPath $artifact.FullName).Hash.ToLowerInvariant()) { throw 'Artifact evidence checksum mismatch.' }
if ($evidence.signatureStatus -ne [string](Get-AuthenticodeSignature -LiteralPath $artifact.FullName).Status) { throw 'Artifact signature evidence mismatch.' }
Add-Content -LiteralPath (Join-Path $package 'tools/Installer-Snapshot.ps1') -Value '# synthetic stale package'
$blocked=$false;try { & $builder -InnoCompiler $InnoCompiler } catch { $blocked=$_.Exception.Message -like '*stale*' }
if (-not $blocked) { throw 'Stale packaged helper was not rejected.' }
Copy-Item -LiteralPath (Join-Path $root 'app/tools/Installer-Snapshot.ps1') -Destination (Join-Path $package 'tools/Installer-Snapshot.ps1') -Force
$blocked=$false;try { & $builder -InnoCompiler $InnoCompiler -RequireValidSignature } catch { $blocked=$_.Exception.Message -like '*valid Authenticode*' }
if ($evidence.signatureStatus -ne 'Valid' -and -not $blocked) { throw 'Required signing policy was not enforced.' }
Write-Host "5 installer build/evidence checks passed (actual artifact signature: $($evidence.signatureStatus)). Fixture: $root"
