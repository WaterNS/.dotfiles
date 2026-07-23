#!/bin/sh

HOMEREPO=${HOMEREPO:-"$HOME/.dotfiles"}
export HOMEREPO

# Identify Operating System (better uname)
. "$HOMEREPO/posixshells/posix_id_os.sh"

# Source posix functions
. "$HOMEREPO/posixshells/posix_functions.sh"

case ":$PATH:" in
  *":$HOMEREPO/opt/bin:"*) ;;
  *) PATH="$HOMEREPO/opt/bin:$PATH" ;;
esac
export PATH

# A true/0 result tells the caller to return success before installing prerequisites/attempting downloads.
skip_ish_install() {
  if [ "${IS_ISH:-}" = true ]; then
    echo "NOTE: skipping $1 on iSH."
    return 0
  fi
  return 1
}

# Zsh and its framework/add-ons are intentionally desktop-only.
skip_install_iSH_aShell() {
  if [ "${IS_ASHELL:-}" = true ] || [ "${IS_ISH:-}" = true ]; then
    echo "NOTE: skipping $1 on ${OS_PLATFORM:-this mobile host}."
    return 0
  fi
  return 1
}

install_generic_apk () {
  __pkgName="$1"

  if [ -n "$2" ]; then
    __executableName=$2
  else
    __executableName=$__pkgName
  fi

  if isMissingOrFakeCmd "$__executableName"; then
    if command_exists apk; then
      if isBusyBoxCmd "$__executableName"; then
        echo "NOTE: $__executableName is busybox polyfill, installing real version via APK"
      else
        echo "NOTE: $__executableName not found, installing via APK"
      fi
      echo "------------------------------------------------"
      if [ "${APK_CACHE_UPDATED:-}" != true ]; then
        echo "Updating APK cache..."
        if ! apk update; then
          unset __pkgName __executableName
          return 1
        fi
        APK_CACHE_UPDATED=true
      fi

      echo "Requesting ${__pkgName} from APK..."
      if ! apk add "$__pkgName"; then
        echo "BAD - APK was unable to install $__pkgName" >&2
        unset __pkgName __executableName
        return 1
      fi

      if command_exists "$__executableName"; then
        echo "  ++ GOOD - $__executableName is now available ++"; echo "";
      else
        echo "BAD - $__executableName doesn't seem to be available" >&2
        unset __pkgName __executableName
        return 1
      fi
    else
      echo "install_generic_apk (while attempting install $__executableName): APK package manager not found!"
    fi
  fi

  # Cleanup variables - can cause unexpected bugs if not done.
  # Scoped variables (local) not available in base bourne shell.
  unset __pkgName; unset __executableName;
}

install_generic_ashell() {
  __pkgName=$1
  __executableName=${2:-$1}

  if [ "${IS_ASHELL:-}" != true ]; then
    echo "install_generic_ashell: not running in a-Shell" >&2
    unset __pkgName __executableName
    return 1
  fi

  if ! command_exists "$__executableName"; then
    if ! command_exists pkg; then
      echo "install_generic_ashell: a-Shell's pkg command is unavailable" >&2
      unset __pkgName __executableName
      return 1
    fi

    echo "NOTE: $__executableName not found, installing $__pkgName via a-Shell pkg"
    pkg install "$__pkgName" || {
      unset __pkgName __executableName
      return 1
    }
    rehash 2>/dev/null || :
  fi

  if command_exists "$__executableName"; then
    echo "  ++ GOOD - $__executableName is now available ++"
    unset __pkgName __executableName
    return 0
  fi

  echo "BAD - $__executableName doesn't seem to be available" >&2
  unset __pkgName __executableName
  return 1
}

install_generic_apt () {
  __pkgName="$1"

  if [ -n "$2" ]; then
    __executableName=$2
  else
    __executableName=$__pkgName
  fi

  if isMissingOrFakeCmd "$__executableName"; then
    if [ -x "$(command -v apt)" ]; then
      echo "NOTE: $__executableName not found, installing via APT"
      echo "------------------------------------------------"
      echo "Updating APT cache..."
      sudo apt update -qq

      echo "Requesting ${__pkgName} from APT..."
      sudo apt install "$__pkgName" -qqy

      if [ -x "$(command -v "$__executableName")" ]; then
        echo "  ++ GOOD - $__executableName is now available ++"; echo "";
      else
        echo "BAD - $__executableName doesn't seem to be available"
      fi
    else
      echo "install_generic_apt (while attempting install $__executableName): APT package manager not found!"
    fi
  fi

  # Cleanup variables - can cause unexpected bugs if not done.
  # Scoped variables (local) not available in base bourne shell.
  unset __pkgName; unset __executableName;
}

identify_github_pkg () {
  # Expected args: $__repoName $__executableName $__searchString $__searchExcludeString

  __exactName=false
  for arg do
    shift
    if [ "$arg" = "--exact" ]; then
      __exactName=true
    else
      set -- "$@" "$arg"
    fi
  done

  __repoName="$1"
  __repoURL="https://api.github.com/repos/$__repoName/releases/latest"
  __pkgName="$(echo "$__repoName" | cut -d'/' -f2)"

  if [ -n "$2" ]; then
    __executableName="$2"
  else
    __executableName=$__pkgName
  fi

  if [ -n "$3" ]; then
    __searchString="$3"
  else
    __searchString="$__pkgName"
  fi

  if [ -n "$4" ]; then
    __searchExcludeString="$4"
  else
    __searchExcludeString=""
  fi

  install_curl

  #OLd code, leaving commented for now
  # #__pkgRelease=$(curl -S "$__repoURL" | jq -r ".assets[] | .browser_download_url" | grep "$__searchString") #jq dependent
  # $__results=""

  #echo "Looking up URLs for $__repoName..."
  __results=$(curl -S -s "$__repoURL" | grep url | grep browser_download_url)
  #echo "$__results"
  if [ -n "$__searchExcludeString" ]; then
    #echo "Excluding results with '$__searchExcludeString'"
    __results=$(echo "$__results" | grep -v "$__searchExcludeString")
    #echo "$__results"
  fi
  if [ -n "$__searchString" ]; then
    #echo "Searching for '$__searchString'"
    __results=$(echo "$__results" | grep "$__searchString")
    #echo "$__results"
  fi
  if [ $__exactName = true ]; then
    #echo "Looking for exact match..."
    __exactEndString="$__searchString$"
    __results=$(echo "$__results" | tr -d '"' | grep -E "$__exactEndString")
  fi
  if [ -n "$__results" ]; then
    #echo "Cleaning up URL..."
    __cleanURL=$(echo "$__results" | sed 's/.*\(http[s?]:\/\/.*[^"]\).*/\1/')
    echo "$__cleanURL"
  fi
}

