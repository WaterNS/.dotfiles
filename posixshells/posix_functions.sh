#!/bin/sh

fetchGitDefaultBranch() {
  if [ "$#" -ne 1 ]; then
    echo "Usage: fetchGitDefaultBranch /path/to/repo"
    return 1
  fi

  # Ignore git config and force git output in English to make our work easier
  git_eng="env LANG=C GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG=/dev/null HOME=/dev/null git"

  if [ -d "$1" ]; then
    # Default Branch:
    GITDEFAULTBRANCH="master"
    __gitLocalLookup=$($git_eng -C "$1" rev-parse --abbrev-ref origin/HEAD 2>/dev/null)
    if [ -n "$__gitLocalLookup" ] && [ "$__gitLocalLookup" != "origin/HEAD" ]; then
      GITDEFAULTBRANCH="$__gitLocalLookup"
    else
      # Second check: git remote show with sed
      # assuming that "origin" is your remote. Replace "origin" with your actual remote name if different.
      __gitDefaultRemoteBranch=$($git_eng -C "$1" remote show origin | sed -n '/HEAD branch/s/.*: //p' 2>/dev/null)
      if [ -n "$__gitDefaultRemoteBranch" ]; then
        GITDEFAULTBRANCH="$__gitDefaultRemoteBranch"
      fi
    fi

    # strip out "origin/" if exists in $GITDEFAULTBRANCH
    GITDEFAULTBRANCH=${GITDEFAULTBRANCH#origin/}

    echo "$GITDEFAULTBRANCH"
  fi
}


# Function: Update git repo (if needed)
updateGitRepo() {
  olddir=$PWD
  reponame=""
  description=""
  repolocation=""
  depth=""

  # Ignore git config and force git output in English to make our work easier
  git_eng="env LANG=C GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG=/dev/null HOME=/dev/null git"

  positional_counter=0
  while [ $# -gt 0 ]; do
    case "$1" in
      -n|--name)
        reponame="$2"; shift 2 ;;
      -desc|--description)
        description="$2"; shift 2 ;;
      -p|--path)
        repolocation="$2"; shift 2 ;;
      -z|--depth)
        depth="$2"; shift 2 ;;
      --)
        shift; break ;;
      -*)
        echo "Unknown option: $1" >&2; return 1 ;;
      *)
        if [ $positional_counter -eq 0 ]; then
          reponame="$1"
        elif [ $positional_counter -eq 1 ]; then
          description="$1"
        elif [ $positional_counter -eq 2 ]; then
          repolocation="$1"
        elif [ $positional_counter -eq 3 ]; then
          depth="$1"
        fi
        positional_counter=$((positional_counter + 1))
        shift ;;
    esac
  done

  if [ -z "$reponame" ] || [ -z "$description" ] || [ -z "$repolocation" ]; then
    echo "Usage: updateGitRepo [-n|--name] <reponame> [-desc|--description] <description> [-p|--path] <repolocation> [-d|--depth depth]"
    return 1
  fi

  cd "$repolocation" || return
  if [ -n "$depth" ]; then
    $git_eng fetch --depth="$depth" -q
  else
    $git_eng fetch -q
  fi

  GITDEFAULTBRANCH="$(fetchGitDefaultBranch "$repolocation")"
  if [ "$($git_eng rev-list --count "$GITDEFAULTBRANCH"..origin/"$GITDEFAULTBRANCH")" -gt 0 ]; then
    printf -- "--Updating %s %s repo " "$reponame" "$description"
    printf "(from %s to " "$($git_eng rev-parse --short "$GITDEFAULTBRANCH")"
    printf "%s)" "$($git_eng rev-parse --short origin/"$GITDEFAULTBRANCH")"
    if [ -n "$depth" ]; then
      $git_eng pull --depth="$depth" origin "$GITDEFAULTBRANCH" --quiet
    else
      $git_eng pull origin "$GITDEFAULTBRANCH" --quiet
    fi

    # Restart the init script if it self updated
    if [ "$reponame" = "dotfiles" ]; then
      cd "$olddir" || return
      echo ""
      echo ""
      exec "$SCRIPTPATHINIT" "$INITSCRIPTARGS";
    fi
  fi

  cd "$olddir" || return
}


