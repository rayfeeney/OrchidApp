$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "Repository setup starting..." -ForegroundColor Cyan
Write-Host ""

# --- Helper function ---
function Require-Command {
    param (
        [string]$Name
    )

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        Write-Error "Required command '$Name' was not found in PATH."
    }

    Write-Host "✔ Found $Name"
}

# --- Ensure PowerShell 7 ---
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Error "PowerShell 7 or higher is required. Please run this script using 'pwsh'."
}

Write-Host "✔ PowerShell $($PSVersionTable.PSVersion) detected"

# --- Required commands ---
Require-Command git
Require-Command pwsh
Require-Command mysql
Require-Command mysqldump

Write-Host ""

# --- Environment variables ---
$MissingEnv = @()

if (-not $env:MYSQL_USER) {
    $MissingEnv += "MYSQL_USER"
}

if (-not $env:MYSQL_PASSWORD) {
    $MissingEnv += "MYSQL_PASSWORD"
}

if ($MissingEnv.Count -gt 0) {
    Write-Error (
        "Missing required environment variables: " +
        ($MissingEnv -join ", ") +
        "`nSet them using:`n" +
        'setx MYSQL_USER "your_mysql_user"`n' +
        'setx MYSQL_PASSWORD "your_mysql_password"`n' +
        "`nThen restart GitHub Desktop."
    )
}

Write-Host "✔ Required environment variables are set"

Write-Host ""

# --- Configure Git hooks path ---
Write-Host "Configuring Git hooks path for this repository..."

git config core.hooksPath .githooks

$ConfiguredHooksPath = git config --local --get core.hooksPath

if ($ConfiguredHooksPath -ne ".githooks") {
    Write-Error "Failed to configure core.hooksPath. Expected '.githooks', got '$ConfiguredHooksPath'."
}

Write-Host "✔ Git hooks path set to .githooks"

Write-Host ""
Write-Host "Setup complete." -ForegroundColor Green
Write-Host ""
Write-Host "If you use GitHub Desktop, please restart it before committing." -ForegroundColor Yellow
Write-Host ""
