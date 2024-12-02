<#
.SYNOPSIS
Lando Windows Installer Script.

.DESCRIPTION
This script is used to download and install Lando on Windows. It will also run lando setup on >3.21 <4 but this can
be disabled with -NoSetup.

Environment Variables:
NONINTERACTIVE   Installs without prompting for user input
CI               Installs in CI mode (e.g. does not prompt for user input)

.EXAMPLE
.\setup-lando.ps1 -Arch x64 -Version edge
Installs the Lando edge version binary with x64 architecture.

#>

# Script parameters must be declared before any other statements
param(
  # Installs for this architecture (x64 or arm64). Defaults to the system architecture.
  [ValidateSet("x64", "arm64", "auto")]
  [string]$Arch = "auto",
  # Shows debug messages.
  [switch]$Debug = $env:LANDO_INSTALLER_DEBUG -or $env:RUNNER_DEBUG -or $false,
  # Installs in this directory. Defaults to "$env:USERPROFILE\.lando\bin".
  [ValidateNotNullOrEmpty()]
  [string]$Dest = "$env:USERPROFILE\.lando\bin",
  # Installs the fat binary. 3.21+ <4 only, NOT RECOMMENDED!
  [switch]$Fat = $env:LANDO_INSTALLER_FAT -or $false,
  # Installs without running lando setup. 3.21+ <4 only.
  [switch]$NoSetup = $env:LANDO_INSTALLER_SETUP -eq 0 -or $false,
  # Installs this version. Defaults to "stable".
  [ValidateNotNullOrEmpty()]
  [string]$Version = "stable",
  # Skips all interactive prompts.
  [switch]$Yes = $env:NONINTERACTIVE -or $env:CI,
  # Displays this help message.
  [switch]$Help
)

Set-StrictMode -Version 1

# Stop execution of this script if any cmdlet fails.
# We'll still need to check exit codes on any exe we run.
$ErrorActionPreference = "Stop"

# Normalize debug preference
$DebugPreference = If ($Debug) { "Continue" } Else { $DebugPreference }
if ($DebugPreference -eq "Inquire" -or $DebugPreference -eq "Continue") {
  $Debug = $true
}

# Normalize UX
$Host.PrivateData.DebugForegroundColor = "DarkGray"
$Host.PrivateData.DebugBackgroundColor = $Host.UI.RawUI.BackgroundColor

function Confirm-EnvIsSet {
  param(
		[Parameter(Mandatory)]
		[string]$Var
  )
	$value = [System.Environment]::GetEnvironmentVariable($Var);
	return $value -and $value.Trim() -ne ""
}

function Get-SystemArchitecture {
	# Get from env
	$arch = if ($env:PROCESSOR_ARCHITEW6432) {$env:PROCESSOR_ARCHITEW6432} else {$env:PROCESSOR_ARCHITECTURE}

	# Normalize for our purposes
	if ($arch -eq "AMD64") {
		return "x64"
	} elseif ($arch === "ARM64") {
		return "arm64"
	} else {
		return $arch
	}
}

# Config of sorts
$SCRIPT_VERSION = $null

$LANDO_DEFAULT_MV = "3"
$LANDO_BINDIR = "$env:USERPROFILE\.lando\bin"
$LANDO_DATADIR = "$env:LOCALAPPDATA\Lando"
$LANDO_TMPDIR = "$env:TEMP"
$SYMLINKER = "$env:USERPROFILE\.lando\bin\lando.cmd"

$CI = Confirm-EnvIsSet -Var "CI"
$NONINTERACTIVE = $CI -or ![Environment]::UserInteractive -or $Yes
$SYSTEM_ARCHITECTURE = Get-SystemArchitecture
$USER = [System.Environment]::UserName

$issueEncountered = $false
$resolvedVersion = $null

# Adds a path to the system PATH if not already present.
#  -NewPath <path> : Path to add
function Add-ToPath {
  param(
		[Parameter(Mandatory, Position = 0)]
		[string]$NewPath
  )
  Write-Debug "Adding $NewPath to system PATH..."
  $regPath = "registry::HKEY_CURRENT_USER\Environment"
  $currDirs = (Get-Item -LiteralPath $regPath).GetValue("Path", "", "DoNotExpandEnvironmentNames") -split ";" -ne ""

  if ($NewPath -in $currDirs) {
    Write-Debug "'$NewPath' is already present in the user-level Path environment variable."
    return
  }

  $newValue = ($currDirs + $NewPath) -join ";"

  # Update the registry to make the change permanent.
  Set-ItemProperty -Type ExpandString -LiteralPath $regPath Path $newValue

  # Broadcast WM_SETTINGCHANGE to get the Windows shell to reload the
  # updated environment, via a dummy [Environment]::SetEnvironmentVariable() operation.
  $dummyName = [guid]::NewGuid().ToString()
  [Environment]::SetEnvironmentVariable($dummyName, "foo", "User")
  [Environment]::SetEnvironmentVariable($dummyName, [NullString]::value, "User")

  # Also update the current session's `$env:Path` definition.
  $env:Path = ($env:Path -replace ";$") + ";" + $NewPath
  $env:Path = $NewPath + ";" + $env:Path
  Write-Debug "'$NewPath' added to the user-level Path."
}

