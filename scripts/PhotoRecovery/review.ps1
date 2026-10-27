param(
    [Parameter(Mandatory=$true)][string]$UploadsRoot,
    [switch]$UseRepositoryEnvironment,
    [string]$RepositoryRoot=(Join-Path $PSScriptRoot '../..')
)
$ErrorActionPreference='Stop'
$PSNativeCommandUseErrorActionPreference=$false
if(-not[IO.Path]::IsPathFullyQualified($UploadsRoot)){throw 'An explicit absolute upload root is required.'}
$UploadsRoot=[IO.Path]::GetFullPath($UploadsRoot)
$RepositoryRoot=(Resolve-Path -LiteralPath $RepositoryRoot).Path
. (Join-Path $RepositoryRoot 'database/scripts/Migration-History.ps1')
. (Join-Path $RepositoryRoot 'database/scripts/Database-Environment.ps1')
function Read-PhotoRecovery {
    $target=Get-ExplicitDatabaseEnvironment
    $client=Resolve-MariaDbTool -Override $env:MARIADB_EXE
    $priorPassword=$env:MYSQL_PWD
    try {
        $env:MYSQL_PWD=$target.Password
        $arguments=@('--no-defaults','--protocol=TCP',"--host=$($target.HostName)","--port=$($target.Port)","--user=$($target.User)","--database=$($target.Database)",'--connect-timeout=5','--batch','--skip-column-names')
        $folder=Join-Path $UploadsRoot '.photo-recovery'
        $results=@()
        if(Test-Path -LiteralPath $folder -PathType Container) {
            foreach($journal in Get-ChildItem -LiteralPath $folder -File) {
                try{$record=Get-Content -LiteralPath $journal.FullName -Raw | ConvertFrom-Json}catch{throw "Unreadable recovery journal: $($journal.Name). Preserve it and obtain support."}
                if($record.version -ne 1 -or -not $record.state -or -not $record.files){throw "Invalid recovery journal: $($journal.Name)."}
                foreach($relative in $record.files) {
                    $relative=([string]$relative).Replace('\','/')
                    if($relative -cnotmatch '\A(plants|taxa)/([0-9]+)/([a-f0-9]{32}(?:_thumb)?\.jpg(?:\.tmp)?)\z'){throw "Unsafe recovery path in $($journal.Name). Preserve it for review."}
                    $entity=$Matches[1];$id=$Matches[2];$name=$Matches[3]
                    $table=if($entity -eq 'plants'){'plantphoto'}else{'taxonphoto'}
                    $key=if($entity -eq 'plants'){'plantId'}else{'taxonId'}
                    $query="SELECT COUNT(*) FROM $table WHERE $key=$id AND (fileName='$name' OR thumbnailFileName='$name');"
                    $rows=& $client @arguments "--execute=$query" 2>&1
                    if($LASTEXITCODE -ne 0){throw 'Database reference review failed. No files were changed.'}
                    $references=[int]([string]($rows | Select-Object -Last 1))
                    $file=Join-Path $UploadsRoot $relative
                    $present=Test-Path -LiteralPath $file -PathType Leaf
                    $status=if($references -gt 0){if($present){'ReferencedPresent'}else{'ReferencedMissing'}}else{if($present){'UnreferencedPresent'}else{'UnreferencedAbsent'}}
                    $results+=[pscustomobject]@{journal=$journal.Name;state=[string]$record.state;file=$relative;references=$references;status=$status}
                }
            }
        }
        ConvertTo-Json -InputObject @($results) -Depth 4
    }
    finally{$env:MYSQL_PWD=$priorPassword}
}
if($UseRepositoryEnvironment) {
    . (Join-Path $RepositoryRoot 'scripts/DevSetup/Repository-Environment.ps1')
    Invoke-RepositoryDatabaseEnvironment $RepositoryRoot { Read-PhotoRecovery }
}else{Read-PhotoRecovery}
