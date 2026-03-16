param(
    [string]$SchemaRoot = "database/schema",
    [string]$OutputFile = "taxonomy-lifecycle-audit.md",
    [switch]$IncludeStructural
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $SchemaRoot)) {
    throw "Schema root not found: $SchemaRoot"
}

function Get-ObjectType {
    param([string]$FullName)

    $normalised = $FullName.Replace('\', '/').ToLowerInvariant()

    if ($normalised -match '/tables/')      { return 'Table' }
    if ($normalised -match '/views/')       { return 'View' }
    if ($normalised -match '/routines/')    { return 'Routine' }
    if ($normalised -match '/constraints/') { return 'Constraint' }

    return 'Other'
}

function Get-ObjectName {
    param([System.IO.FileInfo]$File)
    return [System.IO.Path]::GetFileNameWithoutExtension($File.Name)
}

function Add-Finding {
    param(
        [System.Collections.Generic.List[object]]$Findings,
        [string]$Severity,
        [string]$Category,
        [string]$ObjectType,
        [string]$ObjectName,
        [string]$File,
        [int]$LineNumber,
        [string]$LineText,
        [string]$Rule,
        [string]$Reason
    )

    $Findings.Add([PSCustomObject]@{
        Severity   = $Severity
        Category   = $Category
        ObjectType = $ObjectType
        ObjectName = $ObjectName
        File       = $File
        LineNumber = $LineNumber
        LineText   = $LineText.Trim()
        Rule       = $Rule
        Reason     = $Reason
    })
}

$allFiles = Get-ChildItem -Path $SchemaRoot -Recurse -File
$findings = New-Object 'System.Collections.Generic.List[object]'

foreach ($file in $allFiles) {
    $objectType = Get-ObjectType -FullName $file.FullName
    $objectName = Get-ObjectName -File $file

    if (-not $IncludeStructural -and ($objectType -in @('Table', 'Constraint'))) {
        continue
    }

    $lines = Get-Content -Path $file.FullName

    $content = ($lines -join "`n")
    $contentLower = $content.ToLowerInvariant()

    $mentionsGenus   = $contentLower -match '\bgenus\b'
    $mentionsGenusId = $contentLower -match '\bgenusid\b'

    if (-not ($mentionsGenus -or $mentionsGenusId)) {
        continue
    }

    # Rule 1: Any routine that creates new identity should validate active taxonomy
    $isIdentityCreationRoutine =
        $objectType -eq 'Routine' -and (
            $objectName -match '^spSplitPlant$' -or
            $objectName -match '^spAddTaxonInternal$' -or
            $contentLower -match 'insert\s+into\s+plant\b' -or
            $contentLower -match 'insert\s+into\s+taxon\b' -or
            $contentLower -match 'insert\s+into\s+plantsplit\b' -or
            $contentLower -match 'insert\s+into\s+plantsplitchild\b'
        )

    if ($isIdentityCreationRoutine) {
        $hasGenusIsActiveCheck =
            $contentLower -match 'g\.isactive' -or
            $contentLower -match 'genus\.isactive' -or
            $contentLower -match 'vgenusisactive' -or
            $contentLower -match 'genusisactive'

        $hasTaxonIsActiveCheck =
            $contentLower -match 't\.isactive' -or
            $contentLower -match 'taxon\.isactive' -or
            $contentLower -match 'vtaxonisactive' -or
            $contentLower -match 'taxonisactive'

        if (-not ($hasGenusIsActiveCheck -and $hasTaxonIsActiveCheck)) {
            Add-Finding `
                -Findings $findings `
                -Severity 'High' `
                -Category 'IdentityCreation' `
                -ObjectType $objectType `
                -ObjectName $objectName `
                -File $file.FullName `
                -LineNumber 1 `
                -LineText '[object-level finding]' `
                -Rule 'Identity creation must validate active genus and active taxon.' `
                -Reason 'This object appears to create plant or taxon identity but may not enforce taxonomy active-state.'
        }
    }

    # Rule 2: Views used for selection should probably filter active taxonomy
    $isLikelySelectionView =
        $objectType -eq 'View' -and (
            $objectName -match 'identity' -or
            $objectName -match 'active' -or
            $contentLower -match 'order\s+by' -or
            $contentLower -match 'select\s+.*genus' -or
            $contentLower -match 'select\s+.*taxon'
        )

    if ($isLikelySelectionView) {
        $hasGenusActiveFilter =
            $contentLower -match 'g\.isactive\s*=\s*1' -or
            $contentLower -match 'genus\.isactive\s*=\s*1' -or
            $contentLower -match 'where\s+.*isactive\s*=\s*1' -or
            $contentLower -match 'and\s+.*isactive\s*=\s*1'

        if (-not $hasGenusActiveFilter) {
            Add-Finding `
                -Findings $findings `
                -Severity 'Medium' `
                -Category 'SelectionView' `
                -ObjectType $objectType `
                -ObjectName $objectName `
                -File $file.FullName `
                -LineNumber 1 `
                -LineText '[object-level finding]' `
                -Rule 'Selection-facing views should usually exclude inactive genus/taxon.' `
                -Reason 'This view mentions genus/taxon but no obvious active-state filter was detected.'
        }
    }

    # Rule 3: Historical/current display views should not hide records merely because taxonomy is inactive
    $isLikelyHistoryOrDisplayView =
        $objectType -eq 'View' -and (
            $objectName -match 'currentlocation' -or
            $objectName -match 'summary' -or
            $objectName -match 'history'
        )

    if ($isLikelyHistoryOrDisplayView) {
        $hasHardGenusActiveFilter =
            $contentLower -match 'g\.isactive\s*=\s*1' -or
            $contentLower -match 'genus\.isactive\s*=\s*1'

        if ($hasHardGenusActiveFilter) {
            Add-Finding `
                -Findings $findings `
                -Severity 'High' `
                -Category 'HistoryVisibility' `
                -ObjectType $objectType `
                -ObjectName $objectName `
                -File $file.FullName `
                -LineNumber 1 `
                -LineText '[object-level finding]' `
                -Rule 'History/display views must not hide plants because genus is inactive.' `
                -Reason 'This looks like a display/history view and contains an active-genus filter that may wrongly suppress historical records.'
        }
    }

    # Rule 4: Line-level findings for direct genus usage
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        $lineLower = $line.ToLowerInvariant()

        if ($lineLower -notmatch '\bgenus\b|\bgenusid\b') {
            continue
        }

        if ($lineLower -match 'join\s+genus|from\s+genus|update\s+genus|insert\s+into\s+genus') {
            Add-Finding `
                -Findings $findings `
                -Severity 'Info' `
                -Category 'DirectGenusReference' `
                -ObjectType $objectType `
                -ObjectName $objectName `
                -File $file.FullName `
                -LineNumber ($i + 1) `
                -LineText $line `
                -Rule 'Direct genus reference.' `
                -Reason 'Useful for manual review.'
        }

        if ($lineLower -match 'genusid') {
            Add-Finding `
                -Findings $findings `
                -Severity 'Info' `
                -Category 'GenusIdReference' `
                -ObjectType $objectType `
                -ObjectName $objectName `
                -File $file.FullName `
                -LineNumber ($i + 1) `
                -LineText $line `
                -Rule 'Direct genusId reference.' `
                -Reason 'Useful for tracing propagation of genus identity.'
        }

        if ($lineLower -match 'isactive' -and $lineLower -match 'genus') {
            Add-Finding `
                -Findings $findings `
                -Severity 'Info' `
                -Category 'GenusActiveLogic' `
                -ObjectType $objectType `
                -ObjectName $objectName `
                -File $file.FullName `
                -LineNumber ($i + 1) `
                -LineText $line `
                -Rule 'Line contains genus and active-state logic.' `
                -Reason 'Likely relevant to the inactive-genus refactor.'
        }
    }
}
# Build report
$report = New-Object System.Collections.Generic.List[string]

