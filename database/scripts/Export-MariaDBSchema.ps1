$ErrorActionPreference = "Stop"

try {

# --- PRECONDITIONS -----------------------------------------------------------
$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Set-Location $RepoRoot

# --- TOOL PATHS (deterministic, no PATH dependency) --------------------------

if ($IsWindows) {
  $MariaDbExe = "C:\Program Files\MariaDB 10.11\bin\mariadb.exe"
  $MariaDbDumpExe = "C:\Program Files\MariaDB 10.11\bin\mariadb-dump.exe"
}
else {
  $MariaDbExe = "mariadb"
  $MariaDbDumpExe = "mariadb-dump"
}

if (-not (Test-Path $MariaDbExe)) {
  throw "mariadb.exe not found at $MariaDbExe"
}

if (-not (Test-Path $MariaDbDumpExe)) {
  throw "mariadb-dump.exe not found at $MariaDbDumpExe"
}

$MariaDbHost = $env:MARIADB_HOST ?? $env:MYSQL_HOST ?? "localhost"
$MariaDbPort = $env:MARIADB_PORT ?? $env:MYSQL_PORT ?? 3306
$Database = "orchids"
$User = $env:MARIADB_USER
$Password = $env:MARIADB_PASSWORD

if (-not $User -or -not $Password) {
    throw "MARIADB_USER and MARIADB_PASSWORD must be set"
}

$env:MYSQL_PWD = $Password

Write-Host "Using DB user: $User"

if (-not $User -or -not $Password) {
  throw "MARIADB_USER or MARIADB_PASSWORD environment variables not set"
}

Write-Host "Starting MariaDB schema export…"
Write-Host "Server: ${MariaDbHost}:${MariaDbPort}"
Write-Host "Database: $Database"

$SchemaRoot = Resolve-Path "database/schema"
$ChecksumFile = "database/checksums/schema.json"

New-Item -ItemType Directory -Force -Path `
  "$SchemaRoot/tables",
"$SchemaRoot/constraints",
"$SchemaRoot/views",
"$SchemaRoot/routines",
"$SchemaRoot/triggers",
"database/checksums" | Out-Null

# --- HELPERS ----------------------------------------------------------------
function Invoke-MariaDbQuery {
    param (
        [Parameter(Mandatory)]
        [string]$Query
    )

  $compoundQuery = @"
SET SESSION lock_wait_timeout = 5;
$Query
"@

  Write-Host "Connecting to MariaDB (timeout 5s)…"

  $output = & $MariaDbExe `
    --protocol=TCP `
    --host=$MariaDbHost `
    --port=$MariaDbPort `
    --user=$User `
    --connect-timeout=5 `
    --batch `
    --skip-column-names `
    --database=$Database `
    --execute="$compoundQuery" `
    2>&1

  if ($LASTEXITCODE -ne 0) {
      Write-Host "---- MariaDB ERROR OUTPUT ----" -ForegroundColor Red
      $output | ForEach-Object { Write-Host $_ -ForegroundColor Red }
      Write-Host "--------------------------------" -ForegroundColor Red

      throw "MariaDB command failed (exit code $LASTEXITCODE)"
  }

  return $output
}

function Get-Checksum($Content) {
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($Content)
  (Get-FileHash -InputStream ([IO.MemoryStream]::new($bytes)) -Algorithm SHA256).Hash
}

function New-DirectoryForFile {
    param (
        [Parameter(Mandatory)]
        [string]$FilePath
    )

    $dir = Split-Path $FilePath
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir | Out-Null
    }
}

function Format-SqlContent {
  param(
    [Parameter(Mandatory)]
    [string]$Sql
  )

  $Sql = $Sql -replace '(?is)\bDEFINER\s*=\s*`[^`]+`\s*@\s*`[^`]+`\s*', ''
  $Sql = $Sql -replace 'AUTO_INCREMENT=\d+', ''

  $Sql = $Sql -replace '(?ms)/\*![0-9]+.*?\*/', ''
  $Sql = $Sql -replace '(?ms)/\*M![0-9]+.*?\*/', ''
  $Sql = $Sql -replace '(?m)^\s*/\*.*?\*/\s*$', ''

  $Sql = $Sql -replace '(?m)^\s*SET\s+.*?;\s*$', ''

  $Sql = $Sql -replace '(?m)^\s*LOCK TABLES.*$', ''
  $Sql = $Sql -replace '(?m)^\s*UNLOCK TABLES.*$', ''
  $Sql = $Sql -replace '(?m)^\s*COMMIT;.*$', ''

  $Sql = $Sql -replace '(?m)^\s*(;\s*)+$', ''
  $Sql = $Sql -replace '(?ms)(?:^\s*;\s*$\r?\n?)+', ''

  $Sql = $Sql -replace "(\r?\n){3,}", "`n`n"

  return ($Sql.Trim() + "`n")
}

