param(
    [string]$Configuration = "Release",
    [string]$Runtime = "linux-arm64"
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)

    Write-Host ""
    Write-Host "==> $Message"
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
        ProductVersion       = $ProductVersion
        AssemblyVersion      = $assemblyVersion
        FileVersion          = $buildVersion
        InformationalVersion = $informationalVersion
    }
}

function Update-OrchidAppVersionForPackaging {
    param(
        [string]$DirectoryBuildPropsPath
    )

    $currentVersion = Get-OrchidAppVersion `
        -DirectoryBuildPropsPath $DirectoryBuildPropsPath

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
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Resolve-Path (Join-Path $ScriptRoot "..")

$DirectoryBuildProps = Join-Path $RepoRoot "Directory.Build.props"

Write-Step "Stamping application version"

$AppVersion = Update-OrchidAppVersionForPackaging `
    -DirectoryBuildPropsPath $DirectoryBuildProps

$PackageName = "OrchidApp-v$($AppVersion.ProductVersion)-RaspberryPi-Linux-arm64"

$DistRoot = Join-Path $RepoRoot "dist"
$PlatformDistRoot = Join-Path $DistRoot "linuxpi"
$PackageRoot = Join-Path $PlatformDistRoot "OrchidApp"
$AppOutput = Join-Path $PackageRoot "app"
$ZipPath = Join-Path $PlatformDistRoot "$PackageName.zip"

Write-Step "Checking source paths"

$WebProject = Join-Path $RepoRoot "src\OrchidApp.Web\OrchidApp.Web.csproj"
$DatabaseSource = Join-Path $RepoRoot "database"
$InfrastructureSource = Join-Path $RepoRoot "infrastructure"
$ReadMeSource = Join-Path $RepoRoot "README.md"
$LinuxUserGuidesSource = Join-Path $RepoRoot "docs\user-guides\linux"

if (-not (Test-Path $WebProject)) {
    throw "Web project not found: $WebProject"
}

if (-not (Test-Path $DatabaseSource)) {
    throw "Database folder not found: $DatabaseSource"
}

Write-Step "Preparing package folders"

if (Test-Path $PlatformDistRoot) {
    Remove-Item $PlatformDistRoot -Recurse -Force
}

New-Item -ItemType Directory -Force -Path $PlatformDistRoot | Out-Null
New-Item -ItemType Directory -Force -Path $AppOutput | Out-Null

Write-Step "Publishing .NET app"

dotnet publish $WebProject `
    -c $Configuration `
    -r $Runtime `
    --self-contained true `
    -o $AppOutput

Write-Step "Copying database files"

Copy-Item `
    -Path $DatabaseSource `
    -Destination (Join-Path $PackageRoot "database") `
    -Recurse

Write-Step "Copying infrastructure files"

if (Test-Path $InfrastructureSource) {
    Copy-Item `
        -Path $InfrastructureSource `
        -Destination (Join-Path $PackageRoot "infrastructure") `
        -Recurse
}

Write-Step "Copying documentation"

if (Test-Path $ReadMeSource) {
    Copy-Item `
        -Path $ReadMeSource `
        -Destination (Join-Path $PackageRoot "README.md")
}

if (Test-Path $LinuxUserGuidesSource) {
    New-Item `
        -ItemType Directory `
        -Force `
        -Path (Join-Path $PackageRoot "docs\user-guides\linux") | Out-Null

    Copy-Item `
        -Path (Join-Path $LinuxUserGuidesSource "*") `
        -Destination (Join-Path $PackageRoot "docs\user-guides\linux") `
        -Recurse
}

Write-Step "Creating ZIP"

Compress-Archive `
    -Path $PackageRoot `
    -DestinationPath $ZipPath `
    -Force

Write-Host ""
Write-Host "Linux/Raspberry Pi package created successfully:"
Write-Host $ZipPath