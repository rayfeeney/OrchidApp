$ErrorActionPreference = "Stop"

# --- Preconditions -----------------------------------------------------------

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Set-Location $RepoRoot

foreach ($cmd in @("mysql", "mysqldump")) {
  if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
    throw "$cmd not found in PATH"
  }
}

$MySqlHost = $env:MYSQL_HOST ?? "localhost"
$MySqlPort = $env:MYSQL_PORT ?? 3306
$Database  = "orchids"
$User      = $env:MYSQL_USER
$Password  = $env:MYSQL_PASSWORD

if (-not $User -or -not $Password) {
  throw "MYSQL_USER or MYSQL_PASSWORD environment variables not set"
}

Write-Host "Exporting schema snapshot from ${MySqlHost}:${MySqlPort} as ${User}"

$SchemaRoot   = "database/schema"
$ChecksumFile = "database/checksums/schema.json"

New-Item -ItemType Directory -Force -Path `
  "$SchemaRoot/tables",
  "$SchemaRoot/views",
  "$SchemaRoot/routines",
  "database/checksums" | Out-Null

# --- Helpers ----------------------------------------------------------------

function Invoke-MySqlQuery {
  param ($Query)

  $Query | mysql `
    --protocol=TCP `
    --host=$MySqlHost `
    --port=$MySqlPort `
    --user=$User `
    --password=$Password `
    --batch `
    --skip-column-names `
    $Database
}

function Get-Checksum($Content) {
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($Content)
  (Get-FileHash -InputStream ([IO.MemoryStream]::new($bytes)) -Algorithm SHA256).Hash
}

# --- Load existing checksums -------------------------------------------------

$Checksums = @{}
if (Test-Path $ChecksumFile) {
  $json = Get-Content $ChecksumFile -Raw | ConvertFrom-Json
  foreach ($p in $json.PSObject.Properties) {
    $Checksums[$p.Name] = $p.Value
  }
}

$SeenObjects = @{}

# --- Export logic ------------------------------------------------------------

function Export-Object {
  param (
    [string]$Type,
    [string]$Name,
    [string]$OutPath,
    [string]$DumpArgs
  )

  $sql = & mysqldump `
    --host=$MySqlHost `
    --port=$MySqlPort `
    --user=$User `
    "--password=$Password" `
    $DumpArgs `
    $Database `
    $Name `
    --skip-comments `
    --skip-dump-date 2>$null

  if (-not $sql) { return }

  # Join output into single string
  $sql = ($sql -join "`n")

  # Normalise noise
  $sql = $sql `
    -replace 'DEFINER=`[^`]+`@`[^`]+`', '' `
    -replace 'AUTO_INCREMENT=\d+', ''

  # Strip FOREIGN KEY constraints from table DDL
  if ($Type -eq "tables") {

    # Remove named FK constraints
    $sql = $sql -replace '(?ms),?\s*CONSTRAINT\s+`[^`]+`\s+FOREIGN\s+KEY\s*\([^\)]*\)\s+REFERENCES\s+`[^`]+`\s*\([^\)]*\)(?:\s+ON\s+DELETE\s+\w+)?(?:\s+ON\s+UPDATE\s+\w+)?', ''

    # Remove unnamed FK constraints
    $sql = $sql -replace '(?ms),?\s*FOREIGN\s+KEY\s*\([^\)]*\)\s+REFERENCES\s+`[^`]+`\s*\([^\)]*\)(?:\s+ON\s+DELETE\s+\w+)?(?:\s+ON\s+UPDATE\s+\w+)?', ''
  }

  # Remove MySQL versioned executable comments (entire statements)
  $sql = $sql -replace '(?ms)/\*![0-9]+\s.*?\*/\s*;?', ''

  # Remove mysqldump session SET statements
  $sql = $sql -replace '(?m)^\s*SET\s+@?OLD_.*?;\s*$', ''
  $sql = $sql -replace '(?m)^\s*SET\s+(SQL_MODE|CHARACTER_SET_.*|COLLATION_.*|TIME_ZONE).*?;\s*$', ''

  # Normalise whitespace
  $sql = $sql -replace "(\r?\n){3,}", "`n`n"
  $sql = $sql.Trim()
  $sql = $sql + "`n"

  $hash = Get-Checksum $sql
  $key  = "$Type/$Name"
  $SeenObjects[$key] = $true

  if ($Checksums[$key] -ne $hash) {
    $sql | Out-File -Encoding utf8 $OutPath
    $Checksums[$key] = $hash
    Write-Host "Updated $key"
  }
}

