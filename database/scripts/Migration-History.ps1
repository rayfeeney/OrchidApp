. (Join-Path $PSScriptRoot 'Schema-Baseline.ps1')

function Get-MigrationTimestamp([string]$Name) {
    if ($Name.Length -gt 255 -or $Name -cnotmatch '^[0-9]{12}_[A-Za-z0-9_]+\.sql$' -or
        -not (Test-BaselineTimestamp $Name.Substring(0,12))) { throw "Invalid migration filename: $Name" }
    $Name.Substring(0,12)
}

function Get-MigrationFileChecksum([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }

function Get-MigrationPlan([AllowEmptyCollection()][string[]]$Files, [hashtable]$History) {
    $cutoff = Get-DatabaseBaselineCutoff $History
    $byName = @{}; $timestamps = @{}
    function Register-MigrationName([string]$Name) {
        $stamp = Get-MigrationTimestamp $Name
        if ($timestamps.ContainsKey($stamp) -and $timestamps[$stamp] -cne $Name) {
            throw "Duplicate migration timestamp ${stamp}: $($timestamps[$stamp]) / $Name"
        }
        $timestamps[$stamp] = $Name
    }
    foreach ($path in $Files) {
        $name = [IO.Path]::GetFileName($path)
        Register-MigrationName $name
        if ($byName.ContainsKey($name)) { throw "Duplicate migration file: $name" }
        $byName[$name] = $path
    }
    $applied = @($History.GetEnumerator() | Where-Object { -not $_.Key.StartsWith('baseline', [StringComparison]::OrdinalIgnoreCase) })
    if ($History.ContainsKey('baseline') -and $applied.Count -eq 0 -and $byName.Count -gt 0) {
        throw 'Legacy baseline has no recorded migration ledger; review compatibility before upgrading.'
    }
    $latest = $cutoff
    foreach ($row in $applied) {
        Register-MigrationName $row.Key
        $stamp = Get-MigrationTimestamp $row.Key
        if ($row.Value -cnotmatch '^[a-fA-F0-9]{64}$') { throw "Invalid recorded migration checksum: $($row.Key)" }
        if ($byName.ContainsKey($row.Key)) {
            if ((Get-MigrationFileChecksum $byName[$row.Key]) -ne $row.Value) { throw "Applied migration checksum changed: $($row.Key)" }
        }
        elseif (-not $cutoff -or [string]::CompareOrdinal($stamp, $cutoff) -gt 0) { throw "Applied migration file is missing: $($row.Key)" }
        if (-not $latest -or [string]::CompareOrdinal($stamp, $latest) -gt 0) { $latest = $stamp }
    }
    foreach ($name in ($byName.Keys | Sort-Object -CaseSensitive)) {
        $stamp = Get-MigrationTimestamp $name
        if ($History.ContainsKey($name) -or ($cutoff -and [string]::CompareOrdinal($stamp, $cutoff) -le 0)) { continue }
        if ($latest -and [string]::CompareOrdinal($stamp, $latest) -le 0) { throw "Backdated or out-of-order pending migration: $name" }
        $bytes = [IO.File]::ReadAllBytes($byName[$name])
        $sha = [Security.Cryptography.SHA256]::Create()
        try { $checksum = [BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-', '').ToLowerInvariant() }
        finally { $sha.Dispose() }
        $sql = [Text.UTF8Encoding]::new($false, $true).GetString($bytes).TrimStart([char]0xFEFF)
        [pscustomobject]@{ Path = $byName[$name]; Name = $name; Timestamp = $stamp; Checksum = $checksum; Sql = $sql }
    }
}

function Get-MigrationFiles([string]$Folder) {
    if (-not (Test-Path -LiteralPath $Folder -PathType Container)) { throw "Required migration directory missing: $Folder" }
    Get-ChildItem -LiteralPath $Folder -File | Where-Object { $_.Extension.Equals('.sql', [StringComparison]::OrdinalIgnoreCase) } | ForEach-Object FullName
}
