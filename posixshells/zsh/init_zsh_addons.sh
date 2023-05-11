#!/bin/sh

# shellcheck disable=SC2154 # $ri/$u sourced from upstream script
if [ "$r" = true ]; then
  echo "  ReInitializing ZSH addons:";
  if [ -d "$HOME/.dotfiles/opt/ohmyzsh-custom" ]; then rm -rf "$HOME/.dotfiles/opt/ohmyzsh-custom"; fi
  if [ -d "$HOME/.dotfiles/opt/zsh-extras" ]; then rm -rf "$HOME/.dotfiles/opt/zsh-extras"; fi
elif [ "$u" = true ]; then
	echo "  UPDATING ZSH addons";
fi

#ZSH theme: powerlevel10k
if [ ! -d "$HOME/.dotfiles/opt/ohmyzsh-custom/themes/powerlevel10k" ]; then
	# git clone https://github.com/romkatv/powerlevel10k ~/.dotfiles/opt/ohmyzsh-custom/themes/powerlevel10k;
  githubCloneByCurl https://github.com/romkatv/powerlevel10k ~/.dotfiles/opt/ohmyzsh-custom/themes/powerlevel10k --depth 1;
  echo ""
elif [ "$u" = true  ]; then updategitrepo "Powerlevel10k" "OhMyZSH theme" ~/.dotfiles/opt/ohmyzsh-custom/themes/powerlevel10k;
fi

#ZSH extra: Auto Suggestions
if [ ! -d "$HOME/.dotfiles/opt/zsh-extras/zsh-autosuggestions" ]; then
	# git clone https://github.com/zsh-users/zsh-autosuggestions ~/.dotfiles/opt/zsh-extras/zsh-autosuggestions;
  githubCloneByCurl https://github.com/zsh-users/zsh-autosuggestions ~/.dotfiles/opt/zsh-extras/zsh-autosuggestions --depth 1;
  echo ""
elif [ "$u" = true  ]; then updategitrepo "ZSH Auto Suggestions" "ZSH extra" ~/.dotfiles/opt/zsh-extras/zsh-autosuggestions;
fi

#ZSH extra: Syntax Highlighting
if [ ! -d "$HOME/.dotfiles/opt/zsh-extras/zsh-syntax-highlighting" ]; then
	# git clone https://github.com/zsh-users/zsh-syntax-highlighting ~/.dotfiles/opt/zsh-extras/zsh-syntax-highlighting;
  githubCloneByCurl https://github.com/zsh-users/zsh-syntax-highlighting ~/.dotfiles/opt/zsh-extras/zsh-syntax-highlighting --depth 1;
  echo ""
elif [ "$u" = true  ]; then updategitrepo "ZSH Syntax Highlighting" "ZSH extra" ~/.dotfiles/opt/zsh-extras/zsh-syntax-highlighting;
fi


if [ "$r" = true ]; then
  echo "  Finished ReInitializing ZSH addons!";
elif [ "$u" = true  ]; then
	echo ""
	echo "  Finished UPDATING ZSH addons!";
fi
