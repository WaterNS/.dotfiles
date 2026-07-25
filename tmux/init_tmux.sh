#!/bin/sh

HOMEREPO=${HOMEREPO:-"$HOME/.dotfiles"}

# shellcheck disable=SC2154 # $ri/$u sourced from upstream script
if [ "$r" = true ]; then
  echo "  ReInitializing TMUX components:";
  if [ -d "$HOMEREPO/opt/tmux" ]; then rm -rf "$HOMEREPO/opt/tmux"; fi
elif [ "$u" = true ]; then
	echo "  UPDATING TMUX components";
else
  echo "Initializing TMUX components";
fi

#TMUX Plugin Loader: TPM
tpmPath="$HOMEREPO/opt/tmux/plugins/tpm"
if [ ! -f "$tpmPath/bin/install_plugins" ]; then
  if [ -d "$tpmPath" ]; then
    echo "TMUX installer: removing an incomplete TPM checkout at $tpmPath"
    if ! rm -rf "$tpmPath"; then
      unset tpmPath
      return 1
    fi
  fi
  if ! githubCloneByCurl https://github.com/tmux-plugins/tpm "$tpmPath"; then
    unset tpmPath
    return 1
  fi
# elif [ "$u" = true ]; then updateGitRepo "TMUX TPM" "TMUX Plugin Manager" ~/.dotfiles/opt/tmux/plugins/tpm;
fi

if [ ! -f "$tpmPath/bin/install_plugins" ]; then
  echo "TMUX installer: TPM's install_plugins script is missing." >&2
  unset tpmPath
  return 1
fi

if ! bash "$tpmPath/bin/install_plugins"; then
  echo "TMUX installer: TPM could not install the configured plugins." >&2
  unset tpmPath
  return 1
fi
echo ""

if [ "$u" = true ]; then
  if [ -f "$tpmPath/bin/update_plugins" ]; then
    if ! bash "$tpmPath/bin/clean_plugins"; then
      unset tpmPath
      return 1
    fi
    if ! bash "$tpmPath/bin/update_plugins" all; then
      unset tpmPath
      return 1
    fi
  else
    echo "TMUX Updater: Couldn't find: $tpmPath/bin/update_plugins"
  fi
fi

if [ "$r" = true ]; then
  echo "  Finished ReInitializing TMUX components!";
elif [ "$u" = true  ]; then
	echo ""
	echo "  Finished UPDATING TMUX components!";
else
	echo "  ++ Finished initializing TMUX components! ++";
fi
unset tpmPath
