$ErrorActionPreference = "Stop"

# --- Preconditions -----------------------------------------------------------

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

  $sql = $sql `
    -replace 'DEFINER=`[^`]+`@`[^`]+`', '' `
    -replace 'AUTO_INCREMENT=\d+', ''

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

# Tables
$tables = Invoke-MySqlQuery @"
SELECT TABLE_NAME
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = '$Database'
  AND TABLE_TYPE = 'BASE TABLE';
"@

foreach ($t in $tables) {
  Export-Object "tables" $t "$SchemaRoot/tables/$t.sql" "--no-data"
}

# Views
$views = Invoke-MySqlQuery @"
SELECT TABLE_NAME
FROM information_schema.VIEWS
WHERE TABLE_SCHEMA = '$Database';
"@

foreach ($v in $views) {
  Export-Object "views" $v "$SchemaRoot/views/$v.sql" "--no-data"
}

# Routines
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

# --- Warn about removed objects ---------------------------------------------

foreach ($dir in @("tables", "views", "routines")) {
  $path = Join-Path $SchemaRoot $dir
  if (-not (Test-Path $path)) { continue }

  Get-ChildItem $path -Filter *.sql | ForEach-Object {
    $key = "$dir/$($_.BaseName)"
    if (-not $SeenObjects.ContainsKey($key)) {
      Write-Warning "Schema object no longer exists in DB: $key"
    }
  }
}
