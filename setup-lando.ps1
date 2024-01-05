# Lando Windows Installer Script
#
# This script will download and install Lando on Windows.
# It will also install Lando in all WSL2 instances.
#

# Script parameters must be declared before any other statements
param(
    [string]$arch,
    [switch]$debug,
    [string]$dest = "$env:USERPROFILE\.lando\bin",
    [switch]$no_setup,
    [switch]$no_wsl,
    [string]$version = "stable",
    [switch]$help
)

$LANDO_DEFAULT_MV = "3"
#$LANDO_SETUP_SH_URL = "https://raw.githubusercontent.com/lando/setup-lando/main/setup-lando.sh"
$LANDO_SETUP_SH_URL = "https://raw.githubusercontent.com/lando/setup-lando/v3/setup-lando.sh"

Set-StrictMode -Version 1

# Normalize debug preference
$DebugPreference = If ($debug) {"Continue"} Else {$DebugPreference}
if ($DebugPreference -eq "Inquire" -or $DebugPreference -eq "Continue") {
    $debug = $true
}

# Bail out if this isn't Windows since PowerShell is cross-platform
Write-Debug "OS is $env:OS"
if ($env:OS -ne "Windows_NT") {
    throw "This script is only supported on Windows."
}

Write-Debug "Running script with:"
Write-Debug "  -arch: $arch"
Write-Debug "  -debug: $debug"
Write-Debug "  -dest: $dest"
Write-Debug "  -no_setup: $no_setup"
Write-Debug "  -no_wsl: $no_wsl"
Write-Debug "  -version: $version"

function Show-Help {
    Write-Host "Usage: setup-lando.ps1 [-arch <x64|arm64>] [-dest <path>] [-no_setup] [-no_wsl] [-version <version>] [-debug] [-help]"
    Write-Host "  -arch <x64|arm64>  : Architecture to install (defaults to system architecture)"
    Write-Host "  -dest <path>       : Destination path (default: $env:USERPROFILE/.lando/bin)"
    Write-Host "  -no_setup          : Skip setup script"
    Write-Host "  -no_wsl            : Skip WSL setup"
    Write-Host "  -version <version> : Version to install (default: stable)"
    Write-Host "  -debug             : Enable debug output"
    Write-Host "  -help              : Display this help message"
}

# Validates whether the system environment is supported
function Confirm-Environment {
    # Windows 10 version 1903 (build 18362) or higher is required for WSL2 support
    Write-Debug "Validating Windows version..."
    $minVersion = [Version]::new(10,0,18362,0)
    $osVersion = [Version][Environment]::OSVersion.Version
    Write-Debug "Minimum Windows version: $minVersion"
    Write-Debug "Current Windows version: $osVersion"

    if ($osVersion -lt $minVersion) {
        throw "Unsupported Windows version. Minimum required version is $minVersion but you have $osVersion."
    }
}

# Selects the appropriate architecture for the current system
function Select-Architecture {
    # We only have x64 and arm64 builds of Lando
    Write-Debug "Checking architecture..."
    if (-not $arch) {
        Switch ($Env:PROCESSOR_ARCHITEW6432) {
            "AMD64" { $arch = "x64" }
            "ARM64" { $arch = "arm64" }
            Default { $arch = "x64" }
        }
    }
    if ($arch -notmatch "x64|arm64") {
        throw "Unsupported architecture. Only x64 and arm64 are supported."
    }
    Write-Debug "System architecture: $arch"
    return $arch
}

# Checks for existing Lando installation and uninstalls it
function Uninstall-Lando {
    Write-Debug "Checking for previous Lando installation..."

    # Catch the object not found error
    try {
        Get-Package -Provider Programs -IncludeWindowsInstaller -Name "Lando version*" -ErrorAction Stop | ForEach-Object {
            $previousInstall = $($_.Name)
            Write-Host "Removing previous installation: $previousInstall..."

            $uninstallString = $_.Meta.Attributes["UninstallString"]
            $arguments = "/Silent /SUPPRESSMSGBOXES"
            if (-not $uninstallString) {
                Write-Warning "Could not automatically uninstall $previousInstall. You may need to manually uninstall this version of Lando."
                continue
            }

            Write-Debug "Uninstall command: $uninstallString $arguments"
            Start-Process -Verb RunAs $uninstallString -ArgumentList $arguments -Wait
        }
    } catch {
        if ($_.CategoryInfo.Activity -eq "Get-Package" -and $_.CategoryInfo.Category -eq "ObjectNotFound") {
            Write-Debug "No previous Lando installation found."
            return
        } else {
            Write-Warning "An error occurred while trying to uninstall a previous version of Lando. You may need to manually uninstall it."
            Write-Debug $_.Exception
        }
    }
}

