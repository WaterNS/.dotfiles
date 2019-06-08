#!/bin/sh

# DOTFILES updater
# Check if last update was longer than set interval, kick off update if so
if [ -f "$HOME/.dotfiles/opt/lastupdate" ]; then
	oldtime=$(head -1 "$HOME/.dotfiles/opt/lastupdate")
	newtime=$(date +%s)
	difftime=$((newtime-oldtime))
	maxtime=$((5*24*60*60))
fi

SHAinitscript=$(git --git-dir "$HOME/.dotfiles/.git" log -n 1 --pretty=format:%H -- init_posix.sh)
if [ ! -f "$HOME/.dotfiles/opt/lastinit" ] || [ "$SHAinitscript" != "$(head -2 "$HOME/.dotfiles/opt/lastinit" | tail -1)" ]; then
	if [ ! -f "$HOME/.dotfiles/opt/lastinit" ]; then
		echo "No init time file found, running initialization now"
	else
	 echo "Init script has been updated since last run, Executing init_posix.sh with ReInitialization flag"
	fi
	"$HOME/.dotfiles/init_posix.sh" -r
	echo "Restarting shell..."
	echo "------------------"
	exec "$RUNNINGSHELL"
elif [ $difftime -gt $maxtime ] || [ ! -f "$HOME/.dotfiles/opt/lastupdate" ]; then
	if [ ! -f "$HOME/.dotfiles/opt/lastupdate" ]; then
		echo "No update time file found, running update now"
	else
		echo "Last update happened $(seconds2time "$difftime") ago, updating dotfiles"
	fi
	"$HOME/.dotfiles/init_posix.sh" -u
	echo "Restarting shell..."
	echo "------------------"
  exec "$RUNNINGSHELL"
else
	echo "Last dotfiles update: $(seconds2time "$difftime") ago / Update Interval: $(seconds2time $maxtime) - [$RUNNINGSHELL] "
	#echo "Update <$maxtime seconds ago, skipping dotfiles update"
fi