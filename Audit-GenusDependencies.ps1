param(
    [string]$SchemaRoot = "database/schema",
    [string]$OutputFile = "genus-dependency-audit.txt"
)

Write-Host "Scanning schema files for genus dependencies..."

$patterns = @(
    '\bgenus\b',
    '\bgenusId\b',
    'JOIN\s+genus',
    'FROM\s+genus',
    'UPDATE\s+genus',
    'INSERT\s+INTO\s+genus',
    'DELETE\s+FROM\s+genus'
)

$results = @()

$files = Get-ChildItem -Path $SchemaRoot -Recurse -File

foreach ($file in $files) {
    $content = Get-Content $file.FullName

    for ($i = 0; $i -lt $content.Length; $i++) {
        foreach ($pattern in $patterns) {
            if ($content[$i] -match $pattern) {
                $results += [PSCustomObject]@{
                    File = $file.FullName
                    LineNumber = $i + 1
                    Text = $content[$i].Trim()
                }
                break
            }
        }
    }
}

$results |
    Sort-Object File, LineNumber |
    Format-Table -AutoSize |
    Out-File $OutputFile

Write-Host "Audit complete -> $OutputFile"
Write-Host "Total matches:" $results.Count
