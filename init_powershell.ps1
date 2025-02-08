Param (
  [switch][Alias('u')]$update,
  [switch][Alias('r')]$reInit
)

$SCRIPTDIR=$PSScriptRoot
$SCRIPTPATH=$PSCommandPath
$SCRIPTARGS=$PSBoundParameters

$HOMEREPO="$HOME\.dotfiles"

$cmdArgs=""
foreach ($arg in $SCRIPTARGS.GetEnumerator()) {
  $cmdArgs+="-"+$arg.key
}

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
if (! ($(git config --global --get-all include.path) -like "*.dotfiles/git/git_tweaks*")) {
  git config --global --add include.path "~/.dotfiles/git/git_tweaks"
}


if ($reInit) {
  Write-Output "Reinitializing..."
  $update = $true
} elseif ($update) {
  Write-Output "UPDATING..."
}

if ($update) {
  updateGitRepo "dotfiles" "profile configs" "$HOMEREPO"
}

if ($reInit) {Remove-Item "$HOMEREPO/opt" -Recurse}

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
$currentPath=$PWD
Set-Location $HOMEREPO
git config user.name "User"
git config user.email waterns@users.noreply.github.com
git config push.default matching

if (!(Test-Path "$HOME/.ssh/WaterNS")) {
  Write-Host "Creating ~/.ssh/WaterNS"
  ssh-keygen -t rsa -b 4096 -f "$HOME/.ssh/WaterNS" -q -N '""' -C '""';
}
if (Test-Path ~/.ssh/WaterNS) {
  git config core.sshCommand "ssh -i ~/.ssh/WaterNS"
}
Set-Location $currentPath


# Create Powershell Profile(s), if they don't exist
$PowerShellProfileFiles = @(
  "$HOME\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1", # Powershell 5.1 and Prior
  "$HOME\Documents\PowerShell\Microsoft.VSCode_profile.ps1", # VsCode Powershell Integrated Console
  "$HOME\Documents\PowerShell\Microsoft.PowerShell_profile.ps1" # Powershell 7+
)

foreach ($ProfileFile in $PowerShellProfileFiles) {
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

  # VS Code env config files: settings.json, and perhaps others
  $vsCodeEnvFiles = 'settings.json'
  foreach ($envFile in $vsCodeEnvFiles) {
    $RepoVSCodeEnvFile="$HOME\.dotfiles\vscode\$envFile"
    $VSCodeEnvDir="$env:APPDATA\Code\User"
    $VSCodeEnvFile="$VSCodeEnvDir\$envFile"

    If (-NOT (Test-Path "$VSCodeEnvDir")) {
      Write-Output "No VSCode user environment directory found, creating..."
      mkdir $VSCodeEnvDir > $null
    }
    If (Test-Path "$VSCodeEnvFile") {
      If (-NOT (Get-Item "$VSCodeEnvFile" | Select-Object -ExpandProperty Target) -like "*$RepoVSCodeEnvFile*") {
        Write-Output "Found existing VScode $envFile, moving to ~/.dotfiles incase need to review/crib"
        Move-Item "$VSCodeEnvFile" -Destination "~/.dotfiles/$((get-date).ToString('M-d-y-HH:mm'))-$envFile"
      }
    }

    If (-NOT (Test-Path "$VSCodeEnvFile")) {
      # Requires Admin Permissions
      Write-Output "Linking $VSCodeEnvFile to $RepoVSCodeEnvFile"
      New-Item -ItemType SymbolicLink -Path "$VSCodeEnvFile" -Value "$RepoVSCodeEnvFile" > $null
    }
  }

}


# Install some handy dev tools
install-jq
install-shellcheck
install-shfmt
install-less
install-cht
install-delta
install-diffsofancy
install-bat
install-cloc
install-ntop
install-monitorian
install-classicNotepad

#Write update/init file
$shaInitUpdated=$(git --git-dir "$HOME/.dotfiles/.git" log -n 1 --pretty=format:%H -- init_powershell.ps1)
if ((!(Test-Path $HOMEREPO\opt\lastUpdate -Type Leaf)) -OR (!(Test-Path $HOMEREPO\opt\lastInit -Type Leaf))) {
  if (!(Test-Path $HOMEREPO\opt\lastUpdate -Type Leaf)) {
    [int](Get-Date (Get-Date).ToUniversalTime() -UFormat %s) > $HOMEREPO\opt\lastUpdate
    ((Get-Date -UFormat '%A %Y-%m-%d %I:%M:%S %p ')+(Get-TimeZone).ID) >> $HOMEREPO\opt\lastUpdate
  }

  if (!(Test-Path $HOMEREPO\opt\lastInit -Type Leaf)) {
    "Last commit at which init_powershell.ps1 initialization ran:" > $HOMEREPO\opt\lastInit
    "$shaInitUpdated" >> $HOMEREPO\opt\lastInit
  }
}
elseif (($update) -OR ($reInit)) {
  if ($update) {
    Write-Output ""
    Write-Output "Updating last update time file with current date"
    [int](Get-Date (Get-Date).ToUniversalTime() -UFormat %s) > $HOMEREPO\opt\lastUpdate
    ((Get-Date -UFormat '%A %Y-%m-%d %I:%M:%S %p ')+(Get-TimeZone).ID) >> $HOMEREPO\opt\lastUpdate
  }

  if ($reInit) {
    Write-Output ""
    Write-Output "Updating lastInit time with current SHA: $shaInitUpdated"
    "Last commit at which init_powershell.ps1 initialization ran:" > $HOMEREPO\opt\lastInit
    "$shaInitUpdated" >> $HOMEREPO\opt\lastInit
  }
}

if ($reInit) {
	Write-Output ""
	Write-Output "ReInitialization Completed!"
} elseif ($update) {
	Write-Output ""
	Write-Output "UPDATING Completed!"
}
