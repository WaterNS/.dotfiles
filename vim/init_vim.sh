#!/bin/bash

if [ $ri ]; then
  echo "  ReInitializing Vim components:";
  if [ -d "$HOME/.vim/autoload" ]; then rm -rf "$HOME/.vim/autoload"; fi
  if [ -d "$HOME/.vim/bundle" ]; then rm -rf "$HOME/.vim/bundle"; fi
elif [ $u ]; then
	echo "  UPDATING Vim components";
fi

#VIM Plugin Loader: Pathogen
mkdir -p ~/.vim/autoload ~/.vim/bundle && \
curl -LSso ~/.vim/autoload/pathogen.vim https://tpo.pe/pathogen.vim
if [ $u ]; then
	echo ""
	echo "--Updating Pathogen"
	curl -LSso ~/.vim/autoload/pathogen.vim https://tpo.pe/pathogen.vim
fi

#VIM Theme: Badwolf
if [ ! -d "$HOME/.vim/bundle/badwolf" ]; then
	git clone https://github.com/sjl/badwolf/ ~/.vim/bundle/badwolf; echo ""
elif [ $u ]; then updategitrepo "BadWolf" "VIM theme" ~/.vim/bundle/badwolf ;
fi

#VIM Plugin: vim-airline (light weight vim powerline) + themes
if [ ! -d "$HOME/.vim/bundle/vim-airline" ]; then
	git clone https://github.com/vim-airline/vim-airline ~/.vim/bundle/vim-airline; echo ""
elif [ $u ]; then updategitrepo "vim-airline" "VIM status bar plugin" ~/.vim/bundle/vim-airline ;
fi

if [ ! -d "$HOME/.vim/bundle/vim-airline-themes" ]; then
	git clone https://github.com/vim-airline/vim-airline-themes ~/.vim/bundle/vim-airline-themes; echo ""
elif [ $u ]; then updategitrepo "vim-airline-themes" "vim-airline themes" ~/.vim/bundle/vim-airline-themes ;
fi

#VIM Plugin: Super Tab (tab to complete)
if [ ! -d "$HOME/.vim/bundle/supertab" ]; then
	echo "- Installing: SuperTab (VIM tab completion plugin)";
	git clone https://github.com/ervandew/supertab.git ~/.vim/bundle/supertab; echo ""
elif [ $u ]; then updategitrepo "supertab" "VIM tab completion plugin" ~/.vim/bundle/supertab ;
fi

if [ $ri ]; then
  echo "  Finished ReInitializing Vim components!";
elif [ $u ]; then
	echo ""
	echo "  Finished UPDATING Vim components!";
fi
