$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '../../scripts/DevSetup/Repository-Environment.ps1')
$root=Join-Path ([IO.Path]::GetTempPath()) ('orchid-dotenv-'+[guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory -Path $root
$file=Join-Path $root '.env';$checks=0
$keys=@('MARIADB_HOST','MARIADB_PORT','MARIADB_DATABASE','MARIADB_USER','MARIADB_PASSWORD','MYSQL_PWD','IGNORED_KEY')
$previous=@{};foreach($name in $keys){$previous[$name]=[Environment]::GetEnvironmentVariable($name)}
function Check([string]$Name,[bool]$Pass){if(-not $Pass){throw "Check failed: $Name"};$script:checks++}
function Write-Env([string]$Password='literal;#=$HOME`$(not-executed)'){
    $content=@('MARIADB_HOST=127.0.0.1','MARIADB_PORT=53336','MARIADB_DATABASE=orchids_dotenv','MARIADB_USER=fixture',("MARIADB_PASSWORD='"+$Password+"'"),'IGNORED_KEY=do-not-import')
    [IO.File]::WriteAllLines($file,$content,[Text.UTF8Encoding]::new($false))
}
try {
    Write-Env
    $values=Read-RepositoryDatabaseEnvironment $root
    Check 'All five canonical keys loaded' ($values.Count -eq 5)
    Check 'Secret punctuation/variables stay literal' ($values.MARIADB_PASSWORD -ceq 'literal;#=$HOME`$(not-executed)')
    Check 'Unknown keys are ignored' (-not $values.ContainsKey('IGNORED_KEY'))
    $env:MARIADB_HOST='ambient-host';$env:MARIADB_PORT='1';$env:MARIADB_DATABASE='ambient_db';$env:MARIADB_USER='ambient-user';$env:MARIADB_PASSWORD='ambient-password';$env:MYSQL_PWD='ambient-native-password'
    Invoke-RepositoryDatabaseEnvironment $root {
        Check 'File replaces stale host' ($env:MARIADB_HOST -ceq '127.0.0.1')
        Check 'File replaces stale port' ($env:MARIADB_PORT -ceq '53336')
        Check 'File replaces stale DB' ($env:MARIADB_DATABASE -ceq 'orchids_dotenv')
        Check 'File replaces stale user' ($env:MARIADB_USER -ceq 'fixture')
        Check 'File replaces stale password' ($env:MARIADB_PASSWORD -ceq 'literal;#=$HOME`$(not-executed)')
        Check 'Unrelated native password cleared' ([string]::IsNullOrEmpty($env:MYSQL_PWD))
    }
    Check 'Ambient target restored after success' ($env:MARIADB_HOST -ceq 'ambient-host' -and $env:MARIADB_PASSWORD -ceq 'ambient-password' -and $env:MYSQL_PWD -ceq 'ambient-native-password')
    try{Invoke-RepositoryDatabaseEnvironment $root {throw 'expected failure'}}catch{Check 'Original error retained' ($_.Exception.Message -ceq 'expected failure')}
    Check 'Ambient target restored after failure' ($env:MARIADB_HOST -ceq 'ambient-host' -and $env:MYSQL_PWD -ceq 'ambient-native-password')
    $text=[IO.File]::ReadAllText($file).Replace('MARIADB_HOST','mariadb_host').Replace('MARIADB_PASSWORD','export mariadb_password')
    [IO.File]::WriteAllText($file,$text)
    $values=Read-RepositoryDatabaseEnvironment $root
    Check 'Lowercase/export names become canonical' (@($values.Keys | Where-Object {$_ -cnotmatch '^MARIADB_[A-Z]+$'}).Count -eq 0)
    [IO.File]::AppendAllText($file,"`nMARIADB_PASSWORD=literal#hash`n")
    Check 'Unquoted hash remains literal; last definition wins' ((Read-RepositoryDatabaseEnvironment $root).MARIADB_PASSWORD -ceq 'literal#hash')
    [IO.File]::AppendAllText($file,"MARIADB_PASSWORD=`"quoted value`" # comment`n")
    Check 'Quoted value permits trailing comment' ((Read-RepositoryDatabaseEnvironment $root).MARIADB_PASSWORD -ceq 'quoted value')
    foreach($name in @('MARIADB_HOST','MARIADB_PORT','MARIADB_DATABASE','MARIADB_USER','MARIADB_PASSWORD')){
        Write-Env
        $lines=[IO.File]::ReadAllLines($file) | Where-Object {$_ -notmatch ('^'+$name+'=')}
        [IO.File]::WriteAllLines($file,[string[]]$lines)
        $rejected=$false;try{Read-RepositoryDatabaseEnvironment $root | Out-Null}catch{$rejected=$_.Exception.Message.Contains($name)}
        Check "Missing $name rejected without ambient fallback" $rejected
    }
    foreach($port in @('0','65536','text')){
        Write-Env;[IO.File]::AppendAllText($file,"MARIADB_PORT=$port`n")
        $rejected=$false;try{Read-RepositoryDatabaseEnvironment $root | Out-Null}catch{$rejected=$_.Exception.Message.Contains('MARIADB_PORT')}
        Check 'Invalid port rejected' $rejected
    }
    Write-Env;[IO.File]::AppendAllText($file,"MARIADB_DATABASE=unsafe-name`n")
    $rejected=$false;try{Read-RepositoryDatabaseEnvironment $root | Out-Null}catch{$rejected=$_.Exception.Message.Contains('MARIADB_DATABASE')}
    Check 'Invalid identifier rejected' $rejected
    Write-Env;[IO.File]::AppendAllText($file,"MARIADB_PASSWORD='private-sentinel`n")
    $message='';try{Read-RepositoryDatabaseEnvironment $root | Out-Null}catch{$message=$_.Exception.Message}
    Check 'Malformed quote rejected without secret' ($message.Contains('Invalid quoted') -and -not $message.Contains('private-sentinel'))
    Remove-Item -LiteralPath $file -Force
    $rejected=$false;try{Read-RepositoryDatabaseEnvironment $root | Out-Null}catch{$rejected=$_.Exception.Message.Contains('.env file is missing')}
    Check 'Missing file rejected' $rejected
    Write-Host "$checks repository .env checks passed."
}
finally {
    if(Test-Path -LiteralPath $file){Remove-Item -LiteralPath $file -Force}
    Remove-Item -LiteralPath $root -Force
    foreach($name in $previous.Keys){[Environment]::SetEnvironmentVariable($name,$previous[$name])}
}
