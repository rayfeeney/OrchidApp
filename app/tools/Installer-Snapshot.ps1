# Windows PowerShell 5.1 / PowerShell 7. Offline installer rollback snapshots.
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
function Get-InstallerFullPath([string]$Path) {
    if (-not [IO.Path]::IsPathRooted($Path)) { throw 'An absolute local path is required.' }
    $full=[IO.Path]::GetFullPath($Path).TrimEnd([char[]]@('\','/'))
    if ($full.StartsWith('\\') -or $full.Length -lt 4) { throw 'A local directory below a drive root is required.' }
    $full
}
function Test-InstallerChild([string]$Path,[string]$Parent) {
    (Get-InstallerFullPath $Path).StartsWith((Get-InstallerFullPath $Parent)+'\',[StringComparison]::OrdinalIgnoreCase)
}
function Assert-InstallerPath([string]$Path) {
    $current=$Path
    while ($current) {
        if (Test-Path -LiteralPath $current) {
            $item=Get-Item -LiteralPath $current -Force
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Snapshot paths must not contain links or reparse points.' }
        }
        $parent=Split-Path -Parent $current
        if ($parent -eq $current) { break };$current=$parent
    }
}
function Get-InstallerFiles([string]$Root,[string]$Prefix) {
    if (-not (Test-Path -LiteralPath $Root)) { return }
    Assert-InstallerPath $Root
    $pending=New-Object 'Collections.Generic.Stack[string]';$pending.Push($Root)
    while ($pending.Count) {
        $directory=$pending.Pop()
        foreach ($item in Get-ChildItem -LiteralPath $directory -Force -ErrorAction Stop) {
            # Existing backup history stays in place and must not recurse into this snapshot.
            if ($directory -ieq $Root -and $item.Name -ieq 'backups' -and $item.PSIsContainer) { continue }
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Snapshot source contains a link or reparse point.' }
            if ($item.PSIsContainer) { $pending.Push($item.FullName) }
            else { [pscustomobject]@{source=$item.FullName;path=$Prefix+'/'+$item.FullName.Substring($Root.Length+1).Replace('\','/')} }
        }
    }
}
function Assert-InstallerStopped([string]$AppRoot,[string]$PersistentRoot,[int]$InstallerProcessId) {
    # Do not kill a database. The owner must close the launcher and stop other writers.
    foreach ($process in Get-CimInstance Win32_Process -ErrorAction Stop) {
        if ($process.ProcessId -eq $PID -or $process.ProcessId -eq $InstallerProcessId) { continue }
        $exe=[string]$process.ExecutablePath;$command=[string]$process.CommandLine
        if (($exe -and (Test-InstallerChild $exe $AppRoot)) -or
            ($process.Name -match '^(dotnet|powershell|pwsh|mariadbd|mysqld|OrchidApp\.Web|OrchidApp\.Launcher)\.exe$' -and $command -and ($command.IndexOf($AppRoot,[StringComparison]::OrdinalIgnoreCase) -ge 0 -or
                            $command.IndexOf($PersistentRoot,[StringComparison]::OrdinalIgnoreCase) -ge 0))) {
            throw 'Close OrchidApp and stop its database, backup and other writers before installing. No process was killed.'
        }
        if (-not $exe -and $process.Name -match '^(OrchidApp.*|mariadbd|mysqld)\.exe$') {
            throw 'A possible OrchidApp/database process cannot be identified. Stop and obtain support before upgrading.'
        }
    }
}
function Assert-InstallerRecoveryState([string]$AppRoot,[string]$PersistentRoot) {
    foreach ($root in @($AppRoot,$PersistentRoot)) {
        if (Test-Path -LiteralPath (Join-Path $root 'restore-pending.json')) { throw 'An interrupted restore requires recovery before installation.' }
        $state=Join-Path $root 'migration-state.json'
        if (Test-Path -LiteralPath $state) {
            $record=Get-Content -LiteralPath $state -Raw | ConvertFrom-Json
            if ($record.SchemaVersion -ne 2 -or $record.MigrationStatus -ne 'Completed' -or $record.Phase -ne 'Completed') {
                throw 'Migration state requires review before installation. Preserve the old installation and its recovery files.'
            }
        }
        foreach ($upload in @('uploads/.photo-recovery','wwwroot/uploads/.photo-recovery')) {
            $folder=Join-Path $root $upload
            if ((Test-Path -LiteralPath $folder) -and @(Get-ChildItem -LiteralPath $folder -Force).Count) {
                throw 'Photo recovery records require review before installation.'
            }
        }
    }
}
function Get-InstallerStreamHash([IO.Stream]$Stream) {
    $sha=[Security.Cryptography.SHA256]::Create()
    try { ([BitConverter]::ToString($sha.ComputeHash($Stream))).Replace('-','').ToLowerInvariant() }
    finally { $sha.Dispose() }
}
function Read-InstallerSnapshot([string]$Archive) {
    Assert-InstallerPath $Archive
    $zip=[IO.Compression.ZipFile]::OpenRead($Archive)
    try {
        $entry=$zip.GetEntry('installer-snapshot.json')
        if (-not $entry) { throw 'Not an OrchidApp installer rollback snapshot.' }
        $reader=New-Object IO.StreamReader($entry.Open())
        try { $manifest=$reader.ReadToEnd() | ConvertFrom-Json } finally { $reader.Dispose() }
        if ($manifest.formatVersion -ne 1 -or $manifest.kind -cne 'OrchidAppOfflineInstallerRollback' -or -not $manifest.files) { throw 'Unsupported or empty installer snapshot.' }
        $seen=New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
        foreach ($file in $manifest.files) {
            $name=[string]$file.path
            if ($name -cnotmatch '^(application|persistent)/[^\\:]+$' -or $name.Split('/') -contains '..' -or
                $name.Split('/') -contains '.' -or $name.Contains('//') -or -not $seen.Add($name)) { throw 'Unsafe or duplicate installer snapshot path.' }
            $item=$zip.GetEntry($name)
            if (-not $item -or $item.Length -ne $file.length) { throw 'Installer snapshot file is missing or has changed length.' }
            $stream=$item.Open()
            try { if ((Get-InstallerStreamHash $stream) -cne $file.sha256) { throw 'Installer snapshot checksum mismatch.' } }
            finally { $stream.Dispose() }
        }
        if ($zip.Entries.Count -ne $seen.Count+1) { throw 'Installer snapshot has unlisted entries.' }
        $manifest
    }
    finally { $zip.Dispose() }
}
function New-InstallerSnapshot([string]$AppRoot,[string]$PersistentRoot,[int]$InstallerProcessId) {
    $AppRoot=Get-InstallerFullPath $AppRoot;$PersistentRoot=Get-InstallerFullPath $PersistentRoot
    if ($AppRoot -ieq $PersistentRoot -or (Test-InstallerChild $AppRoot $PersistentRoot) -or (Test-InstallerChild $PersistentRoot $AppRoot)) { throw 'Application and persistent roots must be separate.' }
    Assert-InstallerPath $AppRoot;Assert-InstallerPath $PersistentRoot
    Assert-InstallerStopped $AppRoot $PersistentRoot $InstallerProcessId
    Assert-InstallerRecoveryState $AppRoot $PersistentRoot
    $files=@(@((Get-InstallerFiles $AppRoot 'application');(Get-InstallerFiles $PersistentRoot 'persistent')) | Sort-Object path)
    if (-not $files.Count) { return $null }
    $destination=Join-Path $PersistentRoot 'backups/pre-install'
    Assert-InstallerPath $destination
    $null=New-Item -ItemType Directory -Path $destination -Force
    $archive=Join-Path $destination ('OrchidAppUpgrade-'+[datetime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'-'+[guid]::NewGuid().ToString('N')+'.zip')
    $partial=$archive+'.partial';$handles=New-Object 'Collections.Generic.List[IO.FileStream]'
    try {
        # Deny writes/deletion on every inventoried file throughout capture and verification.
        foreach ($file in $files) { $handles.Add([IO.File]::Open($file.source,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)) }
        $zip=[IO.Compression.ZipFile]::Open($partial,[IO.Compression.ZipArchiveMode]::Create)
        try {
            $entries=@();$number=0
            foreach ($file in $files) {
                $stream=$handles[$number];$number++
                $hash=Get-InstallerStreamHash $stream;$stream.Position=0
                $entry=$zip.CreateEntry($file.path,[IO.Compression.CompressionLevel]::Optimal);$output=$entry.Open()
                try { $stream.CopyTo($output) } finally { $output.Dispose() }
                $entries+=@{path=$file.path;length=$stream.Length;sha256=$hash}
            }
            $manifest=@{formatVersion=1;kind='OrchidAppOfflineInstallerRollback';createdUtc=[datetime]::UtcNow.ToString('o');applicationRoot=$AppRoot;persistentRoot=$PersistentRoot;files=$entries}
            $entry=$zip.CreateEntry('installer-snapshot.json');$writer=New-Object IO.StreamWriter($entry.Open(),(New-Object Text.UTF8Encoding($false)))
            try { $writer.Write(($manifest | ConvertTo-Json -Depth 6)) } finally { $writer.Dispose() }
        } finally { $zip.Dispose() }
        $null=Read-InstallerSnapshot $partial
        Assert-InstallerStopped $AppRoot $PersistentRoot $InstallerProcessId
        Assert-InstallerRecoveryState $AppRoot $PersistentRoot
        $current=@(@((Get-InstallerFiles $AppRoot 'application');(Get-InstallerFiles $PersistentRoot 'persistent')) | Sort-Object path)
        if (@(Compare-Object @($files.path) @($current.path)).Count) { throw 'Snapshot source inventory changed; installation must stop.' }
        [IO.File]::Move($partial,$archive)
        $archive
    }
    finally { foreach ($handle in $handles) { $handle.Dispose() } }
}
function Expand-InstallerSnapshot([string]$Archive,[string]$Destination) {
    $Destination=Get-InstallerFullPath $Destination
    Assert-InstallerPath $Destination
    if (Test-Path -LiteralPath $Destination) { throw 'Recovery extraction requires a new, absent directory. Existing data will not be overwritten.' }
    $manifest=Read-InstallerSnapshot $Archive
    $null=New-Item -ItemType Directory -Path $Destination
    $zip=[IO.Compression.ZipFile]::OpenRead($Archive)
    try {
        foreach ($file in $manifest.files) {
            $path=Join-Path $Destination $file.path
            if (-not (Test-InstallerChild $path $Destination)) { throw 'Recovery target escaped its directory.' }
            $null=New-Item -ItemType Directory -Path (Split-Path -Parent $path) -Force
            $source=$zip.GetEntry($file.path).Open();$output=[IO.File]::Open($path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
            try { $source.CopyTo($output) } finally { $source.Dispose();$output.Dispose() }
            if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -cne $file.sha256) { throw 'Extracted recovery file checksum mismatch. Preserve the staging directory.' }
        }
        $manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $Destination 'installer-snapshot.json') -Encoding UTF8
    }
    finally { $zip.Dispose() }
    $Destination
}
