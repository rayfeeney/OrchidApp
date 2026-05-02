$ErrorActionPreference = "Stop"

try {
    Write-Host "=== DEV MIGRATION RUNNER START ==="

    # --- ENV VALIDATION ----------------------------------------------------

    if (-not $env:MARIADB_USER) {
        throw "MARIADB_USER not set."
    }

    if (-not $env:MARIADB_PASSWORD) {
        throw "MARIADB_PASSWORD not set."
    }

    # --- REPO ROOT ---------------------------------------------------------

    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
    Set-Location $RepoRoot

    # --- PATH VALIDATION ---------------------------------------------------

    $MigrationFolder = "database/migrations"
    $SchemaFolder    = "database/schema"
    $ExportScript    = "database/scripts/Export-MariaDbSchema.ps1"
    $ApplyScript     = "database/scripts/apply-migrations.ps1"

    foreach ($path in @($MigrationFolder, $SchemaFolder, $ExportScript, $ApplyScript)) {
        if (-not (Test-Path $path)) {
            throw "Required path not found: $path"
        }
    }

    Write-Host "Repository root: $RepoRoot"

    # --- CONNECTION (for export script) -----------------------------------

    $env:MYSQL_PWD = $env:MARIADB_PASSWORD

    # --- WORKING TREE CLEAN CHECK -----------------------------------------

    Write-Host "[CHECK] Working tree..."

    git diff --quiet -- $SchemaFolder $MigrationFolder
    if ($LASTEXITCODE -ne 0) {
        throw "Tracked database files have uncommitted changes."
    }

    $untracked = @(git ls-files --others --exclude-standard -- $MigrationFolder)
    if ($untracked.Count -gt 0) {
        throw "Untracked migration files detected:`n$($untracked -join "`n")"
    }

    Write-Host "[OK] Working tree clean"

    # --- EXPORT (PRE) ------------------------------------------------------

    Write-Host "[STEP] Export schema (pre-check)..."

    & $ExportScript

    # export script clears MYSQL_PWD
    $env:MYSQL_PWD = $env:MARIADB_PASSWORD

    # --- DRIFT CHECK (PRE) -------------------------------------------------

    Write-Host "[CHECK] Schema drift (pre)..."

    $diff = @(git diff --name-only -- $SchemaFolder)

    if ($diff.Count -gt 0) {
        throw "Schema drift detected BEFORE migrations:`n$($diff -join "`n")"
    }

    Write-Host "[OK] No drift before migrations"

    # --- APPLY MIGRATIONS --------------------------------------------------

    Write-Host "[STEP] Applying migrations..."

    & $ApplyScript

    Write-Host "[OK] Migrations applied"

    # --- EXPORT (POST) -----------------------------------------------------

    Write-Host "[STEP] Export schema (post-check)..."

    & $ExportScript

    $env:MYSQL_PWD = $env:MARIADB_PASSWORD

    # --- DRIFT CHECK (POST) ------------------------------------------------

    Write-Host "[CHECK] Schema drift (post)..."

    $postDiff = @(git diff --name-only -- $SchemaFolder)

    if ($postDiff.Count -gt 0) {
        throw "Schema drift detected AFTER migrations (export not committed):`n$($postDiff -join "`n")"
    }

    Write-Host "[OK] No drift after migrations"

    Write-Host "=== DEV MIGRATION RUNNER SUCCESS ==="
}
finally {
    Remove-Item Env:\MYSQL_PWD -ErrorAction SilentlyContinue
}