function Add-WrapperScript {
  param(
		[Parameter(Mandatory)]
		[string]$Location,
    [string]$Symlink = $script:SYMLINKER
  )

  $wrapper = @"
@echo off
setlocal enableextensions
set LANDO_ENTRYPOINT_NAME=lando
set LANDO_WRAPPER_SCRIPT=1
"$Location" %*
"@

  # Use .NET to write UTF-8 without BOM
  $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
  [System.IO.File]::WriteAllLines($Symlink, $wrapper, $Utf8NoBomEncoding)
  Write-Debug "Wrote wrapper script to ${Symlink}:"
  $wrapper -split "`n" | ForEach-Object { Write-Debug $_ }
}

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

  Write-Debug "Processor architecture: $SYSTEM_ARCHITECTURE"
  Write-Debug "Selected architecture: $Arch"

  if ($Arch -notmatch "x64|arm64") {
    throw "Unsupported architecture provided. Only x64 and arm64 are supported."
  }

  if ($Arch -eq "x64" -and $SYSTEM_ARCHITECTURE -eq "arm64") {
    $script:issueEncountered = $true
    Write-Warning "You are attempting to install the x64 version of Lando on an arm64 system. This may not work."
  }
  if ($Arch -eq "arm64" -and $SYSTEM_ARCHITECTURE -eq "x64") {
    $script:issueEncountered = $true
    Write-Warning "You are attempting to install the arm64 version of Lando on an x64 system. This may not work."
  }

  # Set up our working directories
  if (-not (Test-Path "$LANDO_DATADIR" -ErrorAction SilentlyContinue)) {
    Write-Debug "Creating destination directory $LANDO_DATADIR..."
    New-Item -ItemType Directory -Path $LANDO_DATADIR -Force | Out-Null
  }
  if (-not (Test-Path "$LANDO_BINDIR" -ErrorAction SilentlyContinue)) {
    Write-Debug "Creating destination directory $LANDO_BINDIR..."
    New-Item -ItemType Directory -Path $LANDO_BINDIR -Force | Out-Null
  }
}

function Confirm-FattyOrSetupy {
  param([string]$Version = "$script:Version")
  $Info = Get-SemanticVersionInfo -Version "$Version"
  return [Version]$Info.Version -lt [Version]"3.24.0" -and [Version]$Info.Version -ge [Version]"3.21.0";
}

# Converts a byte size to a human-readable string
#  -Bytes <bytes> : Bytes to convert
function Get-FriendlySize {
  param($Bytes)
  $sizes = "Bytes,KB,MB,GB,TB,PB,EB,ZB" -split ","
  for ($i = 0; ($Bytes -ge 1kb) -and
  ($i -lt $sizes.Count); $i++) { $Bytes /= 1kb }
  $N = 2; if ($i -eq 0) { $N = 0 }
  "{0:N$($N)}{1}" -f $Bytes, $sizes[$i]
}

