Param (
  [switch][Alias('u')]$update
)

# ToDo:
#  - Add Git Prompt
#  - Everything else
#    - foreach dot file linking?
#    - install less (for diff-so-fancy?)
#    - recreate .bashrc?


$SCRIPTDIR=$PSScriptRoot
$SCRIPTPATH=$PSCommandPath

$HOMEREPO="$HOME\.dotfiles"
$HOMEREPOlit='~\.dotfiles'

#Source our powershell polyfills & functions
. "$SCRIPTDIR\powershell\powershell-polyfills.ps1"
. "$SCRIPTDIR\powershell\powershell-functions.ps1"

#Check if Git is available
try {git | Out-Null}
catch [System.Management.Automation.CommandNotFoundException]
{
    "Git is unavailable - please install Git or add it to your path"
    exit 1
}

if ($update) {
  echo "UPDATING..."
  updategitrepo "dotfiles" "profile configs" "$HOMEREPO"
}

# Create dir for installation of packages for dotfiles
If (!(Test-Path $HOMEREPO/opt)) {mkdir -p $HOMEREPO/opt/bin > $null}

# Set .dotfiles repo setting
$curpath=$PWD
cd $HOMEREPO
git config user.name "User"
git config user.email waterns@users.noreply.github.com
git config push.default matching
cd $curpath


# Create Powershell Profile if doesn't exist
$ProfileFile="~\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
if (!(Test-Path $ProfileFile)) {
	
  echo "NOTE: $ProfileFile not found, creating!"
  If (!(Test-Path (Split-Path $ProfileFile))) {
    echo "  Profile folder not found, creating..."
    mkdir $(Split-Path $ProfileFile) > $null
  }

  touch $ProfileFile
  echo ""
}

$ProfileDotFile='$HOME\.dotfiles\powershell\profile-powershell.ps1'
if (!(Get-Content "$ProfileFile" | Where {$_ -like "*$ProfileDotFile*"})) {
  echo 'NOTE: Powershell Profile found, but missing reference to our dotfiles repo, adding!'
  echo ". $ProfileDotFile" >> $ProfileFile
}

#Perl binary: diff-so-fancy (better git diff)
if (!(Test-Path "$HOMEREPO/opt/bin/diff-so-fancy")) {
  echo ""; echo "Pulling down: diff-so-fancy (better git diff)"
  wget https://raw.githubusercontent.com/so-fancy/diff-so-fancy/master/third_party/build_fatpack/diff-so-fancy -UseBasicParsing -OutFile "$HOMEREPO/opt/bin/diff-so-fancy"
} elseif ($update) {
  echo ""; echo "--Updating diff-so-fancy"
  wget https://raw.githubusercontent.com/so-fancy/diff-so-fancy/master/third_party/build_fatpack/diff-so-fancy -UseBasicParsing -OutFile "$HOMEREPO/opt/bin/diff-so-fancy"
}



#Write last update file
if (!(Test-Path $HOMEREPO\opt\lastupdate -Type Leaf)) {
	[int](Get-Date (Get-Date).ToUniversalTime() -UFormat %s) > $HOMEREPO\opt\lastupdate
	((Get-Date -UFormat '%A %Y-%m-%d %I:%M:%S %p ')+(Get-TimeZone).ID) >> $HOMEREPO\opt\lastupdate
}
elseif ($update) {
	echo ""
	echo "Updating last update time file with current date"
	[int](Get-Date (Get-Date).ToUniversalTime() -UFormat %s) > $HOMEREPO\opt\lastupdate
	((Get-Date -UFormat '%A %Y-%m-%d %I:%M:%S %p ')+(Get-TimeZone).ID) >> $HOMEREPO\opt\lastupdate
}

if ($update) {
	echo ""
	echo "UPDATING Completed!"
}