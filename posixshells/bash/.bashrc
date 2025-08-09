#!/bin/bash

# Non-Interactive Guard Check -- No-op when running in non-interactive shells
# Short-circuit if the guard says to skip
if [ -f "$HOME/.dotfiles/posixshells/nonInteractiveGuardCheck.sh" ] && \
          . "$HOME/.dotfiles/posixshells/nonInteractiveGuardCheck.sh"; \
then
  return # Exit RC script in non-interactive shells
fi

### INCLUDE: AWS Cloudshell bashrc, if available ##
if [ -f "$HOME/.bashrc.awscloudshell" ]; then
  . "$HOME/.bashrc.awscloudshell"
fi

### INCLUDE: posix base ##
. ~/.dotfiles/posixshells/.profile

# ble.sh - Bash Syntax Highlighting - Top of RC script code:
if [ -f ~/.dotfiles/opt/bash-extras/blesh/ble.sh ]; then
  [[ $- == *i* ]] && source ~/.dotfiles/opt/bash-extras/blesh/ble.sh --noattach
fi

### History Stuffs - bash specific
# OSX: Disable bash session saving
if [ "$OS_FAMILY" = "Darwin" ]; then
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
if [ -f ~/.dotfiles/posixshells/modernshell_functions ]; then
	. ~/.dotfiles/posixshells/modernshell_functions
fi

if [ -f ~/.bash_aliases ]; then
	. ~/.bash_aliases
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

# ble.sh - Bash Syntax Highlighting - End of RC script code:
#shellcheck disable=SC2154 # Exception: Ignore unassigned reference to _ble_bash
if [ -f ~/.dotfiles/opt/bash-extras/blesh/ble.sh ]; then
  ((_ble_bash)) && ble-attach
fi

# NVM helper
if [ -d ~/.nvm ]; then
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
fi

#MYEOF
