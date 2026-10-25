# Local database checks against an explicitly supplied disposable MariaDB server.
# No Docker installation, hidden port, historical replay or claim of CI parity.
$ErrorActionPreference = 'Stop'
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
foreach ($suite in @('SchemaBaseline.Checks','MigrationHistory.Checks')) {
    & pwsh -NoProfile -File (Join-Path $repositoryRoot "tests/$suite/Database.Checks.ps1")
    if ($LASTEXITCODE -ne 0) { throw "Local $suite checks failed." }
}