# statByteSize: Handle different flags for GNU/Linux `stat` vs Darwin version
if [ -x "$(command -v stat)" ]; then
  if [ "$OS_FAMILY" = "Darwin" ]; then
    alias statByteSize='stat -f %z'
  else
    alias statByteSize='stat -c %s'
  fi
fi

# statWhenModified: Handle different flags for GNU/Linux `stat` vs Darwin version
if [ -x "$(command -v stat)" ]; then
  if [ "$OS_FAMILY" = "Darwin" ]; then
    alias statWhenModified='stat -f %m'
  else
    alias statWhenModified='stat -c %Y'
  fi
fi

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
      printf "%s" "$(cat ~/.ssh/"$file".pub)" | pbcopy
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

  PID=${PIDarg:-$$}

  while true; do
    PARENT=$(ps -p "$PID" -o ppid=)
    PARENTCMD=$(ps -p "$PID" -o args | awk 'NR>1')

    # /sbin/init always has a PID of 1, so if you reach that, the current PID is
    # the top-level parent. Otherwise, keep looking.
    if [ "${PARENT}" -eq 1 ]; then
      echo "${PID}"
      break
    else
      case "$PARENTCMD" in
        *"$catchterm"*)
          echo "${PID}"
          break
        ;;
        *)
          PID="${PARENT}"
        ;;
      esac
    fi
  done

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
    *.rar)     echo "rar" ;;
    *.7z)      echo "7z" ;;
    *.ps1)     echo "ps1" ;;
    *.sh)      echo "sh" ;;
    *)         echo "" ;;
  esac
}

getBaseNameNoExt() {
  __basefilename="${1##*/}"
  __extension=$(getFileExt "$__basefilename")
  #echo "detected extension: $__extension"
  echo "${__basefilename%."$__extension"}"

  unset __basefilename; unset __extension;
}

caller_func_name() {
  if [ -n "$1" ]; then
    __stackDepth="$1"
  else
    __stackDepth=1
  fi

  if [ -n "$ZSH_VERSION" ]; then
    # Use offset:length as array indexing may start at 1 or 0
    printf "%s\n" "${funcstack[@]:$__stackDepth:$__stackDepth}"
  else # Bash, Bourne shells
    printf "%s\n" "${FUNCNAME[$__stackDepth]}"
  fi
}

isBusyBoxCmd() {
  __testcommand="$1"
  if [ "$__testcommand" ] && [ -x "$(command -v "$__testcommand")" ]; then
    __commandTarget=$(readlink "$(command -v "$__testcommand")")
    if [ "$__commandTarget" ] && [ -f "$__commandTarget" ]; then
      if contains "$__commandTarget" "busybox"; then
        unset __commandTarget;
        unset __testcommand;
        return 0;
      fi
    fi
  fi

  unset __testcommand;
  unset __commandTarget;
  return 1;
}

isFakeXcodeCmd() {
  __originalCmd=$1
  __fakeXcodeCmd=false

  if [ -x "$(command -v "$__originalCmd")" ]; then
    __cmd=$(which "$__originalCmd")
    if [ -L "$__cmd" ]; then __cmd="$(readlink -f "$__cmd")"; fi

    __cmdByteSize=$(statByteSize "$__cmd")
    if [ "$__cmdByteSize" -lt 180000 ]; then
      xcode_tools_dir=$(xcode-select -p 2>/dev/null)
      #xcodeTest=$(xcode_tools_dir=$(xcode-select -p 2>/dev/null) && ls "${xcode_tools_dir}"/usr/bin/"$__originalCmd")
      if [ "${#xcode_tools_dir}" != 0 ] && [ ! -f "$xcode_tools_dir"/usr/bin/"$__originalCmd" ]; then
        __fakeXcodeCmd=true
      fi
    fi

  fi

  if [ "$__fakeXcodeCmd" = true ]; then
    return 0
  else
    return 1
  fi
}

