# Shared Windows PowerShell 5.1 / PowerShell 7 backup/restore contract.
function Get-FullLocalPath([string]$Path) {
    [IO.Path]::GetFullPath($Path).TrimEnd([char[]]@('\','/'))
}
function Assert-NoPathAlias([string]$Path) {
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Data file is a reparse point.' }
    if ($item -is [IO.FileInfo]) { $item = $item.Directory }
    while ($null -ne $item) {
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Data path contains a reparse point; review the source/target.' }
        $item = $item.Parent
    }
}
function Assert-ChildPath([string]$Path, [string]$Parent) {
    $prefix = (Get-FullLocalPath $Parent) + [IO.Path]::DirectorySeparatorChar
    if (-not (Get-FullLocalPath $Path).StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)) { throw 'Data target is outside its intended parent.' }
    if (Test-Path -LiteralPath $Path) { Assert-NoPathAlias $Path }
}
function Invoke-OrchidQuery([string]$Sql) {
    [string[]]$arguments = @('--no-defaults','--protocol=TCP','--host=127.0.0.1',"--port=$MariaDbPort",'--user=orchid','--connect-timeout=5','--default-character-set=utf8mb4','--batch','--skip-column-names',"--execute=$Sql")
    $output = & $MariaDbClient @arguments 2>&1
    if ($LASTEXITCODE -ne 0) { throw "MariaDB query failed: $($output -join "`n")" }
    $output
}
function Assert-DatabaseIdentity {
    $actual = @(Invoke-OrchidQuery 'SELECT @@datadir;')
    if ($actual.Count -ne 1 -or (Get-FullLocalPath ([string]$actual[0])) -ine (Get-FullLocalPath $MariaDbData)) {
        throw 'MariaDB source/target identity mismatch: listener data directory differs from the selected directory. No dump/import is authorised.'
    }
}
function Assert-OrchidDatabaseCanStart {
    $servers = Get-CimInstance Win32_Process -Filter "Name='mariadbd.exe' OR Name='mysqld.exe'" -ErrorAction Stop
    $possibleOwner = $null
    foreach ($server in $servers) {
        $command = [string]$server.CommandLine
        $dataOptions = [regex]::Matches($command, '(?i)(?:^|\s)--datadir(?:=|\s+)(?:"([^"]+)"|([^\s"]+))(?=\s|$)')
        # Only rule out an owner when its command identifies a different, ordinary data directory.
        if ($dataOptions.Count -eq 1 -and $command -match '(?:^|\s)--no-defaults(?=\s|$)') {
            $data = $dataOptions[0].Groups[1].Value + $dataOptions[0].Groups[2].Value
            if ($data -match '^[a-zA-Z]:[\\/][^:]+$') {
                $verifiedDirectory = $null
                try {
                    $data = Get-FullLocalPath $data
                    Assert-NoPathAlias $data
                    $verifiedDirectory = (Get-Item -LiteralPath $data).FullName
                } catch {
                    # Unverifiable process identity must block a competing start.
                }
                if ($verifiedDirectory) {
                    if ($verifiedDirectory -ine (Get-FullLocalPath $MariaDbData)) { continue }
                    $possibleOwner = $server
                    break
                }
            }
        }
        if (-not $possibleOwner) { $possibleOwner = $server }
    }
    if ($possibleOwner) {
        throw "MariaDB process $($possibleOwner.ProcessId) is still running and may own the selected database, but port $MariaDbPort is not listening. Wait for it to exit or close OrchidApp before retrying. No competing MariaDB was started."
    }
}
function Start-OrchidDatabase {
    # Share the startup lock across the Windows backup and restore tools.
    $dataParent = Split-Path -Parent $MariaDbData
    $lockPath = Join-Path $dataParent '.orchidapp-mariadb-start.lock'
    Assert-ChildPath $lockPath $dataParent
    $startupLock = [IO.File]::Open($lockPath,[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
    try { Open-OrchidDatabase } finally { $startupLock.Dispose() }
}
function Test-OrchidDatabaseListener {
    # Check the loopback endpoint the SQL client will actually use.
    $tcp = [Net.Sockets.TcpClient]::new()
    try {
        return $tcp.ConnectAsync([Net.IPAddress]::Loopback, $MariaDbPort).Wait(1000)
    } catch [AggregateException] {
        if ($_.Exception.GetBaseException() -is [Net.Sockets.SocketException]) { return $false }
        throw
    } finally {
        $tcp.Dispose()
    }
}
function Open-OrchidDatabase {
    if (-not (Test-OrchidDatabaseListener)) {
        Assert-OrchidDatabaseCanStart
        $script:MariaDbProcess = Start-Process -FilePath $MariaDbServer `
            -ArgumentList "--no-defaults --basedir=`"$MariaDbRoot`" --datadir=`"$MariaDbData`" --port=$MariaDbPort --bind-address=127.0.0.1 --console" `
            -WorkingDirectory $AppRoot -RedirectStandardOutput $MariaDbServerLogPath -RedirectStandardError $MariaDbServerErrorLogPath -PassThru -WindowStyle Hidden
        # Retain the handle: Windows PowerShell otherwise may lose ExitCode after exit.
        $null = $script:MariaDbProcess.Handle
        $script:StartedMariaDb = $true
        $ready = $false
        for ($attempt=0; $attempt -lt 30; $attempt++) {
            if ($MariaDbProcess.HasExited) { throw 'Selected MariaDB exited before becoming ready; inspect its log.' }
            try { Assert-DatabaseIdentity; $ready=$true; break } catch { Start-Sleep -Seconds 1 }
        }
        if (-not $ready) { throw 'Selected MariaDB did not become ready with the required directory identity.' }
    }
    Assert-DatabaseIdentity
}
function Stop-OrchidDatabase {
    if (-not $StartedMariaDb -or $null -eq $MariaDbProcess) { return }
    if ($MariaDbProcess.HasExited) {
        if ($MariaDbProcess.ExitCode -ne 0) { throw 'MariaDB exited abnormally; do not copy its raw files.' }
        return
    }
    Assert-DatabaseIdentity
    $previous = $env:MYSQL_PWD
    try {
        $env:MYSQL_PWD = 'orchid_shutdown'
        & $MariaDbAdmin --no-defaults --protocol=TCP --host=127.0.0.1 "--port=$MariaDbPort" --user=orchid_shutdown --connect-timeout=5 shutdown | Out-Null
        if ($LASTEXITCODE -ne 0 -or -not $MariaDbProcess.WaitForExit(30000) -or $MariaDbProcess.ExitCode -ne 0) {
            throw 'MariaDB did not stop cleanly. Backup/migration must stop; retain staging/logs.'
        }
        $script:StartedMariaDb = $false
    }
    finally { $env:MYSQL_PWD = $previous }
}
function Get-PhotoReferences {
    Invoke-OrchidQuery @"
SELECT CONCAT('plants/',plantId,'/',fileName) FROM orchids.plantphoto WHERE isActive=1
UNION SELECT CONCAT('plants/',plantId,'/',thumbnailFileName) FROM orchids.plantphoto WHERE isActive=1 AND thumbnailFileName IS NOT NULL AND thumbnailFileName<>''
UNION SELECT CONCAT('taxa/',taxonId,'/',fileName) FROM orchids.taxonphoto WHERE isActive=1
UNION SELECT CONCAT('taxa/',taxonId,'/',thumbnailFileName) FROM orchids.taxonphoto WHERE isActive=1 AND thumbnailFileName<>'';
"@
}
function Assert-PhotoFiles([string]$Root) {
    foreach ($relative in @(Get-PhotoReferences)) {
        if ($relative -match '(^|[\\/])\.\.([\\/]|$)' -or [IO.Path]::IsPathRooted($relative)) { throw 'Unsafe database photo reference.' }
        $file = Join-Path $Root $relative
        Assert-ChildPath $file $Root
        if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw "Backup/restore photo is missing: $relative" }
    }
}
function Get-PayloadFiles([string]$Root) {
    foreach ($name in @('orchids.sql','schemaversion.txt','uploads','launcher-settings')) {
        $path = Join-Path $Root $name
        if (Test-Path -LiteralPath $path -PathType Leaf) { Get-Item -LiteralPath $path }
        elseif (Test-Path -LiteralPath $path -PathType Container) { Get-ChildItem -LiteralPath $path -Recurse -File -Force }
    }
}
function Read-BackupJsonObject([string]$Path) {
    $text=Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    if (-not $text.TrimStart().StartsWith('{')) { throw 'Backup metadata/settings must be a JSON object.' }
    $text | ConvertFrom-Json
}
function Read-BackupPayload([string]$Root) {
    $manifestFile = Join-Path $Root 'manifest.json'; $sql = Join-Path $Root 'orchids.sql'
    if (-not (Test-Path -LiteralPath $manifestFile -PathType Leaf) -or -not (Test-Path -LiteralPath $sql -PathType Leaf) -or (Get-Item -LiteralPath $sql -Force).Length -eq 0) { throw 'Backup requires manifest.json and nonempty orchids.sql.' }
    $manifest = Read-BackupJsonObject $manifestFile
    if ($manifest.database -cne 'orchids' -or $manifest.databaseBackup -cne 'orchids.sql') { throw 'Backup manifest database/payload is incompatible.' }
    $version = 1
    if ($null -ne $manifest.formatVersion) {
        if ([string]$manifest.formatVersion -notin @('1','2')) { throw 'Unsupported backup formatVersion.' }
        $version = [int]$manifest.formatVersion
    }
    if ($version -notin @(1,2)) { throw 'Unsupported backup formatVersion.' }
    $nested = Join-Path $Root 'launcher-settings/launcher-settings.json'; $legacy = Join-Path $Root 'launcher-settings.json'; $settings = $null
    if (Test-Path -LiteralPath $nested -PathType Leaf) { $settings = $nested }
    if (Test-Path -LiteralPath $legacy -PathType Leaf) {
        if ($settings -and (Get-FileHash -LiteralPath $settings).Hash -ne (Get-FileHash -LiteralPath $legacy).Hash) { throw 'Backup has conflicting launcher settings layouts.' }
        if (-not $settings) { $settings = $legacy }
    }
    if ($settings) {
        $settingsObject = Read-BackupJsonObject $settings
        if ($null -eq $settingsObject -or $settingsObject -is [Array] -or $settingsObject -is [string] -or $settingsObject -is [ValueType]) { throw 'Launcher settings must be a JSON object.' }
        if ($null -ne $settingsObject.CloudBackupFolderPath -and $settingsObject.CloudBackupFolderPath -isnot [string]) { throw 'Launcher cloud-folder setting must be a string or null.' }
    }
    elseif ($version -eq 1 -and $manifest.launcherSettingsIncluded -ne $false) {
        throw 'Older backup does not declare whether missing launcher settings were intentional; source review is required.'
    }
    $uploads = Join-Path $Root 'uploads'; $hasUploads = Test-Path -LiteralPath $uploads -PathType Container
    if (-not $hasUploads -and -not ($manifest.uploadsIncluded -eq $false -and $null -ne $manifest.uploadsFileCount -and [int]$manifest.uploadsFileCount -eq 0)) { throw 'Backup uploads are missing or absence is not explicitly declared empty.' }
    $count = @(Get-ChildItem -LiteralPath $uploads -Recurse -File -Force -ErrorAction SilentlyContinue).Count
    if ($null -eq $manifest.uploadsFileCount -or $count -ne [int]$manifest.uploadsFileCount) { throw 'Backup upload count does not match its manifest.' }
    if ($version -eq 2) {
        if ($manifest.launcherSettingsIncluded -isnot [bool] -or [bool]$settings -ne $manifest.launcherSettingsIncluded) { throw 'Backup settings presence does not match its manifest.' }
        if (-not $hasUploads) { throw 'Version 2 backup requires an uploads directory, even if empty.' }
        $seen = @{}
        foreach ($entry in @($manifest.files)) {
            $relative = [string]$entry.path
            if (-not $relative -or $relative.Contains('\') -or $relative -match '(^|/)\.\.(/|$)' -or [IO.Path]::IsPathRooted($relative) -or $relative -eq 'manifest.json' -or $seen.ContainsKey($relative)) { throw 'Invalid or duplicated backup inventory path.' }
            $seen[$relative]=$true; $file = Join-Path $Root $relative
            Assert-ChildPath $file $Root
            if (-not (Test-Path -LiteralPath $file -PathType Leaf) -or (Get-Item -LiteralPath $file -Force).Length -ne [long]$entry.length -or (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash -ine [string]$entry.sha256) { throw "Backup payload missing or checksum changed: $relative" }
        }
        $actual = @(Get-ChildItem -LiteralPath $Root -Recurse -File -Force | Where-Object FullName -ne $manifestFile)
        if ($actual.Count -ne $seen.Count) { throw 'Backup inventory does not cover the archive.' }
        foreach ($file in $actual) {
            $relative = $file.FullName.Substring($Root.TrimEnd('\','/').Length+1).Replace('\','/')
            if (-not $seen.ContainsKey($relative)) { throw 'Backup inventory does not cover the archive.' }
        }
        if (-not $seen.ContainsKey('orchids.sql') -or -not $seen.ContainsKey('schemaversion.txt')) { throw 'Backup inventory lacks required database metadata.' }
    }
    [pscustomobject]@{ Manifest=$manifest; Settings=$settings; Uploads=$uploads; HasUploads=$hasUploads }
}
function Expand-CheckedBackup([string]$Zip, [string]$Destination) {
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [IO.Compression.ZipFile]::OpenRead($Zip)
    try {
        $seen = @{}
        foreach ($entry in $archive.Entries) {
            $name=$entry.FullName.Replace('\','/')
            if (-not $name -or $name -match '(^|/)\.\.(/|$)' -or $name.StartsWith('/') -or $name.Contains(':') -or $seen.ContainsKey($name.TrimEnd('/')) -or (($entry.ExternalAttributes -shr 16) -band 0xF000) -eq 0xA000) { throw 'Unsafe or duplicate backup archive entry.' }
            $seen[$name.TrimEnd('/')]=$true
        }
    }
    finally { $archive.Dispose() }
    Expand-Archive -LiteralPath $Zip -DestinationPath $Destination -Force
}

function New-OrchidBackupArchive([string]$PayloadRoot,[string]$Zip) {
    Assert-NoPathAlias $PayloadRoot
    Assert-NoPathAlias (Split-Path -Parent ([IO.Path]::GetFullPath($Zip)))
    $prefix=(Get-FullLocalPath $PayloadRoot)+[IO.Path]::DirectorySeparatorChar
    if ([IO.Path]::GetFullPath($Zip).StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)) { throw 'Archive output must be outside the payload.' }
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    # Compress-Archive drops empty directories and hidden files; both belong to the payload.
    [IO.Compression.ZipFile]::CreateFromDirectory($PayloadRoot,$Zip,[IO.Compression.CompressionLevel]::Optimal,$false)
}
