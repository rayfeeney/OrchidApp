$ErrorActionPreference = "Stop"

try {

    Write-Host "Starting migration runner..."


    # --- Locate Repository Root --------------------------------------------

    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
    Set-Location $RepoRoot


    # --- Key Paths ----------------------------------------------------------
 
    $MigrationFolder = Resolve-Path "database/migrations"
    $SchemaFolder    = Resolve-Path "database/schema"
    $ExportScript    = Resolve-Path "database/scripts/Export-MySqlSchema.ps1"

 
    # --- Ensure Database Working Tree Is Clean ---------------------------------

    Write-Host "Checking database-related working tree..."

    $diffExit = git diff --quiet -- database/schema database/migrations
    if ($LASTEXITCODE -ne 0) {
        throw "Database-related tracked files have uncommitted changes."
    }

    Write-Host "Database working tree is clean."

 
    # --- Run Schema Export ------------------------------------------------------

    Write-Host "Running schema export to detect drift..."

    & $ExportScript

    Write-Host "Schema export completed."


    # --- Detect Schema Drift ----------------------------------------------------
 
    Write-Host "Checking for schema drift..."

    $schemaDiff = git diff --name-only -- database/schema

    if ($schemaDiff) {
        throw "Schema drift detected. Database structure does not match committed snapshot."
    }

    Write-Host "No schema drift detected."

    Write-Host "Repository root: $RepoRoot"
    Write-Host "Migration folder: $MigrationFolder"


    # --- Ensure MySQL CLI Available --------------------------------------------
 
    foreach ($cmd in @("mysql")) {
        if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
            throw "$cmd not found in PATH"
        }
    }


    # --- Load Connection Settings ----------------------------------------------
 
    $MySqlHost = $env:MYSQL_HOST ?? "localhost"
    $MySqlPort = $env:MYSQL_PORT ?? 3306
    $Database  = "orchids"
    $User      = $env:MYSQL_USER
    $Password  = $env:MYSQL_PASSWORD

    if (-not $User -or -not $Password) {
        throw "MYSQL_USER or MYSQL_PASSWORD environment variables not set"
    }

    $env:MYSQL_PWD = $Password


    # --- Ensure schemaversion Table Exists -------------------------------------

    Write-Host "Ensuring schemaversion table exists..."

$createVersionTable = @"
CREATE TABLE IF NOT EXISTS schemaversion (
  versionId int NOT NULL AUTO_INCREMENT,
  scriptName varchar(255) NOT NULL,
  checksum char(64) NOT NULL,
  appliedAt datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (versionId),
  UNIQUE KEY uq_scriptName (scriptName)
);
"@.Trim()

