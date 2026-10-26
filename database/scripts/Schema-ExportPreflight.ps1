. (Join-Path $PSScriptRoot 'Migration-History.ps1')

function Assert-SchemaExportReady {
    param([hashtable]$History,[string]$SchemaCutoff,[AllowEmptyCollection()][string[]]$Files,[bool]$HasMigrationFolder)
    if(-not (Test-BaselineTimestamp $SchemaCutoff)){throw 'Invalid source schema cutoff.'}
    $cutoff=Get-DatabaseBaselineCutoff $History
    if($HasMigrationFolder){
        $pending=@(Get-MigrationPlan $Files $History)
        if($pending.Count){
            throw "Pending database migrations block schema export before source files are changed: $($pending.Name -join ', '). Back up the isolated development database, run Apply-Migrations.ps1 -PlanOnly, then apply through the canonical runner before committing."
        }
    }
    $recorded=@()
    if($cutoff){$recorded+=$cutoff}
    foreach($name in $History.Keys){
        if($name.StartsWith('baseline',[StringComparison]::OrdinalIgnoreCase)){continue}
        $stamp=Get-MigrationTimestamp $name
        if($History[$name] -cnotmatch '^[a-fA-F0-9]{64}$'){throw "Invalid recorded migration checksum: $name"}
        $recorded+=$stamp
    }
    $latest=$recorded | Sort-Object -Descending | Select-Object -First 1
    if(-not $latest -or [string]::CompareOrdinal($latest,$SchemaCutoff) -lt 0){
        throw "Database history is older than source schema cutoff $SchemaCutoff, or cannot establish it. Export refused before changing source files. Review the selected database and apply its missing migrations; do not downgrade schema/bootstrap.json or bypass the hook."
    }
}
