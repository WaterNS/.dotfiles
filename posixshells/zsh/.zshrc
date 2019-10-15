#!/bin/zsh

# ZSH: posix/sh->bash->zsh

### Set ZSH to word split IFS
if [ "$ZSH_VERSION" ]; then
  setopt sh_word_split
fi

### INCLUDE: posix base ##
. ~/.dotfiles/posixshells/.profile

############################################
# INCLUDES
############################################
if [ -f ~/.dotfiles/posixshells/modernshell_functions ]; then
	. ~/.dotfiles/posixshells/modernshell_functions
fi

if [ -f ~/.bash_aliases ]; then
	. ~/.bash_aliases
fi

if [ -f ~/.dotfiles/posixshells/posixshells/posix_installers.sh ]; then
	. ~/.dotfiles/posixshells/posixshells/posix_installers.sh
fi