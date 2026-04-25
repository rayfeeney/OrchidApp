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
function Assert-Env($name) {
    $val = (Get-Item "Env:$name" -ErrorAction SilentlyContinue)?.Value

    if (-not $val) {
        throw "Required environment variable '$name' is not set"
    }
}

Assert-Env "MARIADB_HOST"
Assert-Env "MARIADB_PORT"
Assert-Env "MARIADB_USER"
Assert-Env "MARIADB_PASSWORD"
Assert-Env "MARIADB_DATABASE"
Assert-Env "MARIADB_CHARSET"
Assert-Env "MARIADB_COLLATION"

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

    $output = $Sql | & $MariaDbExe `
        --protocol=TCP `
        --host=$env:MARIADB_HOST `
        --port=$env:MARIADB_PORT `
        --user=$env:MARIADB_USER `
        --default-character-set=$env:MARIADB_CHARSET `
        2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-Host "---- MariaDB ERROR OUTPUT ----" -ForegroundColor Red
        $output | ForEach-Object { Write-Host $_ -ForegroundColor Red }
        Write-Host "--------------------------------" -ForegroundColor Red

        throw "MariaDB execution failed"
    }

    return $output
}

Write-Host "Rebuild configuration:"
Write-Host "  Host: $($env:MARIADB_HOST)"
Write-Host "  Port: $($env:MARIADB_PORT)"
Write-Host "  User: $($env:MARIADB_USER)"
Write-Host "  Database: $($env:MARIADB_DATABASE)"
Write-Host "  Charset: $($env:MARIADB_CHARSET)"
Write-Host "  Collation: $($env:MARIADB_COLLATION)"


# -------------------------------------------------------
# Drop and recreate database
# -------------------------------------------------------
Write-Host "Recreating database..."

$db        = $env:MARIADB_DATABASE
$charset   = $env:MARIADB_CHARSET
$collation = $env:MARIADB_COLLATION

$recreateSql = @"
DROP DATABASE IF EXISTS $db;
CREATE DATABASE $db
  CHARACTER SET $charset
  COLLATE $collation;
"@

Invoke-MariaDb -Sql $recreateSql

Write-Host "Database recreated."

Write-Host "Verifying database exists..."

$testSql = "USE $db; SELECT 1;"

Invoke-MariaDb -Sql $testSql

Write-Host "Database verified."

function Invoke-RequiredDir($dir) {

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
            --database=$env:MARIADB_DATABASE

        if ($LASTEXITCODE -ne 0) {
            throw "Failed applying $($file.Name)"
        }
    }
}

function Invoke-MariaDbDirectoryIfExists($dir) {

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

        Invoke-MariaDbFile $file.FullName
    }
}

function Invoke-MariaDbFile {
    param (
        [Parameter(Mandatory)]
        [string]$FilePath
    )

    Get-Content $FilePath -Raw | & $MariaDbExe `
        --protocol=TCP `
        --host=$env:MARIADB_HOST `
        --port=$env:MARIADB_PORT `
        --user=$env:MARIADB_USER `
        --database=$env:MARIADB_DATABASE

    if ($LASTEXITCODE -ne 0) {
        throw "Failed applying $FilePath"
    }
}
# -------------------------------------------------------
# Apply schema in dependency order
# -------------------------------------------------------
Invoke-RequiredDir "database/schema/tables"
Invoke-RequiredDir "database/schema/constraints"
Invoke-RequiredDir "database/schema/views"
Invoke-RequiredDir "database/schema/routines"
Invoke-RequiredDir "database/schema/triggers"
Invoke-MariaDbDirectoryIfExists "database/schema/seeds"

Write-Host "Database rebuild completed successfully."