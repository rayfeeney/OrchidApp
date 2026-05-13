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

# Resolve repo root from this script location.
    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $RepoRoot = Resolve-Path (Join-Path $ScriptDir "..")

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
    $ZipPath = Join-Path $RepoRoot "dist\windows\OrchidApp.zip"

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

Write-Step "Copying libvips runtime"

    New-Item -ItemType Directory -Path (Split-Path -Parent $LibVipsRuntimeDest) -Force | Out-Null

    Copy-Item `
        -Path $LibVipsRuntimeSource `
        -Destination $LibVipsRuntimeDest `
        -Recurse `
        -Force

Write-Step "Removing packaged application database files"

    $ExpectedMariaDbDataDest = Join-Path $DistRoot "data\mariadb"

    if ($MariaDbDataDest -ne $ExpectedMariaDbDataDest) {
        throw "Refusing to remove packaged database files because destination path is unexpected: $MariaDbDataDest"
    }

    if (-not ($MariaDbDataDest -like "*\dist\windows\OrchidApp\data\mariadb")) {
        throw "Refusing to remove packaged database files because destination path is outside the package folder: $MariaDbDataDest"
    }

    $PackagedOrchidsFolder = Join-Path $MariaDbDataDest "orchids"

    if (Test-Path $PackagedOrchidsFolder) {
        Remove-Item `
            -Path $PackagedOrchidsFolder `
            -Recurse `
            -Force

        Write-Host "Removed packaged orchids database folder: $PackagedOrchidsFolder" -ForegroundColor Green
    }
    else {
        Write-Host "No packaged orchids database folder found."
    }

    $PackagedOrchidsFiles = Get-ChildItem `
        -Path $MariaDbDataDest `
        -Filter "orchids.*" `
        -ErrorAction SilentlyContinue

    foreach ($File in $PackagedOrchidsFiles) {
        Remove-Item `
            -Path $File.FullName `
            -Force

        Write-Host "Removed packaged orchids file: $($File.FullName)" -ForegroundColor Green
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