install_generic_homebrew () {
  __pkgName="$1"

  if [ -n "$2" ]; then
    __executableName=$2
  else
    __executableName=$__pkgName
  fi
  if [ ! -x "$(command -v "$__executableName")" ]; then
    install_curl
    install_jq
    if [ "$OS_PLATFORM" = "macos" ]; then
      echo "NOTE: $__pkgName not found, availing into dotfiles bin"
      echo "------------------------------------------------"
      __pkgurl="https://formulae.brew.sh/api/formula/$__pkgName.json"
      bottles=$(curl -S -s "$__pkgurl" | jq -r "[.bottle.stable.files][0]")

      if [ "$bottles" ]; then
        if contains "$(arch)" "arm64"; then
          latestARM=$(echo "$bottles" | jq -r '. | with_entries( select(.key|contains("arm64") ) ) | .[]'.url)
          if [ "$latestARM" ]; then
            latest=$latestARM
          fi
        fi
        if [ ! "$latest" ]; then
          latest=$(echo "$bottles" | jq -r "[.[]][0]".url)
        fi
      fi

      if [ "$latest" ];then
        if [ ! -d "$HOME/.dotfiles/opt/tmp" ]; then
          mkdir -p "$HOME/.dotfiles/opt/tmp"
        fi

        __fileName=${latest##*/}
        # shellcheck disable=SC2086
        # curl has a hard time with the URL when double quoted (probably due to colons)
        curl -H "Authorization: Bearer QQ==" -L -S -s $latest > "$HOME/.dotfiles/opt/tmp/$__fileName"; echo ""

        mkdir "$HOME/.dotfiles/opt/tmp/$__pkgName"
        tar -xzf "$HOME/.dotfiles/opt/tmp/$__fileName" -C "$HOME/.dotfiles/opt/tmp/$__pkgName/"

        mv "$HOME"/.dotfiles/opt/tmp/"$__pkgName"/"$__pkgName"/*/bin/"$__executableName" ~/.dotfiles/opt/bin
      fi

      if [ -x "$(command -v "$__executableName")" ]; then
        rm "$HOME/.dotfiles/opt/tmp/$__fileName"
        rm -rf "$HOME/.dotfiles/opt/tmp/$__pkgName"
        echo "  ++ GOOD - $__pkgName is now available ++"; echo "";
      else
        echo "BAD - $__pkgName doesn't seem to be available"
      fi
    else
      echo "Unable to install $__pkgName - OS version ($OS_FAMILY $OS_ARCH) doesn't have supported function"; echo "";
    fi
  fi

  # Cleanup variables - can cause unexpected bugs if not done.
  # Scoped variables (local) not available in base bourne shell.
  unset __pkgName; unset __executableName;
  unset bottles; unset latest; unset latestARM;
  unset __fileName;
}

install_generic_github () {
  # shellcheck disable=SC2124
  __originalArgs=$@

  for arg do
    shift
    if [ "$arg" = "--exact" ]; then
      __exactName=true
    else
      set -- "$@" "$arg"
    fi
  done

  __repoName="$1"
  __repoURL="https://api.github.com/repos/$__repoName/releases/latest"
  __pkgName="$(echo "$__repoName" | cut -d'/' -f2)"

  if [ -n "$2" ]; then
    __executableName="$2"
  else
    __executableName=$__pkgName
  fi

  if [ -n "$3" ]; then
    __searchString="$3"
  else
    __searchString="osx"
  fi

  if [ -n "$4" ]; then
    __searchExcludeString="$4"
  else
    __searchExcludeString=""
  fi

  if [ ! -x "$(command -v "$__executableName")" ]; then
    if [ "$OS_PLATFORM" = "macos" ] || [ "$OS_FAMILY" = "Linux" ]; then
      echo "NOTE: $__executableName not found, downloading into dotfiles bin"
      echo "------------------------------------------------"
      # shellcheck disable=SC2086
      __pkgRelease=$(identify_github_pkg $__originalArgs)
      #echo "pkg: $__pkgRelease"

      if [ "$__pkgRelease" ];then
        if [ ! -d "$HOME/.dotfiles/opt/tmp" ]; then
          mkdir -p "$HOME/.dotfiles/opt/tmp"
        fi

        __fileName=${__pkgRelease##*/}
        __fileExt=$(getFileExt "$__fileName")

        # echo "Downloading ${__executableName}..."
        if [ -z "$__fileExt" ]; then
          curl -L -S -s "$__pkgRelease" -o "$HOME/.dotfiles/opt/bin/$__executableName"; echo ""
          chmod +x "$HOME/.dotfiles/opt/bin/$__executableName";
        else
          # echo "url: $__pkgRelease"
          # echo "location: $HOME/.dotfiles/opt/tmp/$__fileName"
          curl -L -S -s "$__pkgRelease" -o "$HOME/.dotfiles/opt/tmp/$__fileName"; echo ""
          mkdir "$HOME/.dotfiles/opt/tmp/$__pkgName"

          echo "Extracting archive..."
          if [ "$__fileExt" = "7z" ]; then
            unar "$HOME/.dotfiles/opt/tmp/$__fileName" -o "$HOME/.dotfiles/opt/tmp/$__pkgName/"
          else
            #Fallback to using tar
            tar -xzf "$HOME/.dotfiles/opt/tmp/$__fileName" -C "$HOME/.dotfiles/opt/tmp/$__pkgName/"
          fi

          echo "Moving the binary..."
          if [ -f "$HOME"/.dotfiles/opt/tmp/"$__pkgName"/"$__pkgName" ]; then
            mv "$HOME"/.dotfiles/opt/tmp/"$__pkgName"/"$__pkgName" ~/.dotfiles/opt/bin
          elif [ -f "$HOME"/.dotfiles/opt/tmp/"$__pkgName"/"$(getBaseNameNoExt "$__fileName")"/"$__executableName" ]; then
            mv "$HOME"/.dotfiles/opt/tmp/"$__pkgName"/"$(getBaseNameNoExt "$__fileName")"/"$__executableName" ~/.dotfiles/opt/bin
          else
            # shellcheck disable=SC2086
            mv "$HOME"/.dotfiles/opt/tmp/"$__pkgName"/"$__pkgName"/*/bin/$__executableName ~/.dotfiles/opt/bin
          fi
        fi
      fi

      if [ -x "$(command -v "$__executableName")" ]; then
        rm -f "$HOME/.dotfiles/opt/tmp/$__fileName"
        rm -rf "$HOME/.dotfiles/opt/tmp/$__pkgName"
        echo "  ++ GOOD - $__executableName is now available ++"; echo "";
      else
        echo "BAD - $__executableName doesn't seem to be available"
        echo ""
      fi
    else
      echo "install_generic_github (while attempting install $__executableName): OS version ($OS_FAMILY $OS_ARCH) doesn't have supported function"; echo "";
      echo ""
    fi
  fi

  # Cleanup variables - can cause unexpected bugs if not done.
  # Scoped variables (local) not available in base bourne shell.
  unset __repoName; unset __repoURL; unset __pkgName; unset __executableName;
  unset __pkgRelease; unset __fileName; unset __fileExt; unset __exactName;
}

install_generic_binary () {
  __binaryURL="$1"
  __pkgName="$(basename "$__binaryURL" | cut -d. -f1)"

  if [ -n "$2" ]; then
    __executableName="$2"
  fi

  if [ ! -x "$(command -v "$__executableName")" ]; then
    install_curl
    if [ "$OS_PLATFORM" = "macos" ]; then
      echo "NOTE: $__executableName not found, availing into dotfiles bin"
      echo "------------------------------------------------"
      __pkgRelease=$__binaryURL

      if [ "$__pkgRelease" ];then
        if [ ! -d "$HOME/.dotfiles/opt/tmp" ]; then
          mkdir -p "$HOME/.dotfiles/opt/tmp"
        fi

        __fileName=${__pkgRelease##*/}
        __fileExt=$(getFileExt "$__fileName")

        echo "Downloading ${__executableName}..."
        if [ -z "$__fileExt" ]; then
          curl -L -S -s "$__pkgRelease" -o "$HOME/.dotfiles/opt/bin/$__executableName"; echo ""
          chmod +x "$HOME/.dotfiles/opt/bin/$__executableName";
        else
          curl -L -S -s "$__pkgRelease" -o "$HOME/.dotfiles/opt/tmp/$__fileName"; echo ""
          mkdir "$HOME/.dotfiles/opt/tmp/$__pkgName"

          echo "Extracting archive..."
          if [ "$__fileExt" = "7z" ]; then
            unar "$HOME/.dotfiles/opt/tmp/$__fileName" -o "$HOME/.dotfiles/opt/tmp/$__pkgName/"
          else
            #Fallback to using tar
            tar -xzf "$HOME/.dotfiles/opt/tmp/$__fileName" -C "$HOME/.dotfiles/opt/tmp/$__pkgName/"
          fi

          if [ -f "$HOME"/.dotfiles/opt/tmp/"$__pkgName"/"$__pkgName" ]; then
            mv "$HOME"/.dotfiles/opt/tmp/"$__pkgName"/"$__pkgName" ~/.dotfiles/opt/bin
          elif [ -f "$HOME"/.dotfiles/opt/tmp/"$__pkgName"/"$__executableName" ]; then
            mv "$HOME"/.dotfiles/opt/tmp/"$__pkgName"/"$__executableName" ~/.dotfiles/opt/bin
          else
            mv "$HOME"/.dotfiles/opt/tmp/"$__pkgName"/"$__pkgName"/*/bin/"$__executableName" ~/.dotfiles/opt/bin
          fi

          xattr -d com.apple.quarantine ~/.dotfiles/opt/bin/"$__executableName" #un-quarantine file
        fi
      fi

      if [ -x "$(command -v "$__executableName")" ]; then
        rm -f "$HOME/.dotfiles/opt/tmp/$__fileName"
        rm -rf "$HOME/.dotfiles/opt/tmp/$__pkgName"
        echo "  ++ GOOD - $__executableName is now available ++"; echo "";
      else
        echo "BAD - $__executableName doesn't seem to be available"
      fi
    else
      echo "Unable to install $__executableName - OS version ($OS_FAMILY $OS_ARCH) doesn't have supported function"; echo "";
    fi
  fi

  # Cleanup variables - can cause unexpected bugs if not done.
  # Scoped variables (local) not available in base bourne shell.
  unset __binaryURL; unset __pkgName; unset __executableName;
  unset __pkgRelease; unset __fileName; unset __fileExt;
}

install_diffsofancy () {
  #Git: diff-so-fancy (better git diff)
  if [ ! -f "$HOMEREPO/opt/bin/diff-so-fancy" ]; then
    install_curl
    install_perl
    if [ -x "$(command -v perl)" ]; then
      install_generic_github "so-fancy/diff-so-fancy" "diff-so-fancy"
    else
      echo "Not downloading diff-so-fancy: perl is not available"
    fi
  fi
}

install_youtubedl () {
    if [ ! -x "$(command -v youtube-dl)" ] && [ ! -f "$HOME/.dotfiles/opt/bin/youtube-dl" ]; then
      install_curl
      echo "NOTE: youtube-dl not found, downloading to dotfiles bin location"
      echo "------------------------------------------------"
      curl -L -S -s https://yt-dl.org/downloads/latest/youtube-dl -o "$HOME/.dotfiles/opt/bin/youtube-dl"; echo ""
      chmod a+rx "$HOME/.dotfiles/opt/bin/youtube-dl"
    fi
    install_ffmpeg
    install_ffprobe
    install_phantomjs
}

install_unar () {
  if [ ! -x "$(command -v unar)" ]; then
    if [ "$OS_PLATFORM" = "macos" ]; then
      install_generic_homebrew unar
      #install_generic_binary "https://cdn.theunarchiver.com/downloads/unarMac.zip" "unar"
    else
      echo "Unable to install unar - OS version ($OS_FAMILY $OS_ARCH) doesn't have supported function"; echo "";
    fi
  fi
}

install_ffmpeg () {
  if isMissingOrFakeCmd ffmpeg; then
    if [ "${IS_ASHELL:-}" = true ]; then
      echo 'ffmpeg is normally bundled with a-Shell; update or reinstall the app if it is unavailable.' >&2
      return 1
    elif [ "$OS_FAMILY" = "Linux" ] && command_exists apk; then
      install_generic_apk ffmpeg ffmpeg
      return
    elif [ "$OS_FAMILY" = "Linux" ] && command_exists apt; then
      install_generic_apt ffmpeg ffmpeg
      return
    fi

    install_curl
    if [ "$OS_PLATFORM" = "macos" ]; then
      install_unar
      echo "NOTE: ffmpeg not found, installing into dotfiles bin"
      echo "------------------------------------------------"
      if [ ! -x "$(command -v unar)" ]; then
        echo "Unable to install ffmpeg - missing unar"; echo ""
        return 1
      fi

      if [ ! -d "$HOMEREPO/opt/tmp" ]; then
        mkdir -p "$HOMEREPO/opt/tmp"
      fi

      ffmpeg="https://evermeet.cx/pub/ffmpeg/snapshots/"
      latest=$(curl $ffmpeg | grep -v ".7z.sig" | grep .7z | head -1 | sed -n 's/.*href="\([^"]*\).*/\1/p')
      curl "$ffmpeg$latest" -o "$HOMEREPO/opt/tmp/ffmpeg.7z"; echo ""

      unar "$HOMEREPO/opt/tmp/ffmpeg.7z" -o "$HOMEREPO/opt/bin/"
      rm -r "$HOMEREPO/opt/tmp/ffmpeg.7z"

      if [ -x "$(command -v ffmpeg)" ]; then
        echo "  ++ GOOD - ffmpeg is now available ++"; echo "";
      else
        echo "BAD - ffmpeg doesn't seem to be available"
      fi
    else
      echo "Unable to install ffmpeg - OS version ($OS_FAMILY $OS_ARCH) doesn't have supported function"; echo "";
    fi
    unset ffmpeg; unset latest;
  fi
}

