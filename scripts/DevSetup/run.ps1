param([switch]$CheckOnly, [string]$Url = 'http://localhost:5285')
$ErrorActionPreference = 'Stop'
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
. (Join-Path $PSScriptRoot 'configure.ps1')
$previousPath = $env:PATH
try {
    if ($IsWindows) {
        if ([Runtime.InteropServices.RuntimeInformation]::OSArchitecture -ne 'X64') { throw 'Windows source development currently requires x64.' }
        & (Join-Path $repositoryRoot 'scripts/restore-windows-runtime.ps1') -LibVipsOnly
        $nativeDirectory = Join-Path $repositoryRoot 'app/runtime/libvips/win-x64/bin'
        $env:PATH = $nativeDirectory + [IO.Path]::PathSeparator + $env:PATH
    }
    & dotnet run --configuration Release --project (Join-Path $repositoryRoot 'tests/DevelopmentNative.Checks/DevelopmentNative.Checks.csproj')
    if ($LASTEXITCODE -ne 0) { throw 'Native photo save/reopen check failed; application was not started.' }
    if (-not $CheckOnly) {
        & dotnet run --project (Join-Path $repositoryRoot 'src/OrchidApp.Web/OrchidApp.Web.csproj') --no-launch-profile --urls $Url
        if ($LASTEXITCODE -ne 0) { throw "Development application exited with code $LASTEXITCODE." }
    }
}
finally { $env:PATH = $previousPath }
