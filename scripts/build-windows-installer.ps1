Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptRoot

$sourceDir = Join-Path $repoRoot "dist\windows\OrchidApp"
$launcherExe = Join-Path $sourceDir "OrchidApp.Launcher.exe"

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
$isccExe = "C:\Program Files\Inno Setup 7\ISCC.exe"

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

& $isccExe $installerScript "/DMyAppVersion=$appVersion"

Write-Host "App version: $appVersion"

if ($LASTEXITCODE -ne 0) {
    throw "Inno Setup compiler failed with exit code $LASTEXITCODE."
}

if (-not (Test-Path $outputInstaller)) {
    throw "Installer was not created: $outputInstaller"
}

Write-Host "Installer created:"
Write-Host $outputInstaller