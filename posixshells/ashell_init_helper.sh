#!/bin/sh

# a-Shell's prompt is ios_system, not a persistent POSIX shell. This helper is
# sourced into one bundled Dash session, while the installed startup files remain
# deliberately flat so a-Shell can execute them one line at a time.

if [ -n "${HOMEREPO:-}" ]; then
  HOMEREPO=$(CDPATH='' cd -- "$HOMEREPO" || exit 1; pwd -P)
  SCRIPT_DIR=$HOMEREPO/posixshells
else
  SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" || exit 1; pwd -P)
  HOMEREPO=$(CDPATH='' cd -- "$SCRIPT_DIR/.." || exit 1; pwd -P)
fi
export HOMEREPO

. "$HOMEREPO/posixshells/posix_id_os.sh"

if [ "${IS_ASHELL:-}" != true ]; then
  echo 'ashell_init_helper.sh must be run from a-Shell.' >&2
  exit 1
fi

ASHELL_EXPECTED_REPO_LOGICAL="$HOME/Documents/.dotfiles"
if [ -d "$ASHELL_EXPECTED_REPO_LOGICAL" ]; then
  ASHELL_EXPECTED_REPO=$(CDPATH='' cd -- "$ASHELL_EXPECTED_REPO_LOGICAL" || exit 1; pwd -P)
else
  ASHELL_EXPECTED_REPO=$ASHELL_EXPECTED_REPO_LOGICAL
fi
if [ "$HOMEREPO" != "$ASHELL_EXPECTED_REPO" ]; then
  echo "a-Shell requires this repository at $ASHELL_EXPECTED_REPO_LOGICAL." >&2
  echo "Current repository path: $HOMEREPO" >&2
  exit 1
fi

. "$HOMEREPO/posixshells/posix_functions.sh"
. "$HOMEREPO/posixshells/posix_installers.sh"

ashell_update_arg=''
while getopts ':ur' opt; do
  case "$opt" in
    u|r) ashell_update_arg='--update' ;;
    *) ;;
  esac
done

ASHELL_DOCUMENTS="$HOME/Documents"
ASHELL_BIN="$ASHELL_DOCUMENTS/bin"
mkdir -p "$ASHELL_BIN" "$HOMEREPO/opt/bin" "$HOMEREPO/opt/tmp" || exit 1

ashell_backup_stamp=$(date -u '+%Y%m%dT%H%M%SZ')

link_ashell_file() {
  ashell_source=$1
  ashell_target=$2

  if [ ! -f "$ashell_source" ]; then
    echo "Missing a-Shell setup source: $ashell_source" >&2
    unset ashell_source ashell_target
    return 1
  fi

  if [ -L "$ashell_target" ] && [ "$(readlink "$ashell_target" 2>/dev/null)" = "$ashell_source" ]; then
    unset ashell_source ashell_target
    return 0
  fi

  ashell_temp="$ashell_target.dotfiles-new.$$"
  ashell_counter=0
  while [ -e "$ashell_temp" ] || [ -L "$ashell_temp" ]; do
    ashell_counter=$((ashell_counter + 1))
    ashell_temp="$ashell_target.dotfiles-new.$$.$ashell_counter"
  done
  ln -s "$ashell_source" "$ashell_temp" || return 1

  ashell_backup=''
  if [ -e "$ashell_target" ] || [ -L "$ashell_target" ]; then
    ashell_backup="$ashell_target.dotfiles-backup-$ashell_backup_stamp"
    ashell_counter=0
    while [ -e "$ashell_backup" ] || [ -L "$ashell_backup" ]; do
      ashell_counter=$((ashell_counter + 1))
      ashell_backup="$ashell_target.dotfiles-backup-$ashell_backup_stamp.$ashell_counter"
    done
    echo "NOTE: Preserving existing $ashell_target as $ashell_backup"
    if ! mv "$ashell_target" "$ashell_backup"; then
      rm -f "$ashell_temp"
      unset ashell_backup ashell_counter ashell_source ashell_target ashell_temp
      return 1
    fi
  fi

  if ! mv "$ashell_temp" "$ashell_target"; then
    rm -f "$ashell_temp"
    if [ -n "$ashell_backup" ] && [ ! -e "$ashell_target" ] && [ ! -L "$ashell_target" ]; then
      mv "$ashell_backup" "$ashell_target" || echo "ERROR: Restore $ashell_backup to $ashell_target manually." >&2
    fi
    unset ashell_backup ashell_counter ashell_source ashell_target ashell_temp
    return 1
  fi

  echo "NOTE: Linked $ashell_target to $ashell_source"
  unset ashell_backup ashell_counter ashell_source ashell_target ashell_temp
}

