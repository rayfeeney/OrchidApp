# Root of your solution
$rootPath = "C:\Users\rfeen\source\repos\OrchidApp"

# File types to scan
$filePatterns = @("*.cs", "*.cshtml")

# Patterns to search for
$searchPatterns = @(
    "DateTime\.Now",
    "DateTime\.Today",
    "DateTime\.UtcNow",
    "DateTime\.Now\.Date",
    "= *DateTime",
    'value\s*=\s*"@DateTime'
)

Write-Host "Scanning for default date usage..." -ForegroundColor Cyan

$results = @()

foreach ($pattern in $filePatterns) {
    Get-ChildItem -Path $rootPath -Recurse -Include $pattern | ForEach-Object {
        $file = $_

        $content = Get-Content $file.FullName

        for ($i = 0; $i -lt $content.Length; $i++) {
            foreach ($search in $searchPatterns) {
                if ($content[$i] -match $search) {
                    $results += [PSCustomObject]@{
                        File      = $file.FullName
                        Line      = $i + 1
                        Match     = $content[$i].Trim()
                        Pattern   = $search
                    }
                }
            }
        }
    }
}

if ($results.Count -eq 0) {
    Write-Host "✅ No default date usage found." -ForegroundColor Green
}
else {
    Write-Host "⚠️ Potential default date usage found:" -ForegroundColor Yellow
    $results | Sort-Object File, Line | Format-Table -AutoSize
}

# Optional: export to CSV
$results | Export-Csv -Path "$rootPath\date_audit_results.csv" -NoTypeInformation
Write-Host "Results exported to date_audit_results.csv"