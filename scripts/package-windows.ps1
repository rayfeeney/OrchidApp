param(
    [string]$Configuration = "Release",
    [string]$Runtime = "win-x64",
    [int]$MariaDbPort = 3308
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)

    Write-Host ""
    Write-Host "==> $Message"
}

function Test-PortListening {
    param(
        [int]$Port
    )

    $listener = Get-NetTCPConnection `
        -LocalPort $Port `
        -State Listen `
        -ErrorAction SilentlyContinue

    return $null -ne $listener
}

function Get-OrchidAppVersion {
    param(
        [string]$DirectoryBuildPropsPath
    )

    if (-not (Test-Path $DirectoryBuildPropsPath)) {
        return [pscustomobject]@{
            ProductVersion = "1.1.0"
            BuildVersion   = "1.1.0.0"
            BuildNumber    = 0
        }
    }

    [xml]$props = Get-Content $DirectoryBuildPropsPath

    $fileVersion = $props.Project.PropertyGroup.FileVersion

    if ([string]::IsNullOrWhiteSpace($fileVersion)) {
        $fileVersion = "1.1.0.0"
    }

    $parts = $fileVersion.Split(".")

    if ($parts.Count -ne 4) {
        throw "Invalid FileVersion in Directory.Build.props: $fileVersion. Expected Major.Minor.Patch.Build."
    }

    return [pscustomobject]@{
        ProductVersion = "$($parts[0]).$($parts[1]).$($parts[2])"
        BuildVersion   = $fileVersion
        BuildNumber    = [int]$parts[3]
    }
}

function Set-OrchidAppVersion {
    param(
        [string]$DirectoryBuildPropsPath,
        [string]$ProductVersion,
        [int]$BuildNumber
    )

    if ($ProductVersion -notmatch '^\d+\.\d+\.\d+$') {
        throw "Invalid product version: $ProductVersion. Expected Major.Minor.Patch, for example 1.2.0."
    }

    $buildVersion = "$ProductVersion.$BuildNumber"
    $assemblyVersion = "$ProductVersion.0"
    $informationalVersion = "$ProductVersion+build.$BuildNumber"

    $content = @"
<Project>
  <PropertyGroup>
    <!-- Public product version shown to users -->
    <Version>$ProductVersion</Version>

    <!-- Assembly identity version. Keep aligned with the public product version. -->
    <AssemblyVersion>$assemblyVersion</AssemblyVersion>

    <!-- Full internal packaged build version -->
    <FileVersion>$buildVersion</FileVersion>

    <!-- Public version plus internal build metadata -->
    <InformationalVersion>$informationalVersion</InformationalVersion>
  </PropertyGroup>
</Project>
"@

    Set-Content `
        -Path $DirectoryBuildPropsPath `
        -Value $content `
        -Encoding UTF8

    return [pscustomobject]@{
        ProductVersion        = $ProductVersion
        AssemblyVersion       = $assemblyVersion
        FileVersion           = $buildVersion
        InformationalVersion  = $informationalVersion
    }
}

