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
    [switch]$wsl_only,
    [switch]$help
)

$LANDO_DEFAULT_MV = "3"
#$LANDO_SETUP_SH_URL = "https://raw.githubusercontent.com/lando/setup-lando/main/setup-lando.sh"
$LANDO_SETUP_SH_URL = "https://raw.githubusercontent.com/lando/setup-lando/v3/setup-lando.sh"

$resolvedVersion = $null

Set-StrictMode -Version 1

# Normalize debug preference
$DebugPreference = If ($debug) { "Continue" } Else { $DebugPreference }
if ($DebugPreference -eq "Inquire" -or $DebugPreference -eq "Continue") {
    $debug = $true
}
$Host.PrivateData.DebugForegroundColor = "Gray"

# Encoding must be Unicode to support parsing wsl.exe output
[Console]::OutputEncoding = [System.Text.Encoding]::Unicode

function Show-Help {
    Write-Host "Usage: setup-lando.ps1 [-arch <x64|arm64>] [-dest <path>] [-no_setup] [-no_wsl] [-version <version>] [-debug] [-help]"
    Write-Host "  -arch <x64|arm64>  : Architecture to install (defaults to system architecture)"
    Write-Host "  -dest <path>       : Destination path (default: $env:USERPROFILE/.lando/bin)"
    Write-Host "  -no_setup          : Skip setup script"
    Write-Host "  -no_wsl            : Skip WSL setup"
    Write-Host "  -version <version> : Version to install (default: stable)"
    Write-Host "  -wsl_only          : Only install Lando in WSL"
    Write-Host "  -debug             : Enable debug output"
    Write-Host "  -help              : Display this help message"
}

