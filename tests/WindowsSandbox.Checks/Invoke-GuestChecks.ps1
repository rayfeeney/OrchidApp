param([switch]$Upgrade)
$ErrorActionPreference = 'Stop'

# The mapped input and evidence locations are supplied by the generated .wsb file.
if ($env:USERNAME -cne 'WDAGUtilityAccount' -or
    !(Test-Path 'C:\OrchidTestInput\case.json') -or !(Test-Path 'C:\OrchidTestEvidence')) {
    throw 'Run this script only in its fresh Windows Sandbox.'
}

$inputRoot = 'C:\OrchidTestInput'
$evidence = 'C:\OrchidTestEvidence'
$work = 'C:\OrchidTest'
$install = Join-Path $env:ProgramFiles 'OrchidApp'
$data = Join-Path $env:ProgramData 'OrchidApp'
$launcherExe = Join-Path $install 'OrchidApp.Launcher.exe'
$log = Join-Path $data 'logs\launcher.log'
$baseUrl = 'http://127.0.0.1:5285'
$case = Get-Content -LiteralPath (Join-Path $inputRoot 'case.json') -Raw | ConvertFrom-Json
$report = [ordered]@{
    startedUtc = [DateTime]::UtcNow.ToString('o')
    mode = if ($Upgrade) { 'v1.4.0 to v1.4.1' } else { 'clean v1.4.1' }
    windows = [Environment]::OSVersion.VersionString
    architecture = $env:PROCESSOR_ARCHITECTURE
    sourceRevision = $case.sourceRevision
    candidateRevision = $case.candidateRevision
    inputs = $case.inputs
    stages = [ordered]@{}
    status = 'running'
}
$launcher = $null

function Write-Report {
    $report | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $evidence 'report.json') -Encoding UTF8
}

function Complete-Stage([string]$Name) {
    $report.stages[$Name] = [DateTime]::UtcNow.ToString('o')
    Write-Report
}

function Wait-For([string]$Description, [scriptblock]$Probe, [int]$Seconds = 120) {
    $until = [DateTime]::UtcNow.AddSeconds($Seconds)
    do {
        $found = & $Probe
        if ($found) { return $found }
        Start-Sleep -Milliseconds 500
    } until ([DateTime]::UtcNow -ge $until)
    throw "Timed out waiting for $Description."
}

function Invoke-Native([string]$Exe, [string[]]$Arguments, [int]$Seconds = 600) {
    $process = Start-Process -FilePath $Exe -ArgumentList $Arguments -PassThru -WindowStyle Hidden
    try {
        if (!$process.WaitForExit($Seconds * 1000)) { throw "Timed out running $Exe." }
        $process.Refresh()
        if ($process.ExitCode -ne 0) { throw "$Exe exited with code $($process.ExitCode)." }
    } finally {
        $process.Dispose()
    }
}

function Test-Port([int]$Port) {
    $client = [Net.Sockets.TcpClient]::new()
    try { $client.Connect('127.0.0.1', $Port); return $true }
    catch [Net.Sockets.SocketException] { return $false }
    finally { $client.Dispose() }
}

function Get-Window([string]$Title, [int]$Seconds = 120) {
    Wait-For $Title {
        $launcher.Refresh()
        $handle = $launcher.MainWindowHandle
        if ($handle -ne [IntPtr]::Zero) {
            $mainWindow = [Windows.Automation.AutomationElement]::FromHandle($handle)
            if ($mainWindow -and ($Title -eq 'OrchidApp Launcher -*' -or $mainWindow.Current.Name -like $Title)) {
                return ,$mainWindow
            }
        }
        $root = [Windows.Automation.AutomationElement]::RootElement
        $pidMatch = [Windows.Automation.PropertyCondition]::new(
            [Windows.Automation.AutomationElement]::ProcessIdProperty, $launcher.Id)
        $windows = $root.FindAll([Windows.Automation.TreeScope]::Children, $pidMatch)
        foreach ($window in $windows) {
            if ($window.Current.Name -like $Title) { return ,$window }
            $condition = [Windows.Automation.PropertyCondition]::new(
                [Windows.Automation.AutomationElement]::NameProperty, $Title)
            $dialog = $window.FindFirst([Windows.Automation.TreeScope]::Descendants, $condition)
            if ($dialog -and $dialog.Current.ControlType -eq [Windows.Automation.ControlType]::Window) {
                return ,$dialog
            }
        }
    } $Seconds
}

