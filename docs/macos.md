---
title: macOS
description: Install Lando on macOS
---

# macOS

The macOS quickstart is to paste the below into a terminal and execute it.

```bash
/bin/bash -c "$(curl -fsSL https://get.lando.dev/setup-lando.sh)"
```

If you are looking to customize your install then [advanced usage](#advanced) if for you.

## Advanced

The installation script has various options but you will need to download the script and invoke it directly.

```zsh
# save the script
curl -fsSL https://get.lando.dev/setup-lando.sh -o setup-lando.sh

# make it executable
chmod +x ./setup-lando.sh

# get usage info
bash setup-lando.sh --help

# example advanced invocation
# note you will need to change these values to ones that make sense for you
# consult the usage and notes below for more into
bash setup-lando.sh \
  --arch=arm64 \
  --dest=/Users/pirog/bin \
  --fat \
  --no-setup \
  --os=macos \
  --version=3.21.2 \
  --debug \
  --yes
```

### Usage

```zsh
[NONINTERACTIVE=1] [CI=1] setup-lando.sh \
  [--arch <x64|arm64>] \
  [--debug] \
  [--dest <path>] \
  [--fat ] \
  [--no-setup] \
  [--os <os>] \
  [--version <version>] \
  [--yes]
```

* `--arch <x64|arm64>`: Specifies the architecture to install (x64 or arm64). Defaults to the system architecture.
* `--debug`: Enables debug output.
* `--dest <path>`: Specifies the destination path for installation. Defaults to `/usr/local/bin`.
* `--fat`: Download the fat v3 Lando binary that comes with official plugins built-in.
* `--no-setup`: Skips running Lando's built-in setup script.
* `--version <version>`: Specifies the version of Lando to install. Defaults to `stable`.
* `--help`: Displays the help message.
* `--yes`: Skips all interactive prompts and installs with defaults

Some notes on advanced usage:

* If you want to install without the `sudo` password requirement then set `--dest` to a location to which your user has `write` permission. Note that you may still need `sudo` for downstream setup tasks eg if you need to install Docker Desktop.
* If you want to customize the behavior of `lando setup` use `--no-setup` and then manually invoke [`lando setup`](https://docs.lando.dev/cli/setup.html) after install is complete.
* If you run in a non-tty environment eg GitHub Actions then `--yes` will be assumed
* If you use `--yes` it is equivalent to setting `NONINTERACTIVE=1`
