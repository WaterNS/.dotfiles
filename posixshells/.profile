#!/bin/sh

HOMEREPO=${HOMEREPO:-"$HOME/.dotfiles"}
export HOMEREPO

# Non-Interactive Guard Check -- No-op when running in non-interactive shells
# Short-circuit if the guard says to skip
if [ -f "$HOMEREPO/posixshells/nonInteractiveGuardCheck.sh" ] && \
          . "$HOMEREPO/posixshells/nonInteractiveGuardCheck.sh"; \
then
  return # Exit RC script in non-interactive shells
fi

# PATH: Include .dotfiles bins
PATH="$HOMEREPO/opt/bin:$HOMEREPO/bin:$PATH"
export PATH

# PATH: Include custom Homebrew bin
if [ -d "$HOMEREPO/opt/homebrew/bin" ]; then
  PATH=$PATH:$HOMEREPO/opt/homebrew/bin
fi

# PATH: Include custom pip bin
if [ -d "$HOMEREPO/opt/pip_packages/bin" ]; then
  PATH=$PATH:$HOMEREPO/opt/pip_packages/bin
  PYTHONPATH=$HOMEREPO/opt/pip_packages
  export PYTHONPATH
fi
# PATH: Include custom python bin
if [ -d ~/Library/Python/3.9/bin ]; then
  PATH=$PATH:~/Library/Python/3.9/bin
fi


# # Activate TMUX session
# if [ -z "$TMUX" ] && [ -x "$(command -v tmux)" ] && [ "$TERM_PROGRAM" != "vscode" ]; then
#   # shellcheck disable=2093 #TMUX is taking over the process here
#   exec tmux; # This makes TMUX replace process, rather than becoming child process
#   #tmux attach -t default || tmux new -s default # This would spawn TMUX as child process
# fi

#Identify running shell
. "$HOMEREPO/posixshells/posix_id_shell.sh"

# Identify Operating System (better uname)
. "$HOMEREPO/posixshells/posix_id_os.sh"
[ "$NOT_SECONDARY_SESSION" ] && echo "$OS_STRING";

# Identify hardware
. "$HOMEREPO/posixshells/posix_id_devicehw.sh"
[ "$NOT_SECONDARY_SESSION" ] && echo "$HW_STRING";

### History Stuffs
. "$HOMEREPO/posixshells/posix_history.sh"

# VIM: Create backup, swap, and undo folders if don't exist
if [ ! -d ~/.vim/backups ]; then mkdir -p ~/.vim/backups; fi
if [ ! -d ~/.vim/swaps ]; then mkdir -p ~/.vim/swaps; fi
if [ ! -d ~/.vim/undo ]; then mkdir -p ~/.vim/undo; fi

############################################
# INCLUDES
############################################
if [ -f "$HOMEREPO/posixshells/posix_functions.sh" ]; then
  . "$HOMEREPO/posixshells/posix_functions.sh"
fi

if [ -f "$HOMEREPO/posixshells/posix_aliases.sh" ]; then
  . "$HOMEREPO/posixshells/posix_aliases.sh"
fi

if [ -f "$HOMEREPO/posixshells/posix_installers.sh" ]; then
	. "$HOMEREPO/posixshells/posix_installers.sh"
fi

if [ -f "$HOMEREPO/posixshells/posix_prompt" ]; then
  . "$HOMEREPO/posixshells/posix_prompt"
fi

# Get color support for 'less', man, etc
if [ -f "$HOMEREPO/posixshells/less/termcap" ]; then
  . "$HOMEREPO/posixshells/less/termcap"
  export LESS="$LESS --RAW-CONTROL-CHARS"
fi

#######################################
# EXPORTING vars that config settings #
#######################################
# Set default editors
export GIT_EDITOR=vim
export VISUAL=vim
export EDITOR=vim

export CONDA_AUTO_ACTIVATE_BASE=false # Don't auto activate Conda on install

# Enable highlight's integration with LESS (if available)
[ -x "$(command -v highlight)" ] && export LESSOPEN="| highlight %s --out-format xterm256 --force"

# Use lesspipe for binaries
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

    ############################
    ## Exporting GIT settings ##
    ############################

    if [ "$NOT_SECONDARY_SESSION" ]; then
      # Set GIT Config Settings
      if [ -x "$(command -v git)" ]; then
        git config --global --remove-section include
        #shellcheck disable=2088 # Exception: Want to explicitly write the tilde to config
        git config --global --add include.path '~/.dotfiles/git/git_tweaks'

        if compare_versions "$(git --version | cut -f3 -d " ")" '>' 2.21;then
          git config --global --add log.date 'auto:format:%a %Y-%h-%d %I:%M %p %z %Z'
        else
          git config --global --add log.test 'foobar'
          git config --global --remove-section log
        fi
      fi

      # GIT PAGER and LESS settings
      # Use diff-so-fancy (if available)
      if [ -x "$(command -v delta)" ]; then
        export GIT_PAGER='delta'
        #shellcheck disable=2088 # Exception: Want to explicitly write the tilde to config
        git config --global --add include.path '~/.dotfiles/git/git_deltadiff'
      elif [ -x "$(command -v diff-so-fancy)" ]; then
        # Set Git Pager and LESS settings for session
        export GIT_PAGER='diff-so-fancy | less'
        export LESS="-x2 -RFX $LESS"

        # Include diff-so-fancy colors
        #shellcheck disable=2088 # Exception: Want to explicitly write the tilde to config
        git config --global --add include.path '~/.dotfiles/git/git_diffsofancy'
      else # Set to use LESS as fallback and undo gitconfig change
        export GIT_PAGER='less'
        export LESS="-x2 -RFX $LESS"

        #shellcheck disable=2088 # Exception: Want to explicitly write the tilde to config
        git config --global --unset-all include.path '~/.dotfiles/git/git_diffsofancy'
        #shellcheck disable=2088 # Exception: Want to explicitly write the tilde to config
        git config --global --unset-all include.path '~/.dotfiles/git/git_deltadiff'
      fi
    fi

#########################
# Run some shell tweaks #
#########################
  # Fix SSH permissions
  [ "$NOT_SECONDARY_SESSION" ] && fixsshperms

  # Set path when running on OSX and from Terminal window
  if [ "$OS_PLATFORM" = "macos" ]; then
    if DidTerminalCallShell && [ "$PWD" = "$HOME" ]; then
      if [ -d "$HOME/Desktop" ]; then
        cd ~/Desktop || exit
      fi
    fi
  fi

  # AWS CloudShell: Set path and Desktop folder
  if [ "$AWSCLOUDSHELL" ]; then
    if [ ! -d "$HOME/Desktop" ]; then
      mkdir "$HOME/Desktop"
    fi
    cd ~/Desktop || exit
  fi


## Update, if needed
if [ "$NOT_SECONDARY_SESSION" ]; then
  . "$HOMEREPO/posixshells/dotfiles_updater.sh"
fi

#tripleSplitTMUX # Split terminal into 3 by default