install_ffprobe () {
  if isMissingOrFakeCmd ffprobe; then
    if [ "${IS_ASHELL:-}" = true ]; then
      echo 'ffprobe is normally bundled with a-Shell; update or reinstall the app if it is unavailable.' >&2
      return 1
    elif [ "$OS_FAMILY" = "Linux" ] && command_exists apk; then
      install_generic_apk ffmpeg ffprobe
      return
    elif [ "$OS_FAMILY" = "Linux" ] && command_exists apt; then
      install_generic_apt ffmpeg ffprobe
      return
    fi

    install_curl
    if [ "$OS_PLATFORM" = "macos" ]; then
      install_unar
      echo "NOTE: ffprobe not found, installing into dotfiles bin"
      echo "------------------------------------------------"
      if [ ! -x "$(command -v unar)" ]; then
        echo "Unable to install ffprobe - missing unar"; echo ""
        return 1
      fi

      if [ ! -d "$HOMEREPO/opt/tmp" ]; then
        mkdir -p "$HOMEREPO/opt/tmp"
      fi

      ffprobe="https://evermeet.cx/pub/ffprobe/snapshots/"
      latest=$(curl $ffprobe | grep -v ".7z.sig" | grep .7z | head -1 | sed -n 's/.*href="\([^"]*\).*/\1/p')
      curl "$ffprobe/$latest" -o "$HOMEREPO/opt/tmp/ffprobe.7z"; echo ""

      unar "$HOMEREPO/opt/tmp/ffprobe.7z" -o "$HOMEREPO/opt/bin/"
      rm -r "$HOMEREPO/opt/tmp/ffprobe.7z"

      if [ -x "$(command -v ffprobe)" ]; then
        echo "  ++ GOOD - ffprobe is now available ++"; echo "";
      else
        echo "BAD - ffprobe doesn't seem to be available"
      fi
    else
      echo "Unable to install ffprobe - OS version ($OS_FAMILY $OS_ARCH) doesn't have supported function"; echo "";
    fi
    unset ffprobe; unset latest;
  fi
}

install_phantomjs () {
    if [ ! -x "$(command -v phantomjs)" ]; then
      install_curl
      if [ "$OS_PLATFORM" = "macos" ]; then
        echo "NOTE: phantomjs not found, installing into dotfiles bin"
        echo "------------------------------------------------"

        if [ ! -d "$HOME/.dotfiles/opt/tmp" ]; then
          mkdir -p "$HOME/.dotfiles/opt/tmp"
        fi

        phantomjs="http://phantomjs.org/download.html"
        latest=$(curl -L -S -s $phantomjs | sed -n 's/.*href="\([^"]*\).*/\1/p' | grep osx.zip)
        curl -L -S -s "$latest" -o "$HOME/.dotfiles/opt/tmp/phantomjs.zip"; echo ""

        unzip -j "$HOME/.dotfiles/opt/tmp/phantomjs.zip" "*/bin/phantomjs" -d "$HOME/.dotfiles/opt/bin/"
        rm -r "$HOME/.dotfiles/opt/tmp/phantomjs.zip"

        if [ -x "$(command -v phantomjs)" ]; then
          echo "  ++ GOOD - phantomjs is now available ++"; echo "";
        else
          echo "BAD - phantomjs doesn't seem to be available"
        fi
      else
        echo "Unable to install phantomjs - OS version ($OS_FAMILY $OS_ARCH) doesn't have supported function"; echo "";
      fi
      unset phantomjs; unset latest;
    fi
}

