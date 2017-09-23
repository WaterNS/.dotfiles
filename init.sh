#!/bin/bash
shopt -s dotglob
HOMEREPO=$HOME/.dotfiles

for dotfile in $(find $HOMEREPO -maxdepth 1 -type f -iname ".*")
do
	target=$HOME/$(basename $dotfile)
	[ ! -r $target ] && ln -s $dotfile $target && echo "NOTE: Linked ~/$(basename $dotfile) to custom one in dotfiles repo"
done

# Create .bashrc if doesn't exist
if [ ! -f ~/.bashrc ]; then
	echo 'NOTE: .bashrc not found, creating!'
	touch ~/.bashrc
  echo '#!/bin/bash' >> ~/.bashrc
fi

# Source custom bashrc in existing .bashrc
if ! grep -q "bashrc_custom" ~/.bashrc; then
  echo 'NOTE: .bashrc found, but missing reference to custom bashrc, adding!'
  echo "source $HOMEREPO/bashrc_custom" >> ~/.bashrc
fi

# Create .bash_profile if doesn't exist
if [ ! -f ~/.bash_profile ]; then
  echo 'NOTE: .bash_profile not found, creating!'
  touch ~/.bash_profile
  echo '#!/bin/bash' >> ~/.bash_profile
fi

# Source .bashrc in existing .bash_profile
if ! grep -q "bashrc" ~/.bash_profile; then
  echo 'NOTE: .bash_profile found, but missing reference to ~/.bashrc, adding!'
  echo "source ~/.bashrc" >> ~/.bash_profile
fi

curpath=$PWD
cd $HOMEREPO
git config user.name "User"
git config user.email waterns@users.noreply.github.com
cd $curpath


#Setup Pathogen
mkdir -p ~/.vim/autoload ~/.vim/bundle && \
curl -LSso ~/.vim/autoload/pathogen.vim https://tpo.pe/pathogen.vim

#VIM Theme: Badwolf
git clone http://github.com/sjl/badwolf/ ~/.vim/bundle/badwolf

#VIM Theme: Solarized
git clone git://github.com/altercation/vim-colors-solarized.git ~/.vim/bundle/vim-colors-solarized

#VIM Plugin: gUndo (Undo on steriods)
git clone http://github.com/sjl/gundo.vim.git ~/.vim/bundle/gundo

#VIM Plugin: ack (Search files/folders within VIM)
#TODO: Requires silver searcher (ag) to be installed
git clone https://github.com/mileszs/ack.vim.git ~/.vim/bundle/ack.vim

#VIM Plugin: vim-airline (light weight vim powerline)
git clone https://github.com/vim-airline/vim-airline ~/.vim/bundle/vim-airline
git clone https://github.com/vim-airline/vim-airline-themes ~/.vim/bundle/vim-airline-themes

#VIM Plugin: vim-gitgutter (git plugin)
git clone git://github.com/airblade/vim-gitgutter.git ~/.vim/bundle/vim-gitgutter

#VIM Plugin:
git clone https://github.com/tpope/vim-fugitive.git ~/.vim/bundle/vim-fugitive

#BASH Plugin: bash-powerline
curl https://raw.githubusercontent.com/riobard/bash-powerline/master/bash-powerline.sh > ~/.bash-powerline.sh

#OSX Terminal Theme: Dracula:
if [[ $OSTYPE == darwin* ]]; then
  #TODO: Check to see if folder exists
  mkdir -p ~/.osx/
  git clone https://github.com/dracula/terminal.app.git ~/.osx/terminal/dracula
  open ~/.osx/terminal/dracula/Dracula.terminal
fi

#OSX: Show hidden files
if [[ $OSTYPE == darwin* ]]; then
  defaults write com.apple.finder AppleShowAllFiles YES
fi