function Remove-DatabaseQualification {
  param(
    [Parameter(Mandatory)]
    [string]$Sql
  )

  $dbPattern = [regex]::Escape($Database)

  # Remove `orchids`.
  $Sql = $Sql -replace "``$dbPattern``\.", ''

  # Remove orchids.
  $Sql = $Sql -replace "(?i)\b$dbPattern\.", ''

  return $Sql
}

# --- LOAD EXISTING CHECKSUMS -------------------------------------------------
$Checksums = @{}
if (Test-Path $ChecksumFile) {
  $json = Get-Content $ChecksumFile -Raw | ConvertFrom-Json
  foreach ($p in $json.PSObject.Properties) {
    $Checksums[$p.Name] = $p.Value
  }
}

$SeenObjects = @{}

# --- EXPORT LOGIC ------------------------------------------------------------
function Export-Object {
  param (
    [string]$Type,
    [string]$Name,
    [string]$OutPath,
    [string[]]$DumpArgs
  )

  $dumpExe = $MariaDbDumpExe
  $dumpArgs = @(
    "--host=$MariaDbHost"
    "--port=$MariaDbPort"
    "--user=$User"
    "--skip-dump-date"
    "--skip-comments"
    "--single-transaction"
  )

  # Force schema-only for tables (never trust caller)
  if ($Type -eq "tables") {
    $dumpArgs += @(
      "--no-data",
      "--skip-add-drop-table"
    )
  }
  elseif ($DumpArgs) {
    $dumpArgs += $DumpArgs
  }

  $dumpArgs += @(
    $Database
    $Name
  )

  $sql = & $dumpExe @dumpArgs 2>&1

  if ($LASTEXITCODE -ne 0) {
      throw "mariadb-dump failed for $Type $Name"
  }

  if (-not $sql) {
      throw "mariadb-dump returned empty output for $Type $Name"
  }

  $sql = ($sql -join "`n")

if ($Type -eq "views") {

  $result = Invoke-MariaDbQuery "SHOW CREATE VIEW ``$Database``.``$Name``;"

  if (-not $result) {
    throw "Failed to read definition for view $Name"
  }

  $resultText = ($result -join "`n")

  # Extract CREATE VIEW
  $m = [regex]::Match(
    $resultText,
    '(?is)\bCREATE\b.*?\bVIEW\b'
  )

  if (-not $m.Success) {
    throw "Could not find CREATE VIEW for $Name. Raw output: [$resultText]"
  }

  $definition = $resultText.Substring($m.Index)

  # Strip DEFINER clause
  $definition = $definition -replace '(?is)\bDEFINER\s*=\s*`[^`]+`\s*@\s*`[^`]+`\s*', ''

  # Remove ALGORITHM and SQL SECURITY noise
  $definition = $definition -replace '(?i)\s+ALGORITHM\s*=\s*\w+', ''
  $definition = $definition -replace '(?i)\s+SQL\s+SECURITY\s+\w+', ''

  # Force idempotency
  $definition = $definition -replace '^(?i)CREATE\s+', 'CREATE OR REPLACE '

  # Remove trailing charset/collation junk
  $definition = $definition -replace '(?is)\s+(utf8mb4|utf8|latin1)\s+(utf8mb4_[^\s]+|utf8_[^\s]+|latin1_[^\s]+)\s*$', ''

  # Normalise whitespace
  $definition = $definition -replace "\s+", " "

  # Restore line break before AS SELECT for readability
  $definition = $definition -replace '\s+AS\s+', "`nAS "

  # --- NEW: normalise SQL keywords (deterministic casing) ---
  $definition = $definition -replace '(?i)\bselect\b', 'SELECT'
  $definition = $definition -replace '(?i)\bfrom\b', 'FROM'
  $definition = $definition -replace '(?i)\bwhere\b', 'WHERE'
  $definition = $definition -replace '(?i)\bas\b', 'AS'

  # Final tidy
  $definition = $definition.Trim() + "`n"

  $sql = $definition
}
  else {
if ($Type -eq "tables") {

    # Ensure idempotent create
    $sql = $sql -replace 'CREATE TABLE `', 'CREATE TABLE IF NOT EXISTS `'

    # Remove ALL indexes that include FK columns
    if ($fkColumnMap.ContainsKey($Name)) {

        # Get FK columns for this table
        $fkColumns = @()

        foreach ($fkCols in $fkColumnMap[$Name]) {
            $fkColumns += ($fkCols -split "," | ForEach-Object { $_.Trim() })
        }

        $fkColumns = $fkColumns | Sort-Object -Unique

        # Remove any KEY that references any FK column
        $sql = [regex]::Replace($sql, '(?ms),?\s*KEY\s+`[^`]+`\s*\(([^)]*)\)', {
            param($match)

            $cols = $match.Groups[1].Value

            foreach ($fkCol in $fkColumns) {
                if ($cols -match "``$([regex]::Escape($fkCol))``") {
                    return ''   # REMOVE the entire KEY
                }
            }

            return $match.Value
        })
    }

    # Remove FOREIGN KEY constraints completely
    $sql = $sql -replace '(?ms),?\s*CONSTRAINT\s+`[^`]+`\s+FOREIGN\s+KEY\s*\([^\)]*\)\s+REFERENCES\s+`[^`]+`\s*\([^\)]*\)\s*(?:ON\s+DELETE\s+\w+\s*)?(?:ON\s+UPDATE\s+\w+\s*)?', ''
    $sql = $sql -replace '(?ms),?\s*FOREIGN\s+KEY\s*\([^\)]*\)\s+REFERENCES\s+`[^`]+`\s*\([^\)]*\)\s*(?:ON\s+DELETE\s+\w+\s*)?(?:ON\s+UPDATE\s+\w+\s*)?', ''

    # Remove dump artefacts
    $sql = $sql -replace '(?m)^DROP TABLE IF EXISTS.*$', ''
    $sql = $sql -replace '(?m)^LOCK TABLES.*$', ''
    $sql = $sql -replace '(?m)^UNLOCK TABLES.*$', ''
    $sql = $sql -replace '(?m)^INSERT INTO.*$', ''
    $sql = $sql -replace '(?m)^COMMIT;.*$', ''
    $sql = $sql -replace '(?m)^SET .*$', ''

    # Remove charset / collation noise
    $sql = $sql -replace 'DEFAULT CHARSET=\w+', ''
    $sql = $sql -replace 'COLLATE=\w+', ''

    # Cleanup after removals
    $sql = $sql -replace '(?i)\bACTION\s+ON\s+UPDATE\s+NO\s+ACTION\b', ''
    $sql = $sql -replace '(?i)\bON\s+UPDATE\s+NO\s+ACTION\b', ''
    $sql = $sql -replace '(?i)\bON\s+DELETE\s+NO\s+ACTION\b', ''
    $sql = $sql -replace '(?m)^\s*UNIQUE\s*,\s*$', ''
    $sql = $sql -replace ',\s*\)', ')'
    $sql = $sql -replace '(?m)^\s*(;\s*)+$', ''

    # Formatting
    $sql = $sql -replace '\)\s*ENGINE=InnoDB\s*', "`n) ENGINE=InnoDB"
    $sql = $sql -replace "(\r?\n){3,}", "`n`n"

    # Final tidy
    $sql = $sql.Trim()
}

  # Apply shared normalisation
  $sql = Format-SqlContent -Sql $sql
    }

  $hash = Get-Checksum $sql
  $key = "$Type/$Name"
  $SeenObjects[$key] = $true

  if (-not (Test-Path $OutPath) -or $Checksums[$key] -ne $hash) {
    New-DirectoryForFile $OutPath
    $sql | Out-File -Encoding utf8NoBOM $OutPath
    $Checksums[$key] = $hash
    Write-Host "Updated $key"
  }
}