install_jq () {
  if [ ! -x "$(command -v jq)" ]; then
    if [ "$OS_FAMILY" = "Linux" ] && command_exists apk; then
      install_generic_apk jq jq
    elif [ "$OS_PLATFORM" = "macos" ]; then
      install_generic_github "jqlang/jq" "jq" "osx"
    elif [ "$OS_FAMILY" = "Linux" ] && [ "$OS_ARCH" = "x64" ]; then
      install_generic_github "jqlang/jq" "jq" "linux64"
    elif [ "$OS_FAMILY" = "Linux" ] && [ "$OS_ARCH" = "x32" ]; then
      install_generic_github "jqlang/jq" "jq" "linux32"
    else
      echo "install_jq: OS version ($OS_FAMILY $OS_ARCH) doesn't have supported function"; echo "";
    fi
  fi
}

install_shellcheck () {
  if [ ! -x "$(command -v shellcheck)" ]; then
    if [ "$OS_FAMILY" = "Linux" ] && command_exists apk; then
      install_generic_apk shellcheck shellcheck
    elif [ "$OS_PLATFORM" = "macos" ]; then
      install_generic_homebrew "shellcheck"
    elif [ "$OS_FAMILY" = "Linux" ] && [ "$OS_ARCH" = "x64" ]; then
      install_generic_github "koalaman/shellcheck" "shellcheck" "linux.x86_64"
    else
      echo "install_shellcheck: OS version ($OS_FAMILY $OS_ARCH) doesn't have supported function"; echo "";
    fi
  fi
}

install_shfmt () {
  if [ ! -x "$(command -v shfmt)" ]; then
    if [ "$OS_FAMILY" = "Linux" ] && command_exists apk; then
      install_generic_apk shfmt shfmt
    elif [ "$OS_PLATFORM" = "macos" ] && [ "$OS_ARCH" = "ARM64" ]; then
      install_generic_github "mvdan/sh" "shfmt" "darwin_amd64"
    elif [ "$OS_PLATFORM" = "macos" ] && [ "$OS_ARCH" = "x64" ]; then
      install_generic_github "mvdan/sh" "shfmt" "darwin_amd64"
    elif [ "$OS_FAMILY" = "Linux" ] && [ "$OS_ARCH" = "x64" ]; then
      install_generic_github "mvdan/sh" "shfmt" "linux_amd64"
    elif [ "$OS_FAMILY" = "Linux" ] && [ "$OS_ARCH" = "x32" ]; then
      install_generic_github "mvdan/sh" "shfmt" "linux_386"
    else
      echo "Unable to install shfmt - OS version ($OS_FAMILY $OS_ARCH) doesn't have supported function"; echo "";
    fi
  fi
}

install_nerdfonts () {
    fontname="Droid Sans Mono for Powerline Nerd Font Complete.otf"
    if [ ! -f "$HOME/.dotfiles/opt/fonts/$fontname" ] && [ ! -f "$HOME/Library/Fonts/dotfiles/$fontname" ]; then
      install_curl
      if [ "$OS_PLATFORM" = "macos" ]; then
        echo "NOTE: nerd-fonts not found, availing into $HOME/Library/Fonts/dotfiles/"
        echo "------------------------------------------------------------------------"

        if [ ! -d "$HOME/Library/Fonts/dotfiles" ]; then mkdir "$HOME/Library/Fonts/dotfiles"; fi

        curl -fLo "$HOME/Library/Fonts/dotfiles/$fontname" \
          https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/DroidSansMono/complete/Droid%20Sans%20Mono%20Nerd%20Font%20Complete.otf

        if [ -f "$HOME/Library/Fonts/dotfiles/$fontname" ]; then
          echo "  ++ GOOD - nerd-fonts are now available ++"; echo "";
        else
          echo "BAD - nerd-fonts don't seem to be available"
        fi
      else
        echo "Unable to install nerd-fonts - OS version ($OS_FAMILY $OS_ARCH) doesn't have supported function"; echo "";
      fi
    fi
    unset fontname;
}

install_lsd () {
  if [ ! -x "$(command -v lsd)" ]; then
    if [ "$OS_PLATFORM" = "macos" ]; then
      install_generic_homebrew "lsd"
    elif [ "$OS_FAMILY" = "Linux" ] && [ -x "$(command -v apt)" ]; then
      install_generic_apt "lsd"
    elif [ "$OS_FAMILY" = "Linux" ] && [ "$OS_ARCH" = "x64" ] && notcontains "$OS_NAME" "Alpine"; then
      install_generic_github "Peltoche/lsd" "lsd" "x86_64-unknown-linux-musl"
    elif [ "$OS_FAMILY" = "Linux" ] && [ "$OS_ARCH" = "x32" ] && notcontains "$OS_NAME" "Alpine"; then
      install_generic_github "Peltoche/lsd" "lsd" "i686-unknown-linux-musl"
    else
      echo "install_lsd: OS version ($OS_STRING) doesn't have supported function"; echo "";
    fi
  fi
}

install_prettyping () {
    if [ ! -x "$(command -v prettyping)" ]; then
      install_curl
      if [ "$OS_PLATFORM" = "macos" ] || [ "$OS_FAMILY" = "Linux" ]; then
        echo "NOTE: prettyping not found, availing into dotfiles bin"
        echo "------------------------------------------------"

        curl -L -S -s https://raw.githubusercontent.com/denilsonsa/prettyping/master/prettyping -o ~/.dotfiles/opt/bin/prettyping
        chmod +x ~/.dotfiles/opt/bin/prettyping

        if [ -x "$(command -v prettyping)" ]; then
          echo "  ++ GOOD - prettyping is now available ++"; echo "";
        else
          echo "BAD - prettyping doesn't seem to be available"
        fi
      else
        echo "Unable to install prettyping - OS version ($OS_FAMILY $OS_ARCH) doesn't have supported function"; echo "";
      fi
    fi
}

install_ohmyzsh () {
  if skip_install_iSH_aShell "Oh My Zsh"; then
    return 0
  fi

  #Super enhancement framework for ZSH shell
  if [ ! -d ~/.dotfiles/opt/ohmyzsh ]; then
    if [ -x "$(command -v zsh)" ]; then
      install_curl
      echo "NOTE: OhMyZSH not found, installing to dotfiles opt location"
      echo "------------------------------------------------"
      echo ""; echo "Calling OhMyZSH installer script (w/ options)..."

      ZSH=~/.dotfiles/opt/ohmyzsh \
      CHSH="no" \
      RUNZSH="no" \
      KEEP_ZSHRC="yes" \
      sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

      if [ -d ~/.dotfiles/opt/ohmyzsh ]; then
        echo "  ++ GOOD - OhMyZSH is now available ++"; echo "";
      else
        echo "BAD - OhMyZSH doesn't seem to be available"
      fi
    # else
    #   echo "Not installing OhMyZSH: zsh is not available"
    fi
  fi
}

