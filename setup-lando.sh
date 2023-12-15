#!/bin/bash

# Lando linux/macos installer script
# This was based on the HOMEBREW installer script and as such you may enjoy the below licensing requirement:
#
# Copyright (c) 2009-present, Homebrew contributors
# All rights reserved.

# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:

# * Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.

# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.

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

# Any code that has been modified by the original falls under
# Copyright (c) 2009-2023, Lando.
# All rights reserved.
# See license in the repo: https://github.com/lando/setup-lando/blob/main/LICENSE

# We don't need return codes for "$(command)", only stdout is needed.
# Allow `[[ -n "$(command)" ]]`, `func "$(command)"`, pipes, etc.
# shellcheck disable=SC2312

set -u

# configuration things, at the top for quality of life
LANDO_DEFAULT_MV="3"
MACOS_NEWEST_UNSUPPORTED="15.0"
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
tty_underline="$(tty_escape "4;39")"
tty_red="$(tty_mkbold 31)"
tty_green="$(tty_escape 32)"
tty_yellow="$(tty_escape 33)"
tty_magenta="$(tty_escape 35)"
tty_bold="$(tty_mkbold 39)"
tty_dim="$(tty_mkdim 39)"
tty_reset="$(tty_escape 0)"
# tty_blue="$(tty_mkbold 34)"

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
DEST="${LANDO_INSTALLER_DEST:-"${HOME}/.lando/bin"}"
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
  --no-setup       installs without running lando setup ${tty_dim}3.21+ <4 only${tty_reset}
  --no-sudo        installs without sudo ${tty_dim}may require additional manual setup${tty_reset}
  --os             installs for this os ${tty_dim}[default: ${OS}]${tty_reset}
  --version        installs this version ${tty_dim}[default: ${VERSION}]${tty_reset}
  --debug          shows debug messages
  -h, --help       displays this message

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
    -h | --help)
      usage
      ;;
    --no-setup)
      SUDO="0"
      shift
      ;;
    --no-sudo)
      SUDO="0"
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

# redefine this one
abort() {
  printf "${tty_red}ERROR${tty_reset}: %s\n" "$(chomp "$1")" >&2
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
  printf "$(shell_join "$@")"
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

# debug raw options
# these are options that have not yet been validated or mutated e.g. the ones the user has supplied or defualts\
debug "raw args setup-lando.sh $ORIGOPTS"
debug raw ARCH="$ARCH"
debug raw DEBUG="$DEBUG"
debug raw DEST="$DEST"
debug raw OS="$OS"
debug raw SETUP="$SETUP"
debug raw SUDO="$SUDO"
debug raw USER="$USER"
debug raw VERSION="$VERSION"

#######################################################################  tool-verification

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

# at this point we should be able to resolve release aliases

# STABLE
if [[ "${VERSION}" == "4-stable" ]]; then
  VERSION="$($CURL -fsSL https://raw.githubusercontent.com/lando/cli/main/release-aliases/4-STABLE | tr -s '[:blank:]')"
  URL="https://github.com/lando/cli/releases/download/${VERSION}/lando-${OS}-${ARCH}-${VERSION}"

elif [[ "${VERSION}" == "3-stable" ]]; then
  VERSION="$($CURL -fsSL https://raw.githubusercontent.com/lando/cli/main/release-aliases/3-STABLE | tr -s '[:blank:]')"
  URL="https://github.com/lando/cli/releases/download/${VERSION}/lando-${OS}-${ARCH}-${VERSION}"

elif [[ "${VERSION}" == "3-stable-slim" ]]; then
  VERSION="$($CURL -fsSL https://raw.githubusercontent.com/lando/cli/main/release-aliases/3-STABLE | tr -s '[:blank:]')"
  URL="https://github.com/lando/cli/releases/download/${VERSION}/lando-${OS}-${ARCH}-${VERSION}-slim"

# EDGE
elif [[ "${VERSION}" == "4-edge" ]]; then
  VERSION="$($CURL -fsSL https://raw.githubusercontent.com/lando/cli/main/release-aliases/4-EDGE | tr -s '[:blank:]')"
  URL="https://github.com/lando/cli/releases/download/${VERSION}/lando-${OS}-${ARCH}-${VERSION}"

elif [[ "${VERSION}" == "3-edge" ]]; then
  VERSION="$($CURL -fsSL https://raw.githubusercontent.com/lando/cli/main/release-aliases/3-EDGE | tr -s '[:blank:]')"
  URL="https://github.com/lando/cli/releases/download/${VERSION}/lando-${OS}-${ARCH}-${VERSION}"

elif [[ "${VERSION}" == "3-edge-slim" ]]; then
  VERSION="$($CURL -fsSL https://raw.githubusercontent.com/lando/cli/main/release-aliases/3-EDGE | tr -s '[:blank:]')"
  URL="https://github.com/lando/cli/releases/download/${VERSION}/lando-${OS}-${ARCH}-${VERSION}-slim"

# DEV
elif [[ "${VERSION}" == "4-dev" ]]; then
  URL="https://files.lando.dev/cli/lando-${OS}-${ARCH}-dev"
  VERSION_DEV=1

elif [[ "${VERSION}" == "3-dev" ]] ; then
  URL="https://files.lando.dev/cli/lando-${OS}-${ARCH}-dev"
  VERSION_DEV=1

elif [[ "${VERSION}" == "3-dev-slim" ]]; then
  URL="https://files.lando.dev/cli/lando-${OS}-${ARCH}-dev-slim"
  VERSION_DEV=1

# CUSTOM
else
  if [[ $VERSION != v* ]]; then
    VERSION="v${VERSION}"
  fi
  URL="https://github.com/lando/cli/releases/download/${VERSION}/lando-${OS}-${ARCH}-${VERSION}"
fi

# debug version resolution
debug "resolved version '${ORIGINAL_VERSION}' to ${VERSION} (${URL})"

# get semver if it makes sense
if [[ -z "${VERSION_DEV-}" ]]; then
  SVERSION="${VERSION#v}"
  debug using "$SVERSION" for version comparison purposes
fi

####################################################################### pre-script errors

# abort if run as root
# @NOTE: this might change in the future but right now we do not understand all the complexities around this
if [[ "${EUID:-${UID}}" == "0" ]]; then
  abort "Cannot run this script as root"
fi

# abort if unsupported os
if [[ "${OS}" != "macos" ]] && [[ "${OS}" != "linux" ]] ; then
  abort_multi "$(cat <<EOABORT
This installer is only supported on macOS and Linux and not on ${tty_bold}${OS}${tty_reset}!
For installation on other OSes check out: ${tty_underline}${tty_magenta}https://docs.lando.dev/install${tty_reset}
EOABORT
)"
fi

