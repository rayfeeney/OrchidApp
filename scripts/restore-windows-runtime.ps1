param([switch]$LibVipsOnly)
$ErrorActionPreference = "Stop"
if (-not $IsWindows -or [Runtime.InteropServices.RuntimeInformation]::OSArchitecture -ne 'X64') {
    throw "This runtime restore supports Windows x64 only."
}

function Write-Step {
    param([string]$Message)

    Write-Host ""
    Write-Host "==> $Message"
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Resolve-Path (Join-Path $ScriptDir "..")

. (Join-Path $ScriptDir 'windows-mariadb-runtime.ps1')
$MariaDbPackageName = "mariadb-$WindowsMariaDbVersion-winx64.zip"
$MariaDbDownloadUrl = "https://archive.mariadb.org/mariadb-$WindowsMariaDbVersion/winx64-packages/$MariaDbPackageName"
$RuntimeDownloadRoot = Join-Path $RepoRoot ".runtime-downloads"
$MariaDbArchivePath = Join-Path $RuntimeDownloadRoot $MariaDbPackageName
$MariaDbRuntimeRoot = Join-Path $RuntimeDownloadRoot "mariadb-$WindowsMariaDbVersion-winx64"

$LibVipsRuntimeRoot = Join-Path $RepoRoot "app\runtime\libvips\win-x64"
$LibVipsDll = Join-Path $LibVipsRuntimeRoot "bin\libvips-42.dll"

$LibVipsVersion = "8.18.2"
$LibVipsPackageName = "vips-dev-x64-all-$LibVipsVersion.zip"
$LibVipsDownloadUrl = "https://github.com/libvips/build-win64-mxe/releases/download/v$LibVipsVersion/$LibVipsPackageName"
$LibVipsArchivePath = Join-Path $RuntimeDownloadRoot $LibVipsPackageName
$LibVipsExtractRoot = Join-Path $RuntimeDownloadRoot "libvips"
# Digest of the pinned upstream archive, measured during C16 validation.
$LibVipsSha256 = 'AEC9B8D5E79C06AADE9FD51224570C87687675896D4DA335955047C211D40E01'
# Validate every recursive-removal target before changing anything.
foreach ($target in @($MariaDbRuntimeRoot,$LibVipsRuntimeRoot,$LibVipsExtractRoot)) {
    $absoluteTarget = [IO.Path]::GetFullPath($target)
    if (-not $absoluteTarget.StartsWith($RepoRoot.Path + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Runtime target is outside the repository."
    }
}


Write-Step "Checking Windows runtime dependencies"

if (-not $LibVipsOnly) {
    if (-not (Test-Path -LiteralPath $MariaDbRuntimeRoot)) {
        Write-Step "Restoring MariaDB $WindowsMariaDbVersion"
        New-Item -ItemType Directory -Path $RuntimeDownloadRoot -Force | Out-Null
        if (-not (Test-Path -LiteralPath $MariaDbArchivePath -PathType Leaf)) {
            $download = "$MariaDbArchivePath.$([guid]::NewGuid().ToString('N')).download"
            try {
                Invoke-WebRequest -Uri $MariaDbDownloadUrl -OutFile $download
                if ((Get-FileHash -LiteralPath $download -Algorithm SHA256).Hash -ne $WindowsMariaDbArchiveSha256) {
                    throw 'Downloaded MariaDB archive checksum differs from the pinned upstream checksum.'
                }
                Move-Item -LiteralPath $download -Destination $MariaDbArchivePath
            }
            finally {
                if (Test-Path -LiteralPath $download) { Remove-Item -LiteralPath $download }
            }
        }

        if ((Get-FileHash -LiteralPath $MariaDbArchivePath -Algorithm SHA256).Hash -ne $WindowsMariaDbArchiveSha256) {
            throw "Pinned MariaDB archive checksum differs. Move the cached archive aside and retry: $MariaDbArchivePath"
        }
        $staging = Join-Path $RuntimeDownloadRoot ("mariadb-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $staging | Out-Null
        try {
            [IO.Compression.ZipFile]::ExtractToDirectory($MariaDbArchivePath, $staging)
            $extracted = Join-Path $staging "mariadb-$WindowsMariaDbVersion-winx64"
            Assert-WindowsMariaDbRuntime $extracted
            New-Item -ItemType Directory -Path (Split-Path -Parent $MariaDbRuntimeRoot) -Force | Out-Null
            Move-Item -LiteralPath $extracted -Destination $MariaDbRuntimeRoot
        }
        finally {
            $resolvedStage = (Resolve-Path -LiteralPath $staging).Path
            if (-not $resolvedStage.StartsWith($RepoRoot.Path + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
                throw 'MariaDB staging directory is outside the repository.'
            }
            Remove-Item -LiteralPath $resolvedStage -Recurse -Force
        }
    }
    Assert-WindowsMariaDbRuntime $MariaDbRuntimeRoot
    Write-Host "Verified MariaDB $WindowsMariaDbVersion runtime: $MariaDbRuntimeRoot" -ForegroundColor Green
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

    if ((Get-FileHash -LiteralPath $LibVipsArchivePath -Algorithm SHA256).Hash -ne $LibVipsSha256) {
        throw "Pinned libvips archive checksum differs. Remove the cached archive and download again."
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

foreach ($file in @('libvips-42.dll','libglib-2.0-0.dll','libgobject-2.0-0.dll','vips.exe')) {
    if (-not (Test-Path -LiteralPath (Join-Path $LibVipsRuntimeRoot "bin/$file") -PathType Leaf)) {
        throw "Incomplete libvips runtime: $file is missing. Restore the complete pinned archive."
    }
}
$nativeVersion = & (Join-Path $LibVipsRuntimeRoot 'bin/vips.exe') --version
if ($LASTEXITCODE -ne 0 -or $nativeVersion -cne "vips-$LibVipsVersion") {
    throw "libvips runtime must be version $LibVipsVersion."
}
Write-Step "Windows runtime check complete"