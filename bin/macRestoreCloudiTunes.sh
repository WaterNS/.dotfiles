#!/bin/bash

# macRestoreCloudiTunes.sh

# This script will migrate/restore your AppleTV and AppleMusic library database to/from Cloud file storage
# but keep your media storage still local/not cloud synced. Basic principle is symlinks.
# This should let you retain/restore local/smart playlists [and potentially preferences].

# It uses iCloud by default, but can likely work with other providers

if [ ! "$OS_FAMILY" = "Darwin" ]; then
  echo "Not Darwin-based OS, exiting"
  exit 1
fi

CLOUDDIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/.CustomiTunesSync"
baseTVDIR="$HOME/Movies/TV"
baseMusicDIR="$HOME/Music/Music"

printf "Do you want use Cloud Sync for Apple TV? [Y/n]: " >&2
read -r optionAppleTV

echo ""
printf "Do you want use Cloud Sync for Apple Music? [Y/n]: " >&2
read -r optionAppleMusic

function arrayContains {
  local e match="$1"
  shift
  for e; do [[ "$e" == "$match" ]] && return 0; done
  return 1
}

# Function to check if an item has been processed
function isProcessed {
  local folder_name=$1
  for folder in "${processed_folders_list[@]}"; do
    if [[ "$folder" == "$folder_name" ]]; then
      return 0
    fi
  done
  return 1
}

function MigrateItunes {
  declare -a processed_folders_list=() # Array to track which known folders have been processed
  declare -a known_folders=( # Known Folders
    "Media"
    "Media.localized"
    "Previous Libraries"
    "Previous Libraries.localized"
    "TV Library.tvlibrary"
    "Music Library.musiclibrary"
  )
  declare -a known_files=() # Known Files
  declare -a ignored_items=(".DS_Store") # Ignored files and folders

  echo "--------------------"
  echo "- Running check on -"
  echo "    *  $libNick  *"
  echo "--------------------"

  if [ ! -L "$localBaseDIR" ] && [ -d "$localBaseDIR" ] && [ -d "$cloudBaseDIR" ]; then
    echo "ERROR: Both local and cloud copies appear to exist. Remove/Backup one and try again"
    echo "  Local: $localBaseDIR"
    echo "  Cloud: $cloudBaseDIR"

    echo ""
    printf "Do you want to overwrite existing library and use cloud version? [Y/n]: " >&2
    read -r overwriteLocal

    if [ "$overwriteLocal" == 'Y' ]; then
      if [ -f "$localBaseDIRlib" ]; then
        trashOSX "$localBaseDIRlib" || exit 1
      fi
    else
      exit 1
    fi
  fi

  if [ ! -e "$localBaseDIR" ] && [ -d "$cloudBaseDIR" ]; then
    echo "WARNING: Local [$localBaseDIR] doesn't appear to exist, attempting to create and link existing found Library from Cloud"
    mkdir "$localBaseDIR" || echo "Failed?  -- Should exit"
  fi

  if [ -e "$localBaseDIR" ]; then
    if [ ! -L "$localBaseDIR" ]; then
      echo "Found existing, non-linked, $libNick folder: $localBaseDIR"
      echo "  Renaming to ~/Movies/$libNick-Local"
      mv "$localBaseDIR" "$localBaseDIR-Local"
      echo "  Linking [$localBaseDIR] to cloud synced [$cloudBaseDIR]"
      [ ! -r "$localBaseDIR" ] && ln -s "$cloudBaseDIR" "$localBaseDIR" && echo "  Linked $localBaseDIR -> $cloudBaseDIR"
      echo ""
    fi

    if [ -L "$localBaseDIR" ] && [ ! "$(readlink "$localBaseDIR")" = "$cloudBaseDIR" ]; then
      echo "WARNING: Found incorrect SYMBOLIC Link [$localBaseDIR => $(readlink "$localBaseDIR")], removing..."
      rm "$localBaseDIR"
      [ ! -r "$localBaseDIR" ] && ln -s "$cloudBaseDIR" "$localBaseDIR" && echo "  Linked $localBaseDIR -> $cloudBaseDIR"
    fi

  fi

  # Map the subfolders and folders to their respective locations
  if [ -d "$localBaseDIR-Local" ]; then
    search_dir="$localBaseDIR-Local" # Directory to search

    # Read the directory contents
    while IFS= read -r item; do
      item_name=$(basename "$item")

      # Skip processing if the item is in the ignored list
      if arrayContains "$item_name" "${ignored_items[@]}"; then
        continue
      fi

      if [[ -d "$item" ]]; then
        if arrayContains "$item_name" "${known_folders[@]}"; then
          if ! isProcessed "$item_name"; then
            echo "Found folder: $item_name"
            processed_folders_list+=("$item_name")
            if [ "$item_name" == "TV Library.tvlibrary" ] ||
                  [ "$item_name" == "Music Library.musiclibrary" ] ||
                  [[ "$item_name" == "Previous Libraries"* ]]; then
              echo "  Moving $item_name to $cloudBaseDIR/$item_name"
              mv "$item" "$cloudBaseDIR/$item_name"
            else
              [ ! -r "$cloudBaseDIR/$item_name" ] && ln -s "$item" "$cloudBaseDIR/$item_name" && echo "  Linked $cloudBaseDIR/$item_name -> $item"
            fi
            echo ""
          fi
        else
          echo "  !!!  WARNING::: Found unknown folder: $item"
          echo ""
        fi
      elif [[ -f "$item" ]]; then
        if arrayContains "$item_name" "${known_files[@]}"; then
          echo "Found file: $item_name"
        else
          echo "  !!!  WARNING::: Found unknown file: $item"
        fi
        echo ""
      else
        echo "  !!!  WARNING::: Found unknown file/folder: $item"
        echo ""
      fi
    done < <(find "$search_dir" -mindepth 1 -maxdepth 1)

    # Cleanup variables
    unset known_folders known_files processed_folders_list ignored_items
  else
    echo "ERROR: Didn't find $localBaseDIR-Local" && exit 1
  fi
}

