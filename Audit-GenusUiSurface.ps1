param(
    [string]$Root = ".",
    [string]$OutputFile = "genus-ui-audit.md"
)

$ErrorActionPreference = "Stop"

$extensions = @("*.cs", "*.cshtml")

$files = Get-ChildItem -Path $Root -Recurse -Include $extensions -File

$findings = New-Object System.Collections.Generic.List[object]

function Add-Finding {
    param(
        $File,
        $LineNumber,
        $LineText,
        $Category,
        $Reason
    )

    $findings.Add([PSCustomObject]@{
        File = $File
        LineNumber = $LineNumber
        Category = $Category
        Reason = $Reason
        Text = $LineText.Trim()
    })
}

foreach ($file in $files) {

    $lines = Get-Content $file.FullName

    for ($i = 0; $i -lt $lines.Count; $i++) {

        $line = $lines[$i]
        $lower = $line.ToLowerInvariant()

        # ---- Rendering genus name ----
        if ($lower -match 'genusname') {
            Add-Finding $file.FullName ($i+1) $line `
                "GenusRender" `
                "Direct genusName usage — may require inactive badge support"
        }

        # ---- Rendering display name ----
        if ($lower -match 'displayname') {
            Add-Finding $file.FullName ($i+1) $line `
                "DisplayNameUsage" `
                "Botanical displayName used — badge policy must be applied"
        }

        # ---- Projection creation ----
        if ($lower -match 'select\(|new\s+\w+\s*{') {
            if ($lower -match 'displayname|genusname') {
                Add-Finding $file.FullName ($i+1) $line `
                    "ProjectionCreation" `
                    "Projection builds botanical identity — must propagate inactive metadata"
            }
        }

        # ---- Botanical formatting logic ----
        if ($lower -match 'concat|string\.format|\+.*species|\+.*hybrid') {
            if ($lower -match 'genus') {
                Add-Finding $file.FullName ($i+1) $line `
                    "FormattingLogic" `
                    "Botanical name formatting detected — may bypass central badge logic"
            }
        }

        # ---- Dropdown / selection surface ----
        if ($lower -match 'selectlist|dropdown|asp-for') {
            if ($lower -match 'genus|taxon') {
                Add-Finding $file.FullName ($i+1) $line `
                    "SelectionSurface" `
                    "Selection UI using taxonomy — inactive filtering rules must apply"
            }
        }
    }
}

# ---- Build report ----

$report = New-Object System.Collections.Generic.List[string]

$report.Add("# Genus UI surface audit")
$report.Add("")
$report.Add("Generated: $(Get-Date)")
$report.Add("Root: $Root")
$report.Add("")

$grouped = $findings | Group-Object Category

foreach ($group in $grouped) {

    $report.Add("## $($group.Name)")
    $report.Add("")

    foreach ($item in $group.Group) {

        $report.Add("File: $($item.File)")
        $report.Add("Line: $($item.LineNumber)")
        $report.Add("Reason: $($item.Reason)")
        $report.Add("Text: $($item.Text)")
        $report.Add("")
    }
}

$report | Set-Content $OutputFile -Encoding UTF8

Write-Host "UI audit complete: $OutputFile"
Write-Host "Findings: $($findings.Count)"
