#!/bin/bash
shopt -s dotglob
HOMEREPO=$HOME/.dotfiles/

for dotfile in $HOMEREPO/*
do
    if [ ! "$(basename $dotfile)" == ".git" ]; then
      target=$HOME/$(basename $dotfile)
      [ ! -r $target ] && ln -s $dotfile $target && echo "Linked $(basename $dotfile)"
    else
      echo "Skipping .git folder"
    fi
done


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

#OSX Terminal Theme: Dracula:
if [[ $OSTYPE == darwin* ]]; then
  mkdir -p ~/.osx/
  git clone https://github.com/dracula/terminal.app.git ~/.osx/terminal/dracula
  open ~/.osx/terminal/dracula/Dracula.terminal
fi
