$ErrorActionPreference = "Stop"

try {

# --- PRECONDITIONS -----------------------------------------------------------
$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Set-Location $RepoRoot

foreach ($cmd in @("mysql", "mysqldump")) {
  if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
    throw "$cmd not found in PATH"
  }
}

$MySqlHost = $env:MYSQL_HOST ?? "localhost"
$MySqlPort = $env:MYSQL_PORT ?? 3306
$Database = "orchids"
$User = $env:MYSQL_USER
$Password = $env:MYSQL_PASSWORD
$env:MYSQL_PWD = $Password

if (-not $User -or -not $Password) {
  throw "MYSQL_USER or MYSQL_PASSWORD environment variables not set"
}

Write-Host "Starting MySQL schema export…"
Write-Host "Server: ${MySqlHost}:${MySqlPort}"
Write-Host "Database: $Database"

$SchemaRoot = Resolve-Path "database/schema"
$ChecksumFile = "database/checksums/schema.json"

New-Item -ItemType Directory -Force -Path `
  "$SchemaRoot/tables",
"$SchemaRoot/constraints",
"$SchemaRoot/views",
"$SchemaRoot/routines",
"database/checksums" | Out-Null

# --- HELPERS ----------------------------------------------------------------
function Invoke-MySqlQuery {
    param (
        [Parameter(Mandatory)]
        [string]$Query
    )

  $compoundQuery = @"
SET SESSION lock_wait_timeout = 5;
$Query
"@

Write-Host "Connecting to MySQL (timeout 5s)…"

  $output = & mysql `
    --protocol=TCP `
    --host=$MySqlHost `
    --port=$MySqlPort `
    --user=$User `
    --connect-timeout=5 `
    --batch `
    --skip-column-names `
    --database=$Database `
    --execute="$compoundQuery" `
    2>$null

if ($LASTEXITCODE -ne 0) {
    throw "MySQL command failed (exit code $LASTEXITCODE)"
}

  return $output
}

function Get-Checksum($Content) {
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($Content)
  (Get-FileHash -InputStream ([IO.MemoryStream]::new($bytes)) -Algorithm SHA256).Hash
}

function Ensure-DirectoryForFile {
    param (
        [Parameter(Mandatory)]
        [string]$FilePath
    )

    $dir = Split-Path $FilePath
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir | Out-Null
    }
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
    [string]$DumpArgs
  )

  $mysqldumpArgs = @(
    "--host=$MySqlHost"
    "--port=$MySqlPort"
    "--user=$User"
    "--skip-dump-date"
  )

  if ($Type -ne "views") {
    $mysqldumpArgs += "--skip-comments"
  }

  if ($DumpArgs) {
    $mysqldumpArgs += $DumpArgs
  }

  $mysqldumpArgs += @(
    $Database
    $Name
  )

  $sql = & mysqldump @mysqldumpArgs 2>$null

  if (-not $sql) { return }

  # Join output into single string
  $sql = ($sql -join "`n")

  # ---------------- Views ---------------------------------------------------
  # Views in MySQL dumps do not contain a plain CREATE VIEW statement.
  # The real definition is split across versioned comments.
  # We extract the final VIEW ... AS SELECT and reconstruct a clean CREATE VIEW.
  # The final view definition must be reconstructed from versioned blocks.
  if ($Type -eq "views") {
    # Keep only the final view structure
    if ($sql -notmatch '(?ms)--\s*Final view structure for view.*$') {
      Write-Warning "Final view structure not found for view $Name"
      return
    }

    $sql = $Matches[0]

    # Extract the VIEW ... AS SELECT ... statement
    if ($sql -notmatch '(?ms)/\*![0-9]+\s*VIEW\s+(`[^`]+`\s+AS\s+.*?);?\s*\*/') {
      Write-Warning "VIEW definition not found for view $Name"
      return
    }

    $viewBody = $Matches[1]

    # Reconstruct clean CREATE VIEW
    $sql = "CREATE VIEW $viewBody;"

    # Normalise whitespace
    $sql = $sql.Trim() + "`n"
  }
  else {
    # ---------------- Everything EXCLUDING Constraints ----------------------
    # Normalise noise
    $sql = $sql `
      -replace 'DEFINER=`[^`]+`@`[^`]+`', '' `
      -replace 'AUTO_INCREMENT=\d+', ''

    # Strip FOREIGN KEY constraints from table DDL
    if ($Type -eq "tables") {

      $sql = $sql -replace '(?ms),?\s*CONSTRAINT\s+`[^`]+`\s+FOREIGN\s+KEY\s*\([^\)]*\)\s+REFERENCES\s+`[^`]+`\s*\([^\)]*\)(?:\s+ON\s+DELETE\s+\w+)?(?:\s+ON\s+UPDATE\s+\w+)?', ''

      $sql = $sql -replace '(?ms),?\s*FOREIGN\s+KEY\s*\([^\)]*\)\s+REFERENCES\s+`[^`]+`\s*\([^\)]*\)(?:\s+ON\s+DELETE\s+\w+)?(?:\s+ON\s+UPDATE\s+\w+)?', ''
    }

    # Remove all versioned comments
    $sql = $sql -replace '(?m)^\s*/\*![0-9]+\s.*?\*/\s*;?\s*$', ''

    # Remove mysqldump session SET statements
    $sql = $sql -replace '(?m)^\s*SET\s+@?OLD_.*?;\s*$', ''
    $sql = $sql -replace '(?m)^\s*SET\s+(SQL_MODE|CHARACTER_SET_.*|COLLATION_.*|TIME_ZONE).*?;\s*$', ''

    # Normalise whitespace
    $sql = $sql -replace "(\r?\n){3,}", "`n`n"
    $sql = $sql.Trim() + "`n"
  }
  # ---------------- CHECKSUMS -----------------------------------------------
  # Compare against the last committed checksum to determine whether the
  # generated constraint definition has changed.
  $hash = Get-Checksum $sql
  $key = "$Type/$Name"
  $SeenObjects[$key] = $true

  if ($Checksums[$key] -ne $hash) {
    Ensure-DirectoryForFile $OutPath
    $sql | Out-File -Encoding utf8 $OutPath
    $Checksums[$key] = $hash
    Write-Host "Updated $key"
  }
}

