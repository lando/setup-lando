---
title: Linux
description: Install Lando on Linux
---

# Linux

The Linux quickstart is to paste the below into a terminal and execute it.

```bash
/bin/bash -c "$(curl -fsSL https://get.lando.dev/setup-lando.sh)"
```

If you are looking to customize your install then [advanced usage](#advanced) is for you.

## Advanced

The installation script has various options but you will need to download the script and invoke it directly.

```bash
# save the script
curl -fsSL https://get.lando.dev/setup-lando.sh -o setup-lando.sh

# make it executable
chmod +x ./setup-lando.sh

# get usage info
bash setup-lando.sh --help
```

### Usage

```bash
Usage: [NONINTERACTIVE=1] [CI=1] setup-lando.sh [options]

Options:
  --arch           installs for this arch [default: x64]
  --dest           installs in this directory [default: ~/.lando/bin]
  --fat            installs fat cli <3.24 only, not recommended
  --no-setup       installs without running lando setup <3.24 only
  --os             installs for this os [default: linux]
  --syslink        installs symlink in /usr/local/bin [default: auto]
  --version        installs this version [default: stable]
  --debug          shows debug messages
  -h, --help       displays this message
  -y, --yes        runs with all defaults and no prompts, sets NONINTERACTIVE=1

Environment Variables:
  NONINTERACTIVE   installs without prompting for user input
  CI               installs in CI mode (e.g. does not prompt for user input)
```

Some notes on advanced usage:

* If you are running in `CI` then `--syslink` will be assumed
* If you have an existing installation of `lando` in `/usr/local/bin` and can write to that location then `--syslink` will be assumed
* If you run in a non-tty environment eg GitHub Actions then `--yes` will be assumed
* If you use `--yes` it is equivalent to setting `NONINTERACTIVE=1`

#### Environment Variables

If you do not wish to download the script you can set options with environment variables and `curl` the script.

```bash
LANDO_VERSION=stable
LANDO_INSTALLER_ARCH=auto
LANDO_INSTALLER_DEBUG=0
LANDO_INSTALLER_DEST="~/.lando/bin"
LANDO_INSTALLER_FAT=0
LANDO_INSTALLER_OS=linux
LANDO_INSTALLER_SETUP=auto
LANDO_INSTALLER_SYSLINK=auto
```

#### Examples

These are equivalent commands and meant to demostrate environment variable usage vs direct invocation.

```bash
# use envvars
LANDO_VERSION=3.23.11 \
LANDO_INSTALLER_DEBUG=1 \
LANDO_INSTALLER_SYSLINK=1 \
  /bin/bash -c "$(curl -fsSL https://get.lando.dev/setup-lando.sh)"

# invoke directly
bash setup-lando.sh --version "3.23.11" --debug --syslink
```
