#!/bin/sh

#Enable help command, using tldr library
help () {
  curl -s cheat.sh/"$1" | less
}

# pubkey function to spit out pubkey
pubkey () {
  cat "$HOME/.ssh/id_rsa.pub";
  if [ -x "$(command -v pbcopy)" ]; then
    printf "%s" "$(cat ~/.ssh/id_rsa.pub)" | pbcopy
    printf '\nCopied to Clipboard!\n'
  fi
}

fixsshperms ()
{
  if [ -d ~/.ssh ]; then
    chmod 700 ~/.ssh
    chmod 644 ~/.ssh/*.pub
    find ~/.ssh -type f -iname "id*" -not -path "*.pub" -print0 | xargs -0 chmod 600
  fi
}

debug () {
  #Ref: https://stackoverflow.com/questions/17804007/how-to-show-line-number-when-executing-bash-script
  export PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
}

#seconds2time function
seconds2time ()
{
   T=$1
   D=$((T/60/60/24))
   H=$((T/60/60%24))
   M=$((T/60%60))
   S=$((T%60))

#Print the days, if any
if [ $D -gt 0 ]; then
  printf '%d day' $D; if [ $D -gt 1 ]; then printf 's'; fi
fi

#Print the hours, if any
if [ $H -gt 0 ]; then
  if [ $D -gt 0 ]; then printf ', '; fi
  printf '%d hour' $H; if [ $H -gt 1 ]; then printf 's'; fi
fi

#Print the minutes, if any
if [ $M -gt 0 ]; then
  if [ $H -gt 0 ] || [ $D -gt 0 ]; then printf ', '; fi
  printf '%d minute' $M; if [ $M -gt 1 ]; then printf 's'; fi
fi

#Print the seconds, if any
if [ $S -gt 0 ]; then
  if [ $M -gt 0 ] || [ $H -gt 0 ] || [ $D -gt 0 ]; then printf ', '; fi
  printf '%d second' $S; if [ $S -gt 1 ]; then printf 's'; fi
fi

#Print '0 seconds' if no time provided or time is 0
if [ "x$(printf '%s' "$T" | tr -d "$IFS")" = x ]; then
	printf '0 seconds'
elif [ "$T" -eq "0" ]; then
	printf '0 seconds'
fi
}

# POSIX helper: contains(string, substring)
contains() {
  # Returns 0 if the specified string contains the specified substring,
  # otherwise returns 1.
  string="$1"
  substring="$2"
  if test "${string#*$substring}" != "$string"
  then
      return 0    # $substring is in $string
  else
      return 1    # $substring is not in $string
  fi
}