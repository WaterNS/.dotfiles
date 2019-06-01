#!/bin/bash

### History Stuffs

exit_session() {
  if [ -f "$HOME/.bash_logout" ]; then
    . "$HOME/.bash_logout"
  fi
}
trap exit_session SIGHUP

# BASH: Disable history, and clear it
# set +o history # Enabling will show ZERO history, not even in current session
unset HISTFILE # On exit, will not write history file
history -c
rm -f "$HOME/.bash_history" 2> /dev/null
rm -rf "$HOME/.bash_sessions" 2> /dev/null

# OSX: Disable session saving
if [[ $OSTYPE == darwin* ]]; then
	touch ~/.bash_sessions_disable
fi

# LESS: Disable history and delete it
export LESSHISTFILE=/dev/null
rm -f "$HOME/.lesshst" 2> /dev/null

# Remove .rnd (seed generated by OpenSSL/PGP)
rm -f "$HOME/.rnd" 2> /dev/null

# VIM: Remove history
rm -f "$HOME/.viminfo" 2> /dev/null
rm -f "$HOME/.vim/.netrwhist" 2> /dev/null

# VIM: Create backup, swap, and undo folders if don't exist
if [ ! -d ~/.vim/backups ]; then mkdir -p ~/.vim/backups; fi
if [ ! -d ~/.vim/swaps ]; then mkdir -p ~/.vim/swaps; fi
if [ ! -d ~/.vim/undo ]; then mkdir -p ~/.vim/undo; fi

############################################
# PATH: Include .dotfiles bin
PATH=$PATH:~/.dotfiles/opt/bin

if [ -f ~/.dotfiles/bash/bash_functions ]; then
	. ~/.dotfiles/bash/bash_functions
fi

if [ -f ~/.bash_aliases ]; then
	. ~/.bash_aliases
fi

if [ -f ~/.dotfiles/bash/bash_prompt ]; then
	. ~/.dotfiles/bash/bash_prompt
fi

if [ -f ~/.dotfiles/bash/installerfunctions ]; then
	. ~/.dotfiles/bash/installerfunctions
fi

#############################################

# Running interactively?
case $- in
    *i*) shopt -s checkwinsize ;;
      *) # return;;
esac


# Set default editors
export GIT_EDITOR=vim
export VISUAL=vim
export EDITOR=vim

# Enable programmable completion features
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

# GIT PAGER and LESS settings
# Use diff-so-fancy (if available)
if [ -x "$(command -v diff-so-fancy)" ]; then
	# Set Git Pager and LESS settings for session
	export GIT_PAGER='diff-so-fancy | less'
	export LESS="-x2 -RFX $LESS"

	# Include diff-so-fancy colors
	git config --global include.path '~/.dotfiles/git/git_diffsofancy'
else # Set to use LESS as fallback and undo gitconfig change
  export GIT_PAGER='less'
  export LESS="-x2 -RFX $LESS"
	git config --global --unset include.path '~/.dotfiles/git/git_diffsofancy'
fi

# Set GIT Config Settings
if [ -x "$(command -v git)" ]; then
  git config --global include.path '~/.dotfiles/git/git_tweaks'
fi

# Use lesspipe for binaries
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# Enable ZSH like tab completion functionality
bind 'set show-all-if-ambiguous on'
bind 'TAB:menu-complete'

# Fix SSH permissions
fixsshperms

if [[ $OSTYPE == darwin* ]]; then
	if [ -d ~/Desktop ] && [ "$IN_TERMINAL_APP" ]; then
    cd ~/Desktop || exit
  fi
fi

# DOTFILES updater
# Check if last update was longer than set interval, kick off update if so
if [ -f "$HOME/.dotfiles/opt/lastupdate" ]; then
	oldtime=$(head -1 "$HOME/.dotfiles/opt/lastupdate")
	newtime=$(date +%s)
	difftime=$((newtime-oldtime))
	maxtime=$((5*24*60*60))
fi

SHAinitscript=$(git --git-dir "$HOME/.dotfiles/.git" log -n 1 --pretty=format:%H -- init_bash.sh)
if [ ! -f "$HOME/.dotfiles/opt/lastinit" ] || [ "$SHAinitscript" != "$(head -2 "$HOME/.dotfiles/opt/lastinit" | tail -1)" ]; then
	if [ ! -f "$HOME/.dotfiles/opt/lastinit" ]; then
		echo "No init time file found, running initialization now"
	else
	 echo "Init script has been updated since last run, Executing init_bash.sh with ReInitialization flag"
	fi
	"$HOME/.dotfiles/init_bash.sh" -r
	echo "Restarting shell..."
	echo "------------------"
	exec bash
elif [ $difftime -gt $maxtime ] || [ ! -f "$HOME/.dotfiles/opt/lastupdate" ]; then
	if [ ! -f "$HOME/.dotfiles/opt/lastupdate" ]; then
		echo "No update time file found, running update now"
	else
		echo "Last update happened $(seconds2time "$difftime") ago, updating dotfiles"
	fi
	"$HOME/.dotfiles/init_bash.sh" -u
	echo "Restarting shell..."
	echo "------------------"
	exec bash
else
	echo "Last dotfiles update: $(seconds2time "$difftime") ago / Update Interval: $(seconds2time $maxtime)"
	#echo "Update <$maxtime seconds ago, skipping dotfiles update"
fi
