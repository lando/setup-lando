---
title: Windows
description: Install Lando on Windows
---

# Windows

Before you start, make sure you've [installed Docker Desktop for Windows](https://docs.docker.com/desktop/install/windows-install/).

## Installer (recommended)

This will install the `lando` command to be available on your "native" Powershell, Command Prompt, or other shell.

::: warning YOU MUST HAVE WSL2 ENABLED
Make sure that the [WSL2 feature is enabled](https://learn.microsoft.com/en-us/windows/wsl/install) or the Lando installer will fail.

If you want to use the older [Hyper-V](https://learn.microsoft.com/en-us/virtualization/hyper-v-on-windows/quick-start/enable-hyper-v) compatible version of Lando use version 3.6.5 or below however it is recommended to update to the new WSL based backend.
:::

1.  Make sure you are using **at least** Windows 10 Home or Professional version 21H2 or higher
2.  Download the latest Windows `.exe` installer from [GitHub](https://github.com/lando/lando/releases)
3.  Double-click on `lando.exe`
4.  Go through the setup workflow
5.  Approve various UAC prompts during install

## Manual Installation in a WSL2 Linux Environment

Docker Desktop for Windows (which Lando uses as the easiest way to install Docker on your Windows machine) by default runs Docker within a thin WSL2 environment; hence why WSL2 is required to install Lando, even though you run the `lando` command from your "native" shell (Powershell/Command Prompt/etc.).

HOWEVER, if you have already set up a Linux environment within WSL2, you may want to run Lando from within that environment. To do so, follow the [Linux installation instructions](./linux.md).

Note that Lando will still require Docker to be available within the WSL2 environment. Having Docker Desktop for Windows should make Docker available within all your WSL2 environments; alternatively you can [install Docker Engine for Linux](https://docs.docker.com/engine/install/).