function Invoke-Button($Window, [string]$Name) {
    $button = Wait-For "enabled button '$Name'" {
        $condition = [Windows.Automation.AndCondition]::new(
            [Windows.Automation.PropertyCondition]::new([Windows.Automation.AutomationElement]::NameProperty, $Name),
            [Windows.Automation.PropertyCondition]::new([Windows.Automation.AutomationElement]::ControlTypeProperty, [Windows.Automation.ControlType]::Button))
        $element = $Window.FindFirst([Windows.Automation.TreeScope]::Descendants, $condition)
        if ($element -and $element.Current.IsEnabled) { $element }
    }
    $button.GetCurrentPattern([Windows.Automation.InvokePattern]::Pattern).Invoke()
}

function Start-Orchid {
    if ((Test-Port 5285) -or (Test-Port 3308)) { throw 'An unexpected service is already listening.' }
    $script:launcher = Start-Process -FilePath $launcherExe -WorkingDirectory $install -PassThru
    # Readiness can succeed before the launcher finishes its automatic backup.
    $null = Wait-For 'OrchidApp readiness' {
        if ($launcher.HasExited) { throw 'The launcher exited during startup.' }
        try {
            $health = Invoke-RestMethod -Uri "$baseUrl/health/ready" -TimeoutSec 3 -MaximumRedirection 0
            if ($health.ready -and $health.checks.database -and $health.checks.nativePhotos) { $true }
        } catch {}
    } 180
    foreach ($service in @(@{ port = 5285; exe = 'OrchidApp.Web.exe' }, @{ port = 3308; exe = 'mariadbd.exe' })) {
        $owners = @(Get-NetTCPConnection -State Listen -LocalPort $service.port |
            Select-Object -ExpandProperty OwningProcess -Unique)
        if ($owners.Count -ne 1) { throw "Unexpected owners on port $($service.port)." }
        $process = Get-Process -Id $owners[0]
        if ($process.ProcessName + '.exe' -cne $service.exe -or
            !$process.Path.StartsWith($install + '\', [StringComparison]::OrdinalIgnoreCase)) {
            throw "Port $($service.port) is not owned by the installed package."
        }
    }
}

function Stop-Orchid {
    Invoke-Button (Get-Window 'OrchidApp Launcher -*') 'Close OrchidApp'
    Invoke-Button (Get-Window 'Close OrchidApp?') 'Yes'
    $null = Wait-For 'launcher and owned listeners to stop' {
        $launcher.HasExited -and !(Test-Port 5285) -and !(Test-Port 3308)
    }
    $script:launcher = $null
}

function Install-Orchid([string]$Asset, [string]$Phase) {
    Invoke-Native (Join-Path $work $Asset) @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/SP-', "/LOG=$evidence\$Phase.log")
    if (!(Test-Path -LiteralPath $launcherExe)) { throw 'The installer did not deploy the launcher.' }
    $report["$Phase-version"] = (Get-Item -LiteralPath $launcherExe).VersionInfo.ProductVersion
    $server = Join-Path $install 'runtime\mariadb\win-x64\bin\mariadbd.exe'
    $report["$Phase-MariaDB"] = (& $server --version | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) { throw 'Could not identify the installed MariaDB runtime.' }
    Complete-Stage $Phase
}

function Restore-Orchid([string]$Archive) {
    Invoke-Button (Get-Window 'OrchidApp Launcher -*') 'Restore from backup...'
    $dialog = Get-Window 'Select OrchidApp backup ZIP'
    $name = Wait-For 'backup file name edit' {
        $condition = [Windows.Automation.PropertyCondition]::new(
            [Windows.Automation.AutomationElement]::ControlTypeProperty, [Windows.Automation.ControlType]::Edit)
        $dialog.FindFirst([Windows.Automation.TreeScope]::Descendants, $condition)
    }
    $name.GetCurrentPattern([Windows.Automation.ValuePattern]::Pattern).SetValue($Archive)
    Invoke-Button $dialog 'Open'
    Invoke-Button (Get-Window 'Confirm Restore from Backup') 'Yes'
    Invoke-Button (Get-Window 'Restore Complete' 240) 'OK'
    if (Test-Path -LiteralPath (Join-Path $data 'restore-pending.json')) { throw 'Restore marker remains.' }
    $hash = (Get-FileHash -LiteralPath $Archive -Algorithm SHA256).Hash
    $retained = @(Get-ChildItem -LiteralPath (Join-Path $data 'restore-recovery') -Filter recovery-input.zip -Recurse -File |
        Where-Object { (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash -eq $hash })
    if ($retained.Count -lt 1) { throw 'Restore did not retain a byte-identical input.' }
}

function Get-MediaInventory {
    $uploads = Join-Path $data 'uploads'
    @(Get-ChildItem -LiteralPath $uploads -File -Recurse | Sort-Object FullName | ForEach-Object {
        $relative = $_.FullName.Substring($uploads.Length + 1)
        "$relative $((Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash)"
    })
}

function Get-PersistentInventory {
    $paths = @('data\mariadb', 'uploads', 'backups', 'launcher-settings.json', 'restore-recovery')
    foreach ($path in $paths) {
        $absolute = Join-Path $data $path
        if (!(Test-Path -LiteralPath $absolute)) { continue }
        Get-ChildItem -LiteralPath $absolute -File -Recurse -Force | ForEach-Object {
            "$($_.FullName) $((Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash)"
        }
    }
}

function Invoke-Browser([string[]]$Arguments) {
    $python = Join-Path $inputRoot 'python\python.exe'
    $env:PLAYWRIGHT_BROWSERS_PATH = Join-Path $inputRoot 'browsers'
    $output = & $python (Join-Path $inputRoot 'checks.py') --base-url $baseUrl --disposable @Arguments
    $code = $LASTEXITCODE
    $output | Add-Content -LiteralPath (Join-Path $evidence 'browser.log')
    if ($code -ne 0) { throw "Shared browser checks exited $code." }
    $output
}

try {
    Write-Report
    if ((Test-Path -LiteralPath $install) -or (Test-Path -LiteralPath $data) -or
        (Test-Path -LiteralPath $work) -or (Test-Port 5285) -or (Test-Port 3308)) {
        throw 'A fresh Sandbox without OrchidApp state is required.'
    }
    Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes
    $null = New-Item -ItemType Directory -Path $work
    foreach ($asset in $case.inputs) {
        $source = Join-Path $inputRoot $asset.name
        $target = Join-Path $work $asset.name
        Copy-Item -LiteralPath $source -Destination $target
        if ((Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -ine $asset.sha256) {
            throw "Checksum mismatch for $($asset.name)."
        }
    }
    $specimen = Join-Path $work 'specimen.zip'
    if ($Upgrade) {
        $originalModulePath = $env:PSModulePath
        $legacyModules = Join-Path $inputRoot 'legacy-archive-module'
        if (Test-Path -LiteralPath $legacyModules) {
            $env:PSModulePath = $legacyModules + ';' + $originalModulePath
            $report.legacyArchiveModule = $legacyModules
        }
        Install-Orchid 'previous.exe' 'install-v1.4.0'
        Start-Orchid
        Stop-Orchid
        Invoke-Native 'powershell.exe' @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File',
            ('"' + (Join-Path $install 'tools\restore-orchidapp.ps1') + '"'), '-BackupZip', $specimen)
        $beforeUpgrade = Get-MediaInventory
        if ($beforeUpgrade.Count -ne 20) { throw 'Historical restore did not produce 20 media files.' }
        $env:PSModulePath = $originalModulePath
        Complete-Stage 'historical-offline-restore'
    }

    Install-Orchid 'current.exe' 'install-v1.4.1'
    Start-Orchid
    Complete-Stage 'launcher-startup-and-readiness'
    $null = Wait-For 'launcher startup backup result' {
        if (!(Test-Path -LiteralPath $log)) { return }
        $launcherText = Get-Content -LiteralPath $log -Raw
        $backupError = [regex]::Match($launcherText, '(?m)^.*BACKUP ERROR:.*$')
        if ($backupError.Success) { throw "Published launcher startup backup failed. $($backupError.Value.Trim())" }
        if ($launcherText -match 'Backup completed successfully\.|Automatic backup not required\.|Skipping automatic safety backup\.') {
            return $true
        }
    }
    Invoke-Button (Get-Window 'OrchidApp Launcher -*') 'Open OrchidApp'
    Complete-Stage 'launcher-open'
    if ($Upgrade) {
        if (Compare-Object -ReferenceObject $beforeUpgrade -DifferenceObject (Get-MediaInventory)) {
            throw 'Published upgrade changed historical media.'
        }
        Complete-Stage 'upgrade-media-preserved'
    } else {
        Restore-Orchid $specimen
        Stop-Orchid
        Start-Orchid
        if ((Get-MediaInventory).Count -ne 20) { throw 'Specimen restore did not produce 20 media files.' }
        Complete-Stage 'launcher-specimen-restore'
    }

    $browser = Invoke-Browser @('--jpeg', (Join-Path $work 'large.jpg'), '--heic', (Join-Path $work 'large.heic'))
    $witness = [regex]::Match(($browser -join "\n"), '--reopen ([1-9][0-9]*) (Browserfixture[0-9a-f]+edited)')
    if (!$witness.Success) { throw 'Browser run did not identify its saved witness plant.' }
    $reopen = @('--reopen', $witness.Groups[1].Value, $witness.Groups[2].Value)
    Complete-Stage 'shared-browser-writes'
    $backupRoot = Join-Path $data 'backups'
    $beforeBackup = @(Get-ChildItem -LiteralPath $backupRoot -File -Filter '*.zip' | Select-Object -ExpandProperty FullName)
    Invoke-Button (Get-Window 'OrchidApp Launcher -*') 'Back up now'
    Invoke-Button (Get-Window 'Backup Complete' 240) 'OK'
    $archives = @(Get-ChildItem -LiteralPath $backupRoot -File -Filter '*.zip' |
        Where-Object { $_.FullName -notin $beforeBackup })
    if ($archives.Count -ne 1) { throw 'Expected one new managed backup archive.' }
    $roundTrip = Join-Path $work 'round-trip.zip'
    Copy-Item -LiteralPath $archives[0].FullName -Destination $roundTrip
    $payload = Join-Path $work 'backup-payload'
    . (Join-Path $install 'tools\Backup-Contract.ps1')
    Expand-CheckedBackup $roundTrip $payload
    $null = Read-BackupPayload $payload
    $beforeRestore = Get-MediaInventory
    $report.backupSha256 = (Get-FileHash -LiteralPath $roundTrip -Algorithm SHA256).Hash
    Complete-Stage 'managed-backup-and-archive-validation'

    Stop-Orchid
    Start-Orchid
    $null = Invoke-Browser $reopen
    Complete-Stage 'restart-and-browser-reopen'
    Restore-Orchid $roundTrip
    Stop-Orchid
    Start-Orchid
    $null = Invoke-Browser $reopen
    if (Compare-Object -ReferenceObject $beforeRestore -DifferenceObject (Get-MediaInventory)) {
        throw 'Backup round trip changed the media inventory.'
    }
    Complete-Stage 'round-trip-integrity'
    Stop-Orchid

    $beforeUninstall = @(Get-PersistentInventory | Sort-Object)
    if ($beforeUninstall.Count -eq 0) { throw 'Persistent uninstall witnesses are missing.' }
    Invoke-Native (Join-Path $install 'unins000.exe') @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', "/LOG=$evidence\uninstall.log")
    if (Test-Path -LiteralPath $launcherExe) { throw 'Uninstall did not remove the launcher.' }
    $afterUninstall = @(Get-PersistentInventory | Sort-Object)
    if ($afterUninstall.Count -eq 0 -or (Compare-Object $beforeUninstall $afterUninstall)) {
        throw 'Uninstall changed the persistent state.'
    }
    Complete-Stage 'uninstall-preservation'
    $report.status = 'passed'
} catch {
    $report.status = 'failed'
    $report.error = $_.Exception.Message
    if (Test-Path -LiteralPath $log) {
        if (Select-String -LiteralPath $log -SimpleMatch 'Microsoft.PowerShell.Archive' -Quiet) {
            try {
                Import-Module Microsoft.PowerShell.Archive -ErrorAction Stop
                $report.archiveModuleDiagnostic = 'Import succeeded in the guest harness process.'
            } catch {
                $report.archiveModuleDiagnostic = $_.Exception.Message
            }
        }
    }
    throw
} finally {
    if (Test-Path -LiteralPath $log) {
        Copy-Item -LiteralPath $log -Destination (Join-Path $evidence 'launcher.log')
    }
    $report.finishedUtc = [DateTime]::UtcNow.ToString('o')
    Write-Report
}
