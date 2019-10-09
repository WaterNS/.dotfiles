#!/bin/sh

SCRIPTDIR=$( cd "$(dirname "$0")" || exit ; pwd -P )
SCRIPTPATH=$SCRIPTDIR/$(basename "$0")
cmdlineargs=""

# Check passed options/args
while getopts ":ur" opt ; do
  case $opt in
    u) u=true && cmdlineargs="-u";; # Handle -u, for Update flag
    r) r=true && cmdlineargs="-r";; # Handle -r, for ReInit flag
    *) ;;
  esac
done

### Set ZSH to word split IFS
if [ "$ZSH_VERSION" ]; then
  setopt sh_word_split
fi

# Source posix functions
if [ -f "$HOME/.dotfiles/posixshells/posix_functions.sh" ]; then
  . "$HOME/.dotfiles/posixshells/posix_functions.sh"
fi

# Source installer functions
if [ -f "$HOME/.dotfiles/posixshells/posix_installers.sh" ]; then
  . "$HOME/.dotfiles/posixshells/posix_installers.sh"
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
    printf -- "--Updating %s %s repo " "$reponame" "$description"
    printf "(from %s to " "$(git rev-parse --short master)"
    printf "%s)" "$(git rev-parse --short origin/master)"
    git pull origin master --quiet

    # Restart the init script if it self updated
    if [ "$reponame" = "dotfiles" ]; then
      cd "$olddir" || return
      echo ""
      echo ""
      exec "$SCRIPTPATH" "$cmdlineargs";
    fi

  fi

  cd "$olddir" || return
}

if [ $r ]; then
  echo "ReInitializing...";
elif [ $u ]; then
  echo "UPDATING...";
fi

HOMEREPO="$HOME/.dotfiles"

# Update dotfiles repo
if [ $u ]; then
  updategitrepo "dotfiles" "profile configs" "$HOMEREPO"
fi

# Script to link dotfiles from home folder to dotfiles versions
"$HOME/.dotfiles/posixshells/posix_dotfilelinker.sh"

# If ReInitializing, remove existing bin folders
if [ $r ] && [ -d "$HOMEREPO/opt" ]; then
	if [ -d "$HOMEREPO/opt" ]; then rm -rf "$HOMEREPO/opt"; fi
	if contains "$(uname)" "Darwin"; then
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

# Create .zprofile (zsh) if doesn't exist
if [ ! -f ~/.zprofile ]; then
	echo 'NOTE: .zprofile (zsh) not found, creating!'
	touch ~/.zprofile
	echo '#!/bin/zsh' >> ~/.zprofile
fi

# Source .bashrc in existing .bash_profile
if ! grep -q "bashrc" ~/.bash_profile; then
	echo 'NOTE: .bash_profile found, but missing reference to ~/.bashrc, adding!'
	echo "source ~/.bashrc" >> ~/.bash_profile
fi

# Source .zshrc in existing .zprofile (zsh)
if ! grep -q "zshrc" ~/.zprofile; then
	echo 'NOTE: .zprofile found, but missing reference to ~/.zshrc, adding!'
	echo "source ~/.zshrc" >> ~/.zprofile
fi

# Set .dotfiles git repo setting
curpath=$PWD
cd "$HOMEREPO" || exit
git config user.name "User"
git config user.email waterns@users.noreply.github.com
git config push.default matching
if [ ! -f ~/.ssh/id_rsa ] && [ ! -f ~/.ssh/WaterNS ]; then
  echo "Creating ~/.ssh/WaterNS"
  ssh-keygen -t rsa -b 4096 -f ~/.ssh/WaterNS -N ""
fi
if [ -f ~/.ssh/WaterNS ]; then
	git config core.sshCommand "ssh -i ~/.ssh/WaterNS"
fi
cd "$curpath" || exit

# Install VIM plugins
. "$HOMEREPO/vim/init_vim.sh"

# Make dev tools available in dotfiles bin
install_diffsofancy
install_jq
install_shellcheck
install_shfmt
install_lsd
install_prettyping

#Write last update file
SHAinitupdated=$(git --git-dir "$HOMEREPO/.git" log -n 1 --pretty=format:%H -- init_posix.sh)
if [ ! -f "$HOMEREPO/opt/lastupdate" ] || [ ! -f "$HOMEREPO/opt/lastinit" ]; then
	if [ ! -f "$HOMEREPO/opt/lastupdate" ]; then
		date +%s > "$HOMEREPO/opt/lastupdate"
		date '+%A %F %I:%M:%S %p %Z' >> "$HOMEREPO/opt/lastupdate"
	fi

	if [ ! -f "$HOMEREPO/opt/lastinit" ]; then
		echo "Last commit at which init_posix.sh initialization ran:" > "$HOMEREPO/opt/lastinit"
		echo "$SHAinitupdated" >> "$HOMEREPO/opt/lastinit"
	fi
elif [ $u ] || [ $r ]; then
	if [ $u ]; then
		echo ""
		echo "Updating last update time file with current date"
		date +%s > "$HOMEREPO/opt/lastupdate"
		date '+%A %F %I:%M:%S %p %Z' >> "$HOMEREPO/opt/lastupdate"
	fi

	if [ $r ]; then
		echo ""
		echo "Updating lastinit time with current SHA: $SHAinitupdated"
	  echo "Last commit at which init_posix.sh initialization ran:" > "$HOMEREPO/opt/lastinit"
	  echo "$SHAinitupdated" >> "$HOMEREPO/opt/lastinit"
	fi
fi

if [ $r ]; then
	echo ""
	echo "ReINITIALIZATION Completed!"
elif [ $u ]; then
	echo ""
	echo "UPDATING Completed!"
fi