isRealCommand() {
  __originalCmd=$1
  __realCmd=false

  if [ -x "$(command -v "$__originalCmd")" ] || which "$__originalCmd" > /dev/null 2>&1; then
    __realCmd=true

    if isFakeXcodeCmd "$__originalCmd"; then
      __realCmd=false
    fi

    if isBusyBoxCmd "$__originalCmd"; then
      __realCmd=false
    fi

  fi

  if [ "$__realCmd" = true ]; then
    return 0
  else
    return 1
  fi
}

isMissingOrFakeCmd() {
  if isRealCommand "$1"; then
    return 1
  else
    return 0
  fi
}

compare_versions() {
  LC_ALL=C awk -- '
    function pad(v,  ret) {
      while (match(v, /[0-9]+/)) {
        ret = ret substr(v, 1, RSTART - 1) \
              sprintf("%09d", substr(v, RSTART, RLENGTH))
        v = substr(v, RSTART + RLENGTH)
      }
      return ret v
    }
    BEGIN {exit !(pad(ARGV[1]) '"$2"' pad(ARGV[2]))}' "$1" "$3"
}

reHydrateRepo() {
  path_to_repo=""
  repo_remote_url=""
  depth=""

  positional_counter=0
  while [ $# -gt 0 ]; do
    case "$1" in
      -p|--path)
        path_to_repo="$2"; shift 2 ;;
      -r|--repo)
        repo_remote_url="$2"; shift 2 ;;
      -d|--depth)
        depth="$2"; shift 2 ;;
      --)
        shift; break ;;
      -*)
        echo "Unknown option: $1" >&2; return 1 ;;
      *)
        if [ $positional_counter -eq 0 ]; then
          path_to_repo="$1"
        elif [ $positional_counter -eq 1 ]; then
          repo_remote_url="$1"
        elif [ $positional_counter -eq 2 ]; then
          depth="$1"
        fi
        positional_counter=$((positional_counter + 1))
        shift ;;
    esac
  done

  if [ -z "$path_to_repo" ] || [ -z "$repo_remote_url" ]; then
    echo "Usage: reHydrateRepo [-p|--path] <path_to_repo> [-r|--repo] <repo_remote_url> [-d|--depth depth] (git is required)"
    return 2
  fi

  if [ ! -x "$(command -v git)" ]; then
    echo "ERROR - reHydrateRepo - * git * is required"
    return 3
  fi

  if [ -d "$path_to_repo" ]; then
    git -C "$path_to_repo" init -q
    git -C "$path_to_repo" remote add origin "$repo_remote_url"
    if [ -n "$depth" ]; then
      git -C "$path_to_repo" fetch -q --depth="$depth" origin
    else
      git -C "$path_to_repo" fetch -q origin
    fi
    GITDEFAULTBRANCH="$(fetchGitDefaultBranch "$path_to_repo")"
    git -C "$path_to_repo" reset -q origin/"$GITDEFAULTBRANCH"
    git -C "$path_to_repo" checkout -q "$GITDEFAULTBRANCH"
    git -C "$path_to_repo" branch -q --set-upstream-to=origin/"$GITDEFAULTBRANCH" "$GITDEFAULTBRANCH"
  else
    echo "ERROR - reHydrateRepo - Folder provided doesn't exist: $path_to_repo"
    return 4
  fi
}

