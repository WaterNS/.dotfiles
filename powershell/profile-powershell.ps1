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

# Source Visual Studio helpers
. "$HOMEREPO\powershell\powershell-visualstudio.ps1"

### History Stuffs
. "$HOMEREPO\powershell\powershell-history.ps1"

################
# Git Settings #
################
$shouldMutateGitGlobalConfig = (Check-Command git) -and -not (Test-IsNonInteractiveInvocation)

#Use LineFeeds in Repo, Not CarriageReturn+LineFeeds
#Needed if using Windows Subsystem for Linux and Powershell on same repo
if ($shouldMutateGitGlobalConfig) {
  Set-GitGlobalValue "core.autocrlf" "false"
  Set-GitGlobalValue "core.eol" "lf"
}

# Set GIT Config Settings
if ($shouldMutateGitGlobalConfig) {
  Ensure-GitGlobalIncludePath '~/.dotfiles/git/git_tweaks'

  if ([version]$(((git --version) -replace('[^0-9.]')).split('.')[0..2] -join (".")) -gt [version]'2.21') {
    Set-GitGlobalValue "log.date" 'auto:format:%a %Y-%h-%d %I:%M %p %z %Z'
  }
  else {
    git config --global --unset-all log.date 2>$null
  }
}

if (Check-Command delta) {
  $env:GIT_PAGER = 'delta' # Set Git Pager for session
  if ($shouldMutateGitGlobalConfig) {
    Ensure-GitGlobalIncludePath '~/.dotfiles/git/git_deltadiff'
    Remove-GitGlobalIncludePath '~/.dotfiles/git/git_diffsofancy'
  }
} elseif (Check-Command "diff-so-fancy") {
  $env:GIT_PAGER='diff-so-fancy | less' # Set Git Pager for session
  $env:LESS="-x2 -RFX $LESS" # Set LESS settings for session
  if ($shouldMutateGitGlobalConfig) {
    Ensure-GitGlobalIncludePath '~/.dotfiles/git/git_diffsofancy' # Include diff-so-fancy colors
    Remove-GitGlobalIncludePath '~/.dotfiles/git/git_deltadiff'
  }
} else {
  if ($shouldMutateGitGlobalConfig) {
    Remove-GitGlobalIncludePath '~/.dotfiles/git/git_diffsofancy'
    Remove-GitGlobalIncludePath '~/.dotfiles/git/git_deltadiff'
  }
}

# Enable Tab Expansion using `MenuComplete` style
Set-PSReadlineKeyHandler -Key Tab -Function MenuComplete

# Add dotfiles bin to PATH - Dynamically downloaded binaries
If (!($env:PATH -like "*$HOME/.dotfiles/opt/bin*")) {
  $env:PATH += ";$HOME/.dotfiles/opt/bin"
}
# Add dotfiles bin-win to PATH - Statically provided binaries
If (!($env:PATH -like "*$HOME/.dotfiles/bin-win*")) {
  $env:PATH += ";$HOME/.dotfiles/bin-win"
}

# Python2 helper for Windows
if ((Test-Path "C:\Python27\python2.exe") -and !($env:PATH -like "*C:\Python27\*")) {
  $env:PATH += ";C:\Python27\"
}

# Python3 helper for Windows
if ((Test-Path "$HOME\.dotfiles\opt\bin\python3\python.exe")) {
  if (!($env:PATH -like "*.dotfiles\opt\bin\python3*")) {
    $env:PATH += ";$HOME\.dotfiles\opt\bin\python3\"
    $env:PATH += ";$HOME\.dotfiles\opt\bin\python3\Scripts"
  }
  Set-Alias python "$HOME\.dotfiles\opt\bin\python3\python.exe"
  Set-Alias python3 "$HOME\.dotfiles\opt\bin\python3\python.exe"
}

# Source Powershell Logout Script
. "$HOMEREPO\powershell\powershell-logout.ps1"
