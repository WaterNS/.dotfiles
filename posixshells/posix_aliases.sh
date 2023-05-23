#!/bin/sh

# #prettier ping (shell script wrapper for ping output)
# if [ -x "$(command -v prettyping)" ]; then
#   alias ping='prettyping --nolegend'
# fi

# cd helper
alias cd..='cd ..'

if [ -x "$(command -v rsync)" ]; then
  rsync_cp() {
    rsync -pogbr -hhh --backup-dir=/tmp/rsync -e /dev/null --progress "$@"
  }
fi

# Move/Copy: Confirm before overwrite
if [ -x "$(command -v cp)" ]; then
  if [ -x "$(command -v rsync)" ]; then
    alias cp='rsync_cp' # Use rsync for copying when available (nicer)
  else
    alias cp='cp -i'
  fi
fi
if [ -x "$(command -v mv)" ]; then
  alias mv='mv -i'
fi

# diskspace: Use ncdu or df, if available
# Note: NEEDS to be ahead tweaks to base commands
if [ -x "$(command -v ncdu)" ];then
  alias diskspace="ncdu"
elif [ -x "$(command -v df)" ]; then
  alias diskspace="df -h"
fi

# df: Human-readable sizes
if [ -x "$(command -v df)" ]; then
  alias df='df -h'
fi

# grep: Auto colorize
if [ -x "$(command -v grep)" ]; then
  alias grep='grep --color=auto'
fi

# add vim alias, run vim with viminfo disabled
if [ -x "$(command -v vim)" ]; then
  alias vim='vim -i NONE'
fi

# Alias `tldr` to help`
if fn_exists "help"; then
  alias tldr='help'
fi

# alias common git commands to shorthand
if [ -x "$(command -v git)" ]; then
  alias status='git status'
  alias log='git customLog'
  alias push='git push'
  alias gitreset='git fetch $(git config branch.`git name-rev --name-only HEAD`.remote) && git reset $(git config branch.`git name-rev --name-only HEAD`.remote)/$(git rev-parse --abbrev-ref HEAD)'
  alias gitresethard='git fetch $(git config branch.`git name-rev --name-only HEAD`.remote) && git reset --hard $(git config branch.`git name-rev --name-only HEAD`.remote)/$(git rev-parse --abbrev-ref HEAD)'
fi

# add common clear screen alias
if [ -x "$(command -v clear)" ]; then
  clearScreen() {
    # if [ -n "$ZSH" ]; then
    #   #zle clear-screen
    # else
    #   clear
    # fi
    clear && printf '\e[3J' && printf '\e[2J\e[3J\e[H'
    if [ -n "$TMUX" ]; then
      tmux clear-history #clears rollback
    fi
  }
  alias clear='clearScreen' # overwrite factory default

  alias cls='clearScreen'
  alias clea='clearScreen' #typo fix
  alias ckear='clearScreen' #typo fix
fi

# add Visual Studio Code aliases
if [ -f "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" ]; then
  alias code="/Applications/Visual\ Studio\ Code.app/Contents/Resources/app/bin/code"
  alias vscode=code
fi

# add Visual Studio Code Insider aliases
if [ -f "/Applications/Visual Studio Code - Insiders.app/Contents/Resources/app/bin/code" ]; then
  if [ ! -x "$(command -v code)" ]; then
    alias code="/Applications/Visual\ Studio\ Code\ -\ Insiders.app/Contents/Resources/app/bin/code"
    alias vscode=code
  else
    alias codeinsiders="/Applications/Visual\ Studio\ Code\ -\ Insiders.app/Contents/Resources/app/bin/code"
  fi
fi

# Set ls behavior
if [ "$OS_FAMILY" = "Darwin" ]; then
  export LSCOLORS='Affxcxdxbxegedabagacad' # See https://geoff.greer.fm/lscolors/
  alias ls='LC_COLLATE=C /bin/ls -alhGpF'
else # Most likely GNU Linux ls
  export LS_COLORS='di=1;30;45:ln=35:so=32:pi=33:ex=31:bd=34;46:cd=34;43:su=30;41:sg=30;46:tw=30;42:ow=30;43'
  alias ls='LC_COLLATE=C /bin/ls -alhpF --color --group-directories-first'
fi

# ls: Use LSD, if available
if [ -x "$(command -v lsd)" ]; then
  alias ls='lsd --group-dirs first --icon "never" -alh'
fi

# add icloud shortcut alias
if [ "$OS_FAMILY" = "Darwin" ]; then
  if [ -d ~/Library/Mobile\ Documents/com~apple~CloudDocs/ ]; then
    if contains "$RUNNINGSHELL" "bash"; then
      #shellcheck disable=3044 # Exception: shopt will be available if running under bash.
      shopt -s cdable_vars
    elif contains "$RUNNINGSHELL" "zsh"; then
      setopt cdable_vars
    else
      setopt cdable_vars
    fi
    export icloud=~/Library/Mobile\ Documents/com~apple~CloudDocs/
  fi
fi


# cat: Use bat, if available
if [ -x "$(command -v bat)" ]; then
  alias cat='bat --tabs 2'
fi

# scp: Use rsync, if available
if [ -x "$(command -v scp)" ]; then
  if [ -x "$(command -v rsync)" ]; then
    alias scp='rsync --archive --xattrs --acls --progress --rsh="ssh"'
  fi
fi

# aria: Alias to aria2c
if [ -x "$(command -v aria2c)" ]; then
  alias aria='aria2c'
fi

# download: Use aria2c, if available
if [ -x "$(command -v aria2c)" ]; then
  alias download='aria2c'
fi

# pip: Use pip3, if nothing else available
if [ -x "$(command -v pip3)" ] && [ ! -x "$(command -v pip)" ]; then
  alias pip='pip3'
fi

# python: Use python3, if nothing else available
if [ -x "$(command -v python3)" ] && [ ! -x "$(command -v python)" ]; then
  alias python='python3'
fi
