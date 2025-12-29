$ErrorActionPreference = "Stop"

# Pre-execute checks
if (-not (Get-Command mysqldump -ErrorAction SilentlyContinue)) {
  throw "mysqldump not found in PATH"
}

if (-not (Get-Command mysql -ErrorAction SilentlyContinue)) {
  throw "mysql not found in PATH"
}

# Config
$MySqlHost = "localhost"
$MySqlPort = 3306
$Database  = "orchids"
$User     = $env:MYSQL_USER
$Password = $env:MYSQL_PASSWORD

if (-not $User -or -not $Password) {
  throw "MYSQL_USER or MYSQL_PASSWORD environment variables not set"
}

$SchemaRoot = "database/schema"
$ChecksumFile = "database/checksums/schema.json"

$mysql     = "mysql"
$mysqldump = "mysqldump"

New-Item -ItemType Directory -Force -Path `
  "$SchemaRoot/tables",
  "$SchemaRoot/views",
  "$SchemaRoot/routines",
  "database/checksums" | Out-Null

# Load existing checksums (as hashtable)
$Checksums = @{}

if (Test-Path $ChecksumFile) {
  $json = Get-Content $ChecksumFile -Raw | ConvertFrom-Json
  foreach ($prop in $json.PSObject.Properties) {
    $Checksums[$prop.Name] = $prop.Value
  }
}

function Get-Checksum($Content) {
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($Content)
  (Get-FileHash -InputStream ([IO.MemoryStream]::new($bytes)) -Algorithm SHA256).Hash
}

# Items previously in Git
$SeenObjects = @{}

function Export-Object {
  param ($Type, $Name, $OutPath, $DumpArgs)

  $sql = & $mysqldump -h $MySqlHost -P $MySqlPort -u $User "-p$Password" `
    $DumpArgs $Database $Name --skip-comments --skip-dump-date 2>$null

  if (-not $sql) { return }

  # Normalise noise
  $sql = $sql `
    -replace 'DEFINER=`[^`]+`@`[^`]+`', '' `
    -replace 'AUTO_INCREMENT=\d+', ''

  $hash = Get-Checksum $sql
  $key = "$Type/$Name"
  $SeenObjects[$key] = $true

  if ($Checksums[$key] -ne $hash) {
    $sql | Out-File -Encoding utf8 $OutPath
    $Checksums[$key] = $hash
    Write-Host "Updated $key"
  }
}

# Tables
$tables = & $mysql -N -B -h $MySqlHost -P $MySqlPort `
  -u $User "-p$Password" $Database `
  -e "SELECT TABLE_NAME FROM information_schema.TABLES 
      WHERE TABLE_SCHEMA = '$Database' 
      AND TABLE_TYPE = 'BASE TABLE'" 2>$null


foreach ($t in $tables) {
  Export-Object "tables" $t "$SchemaRoot/tables/$t.sql" "--no-data"
}

# Views
$views = & $mysql -N -B -h $MySqlHost -P $MySqlPort `
  -u $User "-p$Password" $Database `
  -e "SELECT TABLE_NAME FROM information_schema.VIEWS 
      WHERE TABLE_SCHEMA = '$Database'" 2>$null


foreach ($v in $views) {
  Export-Object "views" $v "$SchemaRoot/views/$v.sql" "--no-data"
}

# Routines
$routines = & $mysql -N -B -h $MySqlHost -P $MySqlPort `
  -u $User "-p$Password" $Database `
  -e "SELECT ROUTINE_NAME FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA = '$Database'" 2>$null

foreach ($r in $routines) {
  Export-Object "routines" $r "$SchemaRoot/routines/$r.sql" "--routines --no-create-info"
}

$Checksums | ConvertTo-Json -Depth 3 | Out-File $ChecksumFile -Encoding utf8

Write-Host ""
#Write-Host "Checking for schema objects present in Git but missing from DB..."

$schemaDirs = @("tables", "views", "routines")

foreach ($dir in $schemaDirs) {
  $path = Join-Path $SchemaRoot $dir
  if (-not (Test-Path $path)) { continue }

  Get-ChildItem $path -Filter *.sql | ForEach-Object {
    $name = [IO.Path]::GetFileNameWithoutExtension($_.Name)
    $key = "$dir/$name"

    if (-not $SeenObjects.ContainsKey($key)) {
      Write-Warning "Schema drift detected: Object exists in Git but not in DB: $key"
    }
  }
}