# abort if unsupported arch
if [[ "${ARCH}" != "x64" ]] && [[ "${ARCH}" != "arm64" ]] ; then
  abort_multi "$(cat <<EOABORT
Lando cannot be install on anything but ${tty_bold}x64${tty_reset} or ${tty_bold}arm64${tty_reset} based systems!
For requirements check out: ${tty_underline}${tty_magenta}https://docs.lando.dev/requirements${tty_reset}
EOABORT
)"
fi

# abort if macos version is too low
if [[ "${OS}" == "macos" ]];then
  macos_version="$(major_minor "$(/usr/bin/sw_vers -productVersion)")"
  if ! version_compare "${macos_version}" "${MACOS_OLDEST_SUPPORTED}"; then
    abort_multi "$(cat <<EOABORT
Your macOS version (${macos_version}) is ${tty_bold}too old${tty_reset}! Min required version is ${MACOS_OLDEST_SUPPORTED}
For requirements check out: ${tty_underline}${tty_magenta}https://docs.lando.dev/requirements${tty_reset}
EOABORT
)"
  fi
fi

# abort if non-dev version is non-semver
if [[ -z "${VERSION_DEV-}" ]] && ! [[ "$SVERSION" =~ $SEMVER_REGEX ]]; then
  abort_multi "$(cat <<EOABORT
"Lando version must be a valid semantic version or supported release alias. You gave '${SVERSION}' as the version."
Check out ${tty_underline}${tty_magenta}https://github.com/lando/setup-lando${tty_reset} for more info.
EOABORT
)"
fi

# abort if non-dev version is before 3.21
if [[ -z "${VERSION_DEV-}" ]] && ! version_compare "$SVERSION" "3.21"; then
  abort_multi "$(cat <<EOABORT
This installer is for Lando 3.21 and above!
To install ${VERSION} check out ${tty_underline}${tty_magenta}https://github.com/lando/lando/releases/${VERSION}${tty_reset}
EOABORT
)"
fi

# abort if non-dev version is above 4
if [[ -z "${VERSION_DEV-}" ]] && version_compare "$SVERSION" "5.0.0"; then
  abort_multi "$(cat <<EOABORT
This installer is for Lando 3 and 4 only!
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
Could not resolve '${VERSION}' to a downloadable URL! (${URL})
Make sure you are using a version that exists! Rerun with --debug for more info!
EOABORT
)"
else
  debug "curl ${URL}"
  debug "curl 2xx WE GOOD!"
fi

####################################################################### pre-script warnings

