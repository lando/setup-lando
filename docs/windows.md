---
title: Windows
description: Install Lando on Windows using PowerShell script
---

# Windows

Installing Lando using the PowerShell script method will set up Lando along with Docker Desktop in a configuration optimized for Windows and WSL2.

This ensures the `lando` command is available on your PowerShell, Command Prompt, or other Windows shell, and also on the default user's shells within your WSL2 Linux instances.

The Windows/WSL2 quickstart is to paste the below into a PowerShell terminal and execute it.

```powershell
iex (irm 'https://get.lando.dev/setup-lando.ps1' -UseB)
```

If you are looking to customize your install then [advanced usage](#advanced) if for you.

## Advanced

The PowerShell installation script supports several options to customize the installation. To use these options, you can download and execute the script locally:

```powershell
# download the script by running the following command in PowerShell
Invoke-WebRequest -Uri 'https://get.lando.dev/setup-lando.ps1' -OutFile 'setup-lando.ps1'

# make local scripts executable
Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope CurrentUser

# show usage info
.\setup-lando.ps1 -Help

# an example advanced invocation
# note you will need to change these values to ones that make sense for you
# consult the usage and notes below for more into
.\setup-lando.ps1 -Dest 'C:\Users\aaron\bin' -Fat -Version 3.21.2 -Debug
```

### Usage

```powershell
.\setup-lando.ps1 [-Arch <x64|arm64>] [-Debug] [-Dest <path>] [-Fat] [-NoSetup] [-NoWSL] [-Resume] [-Version <version>] [-WSLOnly] [-Help]
```

* `-Arch <x64|arm64>`: Specifies the architecture to install (x64 or arm64). Defaults to the system architecture.
* `-Debug`: Enables debug output.
* `-Dest <path>`: Specifies the destination path for installation. Defaults to "$env:USERPROFILE\.lando\bin".
* `-Fat`: Download the fat v3 Lando binary that comes with official plugins built-in.
* `-NoSetup`: Skips running Lando's built-in setup script.
* `-NoWSL`: Skips the Windows Subsystem for Linux (WSL) setup.
* `-Resume`: Resumes a previous installation after a reboot.
* `-Version <version>`: Specifies the version of Lando to install. Defaults to "stable".
* `-WSLOnly`: Only installs Lando in WSL.
* `-Help`: Displays the help message.

Some notes on advanced usage:

* If you want to customize the behavior of `lando setup` use `-NoSetup` and then manually invoke [`lando setup`](https://docs.lando.dev/cli/setup.html) after install is complete.

## Performance Note

While using Docker containers through Lando on Windows, you may experience slower performance due to the process of accessing and translating files between the native Windows file system and the Linux file system used by Docker. This is not a limitation of Lando or Docker itself, but rather of the file system transition. For most projects, this setup still performs adequately and integrates seamlessly with Windows applications and IDEs. More advanced users, comfortable with Linux, may prefer to store their project files within the Linux environment in WSL2 to optimize performance.

## Installation in a WSL2 Linux Environment

If you have already set up a Linux environment within WSL2, the PowerShell script will automatically install Lando within this environment. For those who prefer working exclusively within WSL2, no additional Windows-based installation is necessary. You can install Lando directly within the Linux environment by following the [Linux installation instructions](./linux.md). Note that having Docker Desktop for Windows makes Docker available across all your WSL2 environments, eliminating the need to install Docker Engine separately.
