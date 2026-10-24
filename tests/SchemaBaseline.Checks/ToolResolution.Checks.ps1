param([string]$RepoRoot = (Join-Path $PSScriptRoot '../..'))
$ErrorActionPreference = 'Stop'
. (Join-Path $RepoRoot 'database/scripts/Schema-Baseline.ps1')
$checks = 0
function Check([string]$Name, [bool]$Pass) {
    if (-not $Pass) { throw "Check failed: $Name" }
    $script:checks++
}
$temporary = Join-Path ([IO.Path]::GetTempPath()) ('orchids-tool-resolution-' + [guid]::NewGuid().ToString('N'))
$priorPath = $env:PATH
try {
    $first = Join-Path $temporary 'first path'
    $second = Join-Path $temporary 'second path'
    New-Item -ItemType Directory -Path $first, $second | Out-Null
    $toolName = if ($IsWindows) { 'orchids-resolver-fixture.exe' } else { 'orchids-resolver-fixture' }
    $source = if ($IsWindows) { $env:ComSpec } else { '/bin/echo' }
    $firstTool = Join-Path $first $toolName
    $secondTool = Join-Path $second $toolName
    Copy-Item -LiteralPath $source -Destination $firstTool
    Copy-Item -LiteralPath $source -Destination $secondTool
    if (-not $IsWindows) { & chmod +x $firstTool $secondTool; if ($LASTEXITCODE -ne 0) { throw 'Fixture chmod failed.' } }
    $env:PATH = $first + [IO.Path]::PathSeparator + $second + [IO.Path]::PathSeparator + $priorPath
    Check 'Fixture exposes multiple application matches' (@(Get-Command $toolName -CommandType Application -All).Count -eq 2)
    $resolved = Resolve-MariaDbTool -Name $toolName
    Check 'Resolution returns one string' ($resolved -is [string] -and @($resolved).Count -eq 1)
    Check 'First PATH entry wins' ($resolved -ceq $firstTool)
    $invokeArguments = if ($IsWindows) { @('/d', '/c', 'echo resolver-ok') } else { @('resolver-ok') }
    $result = & $resolved @invokeArguments
    Check 'Resolved tool executes with spaces in its path' ($LASTEXITCODE -eq 0 -and $result.Trim() -eq 'resolver-ok')
    $overridden = Resolve-MariaDbTool -Name $toolName -Override $secondTool
    Check 'Explicit override wins over PATH' ($overridden -is [string] -and $overridden -ceq $secondTool)
    $byName = Resolve-MariaDbTool -Override $toolName
    Check 'Override by command name also returns one path' ($byName -is [string] -and $byName -ceq $firstTool)
    try { $null = Resolve-MariaDbTool -Override (Join-Path $temporary 'missing-tool'); throw 'Invalid override was accepted.' }
    catch [System.Management.Automation.CommandNotFoundException] { $checks++ }
    Write-Host "$checks tool resolution checks passed."
}
finally {
    $env:PATH = $priorPath
    $resolvedTemporary = [IO.Path]::GetFullPath($temporary)
    $expectedParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar)
    if ([IO.Directory]::GetParent($resolvedTemporary).FullName.TrimEnd([IO.Path]::DirectorySeparatorChar) -ne $expectedParent -or
        [IO.Path]::GetFileName($resolvedTemporary) -notlike 'orchids-tool-resolution-*') { throw 'Unsafe test cleanup path.' }
    if (Test-Path -LiteralPath $resolvedTemporary) { Remove-Item -LiteralPath $resolvedTemporary -Recurse -Force }
}