# --- DISCOVER & EXPORT ------------------------------------------------------
Write-Host "Reading database metadata…"
$fkColumnMap = @{}

$fkRows = Invoke-MariaDbQuery @"
SELECT
    TABLE_NAME,
    GROUP_CONCAT(COLUMN_NAME ORDER BY ORDINAL_POSITION SEPARATOR ',') AS Columns
FROM information_schema.KEY_COLUMN_USAGE
WHERE TABLE_SCHEMA = '$Database'
  AND REFERENCED_TABLE_NAME IS NOT NULL
GROUP BY TABLE_NAME, CONSTRAINT_NAME
ORDER BY TABLE_NAME;
"@

foreach ($row in $fkRows) {
    if ([string]::IsNullOrWhiteSpace($row)) { continue }

    $parts = $row -split "`t"

    if ($parts.Count -lt 2) {
        throw "Unexpected FK metadata row: $row"
    }

    $table = $parts[0]
    $cols  = $parts[1]

    if (-not $fkColumnMap.ContainsKey($table)) {
        $fkColumnMap[$table] = @()
    }

    $fkColumnMap[$table] += $cols
}

# --- Tables -----------------------------------------------------------------
$tables = Invoke-MariaDbQuery @"
SELECT TABLE_NAME
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = '$Database'
  AND TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_NAME;
