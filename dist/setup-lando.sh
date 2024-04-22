SCRIPT_VERSION="v3.1.0"
#!/bin/bash
set -u
# Lando POSIX setup script.
#
# This script is the official and recommended way to setup Lando on your POSIX
# based computer. For information on requirements, advanced usage or installing
# in different environments (Windows, CI, GitHub Actions) you should check out:
#
# - https://docs.lando.dev/install
#
# Script source is available at https://github.com/lando/setup-lando

#
# Usage:
#
# To setup the latest stable version of Lando with all defaults you can
# directly curlbash:
#
# $ /bin/bash -c "$(curl -fsSL https://get.lando.dev/setup-lando.sh)"
#
# If you want to customize your installation you will need to download the
# script and invoke directly so you can pass in options:
#
# 1. download
#
#   $ curl -fsSL https://get.lando.dev/setup-lando.sh -o setup-lando.sh
#
# 2. make executable
#
#   $ chmod +x ./setup-lando.sh
#
# 3. print advanced usage
#
#   $ bash setup-lando.sh --help
#
# 4. run customized setup
#
#  $ bash setup-lando.sh --no-setup --version v3.23.1 --debug --yes

#
# This script was based on the HOMEBREW installer script and as such you may
# enjoy the below licensing requirement:
#
# Copyright (c) 2009-present, Homebrew contributors
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
#
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# Any code that has been modified by the original falls under
# Copyright (c) 2009-2023, Lando.
# All rights reserved.
# See license in the repo: https://github.com/lando/setup-lando/blob/main/LICENSE
#
# We don't need return codes for "$(command)", only stdout is needed.
# Allow `[[ -n "$(command)" ]]`, `func "$(command)"`, pipes, etc.
# shellcheck disable=SC2312

# configuration things at the top for QOL
LANDO_DEFAULT_MV="3"
MACOS_OLDEST_SUPPORTED="12.0"
REQUIRED_CURL_VERSION="7.41.0"
SEMVER_REGEX='^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-((0|[1-9][0-9]*|[0-9]*[a-zA-Z-][0-9a-zA-Z-]*)(\.(0|[1-9][0-9]*|[0-9]*[a-zA-Z-][0-9a-zA-Z-]*))*))?(\+([0-9a-zA-Z-]+(\.[0-9a-zA-Z-]+)*))?$'

abort() {
  printf "%s\n" "$@" >&2
  exit 1
}

# Fail fast with a concise message when not using bash
# Single brackets are needed here for POSIX compatibility
# shellcheck disable=SC2292
if [ -z "${BASH_VERSION:-}" ]; then
  abort "Bash is required to interpret this script."
fi

# Check if script is run with force-interactive mode in CI
if [[ -n "${CI-}" && -n "${INTERACTIVE-}" ]]; then
  abort "Cannot run force-interactive mode in CI."
fi

# Check if both `INTERACTIVE` and `NONINTERACTIVE` are set
# Always use single-quoted strings with `exp` expressions
# shellcheck disable=SC2016
if [[ -n "${INTERACTIVE-}" && -n "${NONINTERACTIVE-}" ]]; then
  abort 'Both `$INTERACTIVE` and `$NONINTERACTIVE` are set. Please unset at least one variable and try again.'
fi

# Check if script is run in POSIX mode
if [[ -n "${POSIXLY_CORRECT+1}" ]]; then
  abort 'Bash must not run in POSIX mode. Please unset POSIXLY_CORRECT and try again.'
fi

if [[ -t 1 ]]; then
  tty_escape() { printf "\033[%sm" "$1"; }
else
  tty_escape() { :; }
fi
tty_mkbold() { tty_escape "1;$1"; }
tty_mkdim() { tty_escape "2;$1"; }
tty_blue="$(tty_escape 34)"
tty_bold="$(tty_mkbold 39)"
tty_dim="$(tty_mkdim 39)"
tty_green="$(tty_escape 32)"
tty_magenta="$(tty_escape 35)"
tty_red="$(tty_mkbold 31)"
tty_reset="$(tty_escape 0)"
tty_underline="$(tty_escape "4;39")"
tty_yellow="$(tty_escape 33)"

