# DOTFILES updater

# Time, in seconds, between updates
$maxtime=$((5*24*60*60))


# Check if last update was longer than set interval, kick off update if so
if (Test-Path $HOME\.dotfiles\opt\lastupdate -PathType Leaf) {
	$oldtime=$(head -n 1 $HOME/.dotfiles/opt/lastupdate)
	$newtime=[int](Get-Date (Get-Date).ToUniversalTime() -UFormat %s)
	$difftime=$(($newtime-$oldtime))
}


if ( ($difftime -gt $maxtime) -OR (! (Test-Path $HOME\.dotfiles\opt\lastupdate))) {

	if (!(Test-Path $HOME\.dotfiles\opt\lastupdate)) {
		echo "No update time file found, running update now"
	} else {
		echo "Last update happened $(seconds2time $difftime) ago, updating dotfiles"
	}

	~\.dotfiles\init_powershell.ps1 -update
	echo "Reloading profile... (should find some way to `'exec powershell`')"
	echo "------------------"
	. $profile
}
else {
  cls
	Write-Host "Last dotfiles update: $(seconds2time $difftime) ago / Update Interval: $(seconds2time $maxtime)"
}