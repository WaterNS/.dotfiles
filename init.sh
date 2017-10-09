#!/bin/bash

SCRIPTDIR=$( cd $(dirname $0) ; pwd -P )
SCRIPTPATH=$SCRIPTDIR/$(basename "$0")

# Check passed options/args
while getopts ":u" opt ; do
	case $opt in
		u) u=1 ;; # Handle -u switch
	esac
done

# Function: Update git repo (if needed)
updategitrepo () {
	olddir=$PWD
	reponame=$1
	description=$2
	repolocation=$3

	echo ""
	echo "-Check updates: $reponame ($description)"
	cd "$repolocation"
	git fetch

	if [ "$(git rev-parse master)" != "$(git rev-parse origin/master)" ]; then
		echo -n "--Updating $reponame $description repo "
		echo -n "(from $(git rev-parse --short master) to "
		echo -n "$(git rev-parse --short origin/master))"
		git pull --quiet

		# Restart the init script if it self updated
		if [ "$reponame" == "dotfiles" ]; then
			cd $olddir
			exec $SCRIPTPATH -u;
		fi

  fi

	cd $olddir
}

if [ $u ]; then echo "UPDATING..."; fi

HOMEREPO="$HOME/.dotfiles"
HOMEREPOlit='~/.dotfiles'

# Update dotfiles repo
if [ $u ]; then
	updategitrepo "dotfiles" "profile configs" $HOMEREPO
fi

shopt -s dotglob
for dotfile in $(find $HOMEREPO -maxdepth 1 -type f -iname ".*")
do
	if [ "$(basename $dotfile)" != ".editorconfig" ] && [ "$(basename $dotfile)" != ".gitignore" ]; then
		target=$HOME/$(basename $dotfile)
		if [ -f "$target" ] && [ ! -L "$target" ]; then
			rm $target
			echo "NOTE: Found existing $(basename $dotfile) in HOME, removing..."
		fi
		[ ! -r $target ] && ln -s $dotfile $target && echo "NOTE: Linked ~/$(basename $dotfile) to custom one in dotfiles repo"
	fi
done

# Create dir for installation of packages for dotfiles
mkdir -p $HOMEREPO/opt
mkdir -p $HOMEREPO/opt/bin

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
cd $curpath


#Setup Pathogen
mkdir -p ~/.vim/autoload ~/.vim/bundle && \
curl -LSso ~/.vim/autoload/pathogen.vim https://tpo.pe/pathogen.vim
	if [ $u ]; then
		echo ""
		echo "--Updating Pathogen"
		curl -LSso ~/.vim/autoload/pathogen.vim https://tpo.pe/pathogen.vim
	fi

#VIM Theme: Badwolf
if [ ! -d "$HOME/.vim/bundle/badwolf" ]; then
	git clone https://github.com/sjl/badwolf/ ~/.vim/bundle/badwolf
elif [ $u ]; then updategitrepo "BadWolf" "VIM theme" ~/.vim/bundle/badwolf ;
fi

#VIM Theme: Solarized
if [ ! -d "$HOME/.vim/bundle/vim-colors-solarized" ]; then
	git clone git://github.com/altercation/vim-colors-solarized.git ~/.vim/bundle/vim-colors-solarized
elif [ $u ]; then updategitrepo "Solarized" "VIM theme" ~/.vim/bundle/vim-colors-solarized ;
fi

#VIM Plugin: gUndo (Undo on steriods)
if [ ! -d "$HOME/.vim/bundle/gundo" ]; then
	git clone http://github.com/sjl/gundo.vim.git ~/.vim/bundle/gundo
elif [ $u ]; then updategitrepo "gUndo" "VIM undo plugin" ~/.vim/bundle/gundo ;
fi

#Perl binary: Ack (searcher)
if [ ! -f "$HOMEREPO/opt/bin/ack" ]; then
	curl https://beyondgrep.com/ack-2.18-single-file > "$HOMEREPO/opt/bin/ack" && chmod 0755 "$HOMEREPO/opt/bin/ack"
fi

