# Setup Lando

This action installs Lando in GitHub Actions. With it you can:

* Install using a version-spec-ish eg `3`, `3.12`, `3.x`, `3.14.0`
* Install using convenience aliases eg `stable`, `4-latest`, `main` `3-edge`
* Install and compile directly from a source `ref`
* Set [global Lando config](https://docs.lando.dev/core/global.html) configuration

> **NOTE:** If you are using a self-hosted or custom runner you may need to install the needed Lando dependenices eg Docker and Docker Compose for Lando to work correctly!

## Inputs

All inputs are optional. If you do nothing the latest `stable` Lando will be installed.

| Name | Description | Default | Example |
|---|---|---|---|
| `lando-version` | The version of Lando to install. If set this has primacy over `lando-version-file`. | `stable` | `3.14.0` |
| `lando-version-file` | The AppStore Connect API Issuer. | `.lando-version` | `.tool-versions` |
| `config` | A list of `.` delimited config. If set these have primacy over values in `config-file` | `null` | `engineConfig.port=2376` |
| `config-file` | The path to a Lando global config file to use. | `null` | `/config/lando-global.yml` |

##  Usage

### Basic Usage

```yaml
- name: Setup Lando
  uses: lando/setup-lando@v2
```

## Changelog

We try to log all changes big and small in both [THE CHANGELOG](https://github.com/lando/setup-lando/blob/main/CHANGELOG.md) and the [release notes](https://github.com/lando/setup-lando/releases).

## Releasing

1. Correctly compile, bump versions, tag things and push to GitHub

  ```bash
  yarn release
  ```

2. Publish to [GitHub Actions Marketplace](https://docs.github.com/en/enterprise-cloud@latest/actions/creating-actions/publishing-actions-in-github-marketplace)

## Contributors

<a href="https://github.com/lando/setup-lando/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=lando/setup-lando" />
</a>

Made with [contrib.rocks](https://contrib.rocks).

## Other Resources

* [Important advice](https://www.youtube.com/watch?v=WA4iX5D9Z64)
