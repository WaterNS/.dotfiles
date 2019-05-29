Param (
  [switch][Alias('u')]$update
)

# ToDo:
# - Handle changed init file? Rerun with -r
# - Everything else
#    - foreach dot file linking?
#    - install less (for diff-so-fancy?)
#    - recreate .bashrc?
#    - Backport gitprompt u/d/a to bash git prompt


$SCRIPTDIR=$PSScriptRoot
$SCRIPTPATH=$PSCommandPath #used in powershell-functions.ps1

$HOMEREPO="$HOME\.dotfiles"

#Source our powershell polyfills & functions & installers
. "$SCRIPTDIR\powershell\powershell-polyfills.ps1"
. "$SCRIPTDIR\powershell\powershell-functions.ps1"
. "$SCRIPTDIR\powershell\powershell-installers.ps1"

#Check if Git is available
try {git | Out-Null}
catch [System.Management.Automation.CommandNotFoundException]
{
    "Git is unavailable - please install Git or add it to your path"
    exit 1
}

# Import dotfiles gitconfig
git config --global include.path "~/.dotfiles/git/git_tweaks"

if ($update) {
  Write-Output "UPDATING..."
  updategitrepo "dotfiles" "profile configs" "$HOMEREPO"
}

# Create dir for installation of packages for dotfiles
If (!(Test-Path $HOMEREPO/opt)) {New-Item $HOMEREPO/opt/bin -ItemType Directory > $null}

# Add dotfiles bin to user environment variable (permanently)
$ExistingUserPath = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::User)
If (!($ExistingUserPath -like "*$HOME/.dotfiles/opt/bin*")) {
  [Environment]::SetEnvironmentVariable(
    "Path",
    $ExistingUserPath + ";$HOME/.dotfiles/opt/bin",
    [EnvironmentVariableTarget]::User
  )
}

# Set .dotfiles repo setting
$curpath=$PWD
Set-Location $HOMEREPO
git config user.name "User"
git config user.email waterns@users.noreply.github.com
git config push.default matching
if (Test-Path ~/.ssh/WaterNS) {
  git config core.sshCommand "ssh -i ~/.ssh/WaterNS"
}
Set-Location $curpath


# Create Powershell Profile if doesn't exist
$ProfileFile=$PROFILE
If (!(Test-Path (Split-Path $ProfileFile))) {
  Write-Output "  Profile folder not found, creating..."
  New-Item $(Split-Path $ProfileFile) -ItemType Directory > $null
}
if (!(Test-Path $ProfileFile)) {
  Write-Output "NOTE: $ProfileFile not found, creating!"
  touch $ProfileFile
  Write-Output ""
}



#Add Reference to our dotfile profile to each Powershell profile we use
$ProfileDotFile='$HOME\.dotfiles\powershell\profile-powershell.ps1'
if (!(Get-Content "$ProfileFile" | Where-Object {$_ -like "*$ProfileDotFile*"})) {
  Write-Output 'NOTE: Powershell Profile found, but missing reference to our dotfiles repo, adding!'
  Write-Output ". $ProfileDotFile" >> $ProfileFile
}

# Create VS Code Powershell Profile if doesn't exist
If (Test-Path "~\Documents") { 
  #Only run if ~\Documents exists, 
  # places like Azure hosted Shell don't have a ~\Documents folder

  $VSCodeProfileFile="~\Documents\WindowsPowerShell\Microsoft.VSCode_profile.ps1"
  if (!(Test-Path $VSCodeProfileFile)) {
    Write-Output "NOTE: $VSCodeProfileFile not found, creating!"
    touch $VSCodeProfileFile
    Write-Output ""
  }
  if (!(Get-Content "$VSCodeProfileFile" | Where-Object {$_ -like "*$ProfileDotFile*"})) {
    Write-Output 'NOTE: VSCode Powershell Profile found, but missing reference to our dotfiles repo, adding!'
    Write-Output ". $ProfileDotFile" >> $VSCodeProfileFile
  }

  # VS Code settings.json
  $VSCodeSettingsRepoFile="$HOME\.dotfiles\vscode\settings.json"
  $VScodeSettingsdir="$env:APPDATA\Code\User\"
  $VSCodeSettingsFile="$env:APPDATA\Code\User\settings.json"
  If (-NOT (Test-Path "$VScodeSettingsdir")) {
    Write-Output "No vscode user dir found, creating"
    mkdir $VScodeSettingsdir > $null
  }
  If (Test-Path "$VSCodeSettingsFile") {

    If (-NOT (Get-Item "$VSCodeSettingsFile" | Select-Object -ExpandProperty Target) -like "*VSCodeSettingsRepoFile*") {
      Write-Output "Found existing VScode file, removing"
      Remove-Item "$VSCodeSettingsFile"
    }

  }

  If (-NOT (Test-Path "$VSCodeSettingsFile")) {
    # Requires Admin Permissions
    Write-Output "Linking $VSCodeSettingsFile to $VSCodeSettingsRepoFile"
    New-Item -ItemType SymbolicLink -Path "$VSCodeSettingsFile" -Value "$VSCodeSettingsRepoFile" > $null
  }

}


#Perl binary: diff-so-fancy (better git diff)
if (!(Test-Path "$HOMEREPO/opt/bin/diff-so-fancy")) {
  Write-Output ""; Write-Output "Pulling down: diff-so-fancy (better git diff)"
  Invoke-WebRequest https://raw.githubusercontent.com/so-fancy/diff-so-fancy/master/third_party/build_fatpack/diff-so-fancy -UseBasicParsing -OutFile "$HOMEREPO/opt/bin/diff-so-fancy"
} elseif ($update) {
  Write-Output ""; Write-Output "--Updating diff-so-fancy"
  Invoke-WebRequest https://raw.githubusercontent.com/so-fancy/diff-so-fancy/master/third_party/build_fatpack/diff-so-fancy -UseBasicParsing -OutFile "$HOMEREPO/opt/bin/diff-so-fancy"
}

# Install some handy dev tools
install-jq
install-shellcheck
install-shfmt

#Write last update file
if (!(Test-Path $HOMEREPO\opt\lastupdate -Type Leaf)) {
	[int](Get-Date (Get-Date).ToUniversalTime() -UFormat %s) > $HOMEREPO\opt\lastupdate
	((Get-Date -UFormat '%A %Y-%m-%d %I:%M:%S %p ')+(Get-TimeZone).ID) >> $HOMEREPO\opt\lastupdate
}
elseif ($update) {
	Write-Output ""
	Write-Output "Updating last update time file with current date"
	[int](Get-Date (Get-Date).ToUniversalTime() -UFormat %s) > $HOMEREPO\opt\lastupdate
	((Get-Date -UFormat '%A %Y-%m-%d %I:%M:%S %p ')+(Get-TimeZone).ID) >> $HOMEREPO\opt\lastupdate
}

if ($update) {
	Write-Output ""
	Write-Output "UPDATING Completed!"
}