have_sudo_access() {
  if [[ ! -x "/usr/bin/sudo" ]]; then
    return 1
  fi

  local -a SUDO=("/usr/bin/sudo")
  if [[ -n "${SUDO_ASKPASS-}" ]]; then
    SUDO+=("-A")
  elif [[ -n "${NONINTERACTIVE-}" ]]; then
    SUDO+=("-n")
  fi

  if [[ -z "${HAVE_SUDO_ACCESS-}" ]]; then
    if [[ -n "${NONINTERACTIVE-}" ]]; then
      "${SUDO[@]}" -l mkdir &>/dev/null
    else
      "${SUDO[@]}" -l -U ${USER} &>/dev/null
    fi
    HAVE_SUDO_ACCESS="$?"
  fi

  return "${HAVE_SUDO_ACCESS}"
}

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

# warn if macOS is ahead
if [[ "${OS}" == "macos" ]];then
  macos_version="$(major_minor "$(/usr/bin/sw_vers -productVersion)")"
  if ! version_compare "${MACOS_NEWEST_UNSUPPORTED}" "${macos_version}"; then
    warn_multi "$(cat <<EOS

You are using macOS ${macos_version} which is above our OFFICIALLY supported range!

${tty_bold}This installation may not succeed. Then again, it also might be fine.${tty_reset}

Basically we just want to tell you that you are in uncharted territory and YMMV.
EOS
)"
  warn

  fi
fi

# warn if arch mismatch
if [[ "${ARCH}" != "${INSTALLER_ARCH}" ]]; then
  warn_multi "$(cat <<EOS
Architecture mismatch! You are running on ${INSTALLER_ARCH} but are trying to install for ${ARCH}.
This might be intentional but if it is not then this is us warning you.
EOS
)"
fi

# warn if os mismatch
if [[ "${OS}" != "${INSTALLER_OS}" ]]; then
  warn_multi "$(cat <<EOS
OS mismatch! You are running on ${INSTALLER_OS} but are trying to install for ${OS}.
This might be intentional but if it is not then this is us warning you.
EOS
)"
fi

# warn if sudo mismatch exists
USER=bob
if [[ "${SUDO}" -ne 0 ]] && ! have_sudo_access; then
  warn "Trying to run with sudo but user '${USER}' "
fi



exit 0

# if we get here we are solidly in "warning" territory



# check_run_command_as_root() {
#   [[ "${EUID:-${UID}}" == "0" ]] || return

#   # Allow Azure Pipelines/GitHub Actions/Docker/Concourse/Kubernetes to do everything as root (as it's normal there)
#   [[ -f /.dockerenv ]] && return
#   [[ -f /run/.containerenv ]] && return
#   [[ -f /proc/1/cgroup ]] && grep -E "azpl_job|actions_job|docker|garden|kubepods" -q /proc/1/cgroup && return

#   abort "Don't run this as root!"
# }

# execute() {
#   if ! "$@"; then
#     abort "$(printf "Failed during: %s" "$(shell_join "$@")")"
#   fi
# }

# execute_sudo() {
#   local -a args=("$@")
#   if [[ "${EUID:-${UID}}" != "0" ]] && have_sudo_access; then
#     if [[ -n "${SUDO_ASKPASS-}" ]]; then
#       args=("-A" "${args[@]}")
#     fi
#     ohai "/usr/bin/sudo" "${args[@]}"
#     execute "/usr/bin/sudo" "${args[@]}"
#   else
#     ohai "${args[@]}"
#     execute "${args[@]}"
#   fi
# }

# exists_but_not_writable() {
#   [[ -e "$1" ]] && ! [[ -r "$1" && -w "$1" && -x "$1" ]]
# }

# file_not_grpowned() {
#   [[ " $(id -G "${USER}") " != *" $(get_group "$1") "* ]]
# }

# file_not_owned() {
#   [[ "$(get_owner "$1")" != "$(id -u)" ]]
# }

# get_group() {
#   "${STAT_PRINTF[@]}" "%g" "$1"
# }

# get_owner() {
#   "${STAT_PRINTF[@]}" "%u" "$1"
# }

# get_permission() {
#   "${STAT_PRINTF[@]}" "${PERMISSION_FORMAT}" "$1"
# }

# getc() {
#   local save_state
#   save_state="$(/bin/stty -g)"
#   /bin/stty raw -echo
#   IFS='' read -r -n 1 -d '' "$@"
#   /bin/stty "${save_state}"
# }


# ring_bell() {
#   # Use the shell's audible bell.
#   if [[ -t 1 ]]
#   then
#     printf "\a"
#   fi
# }

# user_only_chmod() {
#   [[ -d "$1" ]] && [[ "$(get_permission "$1")" != 75[0145] ]]
# }

# wait_for_user() {
#   local c
#   echo
#   echo "Press ${tty_bold}RETURN${tty_reset}/${tty_bold}ENTER${tty_reset} to continue or any other key to abort:"
#   getc c
#   # we test for \r and \n because some stuff does \r instead
#   if ! [[ "${c}" == $'\r' || "${c}" == $'\n' ]]
#   then
#     exit 1
#   fi
# }