# Downloads and installs Lando
function Get-Lando {
  param(
    [Parameter(Mandatory)]
		[string]$Url,
		[string]$Dest = "$script:LANDO_TMPDIR"
  )

  # Ensure dest exist
  if (-not (Test-Path "$Dest" -ErrorAction SilentlyContinue)) {
    Write-Debug "Creating destination directory $Dest..."
    New-Item -ItemType Directory -Path $Dest -Force | Out-Null
  }

  # Add the file part
  $Dest = "$Dest\$(Get-Random).exe"
  Write-Host "Fetching Lando $script:Version from $Url to $Dest..."

  # Save current colors
  $Host.PrivateData.ProgressForegroundColor = "White";
  $Host.PrivateData.ProgressBackgroundColor = "DarkMagenta";

  # If file url then just move it and return
  if ($Url.StartsWith("file://")) {
    $Source = $Url.TrimStart("file://");
    Copy-Item -Path "$Source" -Destination "$Dest"> -Force
    Write-Debug("Moved local lando from $Source to $Dest");
    return $Dest;
  }

  Write-Progress -Activity "Downloading Lando $script:Version" -Status "Preparing..." -PercentComplete 0

  $outputFileStream = [System.IO.FileStream]::new($Dest, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write)
  try {
    Add-Type -AssemblyName System.Net.Http
    $httpClient = New-Object System.Net.Http.HttpClient
    $httpCompletionOption = [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead
    $response = $httpClient.GetAsync($Url, $httpCompletionOption)

    Write-Progress -Activity "Downloading Lando $script:Version" -Status "Starting download..." -PercentComplete 0
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

      Write-Progress -Activity "Downloading Lando $script:Version" -Status "$(Get-FriendlySize $downloaded)/$fileSizeString (${speedString}/s)" -PercentComplete ($outputFileStream.Position / $fileSize * 100)
    }
    Write-Progress -Activity "Downloading Lando $script:Version" -Status "Download complete" -PercentComplete 100
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

  return $Dest;
}

# Runs the "lando setup" command if Lando is at least version 3.21.0
function Invoke-LandoSetup {
  param(
		[string]$LandoBin = 'lando.cmd'
  )

  # Start
  $landoSetupCommand = "$LandoBin setup"
  # Add -y if needed
  if ($NONINTERACTIVE) {$landoSetupCommand += " -y"}
  # Add debug if needed
  if ($Debug) {$landoSetupCommand += " --debug"}

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

function Get-SemanticVersionInfo {
  param([string]$Version = "$script:Version")

  if ($Version.StartsWith("v")) {
    $Version = $Version.TrimStart("v");
  }

  # Regex to parse semantic version
  $regex = "(\d+)\.(\d+)\.(\d+)(?:-([\w\d\-\.]+))?(?:\+([\w\d\-\.]+))?$"

  if ($Version -match $regex) {
    $major = [int]$Matches[1]
    $minor = [int]$Matches[2]
    $patch = [int]$Matches[3]

    return @{
      Major = $major
      Minor = $minor
      Patch = $patch
      PreRelease = $Matches[4]
      Build = $Matches[5]
      Version = "${major}.${minor}.${patch}"
      Raw = "$Version"
    }
  } else {
    throw "Invalid semantic version: $Version"
  }
}

function Resolve-Input {
	param (
		[Parameter(Mandatory)]
		[string]$InputVar,
		[Parameter(Mandatory)]
		[string]$DefaultValue,
		[string[]]$EnvVars=@()
	)

	# if the user has modified the input value from the default then just return inputvar
	if ($InputVar -ne $DefaultValue) {
		return $InputVar;
	}

	# otherwise lets try to set it with an envvar if possible
	foreach ($var in $EnvVars) {
		Write-Debug "$var $(Confirm-EnvIsSet -Var "$var")"
		if (Confirm-EnvIsSet -Var "$var") {
			return [System.Environment]::GetEnvironmentVariable($var);
		}
	}

	return $DefaultValue
}

function Resolve-Version {
  param([string]$Version = "$script:Version")

  # If version is a path that exists then return `lando version` output
  if (Test-Path ($Version = Resolve-VersionPath -Version "$Version")) {
    try {
      $result = Invoke-Expression "$Version version"
      return $result.Trim();
    }
    catch {
      throw "$Version does not appear to be a valid Lando or there was an error getting version information from it!"
    }
  }

  # resolve any version aliases as best as possible
  return Resolve-VersionAlias -Version "$Version"
}

function Resolve-VersionAlias {
  param([string]$Version = "$script:Version")

  $aliasMap = @{
    "3"      = "3-stable";
    "4"      = "4-stable";
    "stable" = "$LANDO_DEFAULT_MV-stable";
    "edge"   = "$LANDO_DEFAULT_MV-edge";
    "dev"    = "$LANDO_DEFAULT_MV-dev";
    "latest" = "$LANDO_DEFAULT_MV-dev";
  }

  if ($aliasMap.ContainsKey($Version)) {
    $Version = $($aliasMap[$Version])
  }

  switch -Regex ($Version) {
    "^4-(stable|edge)$" {
      Write-Debug "Fetching release alias '$($Version.ToUpper())' from GitHub..."
      $Version = (Invoke-WebRequest -Uri "https://raw.githubusercontent.com/lando/core-next/main/release-aliases/$($Version.ToUpper())" -UseBasicParsing).Content -replace '\s'
    }
    "^3-(stable|edge)$" {
      Write-Debug "Fetching release alias '$($Version.ToUpper())' from GitHub..."
      $Version = (Invoke-WebRequest -Uri "https://raw.githubusercontent.com/lando/core/main/release-aliases/$($Version.ToUpper())" -UseBasicParsing).Content -replace '\s'
    }
    "^4-(dev|latest)$" {
      $Version = "4-dev"
    }
    "^3-(dev|latest)$" {
      $Version = "3-dev"
    }
    Default {
      if (-not $Version.StartsWith("v")) {
        $Version = "v$Version"
      }
    }
  }

  return $Version
}

function Resolve-VersionPath {
  param([string]$Version = "$script:Version")

  if ([System.IO.Path]::IsPathRooted($Version)) {
    return $Version
  } else {
    try {
      return Resolve-Path $Version | ForEach-Object { $_.Path }
    } catch {
      return $Version
    }
  }
}

# Resolves a version alias to a download URL
function Resolve-VersionUrl {
  param(
    [string]$Arch = $script:Arch,
    [string]$Version = "$script:Version",
    [switch]$Fat = $false
  )

  # If version is a path that exists then return `lando version` output
  if (Test-Path ($Version = Resolve-VersionPath -Version "$Version")) {
    try {
      return "file://$Version"
    }
    catch {
      throw "$Version does not appear to be a valid Lando or there was an error getting version information from it!"
    }
  }

  # Resolve alias first
  $Version = Resolve-VersionAlias -Version "$Version"

  # Resolve versions to download URLs.
  # Default to slim variant for 3.x unless -Fat is specified.
  switch -Regex ($Version) {
    "^4-dev$" {
      return "https://files.lando.dev/core-next/lando-win-${Arch}-dev.exe"
    }
    "^3-dev$" {
      return "https://files.lando.dev/core/lando-win-${Arch}-dev.exe"
    }
    "^v4\." {
      return  "https://github.com/lando/core-next/releases/download/${Version}/lando-win-${Arch}-${Version}.exe"
    }
    "^v3\." {
      if ((Confirm-FattyOrSetupy -Version "$Version") -and -not $Fat) {
        return "https://github.com/lando/core/releases/download/${Version}/lando-win-${Arch}-${Version}-slim.exe"
      }
      return "https://github.com/lando/core/releases/download/${Version}/lando-win-${Arch}-${Version}.exe"
    }
    Default {
      throw "Could not resolve $Version to a downloadable URL!"
    }
  }
}

# Checks for existing Lando installation and uninstalls it
function Uninstall-LegacyLando {
  Write-Debug "Checking for previous Lando installation..."

  # Remove core plugin to assert dominance
  if (Test-Path "$env:USERPROFILE\.lando\plugins\@lando\core" -ErrorAction SilentlyContinue) {
    Write-Debug "Removing detectecd core plugin from $env:USERPROFILE\.lando\plugins\@lando..."
    Remove-Item -Path "$env:USERPROFILE\.lando\plugins\@lando\core" -Recurse -Force
  }

  if (Test-Path "$LANDO_BINDIR\lando.exe" -ErrorAction SilentlyContinue) {
    Write-Debug "Removing detectecd lando.exe from $LANDO_BINDIR..."
    Remove-Item -Path "$LANDO_BINDIR\lando.exe" -Recurse -Force
  }

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

function Wait-ForUser {
  $key = [Console]::ReadKey($true)

  if ($key.Key -eq "Enter") {
    Write-Debug "User confirmed. Continuing..."
  } else {
    Write-Debug "User cancelled with '$($key.Key)'. Exiting..."
    exit 0
  }
}

# reset to a git derived dev version of above is not set
if ([string]::IsNullOrEmpty($SCRIPT_VERSION)) {
  $SCRIPT_VERSION = Invoke-Expression "git describe --tags --always --abbrev=1"
}

Write-Host "Lando Windows Installer" -ForegroundColor DarkMagenta

# It's okay to ask for help
if ($Help) {
  Get-Help $MyInvocation.MyCommand.Path -Detailed
  return
}

# Resolve stringy inputs
$Arch = Resolve-Input -InputVar $Arch -DefaultValue "auto" -EnvVars @("LANDO_INSTALLER_ARCH")
$Dest = Resolve-Input -InputVar $Dest -DefaultValue "$LANDO_BINDIR" -EnvVars @("LANDO_INSTALLER_DEST")
$Version = Resolve-Input -InputVar $Version -DefaultValue "stable" -EnvVars @("LANDO_VERSION", "LANDO_INSTALLER_VERSION")

# Resolve arch if auto
if ($Arch -eq "auto") {
	$Arch = $SYSTEM_ARCHITECTURE;
}

Write-Debug "Running script with resolved inputs:"
Write-Debug "  -Arch: $Arch"
Write-Debug "  -Debug: $Debug"
Write-Debug "  -Dest: $Dest"
Write-Debug "  -Fat: $Fat"
Write-Debug "  -NoSetup: $NoSetup"
Write-Debug "  -Version: $Version"
Write-Debug "  -Help: $Help"
Write-Debug "and config:"
Write-Debug "  CI: $CI"
Write-Debug "  NONINTERACTIVE: $NONINTERACTIVE"
Write-Debug "  SCRIPT_VERSION: $SCRIPT_VERSION"
Write-Debug "  SYSTEM_ARCHITECTURE: $SYSTEM_ARCHITECTURE"
Write-Debug "  USER: $USER"

# Validate the system environment
Confirm-Environment

# Save original version
$originalVersion = $Version;

# Resolve version
$Version = Resolve-Version -Version "$originalVersion"
# Dev version boolean
$isDevVersion = $Version.EndsWith("-dev");
# Resolve URL
$urlFat = @{
  Fat = $Fat
}
$url = Resolve-VersionUrl -Version "$originalVersion" @urlFat

# Debug version resolution
Write-Debug "Version resolution results:"
Write-Debug "  Version: $Version"
Write-Debug "  Url: $url"
Write-Debug "  isDevVersion: $isDevVersion"

# Summarize what the script is about to do
if (-not $NONINTERACTIVE) {
  Write-Host "This script is about to:"
  Write-Host ""
  Write-Host "- " -NoNewline
  Write-Host "Download " -NoNewline -ForegroundColor DarkMagenta
  Write-Host "lando $Version to $Dest"

  if ((Confirm-FattyOrSetupy -Version "$Version") -and -not $NoSetup) {
    Write-Host "- " -NoNewline
    Write-Host "Run " -NoNewline -ForegroundColor DarkBlue
    Write-Host "lando setup"
  }

  Write-Host "- " -NoNewline
  Write-Host "Run " -NoNewline -ForegroundColor DarkBlue
  Write-Host "lando shellenv --add"

  Write-Host "- " -NoNewline
  Write-Host "Add " -NoNewline -ForegroundColor DarkGreen
  Write-Host "$Dest to PATH"
  Write-Host ""

  Write-Host "Press RETURN/ENTER to continue or any other key to abort:"
  Wait-ForUser
}

# Download lando to tmpdir
$LANDO_TMPFILE = Get-Lando "$Url"
# Barebones it works test
$Version = Invoke-Expression "$LANDO_TMPFILE version"
# Remove older landos
Uninstall-LegacyLando
# Define lando
$LANDO = "$Dest\lando.exe"

# if Dest is default then put in data dir and link to that
If ($Dest -eq $LANDO_BINDIR) {
  $HIDDEN_LANDO = "$LANDO_DATADIR\$Version\lando.exe"
  New-Item -ItemType Directory -Path "$LANDO_DATADIR\$Version" -Force | Out-Null
  Move-Item -Path "$LANDO_TMPFILE" -Destination "$HIDDEN_LANDO" -Force
  Add-WrapperScript -Location "$HIDDEN_LANDO"

# Otherwise just move directly to dest and link
} else {
  Move-Item -Path "$LANDO_TMPFILE" -Destination "$LANDO" -Force
  Add-WrapperScript -Location "$LANDO"
}

Write-Host "Moved Lando $Version to $LANDO"

# Do some special stuff on v3
if ($Version.StartsWith("v3.")) {
  $null = Invoke-Expression "$SYMLINKER --clear" | ForEach-Object { Write-Debug $_ }
}

# Add $Dest and $LANDO_BIN to system PATH if not already present
Add-ToPath -NewPath $Dest
Add-ToPath -NewPath "$LANDO_BINDIR"

# Lando setup may have been interrupted by the reboot. Run it again.
# @TODO: pass in lando?
if ((Confirm-FattyOrSetupy -Version "$Version") -and -not $NoSetup) {
  Invoke-LandoSetup -Lando "$Symlinker"
}

# Run lando shell env
Invoke-Expression "$SYMLINKER shellenv --add"

if ($issueEncountered) {
  Write-Warning "Lando was installed but issues were encountered during installation. Please check the output above for details."
}

Write-Host ""
Write-Host "Success! " -NoNewline -ForegroundColor DarkGreen
Write-Host "lando " -NoNewline -ForegroundColor DarkMagenta
Write-Host "is installed!"
