<#
.SYNOPSIS
  Local CI mirror for schema validation.

.DESCRIPTION
  Rebuilds the database schema from committed artefacts
  in a disposable MySQL Docker container.

  This script MUST remain byte-for-byte aligned with CI.
  Any change here must be mirrored in GitHub Actions.

.NOTES
  - Requires Docker
  - Does NOT modify Git state
  - Does NOT export schema
  - Validation only
#>

$ErrorActionPreference = 'Stop'

# ---------------- Check Docker is running -----------------------------------

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
  throw "Docker is required but not available on PATH."
}

docker info | Out-Null
if ($LASTEXITCODE -ne 0) {
  throw "Docker daemon is not running."
}

# ---------------- Configuration ---------------------------------------------

$MySqlImage    = 'mysql:8.0'
$ContainerName = [string]::Concat('orchidapp-ci-mysql-', $PID)
$DatabaseName  = 'orchids_ci'
$RootPassword  = 'root'
$MySqlPort     = 3307   # local-only, avoid clashing with dev DB

# ---------------- Pre-flight checks -----------------------------------------

if (-not (Test-Path 'database/scripts/Assemble-Schema.ps1')) {
  throw "database/scripts/Assemble-Schema.ps1 not found."
}

Write-Host "Starting local CI schema validation..." -ForegroundColor Cyan

# ---------------- Cleanup handler -------------------------------------------

function Cleanup {
  Write-Host "Cleaning up Docker container..." -ForegroundColor DarkGray
  docker rm -f $ContainerName 2>$null | Out-Null
}

Cleanup
try {

  # ---------------- Start MySQL container -----------------------------------

  Write-Host "Starting MySQL container..." -ForegroundColor Cyan

  docker run `
    --name $ContainerName `
    -e MYSQL_ROOT_PASSWORD=$RootPassword `
    -e MYSQL_DATABASE=$DatabaseName `
    -p $MySqlPort`:3306 `
    -d $MySqlImage | Out-Null

  # ---------------- Wait for MySQL ------------------------------------------

  Write-Host "Waiting for MySQL to be ready..." -ForegroundColor Cyan

  $ready = $false
  for ($i = 0; $i -lt 30; $i++) {
    try {
      docker exec $ContainerName `
        mysql -h 127.0.0.1 -u root -p$RootPassword `
        -e "SELECT 1;" 2>$null | Out-Null
      $ready = $true
      break
    }
    catch {
      Start-Sleep -Seconds 2
    }
  }

  if (-not $ready) {
    throw "MySQL did not become ready in time."
  }

  # ---------------- Run schema assembly -------------------------------------

  Write-Host "Assembling schema from Git artefacts..." -ForegroundColor Cyan

  # Provide connection details to Assemble-Schema.ps1
  # These mirror the values used in CI exactly

  $env:MYSQL_HOST     = '127.0.0.1'
  $env:MYSQL_PORT     = $MySqlPort
  $env:MYSQL_USER     = 'root'
  $env:MYSQL_PASSWORD = $RootPassword
  $env:MYSQL_DATABASE = $DatabaseName

  pwsh database/scripts/Assemble-Schema.ps1
  if ($LASTEXITCODE -ne 0) {
    throw "Schema assembly failed."
  }

  Write-Host "Schema build completed successfully." -ForegroundColor Green
}
finally {
  Cleanup
}
