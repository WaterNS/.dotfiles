#!/bin/sh

#Identify running shell
RUNNINGSHELLVERSION=$($SHELL --version);
if [ -n "$ZSH_VERSION" ]; then
  export RUNNINGSHELL='zsh'
  RUNNINGSHELLVERSION=$ZSH_VERSION
elif [ -n "$BASH_VERSION" ]; then
  export RUNNINGSHELL='bash'
  RUNNINGSHELLVERSION=$BASH_VERSION
else
  if contains "$SHELL" "/sh"; then
    export RUNNINGSHELL='sh'
  else
    export RUNNINGSHELL=$SHELL
  fi
fi
export RUNNINGSHELLVERSION;

### History Stuffs
. "$HOME/.dotfiles/posixshells/posix_history.sh"

# VIM: Create backup, swap, and undo folders if don't exist
if [ ! -d ~/.vim/backups ]; then mkdir -p ~/.vim/backups; fi
if [ ! -d ~/.vim/swaps ]; then mkdir -p ~/.vim/swaps; fi
if [ ! -d ~/.vim/undo ]; then mkdir -p ~/.vim/undo; fi

# PATH: Include .dotfiles bin
PATH=$PATH:~/.dotfiles/opt/bin

############################################
# INCLUDES
############################################
if [ -f ~/.dotfiles/posixshells/posix_functions.sh ]; then
  . ~/.dotfiles/posixshells/posix_functions.sh
fi

if [ -f ~/.dotfiles/posixshells/posix_aliases.sh ]; then
  . ~/.dotfiles/posixshells/posix_aliases.sh
fi

if [ -f ~/.dotfiles/posixshells/posix_installers.sh ]; then
	. ~/.dotfiles/posixshells/posix_installers.sh
fi

if [ -f ~/.dotfiles/posixshells/posix_prompt ]; then
	if [ "$RUNNINGSHELL" = "zsh" ]; then
    if [ ! -d ~/.dotfiles/opt/ohmyzsh ]; then
      . ~/.dotfiles/posixshells/posix_prompt # load posix_prompt only if OhMyZsh not installed.
    fi
  else
    . ~/.dotfiles/posixshells/posix_prompt
  fi
fi

#######################################
# EXPORTING vars that config settings #
#######################################
# Set default editors
export GIT_EDITOR=vim
export VISUAL=vim
export EDITOR=vim

# Use lesspipe for binaries
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

    ############################
    ## Exporting GIT settings ##
    ############################

    # GIT PAGER and LESS settings
    # Use diff-so-fancy (if available)
    if [ -x "$(command -v diff-so-fancy)" ]; then
      # Set Git Pager and LESS settings for session
      export GIT_PAGER='diff-so-fancy | less'
      export LESS="-x2 -RFX $LESS"

      # Include diff-so-fancy colors
      #shellcheck disable=2088 # Exception: Want to explictly write the tidle to config
      git config --global include.path '~/.dotfiles/git/git_diffsofancy'
    else # Set to use LESS as fallback and undo gitconfig change
      export GIT_PAGER='less'
      export LESS="-x2 -RFX $LESS"
      #shellcheck disable=2088 # Exception: Want to explictly write the tidle to config
      git config --global --unset include.path '~/.dotfiles/git/git_diffsofancy'
    fi

    # Set GIT Config Settings
    if [ -x "$(command -v git)" ]; then
      #shellcheck disable=2088 # Exception: Want to explictly write the tidle to config
      git config --global include.path '~/.dotfiles/git/git_tweaks'
    fi

#########################
# Run some shell tweaks #
#########################
  # Fix SSH permissions
  fixsshperms

  # Set path when running on OSX and from Terminal window
  if contains "$(uname)" "Darwin"; then
    if DidTerminalCallShell; then
      if [ -d "$HOME/Desktop" ]; then
        cd ~/Desktop || exit
      fi
    fi
  fi


## Update, if needed
. ~/.dotfiles/posixshells/dotfiles_updater.sh