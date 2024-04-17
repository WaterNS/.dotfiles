#!/bin/sh

# shellcheck disable=SC2154 # $ri/$u sourced from upstream script
if [ "$r" = true ]; then
  echo "  ReInitializing Vim components:";
  if [ -d "$HOME/.vim/autoload" ]; then rm -rf "$HOME/.vim/autoload"; fi
  if [ -d "$HOME/.vim/bundle" ]; then rm -rf "$HOME/.vim/bundle"; fi
elif [ "$u" = true ]; then
	echo "  UPDATING Vim components";
else
  echo "Initializing Vim components";
fi

#VIM Plugin Loader: Pathogen
mkdir -p ~/.vim/autoload ~/.vim/bundle && \
curl -LSso ~/.vim/autoload/pathogen.vim https://tpo.pe/pathogen.vim
if [ "$u" = true  ]; then
	echo ""
	echo "--Updating Pathogen"
	curl -LSso ~/.vim/autoload/pathogen.vim https://tpo.pe/pathogen.vim
fi

#VIM Theme: Badwolf
if [ ! -d "$HOME/.vim/bundle/badwolf" ]; then
	# git clone https://github.com/sjl/badwolf/ ~/.vim/bundle/badwolf; echo ""
  githubCloneByCurl https://github.com/sjl/badwolf ~/.vim/bundle/badwolf; echo ""
elif [ "$u" = true  ]; then updateGitRepo "BadWolf" "VIM theme" ~/.vim/bundle/badwolf;
fi

#VIM Plugin: vim-airline (light weight vim powerline) + themes
if [ ! -d "$HOME/.vim/bundle/vim-airline" ]; then
	# git clone https://github.com/vim-airline/vim-airline ~/.vim/bundle/vim-airline; echo ""
  githubCloneByCurl https://github.com/vim-airline/vim-airline ~/.vim/bundle/vim-airline; echo ""
elif [ "$u" = true  ]; then updateGitRepo "vim-airline" "VIM status bar plugin" ~/.vim/bundle/vim-airline;
fi

if [ ! -d "$HOME/.vim/bundle/vim-airline-themes" ]; then
	# git clone https://github.com/vim-airline/vim-airline-themes ~/.vim/bundle/vim-airline-themes; echo ""
  githubCloneByCurl https://github.com/vim-airline/vim-airline-themes ~/.vim/bundle/vim-airline-themes; echo ""
elif [ "$u" = true  ]; then updateGitRepo "vim-airline-themes" "vim-airline themes" ~/.vim/bundle/vim-airline-themes;
fi

#VIM Plugin: Super Tab (tab to complete)
if [ ! -d "$HOME/.vim/bundle/supertab" ]; then
	#printf -- "- Installing: SuperTab (VIM tab completion plugin)\n";
	# git clone https://github.com/ervandew/supertab ~/.vim/bundle/supertab; echo ""
  githubCloneByCurl https://github.com/ervandew/supertab ~/.vim/bundle/supertab; echo ""
elif [ "$u" = true  ]; then updateGitRepo "supertab" "VIM tab completion plugin" ~/.vim/bundle/supertab;
fi

if [ "$r" = true ]; then
  echo "  Finished ReInitializing Vim components!";
elif [ "$u" = true  ]; then
	echo ""
	echo "  Finished UPDATING Vim components!";
else
	echo "  ++ Finished initializing Vim components! ++";
fi