# # Search for the given executable in PATH (avoids a dependency on the `which` command)
# which() {
#   # Alias to Bash built-in command `type -P`
#   type -P "$@"
# }

# # Required installation paths. To install elsewhere (which is unsupported)
# # you can untar https://github.com/Homebrew/brew/tarball/master
# # anywhere you like.
# if [[ -n "${HOMEBREW_ON_MACOS-}" ]]
# then
#   UNAME_MACHINE="$(/usr/bin/uname -m)"

#   if [[ "${UNAME_MACHINE}" == "arm64" ]]
#   then
#     # On ARM macOS, this script installs to /opt/homebrew only
#     HOMEBREW_PREFIX="/opt/homebrew"
#     HOMEBREW_REPOSITORY="${HOMEBREW_PREFIX}"
#   else
#     # On Intel macOS, this script installs to /usr/local only
#     HOMEBREW_PREFIX="/usr/local"
#     HOMEBREW_REPOSITORY="${HOMEBREW_PREFIX}/Homebrew"
#   fi
#   HOMEBREW_CACHE="${HOME}/Library/Caches/Homebrew"

#   STAT_PRINTF=("stat" "-f")
#   PERMISSION_FORMAT="%A"
#   CHOWN=("/usr/sbin/chown")
#   CHGRP=("/usr/bin/chgrp")
#   GROUP="admin"
#   TOUCH=("/usr/bin/touch")
#   INSTALL=("/usr/bin/install" -d -o "root" -g "wheel" -m "0755")
# else
#   UNAME_MACHINE="$(uname -m)"

#   # On Linux, this script installs to /home/linuxbrew/.linuxbrew only
#   HOMEBREW_PREFIX="/home/linuxbrew/.linuxbrew"
#   HOMEBREW_REPOSITORY="${HOMEBREW_PREFIX}/Homebrew"
#   HOMEBREW_CACHE="${HOME}/.cache/Homebrew"

#   STAT_PRINTF=("stat" "--printf")
#   PERMISSION_FORMAT="%a"
#   CHOWN=("/bin/chown")
#   CHGRP=("/bin/chgrp")
#   GROUP="$(id -gn)"
#   TOUCH=("/bin/touch")
#   INSTALL=("/usr/bin/install" -d -o "${USER}" -g "${GROUP}" -m "0755")
# fi
# CHMOD=("/bin/chmod")
# MKDIR=("/bin/mkdir" "-p")
# HOMEBREW_BREW_DEFAULT_GIT_REMOTE="https://github.com/Homebrew/brew"
# HOMEBREW_CORE_DEFAULT_GIT_REMOTE="https://github.com/Homebrew/homebrew-core"

# # Use remote URLs of Homebrew repositories from environment if set.
# HOMEBREW_BREW_GIT_REMOTE="${HOMEBREW_BREW_GIT_REMOTE:-"${HOMEBREW_BREW_DEFAULT_GIT_REMOTE}"}"
# HOMEBREW_CORE_GIT_REMOTE="${HOMEBREW_CORE_GIT_REMOTE:-"${HOMEBREW_CORE_DEFAULT_GIT_REMOTE}"}"
# # The URLs with and without the '.git' suffix are the same Git remote. Do not prompt.
# if [[ "${HOMEBREW_BREW_GIT_REMOTE}" == "${HOMEBREW_BREW_DEFAULT_GIT_REMOTE}.git" ]]
# then
#   HOMEBREW_BREW_GIT_REMOTE="${HOMEBREW_BREW_DEFAULT_GIT_REMOTE}"
# fi
# if [[ "${HOMEBREW_CORE_GIT_REMOTE}" == "${HOMEBREW_CORE_DEFAULT_GIT_REMOTE}.git" ]]
# then
#   HOMEBREW_CORE_GIT_REMOTE="${HOMEBREW_CORE_DEFAULT_GIT_REMOTE}"
# fi
# export HOMEBREW_{BREW,CORE}_GIT_REMOTE





# # Invalidate sudo timestamp before exiting (if it wasn't active before).
# if [[ -x /usr/bin/sudo ]] && ! /usr/bin/sudo -n -v 2>/dev/null; then
#   trap '/usr/bin/sudo -k' EXIT
# fi

# # Things can fail later if `pwd` doesn't exist.
# # Also sudo prints a warning message for no good reason
# cd "/usr" || exit 1

# ####################################################################### script

# # shellcheck disable=SC2016
# ohai 'Checking for `sudo` access (which may request your password)...'

