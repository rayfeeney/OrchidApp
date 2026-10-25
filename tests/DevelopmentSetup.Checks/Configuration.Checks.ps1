$ErrorActionPreference = 'Stop'
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$names = @('MARIADB_HOST','MARIADB_PORT','MARIADB_DATABASE','MARIADB_USER','MARIADB_PASSWORD','Storage__UploadRoot','ConnectionStrings__OrchidDb','ASPNETCORE_ENVIRONMENT','Monitoring__Enabled','MARIADB_CHARSET','MARIADB_COLLATION','MYSQL_HOST','MYSQL_PORT')
$previous = @{}
foreach ($name in $names) { $previous[$name] = [Environment]::GetEnvironmentVariable($name) }
$checks = 0
function Check([string]$Name,[bool]$Pass) { if (-not $Pass) { throw "Check failed: $Name" }; $script:checks++ }
try {
    $env:MARIADB_HOST='127.0.0.1'; $env:MARIADB_PORT='53319'; $env:MARIADB_DATABASE='orchids_setup_fixture'
    $env:MARIADB_USER='user;with=quotes'; $env:MARIADB_PASSWORD='test;"quoted"=value'
    $env:MYSQL_HOST='wrong-host'; $env:MYSQL_PORT='wrong-port'
    $env:Storage__UploadRoot=[IO.Path]::GetTempPath()
    . (Join-Path $repositoryRoot 'scripts/DevSetup/configure.ps1')
    $connection = [System.Data.Common.DbConnectionStringBuilder]::new()
    $connection.set_ConnectionString($env:ConnectionStrings__OrchidDb)
    Check 'Explicit host ignores MYSQL alias' ($connection['Server'] -ceq '127.0.0.1')
    Check 'Explicit non-default port' ($connection['Port'] -eq '53319')
    Check 'Database aligned' ($connection['Database'] -ceq $env:MARIADB_DATABASE)
    Check 'Account escaped' ($connection['User ID'] -ceq $env:MARIADB_USER)
    Check 'Password escaped' ($connection['Password'] -ceq $env:MARIADB_PASSWORD)
    Check 'Monitoring disabled' ($env:Monitoring__Enabled -ceq 'false')
    Check 'Creation charset aligned' ($env:MARIADB_CHARSET -ceq 'utf8mb4' -and $env:MARIADB_COLLATION -ceq 'utf8mb4_unicode_ci')
    foreach ($name in @('MARIADB_HOST','MARIADB_PORT','MARIADB_DATABASE','MARIADB_USER','MARIADB_PASSWORD')) {
        $value=[Environment]::GetEnvironmentVariable($name)
        [Environment]::SetEnvironmentVariable($name,$null)
        $rejected=$false
        try { Get-ExplicitDatabaseEnvironment | Out-Null } catch { $rejected=$_.Exception.Message.Contains($name) }
        finally { [Environment]::SetEnvironmentVariable($name,$value) }
        Check "Missing $name rejected" $rejected
    }
    foreach ($port in @('0','65536','not-a-port')) {
        $env:MARIADB_PORT=$port; $rejected=$false
        try { Get-ExplicitDatabaseEnvironment | Out-Null } catch { $rejected=$_.Exception.Message.Contains('MARIADB_PORT') }
        Check 'Invalid port rejected' $rejected
    }
    $env:MARIADB_PORT='53319'; $env:MARIADB_DATABASE='unsafe-name'; $rejected=$false
    try { Get-ExplicitDatabaseEnvironment | Out-Null } catch { $rejected=$_.Exception.Message.Contains('MARIADB_DATABASE') }
    Check 'Unsafe identifier rejected' $rejected
    $env:MARIADB_DATABASE='orchids_setup_fixture'; $env:Storage__UploadRoot='relative/photos'; $rejected=$false
    try { . (Join-Path $repositoryRoot 'scripts/DevSetup/configure.ps1') } catch { $rejected=$_.Exception.Message.Contains('Storage__UploadRoot') }
    Check 'Relative upload path rejected' $rejected
    Write-Host "$checks development configuration checks passed."
}
finally { foreach ($name in $names) { [Environment]::SetEnvironmentVariable($name,$previous[$name]) } }