# --- DISCOVER & EXPORT ------------------------------------------------------
Write-Host "Reading database metadata…"
# --- Tables -----------------------------------------------------------------
$tables = Invoke-MySqlQuery @"
SELECT TABLE_NAME
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = '$Database'
  AND TABLE_TYPE = 'BASE TABLE';
"@

Write-Host "Exporting tables…"

foreach ($t in $tables) {
  $outPath = Join-Path $SchemaRoot "tables\$t.sql"
  Export-Object "tables" $t $outPath "--no-data"
}

# --- Constraints ------------------------------------------------------------
$constraintRows = Invoke-MySqlQuery @"
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

foreach ($constraintName in $constraints.Keys) {
  $rows = $constraints[$constraintName]

  # Filesystem-safe constraint name
  $FileConstraintName = $constraintName.TrimStart('/') -replace '[\\/:*?"<>|]', '_'

  # PSScriptAnalyzer SuppressMessage PSAvoidUnusedVariables - Justification: Used in the generated SQL
  # Warning may still appear due to use in a loop
  $table = $rows[0][1]

  # PSScriptAnalyzer SuppressMessage PSAvoidUnusedVariables - Justification: Used in the generated SQL
  # Warning may still appear due to use in a loop
  $refTable = $rows[0][3]

  $onUpdate = $rows[0][5]
  $onDelete = $rows[0][6]

  $columns = ($rows | ForEach-Object { "``$($_[2])``" }) -join ", "
  $refColumns = ($rows | ForEach-Object { "``$($_[4])``" }) -join ", "

  $sql = @"
ALTER TABLE `$table`
  ADD CONSTRAINT `$constraintName`
  FOREIGN KEY ($columns)
  REFERENCES `$refTable` ($refColumns)
  ON DELETE $onDelete
  ON UPDATE $onUpdate;
"@

  # Normalise whitespace 
  $sql = $sql.Trim() + "`n"

  $key = "constraints/$FileConstraintName"
  $hash = Get-Checksum $sql
  $SeenObjects[$key] = $true

  $OutPath = Join-Path "$SchemaRoot/constraints" "$FileConstraintName.sql"

  if ($Checksums[$key] -ne $hash) {
    Ensure-DirectoryForFile $OutPath
    $sql | Out-File -Encoding utf8 $OutPath
    $Checksums[$key] = $hash
    Write-Host "Updated $key"
  }
}

# --- Views ------------------------------------------------------------------
$views = Invoke-MySqlQuery @"
SELECT TABLE_NAME
FROM information_schema.VIEWS
WHERE TABLE_SCHEMA = '$Database';
"@

Write-Host "Exporting views…"

foreach ($v in $views) {
  $outPath = Join-Path $SchemaRoot "views\$v.sql"
  Export-Object "views" $v $outPath $null
}

# --- Routines ---------------------------------------------------------------
$routines = Invoke-MySqlQuery @"
SELECT ROUTINE_NAME
FROM information_schema.ROUTINES
WHERE ROUTINE_SCHEMA = '$Database';
"@

Write-Host "Exporting routines…"

foreach ($r in $routines) {
  $outPath = Join-Path $SchemaRoot "routines\$r.sql"
  Export-Object "routines" $r $outPath "--routines --no-create-info"
}

# --- Write checksum file deterministically ----------------------------------
$Ordered = [ordered]@{}
foreach ($k in ($Checksums.Keys | Sort-Object)) {
  $Ordered[$k] = $Checksums[$k]
}

$NewJson = ($Ordered | ConvertTo-Json -Depth 3).Trim()

if (-not (Test-Path $ChecksumFile) -or (Get-Content $ChecksumFile -Raw).Trim() -ne $NewJson) {
  Ensure-DirectoryForFile $ChecksumFile
  $NewJson | Out-File $ChecksumFile -Encoding utf8
  Write-Host "Checksum file updated"
}

# --- Remove schema objects that no longer exist in the DB -------------------
 
foreach ($dir in @("tables", "constraints", "views", "routines")) {
  $path = Join-Path $SchemaRoot $dir
  if (-not (Test-Path $path)) { continue }

  Get-ChildItem $path -Filter *.sql | ForEach-Object {
    $key = "$dir/$($_.BaseName)"

    if (-not $SeenObjects.ContainsKey($key)) {
      Write-Host "Removed $key (no longer exists in DB)"

      Remove-Item $_.FullName -Force

      if ($Checksums.ContainsKey($key)) {
        $Checksums.Remove($key)
      }
    }
  }
}

Write-Host "MySQL schema export completed successfully."
}
finally {
    Remove-Item Env:\MYSQL_PWD -ErrorAction SilentlyContinue
}