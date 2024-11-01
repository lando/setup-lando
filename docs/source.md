---
title: From Source
description: Install Lando from source
---

# From Source

Before you install from source you need to first make sure you've manually installed the below dependencies:

* [git](https://git-scm.com/downloads)
* [the latest node 20](https://nodejs.org/en/download/)

Once you've completed the above then install LAndo from source:

```sh
# Clone
git clone https://github.com/lando/core.git core

# Install its dependencies
cd core && npm install

# Set up a symlink
sudo mkdir -p /usr/local/bin
sudo ln -s $(pwd)/bin/lando /usr/local/bin/lando

# Run lando from source
lando

# Run lando setup to ensure all needed dependencies eg Docker are installed
lando setup
```

Note that to use `bash` symlinks on Windows you need to do a bunch of other stuff first. There isn't really a great singular guide on how to do this however [this](https://stackoverflow.com/questions/5917249/git-symbolic-links-in-windows/59761201#59761201) and [this](https://github.com/orgs/community/discussions/23591) seemed to be best.

It's also possible that you may be able to skip the symlink step and just directly invoke `lando shellenv` like:

```sh
# directly invoke shellenv
node bin/lando shellenv --add

# then source the rc file lando modified or open up a new terminal
```