# if [[ -n "${HOMEBREW_ON_MACOS-}" ]]
# then
#   [[ "${EUID:-${UID}}" == "0" ]] || have_sudo_access
# elif ! [[ -w "${HOMEBREW_PREFIX}" ]] &&
#      ! [[ -w "/home/linuxbrew" ]] &&
#      ! [[ -w "/home" ]] &&
#      ! have_sudo_access
# then
#   abort "$(
#     cat <<EOABORT
# Insufficient permissions to install Homebrew to \"${HOMEBREW_PREFIX}\" (the default prefix).

# Alternative (unsupported) installation methods are available at:
# https://docs.brew.sh/Installation#alternative-installs

# Please note this will require most formula to build from source, a buggy, slow and energy-inefficient experience.
# We will close any issues without response for these unsupported configurations.
# EOABORT
#   )"
# fi
# HOMEBREW_CORE="${HOMEBREW_REPOSITORY}/Library/Taps/homebrew/homebrew-core"

# check_run_command_as_root

# if [[ -d "${HOMEBREW_PREFIX}" && ! -x "${HOMEBREW_PREFIX}" ]]
# then
#   abort "$(
#     cat <<EOABORT
# The Homebrew prefix ${tty_underline}${HOMEBREW_PREFIX}${tty_reset} exists but is not searchable.
# If this is not intentional, please restore the default permissions and
# try running the installer again:
#     sudo chmod 775 ${HOMEBREW_PREFIX}
# EOABORT
#   )"
# fi


# ohai "This script will install:"
# echo "${HOMEBREW_PREFIX}/bin/brew"
# echo "${HOMEBREW_PREFIX}/share/doc/homebrew"
# echo "${HOMEBREW_PREFIX}/share/man/man1/brew.1"
# echo "${HOMEBREW_PREFIX}/share/zsh/site-functions/_brew"
# echo "${HOMEBREW_PREFIX}/etc/bash_completion.d/brew"
# echo "${HOMEBREW_REPOSITORY}"

# # Keep relatively in sync with
# # https://github.com/Homebrew/brew/blob/master/Library/Homebrew/keg.rb
# directories=(
#   bin etc include lib sbin share opt var
#   Frameworks
#   etc/bash_completion.d lib/pkgconfig
#   share/aclocal share/doc share/info share/locale share/man
#   share/man/man1 share/man/man2 share/man/man3 share/man/man4
#   share/man/man5 share/man/man6 share/man/man7 share/man/man8
#   var/log var/homebrew var/homebrew/linked
#   bin/brew
# )
# group_chmods=()
# for dir in "${directories[@]}"
# do
#   if exists_but_not_writable "${HOMEBREW_PREFIX}/${dir}"
#   then
#     group_chmods+=("${HOMEBREW_PREFIX}/${dir}")
#   fi
# done

# # zsh refuses to read from these directories if group writable
# directories=(share/zsh share/zsh/site-functions)
# zsh_dirs=()
# for dir in "${directories[@]}"
# do
#   zsh_dirs+=("${HOMEBREW_PREFIX}/${dir}")
# done

# directories=(
#   bin etc include lib sbin share var opt
#   share/zsh share/zsh/site-functions
#   var/homebrew var/homebrew/linked
#   Cellar Caskroom Frameworks
# )
# mkdirs=()
# for dir in "${directories[@]}"
# do
#   if ! [[ -d "${HOMEBREW_PREFIX}/${dir}" ]]
#   then
#     mkdirs+=("${HOMEBREW_PREFIX}/${dir}")
#   fi
# done

# user_chmods=()
# mkdirs_user_only=()
# if [[ "${#zsh_dirs[@]}" -gt 0 ]]
# then
#   for dir in "${zsh_dirs[@]}"
#   do
#     if [[ ! -d "${dir}" ]]
#     then
#       mkdirs_user_only+=("${dir}")
#     elif user_only_chmod "${dir}"
#     then
#       user_chmods+=("${dir}")
#     fi
#   done
# fi

# chmods=()
# if [[ "${#group_chmods[@]}" -gt 0 ]]
# then
#   chmods+=("${group_chmods[@]}")
# fi
# if [[ "${#user_chmods[@]}" -gt 0 ]]
# then
#   chmods+=("${user_chmods[@]}")
# fi

# chowns=()
# chgrps=()
# if [[ "${#chmods[@]}" -gt 0 ]]
# then
#   for dir in "${chmods[@]}"
#   do
#     if file_not_owned "${dir}"
#     then
#       chowns+=("${dir}")
#     fi
#     if file_not_grpowned "${dir}"
#     then
#       chgrps+=("${dir}")
#     fi
#   done
# fi

