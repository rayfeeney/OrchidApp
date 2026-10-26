param([string]$PythonExe='python3')
$ErrorActionPreference='Stop'
$PSNativeCommandUseErrorActionPreference=$false
$repo=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
foreach($name in @('MARIADB_HOST','MARIADB_PORT','MARIADB_USER','MARIADB_PASSWORD')) {
    if (-not [Environment]::GetEnvironmentVariable($name)) { throw "Explicit $name required for an isolated server." }
}
$client=(Get-Command mariadb -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
$database='orchids_c17_'+[guid]::NewGuid().ToString('N')
$root=Join-Path ([IO.Path]::GetTempPath()) ('orchid-c17-client-'+[guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory -Path $root
$defaults=Join-Path $root 'client.cnf'
$cleanupCode=0
$prior=@{}
foreach($name in @('MARIADB_DATABASE','MARIADB_CHARSET','MARIADB_COLLATION','C17_TEST_DEFAULTS','C17_TEST_DATABASE','MYSQL_PWD')) {
    $prior[$name]=[Environment]::GetEnvironmentVariable($name)
}
function Quote-Option([string]$Value) {
    if ($Value.Contains("`r") -or $Value.Contains("`n")) { throw 'Fixture credentials must not contain newlines.' }
    '"'+$Value.Replace('\','\\').Replace('"','\"')+'"'
}
try {
    $env:MARIADB_DATABASE=$database;$env:MARIADB_CHARSET='utf8mb4';$env:MARIADB_COLLATION='utf8mb4_unicode_ci'
    $lines=@('[client]','protocol=tcp',('host='+ (Quote-Option $env:MARIADB_HOST)),('port='+$env:MARIADB_PORT),('user='+ (Quote-Option $env:MARIADB_USER)),('password='+ (Quote-Option $env:MARIADB_PASSWORD)))
    [IO.File]::WriteAllLines($defaults,$lines,[Text.UTF8Encoding]::new($false))
    if (-not $IsWindows) { & chmod 600 -- $defaults; if ($LASTEXITCODE -ne 0) { throw 'Cannot protect fixture credentials.' } }
    & (Join-Path $repo 'database/scripts/rebuild.ps1') -ConfirmDatabase $database
    $env:C17_TEST_DEFAULTS=$defaults;$env:C17_TEST_DATABASE=$database;$env:MYSQL_PWD=$null
    & $PythonExe (Join-Path $PSScriptRoot 'checks.py')
    if ($LASTEXITCODE -ne 0) { throw 'Linux paired backup checks failed.' }
    Write-Host 'C17 canonical-schema native MariaDB integration passed.'
}
finally {
    if ($database -cnotmatch '^orchids_c17_[0-9a-f]{32}$') { throw 'Unsafe fixture database cleanup.' }
    if (Test-Path -LiteralPath $defaults) {
        & $client "--defaults-extra-file=$defaults" "--execute=DROP DATABASE IF EXISTS ``$database``;" | Out-Null
        $cleanupCode=$LASTEXITCODE
        Remove-Item -LiteralPath $defaults -Force
    }
    foreach($name in $prior.Keys) { [Environment]::SetEnvironmentVariable($name,$prior[$name]) }
    if ($cleanupCode -ne 0) { throw 'Generated database cleanup failed; inspect disposable target.' }
}