"@

Write-Host "Exporting tables…"

foreach ($t in $tables) {
  $outPath = Join-Path $SchemaRoot "tables\$t.sql"
  Export-Object "tables" $t $outPath @("--no-data", "--skip-add-drop-table")
}

# --- Constraints ------------------------------------------------------------
$constraintRows = Invoke-MariaDbQuery @"
SELECT
  kcu.CONSTRAINT_NAME,
  kcu.TABLE_NAME,
  kcu.COLUMN_NAME,
  kcu.REFERENCED_TABLE_NAME,
  kcu.REFERENCED_COLUMN_NAME,
  rc.UPDATE_RULE,
  rc.DELETE_RULE,
  kcu.ORDINAL_POSITION
FROM information_schema.KEY_COLUMN_USAGE kcu
JOIN information_schema.REFERENTIAL_CONSTRAINTS rc
  ON rc.CONSTRAINT_NAME = kcu.CONSTRAINT_NAME
 AND rc.CONSTRAINT_SCHEMA = kcu.CONSTRAINT_SCHEMA
WHERE kcu.TABLE_SCHEMA = '$Database'
  AND kcu.REFERENCED_TABLE_NAME IS NOT NULL
ORDER BY
  kcu.CONSTRAINT_NAME,
  kcu.ORDINAL_POSITION;
"@

$constraints = @{}

foreach ($row in $constraintRows) {
  $parts = $row -split "`t"
  $name = $parts[0]

  if (-not $constraints.ContainsKey($name)) {
    $constraints[$name] = @()
  }

  $constraints[$name] += , $parts
}

foreach ($constraintName in ($constraints.Keys | Sort-Object)) {
  $rows = $constraints[$constraintName]
  $fileConstraintName = $constraintName.TrimStart('/') -replace '[\\/:*?"<>|]', '_'

  $tableName = $rows[0][1]
  $refTableName = $rows[0][3]

  $tableQualified = "``$tableName``"
  $refTableQualified = "``$refTableName``"

  $onUpdate = $rows[0][5]
  $onDelete = $rows[0][6]

  $columns = ($rows | ForEach-Object { "``$($_[2])``" }) -join ", "
  $refColumns = ($rows | ForEach-Object { "``$($_[4])``" }) -join ", "

  $sql = @"
ALTER TABLE $tableQualified
  ADD FOREIGN KEY ($columns)
  REFERENCES $refTableQualified ($refColumns)
  ON DELETE $onDelete
  ON UPDATE $onUpdate;
"@

  $sql = $sql.Trim() + "`n"

  $key = "constraints/$fileConstraintName"
  $hash = Get-Checksum $sql
  $SeenObjects[$key] = $true

  $outPath = Join-Path "$SchemaRoot/constraints" "$fileConstraintName.sql"

  if (-not (Test-Path $OutPath) -or $Checksums[$key] -ne $hash) {
    New-DirectoryForFile $outPath
    $sql | Out-File -Encoding utf8NoBOM $outPath
    $Checksums[$key] = $hash
    Write-Host "Updated $key"
  }
}

