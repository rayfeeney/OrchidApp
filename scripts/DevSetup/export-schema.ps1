param([string]$RepositoryRoot=(Join-Path $PSScriptRoot '../..'))
$ErrorActionPreference='Stop'
$RepositoryRoot=(Resolve-Path -LiteralPath $RepositoryRoot).Path
. (Join-Path $PSScriptRoot 'Repository-Environment.ps1')
Invoke-RepositoryDatabaseEnvironment $RepositoryRoot {
    & (Join-Path $RepositoryRoot 'database/scripts/Export-MariaDBSchema.ps1')
}