# Resolves a version alias to a download URL
#  -version <version> : Version to resolve
function Resolve-VersionAlias {
    param([string]$Version)

    Write-Debug "Resolving version alias '$Version'..."
    $originalVersion = $Version

    $aliasMap = @{
        "3" = "3-stable";
        "4" = "4-stable";
        "stable" = "$LANDO_DEFAULT_MV-stable";
        "edge" = "$LANDO_DEFAULT_MV-edge";
        "dev" = "$LANDO_DEFAULT_MV-dev";
        "latest" = "$LANDO_DEFAULT_MV-dev";
    }

    if ($aliasMap.ContainsKey($Version)) {
        Write-Debug "Version alias '$Version' mapped to '$($aliasMap[$Version])'"
        $Version = $($aliasMap[$Version])
    }

    # Resolving release aliases
    switch ($Version) {
        "4-stable" {
            Write-Debug "Fetching release alias '4-STABLE' from GitHub..."
            $Version = (Invoke-WebRequest -Uri "https://raw.githubusercontent.com/lando/cli/main/release-aliases/4-STABLE" -UseBasicParsing).Content -replace '\s'
            $downloadUrl = "https://github.com/lando/cli/releases/download/${Version}/lando-win-${arch}-${Version}.exe"
        }
        "3-stable" {
            Write-Debug "Fetching release alias '3-STABLE' from GitHub..."
            $Version = (Invoke-WebRequest -Uri "https://raw.githubusercontent.com/lando/cli/main/release-aliases/3-STABLE" -UseBasicParsing).Content -replace '\s'
            $downloadUrl = "https://github.com/lando/cli/releases/download/${Version}/lando-win-${arch}-${Version}.exe"
        }
        "3-stable-slim" {
            Write-Debug "Fetching release alias '3-STABLE' from GitHub..."  
            $Version = (Invoke-WebRequest -Uri "https://raw.githubusercontent.com/lando/cli/main/release-aliases/3-STABLE" -UseBasicParsing).Content -replace '\s'
            $downloadUrl = "https://github.com/lando/cli/releases/download/${Version}/lando-win-${arch}-${Version}-slim.exe"
        }
        "4-edge" {
            Write-Debug "Fetching release alias '4-EDGE' from GitHub..."
            $Version = (Invoke-WebRequest -Uri "https://raw.githubusercontent.com/lando/cli/main/release-aliases/4-EDGE" -UseBasicParsing).Content -replace '\s'
            $downloadUrl = "https://github.com/lando/cli/releases/download/${Version}/lando-win-${arch}-${Version}.exe"
        }
        "3-edge" {
            Write-Debug "Fetching release alias '3-EDGE' from GitHub..."
            $Version = (Invoke-WebRequest -Uri "https://raw.githubusercontent.com/lando/cli/main/release-aliases/3-EDGE" -UseBasicParsing).Content -replace '\s'
            $downloadUrl = "https://github.com/lando/cli/releases/download/${Version}/lando-win-${arch}-${Version}.exe"
        }
        "3-edge-slim" {
            Write-Debug "Fetching release alias '3-EDGE' from GitHub..."
            $Version = (Invoke-WebRequest -Uri "https://raw.githubusercontent.com/lando/cli/main/release-aliases/3-EDGE" -UseBasicParsing).Content -replace '\s'
            $downloadUrl = "https://github.com/lando/cli/releases/download/${Version}/lando-win-${arch}-${Version}-slim.exe"
        }
        "3-dev" {
            $downloadUrl = "https://files.lando.dev/cli/lando-win-${arch}-dev.exe"
        }
        "3-dev-slim" {
            $downloadUrl = "https://files.lando.dev/cli/lando-win-${arch}-dev-slim.exe"
        }
        "4-dev" {
            $downloadUrl = "https://files.lando.dev/cli/lando-win-${arch}-dev.exe"
        }
        Default {
            Write-Debug "Version '$Version' is a semantic version"
            if (-not $Version.StartsWith("v")) {
                $Version = "v$Version"
            }
            $downloadUrl = "https://github.com/lando/cli/releases/download/${Version}/lando-win-${arch}-${Version}.exe"
        }
    }

    Write-Debug "Resolved version '${originalVersion}' to ${Version} (${downloadUrl})"

    return $Version, $downloadUrl
}

# Adds a path to the system PATH if not already present.
#  -NewPath <path> : Path to add
function Add-ToPath {
    param(
        [Parameter(Mandatory, Position=0)]
        [string]$NewPath
    )
    Write-Debug "Adding $NewPath to system PATH..."

    $regPath = 'registry::HKEY_CURRENT_USER\Environment'

    $currDirs = (Get-Item -LiteralPath $regPath).GetValue('Path', '', 'DoNotExpandEnvironmentNames') -split ';' -ne ''

    if ($NewPath -in $currDirs) {
        Write-Debug "'$NewPath' is already present in the user-level Path environment variable."
        return
    }

    $newValue = ($currDirs + $NewPath) -join ';'

    # Update the registry to make the change permanent.
    Set-ItemProperty -Type ExpandString -LiteralPath $regPath Path $newValue

    # Broadcast WM_SETTINGCHANGE to get the Windows shell to reload the
    # updated environment, via a dummy [Environment]::SetEnvironmentVariable() operation.
    $dummyName = [guid]::NewGuid().ToString()
    [Environment]::SetEnvironmentVariable($dummyName, 'foo', 'User')
    [Environment]::SetEnvironmentVariable($dummyName, [NullString]::value, 'User')

    # Also update the current session's `$env:Path` definition.
    $env:Path = ($env:Path -replace ';$') + ';' + $NewPath

    Write-Debug "'$NewPath' added to the user-level Path."
}

