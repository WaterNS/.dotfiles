#!/bin/sh

# Identify Operating System (better uname)
#OS_NAME
#OS_VERSION
#OS_FAMILY
#OS_ARCH
#OS_STRING
unameDetails=$(uname -a);
case "$unameDetails" in
  *Darwin*) OS_FAMILY='Darwin';;
  *Linux*) OS_FAMILY='Linux';;
  *) OS_FAMILY='unknown family' && echo "Dotfiles OS_FAMILY: Wasn't able to id OS family";;
esac
export OS_FAMILY;

case "$unameDetails" in
  *i686*) OS_ARCH='32bit';;
  *ARM64*) OS_ARCH='ARM64';;
  *) OS_ARCH='unknown arch' && echo "Dotfiles OS_ARCH: Wasn't able to id OS arch";;
esac
export OS_ARCH;

OS_NAME="unknown name"
OS_VERSION="unknown version"
if [ -f "/etc/os-release" ]; then
  testOSnameLookup=$(awk -F= '$1=="NAME" { print $2 ;}' /etc/os-release | sed -e 's/^"//' -e 's/"$//')
  OS_NAME=$testOSnameLookup

  testOSversionLookup=$(awk -F= '$1=="VERSION_ID" { print $2 ;}' /etc/os-release | sed -e 's/^"//' -e 's/"$//')
  OS_VERSION=$testOSversionLookup
elif [ "$OS_FAMILY" = "Darwin" ]; then
  OSX_Version_File="/System/Library/CoreServices/SystemVersion.plist"
  if [ -f "$OSX_Version_File" ] && [ -x /usr/libexec/PlistBuddy ]; then
    osx_product_name=$(/usr/libexec/PlistBuddy -c "Print:ProductName" "$OSX_Version_File")
    osx_product_version=$(/usr/libexec/PlistBuddy -c "Print:ProductVersion" "$OSX_Version_File")
    #osx_product_build=$(/usr/libexec/PlistBuddy -c "Print:ProductBuildVersion" "$OSX_Version_File")
    OS_VERSION=$osx_product_version
  fi

  AppleInstallManual="/System/Library/CoreServices/Setup Assistant.app/Contents/Resources/en.lproj/OSXSoftwareLicense.rtf"
  if [ -f "$AppleInstallManual" ]; then
    MacOSprettyName=$(awk '/SOFTWARE LICENSE AGREEMENT FOR macOS/' "$AppleInstallManual" | awk -F 'macOS ' '{print $NF}' | awk '{print substr($0, 0, length($0)-1)}')
    OS_NAME="$osx_product_name $MacOSprettyName"
  fi
else
  echo "Dotfiles OS_NAME: Wasn't able to id OS name"
fi
export OS_NAME;
export OS_VERSION;

OS_STRING="$OS_FAMILY - $OS_NAME $OS_VERSION - $OS_ARCH";
export OS_STRING;
echo "$OS_STRING";
