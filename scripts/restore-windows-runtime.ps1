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

$LibVipsRuntimeRoot = Join-Path $RepoRoot "app\runtime\libvips\win-x64"
$LibVipsDll = Join-Path $LibVipsRuntimeRoot "bin\libvips-42.dll"

Write-Step "Checking Windows runtime dependencies"

if (Test-Path $MariaDbExe) {
    Write-Host "MariaDB runtime already present: $MariaDbExe" -ForegroundColor Green
}
else {
    Write-Host "MariaDB runtime missing: $MariaDbExe" -ForegroundColor Yellow
}

if (Test-Path $LibVipsDll) {
    Write-Host "libvips runtime already present: $LibVipsDll" -ForegroundColor Green
}
else {
    Write-Host "libvips runtime missing: $LibVipsDll" -ForegroundColor Yellow
}

Write-Step "Windows runtime check complete"