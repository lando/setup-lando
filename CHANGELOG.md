## {{ UNRELEASED_VERSION }} - [{{ UNRELEASED_DATE }}]({{ UNRELEASED_LINK }})

## v3.5.0 - [November 22, 2024](https://github.com/lando/setup-lando/releases/tag/v3.5.0)

* Added `path` based installation to POSIX `setup-lando.sh` script
* Added GitHub Actions `RUNNER_DEBUG` support to PowerShell script
* Fixed bug preventing POSIX/Windows script from replacing existing `lando` installations
* Fixed bug preventing Windows script from downloading the correct `dev` alias
* Fixed bug causing Windows script to persist `utf-16` encoding

## v3.4.5 - [November 10, 2024](https://github.com/lando/setup-lando/releases/tag/v3.4.5)

* Updated to [@lando/vitepress-theme-default-plus@v1.1.0-beta.19](https://github.com/lando/vitepress-theme-default-plus/releases/tag/v1.1.0-beta.19)

## v3.4.4 - [November 4, 2024](https://github.com/lando/setup-lando/releases/tag/v3.4.4)

* Updated to [@lando/vitepress-theme-default-plus@v1.1.0-beta.18](https://github.com/lando/vitepress-theme-default-plus/releases/tag/v1.1.0-beta.18)

## v3.4.3 - [November 1, 2024](https://github.com/lando/setup-lando/releases/tag/v3.4.3)

* Updated to [@lando/vitepress-theme-default-plus@v1.1.0-beta.16](https://github.com/lando/vitepress-theme-default-plus/releases/tag/v1.1.0-beta.16)

## v3.4.2 - [October 22, 2024](https://github.com/lando/setup-lando/releases/tag/v3.4.2)

* Fixed bug causing GitHub convenience aliases eg `3-edge-slim` to incorrectly resolve to releases with hitherto unpopulated assets

## v3.4.1 - [October 17, 2024](https://github.com/lando/setup-lando/releases/tag/v3.4.1)

* Fixed bug causing `&&` separated `auto-setup` command strings to not run correctly

## v3.4.0 - [October 15, 2024](https://github.com/lando/setup-lando/releases/tag/v3.4.0)

## New Features

* Added `LANDO_VERSION` as a way to set the `version` in the install pathways

## Fixes

* Fixed bug causing `@lando/setup-lando` GitHub Action to fail on Windows using `bash`

## Internal

* Updated download locations to standardize on relevant `core` and `core-next` pathways

## v3.3.0 - [October 11, 2024](https://github.com/lando/setup-lando/releases/tag/v3.3.0)

* Removed automatic `lando update` from `setup-lando.sh` to be consistent with other install pathways and because it makes `--version` sort of pointless 😉

## v3.2.2 - [May 17, 2024](https://github.com/lando/setup-lando/releases/tag/v3.2.2)

* Fixed `windows` setup script passing incorrect parameter to `wsl` setup script [#46](https://github.com/lando/setup-lando/issues/44)

## v3.2.1 - [May 15, 2024](https://github.com/lando/setup-lando/releases/tag/v3.2.1)

* Fixed bug preventing `Unrecognized option` message from showing correctly [#44](https://github.com/lando/setup-lando/issues/44)

## v3.2.0 - [May 3, 2024](https://github.com/lando/setup-lando/releases/tag/v3.2.0)

* Improved `$TMPDIR` handling for non standard `/tmp` usage [#41](https://github.com/lando/setup-lando/issues/41)
* Improved `arch` detection with fallbacks [#42](https://github.com/lando/setup-lando/issues/42)
* Updated `windows` installer script switch names to follow `PowerShell` convention

## v3.1.0 - [April 22, 2024](https://github.com/lando/setup-lando/releases/tag/v3.1.0)

### Windows/WSL Install Script

* Introduced new `windows` and `wsl` installer script

## v3.0.3 - [April 10, 2024](https://github.com/lando/setup-lando/releases/tag/v3.0.3)

### GitHub Actions

* Relaxed `auto-setup` validation so it only needs to contain `lando setup`

## v3.0.2 - [April 5, 2024](https://github.com/lando/setup-lando/releases/tag/v3.0.2)

### POSIX Install Script

* Improved password prompt to include unwritable `/tmp` consideration

## v3.0.1 - [April 5, 2024](https://github.com/lando/setup-lando/releases/tag/v3.0.1)

### POSIX Install Script

* Fixed bug causing `Killed: 9` output on macOS [#25](https://github.com/lando/setup-lando/issues/25)
* Improved `auto_exec` to also run `elevated` if `/tmp` is secured
* Improved download so it only replaces an existing `lando` if successfull
* Improved `lando --clear` to only run on Lando 3

## v3.0.0 - [March 22, 2024](https://github.com/lando/setup-lando/releases/tag/v3.0.0)

### **BREAKING CHANGES**

This repo should now be the single source of truth for all things relating to the installation and setup of Lando. This currently includes:

* GitHub Actions action
* POSIX setup scripts
* Install docs

But could also include other things in the future like:

* Windows/WSL2 setup scripts
* Homebrew formula
* Chocolatey packages
* Installer packages
* CI Apps

### GitHub Actions

* Deprecated `setup` in favor of `auto-setup`
* Fixed `auto-setup` so it _does not_ run on Lando 4_
* Fixed `edge` releases to also include `stable` releases from release list
* Removed `dependency-check` in favor of mechanisms provided by `lando setup`

### New Features

* Introduced `setup-lando.sh` POSIX setup script at `https://get.lando.dev/setup-lando.sh`
* Reorganized docs to reflect broadened repo scope

## v2.3.1 - [March 13, 2024](https://github.com/lando/setup-lando/releases/tag/v2.3.1)

* Fixed bug causing `3` and `4` GitHub convenience aliases to not resolve to the correct version

## v2.3.0 - [January 13, 2024](https://github.com/lando/setup-lando/releases/tag/v2.3.0)

* Added support for approved `-slim` variants
* Fixed bug causing `edge` GitHub convenience aliases to not resolve to the correct version

## v2.2.2 - [December 7, 2023](https://github.com/lando/setup-lando/releases/tag/v2.2.2)

* Added passthru support for `3-dev-slim` although it just maps to `3-dev` for now
* Removed `yarn` in favor of `npm`

## v2.2.1 - [November 9, 2023](https://github.com/lando/setup-lando/releases/tag/v2.2.1)

* Fixed bug causing `lando version` output to sometimes contain excess characters
* Fixed bug causing `debug` mode to pollute some intelligence gathering
* Fixed bug causing errors to hang the whole thing when telemetry is `true`

## v2.2.0 - [November 6, 2023](https://github.com/lando/setup-lando/releases/tag/v2.2.0)

* Added support for `lando setup` via the `setup` input
* Bumped action to `node18`
* Fixed bug where `lando` was being invoked in `PATH` instead of directly

## v2.1.0 - [June 13, 2023](https://github.com/lando/setup-lando/releases/tag/v2.1.0)

* Added `lando-version` support for local file paths
* Added support for `debug` toggling via https://github.blog/changelog/2022-05-24-github-actions-re-run-jobs-with-debug-logging
* Deprecated usage of `input.debug` in favor of GHA debugging mechanisms

## v2.0.0 - [June 13, 2023](https://github.com/lando/setup-lando/releases/tag/v2.0.0)

* Added `lando-version` support for `**preview**` branches
* Added `lando-version` support for URLs
* Switched release flow over to [@lando/prepare-release-action](https://github.com/lando/prepare-release-action)

## v2.0.0-beta.2 - [May 5, 2023](https://github.com/lando/setup-lando/releases/tag/v2.0.0-beta.2)

* Added logic around `telemetry`
* Added `v3` `dependency-check` logix

## v2.0.0-beta.1 - [May 1, 2023](https://github.com/lando/setup-lando/releases/tag/v2.0.0-beta.1)

* Initial release. See [README.md](https://github.com/lando/setup-lando).