# --- Views ------------------------------------------------------------------
$views = Invoke-MariaDbQuery @"
SELECT TABLE_NAME
FROM information_schema.VIEWS
WHERE TABLE_SCHEMA = '$Database'
ORDER BY TABLE_NAME;
"@

Write-Host "Exporting views…"

foreach ($v in $views) {
  $outPath = Join-Path $SchemaRoot "views\$v.sql"
  Export-Object "views" $v $outPath $null
}

# --- Routines ---------------------------------------------------------------
Write-Host "Exporting routines..."

$routines = Invoke-MariaDbQuery @"
SELECT ROUTINE_NAME, ROUTINE_TYPE
FROM information_schema.ROUTINES
WHERE ROUTINE_SCHEMA = '$Database'
ORDER BY ROUTINE_TYPE, ROUTINE_NAME;
"@

foreach ($row in $routines) {
  $parts = $row -split "`t"
  $name  = $parts[0]
  $type  = $parts[1]

  Write-Host "  $type $name"

  $result = Invoke-MariaDbQuery "SHOW CREATE $type ``$Database``.``$name``;"

  if (-not $result) {
    throw "    Failed to read definition for $type $name"
    continue
  }

  $resultText = ($result -join "`n")

  $pattern = if ($type -eq "PROCEDURE") {
    '(?is)\bCREATE\b.*?\bPROCEDURE\b'
  } else {
    '(?is)\bCREATE\b.*?\bFUNCTION\b'
  }

  $m = [regex]::Match($resultText, $pattern)

  if (-not $m.Success) {
    throw "Exported definition for $type ${name} does not contain a CREATE $type statement. Raw output was: [$resultText]"
  }

  $definition = $resultText.Substring($m.Index)
  $definition = $definition -replace '^(?i)CREATE\s+', 'CREATE OR REPLACE '
  $definition = $definition -replace '(?is)\bDEFINER\s*=\s*`[^`]+`\s*@\s*`[^`]+`\s*', ''
  $definition = $definition -replace '\\r\\n', "`n"
  $definition = $definition -replace '\\n', "`n"
  $definition = $definition -replace '\\t', "`t"
  # Remove charset / collation noise
  $definition = $definition -replace '(?i)\s+CHARSET\s+\w+', ''
  $definition = $definition -replace '(?i)\s+COLLATE\s+\w+', ''

  # Collapse excessive blank lines (deterministic formatting)
  $definition = $definition -replace "(`r?`n){3,}", "`n`n"

  # Trim trailing whitespace on each line
  $definition = ($definition -split "`n" | ForEach-Object { $_.TrimEnd() }) -join "`n"

  $endMatch = [regex]::Match(
    $definition,
    '(?is)\bEND\b',
    [System.Text.RegularExpressions.RegexOptions]::RightToLeft
  )

  if (-not $endMatch.Success) {
    throw "Could not locate END for $type ${name}"
  }

  $definition = $definition.Substring(0, $endMatch.Index + 3)
  $definition = $definition.Trim() + "`n"
  $definition = "DELIMITER //`n$definition//`nDELIMITER ;`n"

  $key = "routines/$name"
  $relativePath = "$key.sql"
  $outPath = Join-Path $SchemaRoot $relativePath

  $hash = Get-Checksum $definition
  $SeenObjects[$key] = $true

  if (-not (Test-Path $OutPath) -or $Checksums[$key] -ne $hash) {
    New-DirectoryForFile $outPath
    $definition | Out-File -Encoding utf8NoBOM $outPath
    $Checksums[$key] = $hash
    Write-Host "    Updated $relativePath"
  }
}

# --- Triggers ---------------------------------------------------------------
Write-Host "Exporting triggers..."

$triggers = Invoke-MariaDbQuery @"
SELECT TRIGGER_NAME
FROM information_schema.TRIGGERS
WHERE TRIGGER_SCHEMA = '$Database'
ORDER BY TRIGGER_NAME;
"@