$report.Add("# Taxonomy lifecycle audit")
$report.Add("")
$report.Add("Generated: " + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
$report.Add("Schema root: " + $SchemaRoot)
$report.Add("Include structural objects: " + $IncludeStructural.IsPresent)
$report.Add("")

$highCount   = ($findings | Where-Object { $_.Severity -eq 'High' }).Count
$mediumCount = ($findings | Where-Object { $_.Severity -eq 'Medium' }).Count
$infoCount   = ($findings | Where-Object { $_.Severity -eq 'Info' }).Count

$report.Add("## Summary")
$report.Add("")
$report.Add("- High findings: " + $highCount)
$report.Add("- Medium findings: " + $mediumCount)
$report.Add("- Info findings: " + $infoCount)
$report.Add("")

$byObject = $findings |
    Sort-Object ObjectType, ObjectName, Severity, LineNumber |
    Group-Object ObjectType, ObjectName

foreach ($group in $byObject) {

    $first = $group.Group[0]

    $report.Add("## " + $first.ObjectType + ": " + $first.ObjectName)
    $report.Add("")
    $report.Add("File: " + $first.File)
    $report.Add("")

    foreach ($finding in $group.Group) {

        $report.Add("### [" + $finding.Severity + "] " + $finding.Category)
        $report.Add("")
        $report.Add("- Rule: " + $finding.Rule)
        $report.Add("- Reason: " + $finding.Reason)
        $report.Add("- Line: " + $finding.LineNumber)
        $report.Add("- Text: " + $finding.LineText)
        $report.Add("")
    }
}

$report | Set-Content -Path $OutputFile -Encoding UTF8

Write-Host ("Audit complete: " + $OutputFile)
Write-Host ("High:   " + $highCount)
Write-Host ("Medium: " + $mediumCount)
Write-Host ("Info:   " + $infoCount)
