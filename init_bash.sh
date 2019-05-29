#!/bin/bash

SCRIPTDIR=$( cd "$(dirname "$0")" || exit ; pwd -P )
SCRIPTPATH=$SCRIPTDIR/$(basename "$0")
cmdlineargs=( "$@" )

# Check passed options/args
while getopts ":ur" opt ; do
	case $opt in
		u) u=1 ;; # Handle -u, for Update flag
		r) ri=1 && u=1 ;; #Handle -r, for ReInit flag
		*) ;;
	esac
done

# Source installer functions
if [ -f "$HOME/.dotfiles/bash/installerfunctions" ]; then
	. "$HOME/.dotfiles/bash/installerfunctions"
fi

# Function: Update git repo (if needed)
updategitrepo () {
	olddir=$PWD
	reponame=$1
	description=$2
	repolocation=$3

	#echo ""
	#echo "-Check updates: $reponame ($description)"
	cd "$repolocation" || return
	git fetch

	if [ "$(git rev-list --count master..origin/master)" -gt 0 ]; then
		echo -n "--Updating $reponame $description repo "
		echo -n "(from $(git rev-parse --short master) to "
		echo -n "$(git rev-parse --short origin/master))"
		git pull origin master --quiet

		# Restart the init script if it self updated
		if [ "$reponame" == "dotfiles" ]; then
			cd "$olddir" || return
			echo ""
			echo ""
			exec "$SCRIPTPATH" "${cmdlineargs[@]}";
		fi

  fi

	cd "$olddir" || return
}

if [ $ri ]; then
	echo "ReInitializing...";
elif [ $u ]; then
	echo "UPDATING...";
fi

HOMEREPO="$HOME/.dotfiles"

# Update dotfiles repo
if [ $u ]; then
	updategitrepo "dotfiles" "profile configs" "$HOMEREPO"
fi

shopt -s dotglob
#See https://github.com/koalaman/shellcheck/wiki/SC2044
while IFS= read -r -d '' dotfile
do
	if [ "$(basename "$dotfile")" != ".editorconfig" ] \
		&& [ "$(basename "$dotfile")" != ".gitignore" ] \
		&& [ "$(basename "$dotfile")" != ".gitattributes" ] \
		&& [ "$(basename "$dotfile")" != ".DS_Store" ]; then
		target=$HOME/$(basename "$dotfile")

		if [ -f "$target" ] && [ ! -L "$target" ]; then
			rm "$target"
			echo "NOTE: Found existing $(basename "$dotfile") in HOME, removing..."
		elif [ -L "$target" ] && [ ! "$(readlink "$target")" -ef "$dotfile" ]; then
			rm "$target"
			echo "NOTE: Found SYMBOLIC Link with incorrect path $(basename "$dotfile") in HOME, removing..."
		fi

		[ ! -r "$target" ] && ln -s "$dotfile" "$target" && echo "NOTE: Linked ~/$(basename "$dotfile") to custom one in dotfiles repo"
	fi
done <   <(find "$HOMEREPO" -type f -iname ".*" -not -path "*opt/*" -print0)

#Handle linking VSCode in OSX and Linux
if [[ $OSTYPE == darwin* ]] || [[ $OSTYPE == linux* ]]; then

	repovscodefile="$HOME/.dotfiles/vscode/settings.json"

	if [[ $OSTYPE == darwin* ]]; then
		vscodedir="$HOME/Library/Application Support/Code/User/"
		vscodefile="$HOME/Library/Application Support/Code/User/settings.json"
	elif [[ $OSTYPE == linux* ]]; then
		vscodedir="$HOME/.config/Code/User/"
		vscodefile="$HOME/.config/Code/User/settings.json"
	fi

	# Create VScode profile folder if doesn't exist
	if [ ! -d "$vscodedir" ]; then
		mkdir -p "$vscodedir"
	fi

	# Remove existing VScode file (if its not a linked one)
	if [ -f "$vscodefile" ] && [ ! -L "$vscodefile" ]; then
		rm "$vscodefile"
		echo "Found existing VScode file at $vscodefile, removing..."
	elif [ -L "$vscodefile" ] && [ ! "$(readlink "$vscodefile")" -ef "$repovscodefile" ]; then
		rm "$vscodefile"
		echo "NOTE: Found existing LINK for VSCode file but with incorrect path, removing..."
	fi

	[ ! -r "$vscodefile" ] && ln -s "$repovscodefile" "$vscodefile" && echo "NOTE: Linked $vscodefile to custom one at $repovscodefile"
