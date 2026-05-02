```powershell
$ErrorActionPreference = "Stop"

try {
    Write-Host "Starting DEV migration runner..."

    if (-not $env:MARIADB_USER) {
        throw "Environment not configured. Set MARIADB_* variables before running."
    }

    # --- REPO ROOT --------------------------------------------------------

    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
    Set-Location $RepoRoot

    # --- PATHS ------------------------------------------------------------

    $MigrationFolder = (Resolve-Path "database/migrations").Path
    $SchemaFolder    = (Resolve-Path "database/schema").Path
    $ExportScript    = (Resolve-Path "database/scripts/Export-MariaDbSchema.ps1").Path
    $ApplyScript     = (Resolve-Path "database/scripts/apply-migrations.ps1").Path

    Write-Host "Repository root: $RepoRoot"

    # --- CONNECTION (for export script consistency) -----------------------

    $Password = $env:MARIADB_PASSWORD
    if (-not $Password) {
        throw "MARIADB_PASSWORD must be set"
    }

    $env:MYSQL_PWD = $Password

    # --- WORKING TREE CHECK ----------------------------------------------

    Write-Host "Checking database working tree..."

    git diff --quiet -- database/schema database/migrations
    if ($LASTEXITCODE -ne 0) {
        throw "Tracked database files have uncommitted changes."
    }

    $untracked = @(git ls-files --others --exclude-standard -- database/migrations)
    if ($untracked.Count -gt 0) {
        throw "Untracked migration files detected:`n$($untracked -join "`n")"
    }

    Write-Host "Working tree clean."

    # --- EXPORT SCHEMA ----------------------------------------------------

    Write-Host "Running schema export..."

    & $ExportScript

    if ($LASTEXITCODE -ne 0) {
        throw "Schema export failed."
    }

    # export script clears MYSQL_PWD
    $env:MYSQL_PWD = $Password

    # --- DRIFT CHECK ------------------------------------------------------

    Write-Host "Checking for schema drift..."

    $diff = @(git diff --name-only -- database/schema)

    if ($diff.Count -gt 0) {
        throw "Schema drift detected:`n$($diff -join "`n")"
    }

    Write-Host "No schema drift."

    # --- APPLY MIGRATIONS -------------------------------------------------

    Write-Host "Applying migrations..."

    & $ApplyScript

    if ($LASTEXITCODE -ne 0) {
        throw "Migration application failed."
    }

    # --- POST-VALIDATION --------------------------------------------------

    Write-Host "Re-exporting schema after migrations..."

    & $ExportScript

    if ($LASTEXITCODE -ne 0) {
        throw "Post-migration export failed."
    }

    $env:MYSQL_PWD = $Password

    $postDiff = @(git diff --name-only -- database/schema)

    if ($postDiff.Count -gt 0) {
        throw "Post-migration schema drift detected (export not committed):`n$($postDiff -join "`n")"
    }

    Write-Host "DEV migration runner completed successfully."
}
finally {
    Remove-Item Env:\MYSQL_PWD -ErrorAction SilentlyContinue
}
```
