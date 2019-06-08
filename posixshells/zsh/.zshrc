#!/bin/zsh

# ZSH: posix/sh->bash->zsh

### INCLUDE: posix base ##
. ~/.dotfiles/posixshells/.profile

############################################
# INCLUDES
############################################
if [ -f ~/.dotfiles/posixshells/bash/bash_functions ]; then
	. ~/.dotfiles/posixshells/bash/bash_functions
fi

if [ -f ~/.bash_aliases ]; then
	. ~/.bash_aliases
fi

if [ -f ~/.dotfiles/posixshells/posixshells/posix_installers.sh ]; then
	. ~/.dotfiles/posixshells/posixshells/posix_installers.sh
fi