# if [[ "${#group_chmods[@]}" -gt 0 ]]
# then
#   ohai "The following existing directories will be made group writable:"
#   printf "%s\n" "${group_chmods[@]}"
# fi
# if [[ "${#user_chmods[@]}" -gt 0 ]]
# then
#   ohai "The following existing directories will be made writable by user only:"
#   printf "%s\n" "${user_chmods[@]}"
# fi
# if [[ "${#chowns[@]}" -gt 0 ]]
# then
#   ohai "The following existing directories will have their owner set to ${tty_underline}${USER}${tty_reset}:"
#   printf "%s\n" "${chowns[@]}"
# fi
# if [[ "${#chgrps[@]}" -gt 0 ]]
# then
#   ohai "The following existing directories will have their group set to ${tty_underline}${GROUP}${tty_reset}:"
#   printf "%s\n" "${chgrps[@]}"
# fi
# if [[ "${#mkdirs[@]}" -gt 0 ]]
# then
#   ohai "The following new directories will be created:"
#   printf "%s\n" "${mkdirs[@]}"
# fi

# if should_install_command_line_tools
# then
#   ohai "The Xcode Command Line Tools will be installed."
# fi

# non_default_repos=""
# additional_shellenv_commands=()
# if [[ "${HOMEBREW_BREW_DEFAULT_GIT_REMOTE}" != "${HOMEBREW_BREW_GIT_REMOTE}" ]]
# then
#   ohai "HOMEBREW_BREW_GIT_REMOTE is set to a non-default URL:"
#   echo "${tty_underline}${HOMEBREW_BREW_GIT_REMOTE}${tty_reset} will be used as the Homebrew/brew Git remote."
#   non_default_repos="Homebrew/brew"
#   additional_shellenv_commands+=("export HOMEBREW_BREW_GIT_REMOTE=\"${HOMEBREW_BREW_GIT_REMOTE}\"")
# fi

# if [[ "${HOMEBREW_CORE_DEFAULT_GIT_REMOTE}" != "${HOMEBREW_CORE_GIT_REMOTE}" ]]
# then
#   ohai "HOMEBREW_CORE_GIT_REMOTE is set to a non-default URL:"
#   echo "${tty_underline}${HOMEBREW_CORE_GIT_REMOTE}${tty_reset} will be used as the Homebrew/homebrew-core Git remote."
#   non_default_repos="${non_default_repos:-}${non_default_repos:+ and }Homebrew/homebrew-core"
#   additional_shellenv_commands+=("export HOMEBREW_CORE_GIT_REMOTE=\"${HOMEBREW_CORE_GIT_REMOTE}\"")
# fi

# if [[ -n "${HOMEBREW_NO_INSTALL_FROM_API-}" ]]
# then
#   ohai "HOMEBREW_NO_INSTALL_FROM_API is set."
#   echo "Homebrew/homebrew-core will be tapped during this ${tty_bold}install${tty_reset} run."
# fi

# if [[ -z "${NONINTERACTIVE-}" ]]
# then
#   ring_bell
#   wait_for_user
# fi

# if [[ -d "${HOMEBREW_PREFIX}" ]]
# then
#   if [[ "${#chmods[@]}" -gt 0 ]]
#   then
#     execute_sudo "${CHMOD[@]}" "u+rwx" "${chmods[@]}"
#   fi
#   if [[ "${#group_chmods[@]}" -gt 0 ]]
#   then
#     execute_sudo "${CHMOD[@]}" "g+rwx" "${group_chmods[@]}"
#   fi
#   if [[ "${#user_chmods[@]}" -gt 0 ]]
#   then
#     execute_sudo "${CHMOD[@]}" "go-w" "${user_chmods[@]}"
#   fi
#   if [[ "${#chowns[@]}" -gt 0 ]]
#   then
#     execute_sudo "${CHOWN[@]}" "${USER}" "${chowns[@]}"
#   fi
#   if [[ "${#chgrps[@]}" -gt 0 ]]
#   then
#     execute_sudo "${CHGRP[@]}" "${GROUP}" "${chgrps[@]}"
#   fi
# else
#   execute_sudo "${INSTALL[@]}" "${HOMEBREW_PREFIX}"
# fi

# if [[ "${#mkdirs[@]}" -gt 0 ]]
# then
#   execute_sudo "${MKDIR[@]}" "${mkdirs[@]}"
#   execute_sudo "${CHMOD[@]}" "ug=rwx" "${mkdirs[@]}"
#   if [[ "${#mkdirs_user_only[@]}" -gt 0 ]]
#   then
#     execute_sudo "${CHMOD[@]}" "go-w" "${mkdirs_user_only[@]}"
#   fi
#   execute_sudo "${CHOWN[@]}" "${USER}" "${mkdirs[@]}"
#   execute_sudo "${CHGRP[@]}" "${GROUP}" "${mkdirs[@]}"
# fi

# if ! [[ -d "${HOMEBREW_REPOSITORY}" ]]
# then
#   execute_sudo "${MKDIR[@]}" "${HOMEBREW_REPOSITORY}"
# fi
# execute_sudo "${CHOWN[@]}" "-R" "${USER}:${GROUP}" "${HOMEBREW_REPOSITORY}"