get_installer_arch() {
  local arch
  arch="$(/usr/bin/uname -m)"
  if [[ "${arch}" == "arm64" ]] || [[ "${arch}" == "aarch64" ]]; then
    INSTALLER_ARCH="arm64"
  elif [[ "${arch}" == "x86_64" ]] || [[ "${arch}" == "x64" ]]; then
    INSTALLER_ARCH="x64"
  else
    INSTALLER_ARCH="${arch}"
  fi
}

get_installer_os() {
  local os
  os="$(uname)"
  if [[ "${os}" == "Linux" ]]; then
    INSTALLER_OS="linux"
  elif [[ "${os}" == "Darwin" ]]; then
    INSTALLER_OS="macos"
  else
    INSTALLER_OS="${os}"
  fi
}

# get sysinfo
get_installer_arch
get_installer_os

# set defaults but allow envvars to be used
#
# RUNNER_DEBUG is used here so we can get good debug output when toggled in GitHub Actions
# see https://github.blog/changelog/2022-05-24-github-actions-re-run-jobs-with-debug-logging/

# @TODO: no-sudo option
# @TODO: dest
ARCH="${LANDO_INSTALLER_ARCH:-"$INSTALLER_ARCH"}"
DEBUG="${LANDO_INSTALLER_DEBUG:-${RUNNER_DEBUG:-}}"
DEST="${LANDO_INSTALLER_DEST:-/usr/local/bin}"
FAT="${LANDO_INSTALLER_FAT:-0}"
OS="${LANDO_INSTALLER_OS:-"$INSTALLER_OS"}"
SUDO="${LANDO_INSTALLER_SUDO:-1}"
SETUP="${LANDO_INSTALLER_SETUP:-1}"
VERSION="${LANDO_INSTALLER_VERSION:-"stable"}"
ORIGOPTS="$*"

usage() {
  cat <<EOS
Usage: ${tty_dim}[NONINTERACTIVE=1] [CI=1]${tty_reset} ${tty_bold}setup-lando.sh${tty_reset} ${tty_dim}[options]${tty_reset}

${tty_green}Options:${tty_reset}
  --arch           installs for this arch ${tty_dim}[default: ${ARCH}]${tty_reset}
  --dest           installs in this directory ${tty_dim}[default: ${DEST}]${tty_reset}
  --fat            installs fat cli ${tty_dim}3.21+ <4 only, not recommended${tty_reset}
  --no-setup       installs without running lando setup ${tty_dim}3.21+ <4 only${tty_reset}
  --os             installs for this os ${tty_dim}[default: ${OS}]${tty_reset}
  --version        installs this version ${tty_dim}[default: ${VERSION}]${tty_reset}
  --debug          shows debug messages
  -h, --help       displays this message
  -y, --yes        runs with all defaults and no prompts, sets NONINTERACTIVE=1

${tty_green}Environment Variables:${tty_reset}
  NONINTERACTIVE   installs without prompting for user input
  CI               installs in CI mode (e.g. does not prompt for user input)

EOS
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --arch)
      ARCH="$2"
      shift 2
      ;;
    --arch=*)
      ARCH="${1#*=}"
      shift
      ;;
    --debug)
      DEBUG=1
      shift
      ;;
    --dest)
      DEST="$2"
      shift 2
      ;;
    --dest=*)
      DEST="${1#*=}"
      shift
      ;;
    --fat)
      FAT="1"
      shift
      ;;
    -h | --help)
      usage
      ;;
    --no-setup)
      SETUP="0"
      shift
      ;;
    --os)
      OS="$2"
      shift 2
      ;;
    --os=*)
      OS="${1#*=}"
      shift
      ;;
    --version)
      VERSION="$2"
      shift 2
      ;;
    --version=*)
      VERSION="${1#*=}"
      shift
      ;;
    -y | --yes)
      NONINTERACTIVE="1"
      shift
      ;;
    *)
      warn "Unrecognized option: '$1'"
      usage 1
      ;;
  esac
done

# USER isn't always set so provide a fall back for the installer and subprocesses.
if [[ -z "${USER-}" ]]; then
  USER="$(chomp "$(id -un)")"
  export USER
fi

# Set lando debug
if [[ "$DEBUG" == "1" ]]; then
  LANDO_DEBUG="--debug"
fi;


# redefine this one
abort() {
  printf "${tty_red}ERROR${tty_reset}: %s\n" "$(chomp "$1")" >&2
  exit 1
}

