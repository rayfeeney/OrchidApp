param (
    [string]$MigrationFolder = "database/migrations"
)

$ErrorActionPreference = "Stop"

try {
    Write-Host "Starting MariaDB migration runner..."

    if (-not $env:MARIADB_USER) {
        throw "Environment not configured. Set MARIADB_* variables before running."
    }

    # --- RESOLVE MIGRATION FOLDER ------------------------------------------

    $MigrationFolder = (Resolve-Path $MigrationFolder).Path
    Write-Host "Migration folder: $MigrationFolder"

    # --- TOOL PATHS ---------------------------------------------------------

    if ($IsWindows) {
        $MariaDbExe = "C:\Program Files\MariaDB 10.11\bin\mariadb.exe"
    }
    else {
        $MariaDbExe = "mariadb"
    }

    if ($IsWindows -and -not (Test-Path $MariaDbExe)) {
        throw "mariadb.exe not found at $MariaDbExe"
    }

    # --- CONNECTION SETTINGS ------------------------------------------------

    $MariaDbHost = $env:MARIADB_HOST ?? "localhost"
    $MariaDbPort = $env:MARIADB_PORT ?? 3306
    $Database    = $env:MARIADB_DATABASE ?? "orchids"
    $User        = $env:MARIADB_USER
    $Password    = $env:MARIADB_PASSWORD

    if (-not $User -or -not $Password) {
        throw "MARIADB_USER and MARIADB_PASSWORD must be set"
    }

    # --- CREATE CREDENTIAL FILE --------------------------------------------

    $credFile = [System.IO.Path]::GetTempFileName()

    [System.IO.File]::WriteAllText(
        $credFile,
@"
[client]
user=$User
password=$Password
host=$MariaDbHost
port=$MariaDbPort
database=$Database
"@,
        [System.Text.Encoding]::UTF8
    )

    if (-not $IsWindows) {
        chmod 600 $credFile
    }

    Write-Host "Using DB user: $User"
    Write-Host "Server: ${MariaDbHost}:${MariaDbPort}"
    Write-Host "Database: $Database"

    # --- HELPERS ------------------------------------------------------------

    function Invoke-MariaDbQuery {
        param ([Parameter(Mandatory)][string]$Query)

        $output = & $MariaDbExe `
            "--defaults-extra-file=$credFile" `
            --protocol=TCP `
            --connect-timeout=5 `
            --batch `
            --skip-column-names `
            --execute="$Query" `
            2>&1

        $exitCode = $LASTEXITCODE

        if ($exitCode -ne 0) {
            Write-Host "---- MariaDB ERROR OUTPUT ----" -ForegroundColor Red
            $output | ForEach-Object { Write-Host $_ -ForegroundColor Red }
            Write-Host "--------------------------------" -ForegroundColor Red
            throw "MariaDB command failed (exit code $exitCode)"
        }

        return $output
    }

    function Invoke-MariaDbSqlFile {
        param ([Parameter(Mandatory)][string]$FilePath)

        if (-not (Test-Path $FilePath)) {
            throw "SQL file not found: $FilePath"
        }

        $normalizedPath = $FilePath -replace '\\', '/'

        $sql = @"
SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;
source $normalizedPath;
"@

        $output = & $MariaDbExe `
            "--defaults-extra-file=$credFile" `
            --protocol=TCP `
            --connect-timeout=5 `
            --default-character-set=utf8mb4 `
            --execute="$sql" `
            2>&1

        $exitCode = $LASTEXITCODE

        if ($exitCode -ne 0) {
            Write-Host "---- MariaDB ERROR OUTPUT ----" -ForegroundColor Red
            $output | ForEach-Object { Write-Host $_ -ForegroundColor Red }
            Write-Host "--------------------------------" -ForegroundColor Red
            throw "Migration failed while executing file: $FilePath"
        }
    }

    function Get-MigrationChecksum {
        param ([Parameter(Mandatory)][string]$FilePath)

        return (Get-FileHash -Path $FilePath -Algorithm SHA256).Hash.ToLowerInvariant()
    }

    # --- ENSURE SCHEMAVERSION TABLE ----------------------------------------

    Write-Host "Ensuring schemaversion table exists..."

    Invoke-MariaDbQuery @"
CREATE TABLE IF NOT EXISTS schemaversion (
    scriptName VARCHAR(255) NOT NULL PRIMARY KEY,
    checksum CHAR(64) NOT NULL,
    appliedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
"@ | Out-Null

    # --- READ APPLIED MIGRATIONS -------------------------------------------

    Write-Host "Reading applied migrations..."

    $appliedRows = @(Invoke-MariaDbQuery @"
SELECT scriptName, checksum
FROM schemaversion
ORDER BY scriptName;
"@)

    $appliedMigrations = @{}

    foreach ($row in $appliedRows) {
        if ([string]::IsNullOrWhiteSpace($row)) { continue }

        $parts = $row -split "`t"
        $appliedMigrations[$parts[0]] = if ($parts.Count -ge 2) { $parts[1] } else { "" }
    }

    Write-Host "Applied migrations found: $($appliedMigrations.Count)"

    # --- COLLECT MIGRATION FILES -------------------------------------------

    $migrationFiles = @(Get-ChildItem -Path $MigrationFolder -Filter "*.sql" -File | Sort-Object Name)

    if ($migrationFiles.Count -eq 0) {
        Write-Host "No migration files found."
        exit 0
    }

    # --- APPLY MIGRATIONS ---------------------------------------------------

    $appliedCount = 0

    foreach ($file in $migrationFiles) {
        if ($appliedMigrations.ContainsKey($file.Name)) {
            Write-Host "Skipping: $($file.Name)"
            continue
        }

        Write-Host "Applying: $($file.Name)"

        $checksum = Get-MigrationChecksum $file.FullName

        Invoke-MariaDbSqlFile $file.FullName

        $safeName = $file.Name.Replace("'", "''")

        Invoke-MariaDbQuery @"
INSERT INTO schemaversion (scriptName, checksum)
VALUES ('$safeName', '$checksum');
"@ | Out-Null

        Write-Host "✔ Applied: $($file.Name)"
        $appliedCount++
    }

    if ($appliedCount -eq 0) {
        Write-Host "No new migrations."
    }
    else {
        Write-Host "Applied $appliedCount migration(s)."
    }

    Write-Host "Migration runner completed successfully."
}
finally {
    if ($credFile -and (Test-Path $credFile)) {
        Remove-Item $credFile -ErrorAction SilentlyContinue
    }
}
