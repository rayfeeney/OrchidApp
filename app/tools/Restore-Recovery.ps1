# Persistent restore journal. A pending marker blocks normal launcher startup.
function Write-RestoreRecord([object]$Record, [string]$Path) {
    Assert-ChildPath $Path $ProgramDataRoot
    $temporary=$Path+'.'+[guid]::NewGuid().ToString('N')+'.tmp'
    try {
        $Record | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $temporary -Encoding UTF8
        if (Test-Path -LiteralPath $Path) { [IO.File]::Replace($temporary,$Path,[System.Management.Automation.Language.NullString]::Value) }
        else { [IO.File]::Move($temporary,$Path) }
    }
    finally { if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force } }
}
function Save-RestorePhase([string]$Phase) {
    $script:RecoveryRecord.phase=$Phase
    $script:RecoveryRecord.updatedUtc=[DateTime]::UtcNow.ToString('o')
    if ($script:RestoreHasStarted) { Write-RestoreRecord $RecoveryRecord $RecoveryMarker }
    Write-RestoreRecord $RecoveryRecord (Join-Path $RestoreRoot 'recovery.json')
}