abort_multi() {
  while read -r line; do
    printf "${tty_red}ERROR${tty_reset}: %s\n" "$(chomp "$line")" >&2
  done <<< "$@"
  exit 1
}

chomp() {
  printf "%s" "${1/"$'\n'"/}"
}

debug() {
  if [[ -n "${DEBUG-}" ]]; then
    printf "${tty_dim}debug${tty_reset} %s\n" "$(shell_join "$@")" >&2
  fi
}

debug_multi() {
  if [[ -n "${DEBUG-}" ]]; then
    while read -r line; do
      debug "$1 $line"
    done <<< "$@"
  fi
}

log() {
  printf "%s\n" "$(shell_join "$@")"
}

shell_join() {
  local arg
  printf "%s" "${1:-}"
  shift
  for arg in "$@"; do
    printf " "
    printf "%s" "${arg// /\ }"
  done
}

warn() {
  printf "${tty_yellow}warning${tty_reset}: %s\n" "$(chomp "$@")" >&2
}

warn_multi() {
  while read -r line; do
    warn "${line}"
  done <<< "$@"
}

# if we dont have a SCRIPT_VERSION then try to get it from git
if [[ -z "${SCRIPT_VERSION-}" ]]; then
  SCRIPT_VERSION="$(git describe --tags --always --abbrev=1)"
fi

# print version of script
debug "running setup-lando.sh script version: ${SCRIPT_VERSION}"

# debug raw options
# these are options that have not yet been validated or mutated e.g. the ones the user has supplied or defualts\
debug "raw args setup-lando.sh $ORIGOPTS"
debug raw CI="${CI:-}"
debug raw NONINTERACTIVE="${NONINTERACTIVE:-}"
debug raw ARCH="$ARCH"
debug raw DEBUG="$DEBUG"
debug raw DEST="$DEST"
debug raw FAT="$FAT"
debug raw OS="$OS"
debug raw SETUP="$SETUP"
debug raw USER="$USER"
debug raw VERSION="$VERSION"

#######################################################################  tool-verification

# precautions
unset HAVE_SUDO_ACCESS

