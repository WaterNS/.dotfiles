#!/bin/bash

### INCLUDE: posix base ##
. ~/.dotfiles/posixshells/.profile

### History Stuffs - bash specific
# OSX: Disable bash session saving
if contains "$(uname)" "Darwin"; then
	touch ~/.bash_sessions_disable
fi

exit_session() {
  if [ -f "$HOME/.bash_logout" ]; then
    . "$HOME/.bash_logout"
  fi
  if [ -f "$HOME/.logout" ]; then
    . "$HOME/.logout"
  fi
}
trap exit_session SIGHUP


############################################
# INCLUDES - bash specific only!
############################################
if [ -f ~/.dotfiles/posixshells/bash/bash_functions ]; then
	. ~/.dotfiles/posixshells/bash/bash_functions
fi

if [ -f ~/.bash_aliases ]; then
	. ~/.bash_aliases
fi

if [ -f ~/.dotfiles/posixshells/bash/bashprompt/bash_prompt ]; then
	. ~/.dotfiles/posixshells/bash/bashprompt/bash_prompt
fi

#############################################

# Bash: Running interactively?
case $- in
    *i*) shopt -s checkwinsize ;;
      *) # return;;
esac

# Bash: Enable programmable completion features
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

# Bash: Enable ZSH like tab completion functionality
bind 'set show-all-if-ambiguous on'
bind 'TAB:menu-complete'