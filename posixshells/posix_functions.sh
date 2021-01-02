#!/bin/sh

#Enable help command, using tldr library
help () {
  curl -s cheat.sh/"$1" | less
}

pubkey () {
  if [ "$1" ]; then
    file=$1
  else
    file=id_rsa
  fi

  if [ -f "$HOME/.ssh/$file.pub" ]; then
    cat "$HOME/.ssh/$file.pub";
    if [ -x "$(command -v pbcopy)" ]; then
      printf "%s" "$(cat ~/.ssh/$file.pub)" | pbcopy
      printf '\nCopied to Clipboard!\n'
    fi
  else
    printf "Didn't find ~/.ssh/%s.pub, aborting...\n" "$file"
  fi
}

fixsshperms ()
{
  if [ -d ~/.ssh ]; then
    chmod 700 ~/.ssh
    chmod 644 ~/.ssh/*.pub

    # More comprehensive version of: find ~/.ssh -type f -iname "id*" -not -path "*.pub" -print0 | xargs -0 chmod 600

    # Ref: https://unix.stackexchange.com/a/103011
    # POSIX way to loop through array where objects are not expected to have newlines (so newline is safe IFS)
    files=$(find "$HOME/.ssh" -type f -not -path "*.pub")
    excludedfiles="authorized_keys known_hosts config"
    set -f; IFS='
    '                           # turn off variable value expansion except for splitting at newlines
    for sshfolderfile in $files; do
      set +f; unset IFS
      if notcontains "$excludedfiles" "$(basename "$sshfolderfile")";then
        if grep -q "PRIVATE KEY" "$sshfolderfile";then
          chmod 600 "$sshfolderfile"
        fi
      fi
    done
    set +f; unset IFS           # do it again in case $INPUT was empty
    unset files
    unset excludedfiles

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
  # Returns 0 if the string contains the substring,
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

# POSIX helper: notcontains(string, substring)
notcontains() {
  # Returns 0 if the specified string does NOT contain the  substring,
  # otherwise returns 1.
  string="$1"
  substring="$2"
  if test "${string#*$substring}" = "$string"
  then
      return 0    # $substring is not in $string
  else
      return 1    # $substring is in $string
  fi
}


fn_exists() {
  if type "$1" 2>/dev/null | grep -q 'function'; then
    return 0
  else
    return 1
  fi
}

rootpid() { #Ref: https://stackoverflow.com/a/34765059/7650275
  if [ "$1" ]; then
    case ${1#[-+]} in
      *[!0-9]* | '') catchterm=$1 ;;
      * ) PIDarg=$1 ;;
    esac

    if [ "$1" ] && [ "$2" ]; then
      catchterm=$2
    fi
  fi

  # Look up the parent of the given PID.
  PID=${PIDarg:-$$}
  PARENT=$(ps -p "$PID" -o ppid=)
  PARENTCMD=$(ps -p "$PID" -o args | awk 'NR>1')

  # /sbin/init always has a PID of 1, so if you reach that, the current PID is
  # the top-level parent. Otherwise, keep looking.
  if [ "${PARENT}" -eq 1 ] || contains "$PARENTCMD" "$catchterm"; then
      echo "${PID}"
  else
    if [ "$catchterm" ]; then
      rootpid "${PARENT}" "$catchterm"
    else
      rootpid "${PARENT}"
    fi
  fi

  unset PARENT
  unset PARENTCMD
  unset PIDarg
  unset catchterm
}

DidTerminalCallShell() {
  if contains "$(ps -p "$(rootpid Code.app)" -o args | awk 'NR>1')" "Terminal.app"; then
    return 0
  else
    return 1
  fi
}

#Ref/Credit: https://unix.stackexchange.com/a/270558
# example: pathadd "/foo/bar"
# example: pathadd "/baz/bat" after
pathadd() {
  newelement=${1%/}
  if [ -d "$1" ] && ! echo "$PATH" | grep -E -q "(^|:)$newelement($|:)" ; then
      if [ "$2" = "after" ] ; then
          PATH="$PATH:$newelement"
      else
          PATH="$newelement:$PATH"
      fi
  fi
}

simpleserver() {
  if [ -x "$(command -v python)" ]; then
    # Use subshell to change path to /tmp and launch simple http server
    (cd /tmp && python -m SimpleHTTPServer 8000);
  fi
}

getFileExt() {
  #Dictionary lookup, perhaps most easiest to understand
  # for the use cases of this dotfiles repo
  case "$1" in
    *.tar.bz2) echo "tar.bz2" ;;
    *.bz2)     echo "bz2" ;;
    *.tar.gz)  echo "tar.gz" ;;
    *.tgz)     echo "tgz" ;;
    *.gz)      echo "gz" ;;
    *.zip)     echo "zip" ;;
    *.7z)      echo "7z" ;;
    *)         echo "" ;;
  esac
}
