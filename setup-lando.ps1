<#
.SYNOPSIS
Lando Windows Installer Script.

.DESCRIPTION
This script is used to download and install Lando on Windows. It also installs Lando in all WSL2 instances.

.EXAMPLE
.\setup-lando.ps1 -Arch x64 -Version edge
Installs Lando with the x64 architecture and the edge version.

.EXAMPLE
.\setup-lando.ps1 -WSLOnly -Version 3.21.0-beta.1
Installs Lando version 3.21.0-beta.1 in WSL only.

.EXAMPLE
.\setup-lando.ps1 -NoWSL
Installs Lando on Windows only, skipping the WSL setup.

#>

# Script parameters must be declared before any other statements
param(
    # Specifies the architecture to install (x64 or arm64). Defaults to the system architecture.
    [ValidateSet("x64", "arm64")]
    [string]$Arch = "x64"

    # Enables debug output.
    [switch]$Debug
    # Specifies the destination path for installation. Defaults to "$env:USERPROFILE\.lando\bin".

    [ValidateNotNullOrEmpty()]
    [string]$Dest = "$env:USERPROFILE\.lando\bin"

    # Download the fat v3 lando binary that comes with official plugins built-in.
    [switch]$Fat

    # Skips running Lando's built-in setup script.
    [switch]$NoSetup

    # Skips the WSL setup.
    [switch]$NoWSL

    # Resumes a previous installation after a reboot.
    [switch]$Resume

    # Specifies the version of Lando to install. Defaults to "stable".
    [ValidateNotNullOrEmpty()]
    [string]$Version = if ($env:LANDO_VERSION -ne $null) { $env:LANDO_VERSION } else { "stable" }

    # Only installs Lando in WSL.
    [switch]$WSLOnly

    # Displays the help message.
    [switch]$Help
)

$SCRIPT_VERSION = $null
$LANDO_DEFAULT_MV = "3"
$LANDO_SETUP_PS1_URL = "https://get.lando.dev/setup-lando.ps1"
$LANDO_SETUP_SH_URL = "https://get.lando.dev/setup-lando.sh"
$LANDO_APPDATA = "$env:LOCALAPPDATA\Lando"

$issueEncountered = $false
$resolvedVersion = $null

Set-StrictMode -Version 1

# Stop execution of this script if any cmdlet fails.
# We'll still need to check exit codes on any exe we run.
$ErrorActionPreference = "Stop"

# Normalize debug preference
$DebugPreference = If ($Debug) { "Continue" } Else { $DebugPreference }
if ($DebugPreference -eq "Inquire" -or $DebugPreference -eq "Continue") {
    $Debug = $true
}
$Host.PrivateData.DebugForegroundColor = "Gray"
$Host.PrivateData.DebugBackgroundColor = $Host.UI.RawUI.BackgroundColor

# Encoding must be Unicode to support parsing wsl.exe output
[Console]::OutputEncoding = [System.Text.Encoding]::Unicode

Write-Host "Lando Windows Installer" -ForegroundColor Cyan

# Validates whether the system environment is supported
function Confirm-Environment {
    # Bail out if this isn't Windows since PowerShell is cross-platform
    Write-Debug "OS is $env:OS"
    if ($env:OS -ne "Windows_NT") {
        throw "This script is only supported on Windows."
    }

    Write-Debug "PowerShell version: $($PSVersionTable.PSVersion.ToString())"

    # Windows 10 version 1903 (build 18362) or higher is required for WSL2 support
    $minVersion = [Version]::new(10, 0, 18362, 0)
    $osVersion = [Version][Environment]::OSVersion.Version
    Write-Debug "Windows version: $osVersion"

    if ($osVersion -lt $minVersion) {
        throw "Unsupported Windows version. Minimum required version is $minVersion but you have $osVersion."
    }

    # Check for WSL
    $wslVersion = $null
    if (Test-Path "$env:WINDIR\system32\wsl.exe") {
        $wslVersion = & wsl.exe --version | Out-String
        # Check for "WSL version" string on the first line
        if ($wslVersion -notmatch "WSL version") {
            $wslVersion = $null
        }
        else {
            Write-Debug "WSL version details: `n$wslVersion"
            $wslList = & wsl.exe --list --verbose | Out-String
            Write-Debug "WSL Instances:`n$wslList"
        }
    }
    if (-not $wslVersion) {
        Write-Debug "WSL is not installed."
        if (-not $NoWSL) {
            $Script:NoWSL = $true
        }
        if ($WSLOnly) {
            throw "WSL is not installed. Cannot install Lando in WSL."
        }
    }
}

