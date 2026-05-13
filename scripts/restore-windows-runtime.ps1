$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)

    Write-Host ""
    Write-Host "==> $Message"
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Resolve-Path (Join-Path $ScriptDir "..")

$MariaDbRuntimeRoot = Join-Path $RepoRoot "app\runtime\mariadb\win-x64"
$MariaDbExe = Join-Path $MariaDbRuntimeRoot "bin\mariadbd.exe"

$MariaDbVersion = "10.11.16"
$MariaDbPackageName = "mariadb-$MariaDbVersion-winx64.zip"
$MariaDbDownloadUrl = "https://mirror.mariadb.org/mariadb-$MariaDbVersion/winx64-packages/$MariaDbPackageName"
$RuntimeDownloadRoot = Join-Path $RepoRoot ".runtime-downloads"
$MariaDbArchivePath = Join-Path $RuntimeDownloadRoot $MariaDbPackageName
$MariaDbExtractRoot = Join-Path $RuntimeDownloadRoot "mariadb"

$LibVipsRuntimeRoot = Join-Path $RepoRoot "app\runtime\libvips\win-x64"
$LibVipsDll = Join-Path $LibVipsRuntimeRoot "bin\libvips-42.dll"

$LibVipsVersion = "8.18.2"
$LibVipsPackageName = "vips-dev-x64-all-$LibVipsVersion.zip"
$LibVipsDownloadUrl = "https://github.com/libvips/build-win64-mxe/releases/download/v$LibVipsVersion/$LibVipsPackageName"
$LibVipsArchivePath = Join-Path $RuntimeDownloadRoot $LibVipsPackageName
$LibVipsExtractRoot = Join-Path $RuntimeDownloadRoot "libvips"

Write-Step "Checking Windows runtime dependencies"

if (Test-Path $MariaDbExe) {
    Write-Host "MariaDB runtime already present: $MariaDbExe" -ForegroundColor Green
}
else {
    Write-Step "Restoring MariaDB runtime"

    New-Item -ItemType Directory -Path $RuntimeDownloadRoot -Force | Out-Null

    if (-not (Test-Path $MariaDbArchivePath)) {
        Write-Host "Downloading MariaDB $MariaDbVersion..."
        Write-Host $MariaDbDownloadUrl

        Invoke-WebRequest `
            -Uri $MariaDbDownloadUrl `
            -OutFile $MariaDbArchivePath
    }
    else {
        Write-Host "MariaDB archive already downloaded: $MariaDbArchivePath"
    }

    if (Test-Path $MariaDbExtractRoot) {
        Remove-Item $MariaDbExtractRoot -Recurse -Force
    }

    New-Item -ItemType Directory -Path $MariaDbExtractRoot -Force | Out-Null

    Write-Host "Extracting MariaDB archive..."

    Expand-Archive `
        -Path $MariaDbArchivePath `
        -DestinationPath $MariaDbExtractRoot `
        -Force

    $ExtractedMariaDbRoot = Get-ChildItem `
        -Path $MariaDbExtractRoot `
        -Directory |
        Select-Object -First 1

    if ($null -eq $ExtractedMariaDbRoot) {
        throw "MariaDB archive extraction did not produce a folder."
    }

    if (Test-Path $MariaDbRuntimeRoot) {
        Remove-Item $MariaDbRuntimeRoot -Recurse -Force
    }

    New-Item -ItemType Directory -Path (Split-Path -Parent $MariaDbRuntimeRoot) -Force | Out-Null

    Copy-Item `
        -Path $ExtractedMariaDbRoot.FullName `
        -Destination $MariaDbRuntimeRoot `
        -Recurse `
        -Force

    if (-not (Test-Path $MariaDbExe)) {
        throw "MariaDB runtime restore failed. Expected file missing: $MariaDbExe"
    }

    Write-Host "MariaDB runtime restored: $MariaDbRuntimeRoot" -ForegroundColor Green
}

if (Test-Path $LibVipsDll) {
    Write-Host "libvips runtime already present: $LibVipsDll" -ForegroundColor Green
}
else {
    Write-Step "Restoring libvips runtime"

    New-Item -ItemType Directory -Path $RuntimeDownloadRoot -Force | Out-Null

    if (-not (Test-Path $LibVipsArchivePath)) {
        Write-Host "Downloading libvips $LibVipsVersion..."
        Write-Host $LibVipsDownloadUrl

        Invoke-WebRequest `
            -Uri $LibVipsDownloadUrl `
            -OutFile $LibVipsArchivePath
    }
    else {
        Write-Host "libvips archive already downloaded: $LibVipsArchivePath"
    }

    if (Test-Path $LibVipsExtractRoot) {
        Remove-Item $LibVipsExtractRoot -Recurse -Force
    }

    New-Item -ItemType Directory -Path $LibVipsExtractRoot -Force | Out-Null

    Write-Host "Extracting libvips archive..."

    Expand-Archive `
        -Path $LibVipsArchivePath `
        -DestinationPath $LibVipsExtractRoot `
        -Force

    $ExtractedLibVipsRoot = Get-ChildItem `
        -Path $LibVipsExtractRoot `
        -Directory |
        Select-Object -First 1

    if ($null -eq $ExtractedLibVipsRoot) {
        throw "libvips archive extraction did not produce a folder."
    }

    if (Test-Path $LibVipsRuntimeRoot) {
        Remove-Item $LibVipsRuntimeRoot -Recurse -Force
    }

    New-Item -ItemType Directory -Path (Split-Path -Parent $LibVipsRuntimeRoot) -Force | Out-Null

    Copy-Item `
        -Path $ExtractedLibVipsRoot.FullName `
        -Destination $LibVipsRuntimeRoot `
        -Recurse `
        -Force

    if (-not (Test-Path $LibVipsDll)) {
        throw "libvips runtime restore failed. Expected file missing: $LibVipsDll"
    }

    Write-Host "libvips runtime restored: $LibVipsRuntimeRoot" -ForegroundColor Green
}

Write-Step "Windows runtime check complete"