install_blesh () {
  echo "ble.sh installer script doesn't work, cant install, skipping for now"; echo "";
  return 1
  # __pkgName="ble.sh"
  # __pkgsafename="blesh"
  # __pkgdesc="Bash Syntax Highlighting"
  # if [ ! -f "$HOME/.dotfiles/opt/bash-extras/$__pkgsafename/$__pkgName" ] && [ -x "$(command -v bash)" ]; then
  #   install_curl
  #   echo "NOTE: $__pkgName ($__pkgdesc) not found, availing into dotfiles bin"
  #   echo "------------------------------------------------"

  #   if [ ! -d "$HOME/.dotfiles/opt/tmp" ]; then
  #     mkdir -p "$HOME/.dotfiles/opt/tmp"
  #   fi

  #   __pkgurl="https://api.github.com/repos/akinomyoga/ble.sh/releases/latest"
  #   latest=$(curl $__pkgurl -S -s  | grep url | grep "tar.xz" | sed 's/.*\(http[s?]:\/\/.*[^"]\).*/\1/')
  #   __fileName=${latest##*/}

  #   curl -L -S -s "$latest" -o "$HOME/.dotfiles/opt/tmp/$__fileName"; echo ""

  #   mkdir "$HOME/.dotfiles/opt/tmp/$__pkgsafename"
  #   tar -xzf "$HOME/.dotfiles/opt/tmp/$__fileName" -C "$HOME/.dotfiles/opt/tmp/$__pkgsafename"
  #   mkdir -p "$HOME/.dotfiles/opt/bash-extras/$__pkgsafename"
  #   cp -r "$HOME"/.dotfiles/opt/tmp/$__pkgsafename/*/ ~/.dotfiles/opt/bash-extras/$__pkgsafename

  #   rm "$HOME/.dotfiles/opt/tmp/$__fileName"
  #   rm -rf "$HOME/.dotfiles/opt/tmp/$__pkgsafename"

  #   if [ -f "$HOME/.dotfiles/opt/bash-extras/$__pkgsafename/$__pkgName" ]; then
  #     echo "  ++ GOOD - $__pkgName ($__pkgdesc) is now available ++"; echo "";
  #   else
  #     echo "BAD - $__pkgName ($__pkgdesc) doesn't seem to be available"
  #   fi
  #   unset __pkgurl; unset latest; unset __fileName;
  # fi
  # unset __pkgName; unset __pkgsafename; unset __pkgdesc;
}

install_ncdu () {
  if [ ! -x "$(command -v ncdu)" ]; then
    if [ "$OS_PLATFORM" = "macos" ]; then
      install_homebrew
      if [ -x "$(command -v brew)" ]; then
        brew install "ncdu"
      # else
      #   install_generic_homebrew "ncdu"
      fi
    else
      echo "";
      echo "Unable to install ncdu - OS version ($OS_FAMILY $OS_ARCH) doesn't have supported function"; echo "";
    fi
  fi
}

install_git_delta () {
  if [ ! -x "$(command -v delta)" ]; then
    install_less
    if [ "$OS_PLATFORM" = "macos" ]; then
      #install_generic_homebrew "git-delta" "delta"
      install_homebrew
      brew install "delta"
    elif [ "$OS_FAMILY" = "Linux" ] && [ "$OS_ARCH" = "x64" ]; then
      install_generic_github "dandavison/delta" "delta" "x86_64-unknown-linux-musl"
    # Doesn't appear to be a 32bit pkg available on github releases
    # elif [ "$OS_FAMILY" = "Linux" ] && [ "$OS_ARCH" = "x32" ]; then
    #   install_generic_github "dandavison/delta" "delta" "i686-unknown-linux"
    else
      echo "";
      echo "install_git_delta: OS version ($OS_FAMILY $OS_ARCH) doesn't have supported function"; echo "";
    fi
  fi
}

install_bat () {
  if [ ! -x "$(command -v bat)" ]; then
    install_less
    if [ "$OS_PLATFORM" = "macos" ]; then
      install_homebrew
      brew install "bat"
    elif [ "$OS_FAMILY" = "Linux" ] && [ -x "$(command -v apk)" ]; then
      install_generic_apk "bat"
    elif [ "$OS_FAMILY" = "Linux" ] && [ "$OS_ARCH" = "x64" ]; then
      install_generic_github "sharkdp/bat" "bat" "x86_64-unknown-linux-musl"
    elif [ "$OS_FAMILY" = "Linux" ] && [ "$OS_ARCH" = "x32" ]; then
      install_generic_github "sharkdp/bat" "bat" "i686-unknown-linux-musl"
    else
      echo "";
      echo "install_bat: OS version ($OS_FAMILY $OS_ARCH) doesn't have supported function"; echo "";
    fi
  fi
}

install_ytdlp() {
  __forceYtdlpUpdate=false
  [ "${1:-}" = '--update' ] && __forceYtdlpUpdate=true
  __managedYtdlp="$HOMEREPO/opt/bin/yt-dlp"

  if [ "${IS_ASHELL:-}" = true ] || [ "${IS_ISH:-}" = true ] || [ "$OS_FAMILY" = "Linux" ]; then
    if [ "${IS_ASHELL:-}" != true ]; then
      install_python3 || return 1
    elif ! command_exists python3; then
      echo 'yt-dlp requires a-Shell Python 3; update or reinstall the app.' >&2
      return 1
    fi

    if [ "$__forceYtdlpUpdate" = true ] || [ ! -s "$__managedYtdlp" ]; then
      if ! command_exists curl; then
        install_curl || return 1
      fi
      if ! mkdir -p "$HOMEREPO/opt/bin" "$HOMEREPO/opt/tmp"; then
        unset __forceYtdlpUpdate __managedYtdlp
        return 1
      fi
      if command_exists mktemp; then
        __ytdlpDownload=$(mktemp "$HOMEREPO/opt/tmp/yt-dlp.download.XXXXXX") || {
          unset __forceYtdlpUpdate __managedYtdlp __ytdlpDownload
          return 1
        }
      else
        __ytdlpDownload="$HOMEREPO/opt/tmp/yt-dlp.download.$$"
      fi
      echo "Downloading the platform-independent yt-dlp release into $HOMEREPO/opt/bin"
      if ! curl -fL -S 'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp' -o "$__ytdlpDownload"; then
        rm -f "$__ytdlpDownload"
        unset __forceYtdlpUpdate __managedYtdlp __ytdlpDownload
        return 1
      fi
      if [ ! -s "$__ytdlpDownload" ]; then
        echo 'yt-dlp download was empty; keeping the previous installation.' >&2
        rm -f "$__ytdlpDownload"
        unset __forceYtdlpUpdate __managedYtdlp __ytdlpDownload
        return 1
      fi
      if ! python3 "$__ytdlpDownload" --version >/dev/null 2>&1; then
        echo 'Downloaded yt-dlp release failed its Python validation; keeping the previous installation.' >&2
        rm -f "$__ytdlpDownload"
        unset __forceYtdlpUpdate __managedYtdlp __ytdlpDownload
        return 1
      fi
      if ! chmod a+rx "$__ytdlpDownload" || ! mv "$__ytdlpDownload" "$__managedYtdlp"; then
        echo 'Unable to install the validated yt-dlp download.' >&2
        rm -f "$__ytdlpDownload"
        unset __forceYtdlpUpdate __managedYtdlp __ytdlpDownload
        return 1
      fi
      if [ ! -s "$__managedYtdlp" ]; then
        echo 'Managed yt-dlp installation is missing after the update.' >&2
        unset __forceYtdlpUpdate __managedYtdlp __ytdlpDownload
        return 1
      fi
      rehash 2>/dev/null || :
    fi
  elif [ "$OS_PLATFORM" = "macos" ]; then
    if [ "$__forceYtdlpUpdate" = true ] && [ -x "$__managedYtdlp" ]; then
      "$__managedYtdlp" -U || return 1
    elif isMissingOrFakeCmd yt-dlp; then
      install_generic_github "yt-dlp/yt-dlp" "yt-dlp" "yt-dlp_macos" --exact
    fi
  else
    echo "install_ytdlp: OS version ($OS_FAMILY $OS_ARCH) doesn't have a supported installer" >&2
    unset __forceYtdlpUpdate __managedYtdlp
    return 1
  fi

  install_ffmpeg || {
    unset __forceYtdlpUpdate __managedYtdlp __ytdlpDownload
    return 1
  }
  install_ffprobe || {
    unset __forceYtdlpUpdate __managedYtdlp __ytdlpDownload
    return 1
  }

  if [ "${IS_ASHELL:-}" = true ]; then
    install_generic_ashell qjs qjs || echo 'WARNING: qjs installation failed; YouTube JavaScript challenge support will be limited.' >&2
  elif [ "${IS_ISH:-}" = true ]; then
    echo 'NOTE: iSH has no supported current JavaScript runtime; yt-dlp works, but some YouTube formats/challenges may be unavailable.'
  else
    install_deno
  fi

  unset __forceYtdlpUpdate __managedYtdlp __ytdlpDownload
}

