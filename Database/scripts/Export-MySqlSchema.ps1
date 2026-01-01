$ErrorActionPreference = "Stop"

# Pre-execute checks
if (-not (Get-Command mysqldump -ErrorAction SilentlyContinue)) {
  throw "mysqldump not found in PATH"
}

# Config
$MySqlHost = $env:MYSQL_HOST ?? "localhost"
$MySqlPort = $env:MYSQL_PORT ?? 3306
$Database  = "orchids"
$User      = $env:MYSQL_USER
$Password  = $env:MYSQL_PASSWORD

if (-not $User -or -not $Password) {
  throw "MYSQL_USER or MYSQL_PASSWORD environment variables not set"
}

Write-Host "Exporting schema from ${MySqlHost}:${MySqlPort} as ${User}"

$SchemaRoot  = "database/schema"
$ChecksumFile = "database/checksums/schema.json"

New-Item -ItemType Directory -Force -Path `
  "$SchemaRoot/tables",
  "$SchemaRoot/views",
  "$SchemaRoot/routines",
  "database/checksums" | Out-Null

# Load existing checksums
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

$SeenObjects = @{}

function Export-Object {
  param ($Type, $Name, $OutPath, $DumpArgs)

  $sql = & mysqldump `
    -h $MySqlHost `
    -P $MySqlPort `
    -u $User `
    "-p$Password" `
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

# Export schema objects (Git-driven)
$schemaDirs = @{
  tables   = "$SchemaRoot/tables"
  views    = "$SchemaRoot/views"
  routines = "$SchemaRoot/routines"
}

foreach ($type in $schemaDirs.Keys) {
  $dir = $schemaDirs[$type]
  if (-not (Test-Path $dir)) { continue }

  Get-ChildItem $dir -Filter *.sql | ForEach-Object {
    Export-Object $type $_.BaseName $_.FullName "--no-data"
  }
}

# Write checksum file deterministically
$OrderedChecksums = [ordered]@{}
foreach ($key in ($Checksums.Keys | Sort-Object)) {
  $OrderedChecksums[$key] = $Checksums[$key]
}

$NewJson = ($OrderedChecksums | ConvertTo-Json -Depth 3).Trim()

$WriteFile = $true
if (Test-Path $ChecksumFile) {
  $ExistingJson = (Get-Content $ChecksumFile -Raw).Trim()
  if ($ExistingJson -eq $NewJson) {
    $WriteFile = $false
  }
}

if ($WriteFile) {
  $NewJson | Out-File $ChecksumFile -Encoding utf8
  Write-Host "Checksum file updated"
}

# Drift warnings (warn only)
foreach ($dir in $schemaDirs.Keys) {
  $path = Join-Path $SchemaRoot $dir
  if (-not (Test-Path $path)) { continue }

  Get-ChildItem $path -Filter *.sql | ForEach-Object {
    $key = "$dir/$($_.BaseName)"
    if (-not $SeenObjects.ContainsKey($key)) {
      Write-Warning "Schema drift detected: Object exists in Git but not in DB: $key"
    }
  }
}
