$ErrorActionPreference = "Stop"

Write-Host "Building OrchidApp database from snapshot..."

# --- Resolve repo root ---
$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Set-Location $RepoRoot

# --- Validate env vars ---
function Require-Env($name) {
    if (-not $env:$name) {
        throw "Missing required environment variable: $name"
    }
}

Require-Env "MYSQL_HOST"
Require-Env "MYSQL_PORT"
Require-Env "MYSQL_USER"
Require-Env "MYSQL_PASSWORD"
Require-Env "MYSQL_DATABASE"

$mysql = Get-Command mysql -ErrorAction Stop

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
        Write-Host " → $($file.Name)"

        & $mysql `
            --protocol=TCP `
            --host=$env:MYSQL_HOST `
            --port=$env:MYSQL_PORT `
            --user=$env:MYSQL_USER `
            --database=$env:MYSQL_DATABASE `
            --execute="source $($file.FullName)"

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
        Write-Host " → $($file.Name)"

        & $mysql `
            --protocol=TCP `
            --host=$env:MYSQL_HOST `
            --port=$env:MYSQL_PORT `
            --user=$env:MYSQL_USER `
            --database=$env:MYSQL_DATABASE `
            --execute="source $($file.FullName)"

        if ($LASTEXITCODE -ne 0) {
            throw "Failed applying $($file.Name)"
        }
    }
}

Apply-RequiredDir "database/schema/tables"
Apply-RequiredDir "database/schema/views"
Apply-RequiredDir "database/schema/routines"
Apply-RequiredDir "database/schema/triggers"
Apply-RequiredDir "database/schema/constraints"
Apply-OptionalDir "database/schema/seeds"

Write-Host "Database snapshot build completed successfully."