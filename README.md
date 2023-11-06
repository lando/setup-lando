# Setup Lando

This action installs Lando in GitHub Actions. With it you can:

* Install using a version-spec-ish eg `3`, `3.12`, `3.x`, `3.14.0`
* Install using convenience aliases eg `stable`, `4-latest`, `dev` `3-edge`
* Install preview branches eg `pm-preview`
* Install from a URL eg `https://github.com/lando/cli/releases/download/v3.18.0/lando-linux-x64-v3.18.0`
* Install from a local file eg `/home/runner/work/setup-lando/setup-lando/bin/lando`
* Set [global Lando config](https://docs.lando.dev/core/global.html) configuration
* Specify how, or if, `lando setup` should run
* Toggle `lando` debugging via [GitHub Actions](https://github.blog/changelog/2022-05-24-github-actions-re-run-jobs-with-debug-logging)
* Verify underlying `engine` and `orchestrator` dependencies are installed and correct

> **NOTE:** If you are using a self-hosted or custom runner you may need to install the needed Lando dependenices eg Docker and Docker Compose for Lando to work correctly!

## Inputs

All inputs are optional. If you do nothing the latest `stable` Lando will be installed.

| Name | Description | Default | Example |
|---|---|---|---|
| `lando-version` | The version of Lando to install. If set this has primacy over `lando-version-file`. | `stable` | `3.14.0` |
| `lando-version-file` | A file that contains the version of Lando to install. | `.lando-version` | `.tool-versions` |
| `config` | A list of `.` delimited config. If set these have primacy over values in `config-file` | `null` | `engineConfig.port=2376` |
| `config-file` | The path to a Lando global config file to use. | `null` | `/config/lando-global.yml` |
| `setup` | The lando setup command to run. | `lando setup -y` | `lando setup --skip-common-plugins --plugin @lando/core@~/path/to/core -y` |

* Note that `setup` is only available in Lando 3.21+

## Outputs

```yaml
outputs:
  lando-path:
    description: "The path to the installed version of Lando."
    value: ${{ steps.setup-lando.outputs.lando-path }}
```

##  Usage

### Basic Usage

```yaml
- name: Setup Lando
  uses: lando/setup-lando@v2
```

### Advanced Usage

**Version examples:**

```yaml
- name: Setup Lando
  uses: lando/setup-lando@v2
  with:
    lando-version: stable | edge | dev | latest | 3 | 3.14.0 | 3.11 | pm-preview
```

```yaml
- name: Setup Lando
  uses: lando/setup-lando@v2
  with:
    lando-version: https://url.to.my.lando.cli
```

```yaml
- name: Setup Lando
  uses: lando/setup-lando@v2
  with:
    lando-version: /path/to/my/lando/cli
```

**Version spec and config file:**

```yaml
- name: Setup Lando
  uses: lando/setup-lando@v2
  with:
    lando-version: ">2"
    config-file: config.yaml
```

**Version file and config list:**

```yaml
- name: Setup Lando
  uses: lando/setup-lando@v2
  with:
    lando-version-file: .tool-versions
    config: |
      core.engine=docker-colima
      core.telemetry=false
      plugins.@lando/php=/home/runner/work/php/php
```

> **NOTE:** The above config is meant purely for illustration.

**Everything, everywhere, all at once:**

```yaml
- name: Setup Lando
  uses: lando/setup-lando@v2
  with:
    architecture: x64
    config: |
      core.engine=docker-colima
      core.telemetry=false
      plugins.@lando/php=/home/runner/work/php/php
    config-file: config.yaml
    debug: true
    dependency-check: error|warn|false
    lando-version: 3.14.0
    lando-version-file: .tool-versions
    os: macOS
    telemetry: false
    token: ${{ github.token }}
    setup: lando setup --orchestrator 2.22.0 --plugins @pirog/my-plugin -y
```

## Changelog

We try to log all changes big and small in both [THE CHANGELOG](https://github.com/lando/setup-lando/blob/main/CHANGELOG.md) and the [release notes](https://github.com/lando/setup-lando/releases).

## Releasing

Create a release and publish to [GitHub Actions Marketplace](https://docs.github.com/en/enterprise-cloud@latest/actions/creating-actions/publishing-actions-in-github-marketplace). Note that the release tag must be a [semantic version](https://semver.org/).

## Contributors

<a href="https://github.com/lando/setup-lando/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=lando/setup-lando" />
</a>

Made with [contrib.rocks](https://contrib.rocks).

## Other Resources

* [Important advice](https://www.youtube.com/watch?v=WA4iX5D9Z64)
