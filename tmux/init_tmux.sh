#!/bin/sh

# shellcheck disable=SC2154 # $ri/$u sourced from upstream script
if [ "$r" = true ]; then
  echo "  ReInitializing TMUX components:";
  if [ -d "$HOME/.dotfiles/opt/tmux" ]; then rm -rf "$HOME/.dotfiles/opt/tmux"; fi
elif [ "$u" = true ]; then
	echo "  UPDATING TMUX components";
else
  echo "Initializing TMUX components";
fi

#TMUX Plugin Loader: TPM
if [ ! -d "$HOME/.dotfiles/opt/tmux/plugins/tpm" ]; then
  githubCloneByCurl https://github.com/tmux-plugins/tpm ~/.dotfiles/opt/tmux/plugins/tpm &&
      ~/.dotfiles/opt/tmux/plugins/tpm/bin/install_plugins; echo ""
# elif [ "$u" = true ]; then updateGitRepo "TMUX TPM" "TMUX Plugin Manager" ~/.dotfiles/opt/tmux/plugins/tpm;
fi

if [ "$u" = true ]; then
  if [ -f "$HOME/.dotfiles/opt/tmux/plugins/tpm/bin/update_plugins" ]; then
    "$HOME/.dotfiles/opt/tmux/plugins/tpm/bin/clean_plugins"
    "$HOME/.dotfiles/opt/tmux/plugins/tpm/bin/update_plugins" all
  else
    echo "TMUX Updater: Couldn't find: $HOME/.dotfiles/opt/tmux/plugins/tpm/bin/update_plugins"
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
