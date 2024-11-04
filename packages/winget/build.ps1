param(
    [string]$Version = "1.0.0",
    [switch]$SkipArm = $false
)

# Function to check if a command exists
function Test-Command($CommandName) {
    return $null -ne (Get-Command $CommandName -ErrorAction SilentlyContinue)
}

# Function to check if ARM64 build tools are installed
function Test-ARM64Support {
    # First check if vswhere exists
    $vsWhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (-not (Test-Path $vsWhere)) {
        Write-Debug "vswhere.exe not found at expected location"
        return $false
    }

    # Try different vswhere queries
    $installPath = $null
    
    # Try BuildTools first
    Write-Debug "Checking for BuildTools installation..."
    $installPath = & $vsWhere -products Microsoft.VisualStudio.Product.BuildTools -latest -property installationPath
    
    # If not found, try Visual Studio
    if (-not $installPath) {
        Write-Debug "Checking for Visual Studio installation..."
        $installPath = & $vsWhere -products * -requires Microsoft.VisualStudio.Workload.NativeDesktop -latest -property installationPath
    }

    if (-not $installPath) {
        Write-Debug "No Visual Studio or BuildTools installation found"
        Write-Debug "vswhere output: $(& $vsWhere -products * -format json)"
        return $false
    }

    Write-Debug "Found installation at: $installPath"

    # Check common paths for ARM64 support
    $possiblePaths = @(
        "MSBuild\Microsoft\VC\v170\Platforms\ARM64\Platform.targets",
        "VC\Tools\MSVC\*\bin\HostX64\arm64\cl.exe"
    )

    foreach ($path in $possiblePaths) {
        if ($path -like "*\*\*") {
            # Handle wildcard paths
            $searchPath = Join-Path $installPath $path
            $matches = Get-ChildItem -Path (Split-Path $searchPath -Parent) -Filter (Split-Path $searchPath -Leaf) -Recurse -ErrorAction SilentlyContinue
            if ($matches) {
                Write-Debug "Found ARM64 support at: $($matches[0].FullName)"
                return $true
            }
        } else {
            $fullPath = Join-Path $installPath $path
            if (Test-Path $fullPath) {
                Write-Debug "Found ARM64 support at: $fullPath"
                return $true
            }
        }
    }

    Write-Debug "No ARM64 support found in Visual Studio installation"
    return $false
}

# Function to get Visual Studio version
function Get-VisualStudioVersion {
    $vsWhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (Test-Path $vsWhere) {
        # Try BuildTools first
        $version = & $vsWhere -products Microsoft.VisualStudio.Product.BuildTools -latest -property installationVersion
        
        # If not found, try Visual Studio
        if (-not $version) {
            $version = & $vsWhere -products * -requires Microsoft.VisualStudio.Workload.NativeDesktop -latest -property installationVersion
        }
        
        if ($version) {
            return $version.Split('.')[0]
        }
    }
    return "17" # Default to VS2022 if we can't detect
}

# Check if we're running from WSL path
$currentPath = (Get-Location).Path
if ($currentPath -like "\\wsl.localhost\*") {
    Write-Error @"
Error: Building from a WSL path is not supported.
Please run this script from a Windows path instead.
"@
    exit 1
}

# Check prerequisites
if (-not (Test-Command "cmake")) {
    Write-Error @"
CMake is not installed or not in PATH. To install CMake, run:
        winget install Kitware.CMake

After installation, restart your terminal and try again.
"@
    exit 1
}

$msbuildPath = "C:/Program Files (x86)/Microsoft Visual Studio/2022/BuildTools/MSBuild/Current/Bin/amd64/MSBuild.exe"
if (-not (Test-Path $msbuildPath)) {
    Write-Error @"
MSBuild not found at $msbuildPath. To install Visual Studio Build Tools, run:
        winget install Microsoft.VisualStudio.2022.BuildTools --override "--add Microsoft.VisualStudio.Workload.VCTools --add Microsoft.VisualStudio.Component.VC.Tools.ARM64 --includeRecommended"

After installation, restart your terminal and try again.
"@
    exit 1
}

