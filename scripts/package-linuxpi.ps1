$ErrorActionPreference = "Stop"

$Runtime = "linux-arm64"
$PackageName = "OrchidApp-RaspberryPi-Linux-arm64"

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Resolve-Path (Join-Path $ScriptRoot "..")

$DistRoot = Join-Path $RepoRoot "dist"
$PlatformDistRoot = Join-Path $DistRoot "linuxpi"
$PackageRoot = Join-Path $PlatformDistRoot "OrchidApp"
$AppOutput = Join-Path $PackageRoot "app"
$ZipPath = Join-Path $PlatformDistRoot "$PackageName.zip"

Write-Host "Packaging OrchidApp for Raspberry Pi / Linux..."
Write-Host "Runtime: $Runtime"
Write-Host "Output:  $ZipPath"

    if (Test-Path $PlatformDistRoot) {
        Remove-Item $PlatformDistRoot -Recurse -Force
    }

New-Item -ItemType Directory -Force -Path $PlatformDistRoot | Out-Null
New-Item -ItemType Directory -Force -Path $AppOutput | Out-Null

Write-Host "Publishing .NET app..."

dotnet publish (Join-Path $RepoRoot "src\OrchidApp.Web\OrchidApp.Web.csproj") `
    -c Release `
    -r $Runtime `
    --self-contained true `
    -o $AppOutput

Write-Host "Copying database files..."

if (Test-Path (Join-Path $RepoRoot "database")) {
    Copy-Item `
        -Path (Join-Path $RepoRoot "database") `
        -Destination (Join-Path $PackageRoot "database") `
        -Recurse
}

Write-Host "Copying infrastructure files..."

if (Test-Path (Join-Path $RepoRoot "infrastructure")) {
    Copy-Item `
        -Path (Join-Path $RepoRoot "infrastructure") `
        -Destination (Join-Path $PackageRoot "infrastructure") `
        -Recurse
}

Write-Host "Copying documentation..."

if (Test-Path (Join-Path $RepoRoot "README.md")) {
    Copy-Item `
        -Path (Join-Path $RepoRoot "README.md") `
        -Destination (Join-Path $PackageRoot "README.md")
}

if (Test-Path (Join-Path $RepoRoot "docs\user-guides\linux")) {
    New-Item `
        -ItemType Directory `
        -Force `
        -Path (Join-Path $PackageRoot "docs\user-guides\linux") | Out-Null

    Copy-Item `
        -Path (Join-Path $RepoRoot "docs\user-guides\linux\*") `
        -Destination (Join-Path $PackageRoot "docs\user-guides\linux") `
        -Recurse
}

Write-Host "Creating ZIP..."

Compress-Archive `
    -Path $PackageRoot `
    -DestinationPath $ZipPath `
    -Force

Write-Host ""
Write-Host "Linux/Raspberry Pi package created successfully:"
Write-Host $ZipPath