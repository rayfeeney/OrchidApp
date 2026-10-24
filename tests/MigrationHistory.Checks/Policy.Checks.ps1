param([string]$RepoRoot = (Join-Path $PSScriptRoot '../..'))
$ErrorActionPreference = 'Stop'
. (Join-Path $RepoRoot 'database/scripts/Migration-History.ps1')
$tests = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'Fixtures/policy.json') -Raw -Encoding utf8 | ConvertFrom-Json
$temporary = Join-Path ([IO.Path]::GetTempPath()) ('orchids-migration-policy-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temporary | Out-Null
$count = 0
try {
    foreach ($test in $tests) {
        $folder = Join-Path $temporary ([string]$count)
        New-Item -ItemType Directory -Path $folder | Out-Null
        $files = @()
        foreach ($file in $test.files) {
            $path = Join-Path $folder $file.name
            [IO.File]::WriteAllText($path, $file.sql, [Text.UTF8Encoding]::new($false))
            $files += $path
        }
        $history = @{}
        foreach ($row in $test.history) {
            $history[$row.name] = if ($row.PSObject.Properties['checksum']) { $row.checksum } else { Get-TextChecksum $row.sql }
        }
        $failure = $null; $plan = @()
        try { $plan = @(Get-MigrationPlan $files $history) } catch { $failure = $_.Exception.Message }
        if ($test.PSObject.Properties['error']) {
            if (-not $failure -or $failure.IndexOf($test.error, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
                throw "$($test.name): expected '$($test.error)', got '$failure'."
            }
        }
        else {
            if ($failure) { throw "$($test.name): $failure" }
            if ((@($plan | ForEach-Object Name) -join '|') -cne ($test.pending -join '|')) { throw "$($test.name): incorrect pending order." }
            foreach ($item in $plan) {
                if ($item.Checksum -ne (Get-MigrationFileChecksum $item.Path) -or $item.Sql -cne [IO.File]::ReadAllText($item.Path)) {
                    throw "$($test.name): SQL/checksum snapshot differs."
                }
            }
        }
        $count++
    }
    $packageFiles=@(Get-MigrationFiles (Join-Path $RepoRoot 'database/migrations'))
    $packageHistory=@{ baseline='baseline' }
    foreach ($file in $packageFiles) { $packageHistory[[IO.Path]::GetFileName($file)]=Get-MigrationFileChecksum $file }
    if (@(Get-MigrationPlan $packageFiles $packageHistory).Count -ne 0) { throw 'Package inventory validation failed.' }
    Write-Host "$count PowerShell migration policy scenarios passed; $($packageFiles.Count) packaged migrations validated."
}
finally {
    $resolved = [IO.Path]::GetFullPath($temporary)
    $parent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar)
    if ([IO.Directory]::GetParent($resolved).FullName.TrimEnd([IO.Path]::DirectorySeparatorChar) -ne $parent -or
        [IO.Path]::GetFileName($resolved) -notlike 'orchids-migration-policy-*') { throw 'Unsafe cleanup path.' }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
