$ErrorActionPreference = "Stop"

try {
    Write-Host "Starting MariaDB migration runner..."

    if (-not $env:MARIADB_USER) {
        throw "Environment not configured. Set MARIADB_* variables before running."
    }
    # --- PRECONDITIONS -----------------------------------------------------

    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
    Set-Location $RepoRoot

    # --- KEY PATHS ---------------------------------------------------------

    $MigrationFolder = (Resolve-Path "database/migrations").Path
    $SchemaFolder    = (Resolve-Path "database/schema").Path
    $ExportScript    = (Resolve-Path "database/scripts/Export-MariaDbSchema.ps1").Path

    Write-Host "Repository root: $RepoRoot"
    Write-Host "Migration folder: $MigrationFolder"
    Write-Host "Schema folder: $SchemaFolder"
    Write-Host "Export script: $ExportScript"

    # --- TOOL PATHS (deterministic, no PATH dependency) --------------------

    if ($IsWindows) {
        $MariaDbExe = "C:\Program Files\MariaDB 10.11\bin\mariadb.exe"
    }
    else {
        $MariaDbExe = "mariadb"
    }

    if ($IsWindows -and -not (Test-Path $MariaDbExe)) {
        throw "mariadb.exe not found at $MariaDbExe"
    }

    # --- CONNECTION SETTINGS -----------------------------------------------

    $MariaDbHost = $env:MARIADB_HOST ?? $env:MYSQL_HOST ?? "localhost"
    $MariaDbPort = $env:MARIADB_PORT ?? $env:MYSQL_PORT ?? 3307
    $Database    = "orchids"
    $User        = $env:MARIADB_USER
    $Password    = $env:MARIADB_PASSWORD

    if (-not $User -or -not $Password) {
        throw "MARIADB_USER and MARIADB_PASSWORD must be set"
    }

    $env:MYSQL_PWD = $Password

    Write-Host "Using DB user: $User"
    Write-Host "Server: ${MariaDbHost}:${MariaDbPort}"
    Write-Host "Database: $Database"

    # --- HELPERS -----------------------------------------------------------

    function Invoke-MariaDbQuery {
        param (
            [Parameter(Mandatory)]
            [string]$Query
        )

        $output = & $MariaDbExe `
            --protocol=TCP `
            --host=$MariaDbHost `
            --port=$MariaDbPort `
            --user=$User `
            --connect-timeout=5 `
            --batch `
            --skip-column-names `
            --database=$Database `
            --execute="$Query" `
            2>&1

        if ($LASTEXITCODE -ne 0) {
            Write-Host "---- MariaDB ERROR OUTPUT ----" -ForegroundColor Red
            $output | ForEach-Object { Write-Host $_ -ForegroundColor Red }
            Write-Host "--------------------------------" -ForegroundColor Red
            throw "MariaDB command failed (exit code $LASTEXITCODE)"
        }

        return $output
    }

    function Invoke-MariaDbSqlFile {
        param (
            [Parameter(Mandatory)]
            [string]$FilePath
        )

        if (-not (Test-Path $FilePath)) {
            throw "SQL file not found: $FilePath"
        }

        # MariaDB expects forward slashes even on Windows
        $normalizedPath = $FilePath -replace '\\', '/'

        $sql = "SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci; source $normalizedPath;"

        $output = $sql | & $MariaDbExe `
            --protocol=TCP `
            --host=$MariaDbHost `
            --port=$MariaDbPort `
            --user=$User `
            --database=$Database `
            --connect-timeout=5 `
            --default-character-set=utf8mb4 `
            2>&1

        if ($LASTEXITCODE -ne 0) {
            Write-Host "---- MariaDB ERROR OUTPUT ----" -ForegroundColor Red
            $output | ForEach-Object { Write-Host $_ -ForegroundColor Red }
            Write-Host "--------------------------------" -ForegroundColor Red
            throw "Migration failed while executing file: $FilePath"
        }
    }

    function Get-MigrationChecksum {
        param (
            [Parameter(Mandatory)]
            [string]$FilePath
        )

        return (Get-FileHash -Path $FilePath -Algorithm SHA256).Hash.ToLowerInvariant()
    }

    # --- ENSURE DATABASE WORKING TREE IS CLEAN -----------------------------

    Write-Host "Checking database-related working tree..."

    git diff --quiet -- database/schema database/migrations
    if ($LASTEXITCODE -ne 0) {
        throw "Database-related tracked files have uncommitted changes."
    }

    $untrackedMigrationFiles = @(git ls-files --others --exclude-standard -- database/migrations)
    if ($untrackedMigrationFiles.Count -gt 0) {
        throw "Untracked migration files detected:`n$($untrackedMigrationFiles -join "`n")"
    }

    Write-Host "Database working tree is clean."

    # --- RUN SCHEMA EXPORT -------------------------------------------------

    Write-Host "Running schema export to detect drift..."

    & $ExportScript

    if ($LASTEXITCODE -ne 0) {
        throw "Schema export failed."
    }

    Write-Host "Schema export completed."

# Reapply MYSQL_PWD because export script clears it
$env:MYSQL_PWD = $Password

    # --- DETECT SCHEMA DRIFT -----------------------------------------------

    Write-Host "Checking for schema drift..."

    $schemaDiff = @(git diff --name-only -- database/schema)
    if ($schemaDiff.Count -gt 0) {
        throw "Schema drift detected. Database structure does not match committed snapshot.`n$($schemaDiff -join "`n")"
    }

    Write-Host "No schema drift detected."

    # --- ENSURE SCHEMAVERSION TABLE EXISTS ---------------------------------

    Write-Host "Ensuring schemaversion table exists..."

    Invoke-MariaDbQuery @"
CREATE TABLE IF NOT EXISTS schemaversion (
    scriptName VARCHAR(255) NOT NULL PRIMARY KEY,
    checksum CHAR(64) NOT NULL,
    appliedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
"@ | Out-Null

    Write-Host "schemaversion table is ready."

    # --- READ APPLIED MIGRATIONS -------------------------------------------

    Write-Host "Reading applied migrations..."

    $appliedRows = @(Invoke-MariaDbQuery @"
SELECT scriptName, checksum
FROM schemaversion
ORDER BY scriptName;
"@)

    $appliedMigrations = @{}

    foreach ($row in $appliedRows) {
        if ([string]::IsNullOrWhiteSpace($row)) {
            continue
        }

        $parts = $row -split "`t"
        $scriptName = $parts[0]
        $checksum   = if ($parts.Count -ge 2) { $parts[1] } else { "" }

        $appliedMigrations[$scriptName] = $checksum
    }

    Write-Host "Applied migrations found: $($appliedMigrations.Count)"

    # --- COLLECT MIGRATION FILES -------------------------------------------

    Write-Host "Collecting migration files..."

    $migrationFiles = @(Get-ChildItem -Path $MigrationFolder -Filter "*.sql" -File | Sort-Object Name)

    if ($migrationFiles.Count -eq 0) {
        Write-Host "No migration files found."
        Write-Host "MariaDB migration runner completed successfully."
        exit 0
    }

    # --- VALIDATE MIGRATION FILENAMES --------------------------------------

    Write-Host "Validating migration filenames..."

    $expectedPattern = '^\d{12}_.+\.sql$'

    foreach ($migrationFile in $migrationFiles) {
        if ($migrationFile.Name -notmatch $expectedPattern) {
            throw "Invalid migration filename '$($migrationFile.Name)'. Expected format: YYYYMMDDHHMM_Description.sql"
        }
    }

    Write-Host "Migration filenames are valid."

    # --- VALIDATE APPLIED MIGRATIONS STILL EXIST ---------------------------

    foreach ($appliedScriptName in $appliedMigrations.Keys) {
        $matchingFile = $migrationFiles | Where-Object { $_.Name -eq $appliedScriptName }

        if (-not $matchingFile) {
            throw "Applied migration '$appliedScriptName' is recorded in schemaversion but no longer exists in database/migrations."
        }
    }

    # --- VALIDATE CHECKSUM IMMUTABILITY ------------------------------------

    Write-Host "Validating applied migration checksums..."

    foreach ($migrationFile in $migrationFiles) {
        if (-not $appliedMigrations.ContainsKey($migrationFile.Name)) {
            continue
        }

        $currentChecksum = Get-MigrationChecksum -FilePath $migrationFile.FullName
        $recordedChecksum = $appliedMigrations[$migrationFile.Name]

        if ([string]::IsNullOrWhiteSpace($recordedChecksum)) {
            throw "Applied migration '$($migrationFile.Name)' has no checksum recorded in schemaversion."
        }

        if ($currentChecksum -ne $recordedChecksum) {
            throw "Checksum mismatch for applied migration '$($migrationFile.Name)'. The file has changed since it was applied."
        }
    }

    Write-Host "Applied migration checksums are valid."

    # --- VALIDATE ORDER / GAPS ---------------------------------------------

    Write-Host "Validating migration order..."

    $firstMissingEncountered = $false

    foreach ($migrationFile in $migrationFiles) {
        $isApplied = $appliedMigrations.ContainsKey($migrationFile.Name)

        if (-not $isApplied) {
            $firstMissingEncountered = $true
            continue
        }

        if ($firstMissingEncountered -and $isApplied) {
            throw "Out-of-order migration state detected. Applied migration '$($migrationFile.Name)' appears after one or more missing earlier migrations."
        }
    }

    Write-Host "Migration order is valid."

    # --- APPLY MISSING MIGRATIONS ------------------------------------------

    $appliedCount = 0

    foreach ($migrationFile in $migrationFiles) {
        $scriptName = $migrationFile.Name

        if ($appliedMigrations.ContainsKey($scriptName)) {
            Write-Host "Skipping already applied migration: $scriptName"
            continue
        }

        Write-Host "Applying migration: $scriptName"

        $checksum = Get-MigrationChecksum -FilePath $migrationFile.FullName

        Invoke-MariaDbSqlFile -FilePath $migrationFile.FullName

        $escapedScriptName = $scriptName.Replace("'", "''")

        Invoke-MariaDbQuery @"
INSERT INTO schemaversion (scriptName, checksum)
VALUES ('$escapedScriptName', '$checksum');
"@ | Out-Null

        Write-Host "Applied migration: $scriptName"
        $appliedCount++
    }

    # --- COMPLETE ----------------------------------------------------------

    if ($appliedCount -eq 0) {
        Write-Host "No new migrations to apply."
    }
    else {
        Write-Host "Applied $appliedCount migration(s)."
    }

    Write-Host "MariaDB migration runner completed successfully."
}
finally {
    Remove-Item Env:\MYSQL_PWD -ErrorAction SilentlyContinue
}