# Validates whether the system environment is supported
function Confirm-Environment {
    # Bail out if this isn't Windows since PowerShell is cross-platform
    Write-Debug "OS is $env:OS"
    if ($env:OS -ne "Windows_NT") {
        throw "This script is only supported on Windows."
    }

    # Windows 10 version 1903 (build 18362) or higher is required for WSL2 support
    $minVersion = [Version]::new(10, 0, 18362, 0)
    $osVersion = [Version][Environment]::OSVersion.Version
    Write-Debug "Windows version: $osVersion"

    if ($osVersion -lt $minVersion) {
        throw "Unsupported Windows version. Minimum required version is $minVersion but you have $osVersion."
    }

    # Check for WSL
    if (Test-Path "$env:WINDIR\system32\wsl.exe") {
        $wslVersion = & wsl.exe --version | Out-String
        Write-Debug "WSL version details: `n$wslVersion"
        $wslList = & wsl.exe --list --verbose | Out-String
        Write-Debug "WSL Instances:`n$wslList"
    }
    else {
        Write-Debug "WSL is not installed."
        if (-not $no_wsl) {
            $Script:no_wsl = $true
        }
        if ($wsl_only) {
            throw "WSL is not installed. Cannot install Lando in WSL."
        }
    }

    # Warn if Docker is not installed
    try {
        # Powershell doesn't like the output encoding from docker.exe
        $dockerVersion = [System.Text.Encoding]::Unicode.GetBytes($(docker.exe --version))
        $dockerVersion = [System.Text.Encoding]::UTF8.GetString($dockerVersion)
        Write-Debug $dockerVersion
    }
    catch {
        Write-Warning "Docker Desktop is not installed. You will need to install Docker Desktop to use Lando."
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
    }
    catch {
        if ($_.CategoryInfo.Activity -eq "Get-Package" -and $_.CategoryInfo.Category -eq "ObjectNotFound") {
            Write-Debug "No previous Lando installation found."
            return
        }
        else {
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
        "3"      = "3-stable";
        "4"      = "4-stable";
        "stable" = "$LANDO_DEFAULT_MV-stable";
        "edge"   = "$LANDO_DEFAULT_MV-edge";
        "dev"    = "$LANDO_DEFAULT_MV-dev";
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
        [Parameter(Mandatory, Position = 0)]
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
    $env:Path = $NewPath + ';' + $env:Path
    Write-Debug "'$NewPath' added to the user-level Path."
}

# Converts a byte size to a human-readable string
#  -Bytes <bytes> : Bytes to convert
function Get-FriendlySize {
    param($Bytes)
    $sizes = 'Bytes,KB,MB,GB,TB,PB,EB,ZB' -split ','
    for ($i = 0; ($Bytes -ge 1kb) -and 
        ($i -lt $sizes.Count); $i++) { $Bytes /= 1kb }
    $N = 2; if ($i -eq 0) { $N = 0 }
    "{0:N$($N)}{1}" -f $Bytes, $sizes[$i]
}

# Downloads and installs Lando
function Install-Lando {
    Write-Debug "Installing Lando in Windows..."
    # Resolve the version alias to a download URL
    try {
        $script:resolvedVersion, $downloadUrl = Resolve-VersionAlias -Version $version
    }
    catch {
        throw "Could not resolve the provided version alias '$version'. Error: $_"
    }

    if (-not $downloadUrl) {
        throw "Could not resolve the download URL for version '$version'."
    }

    $filename = $downloadUrl.Split('/')[-1]
    $landoDir = "$env:LOCALAPPDATA\Lando"
    if (-not (Test-Path $landoDir)) {
        Write-Debug "Creating destination directory $landoDir..."
        New-Item -ItemType Directory -Path $landoDir -Force
    }

    Write-Host "Downloading Lando CLI..."
    $downloadDest = "$landoDir\$filename"
    Write-Debug "From $downloadUrl to $downloadDest..."
    Write-Progress -Activity "Downloading Lando $resolvedVersion" -Status "Preparing..." -PercentComplete 0

    $outputFileStream = [System.IO.FileStream]::new($downloadDest, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write)
    try {
        $httpClient = New-Object System.Net.Http.HttpClient
        $httpCompletionOption = [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead
        $response = $httpClient.GetAsync($downloadUrl, $httpCompletionOption)

        Write-Progress -Activity "Downloading Lando $resolvedVersion" -Status "Starting download..." -PercentComplete 0
        $response.Wait()

        $fileSize = $response.Result.Content.Headers.ContentLength
        $fileSizeString = Get-FriendlySize $fileSize
        
        # Stream the download to the destination file stream
        $downloadTask = $response.Result.Content.CopyToAsync($outputFileStream)
        $previousSize = 0
        $byteChange = @()
        while (-not $downloadTask.IsCompleted) {
            $sleepTime = 500
            Start-Sleep -Milliseconds $sleepTime

            # Calculate the download speed
            $downloaded = $outputFileStream.Position
            $byteChange += ($downloaded - $previousSize)
            $previousSize = $downloaded
            if ($byteChange.Count -gt (1000 / $sleepTime)) {
                $byteChange = $byteChange | Select-Object -Last (1000 / $sleepTime)
            }
            $averageSpeed = $byteChange | Measure-Object -Average | Select-Object -ExpandProperty Average
            $speedString = Get-FriendlySize ($averageSpeed * (1000 / $sleepTime))

            Write-Progress -Activity "Downloading Lando $resolvedVersion" -Status "$(Get-FriendlySize $downloaded)/$fileSizeString (${speedString}/s)" -PercentComplete ($outputFileStream.Position / $fileSize * 100)
        }
        Write-Progress -Activity "Downloading Lando $resolvedVersion" -Status "Download complete" -PercentComplete 100
        Start-Sleep -Milliseconds 200
        $downloadTask.Dispose()

    }
    catch [System.Net.WebException] {
        $message = $_.Exception.Message
        throw "Failed to download Lando from $downloadUrl. Error: $message"
    }
    catch {
        $message = $_.Exception.Message
        throw "Failed to download Lando from $downloadUrl. Error: $_"
    }
    finally {
        $outputFileStream.Close()
    }
    Write-Progress -Activity "Downloading Lando $resolvedVersion" -Completed

    if (-not (Test-Path $dest)) {
        Write-Debug "Creating destination directory $dest..."
        New-Item -ItemType Directory -Path $dest
    }

    $symlinkPath = "$dest\lando.exe"
    if (Test-Path $symlinkPath) {
        Write-Debug "Removing existing file or link at $symlinkPath..."
        Remove-Item -Path $symlinkPath -Force
    }

    try {
        # Set up mklink command
        $QuotedPath = '"{0}"' -f $symlinkPath
        $QuotedTarget = '"{0}"' -f $downloadDest
        $mklink = @('mklink', $QuotedPath, $QuotedTarget)
        (-not $debug -and ($mklink += @('>nul', '2>&1'))) | Out-Null

        # Try to create the link
        Write-Debug "> $($mklink -join ' ')"
        $process = Start-Process -FilePath 'cmd.exe' -ArgumentList "/D /C $($mklink -join ' ')" -NoNewWindow -Wait -PassThru
        
        # Symlink creation will fail if the user doesn't have developer mode enabled in Windows, but hard links work.
        if ($process.ExitCode) {
            Write-Debug "Symlink creation failed with exit code $($process.ExitCode). Trying hard link..."
            $mklink = @('mklink', '/H', $QuotedPath, $QuotedTarget)
            (-not $debug -and ($mklink += @('>nul', '2>&1'))) | Out-Null

            Write-Debug "> $($mklink -join ' ')"
            $process = Start-Process -FilePath 'cmd.exe' -ArgumentList "/D /C $($mklink -join ' ')" -NoNewWindow -Wait -PassThru

            if ($process.ExitCode) {
                Write-Debug "Hard link creation failed with exit code $($process.ExitCode). Trying copy..."
                Copy-Item -Path $downloadDest -Destination $symlinkPath -Force
            }
        }
    }
    catch {
        throw "Failed to create symlink from $symlinkPath to $downloadDest.`nError: $_"
    }

    # Add $dest to system PATH if not already present
    Add-ToPath -NewPath $dest

    # Clear the cache so that new Lando commands are available
    $landoClearCommand = "$symlinkPath --clear"
    Write-Debug "Running '$landoClearCommand'"
    try {
        Invoke-Expression $landoClearCommand
    }
    catch {
        Write-Host $_.Exception.Message
        Write-Host "Failed to run 'lando --clear'. You may need to manually run this command to complete the setup." -ForegroundColor Red
        Write-Debug $_.Exception
    }
}

# Install Lando in WSL2
function Install-LandoInWSL {
    Write-Debug "Installing Lando in WSL..."

    $wslInstances = wsl.exe --list --quiet
    if (-not $wslInstances) {
        Write-Debug "No WSL instances found."
        return
    }
    Write-Debug "Found WSL instances: $wslInstances"

    # Download the Lando installer script that we'll run in WSL
    $wslSetupScript = "$env:TEMP\setup-lando.sh"
    try {
        $originalProgressPreference = $ProgressPreference
        $ProgressPreference = "SilentlyContinue"
        Write-Debug "Downloading Lando Linux installer script from $LANDO_SETUP_SH_URL..."
        Invoke-WebRequest -Uri $LANDO_SETUP_SH_URL -OutFile $wslSetupScript
        $ProgressPreference = $originalProgressPreference
    }
    catch {
        throw "Failed to download Lando Linux installer script from $LANDO_SETUP_SH_URL.`nError: $_"
    }

    # We will pass some of our parameters to the setup script in WSL
    $setupParams = @()
    if ($debug) {
        $setupParams += "--debug"
    }
    if ($arch) {
        $setupParams += "--arch=$arch"
    }
    if ($no_setup) {
        $setupParams += "--no-setup"
    }
    if ($version) {
        $setupParams += "--version=$(if ($resolvedVersion) { $resolvedVersion } Else { $version })"
    }

    Write-Host ""
    foreach ($wslInstance in $wslInstances) {
        # Skip Docker Desktop WSL instance
        if ($wslInstance -match "docker-desktop|docker-desktop-data") {
            Write-Debug "Skipping Docker Desktop WSL instance '$wslInstance'."
            continue
        }
        $currentLoc = Get-Location
        Set-Location $env:TEMP
        
        Write-Host "Installing Lando in WSL distribution '$wslInstance'..."
        $command = "wsl.exe -d $wslInstance --shell-type login ./setup-lando.sh $setupParams"
        Write-Debug "$command"

        try {
            Invoke-Expression $command
        }
        catch {
            Write-Host $_.Exception.Message
            Write-Host "Failed to automatically install Lando into WSL distribution '$wslInstance'. You may need to manually install Lando in this distribution." -ForegroundColor Red
            Write-Debug $_.Exception
        }

        # Check the return code from the setup script
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Failed to automatically install Lando into WSL distribution '$wslInstance'. You may need to manually install Lando in this distribution." -ForegroundColor Red
        }

        Set-Location $currentLoc
        Write-Host ""
    }
}

# Runs the "lando setup" command if Lando is at least version 3.21.0
function Invoke-LandoSetup {
    Write-Debug "Running 'lando setup'..."
    if ($resolvedVersion -lt "v3.21.0") {
        Write-Debug "Skipping 'lando setup' because version $resolvedVersion is less than 3.21.0."
        return
    }
    $landoSetupCommand = "$dest\lando.exe setup -y"
    Write-Debug "Running '$landoSetupCommand'"
    try {
        Invoke-Expression $landoSetupCommand
    }
    catch {
        Write-Host $_.Exception.Message
        Write-Host "Failed to run 'lando setup'. You may need to manually run this command to complete the setup." -ForegroundColor Red
        Write-Debug $_.Exception
    }
}

Write-Debug "Running script with:"
Write-Debug "  -arch: $arch"
Write-Debug "  -debug: $debug"
Write-Debug "  -dest: $dest"
Write-Debug "  -no_setup: $no_setup"
Write-Debug "  -no_wsl: $no_wsl"
Write-Debug "  -version: $version"
Write-Debug "  -wsl_only: $wsl_only"

# It's okay to ask for help
if ($help) {
    Show-Help
    return
}

# Validate the system environment
Confirm-Environment

# Select the appropriate architecture
$arch = Select-Architecture

# Uninstall Lando added by legacy installers
Uninstall-Lando

# Install Lando in Windows
if (-not $wsl_only) {
    Write-Host "Installing Lando..."
    Install-Lando
    if (-not $no_setup) {
        Invoke-LandoSetup
    }
}

# Install Lando in WSL
if (-not $no_wsl) {
    Install-LandoInWSL
}

Write-Host "`nLando setup complete!`n" -ForegroundColor Green
