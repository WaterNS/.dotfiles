#!/bin/zsh

# ZSH: posix/sh -> zsh -> OhMyZsh -> Generic POSIX customizations

############################################
# Launch OhMyZsh
############################################
# Path to your oh-my-zsh installation.
export ZSH=~/.dotfiles/opt/ohmyzsh

# Path to ohmyzsh customizations (default = $ZSH/custom)
ZSH_CUSTOM=~/.dotfiles/posixshells/zsh/custom

# Set name of the theme to load --- See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="robbyrussell"

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git)

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment the following line to disable bi-weekly auto-update checks.
# DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to automatically update without prompting.
# DISABLE_UPDATE_PROMPT="true"

# Uncomment the following line to change how often to auto-update (in days).
# export UPDATE_ZSH_DAYS=13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

source $ZSH/oh-my-zsh.sh

############################################
# Post OhMyZSH customizations
############################################

### Set ZSH to word split IFS
if [ "$ZSH_VERSION" ]; then
  setopt sh_word_split
  setopt +o nomatch # https://unix.stackexchange.com/questions/310540/how-to-get-rid-of-no-match-found-when-running-rm
fi

### INCLUDE: posix base ##
. ~/.dotfiles/posixshells/.profile

############################################
# INCLUDES
############################################
if [ -f ~/.dotfiles/posixshells/modernshell_functions ]; then
	. ~/.dotfiles/posixshells/modernshell_functions
fi

if [ -f ~/.dotfiles/posixshells/posixshells/posix_installers.sh ]; then
	. ~/.dotfiles/posixshells/posixshells/posix_installers.sh
fi