fi

# If ReInitializing, remove existing bin folders
if [ $ri ] && [ -d "$HOMEREPO/opt" ]; then
	if [ -d "$HOMEREPO/opt" ]; then rm -rf "$HOMEREPO/opt"; fi
	if [[ $OSTYPE == darwin* ]]; then
		if [ -d "$HOME/Library/Fonts/dotfiles" ]; then
			rm -rf "$HOME/Library/Fonts/dotfiles";
		fi
	fi
fi

# Create dir for installation of packages for dotfiles
mkdir -p "$HOMEREPO/opt"
mkdir -p "$HOMEREPO/opt/bin"

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

# Set .dotfiles git repo setting
curpath=$PWD
cd "$HOMEREPO" || exit
git config user.name "User"
git config user.email waterns@users.noreply.github.com
git config push.default matching
if [ -f ~/.ssh/WaterNS ]; then
	git config core.sshCommand "ssh -i ~/.ssh/WaterNS"
fi
cd "$curpath" || exit

#Git: diff-so-fancy (better git diff)
if [ ! -f "$HOMEREPO/opt/bin/diff-so-fancy" ]; then
	echo ""; echo "Pulling down: diff-so-fancy (better git diff)"
  curl https://raw.githubusercontent.com/so-fancy/diff-so-fancy/master/third_party/build_fatpack/diff-so-fancy > "$HOMEREPO/opt/bin/diff-so-fancy" && chmod 0755 "$HOMEREPO/opt/bin/diff-so-fancy"; echo ""
elif [ $u ]; then
	echo ""; echo "--Updating diff-so-fancy"
  curl https://raw.githubusercontent.com/so-fancy/diff-so-fancy/master/third_party/build_fatpack/diff-so-fancy > "$HOMEREPO/opt/bin/diff-so-fancy" && chmod 0755 "$HOMEREPO/opt/bin/diff-so-fancy"; echo ""
fi

# Install VIM plugins
source "$HOMEREPO/vim/init_vim.sh"

# Make dev tools available in dotfiles bin
install_jq
install_shellcheck
install_lsd

#Write last update file
SHAinitupdated=$(git --git-dir "$HOMEREPO/.git" log -n 1 --pretty=format:%H -- init_bash.sh)
if [ ! -f "$HOMEREPO/opt/lastupdate" ] || [ ! -f "$HOMEREPO/opt/lastinit" ]; then
	if [ ! -f "$HOMEREPO/opt/lastupdate" ]; then
		date +%s > "$HOMEREPO/opt/lastupdate"
		date '+%A %F %I:%M:%S %p %Z' >> "$HOMEREPO/opt/lastupdate"
	fi

	if [ ! -f "$HOMEREPO/opt/lastinit" ]; then
		echo "Last commit at which init_bash.sh initialization ran:" > "$HOMEREPO/opt/lastinit"
		echo "$SHAinitupdated" >> "$HOMEREPO/opt/lastinit"
	fi
elif [ $u ] || [ $ri ]; then
	if [ $u ]; then
		echo ""
		echo "Updating last update time file with current date"
		date +%s > "$HOMEREPO/opt/lastupdate"
		date '+%A %F %I:%M:%S %p %Z' >> "$HOMEREPO/opt/lastupdate"
	fi

	if [ $ri ]; then
		echo ""
		echo "Updating lastinit time with current SHA: $SHAinitupdated"
	  echo "Last commit at which init_bash.sh initialization ran:" > "$HOMEREPO/opt/lastinit"
	  echo "$SHAinitupdated" >> "$HOMEREPO/opt/lastinit"
	fi
fi

if [ $ri ]; then
	echo ""
	echo "ReINITIALIZATION Completed!"
elif [ $u ]; then
	echo ""
	echo "UPDATING Completed!"
fi