foreach ($row in $triggers) {
  $name = $row.Trim()
  Write-Host "  TRIGGER $name"

  $result = Invoke-MariaDbQuery "SHOW CREATE TRIGGER ``$Database``.``$name``;"

  if (-not $result) {
    throw "Failed to read definition for trigger $name"
  }

  $resultText = ($result -join "`n")

  $m = [regex]::Match(
    $resultText,
    '(?is)\bCREATE\b\s+(?:DEFINER\s*=\s*`[^`]+`\s*@\s*`[^`]+`\s+)?TRIGGER\b'
  )

  if (-not $m.Success) {
    throw "Exported definition for trigger $name does not contain CREATE TRIGGER. Raw output: [$resultText]"
  }

  $definition = $resultText.Substring($m.Index)
  $definition = $definition.TrimStart()
  $definition = $definition -replace '(?is)\bDEFINER\s*=\s*`[^`]+`\s*@\s*`[^`]+`\s*', ''
  $definition = $definition -replace '\\r\\n', "`n"
  $definition = $definition -replace '\\n', "`n"
  $definition = $definition -replace '\\t', "`t"
  $definition = Remove-DatabaseQualification -Sql $definition

  $finalEnd = [regex]::Match(
    $definition,
    '(?is)\bEND\b\s*(?:$|utf8mb4|utf8|latin1|collation|character set)',
    [System.Text.RegularExpressions.RegexOptions]::RightToLeft
  )

  if (-not $finalEnd.Success) {
    $finalEnd = [regex]::Match(
      $definition,
      '(?is)\bEND\b\s*$',
      [System.Text.RegularExpressions.RegexOptions]::RightToLeft
    )
  }

  if (-not $finalEnd.Success) {
    throw "Could not locate final END for trigger $name"
  }

  $definition = $definition.Substring(0, $finalEnd.Index) + "END"
  $definition = $definition.Trim()

  $definition = @"
DELIMITER //

DROP TRIGGER IF EXISTS ``$name``//

$definition//

DELIMITER ;
"@

  $key = "triggers/$name"
  $outPath = Join-Path $SchemaRoot "$key.sql"

  $hash = Get-Checksum $definition
  $SeenObjects[$key] = $true

  if (-not (Test-Path $OutPath) -or $Checksums[$key] -ne $hash) {
    New-DirectoryForFile $outPath
    $definition | Out-File -Encoding utf8NoBOM $outPath
    $Checksums[$key] = $hash
    Write-Host "    Updated $key"
  }
}

# --- Write checksum file deterministically ----------------------------------
$Ordered = [ordered]@{}
foreach ($k in ($Checksums.Keys | Sort-Object)) {
  $Ordered[$k] = $Checksums[$k]
}

$NewJson = ($Ordered | ConvertTo-Json -Depth 3).Trim()

if (-not (Test-Path $ChecksumFile) -or (Get-Content $ChecksumFile -Raw).Trim() -ne $NewJson) {
  New-DirectoryForFile $ChecksumFile
  $NewJson | Out-File $ChecksumFile -Encoding utf8NoBOM
  Write-Host "Checksum file updated"
}

# --- Remove schema objects that no longer exist in the DB -------------------

# SAFETY: ensure discovery worked before allowing deletions
if (-not $tables -or $tables.Count -eq 0) {
  throw "Table discovery failed — aborting cleanup to prevent accidental deletions"
}

foreach ($dir in @("tables", "constraints", "views", "routines", "triggers")) {

  $path = Join-Path $SchemaRoot $dir
  if (-not (Test-Path $path)) { continue }

  Get-ChildItem $path -Filter *.sql | ForEach-Object {

    $key = "$dir/$($_.BaseName)"

    # SAFETY: never auto-delete tables unless explicitly enabled
    if ($dir -eq "tables") {
      Write-Warning "Skipping deletion check for tables/$($_.BaseName) (safety guard)"
      return
    }

    if (-not $SeenObjects.ContainsKey($key)) {

      Write-Host "Removed $key (no longer exists in DB)"

      Remove-Item $_.FullName -Force

      if ($Checksums.ContainsKey($key)) {
        $Checksums.Remove($key)
      }
    }
  }
}

Write-Host "MariaDB schema export completed successfully."

}
finally {
    Remove-Item Env:\MYSQL_PWD -ErrorAction SilentlyContinue
}
