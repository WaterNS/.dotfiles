#!/bin/sh

# Identify Operating System (better uname)
. ~/.dotfiles/posixshells/posix_id_os.sh
echo "$OS_STRING";

#Identify running shell
. ~/.dotfiles/posixshells/posix_id_shell.sh

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
  . ~/.dotfiles/posixshells/posix_prompt
fi

# Get color support for 'less', man, etc
if [ -f ~/.dotfiles/posixshells/less/termcap ]; then
  . ~/.dotfiles/posixshells/less/termcap
  export LESS="$LESS --RAW-CONTROL-CHARS"
fi

#######################################
# EXPORTING vars that config settings #
#######################################
# Set default editors
export GIT_EDITOR=vim
export VISUAL=vim
export EDITOR=vim

# Enable highlight's integration with LESS (if available)
[ -x "$(command -v highlight)" ] && export LESSOPEN="| highlight %s --out-format xterm256 --force"

# Use lesspipe for binaries
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

    ############################
    ## Exporting GIT settings ##
    ############################

    # Set GIT Config Settings
    if [ -x "$(command -v git)" ]; then
      git config --global --unset-all include.path
      #shellcheck disable=2088 # Exception: Want to explictly write the tidle to config
      git config --global --add include.path '~/.dotfiles/git/git_tweaks'
    fi

    # GIT PAGER and LESS settings
    # Use diff-so-fancy (if available)
    if [ -x "$(command -v delta)" ]; then
      export GIT_PAGER='delta'
      #shellcheck disable=2088 # Exception: Want to explictly write the tidle to config
      git config --global --add include.path '~/.dotfiles/git/git_deltadiff'
    elif [ -x "$(command -v diff-so-fancy)" ]; then
      # Set Git Pager and LESS settings for session
      export GIT_PAGER='diff-so-fancy | less'
      export LESS="-x2 -RFX $LESS"

      # Include diff-so-fancy colors
      #shellcheck disable=2088 # Exception: Want to explictly write the tidle to config
      git config --global --add include.path '~/.dotfiles/git/git_diffsofancy'
    else # Set to use LESS as fallback and undo gitconfig change
      export GIT_PAGER='less'
      export LESS="-x2 -RFX $LESS"

      #shellcheck disable=2088 # Exception: Want to explictly write the tidle to config
      git config --global --unset-all include.path '~/.dotfiles/git/git_diffsofancy'
      #shellcheck disable=2088 # Exception: Want to explictly write the tidle to config
      git config --global --unset-all include.path '~/.dotfiles/git/git_deltadiff'
    fi

#########################
# Run some shell tweaks #
#########################
  # Fix SSH permissions
  fixsshperms

  # Set path when running on OSX and from Terminal window
  if [ "$OS_FAMILY" = "Darwin" ]; then
    if DidTerminalCallShell; then
      if [ -d "$HOME/Desktop" ]; then
        cd ~/Desktop || exit
      fi
    fi
  fi


## Update, if needed
. ~/.dotfiles/posixshells/dotfiles_updater.sh
