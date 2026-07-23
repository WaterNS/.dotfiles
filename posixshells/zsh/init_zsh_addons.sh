#!/bin/sh

if [ -z "${HOMEREPO:-}" ]; then
  case "${TERM_PROGRAM:-}:${APPNAME:-}" in
    a-Shell:*|*:a-Shell|*:a-Shell-mini|*:a-Shell-*) HOMEREPO="$HOME/Documents/.dotfiles" ;;
    *) HOMEREPO="$HOME/.dotfiles" ;;
  esac
fi
export HOMEREPO

if [ -f "$HOMEREPO/posixshells/posix_id_os.sh" ]; then
  . "$HOMEREPO/posixshells/posix_id_os.sh"
fi

if [ "${IS_ASHELL:-}" = true ] || [ "${IS_ISH:-}" = true ]; then
  echo "NOTE: skipping Zsh add-ons on ${OS_PLATFORM:-this mobile host}."
  # shellcheck disable=SC2317 # exit is the fallback when this file is executed rather than sourced
  return 0 2>/dev/null || exit 0
fi

if [ -f "$HOMEREPO/posixshells/posix_functions.sh" ]; then
  . "$HOMEREPO/posixshells/posix_functions.sh"
fi

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
  githubCloneByCurl https://github.com/romkatv/powerlevel10k ~/.dotfiles/opt/ohmyzsh-custom/themes/powerlevel10k;
  echo ""
elif [ "$u" = true  ]; then updateGitRepo "Powerlevel10k" "OhMyZSH theme" ~/.dotfiles/opt/ohmyzsh-custom/themes/powerlevel10k;
fi

#ZSH extra: Auto Suggestions
if [ ! -d "$HOME/.dotfiles/opt/zsh-extras/zsh-autosuggestions" ]; then
	# git clone https://github.com/zsh-users/zsh-autosuggestions ~/.dotfiles/opt/zsh-extras/zsh-autosuggestions;
  githubCloneByCurl https://github.com/zsh-users/zsh-autosuggestions ~/.dotfiles/opt/zsh-extras/zsh-autosuggestions;
  echo ""
elif [ "$u" = true  ]; then updateGitRepo "ZSH Auto Suggestions" "ZSH extra" ~/.dotfiles/opt/zsh-extras/zsh-autosuggestions;
fi

#ZSH extra: Syntax Highlighting
if [ ! -d "$HOME/.dotfiles/opt/zsh-extras/zsh-syntax-highlighting" ]; then
	# git clone https://github.com/zsh-users/zsh-syntax-highlighting ~/.dotfiles/opt/zsh-extras/zsh-syntax-highlighting;
  githubCloneByCurl https://github.com/zsh-users/zsh-syntax-highlighting ~/.dotfiles/opt/zsh-extras/zsh-syntax-highlighting;
  echo ""
elif [ "$u" = true  ]; then updateGitRepo "ZSH Syntax Highlighting" "ZSH extra" ~/.dotfiles/opt/zsh-extras/zsh-syntax-highlighting;
fi

#ZSH extra: zsh-nvm -- helper for Node Version Manager
if [ ! -d "$HOME/.dotfiles/opt/zsh-extras/zsh-nvm" ]; then
	# git clone https://github.com/lukechilds/zsh-nvm ~/.dotfiles/opt/zsh-extras/zsh-nvm;
  githubCloneByCurl https://github.com/lukechilds/zsh-nvm ~/.dotfiles/opt/zsh-extras/zsh-nvm;
  echo ""
elif [ "$u" = true  ]; then updateGitRepo "ZSH Syntax Highlighting" "ZSH extra" ~/.dotfiles/opt/zsh-extras/zsh-nvm;
fi

#ZSH extra: zsh-better-npm-completion
if [ ! -d "$HOME/.dotfiles/opt/zsh-extras/zsh-better-npm-completion" ]; then
	# git clone https://github.com/lukechilds/zsh-better-npm-completion ~/.dotfiles/opt/zsh-extras/zsh-better-npm-completion;
  githubCloneByCurl https://github.com/lukechilds/zsh-better-npm-completion ~/.dotfiles/opt/zsh-extras/zsh-better-npm-completion;
  echo ""
elif [ "$u" = true  ]; then updateGitRepo "ZSH Syntax Highlighting" "ZSH extra" ~/.dotfiles/opt/zsh-extras/zsh-better-npm-completion;
fi


if [ "$r" = true ]; then
  echo "  Finished ReInitializing ZSH addons!";
elif [ "$u" = true  ]; then
	echo ""
	echo "  Finished UPDATING ZSH addons!";
fi
