#!/bin/bash
shopt -s dotglob
HOMEREPO=$HOME/.dotfiles

for dotfile in $(find $HOMEREPO -maxdepth 1 -type f -iname ".*")
do
	if [ "$(basename $dotfile)" != ".editorconfig" ] && [ "$(basename $dotfile)" != ".gitignore" ]; then
		target=$HOME/$(basename $dotfile)
		[ ! -r $target ] && ln -s $dotfile $target && echo "NOTE: Linked ~/$(basename $dotfile) to custom one in dotfiles repo"
	fi
done

# Create dir for installation of packages for dotfiles
mkdir -p $HOMEREPO/opt
mkdir -p $HOMEREPO/opt/bin

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

# Set .dotfiles repo setting
curpath=$PWD
cd $HOMEREPO
git config user.name "User"
git config user.email waterns@users.noreply.github.com
git config core.pager 'less -x2'
cd $curpath


#Setup Pathogen
mkdir -p ~/.vim/autoload ~/.vim/bundle && \
curl -LSso ~/.vim/autoload/pathogen.vim https://tpo.pe/pathogen.vim

#VIM Theme: Badwolf
if [ ! -d "$HOME/.vim/bundle/badwolf" ]; then
	git clone http://github.com/sjl/badwolf/ ~/.vim/bundle/badwolf
fi

#VIM Theme: Solarized
if [ ! -d "$HOME/.vim/bundle/vim-colors-solarized" ]; then
	git clone git://github.com/altercation/vim-colors-solarized.git ~/.vim/bundle/vim-colors-solarized
fi

#VIM Plugin: gUndo (Undo on steriods)
if [ ! -d "$HOME/.vim/bundle/gundo" ]; then
	git clone http://github.com/sjl/gundo.vim.git ~/.vim/bundle/gundo
fi

#Perl binary: Ack (searcher)
if [ ! -f "$HOMEREPO/opt/bin/ack" ]; then
	curl https://beyondgrep.com/ack-2.18-single-file > "$HOMEREPO/opt/bin/ack" && chmod 0755 "$HOMEREPO/opt/bin/ack"
fi

#VIM Plugin: ack (Search files/folders within VIM)
#TODO: Requires silver searcher (ag) to be installed
if [ ! -d "$HOME/.vim/bundle/ack.vim" ]; then
	git clone https://github.com/mileszs/ack.vim.git ~/.vim/bundle/ack.vim
fi

#VIM Plugin: vim-airline (light weight vim powerline) + themes
if [ ! -d "$HOME/.vim/bundle/vim-airline" ]; then
	git clone https://github.com/vim-airline/vim-airline ~/.vim/bundle/vim-airline
fi

if [ ! -d "$HOME/.vim/bundle/vim-airline-themes" ]; then
	git clone https://github.com/vim-airline/vim-airline-themes ~/.vim/bundle/vim-airline-themes
fi

#VIM Plugin: vim-gitgutter (git plugin)
if [ ! -d "$HOME/.vim/bundle/vim-gitgutter" ]; then
	git clone git://github.com/airblade/vim-gitgutter.git ~/.vim/bundle/vim-gitgutter
fi

#VIM Plugin:
if [ ! -d "$HOME/.vim/bundle/vim-fugitive" ]; then
	git clone https://github.com/tpope/vim-fugitive.git ~/.vim/bundle/vim-fugitive
fi

#BASH Plugin: bash-powerline
if [ ! -f "$HOMEREPO/opt/bash-powerline.sh" ]; then
	curl https://raw.githubusercontent.com/riobard/bash-powerline/master/bash-powerline.sh > $HOMEREPO/opt/bash-powerline.sh
fi

#OSX Terminal Theme: Dracula:
if [[ $OSTYPE == darwin* ]]; then
	if [ ! -d "$HOMEREPO/opt/osxterminal/dracula" ]; then
		git clone https://github.com/dracula/terminal.app.git $HOMEREPO/opt/osxterminal/dracula
		open $HOMEREPO/opt/osxterminal/dracula/Dracula.terminal
	fi
fi

#OSX: Show hidden files
if [[ $OSTYPE == darwin* ]]; then
	defaults write com.apple.finder AppleShowAllFiles YES
fi

