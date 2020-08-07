$HOMEREPO="$HOME\.dotfiles"

# Source my powershell polyfills
. "$HOMEREPO\powershell\powershell-polyfills.ps1"

# Source my powershell functions/installers
. "$HOMEREPO\powershell\powershell-functions.ps1"
. "$HOMEREPO\powershell\powershell-installers.ps1"

# Source Powershell Profile Updater
. "$HOMEREPO\powershell\powershell-dotfilesupdater.ps1"

# Source git prompt
. "$HOMEREPO\powershell\powershell-gitprompt.ps1"

# Source Powershell Aliases
. "$HOMEREPO\powershell\powershell-aliases.ps1"

################
# Git Settings #
################
#Use LineFeeds in Repo, Not CarriageReturn+LineFeeds
#Needed if using Windows Subsystem for Linux and Powershell on same repo
git config --global core.autocrlf false
git config --global core.eol lf

# Set GIT Config Settings
if (Check-Command git) {
  git config --global --unset-all include.path
  git config --global --add include.path '~/.dotfiles/git/git_tweaks'
}

if (Check-Command delta) {
  $env:GIT_PAGER = 'delta' # Set Git Pager for session
  git config --global --add include.path '~/.dotfiles/git/git_deltadiff'
} elseif (Check-Command "diff-so-fancy") {
  $env:GIT_PAGER='diff-so-fancy | less' # Set Git Pager for session
  $env:LESS="-x2 -RFX $LESS" # Set LESS settings for session
  git config --global --add include.path '~/.dotfiles/git/git_diffsofancy' # Include diff-so-fancy colors
} else {
  git config --global --unset-all include.path '~/.dotfiles/git/git_diffsofancy'
  git config --global --unset-all include.path '~/.dotfiles/git/git_deltadiff'
}

# Enable Tab Expansion using `MenuComplete` style
Set-PSReadlineKeyHandler -Key Tab -Function MenuComplete

# Add dotfiles bin to PATH
If (!($env:PATH -like "*$HOME/.dotfiles/opt/bin*")) {
  $env:PATH += ";$HOME/.dotfiles/opt/bin"
}