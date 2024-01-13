## v3.0.0 - [December 15, 2023](https://github.com/lando/setup-lando/releases/tag/v3.0.0)

### **BREAKING CHANGES**

* Removed `dependency-check` in favor of mechanisms provided by `lando setup`

### New Features

### Bug Fixes

* Fixed `auto-setup` so it _does not_ run on Lando 4_

### Internal

### DEPRECATIONS

* Deprecated `setup` in favor of `auto-setup`

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
