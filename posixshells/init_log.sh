#!/bin/sh

# # shellcheck disable=SC2154 # $ri/$u sourced from upstream script
# if [ "$r" = true ]; then
# elif [ "$u" = true ]; then
# fi

HOMEREPO="$HOME/.dotfiles"

# Ignore git config and force git output in English to make our work easier
git_eng="env LANG=C GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG=/dev/null HOME=/dev/null git"

SHAinitupdated=$($git_eng -C "$HOMEREPO" log -n 1 --pretty=format:%H -- init_posix.sh)
if [ ! -f "$HOMEREPO/opt/lastupdate" ] || [ ! -f "$HOMEREPO/opt/lastinit" ]; then
	if [ ! -f "$HOMEREPO/opt/lastupdate" ]; then
		date +%s > "$HOMEREPO/opt/lastupdate"
		date '+%A %F %I:%M:%S %p %Z' >> "$HOMEREPO/opt/lastupdate"
	fi

	if [ ! -f "$HOMEREPO/opt/lastinit" ]; then
		echo "Last commit at which init_posix.sh initialization ran:" > "$HOMEREPO/opt/lastinit"
		echo "$SHAinitupdated" >> "$HOMEREPO/opt/lastinit"
	fi
elif [ "$u" ] || [ "$r" ]; then
	if [ "$u" ]; then
		echo ""
		echo "Updating last update time file with current date"
		date +%s > "$HOMEREPO/opt/lastupdate"
		date '+%A %F %I:%M:%S %p %Z' >> "$HOMEREPO/opt/lastupdate"
	fi

	if [ "$r" ]; then
		echo ""
		echo "Updating lastinit time with current SHA: $SHAinitupdated"
	  echo "Last commit at which init_posix.sh initialization ran:" > "$HOMEREPO/opt/lastinit"
	  echo "$SHAinitupdated" >> "$HOMEREPO/opt/lastinit"
	fi
fi