# --- Discover & export -------------------------------------------------------

# --- Tables -------------------------
$tables = Invoke-MySqlQuery @"
SELECT TABLE_NAME
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = '$Database'
  AND TABLE_TYPE = 'BASE TABLE';
"@

foreach ($t in $tables) {
  Export-Object "tables" $t "$SchemaRoot/tables/$t.sql" "--no-data"
}

# --- Constraints --------------------
# $constraintRows = Invoke-MySqlQuery @"
# SELECT
#   kcu.CONSTRAINT_NAME,
#   kcu.TABLE_NAME,
#   kcu.COLUMN_NAME,
#   kcu.REFERENCED_TABLE_NAME,
#   kcu.REFERENCED_COLUMN_NAME,
#   rc.UPDATE_RULE,
#   rc.DELETE_RULE,
#   kcu.ORDINAL_POSITION
# FROM information_schema.KEY_COLUMN_USAGE kcu
# JOIN information_schema.REFERENTIAL_CONSTRAINTS rc
#   ON rc.CONSTRAINT_NAME = kcu.CONSTRAINT_NAME
#  AND rc.CONSTRAINT_SCHEMA = kcu.CONSTRAINT_SCHEMA
# WHERE kcu.TABLE_SCHEMA = '$Database'
#   AND kcu.REFERENCED_TABLE_NAME IS NOT NULL
# ORDER BY
#   kcu.CONSTRAINT_NAME,
#   kcu.ORDINAL_POSITION;
# "@

# $constraints = @{}

# foreach ($row in $constraintRows) {
#   $parts = $row -split "`t"
#   $name  = $parts[0]

#   if (-not $constraints.ContainsKey($name)) {
#     $constraints[$name] = @()
#   }

#   $constraints[$name] += ,$parts
# }

# $constraintDir = "$SchemaRoot/constraints"
# New-Item -ItemType Directory -Force -Path $constraintDir | Out-Null

# foreach ($constraintName in $constraints.Keys) {
#   $rows = $constraints[$constraintName]

#   $table       = $rows[0][1]
#   $refTable    = $rows[0][3]
#   $onUpdate    = $rows[0][5]
#   $onDelete    = $rows[0][6]

#   $columns     = $rows | ForEach-Object { "``$($_[2])``" } -join ", "
#   $refColumns  = $rows | ForEach-Object { "``$($_[4])``" } -join ", "

#   $sql = @"
# ALTER TABLE `$table`
#   ADD CONSTRAINT `$constraintName`
#   FOREIGN KEY ($columns)
#   REFERENCES `$refTable` ($refColumns)
#   ON DELETE $onDelete
#   ON UPDATE $onUpdate;
# "@

#   $path = "$constraintDir/$constraintName.sql"

#   $hash = Get-Checksum $sql
#   $key  = "constraints/$constraintName"
#   $SeenObjects[$key] = $true

#   if ($Checksums[$key] -ne $hash) {
#     $sql | Out-File -Encoding utf8 $path
#     $Checksums[$key] = $hash
#     Write-Host "Updated constraints/$constraintName"
#   }
# }

# --- Views --------------------------
$views = Invoke-MySqlQuery @"
SELECT TABLE_NAME
FROM information_schema.VIEWS
WHERE TABLE_SCHEMA = '$Database';
"@

foreach ($v in $views) {
  Export-Object "views" $v "$SchemaRoot/views/$v.sql" "--no-data"
}

# --- Routines -----------------------
$routines = Invoke-MySqlQuery @"
SELECT ROUTINE_NAME
FROM information_schema.ROUTINES
WHERE ROUTINE_SCHEMA = '$Database';
"@

foreach ($r in $routines) {
  Export-Object "routines" $r "$SchemaRoot/routines/$r.sql" "--routines --no-create-info"
}

# --- Write checksum file deterministically ----------------------------------

$Ordered = [ordered]@{}
foreach ($k in ($Checksums.Keys | Sort-Object)) {
  $Ordered[$k] = $Checksums[$k]
}

$NewJson = ($Ordered | ConvertTo-Json -Depth 3).Trim()

if (-not (Test-Path $ChecksumFile) -or (Get-Content $ChecksumFile -Raw).Trim() -ne $NewJson) {
  $NewJson | Out-File $ChecksumFile -Encoding utf8
  Write-Host "Checksum file updated"
}

# --- Remove schema objects that no longer exist in the DB -------------------
 
foreach ($dir in @("tables", "views", "routines")) {
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