# shellcheck disable=SC2230
find_tool() {
  if [[ $# -ne 1 ]]; then
    return 1
  fi

  local executable
  while read -r executable; do
    if [[ "${executable}" != /* ]]; then
      warn "Ignoring ${executable} (relative paths don't work)"
    elif "test_$1" "${executable}"; then
      echo "${executable}"
      break
    fi
  done < <(which -a "$1")
}

# shellcheck disable=SC2317
exists_but_not_writable() {
  [[ -e "$1" ]] && ! [[ -r "$1" && -w "$1" && -x "$1" ]]
}

find_first_existing_parent() {
  dir="$1"

  while [[ ! -d "$dir" ]]; do
    dir=$(dirname "$dir")
  done

  echo "$dir"
}

have_sudo_access() {
  if [[ ! -x "/usr/bin/sudo" ]]; then
    return 1
  fi

  local -a SUDO=("/usr/bin/sudo")
  if [[ -n "${SUDO_ASKPASS-}" ]]; then
    SUDO+=("-A")
  fi

  if [[ -z "${HAVE_SUDO_ACCESS-}" ]]; then
    "${SUDO[@]}" -l -U "${USER}" &>/dev/null
    HAVE_SUDO_ACCESS="$?"
    if [[ "${HAVE_SUDO_ACCESS}" == 1 ]]; then
      debug "${USER} does not appear to have sudo access!"
    else
      debug "${USER} has sudo access"
    fi
  fi

  return "${HAVE_SUDO_ACCESS}"
}

major() {
  echo "$1" | cut -d '.' -f1
}

major_minor() {
  echo "${1%%.*}.$(
    x="${1#*.}"
    echo "${x%%.*}"
  )"
}

# shellcheck disable=SC2317
test_curl() {
  if [[ ! -x "$1" ]]; then
    return 1
  fi

  local curl_version_output curl_name_and_version
  curl_version_output="$("$1" --version 2>/dev/null)"
  curl_name_and_version="${curl_version_output%% (*}"
  version_compare "$(major_minor "${curl_name_and_version##* }")" "$(major_minor "${REQUIRED_CURL_VERSION}")"
}

# returns true if maj.min a is greater than maj.min b
version_compare() (
  yy_a="$(echo "$1" | cut -d'.' -f1)"
  yy_b="$(echo "$2" | cut -d'.' -f1)"
  if [ "$yy_a" -lt "$yy_b" ]; then
    return 1
  fi
  if [ "$yy_a" -gt "$yy_b" ]; then
    return 0
  fi
  mm_a="$(echo "$1" | cut -d'.' -f2)"
  mm_b="$(echo "$2" | cut -d'.' -f2)"

  # trim leading zeros to accommodate CalVer
  mm_a="${mm_a#0}"
  mm_b="${mm_b#0}"

  if [ "${mm_a:-0}" -lt "${mm_b:-0}" ]; then
    return 1
  fi

  return 0
)

# abort if we dont have curl, or the right version of it
if [[ -z "$(find_tool curl)" ]]; then
  abort_multi "$(cat <<EOABORT
You must install cURL ${REQUIRED_CURL_VERSION} or higher before using this installer.
EOABORT
)"
fi

# set curl
CURL=$(find_tool curl);
debug "using the cURL at ${CURL}"

####################################################################### version validation

# if we get here we can start version handling stuff
ORIGINAL_VERSION="$VERSION"

if [[ "${ORIGINAL_VERSION}" == "3" ]]; then
  VERSION="3-stable"
fi
if [[ "${ORIGINAL_VERSION}" == "4" ]]; then
  VERSION="4-stable"
fi
if [[ "${ORIGINAL_VERSION}" == "stable" ]]; then
  VERSION="${LANDO_DEFAULT_MV}-stable"
fi
if [[ "${ORIGINAL_VERSION}" == "edge" ]]; then
  VERSION="${LANDO_DEFAULT_MV}-edge"
fi
if [[ "${ORIGINAL_VERSION}" == "dev" ]] || [[ "${ORIGINAL_VERSION}" == "latest" ]]; then
  VERSION="${LANDO_DEFAULT_MV}-dev"
fi

# STABLE
if [[ "${VERSION}" == "4-stable" ]]; then
  VERSION="$($CURL -fsSL https://raw.githubusercontent.com/lando/cli/main/release-aliases/4-STABLE | tr -s '[:blank:]')"
  URL="https://github.com/lando/cli/releases/download/${VERSION}/lando-${OS}-${ARCH}-${VERSION}"

elif [[ "${VERSION}" == "3-stable" ]]; then
  VERSION="$($CURL -fsSL https://raw.githubusercontent.com/lando/cli/main/release-aliases/3-STABLE | tr -s '[:blank:]')"
  URL="https://github.com/lando/cli/releases/download/${VERSION}/lando-${OS}-${ARCH}-${VERSION}"

# EDGE
elif [[ "${VERSION}" == "4-edge" ]]; then
  VERSION="$($CURL -fsSL https://raw.githubusercontent.com/lando/cli/main/release-aliases/4-EDGE | tr -s '[:blank:]')"
  URL="https://github.com/lando/cli/releases/download/${VERSION}/lando-${OS}-${ARCH}-${VERSION}"

elif [[ "${VERSION}" == "3-edge" ]]; then
  VERSION="$($CURL -fsSL https://raw.githubusercontent.com/lando/cli/main/release-aliases/3-EDGE | tr -s '[:blank:]')"
  URL="https://github.com/lando/cli/releases/download/${VERSION}/lando-${OS}-${ARCH}-${VERSION}"

# DEV
elif [[ "${VERSION}" == "4-dev" ]] || [[ "${VERSION}" == "4-latest" ]]; then
  URL="https://files.lando.dev/cli/lando-${OS}-${ARCH}-dev"
  VERSION_DEV=1

elif [[ "${VERSION}" == "3-dev" ]] || [[ "${VERSION}" == "3-latest" ]]; then
  URL="https://files.lando.dev/cli/lando-${OS}-${ARCH}-dev"
  VERSION_DEV=1

# CUSTOM
else
  if [[ $VERSION != v* ]]; then
    VERSION="v${VERSION}"
  fi
  URL="https://github.com/lando/cli/releases/download/${VERSION}/lando-${OS}-${ARCH}-${VERSION}"
fi

# Set some helper things
if [[ -z "${VERSION_DEV-}" ]]; then
  SVERSION="${VERSION#v}"
  LMV="$(major "$SVERSION")"
  HRV="$SVERSION"
  debug using "$SVERSION" for downstream version comparison purposes
else
  LMV="$(echo "$VERSION" | cut -c1)"
  HRV="$VERSION"
fi

# autoslim all v3 urls by default
# @TODO: --fat flag to stop this?
if [[ $LMV == '3' ]] && [[ $FAT != '1' ]]; then
  URL="${URL}-slim"
  HRV="$VERSION-slim"
  debug "autoslimin url for lando 3"
fi

# debug version resolution
debug "resolved v${LMV} version '${ORIGINAL_VERSION}' to ${VERSION} (${URL})"

# force setup to 0 if lando 4
if [[ $SETUP == '1' ]] && [[ $LMV == '4' ]]; then
  SETUP=0
  debug "disabled autosetup --setup=${SETUP}, not needed in v${LMV}"
fi

# determine existing dir we need to check
PERM_DIR="$(find_first_existing_parent "$DEST")"
debug "resolved install destination ${DEST} to a perm check on ${PERM_DIR}"

needs_sudo() {
  if [[ ! -w "$PERM_DIR" ]] || [[ ! -w "/tmp" ]]; then
    return 0;
  else
    return 1;
  fi
}

####################################################################### pre-script errors

# abort if run as root
# @NOTE: this might change in the future but right now we do not understand all the complexities around this
if [[ "${EUID:-${UID}}" == "0" ]]; then
  abort "Cannot run this script as root"
fi

# abort if dir
if needs_sudo && ! have_sudo_access; then
  abort_multi "$(cat <<EOABORT
${tty_bold}${USER}${tty_reset} cannot write to ${tty_red}${DEST}${tty_reset} and is not a ${tty_bold}sudo${tty_reset} user!
Rerun setup with a sudoer or use --dest to install to a directory ${tty_bold}${USER}${tty_reset} can write to.
For more information on advanced usage rerurn with --help or check out: ${tty_underline}${tty_magenta}https://docs.lando.dev/install${tty_reset}
EOABORT
)"
fi

# abort if unsupported os
if [[ "${OS}" != "macos" ]] && [[ "${OS}" != "linux" ]]; then
  abort_multi "$(cat <<EOABORT
This script is only for ${tty_green}macOS${tty_reset} and ${tty_green}Linux${tty_reset}! ${tty_red}${OS}${tty_reset} is not supported!
For installation on other OSes check out: ${tty_underline}${tty_magenta}https://docs.lando.dev/install${tty_reset}
EOABORT
)"
fi

# abort if unsupported arch
if [[ "${ARCH}" != "x64" ]] && [[ "${ARCH}" != "arm64" ]]; then
  abort_multi "$(cat <<EOABORT
Lando can only be installed on ${tty_green}x64${tty_reset} or ${tty_green}arm64${tty_reset} based systems!
For requirements check out: ${tty_underline}${tty_magenta}https://docs.lando.dev/requirements${tty_reset}
EOABORT
)"
fi

# abort if macos version is too low
if [[ "${OS}" == "macos" ]]; then
  macos_version="$(major_minor "$(/usr/bin/sw_vers -productVersion)")"
  if ! version_compare "${macos_version}" "${MACOS_OLDEST_SUPPORTED}"; then
    abort_multi "$(cat <<EOABORT
Your macOS version ${tty_red}${macos_version}${tty_reset} is ${tty_bold}too old${tty_reset}! Min required version is ${tty_green}${MACOS_OLDEST_SUPPORTED}${tty_reset}
For requirements check out: ${tty_underline}${tty_magenta}https://docs.lando.dev/requirements${tty_reset}
EOABORT
)"
  fi
fi

# abort if non-dev version is non-semver
if [[ -z "${VERSION_DEV-}" ]] && ! [[ "$SVERSION" =~ $SEMVER_REGEX ]]; then
  abort_multi "$(cat <<EOABORT
--version must be a ${tty_green}valid semantic version${tty_reset} or ${tty_green}supported release alias${tty_reset}. You gave ${tty_red}'${SVERSION}'${tty_reset} as the version.
Check out ${tty_underline}${tty_magenta}https://github.com/lando/setup-lando${tty_reset} for more info.
EOABORT
)"
fi

# abort if non-dev version is before 3.21
if [[ -z "${VERSION_DEV-}" ]] && ! version_compare "$SVERSION" "3.21"; then
  abort_multi "$(cat <<EOABORT
This script is for Lando ${tty_green}3.21${tty_reset} and above!
To install ${VERSION} check out ${tty_underline}${tty_magenta}https://github.com/lando/lando/releases/${VERSION}${tty_reset}
EOABORT
)"
fi

# abort if non-dev version is above 4
if [[ -z "${VERSION_DEV-}" ]] && version_compare "$SVERSION" "5.0.0"; then
  abort_multi "$(cat <<EOABORT
This script is for Lando ${tty_green}3${tty_reset} and ${tty_green}4${tty_reset} only!
EOABORT
)"
fi

# abort if version does not resolve to a url
# for some reason --silent does not seem to work with --head?
if ! "${CURL}" --location --head --silent --fail "${URL}" &>/dev/null; then
  debug "curl ${URL}"
  # shellcheck disable=SC2086
  debug_multi "curl" "$($CURL --location --head --silent $URL)"
  abort "$(cat <<EOABORT
Could not resolve ${tty_red}'${VERSION}'${tty_reset} to a downloadable URL! (${URL})
Make sure you are using a version that exists! Rerun with --debug for more info!
EOABORT
)"
else
  debug "curl ${URL}"
  debug "curl 2xx WE GOOD!"
fi

####################################################################### pre-script warnings

# Check if script is run non-interactively (e.g. CI)
# If it is run non-interactively we should not prompt for passwords.
# Always use single-quoted strings with `exp` expressions
# shellcheck disable=SC2016
if [[ -z "${NONINTERACTIVE-}" ]]; then
  if [[ -n "${CI-}" ]]; then
    warn 'Running in non-interactive mode because `$CI` is set.'
    NONINTERACTIVE=1
  elif [[ ! -t 0 ]]; then
    if [[ -z "${INTERACTIVE-}" ]];  then
      warn 'Running in non-interactive mode because `stdin` is not a TTY.'
      NONINTERACTIVE=1
    else
      warn 'Running in interactive mode despite `stdin` not being a TTY because `$INTERACTIVE` is set.'
    fi
  fi
else
  log 'Running in non-interactive mode because `$NONINTERACTIVE` is set.'
fi

# warn if arch mismatch
if [[ "${ARCH}" != "${INSTALLER_ARCH}" ]]; then
  warn_multi "$(cat <<EOS
Architecture mismatch! You are running on ${tty_yellow}${INSTALLER_ARCH}${tty_reset} but are trying to install for ${tty_yellow}${ARCH}${tty_reset}.
This might be intentional but if it is not then this is us warning you.
EOS
)"
fi

# warn if os mismatch
if [[ "${OS}" != "${INSTALLER_OS}" ]]; then
  warn_multi "$(cat <<EOS
OS mismatch! You are running on ${tty_yellow}${INSTALLER_OS}${tty_reset} but are trying to install for ${tty_yellow}${OS}${tty_reset}.
This might be intentional but if it is not then this is us warning you.
EOS
)"
fi

# @TODO: warn if setup is on but user does not have sudo access?
if [[ "${SETUP}" == "1" ]] && ! have_sudo_access; then
  warn_multi "$(cat <<EOS
Lando setup ${tty_bold}may${tty_reset} require ${tty_bold}sudo${tty_reset} but it appears like ${tty_bold}${USER}${tty_reset} does not have sudo access!
In this case you may want to rerun as a ${tty_bold}sudoer${tty_reset} or have a ${tty_bold}sudoer${tty_reset} install
needed dependencies before/after running this script.
EOS
)"
fi

####################################################################### script

getc() {
  local save_state
  save_state="$(/bin/stty -g)"
  /bin/stty raw -echo
  IFS='' read -r -n 1 -d '' "$@"
  /bin/stty "${save_state}"
}

execute() {
  debug "${tty_blue}running${tty_reset}" "$@"
  if ! "$@"; then
    abort "$(printf "Failed during: %s" "$(shell_join "$@")")"
  fi
}

execute_sudo() {
  local -a args=("$@")
  if [[ "${EUID:-${UID}}" != "0" ]] && have_sudo_access; then
    if [[ -n "${SUDO_ASKPASS-}" ]]; then
      args=("-A" "${args[@]}")
    fi
    execute "/usr/bin/sudo" "${args[@]}"
  else
    execute "${args[@]}"
  fi
}

wait_for_user() {
  local c
  echo
  echo "Press ${tty_bold}RETURN${tty_reset}/${tty_bold}ENTER${tty_reset} to continue or any other key to abort:"
  getc c
  # we test for \r and \n because some stuff does \r instead
  if ! [[ "${c}" == $'\r' || "${c}" == $'\n' ]]; then
    exit 1
  fi
}

# determine the exec we need for sudo protected things
# we add /tmp in here because their are high security environments where /tmp is not universally writable
if needs_sudo; then
  debug "auto_exec elevating to sudo"
  auto_exec() {
    execute_sudo "$@"
  }
else
  auto_exec() {
    execute "$@"
  }
fi

# Invalidate sudo timestamp before exiting (if it wasn't active before).
if [[ -x /usr/bin/sudo ]] && ! /usr/bin/sudo -n -v 2>/dev/null; then
  trap '/usr/bin/sudo -k' EXIT
fi

# Things can fail later if `pwd` doesn't exist.
# Also sudo prints a warning message for no good reason
cd "/usr" || exit 1

# if running non-interactively then lets try to summarize what we are going to do
if [[ -z "${NONINTERACTIVE-}" ]]; then
  log "${tty_bold}this script is about to:${tty_reset}"
  log
  # sudo prompt
  if needs_sudo; then log "- ${tty_green}prompt${tty_reset} for ${tty_bold}sudo${tty_reset} password"; fi
  # download
  log "- ${tty_magenta}download${tty_reset} lando ${tty_bold}${HRV}${tty_reset} to ${tty_bold}${DEST}${tty_reset}"
  # setup
  if [[ "$SETUP" == "1" ]]; then log "- ${tty_blue}run${tty_reset} ${tty_bold}lando setup${tty_reset}"; fi
  # update
  log "- ${tty_blue}run${tty_reset} ${tty_bold}lando update${tty_reset}"
  # shellenv
  log "- ${tty_blue}run${tty_reset} ${tty_bold}lando shellenv --add${tty_reset}"
  # block for user
  wait_for_user
fi

# flag for password here if needed
if needs_sudo; then
  log "please enter ${tty_bold}sudo${tty_reset} password:"
  execute_sudo true
fi

# Create directory if we need to
if [[ ! -d "$DEST" ]]; then auto_exec mkdir -p "$DEST"; fi

# LANDO
LANDO="${DEST}/lando"
LANDO_TMP="/tmp/${RANDOM}"

# download lando
log "${tty_magenta}downloading${tty_reset} ${tty_bold}${URL}${tty_reset} to ${tty_bold}${LANDO}${tty_reset}"
auto_exec curl \
  --fail \
  --location \
  --progress-bar \
  --output "$LANDO_TMP" \
  "$URL"

# make executable and weak "it works" test
auto_exec chmod +x "${LANDO_TMP}"
execute "${LANDO_TMP}" version >/dev/null

# if we get here we should be good to move it to its final destination
# NOTE: we use mv here instead of cp because of https://developer.apple.com/forums/thread/130313
auto_exec mv -f "${LANDO_TMP}" "${LANDO}"

# if lando 3 then --clear
if [[ $LMV == '3' ]]; then
  execute "${LANDO}" --clear >/dev/null
fi

# test via log
log "${tty_green}downloaded${tty_reset} @lando/cli ${tty_bold}$("${LANDO}" version --component @lando/cli)${tty_reset} to ${tty_bold}${LANDO}${tty_reset}"

# run correct setup flavor if needed
if [[ "$SETUP" == "1" ]]; then
  if [[ "${NONINTERACTIVE-}" == "1" ]]; then
    execute "${LANDO}" setup --yes "${LANDO_DEBUG-}"
  else
    execute "${LANDO}" setup "${LANDO_DEBUG-}"
  fi
fi

# update
log "${tty_blue}updating${tty_reset} ${tty_bold}lando${tty_reset}"
execute "${LANDO}" update --yes "${LANDO_DEBUG-}"

# shell env
log "${tty_blue}adding${tty_reset} ${tty_bold}${DEST}${tty_reset} to ${tty_bold}PATH${tty_reset}"
execute "${LANDO}" shellenv --add "${LANDO_DEBUG-}"

# TODO: print better messages for different situations eg ensure setup
log "${tty_green}success!${tty_reset} ${tty_bold}lando${tty_reset} is now installed!"

# FIN!
exit 0