install_tput () {
  if [ ! -x "$(command -v tput)" ]; then
    if [ "$OS_FAMILY" = "Linux" ] && [ -x "$(command -v apk)" ]; then
      install_generic_apk "ncurses" "tput"
    elif [ "$OS_FAMILY" = "Linux" ] && [ -x "$(command -v apt)" ]; then
      install_generic_apt "tput"
    else
      echo "";
      echo "install_tput: OS version ($OS_FAMILY $OS_ARCH) doesn't have supported function"; echo "";
    fi
  fi
}

install_curl () {
  if isMissingOrFakeCmd curl; then
    if [ "${IS_ASHELL:-}" = true ]; then
      echo 'curl is normally bundled with a-Shell; update or reinstall the app if it is unavailable.' >&2
      return 1
    fi
    if [ "$OS_FAMILY" = "Linux" ] && [ -x "$(command -v apk)" ]; then
      install_generic_apk "curl"
    elif [ "$OS_FAMILY" = "Linux" ] && [ -x "$(command -v apt)" ]; then
      install_generic_apt "curl"
    else
      echo "";
      echo "install_curl: Unable to install - OS version ($OS_FAMILY $OS_ARCH) doesn't have supported function"; echo "";
    fi
  fi
}

install_vim () {
  if [ ! -x "$(command -v vim)" ]; then
    if [ "$OS_FAMILY" = "Linux" ] && [ -x "$(command -v apk)" ]; then
      install_generic_apk "vim"
    elif [ "$OS_FAMILY" = "Linux" ] && [ -x "$(command -v apt)" ]; then
      install_generic_apt "vim"
    else
      echo "";
      echo "install_vim: Unable to install - OS version ($OS_FAMILY $OS_ARCH) doesn't have supported function"; echo "";
    fi
  fi
}

install_vim_plugins() {
  # if ! isRealCommand "vim"; then
  #   echo "install_vim_plugins: vim is not available; skipping its plugins." >&2
  #   return 1
  # fi

  install_curl || return 1
  if ! isRealCommand "git"; then
    install_git || return 1
  fi
  . "$HOMEREPO/vim/init_vim.sh"
}

install_perl () {
  if [ ! -x "$(command -v perl)" ]; then
    if [ "$OS_FAMILY" = "Linux" ] && [ -x "$(command -v apk)" ]; then
      install_generic_apk "perl"
    elif [ "$OS_FAMILY" = "Linux" ] && [ -x "$(command -v apt)" ]; then
      install_generic_apt "perl"
    else
      echo "";
      echo "install_perl: OS version ($OS_FAMILY $OS_ARCH) doesn't have supported function"; echo "";
    fi
  fi
}

install_opensshkeygen () {
  if [ ! -x "$(command -v ssh-keygen)" ]; then
    if [ "$OS_FAMILY" = "Linux" ] && [ -x "$(command -v apk)" ]; then
      install_generic_apk "openssh-keygen" "ssh-keygen"
    elif [ "$OS_FAMILY" = "Linux" ] && [ -x "$(command -v apt)" ]; then
      install_generic_apt "openssh-keygen"
    else
      echo "";
      echo "install_opensshkeygen: Unable to install - OS version ($OS_FAMILY $OS_ARCH) doesn't have supported function"; echo "";
    fi
  fi
}

install_python3 () {
  if isMissingOrFakeCmd python3; then
    if [ "${IS_ASHELL:-}" = true ]; then
      echo 'Python 3 is normally bundled with a-Shell; update or reinstall the app if it is unavailable.' >&2
      return 1
    fi
    if [ "$OS_FAMILY" = "Linux" ] && [ -x "$(command -v apk)" ]; then
      install_generic_apk "python3"
    elif [ "$OS_FAMILY" = "Linux" ] && [ -x "$(command -v apt)" ]; then
      install_generic_apt "python3"
    else
      echo "";
      echo "install_python3: OS version ($OS_FAMILY $OS_ARCH) doesn't have supported function"; echo "";
    fi
  fi
}

install_whereis () {
  if [ ! -x "$(command -v whereis)" ]; then
    if [ "$OS_FAMILY" = "Linux" ] && [ -x "$(command -v apk)" ]; then
      install_generic_apk "util-linux" "whereis"
    elif [ "$OS_FAMILY" = "Linux" ] && [ -x "$(command -v apt)" ]; then
      install_generic_apt "whereis"
    else
      echo "";
      echo "install_whereis: OS version ($OS_FAMILY $OS_ARCH) doesn't have supported function"; echo "";
    fi
  fi
}

install_less () {
  if isMissingOrFakeCmd "less"; then
    if [ "$OS_FAMILY" = "Linux" ] && [ -x "$(command -v apk)" ]; then
      install_generic_apk "less"
    elif [ "$OS_FAMILY" = "Linux" ] && [ -x "$(command -v apt)" ]; then
      install_generic_apt "less"
    else
      echo "";
      echo "install_less: OS version ($OS_FAMILY $OS_ARCH) doesn't have supported function"; echo "";
    fi
  fi
}

install_aria2 () {
  if [ ! -x "$(command -v aria2)" ]; then
    if [ "$OS_PLATFORM" = "macos" ]; then
      install_homebrew
      if [ -x "$(command -v brew)" ]; then
        brew install "aria2"
      # else
      #   install_generic_homebrew "aria2" "aria2c"
      fi
    else
      echo "";
      echo "Unable to install aria2 - OS version ($OS_FAMILY $OS_ARCH) doesn't have supported function"; echo "";
    fi
  fi
}

install_homebrew () {
  if [ "$OS_PLATFORM" = "macos" ]; then
    export HOMEBREW_INSTALL_FROM_API=1;
    if [ ! -x "$(command -v brew)" ]; then
      install_xcodeCMDlineTools
      __homebrewNewDir="$HOME/.dotfiles/opt/homebrew"
      mkdir -p "$__homebrewNewDir"
      githubCloneByCurl https://github.com/Homebrew/brew "$__homebrewNewDir";
      #curl -L -S -s https://github.com/Homebrew/brew/tarball/master | tar xz --strip 1 -C "$__homebrewNewDir"

      eval "$("$__homebrewNewDir"/bin/brew shellenv)"
      brew update --force --quiet
      chmod -R go-w "$(brew --prefix)/share/zsh"

      if [ -x "$(command -v brew)" ]; then
        echo "  ++ GOOD - brew is now available ++"; echo "";
      else
        echo "BAD - brew doesn't seem to be available"
      fi
    fi
  fi
}

install_xcodeCMDlineTools () {
  if [ "$OS_PLATFORM" = "macos" ]; then
    if [ ! -f "/Library/Developer/CommandLineTools/usr/bin/clang" ]; then
      echo 'Installing XCode Command Line tools...'
      in_progress=/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
      touch ${in_progress}
      product=$(softwareupdate --list | grep "\*.*Command Line" | tail -n 1 | awk -F"*" '{print $2}' |
                      sed -e 's/^ *Label: //' -e 's/^ *//' |
                      sort -V |
                      tail -n1)
      echo "Available version installing: $product"
      softwareupdate --verbose --install "${product}" || echo 'Installation failed.' 1>&2
      if [ -f "$in_progress" ]; then rm ${in_progress}; fi

      if [ -f "/Library/Developer/CommandLineTools/usr/bin/clang" ]; then
        echo "  ++ GOOD - Command Line Tools are now available ++"; echo "";
      else
        echo "BAD - Command Line Tools don't seem to be available"
      fi
    fi
  fi
}

