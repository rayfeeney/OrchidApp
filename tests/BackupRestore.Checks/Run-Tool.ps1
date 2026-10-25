# File-based child harness: no encoded command or generated executable script.
param([Parameter(Mandatory=$true)][string]$RequestFile)
$ErrorActionPreference='Stop'
try {
    $request=Get-Content -LiteralPath $RequestFile -Raw -Encoding UTF8 | ConvertFrom-Json
    $command=Get-Command -Name $request.script -CommandType ExternalScript -ErrorAction Stop
    [string[]]$arguments=@($request.arguments)
    $named=@{}
    for ($i=0;$i -lt $arguments.Count;$i++) {
        $name=$arguments[$i].TrimStart('-')
        if (-not $arguments[$i].StartsWith('-') -or -not $command.Parameters.ContainsKey($name) -or $named.ContainsKey($name)) { throw 'Invalid fixture script parameter.' }
        if ($command.Parameters[$name].ParameterType -eq [Management.Automation.SwitchParameter]) { $named[$name]=$true }
        else { $i++; if ($i -ge $arguments.Count) { throw 'Missing fixture parameter value.' }; $named[$name]=$arguments[$i] }
    }
    & $request.script @named
    [Console]::Out.WriteLine('ORCHID_BACKUP_CHECK:'+(@{success=$true;message=''} | ConvertTo-Json -Compress))
    exit 0
}
catch {
    [Console]::Out.WriteLine('ORCHID_BACKUP_CHECK:'+(@{success=$false;message=$_.Exception.Message} | ConvertTo-Json -Compress))
    exit 1
}
