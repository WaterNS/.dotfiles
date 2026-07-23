#!/bin/sh

# Identify the kernel family separately from the host application/platform.
# a-Shell reports a Darwin kernel but is not macOS; iSH reports Linux but has
# its own emulated hardware and package constraints.

unset IS_ASHELL IS_ISH ISH_VERSION

unameDetails=$(uname -a 2>/dev/null)
unameMachine=$(uname -m 2>/dev/null)
unameRelease=$(uname -r 2>/dev/null)

case "${TERM_PROGRAM:-}:${APPNAME:-}" in
  a-Shell:*|*:a-Shell|*:a-Shell-mini|*:a-Shell-*)
    OS_FAMILY='Darwin'
    OS_PLATFORM='ashell'
    IS_ASHELL=true
    export IS_ASHELL
    ;;
  *)
    case "$unameDetails" in
      *Darwin*) OS_FAMILY='Darwin' ;;
      *Linux*) OS_FAMILY='Linux' ;;
      *)
        OS_FAMILY='unknown family'
        echo "Dotfiles OS_FAMILY: Wasn't able to id OS family"
        ;;
    esac

    if [ -r /proc/ish/version ]; then
      OS_PLATFORM='ish'
      IS_ISH=true
      ISH_VERSION=$(head -n 1 /proc/ish/version 2>/dev/null)
    elif [ -r /ish/version ]; then
      OS_PLATFORM='ish'
      IS_ISH=true
      ISH_VERSION=$(head -n 1 /ish/version 2>/dev/null)
    else
      case "$unameRelease" in
        *-ish*)
          OS_PLATFORM='ish'
          IS_ISH=true
          ISH_VERSION=$unameRelease
          ;;
        *)
          case "$OS_FAMILY" in
            Darwin) OS_PLATFORM='macos' ;;
            Linux) OS_PLATFORM='linux' ;;
            *) OS_PLATFORM='unknown' ;;
          esac
          ;;
      esac
    fi

    if [ "${IS_ISH:-}" = true ]; then
      OS_FAMILY='Linux'
      export IS_ISH ISH_VERSION
    fi
    ;;
esac
export OS_FAMILY OS_PLATFORM

case "$unameMachine" in
  i386|i486|i586|i686|x86) OS_ARCH='x32' ;;
  x86_64|amd64) OS_ARCH='x64' ;;
  arm64|ARM64|aarch64) OS_ARCH='ARM64' ;;
  armv6*|armv7*|armv8l) OS_ARCH='ARM32' ;;
  *)
    OS_ARCH='unknown arch'
    echo "Dotfiles OS_ARCH: Wasn't able to id OS arch"
    ;;
esac
export OS_ARCH

OS_NAME='unknown name'
OS_VERSION='unknown version'
if [ "${IS_ASHELL:-}" = true ]; then
  OS_NAME=${APPNAME:-a-Shell}
  OS_VERSION=${APPVERSION:-unknown}
elif [ -f /etc/os-release ]; then
  OS_NAME=$(awk -F= '$1=="NAME" { print $2; exit }' /etc/os-release | sed -e 's/^"//' -e 's/"$//')
  OS_VERSION=$(awk -F= '$1=="VERSION_ID" { print $2; exit }' /etc/os-release | sed -e 's/^"//' -e 's/"$//')
elif [ "$OS_PLATFORM" = macos ]; then
  OSX_Version_File='/System/Library/CoreServices/SystemVersion.plist'
  if [ -f "$OSX_Version_File" ] && [ -x /usr/libexec/PlistBuddy ]; then
    osx_product_name=$(/usr/libexec/PlistBuddy -c 'Print:ProductName' "$OSX_Version_File")
    OS_VERSION=$(/usr/libexec/PlistBuddy -c 'Print:ProductVersion' "$OSX_Version_File")
  fi

  AppleInstallManual='/System/Library/CoreServices/Setup Assistant.app/Contents/Resources/en.lproj/OSXSoftwareLicense.rtf'
  if [ -f "$AppleInstallManual" ]; then
    MacOSprettyName=$(awk '/SOFTWARE LICENSE AGREEMENT FOR macOS/' "$AppleInstallManual" | awk -F 'macOS ' '{print $NF}' | awk '{print substr($0, 0, length($0)-1)}')
    OS_NAME="$osx_product_name $MacOSprettyName"
  elif [ -n "${osx_product_name:-}" ]; then
    OS_NAME=$osx_product_name
  fi
else
  echo "Dotfiles OS_NAME: Wasn't able to id OS name"
fi
export OS_NAME OS_VERSION

OS_STRING="$OS_FAMILY - $OS_NAME $OS_VERSION - $OS_ARCH [$OS_PLATFORM]"
export OS_STRING
