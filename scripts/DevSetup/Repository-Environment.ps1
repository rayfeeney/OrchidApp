# Development wrappers only. Parse data literally; never dot-source or execute .env.
function Read-RepositoryDatabaseEnvironment([string]$RepositoryRoot) {
    $file=Join-Path $RepositoryRoot '.env'
    if(-not (Test-Path -LiteralPath $file -PathType Leaf)){throw 'The repository .env file is missing. Development database credentials belong there.'}
    $required=@('MARIADB_HOST','MARIADB_PORT','MARIADB_DATABASE','MARIADB_USER','MARIADB_PASSWORD')
    $values=@{};$number=0
    foreach($raw in [IO.File]::ReadAllLines($file)) {
        $number++;$line=$raw.Trim()
        if(-not $line -or $line.StartsWith('#')){continue}
        $match=[regex]::Match($line,'^(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=(.*)$')
        if(-not $match.Success -or $match.Groups[1].Value -notin $required){continue}
        $value=$match.Groups[2].Value.Trim()
        if($value.StartsWith('"') -or $value.StartsWith("'")) {
            $end=$value.LastIndexOf($value[0])
            if($end -eq 0){throw "Invalid quoted .env entry at line $number. Values are not logged."}
            $tail=$value.Substring($end+1).Trim()
            if($tail -and -not $tail.StartsWith('#')){throw "Invalid quoted .env entry at line $number. Values are not logged."}
            $value=$value.Substring(1,$end-1)
        }
        $values[$match.Groups[1].Value.ToUpperInvariant()]=$value
    }
    foreach($name in $required){if([string]::IsNullOrWhiteSpace($values[$name])){throw "Add $name to the repository .env. Values are not logged."}}
    [int]$port=0
    if(-not [int]::TryParse($values.MARIADB_PORT,[ref]$port) -or $port -lt 1 -or $port -gt 65535){throw 'Invalid MARIADB_PORT in .env.'}
    if($values.MARIADB_DATABASE -cnotmatch '^[A-Za-z0-9_]{1,64}$'){throw 'Invalid MARIADB_DATABASE in .env.'}
    $values
}

function Invoke-RepositoryDatabaseEnvironment([string]$RepositoryRoot,[scriptblock]$Action) {
    $values=Read-RepositoryDatabaseEnvironment $RepositoryRoot
    $previous=@{}
    foreach($name in @('MARIADB_HOST','MARIADB_PORT','MARIADB_DATABASE','MARIADB_USER','MARIADB_PASSWORD','MYSQL_PWD')) {
        $previous[$name]=[Environment]::GetEnvironmentVariable($name)
    }
    try {
        foreach($name in $values.Keys){[Environment]::SetEnvironmentVariable($name,$values[$name])}
        # Do not let an unrelated ambient client password choose different credentials.
        $env:MYSQL_PWD=$null
        & $Action
    }
    finally {foreach($name in $previous.Keys){[Environment]::SetEnvironmentVariable($name,$previous[$name])}}
}