& mysql `
  --default-character-set=utf8mb4 `
  --init-command="SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci" `
  --protocol=TCP `
  --host=$MySqlHost `
  --port=$MySqlPort `
  --user=$User `
  --database=$Database `
  --execute=$createVersionTable

    if ($LASTEXITCODE -ne 0) {
    throw "Failed to create or verify schemaversion table."
    }

    Write-Host "schemaversion table verified."


    # --- Read Applied Migrations -----------------------------------------------

    Write-Host "Reading applied migrations..."

    $appliedRows = & mysql `
        --default-character-set=utf8mb4 `
        --protocol=TCP `
        --host=$MySqlHost `
        --port=$MySqlPort `
        --user=$User `
        --batch `
        --skip-column-names `
        --database=$Database `
        --execute="SELECT scriptName, checksum FROM schemaversion ORDER BY scriptName;"

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to read schemaversion table."
    }

    $AppliedMigrations = @{}

    foreach ($row in $appliedRows) {
        $parts = $row -split "`t"
        $AppliedMigrations[$parts[0]] = $parts[1]
    }

    Write-Host "Applied migrations count: $($AppliedMigrations.Count)"


    # --- Discover Migration Files ----------------------------------------------

    Write-Host "Discovering migration files..."

    $MigrationFiles = Get-ChildItem $MigrationFolder -Filter "*.sql" | Sort-Object Name

    if (-not $MigrationFiles) {
        Write-Host "No migration files found. Nothing to do."
        return
    }

    Write-Host "Found $($MigrationFiles.Count) migration file(s)."


    # --- Validate Filename Format ----------------------------------------------

    $FilenamePattern = '^\d{12}_[A-Za-z0-9_]+\.sql$'

    foreach ($file in $MigrationFiles) {
        if ($file.Name -notmatch $FilenamePattern) {
            throw "Invalid migration filename format: $($file.Name)"
        }
    }


    # --- Extract and Validate Timestamps ---------------------------------------

    $Timestamps = @{}

    foreach ($file in $MigrationFiles) {

        $timestamp = $file.Name.Substring(0, 12)

        if ($Timestamps.ContainsKey($timestamp)) {
            throw "Duplicate migration timestamp detected: $timestamp"
        }

        $Timestamps[$timestamp] = $file.Name
    }


    # --- Detect Out-of-Order Migrations ----------------------------------------

    if ($AppliedMigrations.Count -gt 0) {

        $MaxAppliedTimestamp = ($AppliedMigrations.Keys |
            ForEach-Object { $_.Substring(0,12) } |
            Sort-Object |
            Select-Object -Last 1)

        foreach ($file in $MigrationFiles) {

            $timestamp = $file.Name.Substring(0,12)

            if (-not $AppliedMigrations.ContainsKey($file.Name)) {

                if ($timestamp -lt $MaxAppliedTimestamp) {
                    throw "Out-of-order migration detected: $($file.Name)"
                }
            }
        }
    }


    # --- Validate Applied Migration Checksums ----------------------------------

    foreach ($file in $MigrationFiles) {

        if ($AppliedMigrations.ContainsKey($file.Name)) {

            $fileContent = Get-Content $file.FullName -Raw
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($fileContent)
            $hash = (Get-FileHash -InputStream ([IO.MemoryStream]::new($bytes)) -Algorithm SHA256).Hash

            if ($hash -ne $AppliedMigrations[$file.Name]) {
                throw "Checksum mismatch detected for applied migration: $($file.Name)"
            }
        }
    }


    # --- Apply Pending Migrations ----------------------------------------------

    Write-Host "Applying pending migrations..."

    foreach ($file in $MigrationFiles) {

        if (-not $AppliedMigrations.ContainsKey($file.Name)) {

            Write-Host "Applying migration: $($file.Name)"

            # Compute checksum
            $fileContent = Get-Content $file.FullName -Raw
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($fileContent)
            $hash = (Get-FileHash -InputStream ([IO.MemoryStream]::new($bytes)) -Algorithm SHA256).Hash

            # Execute migration file via stdin (production-like behaviour)
            & mysql `
            --default-character-set=utf8mb4 `
            --protocol=TCP `
            --host=$MySqlHost `
            --port=$MySqlPort `
            --user=$User `
            --database=$Database `
            --execute="source $($file.FullName)"

            if ($LASTEXITCODE -ne 0) {
                throw "Migration failed: $($file.Name)"
            }

            # Record migration in schemaversion
            $insertSql = "INSERT INTO schemaversion (scriptName, checksum) VALUES ('$($file.Name)', '$hash');"

            & mysql `
                --default-character-set=utf8mb4 `
                --protocol=TCP `
                --host=$MySqlHost `
                --port=$MySqlPort `
                --user=$User `
                --database=$Database `
                --execute=$insertSql

            if ($LASTEXITCODE -ne 0) {
                throw "Failed to record migration in schemaversion: $($file.Name)"
            }

            Write-Host "Migration applied successfully: $($file.Name)"
        }
    }

    Write-Host "Migration phase completed."


    }
    finally {
        Remove-Item Env:\MYSQL_PWD -ErrorAction SilentlyContinue
}
