# DOTFILES updater

If (Test-IsNonInteractiveShell) {
	#Do Nothing if in Non-Interactive Shell
}
else{ #Presumed interactive or otherwise shell
	# Time, in seconds, between updates
	$maxtime=$((5*24*60*60))

	if (Test-Path $HOME\.dotfiles\opt\lastupdate -PathType Leaf) {
		$oldtime=$(head -n 1 $HOME/.dotfiles/opt/lastupdate)
		$newtime=[int](Get-Date (Get-Date).ToUniversalTime() -UFormat %s)
		$difftime=$(($newtime-$oldtime))
	}

  $SHAinitscript=$(git --git-dir "$HOME/.dotfiles/.git" log -n 1 --pretty=format:%H -- init_powershell.ps1)

  # Check if last init is set or , kick off update if so
  if ( (!(Test-Path $HOME/.dotfiles/opt/lastinit)) -OR ($SHAinitscript -ne (Get-Content $HOME/.dotfiles/opt/lastinit | Select-Object -Index 1)) ) {
    if (!(Test-Path $HOME/.dotfiles/opt/lastinit)) {
      "No init time file found, running initialization now"
    } else {
      "Init script has been updated since last run, Executing init_powershell.ps1 with ReInitialization flag"
    }
    & "$HOME/.dotfiles/init_powershell.ps1" -r
  }
	# Check if last update was longer than set interval, kick off update if so
	elseif ( ($difftime -gt $maxtime) -OR (! (Test-Path $HOME\.dotfiles\opt\lastupdate))) {
		if (!(Test-Path $HOME\.dotfiles\opt\lastupdate)) {
			"No update time file found, running update now"
		} else {
			"Last update happened $(seconds2time $difftime) ago, updating dotfiles"
		}

		~\.dotfiles\init_powershell.ps1 -update
		"Reloading profile... (should find some way to `'exec powershell`')"
		"------------------"
		. $profile
	}
	else {
		Write-Host "Last dotfiles update: $(seconds2time $difftime) ago / Update Interval: $(seconds2time $maxtime)"
	}
}
