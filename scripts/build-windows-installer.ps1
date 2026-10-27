param(
    [string]$InnoCompiler='C:\Program Files\Inno Setup 7\ISCC.exe',
    [switch]$RequireValidSignature
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptRoot

$sourceDir = Join-Path $repoRoot "dist\windows\OrchidApp"
$launcherExe = Join-Path $sourceDir "OrchidApp.Launcher.exe"

if (-not (Test-Path -LiteralPath $launcherExe -PathType Leaf)) { throw "Launcher executable not found: $launcherExe" }
$versionInfo = (Get-Item $launcherExe).VersionInfo
$productVersion = $versionInfo.ProductVersion

if ([string]::IsNullOrWhiteSpace($productVersion)) {
    throw "Could not read ProductVersion from: $launcherExe"
}

$appVersion = ($productVersion -split '\+')[0]

if ($appVersion -notmatch '^\d+\.\d+\.\d+$') {
    throw "ProductVersion '$productVersion' did not contain a valid public version."
}

$installerScript = Join-Path $repoRoot "installer\windows\OrchidApp.iss"
$outputInstaller = Join-Path $repoRoot "dist\installer\OrchidAppSetup-$appVersion.exe"
$isccExe = $InnoCompiler

Write-Host "Building OrchidApp Windows installer..."
Write-Host "Repo root: $repoRoot"

if (-not (Test-Path $sourceDir)) {
    throw "Packaged Windows app folder not found: $sourceDir"
}

if (-not (Test-Path $launcherExe)) {
    throw "Launcher executable not found: $launcherExe"
}

if (-not (Test-Path $installerScript)) {
    throw "Installer script not found: $installerScript"
}

if (-not (Test-Path $isccExe)) {
    throw "Inno Setup compiler not found: $isccExe"
}

Write-Host "Source folder: $sourceDir"
Write-Host "Installer script: $installerScript"
Write-Host "Inno compiler: $isccExe"

foreach ($helper in @('Installer-Snapshot.ps1','prepare-installer-upgrade.ps1','review-installer-snapshot.ps1')) {
    if (-not (Test-Path -LiteralPath (Join-Path $sourceDir "tools/$helper") -PathType Leaf)) { throw "Packaged installer helper missing: $helper. Repackage before building the installer." }
    if ((Get-FileHash -LiteralPath (Join-Path $sourceDir "tools/$helper")).Hash -ne
        (Get-FileHash -LiteralPath (Join-Path $repoRoot "app/tools/$helper")).Hash) { throw "Packaged installer helper is stale: $helper" }
}
# Inno preprocessor options precede the script; use the checked-in production identity.
& $isccExe "/DMyAppVersion=$appVersion" $installerScript

Write-Host "App version: $appVersion"

if ($LASTEXITCODE -ne 0) {
    throw "Inno Setup compiler failed with exit code $LASTEXITCODE."
}

if (-not (Test-Path $outputInstaller)) {
    throw "Installer was not created: $outputInstaller"
}

Write-Host "Installer created:"
Write-Host $outputInstaller

$signature=Get-AuthenticodeSignature -LiteralPath $outputInstaller
$evidence=[ordered]@{
    formatVersion=1
    artifact=[IO.Path]::GetFileName($outputInstaller)
    version=$appVersion
    sha256=(Get-FileHash -LiteralPath $outputInstaller -Algorithm SHA256).Hash.ToLowerInvariant()
    signatureStatus=[string]$signature.Status
    signerThumbprint=if ($signature.SignerCertificate) { $signature.SignerCertificate.Thumbprint } else { $null }
    signatureRequired=[bool]$RequireValidSignature
    createdUtc=[datetime]::UtcNow.ToString('o')
    installedAcceptance='Pending: run isolated installer and actual release acceptance separately.'
}
$evidence | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath ($outputInstaller+'.evidence.json') -Encoding UTF8
Write-Host "Installer SHA-256: $($evidence.sha256)"
Write-Host "Installer signature status: $($signature.Status)"
if ($RequireValidSignature -and $signature.Status -ne 'Valid') { throw 'Installer does not have a valid Authenticode signature. The artifact and evidence were retained; do not release it as signed.' }
