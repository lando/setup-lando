---
title: Windows
description: Install Lando on Windows using PowerShell script
---

# Windows

Installing Lando using the PowerShell script method will set up Lando along with Docker Desktop in a configuration optimized for Windows and WSL2. This ensures the lando command is available on your PowerShell, Command Prompt, or other Windows shell, and also to the default user's shells within your WSL2 instances.

## Quick Start

1. Open PowerShell.
2. To install, run the setup script with the following command:
```powershell
iex (irm 'https://get.lando.dev/setup-lando.ps1' -UseB)
```

## Advanced Installation

The PowerShell installation script supports several options to customize the installation. To use these options, you can download and execute the script locally:

```powershell
# Download the script by running the following command in PowerShell:
Invoke-WebRequest -Uri 'https://get.lando.dev/setup-lando.ps1' -OutFile 'setup-lando.ps1'

# Make local scripts executable:
Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope CurrentUser

# Show usage info:
.\setup-lando.ps1 -help

# An example advanced invocation:
.\setup-lando.ps1 -dest 'C:\Users\aaron\bin' -fat -version 3.22.1 -debug
```

### Usage

```powershell
.\setup-lando.ps1 [-arch <x64|arm64>] [-debug] [-dest <path>] [-fat] [-no_setup] [-no_wsl] [-resume] [-version <version>] [-wsl_only] [-help]
```
- `-arch <x64|arm64>`: Specifies the architecture to install (x64 or arm64). Defaults to the system architecture.
- `-debug`: Enables debug output.
- `-dest <path>`: Specifies the destination path for installation. Defaults to "$env:USERPROFILE\.lando\bin".
- `-fat`: Download the fat v3 Lando binary that comes with official plugins built-in.
- `-no_setup`: Skips running Lando's built-in setup script.
- `-no_wsl`: Skips the Windows Subsystem for Linux (WSL) setup.
- `-resume`: Resumes a previous installation after a reboot.
- `-version <version>`: Specifies the version of Lando to install. Defaults to "stable".
- `-wsl_only`: Only installs Lando in WSL.
- `-help`: Displays the help message.

Some notes on advanced usage:

* If you want to customize the behavior of `lando setup` use `-no_setup` and then manually invoke [`lando setup`](https://docs.lando.dev/cli/setup.html) after install is complete.

## Performance Note

While using Docker containers through Lando on Windows, you may experience slower performance due to the process of accessing and translating files between the native Windows and the Linux file system used by Docker. This is not a limitation of Lando or Docker itself, but rather of the file system transition. For most projects, this setup still performs adequately and integrates seamlessly with Windows applications and IDEs. More advanced users, comfortable with Linux, may prefer to store their project files within the Linux environment in WSL2 to optimize performance.