#Perl binary: diff-so-fancy (better git diff)
if [ ! -f "$HOMEREPO/opt/bin/diff-so-fancy" ]; then
	echo ""; echo "Pulling down: diff-so-fancy (better git diff)"
  curl https://raw.githubusercontent.com/so-fancy/diff-so-fancy/master/third_party/build_fatpack/diff-so-fancy > "$HOMEREPO/opt/bin/diff-so-fancy" && chmod 0755 "$HOMEREPO/opt/bin/diff-so-fancy"
elif [ $u ]; then
	echo ""; echo "--Updating diff-so-fancy"
  curl https://raw.githubusercontent.com/so-fancy/diff-so-fancy/master/third_party/build_fatpack/diff-so-fancy > "$HOMEREPO/opt/bin/diff-so-fancy" && chmod 0755 "$HOMEREPO/opt/bin/diff-so-fancy"
fi

#VIM Plugin: ack (Search files/folders within VIM)
#TODO: Requires silver searcher (ag) to be installed
if [ ! -d "$HOME/.vim/bundle/ack.vim" ]; then
	git clone https://github.com/mileszs/ack.vim.git ~/.vim/bundle/ack.vim
elif [ $u ]; then updategitrepo "ack.vim" "VIM search plugin" ~/.vim/bundle/ack.vim ;
fi

#VIM Plugin: vim-airline (light weight vim powerline) + themes
if [ ! -d "$HOME/.vim/bundle/vim-airline" ]; then
	git clone https://github.com/vim-airline/vim-airline ~/.vim/bundle/vim-airline
elif [ $u ]; then updategitrepo "vim-airline" "VIM status bar plugin" ~/.vim/bundle/vim-airline ;
fi

if [ ! -d "$HOME/.vim/bundle/vim-airline-themes" ]; then
	git clone https://github.com/vim-airline/vim-airline-themes ~/.vim/bundle/vim-airline-themes
elif [ $u ]; then updategitrepo "vim-airline-themes" "vim-airline themes" ~/.vim/bundle/vim-airline-themes ;
fi

#VIM Plugin: vim-gitgutter (git plugin)
if [ ! -d "$HOME/.vim/bundle/vim-gitgutter" ]; then
	git clone git://github.com/airblade/vim-gitgutter.git ~/.vim/bundle/vim-gitgutter
elif [ $u ]; then updategitrepo "vim-gitgutter" "VIM git statusbar plugin" ~/.vim/bundle/vim-gitgutter ;
fi

#VIM Plugin: Adds git capabilities to VIM
if [ ! -d "$HOME/.vim/bundle/vim-fugitive" ]; then
	git clone https://github.com/tpope/vim-fugitive.git ~/.vim/bundle/vim-fugitive
elif [ $u ]; then updategitrepo "vim-fugitive" "VIM git plugin" ~/.vim/bundle/vim-fugitive ;
fi

#VIM Plugin: Add commenting capabilities to VIM
if [ ! -d "$HOME/.vim/bundle/nerdcommenter" ]; then
	echo "- Installing: nerdcommenter (VIM commenting plugin)";
	git clone https://github.com/scrooloose/nerdcommenter.git ~/.vim/bundle/nerdcommenter; echo ""
elif [ $u ]; then updategitrepo "nerdcommenter" "VIM commenting plugin" ~/.vim/bundle/nerdcommenter ;
fi

# Regenerate VIM help catalog
vim -c 'call pathogen#helptags()|q'

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

#Write last update file
if [ ! -f $HOMEREPO/opt/lastupdate ]; then
	date +%s > $HOMEREPO/opt/lastupdate
	date '+%A %F %I:%M:%S %p %Z' >> $HOMEREPO/opt/lastupdate
elif [ $u ]; then
	echo ""
	echo "Updating last update time file with current date"
	date +%s > $HOMEREPO/opt/lastupdate
	date '+%A %F %I:%M:%S %p %Z' >> $HOMEREPO/opt/lastupdate
fi

if [ $u ]; then
	echo ""
	echo "UPDATING Completed!"
fi