# if ! [[ -d "${HOMEBREW_CACHE}" ]]
# then
#   if [[ -n "${HOMEBREW_ON_MACOS-}" ]]
#   then
#     execute_sudo "${MKDIR[@]}" "${HOMEBREW_CACHE}"
#   else
#     execute "${MKDIR[@]}" "${HOMEBREW_CACHE}"
#   fi
# fi
# if exists_but_not_writable "${HOMEBREW_CACHE}"
# then
#   execute_sudo "${CHMOD[@]}" "g+rwx" "${HOMEBREW_CACHE}"
# fi
# if file_not_owned "${HOMEBREW_CACHE}"
# then
#   execute_sudo "${CHOWN[@]}" "-R" "${USER}" "${HOMEBREW_CACHE}"
# fi
# if file_not_grpowned "${HOMEBREW_CACHE}"
# then
#   execute_sudo "${CHGRP[@]}" "-R" "${GROUP}" "${HOMEBREW_CACHE}"
# fi
# if [[ -d "${HOMEBREW_CACHE}" ]]
# then
#   execute "${TOUCH[@]}" "${HOMEBREW_CACHE}/.cleaned"
# fi

# ohai "Downloading and installing Homebrew..."
# (
#   cd "${HOMEBREW_REPOSITORY}" >/dev/null || return

#   # we do it in four steps to avoid merge errors when reinstalling
#   execute "${USABLE_GIT}" "-c" "init.defaultBranch=master" "init" "--quiet"

#   # "git remote add" will fail if the remote is defined in the global config
#   execute "${USABLE_GIT}" "config" "remote.origin.url" "${HOMEBREW_BREW_GIT_REMOTE}"
#   execute "${USABLE_GIT}" "config" "remote.origin.fetch" "+refs/heads/*:refs/remotes/origin/*"

#   # ensure we don't munge line endings on checkout
#   execute "${USABLE_GIT}" "config" "--bool" "core.autocrlf" "false"

#   # make sure symlinks are saved as-is
#   execute "${USABLE_GIT}" "config" "--bool" "core.symlinks" "true"

#   execute "${USABLE_GIT}" "fetch" "--force" "origin"
#   execute "${USABLE_GIT}" "fetch" "--force" "--tags" "origin"

#   execute "${USABLE_GIT}" "reset" "--hard" "origin/master"

#   if [[ "${HOMEBREW_REPOSITORY}" != "${HOMEBREW_PREFIX}" ]]
#   then
#     if [[ "${HOMEBREW_REPOSITORY}" == "${HOMEBREW_PREFIX}/Homebrew" ]]
#     then
#       execute "ln" "-sf" "../Homebrew/bin/brew" "${HOMEBREW_PREFIX}/bin/brew"
#     else
#       abort "The Homebrew/brew repository should be placed in the Homebrew prefix directory."
#     fi
#   fi

#   if [[ -n "${HOMEBREW_NO_INSTALL_FROM_API-}" && ! -d "${HOMEBREW_CORE}" ]]
#   then
#     # Always use single-quoted strings with `exp` expressions
#     # shellcheck disable=SC2016
#     ohai 'Tapping homebrew/core because `$HOMEBREW_NO_INSTALL_FROM_API` is set.'
#     (
#       execute "${MKDIR[@]}" "${HOMEBREW_CORE}"
#       cd "${HOMEBREW_CORE}" >/dev/null || return

#       execute "${USABLE_GIT}" "-c" "init.defaultBranch=master" "init" "--quiet"
#       execute "${USABLE_GIT}" "config" "remote.origin.url" "${HOMEBREW_CORE_GIT_REMOTE}"
#       execute "${USABLE_GIT}" "config" "remote.origin.fetch" "+refs/heads/*:refs/remotes/origin/*"
#       execute "${USABLE_GIT}" "config" "--bool" "core.autocrlf" "false"
#       execute "${USABLE_GIT}" "config" "--bool" "core.symlinks" "true"
#       execute "${USABLE_GIT}" "fetch" "--force" "origin" "refs/heads/master:refs/remotes/origin/master"
#       execute "${USABLE_GIT}" "remote" "set-head" "origin" "--auto" >/dev/null
#       execute "${USABLE_GIT}" "reset" "--hard" "origin/master"

#       cd "${HOMEBREW_REPOSITORY}" >/dev/null || return
#     ) || exit 1
#   fi

#   execute "${HOMEBREW_PREFIX}/bin/brew" "update" "--force" "--quiet"
# ) || exit 1

