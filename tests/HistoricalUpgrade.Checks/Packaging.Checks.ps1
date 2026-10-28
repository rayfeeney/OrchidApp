param([string]$RepoRoot=(Join-Path $PSScriptRoot '../..'))
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath($RepoRoot)
$temp=Join-Path $root ('artifacts/historical-upgrade/package-policy-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temp -Force | Out-Null
$props=Join-Path $root 'Directory.Build.props'
$before=(Get-FileHash -LiteralPath $props).Hash
$script=Join-Path $root 'scripts/package-linuxpi.ps1'
$count=0
try {
    function global:dotnet { $global:LASTEXITCODE=42 }
    $failure=$null
    try { & $script -NoVersionStamp -OutputRoot (Join-Path $temp 'failed-publish') }
    catch { $failure=$_.Exception.Message }
    if (-not $failure -or $failure -notlike '*publish failed*') { throw "Failed publish was not rejected: $failure" }
    if (@(Get-ChildItem -LiteralPath $temp -Recurse -Filter '*.zip').Count) { throw 'Failed publish produced a ZIP.' }
    $count++
    $existing=Join-Path $temp 'existing';New-Item -ItemType Directory -Path $existing | Out-Null
    $witness=Join-Path $existing 'keep.txt';[IO.File]::WriteAllText($witness,'retain existing output')
    $failure=$null
    try { & $script -NoVersionStamp -OutputRoot $existing }
    catch { $failure=$_.Exception.Message }
    if (-not $failure -or $failure -notlike '*must be absent*' -or
        [IO.File]::ReadAllText($witness) -cne 'retain existing output') { throw 'Existing explicit output was not protected.' }
    $count++
    if ((Get-FileHash -LiteralPath $props).Hash -cne $before) { throw 'NoVersionStamp changed tracked version properties.' }
    $count++
    Write-Host "$count Linux package policy checks passed."
}
finally {
    Remove-Item Function:global:dotnet -ErrorAction SilentlyContinue
    $parent=[IO.Path]::GetFullPath((Join-Path $root 'artifacts/historical-upgrade'))
    if ([IO.Directory]::GetParent([IO.Path]::GetFullPath($temp)).FullName -cne $parent -or
        [IO.Path]::GetFileName($temp) -notlike 'package-policy-*') { throw 'Unsafe package test cleanup.' }
    Remove-Item -LiteralPath $temp -Recurse -Force
}
