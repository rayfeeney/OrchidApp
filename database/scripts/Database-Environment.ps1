# Shared explicit endpoint contract for developer setup and schema export.
function Get-ExplicitDatabaseEnvironment {
    foreach ($name in @('MARIADB_HOST','MARIADB_PORT','MARIADB_DATABASE','MARIADB_USER','MARIADB_PASSWORD')) {
        if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($name))) {
            throw "Explicit $name is required. MYSQL_* aliases and endpoint defaults are not used."
        }
    }
    [int]$port = 0
    if (-not [int]::TryParse($env:MARIADB_PORT, [ref]$port) -or $port -lt 1 -or $port -gt 65535) { throw 'Invalid MARIADB_PORT.' }
    if ($env:MARIADB_DATABASE -cnotmatch '^[A-Za-z0-9_]{1,64}$') { throw 'Invalid MARIADB_DATABASE identifier.' }
    [pscustomobject]@{ HostName=$env:MARIADB_HOST; Port=$port; Database=$env:MARIADB_DATABASE; User=$env:MARIADB_USER; Password=$env:MARIADB_PASSWORD }
}
