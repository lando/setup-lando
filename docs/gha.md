---
title: GitHub Actions
description: Install Lando on GitHub Actions
---

# GitHub Actions

The GitHub Actions quickstart is:

```yaml
- name: Setup Lando
  uses: lando/setup-lando@v3
```

If you are looking to customize your install then [advanced usage](#advanced) if for you.

::: tip Docker Desktop EULA
Note that if you run this action on a Windows or macOS runner you are **implicitly accepting** the [Docker Desktop End User License Agreement](https://docs.docker.com/subscription/desktop-license/) so please be sure that is appropriate.
:::

## Inputs

All inputs are optional. If you do nothing the latest `stable` Lando will be installed.

| Name | Description | Default | Example |
|---|---|---|---|
| `auto-setup` | The lando setup command to run. | `lando setup` | `lando setup --skip-common-plugins --plugin @lando/core@~/path/to/core` |
| `lando-version` | The version of Lando to install. If set this has primacy over `lando-version-file`. | `stable` | `3.14.0` |
| `lando-version-file` | A file that contains the version of Lando to install. | `.lando-version` | `.tool-versions` |
| `config` | A list of `.` delimited config. If set these have primacy over values in `config-file` | `null` | `engineConfig.port=2376` |
| `config-file` | The path to a Lando global config file to use. | `null` | `/config/lando-global.yml` |

* Note that `auto-setup` is only available in Lando 3 and in Lando 3.21+ specifically.
* Also note that if you customize the `auto-setup` command it _must_ contain `lando setup`.

## Outputs

```yaml
outputs:
  lando-path:
    description: "The path to the installed version of Lando."
    value: ${{ steps.setup-lando.outputs.lando-path }}
```

## Advanced

Here are some examples of advanced things:

* Install using a version-spec-ish eg `3`, `3.12`, `3.x`, `3.14.0`
* Install using convenience aliases eg `stable`, `4-latest`, `dev` `3-edge`
* Install preview branches eg `pm-preview`
* Install from a URL eg `https://github.com/lando/cli/releases/download/v3.18.0/lando-linux-x64-v3.18.0`
* Install from a local file eg `/home/runner/work/setup-lando/setup-lando/bin/lando`
* Set [global Lando config](https://docs.lando.dev/core/v3/global.html) configuration
* Specify how, or if, `lando setup` should run
* Toggle `lando` debugging via [GitHub Actions](https://github.blog/changelog/2022-05-24-github-actions-re-run-jobs-with-debug-logging/)

**Version examples:**

```yaml
- name: Setup Lando
  uses: lando/setup-lando@v3
  with:
    lando-version: stable | edge | dev | latest | 3 | 3.14.0 | 3.11 | pm-preview
```

```yaml
- name: Setup Lando
  uses: lando/setup-lando@v3
  with:
    lando-version: https://url.to.my.lando.cli
```

```yaml
- name: Setup Lando
  uses: lando/setup-lando@v3
  with:
    lando-version: /path/to/my/lando/cli
```

**Version spec and config file example:**

```yaml
- name: Setup Lando
  uses: lando/setup-lando@v3
  with:
    lando-version: ">2"
    config-file: config.yaml
```

**Version file and config list example:**

```yaml
- name: Setup Lando
  uses: lando/setup-lando@v3
  with:
    lando-version-file: .tool-versions
    config: |
      core.engine=docker-colima
      core.telemetry=false
      plugins.@lando/php=/home/runner/work/php/php
```

**Version file and config list example:**

```yaml
- name: Setup Lando
  uses: lando/setup-lando@v3
  with:
    lando-version-file: .tool-versions
    config: |
      core.engine=docker-colima
      core.telemetry=false
      plugins.@lando/php=/home/runner/work/php/php
```

**Setup example:**

```yaml
- name: Setup Lando
  uses: lando/setup-lando@v3
  with:
    lando-version: 3-dev
    auto-setup: auto | off | disable | lando setup --orchestrator 2.21.0
```

**Everything, everywhere, all at once example:**

```yaml
- name: Setup Lando
  uses: lando/setup-lando@v3
  with:
    architecture: x64
    auto-setup: lando setup --orchestrator 2.22.0 --plugins @pirog/my-plugin
    config: |
      core.engine=docker-colima
      core.telemetry=false
      plugins.@lando/php=/home/runner/work/php/php
    config-file: config.yaml
    debug: true
    lando-version: 3.14.0
    lando-version-file: .tool-versions
    os: macOS
    telemetry: false
    token: ${{ github.token }}
```
