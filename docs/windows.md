---
title: Windows
description: Install Lando on Windows
---

# Windows

## Installer (recommended)

This will install the `lando` command to be available on your "native" Powershell, Command Prompt, or other shell. Docker Desktop utilizes WSL2 to run a thin virtual environment for Docker to run within, powering your install.

::: warning YOU MUST HAVE WSL2 ENABLED
Make sure that the [WSL2 feature is enabled](https://learn.microsoft.com/en-us/windows/wsl/install) or the Lando installer will fail.

If you want to use the older [Hyper-V](https://learn.microsoft.com/en-us/virtualization/hyper-v-on-windows/quick-start/enable-hyper-v) compatible version of Lando use version 3.6.5 or below however it is recommended to update to the new WSL based backend.
:::

1.  Make sure you are using **at least** Windows 10 Home or Professional version 21H2 or higher
2.  Download the latest Windows `.exe` installer from [GitHub](https://github.com/lando/lando/releases)
3.  Double-click on `lando.exe`
4.  Go through the setup workflow
5.  Approve various UAC prompts during install

## Manual Installation in WSL2

If you want to use Lando within a Linux environment that you have created within WSL2, you can follow the [Linux installation instructions](./linux.md).
