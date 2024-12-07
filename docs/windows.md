---
title: Windows
description: Install Lando on Windows using PowerShell script
---

# Windows

The Windows quickstart is to paste the below into a PowerShell terminal and execute it.

```powershell
iex (irm 'https://get.lando.dev/setup-lando.ps1' -UseB)
```

::: tip Installs in Windows only and not in WSL
To install in WSL check out the install docs [over here](https://docs.lando.dev/install/wsl.html).
:::

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
```

### Usage

```powershell
NAME
    setup-lando.ps1

SYNOPSIS
    Lando Windows Installer Script.

SYNTAX
    setup-lando.ps1 [[-Arch] <String>] [-Debug] [[-Dest] <String>] [-Fat] [-NoSetup] [[-Version] <String>] [-Yes] [-Help] [<CommonParameters>]

DESCRIPTION
    This script is used to download and install Lando on Windows. It will also run lando setup on <3.24 but this can
    be disabled with -NoSetup.

    Environment Variables:
    NONINTERACTIVE   Installs without prompting for user input
    CI               Installs in CI mode (e.g. does not prompt for user input)

PARAMETERS
    -Arch <String>
        Installs for this architecture (x64 or arm64). Defaults to the system architecture.
    -Debug [<SwitchParameter>]
        Shows debug messages.
    -Dest <String>
        Installs in this directory. Defaults to "$env:USERPROFILE\.lando\bin".
    -Fat [<SwitchParameter>]
        Installs the fat binary. <3.24 only, NOT RECOMMENDED!
    -NoSetup [<SwitchParameter>]
        Installs without running lando setup. <3.24 only.
    -Version <String>
        Installs this version. Defaults to "stable".
    -Yes [<SwitchParameter>]
        Skips all interactive prompts.
    -Help [<SwitchParameter>]
        Displays this help message.
```

Some notes on advanced usage:

* If you want to customize the behavior of `lando setup` use `-NoSetup` and then manually invoke [`lando setup`](https://docs.lando.dev/cli/setup.html) after install is complete.
* If you run in a non-tty environment eg in `CI` then `--yes` will be assumed
* If you use `--yes` it is equivalent to setting `NONINTERACTIVE=1`

#### Environment Variables

If you do not wish to download the script you can set options with environment variables and `Invoke-WebRequest` the script.

```powershell
LANDO_VERSION=stable
LANDO_INSTALLER_ARCH=auto
LANDO_INSTALLER_DEBUG=0
LANDO_INSTALLER_DEST="$env:USERPROFILE\.lando\bin"
LANDO_INSTALLER_FAT=0
LANDO_INSTALLER_SETUP=auto
```

#### Examples

These are equivalent commands and meant to demostrate environment variable usage vs direct invocation.

```powershell
# use envvars
$env:LANDO_VERSION="3.23.11"; $env:LANDO_INSTALLER_DEBUG=1; iex (irm 'https://get.lando.dev/setup-lando.ps1' -UseB)

# invoke directly
setup-lando.ps1 -Version "3.23.11" -Debug
```