# Downloads and installs Lando
function Install-Lando {
    # Resolve the version alias to a download URL
    try {
        $resolvedVersion, $downloadUrl = Resolve-VersionAlias -Version $version
    } catch {
        throw "Could not resolve the provided version alias '$version'. Error: $_"
    }
    $version = $resolvedVersion

    if (-not $downloadUrl) {
        throw "Could not resolve the download URL for version '$version'."
    }
    $filename = $downloadUrl.Split('/')[-1]
    $tempFile = "$env:TEMP\$filename"

    Write-Host "Downloading Lando CLI..."
    Write-Debug "From $downloadUrl to $tempFile..."
    $wbcl = New-Object System.Net.WebClient
    try {
        # Use WebClient instead of Invoke-WebRequest because Invoke-WebRequest's progress indicator
        # blocks the download to update the status after each byte is received, which is very slow.
        # TODO: Add a non-blocking progress indicator
        $wbcl.DownloadFile($downloadUrl, $tempFile)

    } catch [System.Net.WebException] {
        $message = $_.Exception.Message
        throw "Failed to download Lando from $downloadUrl. Error: $message"
    } catch {
        $message = $_.Exception.Message
        throw "Failed to download Lando from $downloadUrl. Error: $_"
    } finally {
        $wbcl.Dispose()
    }

    if (-not (Test-Path $dest)) {
        Write-Debug "Creating destination directory $dest..."
        New-Item -ItemType Directory -Path $dest
    }

    Write-Debug "Copying $tempFile to $dest..."
    Move-Item -Path $tempFile -Destination $dest\lando.exe -Force

    # Add $dest to system PATH if not already present
    Add-ToPath -NewPath $dest

    # Iterate through WSL instances and install Lando
    if (-not $no_wsl) {
        # Encoding must be Unicode to support parsing wsl.exe output
        [Console]::OutputEncoding = [System.Text.Encoding]::Unicode

        try {
            Write-Debug "Checking for WSL..."
            wsl.exe --help > $null
        } catch {
            Write-Warning "WSL is not installed. Skipping WSL setup."
            return
        }

        $wslInstances = wsl.exe --list --quiet
        if (-not $wslInstances) {
            Write-Debug "No WSL instances found."
            return
        }
        Write-Debug "Found WSL instances: $wslInstances"

        # Download the Lando installer script that we'll run in WSL
        $wslSetupScript = "$env:TEMP\setup-lando.sh"
        try {
            Write-Debug "Downloading Lando Linux installer script from $LANDO_SETUP_SH_URL..."
            Invoke-WebRequest -Uri $LANDO_SETUP_SH_URL -OutFile $wslSetupScript
        } catch {
            throw "Failed to download Lando Linux installer script from $LANDO_SETUP_SH_URL. Error: $_"
        }

        # We will pass some of our parameters to the setup script in WSL
        $setupParams = @()
        if ($debug) {
            $setupParams += "--debug"
        }
        if ($arch) {
            $setupParams += "--arch=$arch"
        }
        if ($version) {
            $setupParams += "--version=$version"
        }

        foreach ($wslInstance in $wslInstances) {
            # Skip Docker Desktop WSL instance
            if ($wslInstance -match "docker-desktop|docker-desktop-data") {
                Write-Debug "Skipping Docker Desktop WSL instance '$wslInstance'."
                continue
            }
            $currentLoc = Get-Location

            Write-Host "Installing Lando in WSL distribution '$wslInstance'..."
            Set-Location $env:TEMP
            wsl.exe -d $wslInstance --shell-type login ./setup-lando.sh $setupParams

            # Exit code 0 means success
            if ($LASTEXITCODE -ne 0) {
                Write-Error "Failed to automatically install Lando into WSL distribution '$wslInstance'. You may need to manually install Lando in this distribution."
            }

            Set-Location $currentLoc
        }
    }

    Write-Host "Lando setup complete!"
}

# It's okay to ask for help
if ($help) {
    Show-Help
    return
}

# Validate the system environment
Confirm-Environment

# Select the appropriate architecture
$arch = Select-Architecture

# Uninstall previous Lando if it's already installed
Uninstall-Lando

# Install Lando
Install-Lando
