# DOTFILES updater

If (Test-IsNonInteractiveShell) {
	#Do Nothing if in Non-Interactive Shell
}
else{ #Presumed interactive or otherwise shell
	# Time, in seconds, between updates
	$maxTime=$((5*24*60*60))

	if (Test-Path $HOME\.dotfiles\opt\lastUpdate -PathType Leaf) {
		$oldTime=$(head -n 1 $HOME/.dotfiles/opt/lastUpdate)
		$newTime=[int](Get-Date (Get-Date).ToUniversalTime() -UFormat %s)
		$diffTime=$(($newTime-$oldTime))
	}

  $shaInitScript=$(git --git-dir "$HOME/.dotfiles/.git" log -n 1 --pretty=format:%H -- init_powershell.ps1)

  # Check if last init is set or , kick off update if so
  if ( (!(Test-Path $HOME/.dotfiles/opt/lastInit)) -OR ($shaInitScript -ne (Get-Content $HOME/.dotfiles/opt/lastInit | Select-Object -Index 1)) ) {
    if (!(Test-Path $HOME/.dotfiles/opt/lastInit)) {
      "No init time file found, running initialization now"
    } else {
      "Init script has been updated since last run, Executing init_powershell.ps1 with ReInitialization flag"
    }
    & "$HOME/.dotfiles/init_powershell.ps1" -r
  }
	# Check if last update was longer than set interval, kick off update if so
	elseif ( ($diffTime -gt $maxTime) -OR (! (Test-Path $HOME\.dotfiles\opt\lastUpdate))) {
		if (!(Test-Path $HOME\.dotfiles\opt\lastUpdate)) {
			"No update time file found, running update now"
		} else {
			"Last update happened $(seconds2time $diffTime) ago, updating dotfiles"
		}

		~\.dotfiles\init_powershell.ps1 -update
		"Reloading profile... (should find some way to `'exec powershell`')"
		"------------------"
		. $profile
	}
	else {
		Write-Host "Last dotfiles update: $(seconds2time $diffTime) ago / Update Interval: $(seconds2time $maxTime)"
	}
}
