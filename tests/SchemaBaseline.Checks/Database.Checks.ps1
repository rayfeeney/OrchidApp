# Requires explicit MARIADB_HOST/PORT/USER/PASSWORD for an isolated test server.
# Creates and drops only a generated orchids_contract_<guid> database.
param([string]$RepoRoot = (Join-Path $PSScriptRoot '../..'))
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
. (Join-Path $RepoRoot 'database/scripts/Schema-Baseline.ps1')
. (Join-Path $RepoRoot 'tests/MigrationHistory.Checks/Process.Helpers.ps1')
$pwsh = (Get-Command pwsh -CommandType Application | Select-Object -First 1).Source
foreach ($name in @('MARIADB_HOST','MARIADB_PORT','MARIADB_USER','MARIADB_PASSWORD')) {
    if (-not [Environment]::GetEnvironmentVariable($name)) { throw "Explicit $name required for isolated checks." }
}
$client = Resolve-MariaDbTool -Override $env:MARIADB_EXE
$db = 'orchids_contract_' + [guid]::NewGuid().ToString('N')
$testRoot = Join-Path ([IO.Path]::GetTempPath()) $db
$prior = @{}
foreach ($name in @('MARIADB_DATABASE','MARIADB_CHARSET','MARIADB_COLLATION','MYSQL_PWD')) { $prior[$name] = [Environment]::GetEnvironmentVariable($name) }
$checks = 0
function Check([string]$Name, [bool]$Pass) {
    if (-not $Pass) { throw "Check failed: $Name" }
    $script:checks++
}
function Query([string]$Sql, [switch]$Global) {
    $arguments = @('--no-defaults', '--default-character-set=utf8mb4', '--connect-timeout=5', '--protocol=TCP', "--host=$env:MARIADB_HOST", "--port=$env:MARIADB_PORT", "--user=$env:MARIADB_USER", '--batch', '--skip-column-names')
    if (-not $Global) { $arguments += "--database=$db" }
    $result = $Sql | & $client @arguments 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Test query failed: $($result -join "`n")" }
    $result
}
function Run([string]$Script, [string[]]$Arguments, [bool]$Success = $true, [string]$ErrorText = '') {
    $result = Invoke-CheckProcess -Pwsh $pwsh -Script $Script -Arguments $Arguments
    if ($result.Success -ne $Success) { throw "Unexpected script result: $($result.Output)" }
    if ($ErrorText -and $result.Message.IndexOf($ErrorText, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
        throw "Expected '$ErrorText'; exit=$($result.ExitCode); $($result.Output)"
    }
    $script:checks++
}
try {
    $env:MARIADB_DATABASE = $db; $env:MARIADB_CHARSET = 'utf8mb4'; $env:MARIADB_COLLATION = 'utf8mb4_unicode_ci'
    $env:MYSQL_PWD = $env:MARIADB_PASSWORD
    New-Item -ItemType Directory -Path $testRoot | Out-Null
    # Execute production scripts from a stage containing schema and NO migrations.
    $databaseRoot = Join-Path $testRoot 'database'
    New-Item -ItemType Directory -Path $databaseRoot | Out-Null
    foreach ($directory in @('scripts','schema')) {
        Copy-Item -LiteralPath (Join-Path $RepoRoot "database/$directory") -Destination $databaseRoot -Recurse
    }
    $create = Join-Path $databaseRoot 'scripts/rebuild.ps1'
    $schema = Join-Path $databaseRoot 'schema'
    $canonicalPlan = Read-SchemaManifest $schema
    Check 'Staged production scripts have no migration directory' (-not (Test-Path (Join-Path $databaseRoot 'migrations')))

    # Missing reference inputs and baseline metadata fail before creating any DB.
    $seed = Join-Path $schema 'seeds/observationtype_records.sql'
    $seedText = [IO.File]::ReadAllText($seed)
    Remove-Item -LiteralPath $seed
    Run $create @('-ConfirmDatabase', $db) $false 'Schema file missing or changed: seeds/observationtype_records.sql'
    Check 'Missing seed rejected before DB creation' (-not @(Query "SELECT SCHEMA_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME='$db';" -Global).Count)
    [IO.File]::WriteAllText($seed, $seedText)
    $manifestPath = Join-Path $schema 'bootstrap.json'
    $manifestText = [IO.File]::ReadAllText($manifestPath)
    Remove-Item -LiteralPath $manifestPath
    Run $create @('-ConfirmDatabase', $db) $false 'bootstrap.json'
    Check 'Missing baseline metadata rejected before DB creation' (-not @(Query "SELECT SCHEMA_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME='$db';" -Global).Count)
    [IO.File]::WriteAllText($manifestPath, $manifestText)

    # Deliberately reorder dependent views in this disposable manifest only.
    $brokenPlan = $manifestText | ConvertFrom-Json
    $dependent = @($brokenPlan.files | Where-Object path -eq 'views/venvironmentdailyperiodsummary.sql')[0]
    $brokenPlan.files = @($brokenPlan.files | Where-Object { -not $_.path.StartsWith('views/') })
    $viewStart = @($brokenPlan.files | Where-Object { $_.path.StartsWith('tables/') -or $_.path.StartsWith('constraints/') -or $_.path.StartsWith('routines/') }).Count
    $originalViews = @($canonicalPlan.files | Where-Object { $_.path.StartsWith('views/') -and $_.path -ne $dependent.path })
    $nonViews = @($brokenPlan.files)
    $brokenPlan.files = @($nonViews[0..($viewStart-1)]) + @($dependent) + $originalViews + @($nonViews[$viewStart..($nonViews.Count-1)])
    [IO.File]::WriteAllText($manifestPath, ($brokenPlan | ConvertTo-Json -Depth 6))
    Run $create @('-ConfirmDatabase', $db) $false 'Schema command failed'
    Check 'Broken view order has no completion marker' ([int](Query 'SELECT COUNT(*) FROM schemaversion;') -eq 0)
    Query "DROP DATABASE ``$db``;" -Global | Out-Null
    [IO.File]::WriteAllText($manifestPath, $manifestText)

    Run $create @('-ConfirmDatabase', ($db + '_wrong'), '-SchemaRoot', $schema) $false 'ConfirmDatabase must exactly match'
    Check 'Mismatched confirmation did not create a database' (-not @(Query "SELECT SCHEMA_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME='$db';" -Global).Count)
    Run $create @('-ConfirmDatabase', $db, '-SchemaRoot', $schema)
    Check 'No migration directory used for creation' (-not (Test-Path (Join-Path $databaseRoot 'migrations')))
    Check 'Required observation seeds active' ([int](Query "SELECT COUNT(*) FROM observationtype WHERE typeCode IN ('OBS_NOTE','OBS_PHOTO','OBS_FEED_GROWTH','OBS_FEED_BLOOM') AND isActive=1 AND isSystem=1;") -eq 4)
    Check 'Phonetic seeds' ([int](Query 'SELECT COUNT(*) FROM phoneticprefix WHERE isActive=1;') -gt 0)
    Check 'Required propagation seeds active' ([int](Query "SELECT COUNT(*) FROM propagationtype WHERE propagationTypeCode IN ('KEIKI','BACKBULB','CUTTING') AND isActive=1;") -eq 3)
    Check 'One completion marker only' ([int](Query "SELECT COUNT(*) FROM schemaversion WHERE scriptName LIKE 'baseline:v1:%';") -eq 1)
    Check 'Baseline has exact manifest identity' ((Query "SELECT checksum FROM schemaversion WHERE scriptName='baseline:v1:$($canonicalPlan.throughMigration)';") -eq $canonicalPlan.manifestChecksum)
    Check 'Fresh history contains only baseline' ([int](Query 'SELECT COUNT(*) FROM schemaversion;') -eq 1)
    Check 'Creation collation' ((Query 'SELECT @@collation_database;') -eq 'utf8mb4_unicode_ci')
    $markerBefore = (Query 'SELECT CONCAT(scriptName,checksum) FROM schemaversion;') -join ''
    Query "CALL spAddGenus('Contract orchid', 'Schema-only check'); SET @taxon=(SELECT MIN(taxonId) FROM taxon); CALL spAddPlant(@taxon, NOW(), 'Disposable check', 'Contract plant', 'Saved notes');" | Out-Null
    Check 'Plant creation and tag generation' ([int](Query 'SELECT COUNT(*) FROM plant WHERE CHAR_LENGTH(plantTag)=8;') -eq 1)
    Check 'Saved plant notes reopen' ((Query 'SELECT plantNotes FROM plant LIMIT 1;') -eq 'Saved notes')
    $views = @(Query 'SELECT TABLE_NAME FROM information_schema.VIEWS WHERE TABLE_SCHEMA=DATABASE();')
    foreach ($view in $views) { Query "SELECT * FROM ``$view`` LIMIT 1;" | Out-Null }
    Check 'All canonical views query successfully' ($views.Count -eq 16)
    Run $create @('-ConfirmDatabase', $db, '-SchemaRoot', $schema) $false 'Target database is not empty'
    Check 'Existing collection preserved after creation refusal' ([int](Query 'SELECT COUNT(*) FROM plant;') -eq 1)

    $migrations = Join-Path $testRoot 'migrations'
    New-Item -ItemType Directory -Path $migrations | Out-Null
    $historic = Join-Path $migrations '202604010000_HistoricalPoison.sql'
    [IO.File]::WriteAllText($historic, "SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Must never replay historical SQL';")
    $future = Join-Path $migrations '209901010000_ContractFuture.sql'
    [IO.File]::WriteAllText($future, 'CREATE TABLE contract_future (id INT PRIMARY KEY); INSERT INTO contract_future VALUES (1);')
    $apply = Join-Path $databaseRoot 'scripts/Apply-Migrations.ps1'
    Run $apply @('-MigrationFolder', $migrations, '-PlanOnly')
    Check 'PlanOnly leaves original records and history intact' ([int](Query 'SELECT COUNT(*) FROM schemaversion;') -eq 1 -and [int](Query 'SELECT COUNT(*) FROM plant;') -eq 1)
    Check 'PlanOnly does not execute future DDL' ([int](Query "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='contract_future';") -eq 0)
    Run $apply @('-MigrationFolder', $migrations)
    Run $apply @('-MigrationFolder', $migrations)
    Check 'Future migration applies once' ([int](Query 'SELECT COUNT(*) FROM contract_future;') -eq 1)
    Check 'Future history written once with exact checksum' ([int](Query "SELECT COUNT(*) FROM schemaversion WHERE scriptName='209901010000_ContractFuture.sql' AND checksum='$((Get-FileHash -LiteralPath $future -Algorithm SHA256).Hash.ToLowerInvariant())';") -eq 1)
    Check 'Existing plant and notes preserved after upgrade' ([int](Query "SELECT COUNT(*) FROM plant WHERE plantName='Contract plant' AND plantNotes='Saved notes' AND CHAR_LENGTH(plantTag)=8;") -eq 1)
    Check 'No incomplete migration marker after upgrade' ([int](Query "SELECT COUNT(*) FROM schemaversion WHERE scriptName='migration:pending';") -eq 0)
    Check 'Historical files not recorded or replayed' ([int](Query "SELECT COUNT(*) FROM schemaversion WHERE scriptName='202604010000_HistoricalPoison.sql';") -eq 0)
    Check 'Database baseline unchanged by upgrade' ((Query "SELECT CONCAT(scriptName,checksum) FROM schemaversion WHERE scriptName LIKE 'baseline:%';") -eq $markerBefore)
    $futureContent = [IO.File]::ReadAllText($future)
    [IO.File]::AppendAllText($future, '-- tampered')
    Run $apply @('-MigrationFolder', $migrations) $false
    [IO.File]::WriteAllText($future, $futureContent)

    # Reproduce pre-change Desktop bookkeeping on this disposable database.
    # This test-only replacement is never an operator upgrade procedure.
    $historicHash = (Get-FileHash -LiteralPath $historic -Algorithm SHA256).Hash.ToLowerInvariant()
    Query "DELETE FROM schemaversion WHERE scriptName LIKE 'baseline:%'; INSERT INTO schemaversion(scriptName,checksum) VALUES ('baseline','baseline'),('202604010000_HistoricalPoison.sql','$historicHash');" | Out-Null
    Run $apply @('-MigrationFolder', $migrations)
    Check 'Legacy baseline retained untouched' ((Query "SELECT checksum FROM schemaversion WHERE scriptName='baseline';") -eq 'baseline')
    Check 'Legacy migration checksums retained' ((Query "SELECT checksum FROM schemaversion WHERE scriptName='202604010000_HistoricalPoison.sql';") -eq $historicHash)
    # Fail late in a disposable schema import. A completion marker must never
    # survive partial DDL, and neither creation nor migration may silently retry.
    Query "DROP DATABASE ``$db``;" -Global | Out-Null
    $brokenSeed = Join-Path $schema 'seeds/propagationtype_records.sql'
    [IO.File]::AppendAllText($brokenSeed, "`nTHIS IS INTENTIONALLY INVALID SQL;`n")
    $plan = Read-SchemaManifest (Join-Path $RepoRoot 'database/schema')
    Run (Join-Path $databaseRoot 'scripts/New-SchemaManifest.ps1') @('-SchemaRoot', $schema, '-ThroughMigration', $plan.throughMigration)
    Run $create @('-ConfirmDatabase', $db, '-SchemaRoot', $schema) $false
    Check 'Failed import has no completion marker' ([int](Query 'SELECT COUNT(*) FROM schemaversion;') -eq 0)
    Run $create @('-ConfirmDatabase', $db, '-SchemaRoot', $schema) $false
    Run $apply @('-MigrationFolder', $migrations) $false
    Check 'Incomplete history remains incomplete' ([int](Query 'SELECT COUNT(*) FROM schemaversion;') -eq 0)
    Write-Host "$checks database creation/baseline checks passed on $($env:MARIADB_HOST):$($env:MARIADB_PORT)."
}
finally {
    if ($db -cnotmatch '^orchids_contract_[a-f0-9]{32}$') { throw 'Unsafe generated test target.' }
    Query "DROP DATABASE IF EXISTS ``$db``;" -Global | Out-Null
    foreach ($name in $prior.Keys) { [Environment]::SetEnvironmentVariable($name, $prior[$name]) }
    # Keep the unique small fixture directory for inspection; never remove a
    # caller-supplied or computed directory recursively as part of these checks.
}
