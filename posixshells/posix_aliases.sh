#!/bin/sh

#prettier ping (shell script wrapper for ping output)
if [ -x "$(command -v prettyping)" ]; then
  alias ping='prettyping --nolegend'
fi

# add vim alias, run vim with viminfo disabled
if [ -x "$(command -v vim)" ]; then
  alias vim='vim -i NONE'
fi

# alias common git commands to shorthand
if [ -x "$(command -v git)" ]; then
  alias status='git status'
  alias push='git push'
  alias gitreset='git fetch $(git config branch.`git name-rev --name-only HEAD`.remote) && git reset $(git config branch.`git name-rev --name-only HEAD`.remote)/$(git rev-parse --abbrev-ref HEAD)'
  alias gitresethard='git fetch $(git config branch.`git name-rev --name-only HEAD`.remote) && git reset --hard $(git config branch.`git name-rev --name-only HEAD`.remote)/$(git rev-parse --abbrev-ref HEAD)'
fi

# add common clear screen alias
if [ -x "$(command -v clear)" ]; then
  alias cls='clear'
  alias clea='clear' #typo fix
  alias ckear='clear' #typo fix
fi

# add Visual Studio Code aliases
if [ -f "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" ]; then
  alias code='/Applications/"Visual Studio Code.app"/Contents/Resources/app/bin/code'
  alias vscode=code
fi

# Set ls behavior
if contains "$(uname)" "Darwin"; then
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
if contains "$(uname)" "Darwin"; then
  if [ -d ~/Library/Mobile\ Documents/com~apple~CloudDocs/ ]; then
    if contains "$RUNNINGSHELL" "bash"; then
      shopt -s cdable_vars
    elif contains "$RUNNINGSHELL" "zsh"; then
      setopt cdable_vars
    else
      setopt cdable_vars
    fi
    export icloud=~/Library/Mobile\ Documents/com~apple~CloudDocs/
  fi
fi