githubCloneByCurl() {
  repo_url=""
  dest_folder=""
  depth=""

  positional_counter=0
  while [ $# -gt 0 ]; do
    case "$1" in
      -r|--repo)
        repo_url="$2"; shift 2 ;;
      -p|--path)
        dest_folder="$2"; shift 2 ;;
      -d|--depth)
        depth="$2"; shift 2 ;;
      --)
        shift; break ;;
      -*)
        echo "Unknown option: $1" >&2; return 1 ;;
      *)
        if [ $positional_counter -eq 0 ]; then
          repo_url="$1"
        elif [ $positional_counter -eq 1 ]; then
          dest_folder="$1"
        elif [ $positional_counter -eq 2 ]; then
          depth="$1"
        fi
        positional_counter=$((positional_counter + 1))
        shift ;;
    esac
  done

  if [ -z "$repo_url" ]; then
    echo "Usage: githubCloneByCurl [-r|--repo] <repo_url> [-p|--path] [destination_folder] [-d|--depth depth] (requires curl + tar|unzip)"
    return 1
  fi

  if [ ! -x "$(command -v curl)" ]; then
    echo "ERROR - githubCloneByCurl - requires curl + tar|unzip"
    return 2
  fi

  [ "${repo_url%.git}" != "$repo_url" ] && repo_remote=$repo_url || repo_remote="$repo_url.git"
  repo_name=$(basename "$repo_url" .git)

  if [ -z "$dest_folder" ]; then
    dest_folder="$PWD/$repo_name"
  fi

  # Identify which type of archive to fetch
  echo "Downloading and rehydrating repo $repo_url to $dest_folder ..."
  if [ -x "$(command -v tar)" ]; then
    archive_url="${repo_url%/}/tarball/master"
    mkdir -p "$dest_folder" && curl -L -s "$archive_url" | tar xz --strip 1 -C "$dest_folder" && reHydrateRepo "$dest_folder" "$repo_remote" "$depth"
  elif [ -x "$(command -v unzip)" ]; then
    archive_url="${repo_url%/}/zipball/master"
    mkdir -p "$dest_folder" && curl -L -s "$archive_url" | unzip -q -d "$dest_folder" - && reHydrateRepo "$dest_folder" "$repo_remote" "$depth"
  else
    echo " -- githubCloneByCurl: Couldn't find extract tool (tar/unzip)"
    return 1
  fi

  if [ -d "$dest_folder" ] && [ -d "$dest_folder/.git" ];then
    echo "  ++ SUCCESS: Cloned $repo_name -> $dest_folder ++"
  else
    echo " -- githubCloneByCurl - FAILED - didn't find folder or failed git rehydrate"
  fi
}

shortcutHere() {
  #Creates Finder shortcuts in OSX, via commandline
  if [ "$OS_FAMILY" = "Darwin" ]; then
    target="$1"
    targetBasename=$(basename "$target")
    shortcutLocation=""

    shortcutLocation=$PWD

    if [ -n "$target" ] && [ -n "$targetBasename" ] && [ -n "$shortcutLocation" ];then
      from=$(printf '%s' "$(cd "$(dirname "$target")" && pwd)/$(basename "$target")")
      shortcutName=$shortcutLocation/$targetBasename
      #shortcutName=$targetBasename
      if [ -f "$from" ]; then
          type="file"
      elif [ -d "$from" ]; then
          type="folder"
      else
          echo "mkalias: invalid path or unsupported type: '$from'" >&2
          return 1
      fi

    echo "target: $target"
    echo "dest: $shortcutLocation/$targetBasename (type: $type)"

      osascript <<EOF
        tell application "Finder"
          make new alias to $type (posix file "$from") at (posix file "$shortcutLocation")
          set name of result to "$shortcutName"
        end tell
EOF
    else
      echo "Missing required items";
    fi
  else
    echo "Unable to run makeShortcut - OS version ($OS_FAMILY $OS_ARCH) doesn't have supported function";
  fi
}

tripleSplitTMUX() {
  if [ -n "$TMUX" ]; then
    # If there's only one pane, split it horizontally
    if [ "$(tmux list-panes | wc -l)" -eq 1 ]; then
      tmux split-window -h -p 30
    fi

    # If there are two panes, split the second pane vertically
    if [ "$(tmux list-panes | wc -l)" -eq 2 ]; then
      tmux split-window -v -p 40
    fi

    # Select the first pane
    tmux select-pane -t 1
  fi
}
