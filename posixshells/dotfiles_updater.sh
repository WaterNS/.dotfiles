#!/bin/sh

# Ignore git config and force git output in English to make our work easier
git_eng="env LANG=C GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG=/dev/null HOME=/dev/null git"
HOMEREPO=${HOMEREPO:-"$HOME/.dotfiles"}

restart_dotfiles_shell() {
  case "${RUNNINGSHELL:-}" in
    ash|sh|*/ash|*/sh) exec "$RUNNINGSHELL" -l ;;
    '') return 0 ;;
    *) exec "$RUNNINGSHELL" ;;
  esac
}

# DOTFILES updater
# Check if last update was longer than set interval, kick off update if so
diffTime=0
maxTime=$((5*24*60*60))
if [ -f "$HOMEREPO/opt/lastUpdate" ]; then
	oldTime=$(head -n 1 "$HOMEREPO/opt/lastUpdate")
	newTime=$(date +%s)
	diffTime=$((newTime-oldTime))
fi

shaInitScript=$($git_eng --git-dir "$HOMEREPO/.git" log -n 1 --pretty=format:%H -- init_posix.sh)
if [ ! -f "$HOMEREPO/opt/lastInit" ] || [ "$shaInitScript" != "$(head -n 2 "$HOMEREPO/opt/lastInit" | tail -n 1)" ]; then
	if [ ! -f "$HOMEREPO/opt/lastInit" ]; then
		echo "No init time file found, running initialization now"
	else
	 echo "Init script has been updated since last run, Executing init_posix.sh with ReInitialization flag"
	fi
  if "$HOMEREPO/init_posix.sh" -r; then
    echo "Restarting shell..."
    echo "------------------"
    restart_dotfiles_shell
  fi
elif [ ! -f "$HOMEREPO/opt/lastUpdate" ] || [ "$diffTime" -gt "$maxTime" ]; then
	if [ ! -f "$HOMEREPO/opt/lastUpdate" ]; then
		echo "No update time file found, running update now"
	else
		echo "Last update happened $(seconds2time "$diffTime") ago, updating dotfiles"
	fi
	"$HOMEREPO/init_posix.sh" -u
	echo "Restarting shell..."
	echo "------------------"
  restart_dotfiles_shell
else
	echo "Last dotfiles update: $(seconds2time "$diffTime") ago / Update Interval: $(seconds2time "$maxTime") - [$RUNNINGSHELL $RUNNINGSHELLVERSION] "
	#echo "Update <$maxTime seconds ago, skipping dotfiles update"
fi
