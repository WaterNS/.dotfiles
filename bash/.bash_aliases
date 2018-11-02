#!/bin/bash

# Set ls behavior
if [[ $OSTYPE == darwin* ]]; then
  export LSCOLORS='Affxcxdxbxegedabagacad' # See https://geoff.greer.fm/lscolors/
  alias ls='LC_COLLATE=C /bin/ls -alhGpF'
else # Most likely GNU Linux ls
  export LS_COLORS='di=1;30;45:ln=35:so=32:pi=33:ex=31:bd=34;46:cd=34;43:su=30;41:sg=30;46:tw=30;42:ow=30;43'
  alias ls='LC_COLLATE=C /bin/ls -alhpF --color --group-directories-first'
fi

# alias common git commands to shorthand
if [ -x "$(command -v git)" ]; then
  alias status='git status'
  alias push='git push'
  alias gitreset='git fetch $(git config branch.`git name-rev --name-only HEAD`.remote) && git reset $(git config branch.`git name-rev --name-only HEAD`.remote)/$(git rev-parse --abbrev-ref HEAD)'
  alias gitresethard='git fetch $(git config branch.`git name-rev --name-only HEAD`.remote) && git reset --hard $(git config branch.`git name-rev --name-only HEAD`.remote)/$(git rev-parse --abbrev-ref HEAD)'
fi

# pubkey function to spit out pubkey
pubkey () { echo "$(cat ~/.ssh/id_rsa.pub)"; }

# add vim alias, run vim with viminfo disabled
if [ -x "$(command -v vim)" ]; then
  alias vim='vim -i NONE'
fi

# add common clear screen alias
if [ -x "$(command -v clear)" ]; then
  alias cls='clear'
  alias clea='clear' #typo fix
fi

# add Visual Studio Code aliases
if [ -f "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" ]; then
  alias code='/Applications/"Visual Studio Code.app"/Contents/Resources/app/bin/code'
  alias vscode=code
fi

# youtube-dl shorthand function that does auto retry
if [ -x "$(command -v youtube-dl)" ]; then
  ytdl () { while ! youtube-dl "$1" -c --socket-timeout 5; do echo DISCONNECTED; sleep 5; done; }
  ytdl-hq () { while ! youtube-dl -f 'bestvideo+bestaudio[ext=m4a]/bestvideo+bestaudio/best' "$1" -c --socket-timeout 5; do echo DISCONNECTED; sleep 5; done; }
  ytdl-mp3 () { while ! youtube-dl -f bestaudio --embed-thumbnail --add-metadata --extract-audio --audio-format mp3 -o "%(title)s.%(ext)s" "$1" -c --socket-timeout 5; do echo DISCONNECTED; sleep 5; done; }
fi
