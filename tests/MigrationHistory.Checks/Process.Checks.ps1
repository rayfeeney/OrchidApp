$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Process.Helpers.ps1')
$pwsh = (Get-Command pwsh -CommandType Application | Select-Object -First 1).Source
$temporary = Join-Path ([IO.Path]::GetTempPath()) ('orchids-check-process-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temporary | Out-Null
$count = 0
function Check([string]$Name, [bool]$Pass) { if (-not $Pass) { throw "Check failed: $Name" }; $script:count++ }
try {
    # This is the exact presentation split in the reported Linux CI error.
    $formatted = "Migration failed. SQL`n     | may be partially applied; no automatic DDL rollback is promised."
    Check 'Reported formatted text breaks the old assertion' ($formatted.IndexOf('SQL may be partially applied', [StringComparison]::OrdinalIgnoreCase) -lt 0)
    $script = Join-Path $temporary 'fixture with spaces.ps1'
    [IO.File]::WriteAllText($script, @'
param([string]$Message)
$ErrorView = 'ConciseView'
$PSStyle.OutputRendering = 'Ansi'
Write-Host 'Fixture diagnostic output before exception'
throw $Message
'@, [Text.UTF8Encoding]::new($false))
    $message = ('Long diagnostic prefix. ' * 25) + "SQL may be partially applied; no automatic DDL rollback is promised.`nSecond line with a | gutter character, quotes `"here`" and Unicode: café."
    $failure = Invoke-CheckProcess $pwsh $script @('-Message', $message)
    Check 'Exception returns failure exit code' ($failure.ExitCode -eq 1 -and -not $failure.Success)
    Check 'Full exception survives unchanged' ($failure.Message -ceq $message)
    Check 'Semantic assertion ignores terminal wrapping' ($failure.Message.Contains('SQL may be partially applied'))
    Check 'Unrelated error cannot match' (-not $failure.Message.Contains('Duplicate migration timestamp'))
    [IO.File]::WriteAllText($script, "param([string]`$Value)`nWrite-Host 'Success fixture diagnostics'`nif (`$Value -cne 'one argument') { throw 'Argument split'; }", [Text.UTF8Encoding]::new($false))
    $success = Invoke-CheckProcess $pwsh $script @('one argument')
    Check 'Successful script returns success' ($success.ExitCode -eq 0 -and $success.Success -and $success.Message -eq '')
    Check 'Diagnostic output is preserved' ($success.Output.Contains('Success fixture diagnostics'))
    [IO.File]::WriteAllText($script, 'return', [Text.UTF8Encoding]::new($false))
    $empty = Invoke-CheckProcess $pwsh $script @()
    Check 'Empty arguments and script return are supported' ($empty.Success)
    [IO.File]::WriteAllText($script, "param([string]`$Folder,[switch]`$PlanOnly)`nif (-not `$PlanOnly) { throw 'Switch missing'; }`nif (`$Folder -cne 'folder with spaces') { throw 'Named value split'; }", [Text.UTF8Encoding]::new($false))
    $switch = Invoke-CheckProcess $pwsh $script @('-Folder','folder with spaces','-PlanOnly')
    Check 'Named values and switches are bound correctly' ($switch.Success)
    $missingSwitch = Invoke-CheckProcess $pwsh $script @('-Folder','folder with spaces')
    Check 'Omitted switches remain false' (-not $missingSwitch.Success -and $missingSwitch.Message -ceq 'Switch missing')
    Write-Host "$count child-process protocol checks passed."
}
finally {
    $resolved = [IO.Path]::GetFullPath($temporary)
    $parent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar)
    if ([IO.Directory]::GetParent($resolved).FullName.TrimEnd([IO.Path]::DirectorySeparatorChar) -ne $parent -or
        [IO.Path]::GetFileName($resolved) -notlike 'orchids-check-process-*') { throw 'Unsafe cleanup path.' }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