# Selects the appropriate architecture for the current system and warns about issues.
function Select-Architecture {
    $procArch = $(if ($Env:PROCESSOR_ARCHITEW6432) { $Env:PROCESSOR_ARCHITEW6432 } Else { $Env:PROCESSOR_ARCHITECTURE })
    Write-Debug "Processor architecture: $procArch"

    if (-not $Arch) {
        $Arch = "x64"  # Default architecture is x64
        if ($procArch -eq "ARM64") {
            $Arch = "arm64"
        }
    }
    Write-Debug "Selected architecture: $Arch"

    if ($Arch -notmatch "x64|arm64") {
        throw "Unsupported architecture provided. Only x64 and arm64 are supported."
    }

    if ($Arch -eq "x64" -and $procArch -eq "ARM64") {
        $script:issueEncountered = $true
        Write-Warning "You are attempting to install the x64 version of Lando on an arm64 system. This may not work."
    }
    if ($Arch -eq "arm64" -and $procArch -eq "AMD64") {
        $script:issueEncountered = $true
        Write-Warning "You are attempting to install the arm64 version of Lando on an x64 system. This may not work."
    }

    return $Arch
}

# Checks for existing Lando installation and uninstalls it
function Uninstall-LegacyLando {
    Write-Debug "Checking for previous Lando installation..."

    # Catch the object not found error
    try {
        Get-Package -Provider Programs -IncludeWindowsInstaller -Name "Lando version*" -ErrorAction Stop | ForEach-Object {
            $previousInstall = $($_.Name)
            Write-Host "Removing previous installation: $previousInstall..."

            $uninstallString = $_.Meta.Attributes["UninstallString"]
            $arguments = "/Silent /SUPPRESSMSGBOXES"
            if (-not $uninstallString) {
                $script:issueEncountered = $true
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
            $script:issueEncountered = $true
            Write-Warning "An error occurred while trying to uninstall a previous version of Lando. You may need to manually uninstall it."
            Write-Debug $_.Exception
        }
    }
}

# Resolves a version alias to a download URL
#  -Version <version> : Version to resolve
function Resolve-VersionAlias {
    param([string]$Version)

    Write-Debug "Resolving version alias '$Version'..."
    $originalVersion = $Version
    $baseUrl3 = "https://github.com/lando/core/releases/download/"
    $baseUrl4 = "https://github.com/lando/core-next/releases/download/"

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

    # Resolve release aliases to download URLs.
    # Default to slim variant for 3.x unless -Fat is specified.
    switch -Regex ($Version) {
        "^4-(stable|edge)$" {
            Write-Debug "Fetching release alias '$($Version.ToUpper())' from GitHub..."
            $VersionLabel = (Invoke-WebRequest -Uri "https://raw.githubusercontent.com/lando/core-next/main/release-aliases/$($Version.ToUpper())" -UseBasicParsing).Content -replace '\s'
            $variant = if ($Version -match "^3-" -and !$Fat) { "-slim" } else { "" }
            $downloadUrl = "${baseUrl4}${VersionLabel}/lando-win-${arch}-${VersionLabel}${variant}.exe"
        }
        "^3-(stable|edge)$" {
            Write-Debug "Fetching release alias '$($Version.ToUpper())' from GitHub..."
            $VersionLabel = (Invoke-WebRequest -Uri "https://raw.githubusercontent.com/lando/core/main/release-aliases/$($Version.ToUpper())" -UseBasicParsing).Content -replace '\s'
            $variant = if ($Version -match "^3-" -and !$Fat) { "-slim" } else { "" }
            $downloadUrl = "${baseUrl3}${VersionLabel}/lando-win-${arch}-${VersionLabel}${variant}.exe"
        }
        "^4-dev$" {
            $downloadUrl = "https://files.lando.dev/core-next/lando-win-${arch}-${Version}.exe"
        }
        "^3-dev$" {
            $variant = if ($Version -match "^3-" -and !$Fat) { "-slim" } else { "" }
            $downloadUrl = "https://files.lando.dev/core/lando-win-${arch}-${Version}${variant}.exe"
        }
        Default {
            Write-Debug "Version '$Version' is a semantic version"
            if (-not $Version.StartsWith("v")) {
                $Version = "v$Version"
            }
            if ($Version.StartsWith("v4")) {
                $downloadUrl = "${baseUrl4}${Version}/lando-win-${arch}-${Version}.exe"
            }
            else {
                $downloadUrl = "${baseUrl3}${Version}/lando-win-${arch}-${Version}.exe"
            }
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

# Builds the command to execute after a reboot
#  -ScriptPath <path> : Path to the script
#  -BoundParameters <$MyInvocation.BoundParameters> : Pass in the $MyInvocation.BoundParameters for the script
function Get-ResumeCommand {
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$ScriptPath,
        [Parameter(Mandatory, Position = 1)]
        $BoundParameters

    )
    Write-Debug "Building resume command string..."

    # Strongly-typed array to avoid issues with the -join operator in some cases
    [string[]]$arguments = $BoundParameters.GetEnumerator() | ForEach-Object {
        if ($_.Value -is [switch]) {
            if ($_.Value) {
                "-$($_.Key)"
            }
        }
        else {
            "-$($_.Key) `"$($_.Value)`""
        }
    }
    $argString = ($arguments += "-Resume") -join " "
    if ($script:resolvedVersion) {
        $argString += " -Version `"$script:resolvedVersion`""
    }
    $command = ("PowerShell -NoLogo -NoExit -ExecutionPolicy Bypass -Command `"$ScriptPath`" $argString").Trim()

    Write-Debug "Resume command: $command"
    return $command
}

# Downloads and installs Lando
function Install-Lando {
    Write-Debug "Installing Lando in Windows..."
    # Resolve the version alias to a download URL
    try {
        $script:resolvedVersion, $downloadUrl = Resolve-VersionAlias -Version $Version
    }
    catch {
        throw "Could not resolve the provided version alias '$Version'. Error: $_"
    }

    if (-not $downloadUrl) {
        throw "Could not resolve the download URL for version '$Version'."
    }

    $filename = $downloadUrl.Split('/')[-1]

    Write-Host "Downloading Lando CLI..."
    $downloadDest = "$LANDO_APPDATA\$filename"
    Write-Debug "From $downloadUrl to $downloadDest..."
    Write-Progress -Activity "Downloading Lando $script:resolvedVersion" -Status "Preparing..." -PercentComplete 0

    $outputFileStream = [System.IO.FileStream]::new($downloadDest, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write)
    try {
        Add-Type -AssemblyName System.Net.Http
        $httpClient = New-Object System.Net.Http.HttpClient
        $httpCompletionOption = [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead
        $response = $httpClient.GetAsync($downloadUrl, $httpCompletionOption)

        Write-Progress -Activity "Downloading Lando $script:resolvedVersion" -Status "Starting download..." -PercentComplete 0
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

            Write-Progress -Activity "Downloading Lando $script:resolvedVersion" -Status "$(Get-FriendlySize $downloaded)/$fileSizeString (${speedString}/s)" -PercentComplete ($outputFileStream.Position / $fileSize * 100)
        }
        Write-Progress -Activity "Downloading Lando $script:resolvedVersion" -Status "Download complete" -PercentComplete 100
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
    Write-Progress -Activity "Downloading Lando $script:resolvedVersion" -Completed
    Write-Host "Installing Lando..."

    if (-not (Test-Path $Dest)) {
        Write-Debug "Creating destination directory $Dest..."
        New-Item -ItemType Directory -Path $Dest | Out-Null
    }

    $symlinkPath = "$Dest\lando.exe"
    if (Test-Path $symlinkPath) {
        Write-Debug "Removing existing file or link at $symlinkPath..."
        Remove-Item -Path $symlinkPath -Force
    }

    try {
        # Set up mklink command
        $QuotedPath = '"{0}"' -f $symlinkPath
        $QuotedTarget = '"{0}"' -f $downloadDest
        $mklink = @('mklink', $QuotedPath, $QuotedTarget)
        (-not $Debug -and ($mklink += @('>nul', '2>&1'))) | Out-Null

        # Try to create the link
        Write-Debug "> $($mklink -join ' ')"
        $process = Start-Process -FilePath 'cmd.exe' -ArgumentList "/D /C $($mklink -join ' ')" -NoNewWindow -Wait -PassThru

        # Symlink creation will fail if the user doesn't have developer mode enabled in Windows, but hard links work.
        if ($process.ExitCode) {
            Write-Debug "Symlink creation failed with exit code $($process.ExitCode). Trying hard link..."
            $mklink = @('mklink', '/H', $QuotedPath, $QuotedTarget)
            (-not $Debug -and ($mklink += @('>nul', '2>&1'))) | Out-Null

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

    # Add $Dest to system PATH if not already present
    Add-ToPath -NewPath $Dest

    # Clear the cache so that new Lando commands are available
    $landoClearCommand = "$symlinkPath --clear"
    ($Debug -and ($landoClearCommand += " --debug")) | Out-Null
    Write-Debug "Running '$landoClearCommand'"
    try {
        Invoke-Expression $landoClearCommand
    }
    catch {
        $script:issueEncountered = $true
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
    if ($Debug) {
        $setupParams += "--debug"
    }
    if ($Arch) {
        $setupParams += "--arch=$Arch"
    }
    if ($Fat) {
        $setupParams += "--fat"
    }
    if ($NoSetup) {
        $setupParams += "--no-setup"
    }
    if ($Version) {
        $setupParams += "--version=$(if ($script:resolvedVersion) { $script:resolvedVersion } Else { $Version })"
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
            $script:issueEncountered = $true
            Write-Host $_.Exception.Message
            Write-Host "Failed to automatically install Lando into WSL distribution '$wslInstance'. You may need to manually install Lando in this distribution." -ForegroundColor Red
            Write-Debug $_.Exception
        }

        # Check the return code from the setup script
        if ($LASTEXITCODE -ne 0) {
            $script:issueEncountered = $true
            Write-Host "Failed to automatically install Lando into WSL distribution '$wslInstance'. You may need to manually install Lando in this distribution." -ForegroundColor Red
        }

        Set-Location $currentLoc
        Write-Host ""
    }
}

# Runs the "lando setup" command if Lando is at least version 3.21.0
function Invoke-LandoSetup {
    Write-Debug "Running 'lando setup'..."
    if ($script:resolvedVersion -lt "v3.21.0") {
        Write-Debug "Skipping 'lando setup' because version $script:resolvedVersion is less than 3.21.0."
        return
    }

    $landoSetupCommand = "$Dest\lando.exe setup -y"
    ($Debug -and ($landoSetupCommand += " --debug")) | Out-Null

    Write-Debug "Running '$landoSetupCommand'"
    try {
        Invoke-Expression $landoSetupCommand
        if ($LASTEXITCODE -ne 0) {
            throw "'lando setup' failed with exit code $LASTEXITCODE."
        }
    }
    catch {
        $script:issueEncountered = $true
        Write-Host "Failed to run 'lando setup'. You may need to manually run this command to complete the setup. `nError: $_" -ForegroundColor Red
    }
}

# reset to a git derived dev version of above is not set
if ([string]::IsNullOrEmpty($SCRIPT_VERSION)) {
    $SCRIPT_VERSION = Invoke-Expression "git describe --tags --always --abbrev=1"
}

Write-Debug "Running script $SCRIPT_VERSION with:"
Write-Debug "  -Arch: $Arch"
Write-Debug "  -Debug: $Debug"
Write-Debug "  -Dest: $Dest"
Write-Debug "  -Fat: $Fat"
Write-Debug "  -NoSetup: $NoSetup"
Write-Debug "  -NoWSL: $NoWSL"
Write-Debug "  -Resume: $Resume"
Write-Debug "  -Version: $Version"
Write-Debug "  -WSLOnly: $WSLOnly"
Write-Debug "  -Help: $Help"

# It's okay to ask for help
if ($Help) {
    Get-Help $MyInvocation.MyCommand.Path -Detailed
    return
}

if ($Resume) {
    Write-Host "Lando installation was previously interrupted by a Windows restart. Resuming..."
}

# Validate the system environment
Confirm-Environment

# Select the appropriate architecture
$Arch = Select-Architecture

# Set up our working directory
if (-not (Test-Path "$LANDO_APPDATA" -ErrorAction SilentlyContinue)) {
    Write-Debug "Creating destination directory $LANDO_APPDATA..."
    New-Item -ItemType Directory -Path $LANDO_APPDATA -Force | Out-Null
}

# Add a RunOnce registry key so Windows will automatically resume the script when interrupted by a reboot
$runOnceKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
$runOnceName = "LandoSetup"
if (-not $WSLOnly -and -not $Resume) {
    # When the script is invoked from a piped web request, the script path is not available.
    # Detect this and save the script to a known location so it can be resumed after a reboot.
    $localScriptPath = $MyInvocation.MyCommand.Path
    if ($null -eq $localScriptPath) {
        $localScriptPath = "$LANDO_APPDATA\setup-lando.ps1"
        Write-Debug "Saving script to $localScriptPath..."
        $scriptContent = (Invoke-WebRequest -Uri "$LANDO_SETUP_PS1_URL" -UseBasicParsing).Content
        Set-Content -Path $localScriptPath -Value $scriptContent
    }

    # Install Lando in Windows
    if (-not $WSLOnly) {
        Uninstall-LegacyLando

        Install-Lando

        if (-not $NoSetup) {
            # Dependency installation may trigger a reboot so make sure we can resume after
            $resumeCommand = Get-ResumeCommand $localScriptPath $MyInvocation.BoundParameters

            Write-Debug "Adding RunOnce registry key to re-run the script after a reboot..."
            if (-not (Test-Path $runOnceKey)) {
                New-Item -Path $runOnceKey -Force | Out-Null
            }
            New-ItemProperty -Path $runOnceKey -Name $runOnceName -Value $resumeCommand -PropertyType String -Force | Out-Null

            # Let Lando take over for dependecy installation. A system reboot may happen here.
            Invoke-LandoSetup

            # If we get here, a reboot didn't happen, so we won't need to resume later.
            Write-Debug "Removing RunOnce registry key..."
            Remove-ItemProperty -Path $runOnceKey -Name $runOnceName -ErrorAction SilentlyContinue
        }
    }
}

# Lando setup may have been interrupted by the reboot. Run it again.
if ($Resume -and -not $NoSetup -and -not $WSLOnly) {
    Invoke-LandoSetup
}

# Install in WSL after lando setup runs because Docker Desktop WSL
# instances may not be available until after reboot.
if (-not $NoWSL) {
    Install-LandoInWSL
}

if ($issueEncountered) {
    Write-Warning "Lando was installed but issues were encountered during installation. Please check the output above for details."
}

Write-Host "`nLando setup complete!`n" -ForegroundColor Green
