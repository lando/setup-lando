---
title: Linux
description: Install Lando on Linux
---

# Linux

The Linux quickstart is to paste the below into a terminal and execute it.

```bash
/bin/bash -c "$(curl -fsSL https://get.lando.dev/setup-lando.sh)"
```

If you are looking to customize your install then [advanced usage](#advanced) if for you.

## Advanced

The installation script has various options but you will need to download the script and invoke it directly.

```bash
# save the script
curl -fsSL https://get.lando.dev/setup-lando.sh -o setup-lando.sh

# make it executable
chmod +x ./setup-lando.sh

# get usage info
bash setup-lando.sh --help

# example advanced invocation
bash setup-lando.sh \
  --arch=x64 \
  --dest=/Users/pirog/bin \
  --fat \
  --no-setup \
  --os=linux \
  --version=3.22.1 \
  --debug \
  --yes
```

### Usage

```bash
Usage: [NONINTERACTIVE=1] [CI=1] setup-lando.sh [options]

Options:
  --arch           installs for this arch [default: x64]
  --dest           installs in this directory [default: /usr/local/bin]
  --fat            installs fat cli 3.21+ <4 only, not recommended
  --no-setup       installs without running lando setup 3.21+ <4 only
  --os             installs for this os [default: linux]
  --version        installs this version [default: stable]
  --debug          shows debug messages
  -h, --help       displays this message
  -y, --yes        runs with all defaults and no prompts, sets NONINTERACTIVE=1

Environment Variables:
  NONINTERACTIVE   installs without prompting for user input
  CI               installs in CI mode (e.g. does not prompt for user input)
```

Some notes on advanced usage:

* If you want to install without the `sudo` password requirement then set `--dest` to a location to which your user has `write` permission. Note that you may still need `sudo` for downstream setup tasks eg if you need to install Docker Engine.
* If you want to customize the behavior of `lando setup` use `--no-setup` and then manually invoke [`lando setup`](https://docs.lando.dev/cli/setup.html) after install is complete.
* If you run in a non-tty environment eg GitHub Actions then `--yes` will be assumed
* If you use `--yes` it is equivalent to setting `NONINTERACTIVE=1`
