param(
    [Parameter(Mandatory=$true)][string]$AppRoot,
    [Parameter(Mandatory=$true)][string]$PersistentRoot,
    [Parameter(Mandatory=$true)][string]$ResultFile,
    [int]$InstallerProcessId=0
)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Installer-Snapshot.ps1')

function Invoke-UpgradeTool([string]$File,[string[]]$Arguments,[string]$Log,[int]$TimeoutMs=30000) {
    $process=Start-Process -FilePath $File -ArgumentList $Arguments -PassThru -WindowStyle Hidden -RedirectStandardOutput "$Log.out" -RedirectStandardError "$Log.err"
    $null=$process.Handle
    if (-not $process.WaitForExit($TimeoutMs)) {
        Stop-Process -Id $process.Id -Force
        throw "MariaDB tool timed out. Diagnostics: $Log"
    }
    if ($process.ExitCode -ne 0) { throw "MariaDB tool exited with code $($process.ExitCode). Diagnostics: $Log" }
    Get-Content -LiteralPath "$Log.out"
}

try {
    $AppRoot=Get-InstallerFullPath $AppRoot
    $PersistentRoot=Get-InstallerFullPath $PersistentRoot
    $marker=Join-Path $PersistentRoot 'mariadb-upgrade-pending.json'
    if (-not (Test-Path -LiteralPath $marker)) { exit 0 }
    Assert-InstallerPath $marker
    Assert-InstallerStopped $AppRoot $PersistentRoot $InstallerProcessId
    $state=Get-Content -LiteralPath $marker -Raw | ConvertFrom-Json
    $data=Join-Path $PersistentRoot 'data/mariadb'
    if ($state.formatVersion -ne 1 -or $state.operationId -notmatch '^[0-9a-f-]{36}$' -or
        $state.dataDirectory -ine $data -or $state.sourceVersion -notmatch '^10\.11\.\d+$' -or
        $state.targetVersion -notmatch '^11\.8\.\d+$' -or
        (Split-Path -Parent $state.snapshot) -ine (Join-Path $PersistentRoot 'backups/pre-install')) {
        throw 'Invalid MariaDB upgrade record.'
    }
    Assert-InstallerPath $state.snapshot
    if ((Get-FileHash -LiteralPath $state.snapshot -Algorithm SHA256).Hash -ine $state.snapshotSha256) {
        throw 'The recorded recovery snapshot checksum changed.'
    }
    $manifest=Read-InstallerSnapshot $state.snapshot
    if ($manifest.applicationRoot -ine $AppRoot -or $manifest.persistentRoot -ine $PersistentRoot) {
        throw 'The recovery snapshot belongs to a different installation.'
    }
    $expected=@($manifest.files | Where-Object { $_.path -like 'persistent/data/mariadb/*' })
    $current=@(Get-InstallerFiles $data 'persistent/data/mariadb')
    if (-not $expected.Count -or @(Compare-Object @($expected.path) @($current.path)).Count) {
        throw 'The stopped database inventory differs from its snapshot.'
    }
    $files=@{}
    foreach ($item in $expected) { $files[$item.path]=$item.sha256 }
    foreach ($item in $current) {
        if ((Get-FileHash -LiteralPath $item.source -Algorithm SHA256).Hash -ine $files[$item.path]) {
            throw 'Stopped database bytes differ from the verified snapshot.'
        }
    }

    $bin=Join-Path $AppRoot 'runtime/mariadb/win-x64/bin'
    $server=Join-Path $bin 'mariadbd.exe'
    $client=Join-Path $bin 'mariadb.exe'
    $admin=Join-Path $bin 'mariadb-admin.exe'
    $upgrade=Join-Path $bin 'mariadb-upgrade.exe'
    foreach ($tool in @($server,$client,$admin,$upgrade)) {
        Assert-InstallerPath $tool
        if (-not (Test-Path -LiteralPath $tool -PathType Leaf)) { throw "Missing bundled MariaDB tool: $tool" }
    }
    $version=& $server --no-defaults --version
    if ($LASTEXITCODE -ne 0 -or $version -notmatch ('\b'+[regex]::Escape($state.targetVersion)+'-MariaDB\b')) {
        throw 'The installed target engine does not match the pending upgrade.'
    }
    $logs=Join-Path $PersistentRoot ('logs/mariadb-upgrade-'+$state.operationId)
    Assert-InstallerPath $logs
    $null=New-Item -ItemType Directory -Path $logs
    $pipe='OrchidAppUpgrade-'+[guid]::NewGuid().ToString('N')
    $connect=@('--no-defaults','--protocol=PIPE',"--socket=$pipe",'--user=root','--password=')
    $db=Start-Process -FilePath $server -ArgumentList "--no-defaults --datadir=`"$data`" --skip-networking --enable-named-pipe --socket=$pipe --event-scheduler=OFF --console" -WindowStyle Hidden -PassThru -RedirectStandardOutput "$logs/server.out" -RedirectStandardError "$logs/server.err"
    $null=$db.Handle
    $identityVerified=$false
    try {
        $identity=$null
        for ($attempt=0;$attempt -lt 30;$attempt++) {
            if ($db.HasExited) { throw "The target database stopped before upgrade. Diagnostics: $logs" }
            try {
                $identity=Invoke-UpgradeTool $client ($connect+@('--connect-timeout=2','--batch','--skip-column-names','--execute="SELECT @@datadir,@@version,@@skip_networking;"')) "$logs/identity" 4000
                break
            } catch { Start-Sleep -Seconds 1 }
        }
        $values=([string]$identity).Split("`t")
        if ($values.Count -ne 3 -or (Get-InstallerFullPath $values[0]) -ine $data -or
            $values[1] -notmatch ('^'+[regex]::Escape($state.targetVersion)+'-MariaDB') -or $values[2] -ne '1') {
            throw 'Private MariaDB connection identity could not be verified.'
        }
        $identityVerified=$true
        $null=Invoke-UpgradeTool $upgrade $connect "$logs/upgrade" 900000
        $upgradedVersion=(Get-Content -LiteralPath (Join-Path $data 'mariadb_upgrade_info') -Raw).Trim()
        if ($upgradedVersion -notmatch ('^'+[regex]::Escape($state.targetVersion)+'(?:-MariaDB)?$')) {
            throw 'MariaDB did not record the expected completed engine upgrade.'
        }
    } finally {
        if ($identityVerified -and -not $db.HasExited) {
            $null=Invoke-UpgradeTool $admin ($connect+@('shutdown')) "$logs/shutdown"
            if (-not $db.WaitForExit(30000) -or $db.ExitCode -ne 0) { throw 'The upgraded database did not stop cleanly.' }
        }
    }
    if (-not $db.HasExited -or $db.ExitCode -ne 0) { throw 'The target database did not stop cleanly.' }
    Remove-Item -LiteralPath $marker
    [IO.File]::WriteAllText($ResultFile,"MariaDB upgraded from $($state.sourceVersion) to $($state.targetVersion). Diagnostics: $logs")
    exit 0
} catch {
    [IO.File]::WriteAllText($ResultFile,('MariaDB upgrade stopped. Preserve the recovery record and snapshot. '+$_.Exception.Message))
    exit 1
}
