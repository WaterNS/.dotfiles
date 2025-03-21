#!/bin/sh

if [ -f ~/.dotfiles/posixshells/posix_functions.sh ]; then
  . ~/.dotfiles/posixshells/posix_functions.sh
fi

# Clean up any broken symlinks pointing to dotfiles
# Ref: https://unix.stackexchange.com/a/103011
# POSIX way to loop through array where objects are not expected to have newlines (so newline is safe IFS)
brokensymlinks=$(find "$HOME" -maxdepth 1 -type l -exec test ! -e {} \; -print)
set -f; IFS='
'                           # turn off variable value expansion except for splitting at newlines
for file in $brokensymlinks; do
  set +f; unset IFS

  if contains "$(readlink "$file")" "$HOME/.dotfiles/";then
    printf "Found broken symlink (%s) to dotfiles, removing...\n" "$file"
    rm "$file"
  fi
done
set +f; unset IFS           # do it again in case $INPUT was empty
unset brokensymlinks


# Ref: https://unix.stackexchange.com/a/103011
# POSIX way to loop through array where objects are not expected to have newlines (so newline is safe IFS)
files=$(find "$HOME/.dotfiles" -type f -name '.*' -not -path "*/opt/*")
excludedfiles=".editorconfig .gitignore .gitattributes .DS_Store"
set -f; IFS='
'                           # turn off variable value expansion except for splitting at newlines
for dotfile in $files; do
  set +f; unset IFS

  if notcontains "$excludedfiles" "$(basename "$dotfile")"; then
    target=$HOME/$(basename "$dotfile")

    if [ -f "$target" ] && [ ! -L "$target" ]; then
      if contains "$(cat "$target")" "amazon-q"; then
        echo "NOTE: AWS CLOUDSHELL Found existing $(basename "$dotfile") in HOME, renaming..."
        mv "$target" "$target.awscloudshell"
      else
        echo "NOTE: Found existing $(basename "$dotfile") in HOME, renaming..."
        mv "$target" "$target.$(date -u +"%Y-%m-%d")"
      fi
    elif [ -L "$target" ] && [ ! "$(readlink "$target")" = "$dotfile" ]; then
      echo "NOTE: Found SYMBOLIC Link with incorrect path $(basename "$dotfile") in HOME, removing..."
      rm "$target"
    fi

    [ ! -r "$target" ] && ln -s "$dotfile" "$target" && echo "NOTE: Linked ~/$(basename "$dotfile") to custom one in dotfiles repo"
    unset target
  fi
done
set +f; unset IFS           # do it again in case $INPUT was empty
unset files

#Handle linking VSCode in OSX and Linux
if [ "$OS_FAMILY" = "Darwin" ] || [ "$OS_FAMILY" = "Linux" ]; then
  repoVSCodeFile="$HOME/.dotfiles/vscode/settings.json"

  vsCodeDirs=""
  customIFS=":"

  if [ "$OS_FAMILY" = "Darwin" ]; then
    vsCodeDirs="$HOME/Library/Application Support/Code/User/"
    vsCodeDirs="${vsCodeDirs}${customIFS}$HOME/Library/Application Support/Code - Insiders/User/"
  elif [ "$OS_FAMILY" = "Linux" ]; then
    vsCodeDirs="$HOME/.config/Code/User/"
    vsCodeDirs="${vsCodeDirs}${customIFS}$HOME/.config/Code - Insiders/User/"
  fi

  IFS=$customIFS
  for codeDir in $vsCodeDirs; do
    settingsFile="${codeDir}settings.json"

    # Create VScode profile folder if doesn't exist
    if [ ! -d "$codeDir" ]; then
      mkdir -p "$codeDir"
    fi

    # Remove existing VScode file (if its not a linked one)
    if [ -f "$settingsFile" ] && [ ! -L "$settingsFile" ]; then
      echo "Found existing VScode file at $settingsFile, removing..."
      rm "$settingsFile"
    elif [ -L "$settingsFile" ] && [ ! "$(readlink "$settingsFile")" = "$repoVSCodeFile" ]; then
      echo "NOTE: Found existing LINK for VSCode file but with incorrect path, removing..."
      rm "$settingsFile"
    fi

    [ ! -r "$settingsFile" ] && ln -s "$repoVSCodeFile" "$settingsFile" && echo "NOTE: Linked $settingsFile to custom one at $repoVSCodeFile"
  done
  unset IFS;
  unset customIFS;

fi
