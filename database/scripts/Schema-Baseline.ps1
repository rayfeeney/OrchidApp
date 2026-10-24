# Shared schema-only creation and baseline contract (PowerShell 7+).
function Get-TextChecksum([string]$Text) {
    $bytes = [Text.Encoding]::UTF8.GetBytes($Text.Replace("`r`n", "`n").Replace("`r", "`n"))
    $sha = [Security.Cryptography.SHA256]::Create()
    try { [BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-', '').ToLowerInvariant() }
    finally { $sha.Dispose() }
}

function Test-BaselineTimestamp([string]$Value) {
    $parsedDate = [datetime]::MinValue
    $Value -cmatch '^[0-9]{12}$' -and [datetime]::TryParseExact($Value, 'yyyyMMddHHmm',
        [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$parsedDate)
}

function Read-SchemaManifest([string]$SchemaRoot) {
    $text = Get-Content -LiteralPath (Join-Path $SchemaRoot 'bootstrap.json') -Raw -Encoding utf8
    $plan = $text | ConvertFrom-Json
    if ($plan.formatVersion -ne 1 -or -not (Test-BaselineTimestamp $plan.throughMigration)) {
        throw 'Unsupported schema baseline format or cut-off.'
    }
    $stages = @('tables', 'constraints', 'routines', 'views', 'triggers', 'seeds')
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $previousStage = -1
    foreach ($item in $plan.files) {
        if ($item.path -cnotmatch '^[a-z]+/[A-Za-z0-9_]+\.sql$') { throw "Unsafe schema path: $($item.path)" }
        $stage = [Array]::IndexOf($stages, $item.path.Split('/')[0])
        if ($stage -lt 0 -or $stage -lt $previousStage -or -not $seen.Add($item.path)) {
            throw "Invalid schema order or duplicate file: $($item.path)"
        }
        $previousStage = $stage
        $file = Join-Path $SchemaRoot $item.path
        if (-not (Test-Path -LiteralPath $file -PathType Leaf) -or
            (Get-TextChecksum (Get-Content -LiteralPath $file -Raw -Encoding utf8)) -ne $item.sha256) {
            throw "Schema file missing or changed: $($item.path)"
        }
    }
    $actual = @(Get-ChildItem -LiteralPath $SchemaRoot -Recurse -File -Filter '*.sql' | ForEach-Object {
        [IO.Path]::GetRelativePath($SchemaRoot, $_.FullName).Replace('\', '/')
    })
    if (-not $seen.SetEquals([string[]]$actual)) { throw 'Schema manifest does not cover the complete schema.' }
    foreach ($stage in $stages) {
        if (-not @($seen | Where-Object { $_.StartsWith($stage + '/', [StringComparison]::Ordinal) }).Count) {
            throw "Required schema stage is empty: $stage"
        }
    }
    foreach ($required in @('tables/schemaversion.sql', 'seeds/observationtype_records.sql', 'seeds/phoneticprefix_records.sql', 'seeds/propagationtype_records.sql')) {
        if (-not $seen.Contains($required)) { throw "Required schema input missing: $required" }
    }
    $plan | Add-Member -NotePropertyName manifestChecksum -NotePropertyValue (Get-TextChecksum $text)
    $plan
}

function Get-DatabaseBaselineCutoff([hashtable]$History) {
    if ($History.Count -eq 0) { throw 'Database setup is incomplete: migration history is empty. Restore or recreate an explicitly disposable target.' }
    $incomplete = @($History.Keys | Where-Object { $_.StartsWith('migration:', [StringComparison]::OrdinalIgnoreCase) })
    if ($incomplete.Count) { throw "An incomplete or running migration requires review ($($incomplete[0]), checksum $($History[$incomplete[0]])). SQL may be partially applied. Do not automatically retry; inspect the earlier error and restore a verified pre-migration backup when needed." }
    $markers = @($History.Keys | Where-Object { $_ -like 'baseline*' })
    if ($markers.Count -gt 1) { throw 'Multiple database baseline markers require review.' }
    if ($markers.Count -eq 0) { return $null }
    $marker = $markers[0]
    if ($marker -ceq 'baseline' -and $History[$marker] -ceq 'baseline') { return $null }
    if ($marker -cnotmatch '^baseline:v1:([0-9]{12})$' -or
        -not (Test-BaselineTimestamp $marker.Substring(12)) -or $History[$marker] -cnotmatch '^[a-fA-F0-9]{64}$') {
        throw 'Unrecognised database baseline marker.'
    }
    $marker.Substring(12)
}

function Test-MigrationCovered([string]$Name, [string]$Cutoff) {
    if ($Name -cnotmatch '^[0-9]{12}_[A-Za-z0-9_]+\.sql$' -or -not (Test-BaselineTimestamp $Name.Substring(0,12))) {
        throw "Invalid migration filename: $Name"
    }
    $Cutoff -and [string]::CompareOrdinal($Name.Substring(0,12), $Cutoff) -le 0
}

function Resolve-MariaDbTool([string]$Name = 'mariadb', [string]$Override = '') {
    if ($Override) {
        $tool = Get-Command $Override -CommandType Application -ErrorAction Stop | Select-Object -First 1
        return $tool.Source
    }
    # Get-Command can emit every application match (e.g. /usr/bin and /bin).
    # Return one executable in PATH order, never an array of joined paths.
    $tool = Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($tool) { return $tool.Source }
    if ($IsWindows) {
        $fallback = Join-Path $env:ProgramFiles "MariaDB 10.11/bin/$Name.exe"
        if (Test-Path -LiteralPath $fallback -PathType Leaf) { return $fallback }
    }
    throw "MariaDB tool '$Name' not found. Install it on PATH or supply an explicit executable."
}
