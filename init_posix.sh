#!/bin/sh

export RUNNINGINITSCRIPT=true
SCRIPTDIR=$( cd "$(dirname "$0")" || exit ; pwd -P )
SCRIPTPATH=$SCRIPTDIR/$(basename "$0")
export SCRIPTPATHINIT="$SCRIPTPATH"
INITSCRIPTARGS=""
HOMEREPO="$HOME/.dotfiles"
PATH=$PATH:$HOMEREPO/bin

# Check passed options/args
while getopts ":ur" opt ; do
  case $opt in
    u) u=true && INITSCRIPTARGS="-u";; # Handle -u, for Update flag
    r) r=true && INITSCRIPTARGS="-r";; # Handle -r, for ReInit flag
    *) ;;
  esac
done
export INITSCRIPTARGS

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

# Mac: Check if Full Disk Access is available -- if not prompt and exit
if [ "$OS_FAMILY" = "Darwin" ]; then
  if ! plutil -lint /Library/Preferences/com.apple.TimeMachine.plist >/dev/null; then
    echo "This script requires your terminal app to have Full Disk Access."
    echo "Add this terminal to the Full Disk Access list in System Preferences > Security & Privacy, quit the app, and re-run this script."

    osascript <<EOF
      display dialog "This script requires Full Disk Access for Terminal. Please enable it in System Settings → Privacy & Security → Full Disk Access." buttons {"OK"} default button 1
EOF

    open "x-apple.systempreferences:com.apple.preference.security?Privacy_All"

    exit 1
  fi
fi

# Preload Rosetta (lot of utils aren't compiled for ARM in macOS space)
if [ "$OS_FAMILY" = "Darwin" ]; then
  setMacTerminalDefaultTheme
  install_macRosetta2
fi

# Preload Git (if not yet available)
install_git

# Ignore git config and force git output in English to make our work easier
git_eng="env LANG=C GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG=/dev/null HOME=/dev/null git"

if [ "$r" ]; then
  echo "ReInitializing...";
elif [ "$u" ]; then
  echo "UPDATING...";
fi

# Init dotfiles repo (if came from tarball/zip)
if [ -z "$(git -C "$HOMEREPO" remote show origin 2>/dev/null)" ]; then
  echo "Init $HOMEREPO dotfiles remote git connection..."
  reHydrateRepo "$HOMEREPO" "https://github.com/WaterNS/.dotfiles.git"
fi

# Update dotfiles repo
if [ "$u" ]; then
  updateGitRepo "dotfiles" "profile configs" "$HOMEREPO"
fi

# Script to link dotfiles from home folder to dotfiles versions
"$HOME/.dotfiles/posixshells/posix_dotfilelinker.sh"

# If ReInitializing, remove existing bin folders
if [ "$r" ] && [ -d "$HOMEREPO/opt" ]; then
	if [ -d "$HOMEREPO/opt" ]; then rm -rf "$HOMEREPO/opt"; fi
	if [ "$OS_FAMILY" = "Darwin" ]; then
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

## Below appears to be wrong. Commenting out.
## Source .zshrc in existing .zprofile (zsh)
#if ! grep -q "zshrc" ~/.zprofile; then
#	echo 'NOTE: .zprofile found, but missing reference to ~/.zshrc, adding!'
#	echo "source ~/.zshrc" >> ~/.zprofile
#fi

# Set .dotfiles git repo setting
currentPath=$PWD
cd "$HOMEREPO" || exit
git config user.name "User"
git config user.email waterns@users.noreply.github.com
git config push.default matching
if [ ! -f ~/.ssh/id_rsa ] && [ ! -f ~/.ssh/WaterNS ]; then
  install_opensshkeygen # ssh-keygen is required to generate key
  echo "Creating ~/.ssh/WaterNS"
  ssh-keygen -t rsa -b 4096 -f ~/.ssh/WaterNS -N "" -q;
  echo "";
fi
if [ -f ~/.ssh/WaterNS ]; then
	git config core.sshCommand "ssh -i $HOME/.ssh/WaterNS" # Use expanding $HOME value to hardcode
fi
cd "$currentPath" || exit

# Make dev tools available in dotfiles bin
install_opensshkeygen
install_tput
install_less
install_vim
install_jq
install_diffsofancy
install_git_delta
install_bat
install_shellcheck
install_shfmt
install_lsd
install_blesh
install_whereis
install_tmux
install_trash
install_btop
install_htop

# Install VIM items
. "$HOMEREPO/vim/init_vim.sh"

# Init TMUX items
. "$HOMEREPO/tmux/init_tmux.sh"

# Install ZSH and its addons
#install_zsh
if [ -x "$(command -v zsh)" ]; then
  install_ohmyzsh
  . "$HOMEREPO/posixshells/zsh/init_zsh_addons.sh"
fi


# Update youtube-dl, if installed
if [ "$u" ] && [ -x "$(command -v youtube-dl)" ]; then
  youtube-dl -U
fi

# Init Darwin based systems
if [ "$OS_FAMILY" = "Darwin" ]; then
  . "$HOMEREPO/macOS/darwin_inits.sh"
fi

#Write last update file
. "$HOMEREPO/posixshells/init_log.sh"

if [ "$r" ]; then
	echo ""
	echo "ReINITIALIZATION Completed!"
elif [ "$u" ]; then
	echo ""
	echo "UPDATING Completed!"
fi
unset RUNNINGINITSCRIPT;