install_macRosetta2 () {
  if [ "$OS_PLATFORM" = "macos" ]; then
    if [ ! -f "/Library/Apple/usr/share/rosetta/rosetta" ]; then
      echo 'Installing Rosetta2...'
      softwareupdate --install-rosetta --agree-to-license || echo 'Installation failed.' 1>&2

      if [ -f "/Library/Apple/usr/share/rosetta/rosetta" ]; then
        echo "  ++ GOOD - Rosetta2 is now available ++"; echo "";
      else
        echo "BAD - Rosetta2 don't seem to be available"
      fi
    fi
  fi
}

install_git () {
  if [ "${IS_ASHELL:-}" = true ]; then
    echo "a-Shell provides lg2 rather than a fully compatible git command; automatic git setup is skipped."
    return 0
  fi

  if isMissingOrFakeCmd "git"; then
    if [ "$OS_PLATFORM" = "macos" ]; then
      install_homebrew
      if [ -x "$(command -v brew)" ] && isMissingOrFakeCmd "git"; then
        #This likely won't run since Homebrew installs xCode, which installs git
        brew install "git"
      fi

      if isRealCommand "git"; then
        echo "  ++ GOOD - git is now available ++"; echo "";
      else
        echo "BAD - git doesn't seem to be available"
      fi
    elif [ "$OS_FAMILY" = "Linux" ] && [ -x "$(command -v apk)" ]; then
      install_generic_apk "git"
    elif [ "$OS_FAMILY" = "Linux" ] && [ -x "$(command -v apt)" ]; then
      install_generic_apt "git"
    else
      echo "";
      echo "Unable to install git - OS version ($OS_FAMILY $OS_ARCH) doesn't have supported function"; echo "";
    fi
  fi
  if [ "${IS_ISH:-}" != true ]; then
    install_git_lfs
  fi
}

install_git_lfs() {
  if isMissingOrFakeCmd "git-lfs"; then
    if [ "$OS_PLATFORM" = "macos" ]; then
      install_homebrew
      if [ -x "$(command -v brew)" ] && isMissingOrFakeCmd "git-lfs"; then
        brew install "git-lfs"
        git lfs install
      fi

      if isRealCommand "git-lfs"; then
        echo "  ++ GOOD - git-lfs is now available ++"; echo "";
      else
        echo "BAD - git-lfs doesn't seem to be available"
      fi
    elif [ "$OS_FAMILY" = "Linux" ] && [ -x "$(command -v apk)" ]; then
      install_generic_apk "git-lfs"
    elif [ "$OS_FAMILY" = "Linux" ] && [ -x "$(command -v apt)" ]; then
      install_generic_apt "git-lfs"
    else
      echo "";
      echo "Unable to install git-lfs - OS version ($OS_FAMILY $OS_ARCH) doesn't have supported function"; echo "";
    fi
  fi
}

install_pip () {
  if [ ! -d ~/.dotfiles/opt/pip_packages ]; then
    mkdir -p ~/.dotfiles/opt/pip_packages
  fi
  PATH=$PATH:~/.dotfiles/opt/pip_packages/bin
  PYTHONPATH=~/.dotfiles/opt/pip_packages
  export PYTHONPATH
  if isMissingOrFakeCmd "pip"; then
    install_python3
    if isRealCommand "python3"; then
      python3 -m ensurepip --upgrade

      if isRealCommand "pip"; then
        echo "  ++ GOOD - pip is now available ++"; echo "";
      else
        echo "BAD - pip doesn't seem to be available"
      fi
    else
      echo "";
      echo "Unable to install pip - OS version ($OS_FAMILY $OS_ARCH) doesn't have supported function"; echo "";
    fi
  fi
}

install_asitop () {
  if [ "$OS_PLATFORM" = "macos" ]; then
    if isMissingOrFakeCmd "asitop"; then
      install_pip
      if isRealCommand "pip"; then
        pip install asitop --target ~/.dotfiles/opt/pip_packages/

        if isRealCommand "asitop"; then
          echo "  ++ GOOD - asitop is now available ++"; echo "";
        else
          echo "BAD - asitop doesn't seem to be available"
        fi
      fi
    fi
  else
    echo "";
    echo "Unable to install asitop - OS version ($OS_FAMILY $OS_ARCH) doesn't have supported function"; echo "";
  fi
}

install_tmux() {
  if isMissingOrFakeCmd "tmux"; then
    if [ "$OS_PLATFORM" = "macos" ]; then
      install_homebrew
      if [ -x "$(command -v brew)" ] && isMissingOrFakeCmd "tmux"; then
        brew install "tmux"
      fi

      if isRealCommand "tmux"; then
        echo "  ++ GOOD - tmux is now available ++"; echo "";
      else
        echo "BAD - tmux doesn't seem to be available"
      fi
    elif [ "$OS_FAMILY" = "Linux" ] && [ -x "$(command -v apk)" ]; then
      install_generic_apk "tmux"
    elif [ "$OS_FAMILY" = "Linux" ] && [ -x "$(command -v apt)" ]; then
      install_generic_apt "tmux"
    else
      echo "";
      echo "Unable to install tmux - OS version ($OS_FAMILY $OS_ARCH) doesn't have supported function"; echo "";
    fi
  fi

  if [ "${RUNNINGINITSCRIPT:-}" != true ] &&
     isRealCommand "tmux" &&
     [ ! -d "$HOMEREPO/opt/tmux/plugins/tpm" ]; then
    install_tmux_plugins
  fi
}

install_tmux_plugins() {
  # if ! isRealCommand "tmux"; then
  #   echo "install_tmux_plugins: tmux is not available; skipping its plugins." >&2
  #   return 1
  # fi

  install_curl || return 1
  if ! isRealCommand "git"; then
    install_git || return 1
  fi
  . "$HOMEREPO/tmux/init_tmux.sh"
}

install_tree () {
  if [ ! -x "$(command -v tree)" ]; then
    if [ "$OS_PLATFORM" = "macos" ]; then
      install_homebrew
      brew install "tree"
    elif [ "$OS_FAMILY" = "Linux" ] && [ -x "$(command -v apk)" ]; then
      install_generic_apk "tree"
    elif [ "$OS_FAMILY" = "Linux" ] && [ -x "$(command -v apt)" ]; then
      install_generic_apt "tree"
    # elif [ "$OS_FAMILY" = "Linux" ] && [ "$OS_ARCH" = "x64" ]; then
    #   install_generic_github "sharkdp/bat" "bat" "x86_64-unknown-linux-musl"
    # elif [ "$OS_FAMILY" = "Linux" ] && [ "$OS_ARCH" = "x32" ]; then
    #   install_generic_github "sharkdp/bat" "bat" "i686-unknown-linux-musl"
    else
      echo "";
      echo "install_tree: OS version ($OS_FAMILY $OS_ARCH) doesn't have supported function"; echo "";
    fi
  fi
}

install_trash () {
  if [ ! -x "$(command -v trash)" ]; then
    if [ "$OS_PLATFORM" = "macos" ]; then
      install_homebrew
      brew install "trash"
    # elif [ "$OS_FAMILY" = "Linux" ] && [ -x "$(command -v apk)" ]; then
    #   install_generic_apk "tree"
    # elif [ "$OS_FAMILY" = "Linux" ] && [ "$OS_ARCH" = "x64" ]; then
    #   install_generic_github "sharkdp/bat" "bat" "x86_64-unknown-linux-musl"
    # elif [ "$OS_FAMILY" = "Linux" ] && [ "$OS_ARCH" = "x32" ]; then
    #   install_generic_github "sharkdp/bat" "bat" "i686-unknown-linux-musl"
    else
      echo "";
      echo "install_trash: OS version ($OS_FAMILY $OS_ARCH) doesn't have supported function"; echo "";
    fi
  fi
}

