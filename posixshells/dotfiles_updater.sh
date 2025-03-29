#!/bin/sh

# Ignore git config and force git output in English to make our work easier
git_eng="env LANG=C GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG=/dev/null HOME=/dev/null git"
HOME2=$HOME

# DOTFILES updater
# Check if last update was longer than set interval, kick off update if so
if [ -f "$HOME/.dotfiles/opt/lastUpdate" ]; then
	oldTime=$(head -1 "$HOME/.dotfiles/opt/lastUpdate")
	newTime=$(date +%s)
	diffTime=$((newTime-oldTime))
	maxTime=$((5*24*60*60))
fi

shaInitScript=$($git_eng --git-dir "$HOME2/.dotfiles/.git" log -n 1 --pretty=format:%H -- init_posix.sh)
if [ ! -f "$HOME/.dotfiles/opt/lastInit" ] || [ "$shaInitScript" != "$(head -2 "$HOME/.dotfiles/opt/lastInit" | tail -1)" ]; then
	if [ ! -f "$HOME/.dotfiles/opt/lastInit" ]; then
		echo "No init time file found, running initialization now"
	else
	 echo "Init script has been updated since last run, Executing init_posix.sh with ReInitialization flag"
	fi
  if "$HOME/.dotfiles/init_posix.sh" -r; then
    echo "Restarting shell..."
    echo "------------------"
    exec "$RUNNINGSHELL"
  fi
elif [ "$diffTime" -gt "$maxTime" ] || [ ! -f "$HOME/.dotfiles/opt/lastUpdate" ]; then
	if [ ! -f "$HOME/.dotfiles/opt/lastUpdate" ]; then
		echo "No update time file found, running update now"
	else
		echo "Last update happened $(seconds2time "$diffTime") ago, updating dotfiles"
	fi
	"$HOME/.dotfiles/init_posix.sh" -u
	echo "Restarting shell..."
	echo "------------------"
  exec "$RUNNINGSHELL"
else
	echo "Last dotfiles update: $(seconds2time "$diffTime") ago / Update Interval: $(seconds2time "$maxTime") - [$RUNNINGSHELL $RUNNINGSHELLVERSION] "
	#echo "Update <$maxTime seconds ago, skipping dotfiles update"
fi
