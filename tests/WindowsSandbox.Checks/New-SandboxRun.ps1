param(
    [Parameter(Mandatory)][string]$Installer,
    [Parameter(Mandatory)][string]$Specimen,
    [Parameter(Mandatory)][string]$Jpeg,
    [Parameter(Mandatory)][string]$Heic,
    [Parameter(Mandatory)][string]$PythonRoot,
    [Parameter(Mandatory)][string]$BrowserRoot,
    [string]$PreviousInstaller,
    [ValidatePattern('^[0-9a-fA-F]{64}$')][string]$CandidateSha256,
    [ValidatePattern('^[0-9a-fA-F]{40}$')][string]$CandidateRevision,
    [string]$PreviousArchiveModuleRoot,
    [string]$OutputRoot = 'artifacts/windows-sandbox',
    [switch]$Launch
)
$ErrorActionPreference = 'Stop'
if ([Environment]::OSVersion.Platform -ne 'Win32NT') { throw 'Windows Sandbox requires a Windows host.' }
$repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
if ([bool]$CandidateSha256 -ne [bool]$CandidateRevision) { throw 'Specify candidate SHA-256 and source revision together.' }
if ($PreviousArchiveModuleRoot -and !$PreviousInstaller) { throw 'The legacy module is allowed only for the historical installer.' }
$currentHash = if ($CandidateSha256) { $CandidateSha256 } else { '4b116a69c37ef214215efd3fe5655cfece02f5e6d026346f9ab45ddd1ebdba4e' }
$assetInputs = @(
    @{ name = 'current.exe'; path = $Installer; sha256 = $currentHash }
    @{ name = 'specimen.zip'; path = $Specimen; sha256 = '18a10fb72501cf412c3bc8a599dbc693069497665b59c00945f3740a11375786' }
    @{ name = 'large.jpg'; path = $Jpeg }
    @{ name = 'large.heic'; path = $Heic }
)
if ($PreviousInstaller) {
    $assetInputs += @{ name = 'previous.exe'; path = $PreviousInstaller; sha256 = 'b271d9b1da0c351b28736a660c2952c10e14acb3c716da0e048c57d83d26b318' }
}
foreach ($asset in $assetInputs) {
    $asset.path = (Resolve-Path -LiteralPath $asset.path).Path
    $hash = (Get-FileHash -LiteralPath $asset.path -Algorithm SHA256).Hash
    if ($asset.sha256 -and $hash -ine $asset.sha256) { throw "Published checksum mismatch for $($asset.name)." }
    $asset.sha256 = $hash
}
foreach ($required in @('python.exe', 'Lib\site-packages\playwright')) {
    if (!(Test-Path -LiteralPath (Join-Path $PythonRoot $required))) {
        throw "The portable Python directory is missing $required."
    }
}
if (!(Get-ChildItem -LiteralPath $BrowserRoot -Directory -Filter 'chromium_headless_shell-*')) {
    throw 'The browser directory is missing the Playwright Chromium headless shell.'
}
$version = git -C $repo rev-parse HEAD
if ($LASTEXITCODE -ne 0) { throw 'Could not identify test source revision.' }

$session = Join-Path $OutputRoot ([DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ') + '-' + [guid]::NewGuid().ToString('N').Substring(0,8))
$inputs = (New-Item -ItemType Directory -Path (Join-Path $session 'input')).FullName
$evidence = (New-Item -ItemType Directory -Path (Join-Path $session 'evidence')).FullName
foreach ($asset in $assetInputs) {
    Copy-Item -LiteralPath $asset.path -Destination (Join-Path $inputs $asset.name)
}
Copy-Item -LiteralPath $PythonRoot -Destination (Join-Path $inputs 'python') -Recurse
Copy-Item -LiteralPath $BrowserRoot -Destination (Join-Path $inputs 'browsers') -Recurse
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Invoke-GuestChecks.ps1') -Destination $inputs
Copy-Item -LiteralPath (Join-Path $repo 'tests/SharedBrowser.Checks/checks.py') -Destination $inputs
if ($PreviousArchiveModuleRoot) {
    Copy-Item -LiteralPath $PreviousArchiveModuleRoot -Destination (Join-Path $inputs 'legacy-archive-module') -Recurse
}
[ordered]@{ sourceRevision = $version; candidateRevision = $CandidateRevision; inputs = @($assetInputs | ForEach-Object {
    [ordered]@{ name = $_.name; sha256 = $_.sha256 }
}) } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $inputs 'case.json') -Encoding UTF8

$escapedInputs = [Security.SecurityElement]::Escape($inputs)
$escapedEvidence = [Security.SecurityElement]::Escape($evidence)
$mode = if ($PreviousInstaller) { ' -Upgrade' } else { '' }
$config = @"
<Configuration>
  <Networking>Disable</Networking>
  <ClipboardRedirection>Disable</ClipboardRedirection>
  <MappedFolders>
    <MappedFolder><HostFolder>$escapedInputs</HostFolder><SandboxFolder>C:\OrchidTestInput</SandboxFolder><ReadOnly>true</ReadOnly></MappedFolder>
    <MappedFolder><HostFolder>$escapedEvidence</HostFolder><SandboxFolder>C:\OrchidTestEvidence</SandboxFolder><ReadOnly>false</ReadOnly></MappedFolder>
  </MappedFolders>
  <LogonCommand>
    <Command>powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\OrchidTestInput\Invoke-GuestChecks.ps1$mode</Command>
  </LogonCommand>
</Configuration>
"@
$configPath = Join-Path (Split-Path $inputs -Parent) 'OrchidApp.wsb'
[xml]$null = $config
Set-Content -LiteralPath $configPath -Value $config -Encoding UTF8
Write-Host "Windows Sandbox configuration: $configPath"
Write-Host "Evidence directory: $evidence"
if ($Launch) { Start-Process -FilePath WindowsSandbox.exe -ArgumentList ('"' + $configPath + '"') -WindowStyle Hidden }