# Check ARM64 support
if (-not $SkipArm -and -not (Test-ARM64Support)) {
    Write-Warning @"
ARM64 build tools are not installed. To install them:
1. Open Visual Studio Installer
2. Modify your Visual Studio installation
3. Under 'Individual components', select:
     - MSVC v143 - VS 2022 C++ ARM64/ARM64EC build tools (latest)
     - C++ Universal Windows Platform tools (ARM64/ARM64EC)

Continuing with x64 build only. Use -SkipArm to suppress this warning.
"@
    $SkipArm = $true
}

# Clean up any existing build directories
if (Test-Path "build-x64") {
    Remove-Item -Recurse -Force "build-x64"
}
if (-not $SkipArm -and (Test-Path "build-arm64")) {
    Remove-Item -Recurse -Force "build-arm64"
}

# Strip 'v' prefix if present
$Version = $Version -replace '^v', ''

# Convert version (e.g. 3.20.8) to RC format (3,20,8,0)
$RcVersion = ($Version -split '\.' + ',0' * (4 - ($Version -split '\.').Count)) -join ','

Write-Host "Updating version information to $Version..." -ForegroundColor Green

# Update RC file version info
$content = Get-Content setup-lando.rc -Raw
$content = $content -replace 'FILEVERSION\s+1,0,0,0', "FILEVERSION         $RcVersion"
$content = $content -replace 'PRODUCTVERSION\s+1,0,0,0', "PRODUCTVERSION    $RcVersion"
$content = $content -replace '"FileVersion",\s*"1.0.0.0"', "`"FileVersion`",            `"$Version`""
$content = $content -replace '"ProductVersion",\s*"1.0.0.0"', "`"ProductVersion`",     `"$Version`""
Set-Content setup-lando.rc $content

# Update manifest version
$content = Get-Content setup-lando.manifest -Raw
$content = $content -replace 'version="1.0.0.0"', "version=`"$Version`""
Set-Content setup-lando.manifest $content

# Get Visual Studio version
$vsVersion = Get-VisualStudioVersion
$generator = "Visual Studio $vsVersion 2022"

Write-Host "Using generator: $generator" -ForegroundColor Green

# Create dist directory if it doesn't exist
$distPath = Join-Path (Resolve-Path "..\..\").Path "dist"
if (-not (Test-Path $distPath)) {
        New-Item -ItemType Directory -Path $distPath -Force
}

# Remove existing executables if they exist
$x64Exe = Join-Path $distPath "setup-lando-win-x64.exe"
$arm64Exe = Join-Path $distPath "setup-lando-win-arm64.exe"

if (Test-Path $x64Exe) {
        Remove-Item $x64Exe -Force
}
if (-not $SkipArm -and (Test-Path $arm64Exe)) {
        Remove-Item $arm64Exe -Force
}

Write-Host "Building x64 version..." -ForegroundColor Green
cmake -G $generator -A x64 -B build-x64 .
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to configure x64 build"
    exit $LASTEXITCODE
}

# Ensure the dist directory exists before building
New-Item -ItemType Directory -Path $distPath -Force -ErrorAction SilentlyContinue

cmake --build build-x64 --config Release
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to build x64 version"
    exit $LASTEXITCODE
}

if (-not $SkipArm) {
    Write-Host "Building ARM64 version..." -ForegroundColor Green
    cmake -G $generator -A ARM64 -B build-arm64 .
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to configure ARM64 build"
        exit $LASTEXITCODE
    }

    cmake --build build-arm64 --config Release
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to build ARM64 version"
        exit $LASTEXITCODE
    }
}

Write-Host "Build completed successfully!" -ForegroundColor Green
Write-Host "Executables can be found in ../../dist/" -ForegroundColor Green
