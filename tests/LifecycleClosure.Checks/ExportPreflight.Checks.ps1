$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '../../database/scripts/Schema-ExportPreflight.ps1')
$root=Join-Path ([IO.Path]::GetTempPath()) ('orchid-export-policy-'+[guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory -Path $root
$file=Join-Path $root '202610261200_AtomicManualPlantClosure.sql'
[IO.File]::WriteAllText($file,'SELECT 1;',[Text.UTF8Encoding]::new($false))
$checks=0
function Pass([string]$Name,[scriptblock]$Action){& $Action;$script:checks++}
function Reject([string]$Name,[string]$Expected,[scriptblock]$Action){
    try{& $Action}catch{if($_.Exception.Message.Contains($Expected)){$script:checks++;return};throw}
    throw "Expected rejection: $Name"
}
try {
    $old=@{'baseline:v1:202606041820'=('a'*64)}
    $fresh=@{'baseline:v1:202610261200'=('b'*64)}
    $applied=@{'baseline:v1:202606041820'=('a'*64);'202610261200_AtomicManualPlantClosure.sql'=(Get-MigrationFileChecksum $file)}
    Reject 'Pending migration with new source' 'Pending database migrations' {Assert-SchemaExportReady $old '202610261200' @($file) $true}
    Reject 'Pending migration even with old source' 'Pending database migrations' {Assert-SchemaExportReady $old '202606041820' @($file) $true}
    Reject 'Older history without migration directory' 'older than source schema' {Assert-SchemaExportReady $old '202610261200' @() $false}
    Pass 'Applied migration' {Assert-SchemaExportReady $applied '202610261200' @($file) $true}
    Pass 'Fresh schema baseline covers migration' {Assert-SchemaExportReady $fresh '202610261200' @($file) $true}
    Pass 'Schema-only source at matching baseline' {Assert-SchemaExportReady $fresh '202610261200' @() $false}
    Pass 'Schema-only source after external migration' {Assert-SchemaExportReady $applied '202610261200' @() $false}
    Reject 'Empty history' 'setup is incomplete' {Assert-SchemaExportReady @{} '202610261200' @() $false}
    Reject 'Running marker' 'incomplete or running migration' {Assert-SchemaExportReady @{'baseline:v1:202610261200'=('b'*64);'migration:pending'=('c'*64)} '202610261200' @($file) $true}
    Reject 'Changed applied bytes' 'checksum changed' {Assert-SchemaExportReady @{'baseline:v1:202606041820'=('a'*64);'202610261200_AtomicManualPlantClosure.sql'=('c'*64)} '202610261200' @($file) $true}
    Reject 'Legacy identity alone' 'cannot establish' {Assert-SchemaExportReady @{'baseline'='baseline'} '202610261200' @() $false}
    Reject 'Invalid cutoff' 'Invalid source schema cutoff' {Assert-SchemaExportReady $fresh 'bad' @() $false}
    Write-Host "$checks schema export preflight policy checks passed."
}
finally {Remove-Item -LiteralPath $file -Force;Remove-Item -LiteralPath $root -Force}