# a-Shell loads both files from Documents and evaluates each non-comment line
# independently. Never link the generic multiline POSIX/Bash startup files here.
link_ashell_file "$HOMEREPO/posixshells/ashell_profile" "$ASHELL_DOCUMENTS/.profile" || exit 1
link_ashell_file "$HOMEREPO/posixshells/ashell_bashrc" "$ASHELL_DOCUMENTS/.bashrc" || exit 1

# Remove obsolete repository files left behind by archive-overlaid updates.
for legacy_ytdlp_file in \
  "$HOMEREPO/bin/ytdl-hq" \
  "$HOMEREPO/bin/ytdl-hq-mp4" \
  "$HOMEREPO/bin/ytdl-mp3" \
  "$HOMEREPO/bin/youtube-dlp" \
  "$HOMEREPO/posixshells/ytdlp_wrapper.sh"
do
  if [ -e "$legacy_ytdlp_file" ] || [ -L "$legacy_ytdlp_file" ]; then
    echo "NOTE: Removing obsolete yt-dlp helper $legacy_ytdlp_file"
    rm -f "$legacy_ytdlp_file" || exit 1
  fi
done
unset legacy_ytdlp_file

# Remove only links created by the previous multi-launcher setup. Preserve
# regular files and links owned by the user.
for legacy_ytdlp_name in ytdl-hq ytdl-hq-mp4 ytdl-mp3 youtube-dlp; do
  legacy_ytdlp_link="$ASHELL_BIN/$legacy_ytdlp_name"
  legacy_ytdlp_source="$HOMEREPO/bin/$legacy_ytdlp_name"
  if [ -L "$legacy_ytdlp_link" ] &&
     [ "$(readlink "$legacy_ytdlp_link" 2>/dev/null)" = "$legacy_ytdlp_source" ]; then
    echo "NOTE: Removing obsolete a-Shell link $legacy_ytdlp_link"
    rm -f "$legacy_ytdlp_link" || exit 1
  fi
done
unset legacy_ytdlp_link legacy_ytdlp_name legacy_ytdlp_source

chmod a+rx "$HOMEREPO/bin/ytdl" || exit 1
link_ashell_file "$HOMEREPO/bin/ytdl" "$ASHELL_BIN/ytdl" || exit 1

# rg and which are small, useful a-Shell packages used by this toolbelt. The
# yt-dlp installer adds qjs for JavaScript challenges.
install_generic_ashell rg rg ||
  echo 'WARNING: rg installation failed; ripgrep shortcuts will be unavailable.' >&2
install_generic_ashell which which ||
  echo 'WARNING: which installation failed; command-location helpers will be limited.' >&2

if [ -n "$ashell_update_arg" ]; then
  install_ytdlp "$ashell_update_arg" || exit 1
else
  install_ytdlp || exit 1
fi

echo ''
echo 'a-Shell setup completed. Open a new a-Shell window to load the profile.'
echo 'For Apple Shortcuts that use yt-dlp, Python, or FFmpeg, select Run in App.'

unset ashell_update_arg ashell_backup_stamp ASHELL_BIN ASHELL_DOCUMENTS ASHELL_EXPECTED_REPO ASHELL_EXPECTED_REPO_LOGICAL SCRIPT_DIR
