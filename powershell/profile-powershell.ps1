$HOMEREPO="$HOME\.dotfiles"
$HOMEREPOlit='~\.dotfiles'

# Source my powershell polyfills
. "$HOMEREPO\powershell\powershell-polyfills.ps1"

# Source my powershell functions
. "$HOMEREPO\powershell\powershell-functions.ps1"

# Source Powershell Profile Updater 
. "$HOMEREPO\powershell\powershell-dotfilesupdater.ps1"

# Source git prompt
. "$HOMEREPO\powershell\powershell-gitprompt.ps1"

#Use LineFeeds in Repo, Not CarriageReturn+LineFeeds
#Needed if using Windows Subsystem for Linux and Powershell on same repo
git config --global core.autocrlf false
git config --global core.eol lf

# Enable Tab Expansion using `MenuComplete` style
Set-PSReadlineKeyHandler -Key Tab -Function MenuComplete