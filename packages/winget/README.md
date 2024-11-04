# Lando Setup

A Windows application that bundles and executes the Lando setup script, passing through any command line arguments.

## Prerequisites

Before building, ensure you have:
- CMake (3.10 or higher)
- Visual Studio Build Tools or Windows SDK

You can install the prerequisites using winget:

```powershell
# Install CMake
winget install Kitware.CMake

# Install Visual Studio Build Tools with x64 and ARM64 support
winget install Microsoft.VisualStudio.2022.BuildTools --override "--add Microsoft.VisualStudio.Workload.VCTools --add Microsoft.VisualStudio.Component.VC.Tools.ARM64 -add Microsoft.VisualStudio.Component.UWP.VC.ARM64 --includeRecommended"
```

After installation, restart your terminal and verify the setup:
```powershell
cmake --version
msbuild -version
```

## Building

Build both architectures:
```powershell
.\build.ps1 -Version "3.20.8"

# Skip ARM64 build
.\build.ps1 -SkipArm
```

The compiled executables will be placed in `../../dist/`:
- `setup-lando-win-x64.exe`
- `setup-lando-win-arm64.exe`