# if [[ ":${PATH}:" != *":${HOMEBREW_PREFIX}/bin:"* ]]
# then
#   warn "${HOMEBREW_PREFIX}/bin is not in your PATH.
#   Instructions on how to configure your shell for Homebrew
#   can be found in the 'Next steps' section below."
# fi

# ohai "Installation successful!"
# echo

# ring_bell

# # Use an extra newline and bold to avoid this being missed.
# ohai "Homebrew has enabled anonymous aggregate formulae and cask analytics."
# echo "$(
#   cat <<EOS
# ${tty_bold}Read the analytics documentation (and how to opt-out) here:
#   ${tty_underline}https://docs.brew.sh/Analytics${tty_reset}
# No analytics data has been sent yet (nor will any be during this ${tty_bold}install${tty_reset} run).
# EOS
# )
# "

# ohai "Homebrew is run entirely by unpaid volunteers. Please consider donating:"
# echo "$(
#   cat <<EOS
#   ${tty_underline}https://github.com/Homebrew/brew#donations${tty_reset}
# EOS
# )
# "

# (
#   cd "${HOMEBREW_REPOSITORY}" >/dev/null || return
#   execute "${USABLE_GIT}" "config" "--replace-all" "homebrew.analyticsmessage" "true"
#   execute "${USABLE_GIT}" "config" "--replace-all" "homebrew.caskanalyticsmessage" "true"
# ) || exit 1

# ohai "Next steps:"
# case "${SHELL}" in
#   */bash*)
#     if [[ -n "${HOMEBREW_ON_LINUX-}" ]]
#     then
#       shell_rcfile="${HOME}/.bashrc"
#     else
#       shell_rcfile="${HOME}/.bash_profile"
#     fi
#     ;;
#   */zsh*)
#     if [[ -n "${HOMEBREW_ON_LINUX-}" ]]
#     then
#       shell_rcfile="${ZDOTDIR:-"${HOME}"}/.zshrc"
#     else
#       shell_rcfile="${ZDOTDIR:-"${HOME}"}/.zprofile"
#     fi
#     ;;
#   */fish*)
#     shell_rcfile="${HOME}/.config/fish/config.fish"
#     ;;
#   *)
#     shell_rcfile="${ENV:-"${HOME}/.profile"}"
#     ;;
# esac

# if grep -qs "eval \"\$(${HOMEBREW_PREFIX}/bin/brew shellenv)\"" "${shell_rcfile}"
# then
#   if ! [[ -x "$(command -v brew)" ]]
#   then
#     cat <<EOS
# - Run this command in your terminal to add Homebrew to your ${tty_bold}PATH${tty_reset}:
#     eval "\$(${HOMEBREW_PREFIX}/bin/brew shellenv)"
# EOS
#   fi
# else
#   cat <<EOS
# - Run these two commands in your terminal to add Homebrew to your ${tty_bold}PATH${tty_reset}:
#     (echo; echo 'eval "\$(${HOMEBREW_PREFIX}/bin/brew shellenv)"') >> ${shell_rcfile}
#     eval "\$(${HOMEBREW_PREFIX}/bin/brew shellenv)"
# EOS
# fi

# if [[ -n "${non_default_repos}" ]]
# then
#   plural=""
#   if [[ "${#additional_shellenv_commands[@]}" -gt 1 ]]
#   then
#     plural="s"
#   fi
#   printf -- "- Run these commands in your terminal to add the non-default Git remote%s for %s:\n" "${plural}" "${non_default_repos}"
#   printf "    echo '# Set PATH, MANPATH, etc., for Homebrew.' >> %s\n" "${shell_rcfile}"
#   printf "    echo '%s' >> ${shell_rcfile}\n" "${additional_shellenv_commands[@]}"
#   printf "    %s\n" "${additional_shellenv_commands[@]}"
# fi

# if [[ -n "${HOMEBREW_ON_LINUX-}" ]]
# then
#   echo "- Install Homebrew's dependencies if you have sudo access:"

#   if [[ -x "$(command -v apt-get)" ]]
#   then
#     echo "    sudo apt-get install build-essential"
#   elif [[ -x "$(command -v yum)" ]]
#   then
#     echo "    sudo yum groupinstall 'Development Tools'"
#   elif [[ -x "$(command -v pacman)" ]]
#   then
#     echo "    sudo pacman -S base-devel"
#   elif [[ -x "$(command -v apk)" ]]
#   then
#     echo "    sudo apk add build-base"
#   fi

#   cat <<EOS
#   For more information, see:
#     ${tty_underline}https://docs.brew.sh/Homebrew-on-Linux${tty_reset}
# - We recommend that you install GCC:
#     brew install gcc
# EOS
# fi

# cat <<EOS
# - Run ${tty_bold}brew help${tty_reset} to get started
# - Further documentation:
#     ${tty_underline}https://docs.brew.sh${tty_reset}

# EOS
