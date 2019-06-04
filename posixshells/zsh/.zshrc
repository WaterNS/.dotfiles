#!/bin/zsh

# ZSH: posix/sh->bash->zsh

### INCLUDE: posix base ##
. ~/.dotfiles/posixshells/posix_rc.sh

############################################
# INCLUDES
############################################
if [ -f ~/.dotfiles/posixshells/bash/bash_functions ]; then
	. ~/.dotfiles/posixshells/bash/bash_functions
fi

if [ -f ~/.bash_aliases ]; then
	. ~/.bash_aliases
fi

if [ -f ~/.dotfiles/posixshells/bash/installerfunctions ]; then
	. ~/.dotfiles/posixshells/bash/installerfunctions
fi