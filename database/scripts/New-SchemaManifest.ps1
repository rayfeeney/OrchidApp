param(
    [string]$SchemaRoot = (Join-Path $PSScriptRoot '../schema'),
    [Parameter(Mandatory)][string]$ThroughMigration
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Schema-Baseline.ps1')
if (-not (Test-BaselineTimestamp $ThroughMigration)) { throw 'ThroughMigration must be a valid YYYYMMDDHHMM cut-off.' }
$SchemaRoot = (Resolve-Path -LiteralPath $SchemaRoot).Path
$entries = [Collections.Generic.List[object]]::new()
foreach ($stage in @('tables', 'constraints', 'routines', 'views', 'triggers', 'seeds')) {
    $files = @(Get-ChildItem -LiteralPath (Join-Path $SchemaRoot $stage) -Filter '*.sql' -File | Sort-Object Name -CaseSensitive)
    if (-not $files.Count) { throw "Required schema stage empty: $stage" }
    if ($stage -eq 'views') {
        # Conservatively treat any quoted view identifier as a dependency. The
        # exporter emits quoted identifiers; reject cycles instead of guessing.
        $pending = @{}; $ordered = [Collections.Generic.List[object]]::new()
        foreach ($file in $files) {
            $sql = Get-Content -LiteralPath $file.FullName -Raw -Encoding utf8
            $dependencies = @($files | Where-Object { $_.Name -cne $file.Name -and
                $sql -match ('(?i)`' + [regex]::Escape($_.BaseName) + '`') } | ForEach-Object Name)
            $pending[$file.Name] = @{ file = $file; dependencies = $dependencies }
        }
        while ($pending.Count) {
            $ready = @($pending.Keys | Where-Object {
                @($pending[$_].dependencies | Where-Object { $pending.ContainsKey($_) }).Count -eq 0
            } | Sort-Object -CaseSensitive)
            if (-not $ready.Count) { throw "Cyclic view dependencies: $($pending.Keys -join ', ')" }
            foreach ($name in $ready) { $ordered.Add($pending[$name].file); $pending.Remove($name) }
        }
        $files = $ordered.ToArray()
    }
    foreach ($file in $files) {
        $entries.Add([ordered]@{ path = "$stage/$($file.Name)"; sha256 = Get-TextChecksum (Get-Content -LiteralPath $file.FullName -Raw -Encoding utf8) })
    }
}
$manifest = [ordered]@{ formatVersion = 1; throughMigration = $ThroughMigration; files = $entries.ToArray() }
$json = ($manifest | ConvertTo-Json -Depth 5).Replace("`r`n", "`n") + "`n"
[IO.File]::WriteAllText((Join-Path $SchemaRoot 'bootstrap.json'), $json, [Text.UTF8Encoding]::new($false))
$null = Read-SchemaManifest $SchemaRoot
Write-Host "Generated schema manifest through $ThroughMigration ($($entries.Count) SQL files)."
