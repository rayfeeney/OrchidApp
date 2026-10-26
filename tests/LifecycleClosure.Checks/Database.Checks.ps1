param([string]$PythonExe='python3',[int]$WebPort=53337,[switch]$ExportSchema)
$ErrorActionPreference='Stop'
$PSNativeCommandUseErrorActionPreference=$false
$repo=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
foreach($name in @('MARIADB_HOST','MARIADB_PORT','MARIADB_USER','MARIADB_PASSWORD')) {
    if(-not [Environment]::GetEnvironmentVariable($name)){throw "Explicit $name required for an isolated server."}
}
$client=(Get-Command mariadb -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
$root=Join-Path ([IO.Path]::GetTempPath()) ('orchid-c11-'+[guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory -Path $root
$defaults=Join-Path $root 'client.cnf'
$databases=@(('orchids_c11_'+[guid]::NewGuid().ToString('N')),('orchids_c11_'+[guid]::NewGuid().ToString('N')))
$prior=@{}
foreach($name in @('MARIADB_DATABASE','MARIADB_CHARSET','MARIADB_COLLATION','C11_TEST_DEFAULTS','C11_TEST_DATABASE','C11_TEST_WEB_URL','MYSQL_PWD','ASPNETCORE_ENVIRONMENT','ASPNETCORE_URLS','ConnectionStrings__OrchidDb','ConnectionStrings__DefaultConnection','Storage__UploadRoot','Monitoring__Enabled')) {
    $prior[$name]=[Environment]::GetEnvironmentVariable($name)
}
$process=$null;$cleanupCode=0
& (Join-Path $PSScriptRoot 'ExportPreflight.Checks.ps1')
function Quote-Option([string]$Value) {
    if($Value.Contains("`r") -or $Value.Contains("`n")){throw 'Fixture credential newline unsupported.'}
    '"'+$Value.Replace('\','\\').Replace('"','\"')+'"'
}
function Query([string]$Statement) {
    $result=$Statement | & $client "--defaults-extra-file=$defaults" "--database=$env:MARIADB_DATABASE" --batch --skip-column-names --default-character-set=utf8mb4 2>&1
    if($LASTEXITCODE -ne 0){throw "Fixture SQL failed: $($result -join "`n")"}
    $result
}
function Stop-HostProcess {
    if($script:process -and -not $script:process.HasExited) {
        Stop-Process -Id $script:process.Id
        if(-not $script:process.WaitForExit(10000)){throw 'Owned fixture host did not exit.'}
    }
    $script:process=$null
}
try {
    $lines=@('[client]','protocol=tcp',('host='+ (Quote-Option $env:MARIADB_HOST)),('port='+$env:MARIADB_PORT),('user='+ (Quote-Option $env:MARIADB_USER)),('password='+ (Quote-Option $env:MARIADB_PASSWORD)))
    [IO.File]::WriteAllLines($defaults,$lines,[Text.UTF8Encoding]::new($false))
    if(-not $IsWindows){& chmod 600 -- $defaults;if($LASTEXITCODE -ne 0){throw 'Credential protection failed.'}}
    $env:MYSQL_PWD=$null;$env:MARIADB_CHARSET='utf8mb4';$env:MARIADB_COLLATION='utf8mb4_unicode_ci'
    $stage=Join-Path $root 'schema-only/database';$null=New-Item -ItemType Directory -Path $stage
    foreach($directory in @('scripts','schema')){Copy-Item -LiteralPath (Join-Path $repo "database/$directory") -Destination $stage -Recurse}
    # Synthetic upgrade fixture: current schema except the genuine pre-C11 procedure.
    # Regenerate its fixture manifest with the preceding cutoff, never edit production artifacts.
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'PreC11UpdatePlantDetails.sql') -Destination (Join-Path $stage 'schema/routines/spUpdatePlantDetails.sql') -Force
    & (Join-Path $stage 'scripts/New-SchemaManifest.ps1') -SchemaRoot (Join-Path $stage 'schema') -ThroughMigration '202606041820'
    if(Test-Path -LiteralPath (Join-Path $stage 'migrations')){throw 'Schema-only stage unexpectedly contains migrations.'}
    $env:MARIADB_DATABASE=$databases[0]
    & (Join-Path $stage 'scripts/rebuild.ps1') -ConfirmDatabase $env:MARIADB_DATABASE
    $oldBaseline=@(Query "SELECT CONCAT(scriptName,':',checksum) FROM schemaversion ORDER BY scriptName;")
    $migration='202610261200_AtomicManualPlantClosure.sql'
    $migrationFolder=Join-Path $root 'c11-migration';$null=New-Item -ItemType Directory -Path $migrationFolder
    Copy-Item -LiteralPath (Join-Path $repo "database/migrations/$migration") -Destination $migrationFolder
    if($ExportSchema) {
        $before=Query "SELECT ROUTINE_DEFINITION FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA=DATABASE() AND ROUTINE_NAME='spUpdatePlantDetails';"
        if(($before -join "`n") -notmatch 'SET endDateTime = vFinalEndDate'){throw 'Export acceptance requires the preceding schema fixture.'}
    }
    # Reproduce the real original failure on generated rows before applying the fix.
    Query "CALL spAddGenus('C11 prior-procedure fixture','fixture'); SET @t=(SELECT MIN(taxonId) FROM taxon); CALL spAddPlant(@t,'2020-01-01','fixture','Prior procedure','Witness'); SET @p=(SELECT MAX(plantId) FROM plant); INSERT INTO flowering(plantId,startDate) VALUES (@p,'2020-02-01');" | Out-Null
    $witnessPlant=[int](Query 'SELECT MAX(plantId) FROM plant;')
    $oldFailure="CALL spUpdatePlantDetails($witnessPlant,(SELECT MIN(taxonId) FROM taxon),'Prior procedure','2020-01-01','fixture','2021-03-01','closure','Witness');" | & $client "--defaults-extra-file=$defaults" "--database=$env:MARIADB_DATABASE" 2>&1
    if($LASTEXITCODE -eq 0 -or ($oldFailure -join "`n") -notmatch 'endDateTime'){throw 'Original closure failure was not reproduced.'}
    if([int](Query "SELECT COUNT(*) FROM plant WHERE plantId=$witnessPlant AND endDate IS NOT NULL;") -ne 1){throw 'Original partial plant save was not reproduced.'}
    $historicalState=@(Query "SELECT p.endDate,f.endDate IS NULL FROM plant p JOIN flowering f ON f.plantId=p.plantId WHERE p.plantId=$witnessPlant;")
    # Reproduce the failed pre-commit route in a disposable copy of CURRENT source.
    $exportSource=Join-Path $root 'export-source/database';$null=New-Item -ItemType Directory -Path $exportSource
    foreach($directory in @('scripts','schema','checksums','migrations')){Copy-Item -LiteralPath (Join-Path $repo "database/$directory") -Destination $exportSource -Recurse}
    $exporter=Join-Path $exportSource 'scripts/Export-MariaDBSchema.ps1'
    function Export-SourceHashes {
        @(foreach($folder in @('schema','checksums')){Get-ChildItem -LiteralPath (Join-Path $exportSource $folder) -Recurse -File | Sort-Object FullName | ForEach-Object { (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash }}) -join '|'
    }
    $beforeExport=Export-SourceHashes
    $blocked=& pwsh -NoProfile -File $exporter 2>&1
    $blockedText=($blocked -join ' ') -replace '\s+',' '
    if($LASTEXITCODE -eq 0 -or $blockedText -notmatch 'Pending database migrations'){throw 'Unmigrated export was not refused with its recovery instruction.'}
    if((Export-SourceHashes) -ne $beforeExport){throw 'Blocked export changed schema/checksum bytes.'}
    Write-Host 'Unmigrated export refused; schema/checksum files unchanged.'
    & (Join-Path $repo 'database/scripts/Apply-Migrations.ps1') -MigrationFolder $migrationFolder -PlanOnly
    & (Join-Path $repo 'database/scripts/Apply-Migrations.ps1') -MigrationFolder $migrationFolder
    & (Join-Path $repo 'database/scripts/Apply-Migrations.ps1') -MigrationFolder $migrationFolder
    if((@(Query "SELECT p.endDate,f.endDate IS NULL FROM plant p JOIN flowering f ON f.plantId=p.plantId WHERE p.plantId=$witnessPlant;") -join '|') -ne ($historicalState -join '|')){throw 'Migration silently rewrote historical partial closure.'}
    $review=@(Query (Get-Content -LiteralPath (Join-Path $repo 'database/scripts/Review-ManualPlantClosure.sql') -Raw))
    if(-not @($review | Where-Object {[string]$_ -match ('^'+$witnessPlant+"`t")}).Count){throw 'Read-only adoption review did not identify the historical fixture.'}
    if((@(Query "SELECT p.endDate,f.endDate IS NULL FROM plant p JOIN flowering f ON f.plantId=p.plantId WHERE p.plantId=$witnessPlant;") -join '|') -ne ($historicalState -join '|')){throw 'Adoption review changed historical data.'}
    $cutoff=(Get-Content -LiteralPath (Join-Path $stage 'schema/bootstrap.json') -Raw | ConvertFrom-Json).throughMigration
    $expectedApplied=if($cutoff -lt '202610261200'){1}else{0}
    if([int](Query "SELECT COUNT(*) FROM schemaversion WHERE scriptName='$migration';") -ne $expectedApplied){throw 'Migration was not applied/skipped exactly once as expected.'}
    $rawHash=(Get-FileHash -LiteralPath (Join-Path $migrationFolder $migration) -Algorithm SHA256).Hash.ToLowerInvariant()
    if((Query "SELECT checksum FROM schemaversion WHERE scriptName='$migration';") -cne $rawHash){throw 'Recorded migration checksum differs from raw file bytes.'}
    $exported=& pwsh -NoProfile -File $exporter 2>&1
    if($LASTEXITCODE -ne 0){throw "Migrated export failed: $($exported -join "`n")"}
    $exportCutoff=(Get-Content -LiteralPath (Join-Path $exportSource 'schema/bootstrap.json') -Raw | ConvertFrom-Json).throughMigration
    if($exportCutoff -ne '202610261200'){throw 'Migrated export did not preserve C11 cutoff.'}
    Write-Host 'Migrated export succeeded with C11 cutoff.'
    foreach($row in $oldBaseline){if(@(Query "SELECT CONCAT(scriptName,':',checksum) FROM schemaversion ORDER BY scriptName;") -notcontains $row){throw 'Existing baseline/history changed.'}}
    if($ExportSchema){& (Join-Path $repo 'database/scripts/Export-MariaDBSchema.ps1')}

    & dotnet build (Join-Path $repo 'src/OrchidApp.Web/OrchidApp.Web.csproj') --configuration Release
    if($LASTEXITCODE -ne 0){throw 'Web build failed.'}
    $bin=Join-Path $repo 'src/OrchidApp.Web/bin/Release/net8.0'
    Add-Type -Path (Join-Path $bin 'MySqlConnector.dll')
    foreach($database in $databases) {
        $env:MARIADB_DATABASE=$database
        if($database -eq $databases[1]) {
            $fresh=Join-Path $root 'fresh-schema-only/database';$null=New-Item -ItemType Directory -Path $fresh
            foreach($directory in @('scripts','schema')){Copy-Item -LiteralPath (Join-Path $repo "database/$directory") -Destination $fresh -Recurse}
            if(Test-Path -LiteralPath (Join-Path $fresh 'migrations')){throw 'Fresh fixture contains migration SQL.'}
            $freshCutoff=(Get-Content -LiteralPath (Join-Path $fresh 'schema/bootstrap.json') -Raw | ConvertFrom-Json).throughMigration
            if($freshCutoff -lt '202610261200'){throw "Fresh schema cutoff is '$freshCutoff'; expected at least 202610261200. Restore the matching generated C11 routine/bootstrap/checksum files and migrate the isolated export database before committing. Do not edit the cutoff by hand."}
            & (Join-Path $fresh 'scripts/rebuild.ps1') -ConfirmDatabase $database
            if([int](Query "SELECT COUNT(*) FROM schemaversion WHERE scriptName='$migration';") -ne 0){throw 'Fresh creation replayed C11 migration.'}
        }
        $builder=[MySqlConnector.MySqlConnectionStringBuilder]::new()
        $builder.Server=$env:MARIADB_HOST;$builder.Port=[uint32]$env:MARIADB_PORT;$builder.UserID=$env:MARIADB_USER;$builder.Password=$env:MARIADB_PASSWORD;$builder.Database=$database;$builder.AllowUserVariables=$true
        $env:ConnectionStrings__OrchidDb=$builder.ConnectionString;$env:ConnectionStrings__DefaultConnection=$builder.ConnectionString
        $env:ASPNETCORE_ENVIRONMENT='Production';$env:ASPNETCORE_URLS="http://127.0.0.1:$WebPort";$env:Monitoring__Enabled='false'
        $env:Storage__UploadRoot=Join-Path $root ('uploads-'+$database);$null=New-Item -ItemType Directory -Path $env:Storage__UploadRoot
        $env:C11_TEST_DATABASE=$database;$env:C11_TEST_DEFAULTS=$defaults;$env:C11_TEST_WEB_URL=$env:ASPNETCORE_URLS
        # Check that no existing listener is answering for the fixture URL.
        $listener=[Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,$WebPort)
        try{$listener.Start()}finally{$listener.Stop()}
        $parameters=@{FilePath='dotnet';ArgumentList=('"'+(Join-Path $bin 'OrchidApp.Web.dll')+'"');WorkingDirectory=(Join-Path $repo 'src/OrchidApp.Web');PassThru=$true;RedirectStandardOutput=(Join-Path $root ($database+'-web.log'));RedirectStandardError=(Join-Path $root ($database+'-web-error.log'))}
        if($IsWindows){$parameters.WindowStyle='Hidden'}
        $process=Start-Process @parameters
        $null=$process.Handle;$ready=$false
        for($i=0;$i -lt 30;$i++){
            if($process.HasExited){throw 'Fixture web host exited; inspect retained logs.'}
            try{$response=Invoke-WebRequest -Uri ($env:ASPNETCORE_URLS+'/Plants') -TimeoutSec 2;if($response.StatusCode -eq 200){$ready=$true;break}}catch{}
            Start-Sleep -Seconds 1
        }
        if(-not $ready){throw 'Fixture web host did not become ready.'}
        & $PythonExe (Join-Path $PSScriptRoot 'checks.py')
        if($LASTEXITCODE -ne 0){throw 'Lifecycle closure database/HTTP checks failed.'}
        Stop-HostProcess
    }
    Write-Host 'C11 upgrade and schema-only creation with actual HTTP closure checks passed.'
}
finally {
    Stop-HostProcess
    if(Test-Path -LiteralPath $defaults){
        foreach($database in $databases){
            if($database -cnotmatch '^orchids_c11_[0-9a-f]{32}$'){throw 'Unsafe fixture cleanup.'}
            & $client "--defaults-extra-file=$defaults" "--execute=DROP DATABASE IF EXISTS ``$database``;" | Out-Null
            if($LASTEXITCODE -ne 0){$cleanupCode=1}
        }
        Remove-Item -LiteralPath $defaults -Force
    }
    foreach($name in $prior.Keys){[Environment]::SetEnvironmentVariable($name,$prior[$name])}
    Write-Host "C11 fixture logs retained: $root"
    if($cleanupCode){throw 'Generated database cleanup failed.'}
}
