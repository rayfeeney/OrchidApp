$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Set-Location $RepoRoot

# -------------------------------------------------------
# Load .env file (env vars override .env)
# -------------------------------------------------------
$envFile = Join-Path $RepoRoot ".env"

if (Test-Path $envFile) {
    Write-Host "Loading .env configuration..."

    Get-Content $envFile | ForEach-Object {

        # Skip comments / empty lines
        if ($_ -match '^\s*#' -or $_ -match '^\s*$') {
            return
        }

        $parts = $_ -split '=', 2

        if ($parts.Count -ne 2) {
            return
        }

        $name  = $parts[0].Trim()
        $value = $parts[1].Trim()

        # Only set if NOT already defined (env vars win)
        if (-not (Test-Path "Env:$name")) {
            Set-Item -Path "Env:$name" -Value $value
        }
    }
}

Write-Host "CONFIG CHECK:"
Write-Host "  Host: $($env:MARIADB_HOST)"
Write-Host "  Port: $($env:MARIADB_PORT)"
Write-Host "  User: $($env:MARIADB_USER)"
Write-Host "  Database: $($env:MARIADB_DATABASE)"


# -------------------------------------------------------
# Validate required environment variables
# -------------------------------------------------------
function Require-Env($name) {
    if (-not (Get-Item "Env:$($name)" -ErrorAction SilentlyContinue)) {
        Set-Item -Path "Env:$($name)" -Value $value
    }
}

Require-Env "MARIADB_HOST"
Require-Env "MARIADB_PORT"
Require-Env "MARIADB_USER"
Require-Env "MARIADB_PASSWORD"
Require-Env "MARIADB_DATABASE"

# -------------------------------------------------------
# MariaDB executable
# -------------------------------------------------------
$MariaDbExe = "C:\Program Files\MariaDB 10.11\bin\mariadb.exe"

if (-not (Test-Path $MariaDbExe)) {
    throw "mariadb.exe not found at $MariaDbExe"
}

# Avoid password escaping issues
$env:MYSQL_PWD = $env:MARIADB_PASSWORD

function Invoke-MariaDb {
    param (
        [Parameter(Mandatory)]
        [string]$Sql
    )

    $Sql | & $MariaDbExe `
        --protocol=TCP `
        --host=$env:MARIADB_HOST `
        --port=$env:MARIADB_PORT `
        --user=$env:MARIADB_USER

    if ($LASTEXITCODE -ne 0) {
        throw "MariaDB execution failed"
    }
}

Write-Host "Rebuild configuration:"
Write-Host "  Host: $($env:MARIADB_HOST)"
Write-Host "  Port: $($env:MARIADB_PORT)"
Write-Host "  User: $($env:MARIADB_USER)"
Write-Host "  Database: $($env:MARIADB_DATABASE)"

# -------------------------------------------------------
# Drop and recreate database
# -------------------------------------------------------
Write-Host "Recreating database..."

$database = $env:MARIADB_DATABASE

$recreateSql = @"
DROP DATABASE IF EXISTS `$database`;
CREATE DATABASE `$database`;
"@

Invoke-MariaDb -Sql $recreateSql

Write-Host "Database recreated."

function Apply-RequiredDir($dir) {

    if (-not (Test-Path $dir)) {
        throw "Required schema directory missing: $dir"
    }

    $files = Get-ChildItem $dir -Filter *.sql | Sort-Object Name

    if (-not $files) {
        throw "Required schema directory empty: $dir"
    }

    Write-Host "Applying $dir"

    foreach ($file in $files) {

        Write-Host "  → $($file.Name)"

        Get-Content $file.FullName -Raw | & $MariaDbExe `
            --protocol=TCP `
            --host=$env:MARIADB_HOST `
            --port=$env:MARIADB_PORT `
            --user=$env:MARIADB_USER `
            $env:MARIADB_DATABASE

        if ($LASTEXITCODE -ne 0) {
            throw "Failed applying $($file.Name)"
        }
    }
}

function Apply-OptionalDir($dir) {

    if (-not (Test-Path $dir)) {
        Write-Host "Optional directory missing: $dir"
        return
    }

    $files = Get-ChildItem $dir -Filter *.sql | Sort-Object Name

    if (-not $files) {
        Write-Host "Optional directory empty: $dir"
        return
    }

    Write-Host "Applying optional $dir"

    foreach ($file in $files) {

        Write-Host "  → $($file.Name)"

        Get-Content $file.FullName -Raw | & $MariaDbExe `
            --protocol=TCP `
            --host=$env:MARIADB_HOST `
            --port=$env:MARIADB_PORT `
            --user=$env:MARIADB_USER `
            $env:MARIADB_DATABASE

        if ($LASTEXITCODE -ne 0) {
            throw "Failed applying $($file.Name)"
        }
    }
}

# -------------------------------------------------------
# Apply schema in dependency order
# -------------------------------------------------------
Apply-RequiredDir "database/schema/tables"
Apply-RequiredDir "database/schema/views"
Apply-RequiredDir "database/schema/routines"
Apply-RequiredDir "database/schema/triggers"
Apply-RequiredDir "database/schema/constraints"
Apply-OptionalDir "database/schema/seeds"

Write-Host "Database rebuild completed successfully."