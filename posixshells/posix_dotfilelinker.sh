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
files=$(find "$HOME/.dotfiles" -type f -name '.*')
excludedfiles=".editorconfig .gitignore .gitattributes .DS_Store"
set -f; IFS='
'                           # turn off variable value expansion except for splitting at newlines
for dotfile in $files; do
  set +f; unset IFS

  if notcontains "$excludedfiles" "$(basename "$dotfile")";then
    target=$HOME/$(basename "$dotfile")

    if [ -f "$target" ] && [ ! -L "$target" ]; then
      echo "NOTE: Found existing $(basename "$dotfile") in HOME, renaming..."
      mv "$target" "$target.$(date -u +"%Y-%m-%d")"
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
if contains "$(uname)" "Darwin" || contains "$(uname)" "linux"; then

  repovscodefile="$HOME/.dotfiles/vscode/settings.json"

  if contains "$(uname)" "Darwin"; then
    vscodedir="$HOME/Library/Application Support/Code/User/"
    vscodefile="$HOME/Library/Application Support/Code/User/settings.json"
  elif contains "$(uname)" "linux"; then
    vscodedir="$HOME/.config/Code/User/"
    vscodefile="$HOME/.config/Code/User/settings.json"
  fi

  # Create VScode profile folder if doesn't exist
  if [ ! -d "$vscodedir" ]; then
    mkdir -p "$vscodedir"
  fi

  # Remove existing VScode file (if its not a linked one)
  if [ -f "$vscodefile" ] && [ ! -L "$vscodefile" ]; then
    echo "Found existing VScode file at $vscodefile, removing..."
    rm "$vscodefile"
  elif [ -L "$vscodefile" ] && [ ! "$(readlink "$vscodefile")" = "$repovscodefile" ]; then
    echo "NOTE: Found existing LINK for VSCode file but with incorrect path, removing..."
    rm "$vscodefile"
  fi

  [ ! -r "$vscodefile" ] && ln -s "$repovscodefile" "$vscodefile" && echo "NOTE: Linked $vscodefile to custom one at $repovscodefile"
fi