# Create iCloud CustomiTunesSync directories if don't exist
if [ "$optionAppleTV" == 'Y' ] || [ "$optionAppleMusic" == 'Y' ];then
  if [ -d "$HOME/Library/Mobile Documents/com~apple~CloudDocs" ]; then
    if [ ! -d "$CLOUDDIR" ]; then
      echo "NOTE: $CLOUDDIR not found, creating!"
      mkdir "$CLOUDDIR" || exit 1
    fi
    if [ "$optionAppleTV" == 'Y' ] && [ ! -d "$CLOUDDIR/AppleTV" ]; then
      echo "NOTE: $CLOUDDIR/AppleTV not found, creating!"
      mkdir "$CLOUDDIR/AppleTV" || exit 1
    fi
    if [ "$optionAppleMusic" == 'Y' ] && [ ! -d "$CLOUDDIR/AppleMusic" ]; then
      echo "NOTE: $CLOUDDIR/AppleMusic not found, creating!"
      mkdir "$CLOUDDIR/AppleMusic" || exit 1
    fi
  else
    echo "ERROR: Didn't find icloud folder, exiting [$HOME/Library/Mobile Documents/com~apple~CloudDocs/]"
    exit 1
  fi
fi

#
# Migrate/Restore AppleTV Library
#
if [ "$optionAppleTV" == 'Y' ]; then
  osascript -e 'quit app "TV"' && pkill -x TV
  libNick="TV"
  cloudBaseDIR="$CLOUDDIR/AppleTV"
  localBaseDIR=$baseTVDIR
  localBaseDIRlib="$localBaseDIR/TV Library.tvlibrary"
  MigrateItunes
fi

#
# Migrate/Restore AppleMusic Library
#
if [ "$optionAppleMusic" == 'Y' ]; then
  osascript -e 'quit app "Music"' && pkill -x Music
  libNick="Music"
  cloudBaseDIR="$CLOUDDIR/AppleMusic"
  localBaseDIR=$baseMusicDIR
  localBaseDIRlib="$localBaseDIR/Music Library.musiclibrary"
  MigrateItunes
fi