function Update-OrchidAppVersionForPackaging {
    param(
        [string]$DirectoryBuildPropsPath
    )

    $currentVersion = Get-OrchidAppVersion -DirectoryBuildPropsPath $DirectoryBuildPropsPath

    Write-Host ""
    Write-Host "Current OrchidApp product version: $($currentVersion.ProductVersion)"
    Write-Host "Current OrchidApp build version:   $($currentVersion.BuildVersion)"
    Write-Host ""

    $enteredProductVersion = Read-Host "Enter public product version, or press Enter to keep $($currentVersion.ProductVersion) and increment build"

    if ([string]::IsNullOrWhiteSpace($enteredProductVersion)) {
        $newProductVersion = $currentVersion.ProductVersion
        $newBuildNumber = $currentVersion.BuildNumber + 1
    }
    else {
        $newProductVersion = $enteredProductVersion.Trim()
        $newBuildNumber = 0
    }

    $newVersion = Set-OrchidAppVersion `
        -DirectoryBuildPropsPath $DirectoryBuildPropsPath `
        -ProductVersion $newProductVersion `
        -BuildNumber $newBuildNumber

    Write-Host ""
    Write-Host "Stamped OrchidApp version:"
    Write-Host "  Product version:       $($newVersion.ProductVersion)"
    Write-Host "  Assembly version:      $($newVersion.AssemblyVersion)"
    Write-Host "  File version:          $($newVersion.FileVersion)"
    Write-Host "  Informational version: $($newVersion.InformationalVersion)"

    return $newVersion
}

# Resolve repo root from this script location.
    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $RepoRoot = Resolve-Path (Join-Path $ScriptDir "..")
    $DirectoryBuildProps = Join-Path $RepoRoot "Directory.Build.props"

    $DistRoot = Join-Path $RepoRoot "dist\windows\OrchidApp"

    $WebProject = Join-Path $RepoRoot "src\OrchidApp.Web\OrchidApp.Web.csproj"
    $LauncherProject = Join-Path $RepoRoot "src\OrchidApp.Launcher\OrchidApp.Launcher.csproj"

    $DatabaseSource = Join-Path $RepoRoot "database"
    $MariaDbRuntimeSource = Join-Path $RepoRoot "app\runtime\mariadb\win-x64"
    $MariaDbDataSource = Join-Path $RepoRoot "app\data\mariadb"

    $DatabaseDest = Join-Path $DistRoot "database"
    $MariaDbRuntimeDest = Join-Path $DistRoot "runtime\mariadb\win-x64"
    $MariaDbDataDest = Join-Path $DistRoot "data\mariadb"

    $MariaDbExe = Join-Path $MariaDbRuntimeDest "bin\mariadbd.exe"
    $MariaDbClient = Join-Path $MariaDbRuntimeDest "bin\mariadb.exe"
    $MariaDbAdmin = Join-Path $MariaDbRuntimeDest "bin\mariadb-admin.exe"

    $LibVipsRuntimeSource = Join-Path $RepoRoot "app\runtime\libvips\win-x64"
    $LibVipsRuntimeDest = Join-Path $DistRoot "runtime\libvips\win-x64"
    $LibVipsBinDest = Join-Path $LibVipsRuntimeDest "bin"

    $ToolsSource = Join-Path $RepoRoot "app\tools"
    $ToolsDest = Join-Path $DistRoot "tools"
    $BackupScriptSource = Join-Path $ToolsSource "backup-orchidapp.ps1"
    $UserGuidesSource = Join-Path $RepoRoot "\docs\user-guides\windows"
    $UserGuidesDest = Join-Path $DistRoot "user-guides"


Write-Step "Stamping application version"

    $AppVersion = Update-OrchidAppVersionForPackaging `
        -DirectoryBuildPropsPath $DirectoryBuildProps

    $ZipPath = Join-Path $RepoRoot "dist\windows\OrchidApp-v$($AppVersion.ProductVersion)-Windows-$Runtime.zip"

Write-Step "Checking source paths"

    if (-not (Test-Path $WebProject)) {
        throw "Web project not found: $WebProject"
    }

    if (-not (Test-Path $LauncherProject)) {
        throw "Launcher project not found: $LauncherProject"
    }

    if (-not (Test-Path $DatabaseSource)) {
        throw "Database folder not found: $DatabaseSource"
    }

    if (-not (Test-Path $MariaDbRuntimeSource)) {
        throw "MariaDB runtime folder not found: $MariaDbRuntimeSource"
    }

    if (-not (Test-Path $MariaDbDataSource)) {
        throw "MariaDB data folder not found: $MariaDbDataSource"
    }

    if (-not (Test-Path $ToolsSource)) {
        throw "Tools folder not found: $ToolsSource"
    }

    if (-not (Test-Path $LibVipsRuntimeSource)) {
        throw "libvips runtime folder not found: $LibVipsRuntimeSource"
    }

    if (-not (Test-Path $BackupScriptSource)) {
        throw "Backup script not found: $BackupScriptSource"
    }

Write-Step "Checking MariaDB port is free"

    if (Test-PortListening -Port $MariaDbPort) {
        throw "Port $MariaDbPort is already in use. Close OrchidApp/MariaDB before packaging."
    }

Write-Step "Cleaning package folder"

    if (Test-Path $DistRoot) {
        Remove-Item $DistRoot -Recurse -Force
    }

New-Item -ItemType Directory -Path $DistRoot | Out-Null

Write-Step "Publishing OrchidApp.Web"

    dotnet publish $WebProject `
        -c $Configuration `
        -r $Runtime `
        --self-contained true `
        -o $DistRoot

    if ($LASTEXITCODE -ne 0) {
        throw "Web publish failed."
    }

Write-Step "Publishing OrchidApp.Launcher"

    dotnet publish $LauncherProject `
        -c $Configuration `
        -r $Runtime `
        --self-contained true `
        -o $DistRoot

    if ($LASTEXITCODE -ne 0) {
        throw "Launcher publish failed."
    }

Write-Step "Copying database scripts"

    Copy-Item `
        -Path $DatabaseSource `
        -Destination $DatabaseDest `
        -Recurse `
        -Force

Write-Step "Copying MariaDB runtime"

    New-Item -ItemType Directory -Path (Split-Path -Parent $MariaDbRuntimeDest) -Force | Out-Null

    Copy-Item `
        -Path $MariaDbRuntimeSource `
        -Destination $MariaDbRuntimeDest `
        -Recurse `
        -Force

Write-Step "Copying MariaDB data directory"

    New-Item -ItemType Directory -Path (Split-Path -Parent $MariaDbDataDest) -Force | Out-Null

    Copy-Item `
        -Path $MariaDbDataSource `
        -Destination $MariaDbDataDest `
        -Recurse `
        -Force

Write-Step "Copying packaged tools"

    Copy-Item `
        -Path $ToolsSource `
        -Destination $ToolsDest `
        -Recurse `
        -Force

Write-Step "Copying user guides"

    Copy-Item `
        -Path $UserGuidesSource `
        -Destination $UserGuidesDest `
        -Recurse `
        -Force

Write-Step "Copying libvips runtime"

    New-Item -ItemType Directory -Path (Split-Path -Parent $LibVipsRuntimeDest) -Force | Out-Null

    Copy-Item `
        -Path $LibVipsRuntimeSource `
        -Destination $LibVipsRuntimeDest `
        -Recurse `
        -Force


Write-Step "Removing packaged application database cleanly"

    $PackagedOrchidsFolder = Join-Path $MariaDbDataDest "orchids"

    if (Test-Path $PackagedOrchidsFolder) {
        Write-Host "Removing packaged trigger metadata before database drop..."

        $TriggerMetadataFiles = @()

        $TriggerMetadataFiles += Get-ChildItem `
            -Path $PackagedOrchidsFolder `
            -Filter "*.TRG" `
            -File `
            -ErrorAction SilentlyContinue

        $TriggerMetadataFiles += Get-ChildItem `
            -Path $PackagedOrchidsFolder `
            -Filter "*.TRN" `
            -File `
            -ErrorAction SilentlyContinue

        foreach ($TriggerMetadataFile in $TriggerMetadataFiles) {
            Write-Host "Removing trigger metadata file: $($TriggerMetadataFile.FullName)"
            Remove-Item -Path $TriggerMetadataFile.FullName -Force
        }

        Write-Host "Removed $($TriggerMetadataFiles.Count) trigger metadata file(s)."
    }

    if (-not (Test-Path $MariaDbExe)) {
        throw "MariaDB server executable not found: $MariaDbExe"
    }

    if (-not (Test-Path $MariaDbClient)) {
        throw "MariaDB client executable not found: $MariaDbClient"
    }

    if (-not (Test-Path $MariaDbAdmin)) {
        throw "MariaDB admin executable not found: $MariaDbAdmin"
    }

    $mariaDbProcess = Start-Process `
        -FilePath $MariaDbExe `
        -ArgumentList "--datadir=`"$MariaDbDataDest`" --port=$MariaDbPort --bind-address=127.0.0.1 --console" `
        -WorkingDirectory $DistRoot `
        -PassThru `
        -NoNewWindow

    try {
        Write-Host "Waiting for packaged MariaDB to accept connections..."

        $ready = $false

        for ($i = 0; $i -lt 30; $i++) {
            & $MariaDbClient `
                -h 127.0.0.1 `
                -P $MariaDbPort `
                -u orchid `
                -porchid `
                -e "SELECT 1;" `
                2>$null | Out-Null

            if ($LASTEXITCODE -eq 0) {
                $ready = $true
                break
            }

            if ($mariaDbProcess.HasExited) {
                throw "Packaged MariaDB exited early. ExitCode=$($mariaDbProcess.ExitCode)"
            }

            Start-Sleep -Seconds 1
        }

        if (-not $ready) {
            throw "Packaged MariaDB did not become ready."
        }

        Write-Host "Dropping packaged orchids database..."

        & $MariaDbClient `
            -h 127.0.0.1 `
            -P $MariaDbPort `
            -u orchid `
            -porchid `
            -e "DROP DATABASE IF EXISTS orchids;"

        if ($LASTEXITCODE -ne 0) {
            throw "Failed to drop packaged orchids database."
        }

        Write-Host "Requesting clean MariaDB shutdown..."

        & $MariaDbAdmin `
            -h 127.0.0.1 `
            -P $MariaDbPort `
            -u orchid_shutdown `
            -porchid_shutdown `
            shutdown

        if ($LASTEXITCODE -ne 0) {
            throw "MariaDB shutdown command failed."
        }

        Write-Host "Waiting for MariaDB process to exit..."

        if (-not $mariaDbProcess.WaitForExit(30000)) {
            throw "MariaDB did not exit cleanly after shutdown request."
        }

        if ($mariaDbProcess.ExitCode -ne 0) {
            throw "MariaDB exited with non-zero code: $($mariaDbProcess.ExitCode)"
        }

        Write-Host "Packaged MariaDB stopped cleanly."
    }
    finally {
        if ($mariaDbProcess -and -not $mariaDbProcess.HasExited) {
            Stop-Process -Id $mariaDbProcess.Id -Force
            throw "Packaged MariaDB had to be force-stopped during cleanup."
        }
    }

Write-Host "Checking MariaDB listener has stopped..."

    for ($i = 0; $i -lt 15; $i++) {
        if (-not (Test-PortListening -Port $MariaDbPort)) {
            Write-Host "MariaDB listener stopped."
            break
        }

        Start-Sleep -Milliseconds 500
    }

    if (Test-PortListening -Port $MariaDbPort) {
        throw "MariaDB stopped, but port $MariaDbPort is still listening."
    }

Write-Step "Checking packaged MariaDB data state"

    $PackagedOrchidsFolder = Join-Path $MariaDbDataDest "orchids"

    if (Test-Path $PackagedOrchidsFolder) {
        Write-Host "Packaged application database exists:" -ForegroundColor Red
        Write-Host $PackagedOrchidsFolder -ForegroundColor Red
        throw "Package validation failed. Packaged orchids database folder must not exist."
    }
    else {
        Write-Host "No packaged orchids database folder found." -ForegroundColor Green
    }

    $PackagedOrchidsFiles = Get-ChildItem `
        -Path $MariaDbDataDest `
        -Filter "orchids.*" `
        -ErrorAction SilentlyContinue

    if ($PackagedOrchidsFiles) {
        Write-Host "Packaged orchids.* files found:" -ForegroundColor Red
        $PackagedOrchidsFiles | ForEach-Object {
            Write-Host $_.FullName -ForegroundColor Red
        }

        throw "Package validation failed. Packaged orchids.* files must not exist."
    }
    else {
        Write-Host "No packaged orchids.* files found." -ForegroundColor Green
    }

Write-Step "Adding Windows shortcut helper"

    $ShortcutSource = Join-Path $RepoRoot "app\windows\Create-Shortcut.cmd"
    $ShortcutTarget = Join-Path $DistRoot "Create-Shortcut.cmd"

    if (-not (Test-Path $ShortcutSource)) {
        throw "Shortcut helper not found: $ShortcutSource"
    }

    Copy-Item `
        -Path $ShortcutSource `
        -Destination $ShortcutTarget `
        -Force

Write-Step "Validating package contents"

    $RequiredPaths = @(
        (Join-Path $DistRoot "OrchidApp.Launcher.exe"),
        (Join-Path $DistRoot "OrchidApp.Web.exe"),
        (Join-Path $DistRoot "database"),
        (Join-Path $DistRoot "database\schema"),
        (Join-Path $DistRoot "database\migrations"),
        (Join-Path $DistRoot "runtime\mariadb\win-x64"),
        (Join-Path $DistRoot "runtime\mariadb\win-x64\bin\mariadbd.exe"),
        (Join-Path $DistRoot "runtime\mariadb\win-x64\bin\mariadb.exe"),
        (Join-Path $DistRoot "runtime\mariadb\win-x64\bin\mariadb-admin.exe"),
        (Join-Path $DistRoot "runtime\mariadb\win-x64\bin\mariadb-dump.exe"),
        (Join-Path $DistRoot "runtime\libvips\win-x64"),
        (Join-Path $DistRoot "runtime\libvips\win-x64\bin"),
        (Join-Path $DistRoot "data"),
        (Join-Path $DistRoot "data\mariadb"),
        (Join-Path $DistRoot "tools"),
        (Join-Path $DistRoot "tools\backup-orchidapp.ps1"),
        (Join-Path $DistRoot "tools\restore-orchidapp.ps1"),
        (Join-Path $DistRoot "Legal"),
        (Join-Path $DistRoot "Legal\LICENSE"),
        (Join-Path $DistRoot "Legal\THIRD_PARTY_NOTICES.md"),
        (Join-Path $DistRoot "Legal\mariadb\COPYING"),
        (Join-Path $DistRoot "Legal\mariadb\THIRDPARTY"),
        (Join-Path $DistRoot "Legal\libvips\LICENSE")
    )

    foreach ($RequiredPath in $RequiredPaths) {
        if (-not (Test-Path $RequiredPath)) {
            throw "Package validation failed. Required path missing: $RequiredPath"
        }

        Write-Host "OK: $RequiredPath" -ForegroundColor Green
    }

    Write-Step "Validating libvips runtime"

    $RequiredLibVipsDlls = @(
        "libvips-42.dll",
        "libgobject-2.0-0.dll",
        "libglib-2.0-0.dll",
        "libgio-2.0-0.dll"
    )

    foreach ($Dll in $RequiredLibVipsDlls) {
        $Path = Join-Path $LibVipsBinDest $Dll

        if (-not (Test-Path $Path)) {
            throw "Package validation failed. Required libvips DLL missing: $Path"
        }

        Write-Host "OK: $Path" -ForegroundColor Green
    } 

    if (Test-PortListening -Port $MariaDbPort) {
        throw "Package validation failed. Port $MariaDbPort is still in use."
    }

    Write-Host "Package validation passed." -ForegroundColor Green

Write-Step "Creating Windows package ZIP"

    if (Test-Path $ZipPath) {
        Remove-Item $ZipPath -Force
    }

    Compress-Archive `
        -Path $DistRoot `
        -DestinationPath $ZipPath `
        -Force

    Write-Host ""
    Write-Host "ZIP package:" -ForegroundColor Green
    Write-Host $ZipPath -ForegroundColor Green

    Write-Step "Windows package created successfully"

Write-Host ""
Write-Host "Package folder:"
Write-Host $DistRoot