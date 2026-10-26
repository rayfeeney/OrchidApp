param(
    [switch]$PlanOnly,
    [string]$RepositoryRoot=(Join-Path $PSScriptRoot '../..'),
    [string]$BackupRoot
)
$ErrorActionPreference='Stop'
$PSNativeCommandUseErrorActionPreference=$false
$RepositoryRoot=(Resolve-Path -LiteralPath $RepositoryRoot).Path
. (Join-Path $PSScriptRoot 'Repository-Environment.ps1')
. (Join-Path $RepositoryRoot 'database/scripts/Migration-History.ps1')
if(-not $BackupRoot){$BackupRoot=Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData,[Environment+SpecialFolderOption]::Create)) 'OrchidApp/Development/database-backups'}
if(-not [IO.Path]::IsPathFullyQualified($BackupRoot)){throw 'Development backup directory must be absolute.'}
Invoke-RepositoryDatabaseEnvironment $RepositoryRoot {
    Write-Host "Development database: $env:MARIADB_HOST`:$env:MARIADB_PORT/$env:MARIADB_DATABASE (repository .env)."
    $apply=Join-Path $RepositoryRoot 'database/scripts/Apply-Migrations.ps1'
    & $apply -PlanOnly
    if($PlanOnly){return}
    $client=Resolve-MariaDbTool -Override $env:MARIADB_EXE
    $env:MYSQL_PWD=$env:MARIADB_PASSWORD
    $arguments=@('--no-defaults','--protocol=TCP',"--host=$env:MARIADB_HOST","--port=$env:MARIADB_PORT","--user=$env:MARIADB_USER",'--connect-timeout=5','--batch','--skip-column-names',"--database=$env:MARIADB_DATABASE")
    $rows=& $client @arguments '--execute=SELECT scriptName,checksum FROM schemaversion ORDER BY scriptName;' 2>&1
    if($LASTEXITCODE -ne 0){throw 'Could not read development migration history. No update was started.'}
    $history=@{}
    foreach($row in $rows){
        if([string]::IsNullOrWhiteSpace([string]$row)){continue}
        $parts=([string]$row) -split "`t"
        if($parts.Count -ne 2 -or $history.ContainsKey($parts[0])){throw 'Invalid migration history. No update was started.'}
        $history[$parts[0]]=$parts[1]
    }
    $pending=@(Get-MigrationPlan @(Get-MigrationFiles (Join-Path $RepositoryRoot 'database/migrations')) $history)
    if(-not $pending.Count){Write-Host 'Development database is already up to date. You can retry the commit.';return}
    $dump=Resolve-MariaDbTool -Name 'mariadb-dump' -Override $env:MARIADB_DUMP_EXE
    $backup=Join-Path $BackupRoot ($env:MARIADB_DATABASE+'-'+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'-'+[guid]::NewGuid().ToString('N'))
    $null=New-Item -ItemType Directory -Path $backup -Force
    if(-not $IsWindows){[IO.File]::SetUnixFileMode($backup,([IO.UnixFileMode]::UserRead -bor [IO.UnixFileMode]::UserWrite -bor [IO.UnixFileMode]::UserExecute))}
    $sql=Join-Path $backup 'database.sql'
    $dumpArguments=@('--no-defaults','--protocol=TCP',"--host=$env:MARIADB_HOST","--port=$env:MARIADB_PORT","--user=$env:MARIADB_USER",'--default-character-set=utf8mb4','--single-transaction','--routines','--triggers','--events','--hex-blob',"--result-file=$sql",$env:MARIADB_DATABASE)
    $dumpOutput=& $dump @dumpArguments 2>&1
    if($LASTEXITCODE -ne 0){throw "Development database backup failed. No migrations were started. Retained backup folder: $backup"}
    if(-not (Test-Path -LiteralPath $sql -PathType Leaf) -or (Get-Item -LiteralPath $sql).Length -eq 0 -or
       -not ((Get-Content -LiteralPath $sql -Tail 5) -match '^-- Dump completed')){throw 'Development backup is incomplete. No migrations were started.'}
    if(-not $IsWindows){[IO.File]::SetUnixFileMode($sql,([IO.UnixFileMode]::UserRead -bor [IO.UnixFileMode]::UserWrite))}
    $record=Join-Path $backup 'backup.json'
    @{database=$env:MARIADB_DATABASE;host=$env:MARIADB_HOST;port=$env:MARIADB_PORT;sha256=(Get-FileHash -LiteralPath $sql -Algorithm SHA256).Hash;pending=@($pending.Name)} | ConvertTo-Json | Set-Content -LiteralPath $record -Encoding utf8
    if(-not $IsWindows){[IO.File]::SetUnixFileMode($record,([IO.UnixFileMode]::UserRead -bor [IO.UnixFileMode]::UserWrite))}
    Write-Host "Development database backup saved: $backup"
    & $apply
    Write-Host 'Development database updated. You can retry the commit.'
}
