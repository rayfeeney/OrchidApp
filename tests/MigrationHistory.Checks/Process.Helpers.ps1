# Test-only child-process protocol. Compare the actual exception message, never
# PowerShell's terminal-formatted error view (which wraps and inserts gutters).
function Invoke-CheckProcess([string]$Pwsh, [string]$Script, [AllowEmptyCollection()][string[]]$Arguments) {
    $request = @{ script = $Script; arguments = @($Arguments) } | ConvertTo-Json -Compress -Depth 4
    $payload = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($request))
    $wrapper = @'
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
try {
    $request = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('__PAYLOAD__')) | ConvertFrom-Json
    [string[]]$scriptArguments = @($request.arguments)
    # Array splatting is positional; bind the checks' declared named/switch
    # parameters explicitly rather than treating '-MigrationFolder' as data.
    $command = Get-Command -Name $request.script -CommandType ExternalScript -ErrorAction Stop
    $named = @{}
    $positional = [Collections.Generic.List[object]]::new()
    for ($i = 0; $i -lt $scriptArguments.Count; $i++) {
        $argument = $scriptArguments[$i]
        if ($argument -match '^-(?<parameter>[A-Za-z][A-Za-z0-9_]*)$' -and $command.Parameters.ContainsKey($Matches.parameter)) {
            $name = $Matches.parameter
            if ($named.ContainsKey($name)) { throw "Duplicate check argument: $name" }
            if ($command.Parameters[$name].ParameterType -eq [Management.Automation.SwitchParameter]) { $named[$name] = $true }
            else {
                $i++
                if ($i -ge $scriptArguments.Count) { throw "Missing check argument value: $name" }
                $named[$name] = $scriptArguments[$i]
            }
        }
        else { $positional.Add($argument) }
    }
    [object[]]$positionalArguments = $positional.ToArray()
    & $request.script @named @positionalArguments
    [Console]::Out.WriteLine('ORCHID_CHECK_RESULT:' + (@{ success = $true; message = '' } | ConvertTo-Json -Compress))
    exit 0
}
catch {
    [Console]::Out.WriteLine('ORCHID_CHECK_RESULT:' + (@{ success = $false; message = $_.Exception.Message } | ConvertTo-Json -Compress))
    exit 1
}
'@
    # Base64 embeds data safely without interpolating paths/arguments as code.
    $wrapper = $wrapper.Replace('__PAYLOAD__', $payload)
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($wrapper))
    $output = & $Pwsh -NoProfile -NonInteractive -OutputFormat Text -EncodedCommand $encoded 2>&1
    $code = $LASTEXITCODE
    $prefix = 'ORCHID_CHECK_RESULT:'
    $records = @($output | ForEach-Object { [string]$_ } | Where-Object { $_.StartsWith($prefix, [StringComparison]::Ordinal) })
    if ($records.Count -ne 1) { throw "Child check did not return exactly one structured result; exit=$code; $($output -join "`n")" }
    $record = $records[0].Substring($prefix.Length) | ConvertFrom-Json
    if (($code -eq 0) -ne [bool]$record.success) { throw 'Child exit code disagrees with its structured result.' }
    [pscustomobject]@{ ExitCode = $code; Success = [bool]$record.success; Message = [string]$record.message; Output = ($output -join "`n") }
}