install_btop () {
  if [ ! -x "$(command -v btop)" ]; then
    if [ "$OS_PLATFORM" = "macos" ]; then
      install_homebrew
      brew install "btop"
    elif [ "$OS_FAMILY" = "Linux" ] && [ -x "$(command -v apt)" ]; then
      install_generic_apt "btop"
    # elif [ "$OS_FAMILY" = "Linux" ] && [ -x "$(command -v apk)" ]; then
    #   install_generic_apk "tree"
    # elif [ "$OS_FAMILY" = "Linux" ] && [ "$OS_ARCH" = "x64" ]; then
    #   install_generic_github "sharkdp/bat" "bat" "x86_64-unknown-linux-musl"
    # elif [ "$OS_FAMILY" = "Linux" ] && [ "$OS_ARCH" = "x32" ]; then
    #   install_generic_github "sharkdp/bat" "bat" "i686-unknown-linux-musl"
    else
      echo "";
      echo "install_btop: OS version ($OS_FAMILY $OS_ARCH) doesn't have supported function"; echo "";
    fi
  fi
}

install_htop () {
  if [ ! -x "$(command -v htop)" ]; then
    if [ "$OS_PLATFORM" = "macos" ]; then
      install_homebrew
      brew install "htop"
    elif [ "$OS_FAMILY" = "Linux" ] && [ -x "$(command -v apt)" ]; then
      install_generic_apt "htop"
    # elif [ "$OS_FAMILY" = "Linux" ] && [ -x "$(command -v apk)" ]; then
    #   install_generic_apk "tree"
    # elif [ "$OS_FAMILY" = "Linux" ] && [ "$OS_ARCH" = "x64" ]; then
    #   install_generic_github "sharkdp/bat" "bat" "x86_64-unknown-linux-musl"
    # elif [ "$OS_FAMILY" = "Linux" ] && [ "$OS_ARCH" = "x32" ]; then
    #   install_generic_github "sharkdp/bat" "bat" "i686-unknown-linux-musl"
    else
      echo "";
      echo "install_htop: OS version ($OS_FAMILY $OS_ARCH) doesn't have supported function"; echo "";
    fi
  fi
}

install_glances () {
  if [ ! -x "$(command -v glances)" ]; then
    if [ "$OS_PLATFORM" = "macos" ]; then
      install_homebrew
      brew install "glances"
    elif [ "$OS_FAMILY" = "Linux" ] && [ -x "$(command -v apt)" ]; then
      install_generic_apt "glances"
    # elif [ "$OS_FAMILY" = "Linux" ] && [ -x "$(command -v apk)" ]; then
    #   install_generic_apk "tree"
    # elif [ "$OS_FAMILY" = "Linux" ] && [ "$OS_ARCH" = "x64" ]; then
    #   install_generic_github "sharkdp/bat" "bat" "x86_64-unknown-linux-musl"
    # elif [ "$OS_FAMILY" = "Linux" ] && [ "$OS_ARCH" = "x32" ]; then
    #   install_generic_github "sharkdp/bat" "bat" "i686-unknown-linux-musl"
    else
      echo "";
      echo "install_glances: OS version ($OS_FAMILY $OS_ARCH) doesn't have supported function"; echo "";
    fi
  fi
}

install_mactop () {
  if [ ! -x "$(command -v mactop)" ]; then
    if [ "$OS_PLATFORM" = "macos" ]; then
      install_homebrew
      brew install "mactop"
    # elif [ "$OS_FAMILY" = "Linux" ] && [ -x "$(command -v apk)" ]; then
    #   install_generic_apk "tree"
    # elif [ "$OS_FAMILY" = "Linux" ] && [ "$OS_ARCH" = "x64" ]; then
    #   install_generic_github "sharkdp/bat" "bat" "x86_64-unknown-linux-musl"
    # elif [ "$OS_FAMILY" = "Linux" ] && [ "$OS_ARCH" = "x32" ]; then
    #   install_generic_github "sharkdp/bat" "bat" "i686-unknown-linux-musl"
    else
      echo "";
      echo "install_mactop: OS version ($OS_FAMILY $OS_ARCH) doesn't have supported function"; echo "";
    fi
  fi
}

install_zsh () {
  if skip_install_iSH_aShell "Zsh"; then
    return 0
  fi

  if [ ! -x "$(command -v zsh)" ]; then
    if [ "$OS_FAMILY" = "Linux" ] && command_exists apk; then
      install_generic_apk zsh zsh
    elif [ "$OS_FAMILY" = "Linux" ] && [ -x "$(command -v apt)" ]; then
      install_generic_apt "zsh"
    else
      echo "install_zsh: OS version ($OS_STRING) doesn't have supported function"; echo "";
    fi
  fi
}

install_zsh_plugins() {
  if skip_install_iSH_aShell "Oh My Zsh and the Zsh plugin suite"; then
    return 0
  fi

  # if ! isRealCommand "zsh"; then
  #   echo "install_zsh_plugins: zsh is not available; skipping its plugins." >&2
  #   return 0
  # fi

  install_curl || return 1
  if ! isRealCommand "git"; then
    install_git || return 1
  fi
  install_ohmyzsh || return 1
  . "$HOMEREPO/posixshells/zsh/init_zsh_addons.sh"
}

install_deno () {
  if [ ! -x "$(command -v deno)" ]; then
    if [ "${IS_ASHELL:-}" = true ] || [ "${IS_ISH:-}" = true ]; then
      echo "install_deno: no compatible Deno binary is available for $OS_PLATFORM/$OS_ARCH"
    elif [ "$OS_PLATFORM" = "macos" ]; then
      # install_homebrew
      # brew install "deno"
      install_generic_github "denoland/deno" "deno" "deno-aarch64-apple-darwin" "sha256"
    # elif [ "$OS_FAMILY" = "Linux" ] && [ -x "$(command -v apk)" ]; then
    #   install_generic_apk "tree"
    elif [ "$OS_FAMILY" = "Linux" ] && [ "$OS_ARCH" = "x64" ]; then
      install_generic_github "denoland/deno" "deno" "deno-x86_64-unknown-linux-gnu" "sha256"
    # elif [ "$OS_FAMILY" = "Linux" ] && [ "$OS_ARCH" = "x32" ]; then
    #   install_generic_github "sharkdp/bat" "bat" "i686-unknown-linux-musl"
    else
      echo "";
      echo "install_deno: OS version ($OS_FAMILY $OS_ARCH) doesn't have supported function"; echo "";
    fi
  fi
}

install_bandwhich () {
  if [ ! -x "$(command -v bandwhich)" ]; then
    if [ "$OS_PLATFORM" = "macos" ]; then
      install_homebrew
      brew install "bandwhich"
    elif [ "$OS_FAMILY" = "Linux" ] && [ -x "$(command -v apk)" ]; then
      install_generic_apk "bandwhich"
    # elif [ "$OS_FAMILY" = "Linux" ] && [ "$OS_ARCH" = "x64" ]; then
    #   install_generic_github "sharkdp/bat" "bat" "x86_64-unknown-linux-musl"
    # elif [ "$OS_FAMILY" = "Linux" ] && [ "$OS_ARCH" = "x32" ]; then
    #   install_generic_github "sharkdp/bat" "bat" "i686-unknown-linux-musl"
    else
      echo "";
      echo "install_bandwhich: OS version ($OS_FAMILY $OS_ARCH) doesn't have supported function"; echo "";
    fi
  fi
}

install_ntop () {
  if [ ! -x "$(command -v ntop)" ]; then
    install_bandwhich
  fi
}

install_rclone () {
  if [ ! -x "$(command -v rclone)" ]; then
    if [ "$OS_PLATFORM" = "macos" ]; then
      install_homebrew
      brew install "rclone"
    elif [ "$OS_FAMILY" = "Linux" ] && [ -x "$(command -v apk)" ]; then
      install_generic_apk "rclone"
    # elif [ "$OS_FAMILY" = "Linux" ] && [ "$OS_ARCH" = "x64" ]; then
    #   install_generic_github "sharkdp/bat" "bat" "x86_64-unknown-linux-musl"
    # elif [ "$OS_FAMILY" = "Linux" ] && [ "$OS_ARCH" = "x32" ]; then
    #   install_generic_github "sharkdp/bat" "bat" "i686-unknown-linux-musl"
    else
      echo "";
      echo "install_rclone: OS version ($OS_FAMILY $OS_ARCH) doesn't have supported function"; echo "";
    fi
  fi
}
