#!/bin/sh

if notcontains "$PATH" "$HOME/.dotfiles/opt/bin"; then
  PATH=$PATH:~/.dotfiles/opt/bin #Include dotfiles bin
fi

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

  #OLd code, leaving commented for now
  # #__pkgRelease=$(curl -S "$__repoURL" | jq -r ".assets[] | .browser_download_url" | grep "$__searchString") #jq dependent
  # $__results=""

  #echo "Looking up URLs for $__repoName..."
  __results=$(curl -S "$__repoURL" | grep url | grep download)
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
  if [ ! -x "$(command -v jq)" ]; then
      install_jq
  fi
  if [ ! -x "$(command -v "$__executableName")" ]; then
    if [ "$OS_FAMILY" = "Darwin" ]; then
      echo "NOTE: $__pkgName not found, availing into dotfiles bin"
      echo "------------------------------------------------"
      __pkgurl="https://formulae.brew.sh/api/formula/$__pkgName.json"
      bottles=$(curl -S "$__pkgurl" | jq -r "[.bottle.stable.files][0]")

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
        # curl has a hard time with the URL when doulbe quoted (probably due to colons)
        curl -H "Authorization: Bearer QQ==" -L $latest > "$HOME/.dotfiles/opt/tmp/$__fileName"; echo ""

        mkdir "$HOME/.dotfiles/opt/tmp/$__pkgName"
        tar -xzf "$HOME/.dotfiles/opt/tmp/$__fileName" -C "$HOME/.dotfiles/opt/tmp/$__pkgName/"

        mv "$HOME"/.dotfiles/opt/tmp/"$__pkgName"/"$__pkgName"/*/bin/"$__executableName" ~/.dotfiles/opt/bin
      fi

      if [ -x "$(command -v "$__executableName")" ]; then
        rm "$HOME/.dotfiles/opt/tmp/$__fileName"
        rm -rf "$HOME/.dotfiles/opt/tmp/$__pkgName"
        echo "GOOD - $__pkgName is now available"
      else
        echo "BAD - $__pkgName doesn't seem to be available"
      fi
    else
      echo "Unable to install $__pkgName - OS version doesn't have supported function"
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
    if [ "$OS_FAMILY" = "Darwin" ]; then
      echo "NOTE: $__executableName not found, availing into dotfiles bin"
      echo "------------------------------------------------"
      # shellcheck disable=SC2086
      __pkgRelease=$(identify_github_pkg $__originalArgs)
      echo "pkg: $__pkgRelease"

      if [ "$__pkgRelease" ];then
        if [ ! -d "$HOME/.dotfiles/opt/tmp" ]; then
          mkdir -p "$HOME/.dotfiles/opt/tmp"
        fi

        __fileName=${__pkgRelease##*/}
        __fileExt=$(getFileExt "$__fileName")

        echo "Downloading ${__executableName}..."
        if [ -z "$__fileExt" ]; then
          curl -L "$__pkgRelease" -o "$HOME/.dotfiles/opt/bin/$__executableName"; echo ""
          chmod +x "$HOME/.dotfiles/opt/bin/$__executableName";
        else
          curl -L "$__pkgRelease" -o "$HOME/.dotfiles/opt/tmp/$__fileName"; echo ""
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
          else
            # shellcheck disable=SC2086
            mv "$HOME"/.dotfiles/opt/tmp/"$__pkgName"/"$__pkgName"/*/bin/$__executableName ~/.dotfiles/opt/bin
          fi
        fi
      fi

      if [ -x "$(command -v "$__executableName")" ]; then
        rm -f "$HOME/.dotfiles/opt/tmp/$__fileName"
        rm -rf "$HOME/.dotfiles/opt/tmp/$__pkgName"
        echo "GOOD - $__executableName is now available"
      else
        echo "BAD - $__executableName doesn't seem to be available"
      fi
    else
      echo "Unable to install $__executableName - OS version doesn't have supported function"
    fi
  fi

  # Cleanup variables - can cause unexpected bugs if not done.
  # Scoped variables (local) not available in base bourne shell.
  unset __repoName; unset __repoURL; unset __pkgName; unset __executableName;
  unset __pkgRelease; unset __fileName; unset __fileExt;
}

install_generic_binary () {
  __binaryURL="$1"
  __pkgName="$(basename "$__binaryURL" | cut -d. -f1)"

  if [ -n "$2" ]; then
    __executableName="$2"
  fi

  if [ ! -x "$(command -v "$__executableName")" ]; then
    if [ "$OS_FAMILY" = "Darwin" ]; then
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
          curl -L "$__pkgRelease" -o "$HOME/.dotfiles/opt/bin/$__executableName"; echo ""
          chmod +x "$HOME/.dotfiles/opt/bin/$__executableName";
        else
          curl -L "$__pkgRelease" -o "$HOME/.dotfiles/opt/tmp/$__fileName"; echo ""
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

          xattr -d com.apple.quarantine ~/.dotfiles/opt/bin/"$__executableName" #unquarrantine file
        fi
      fi

      if [ -x "$(command -v "$__executableName")" ]; then
        rm -f "$HOME/.dotfiles/opt/tmp/$__fileName"
        rm -rf "$HOME/.dotfiles/opt/tmp/$__pkgName"
        echo "GOOD - $__executableName is now available"
      else
        echo "BAD - $__executableName doesn't seem to be available"
      fi
    else
      echo "Unable to install $__executableName - OS version doesn't have supported function"
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
    if [ -x "$(command -v perl)" ]; then
      echo "NOTE: diff-so-fancy not found, downloading to dotfiles bin location"
      echo "------------------------------------------------"
      echo ""; echo "Pulling down: diff-so-fancy (better git diff)"
      diffsofancy="https://raw.githubusercontent.com/so-fancy/diff-so-fancy/master/third_party/build_fatpack/diff-so-fancy"

      curl $diffsofancy > "$HOMEREPO/opt/bin/diff-so-fancy" && chmod 0755 "$HOMEREPO/opt/bin/diff-so-fancy";

      if [ -f "$HOMEREPO/opt/bin/diff-so-fancy" ]; then
        echo "GOOD - diff-so-fancy is now available"
      else
        echo "BAD - diff-so-fancy doesn't seem to be available"
      fi
    else
      echo "Not downloading diff-so-fancy: perl is not available"
    fi
    unset diffsofancy;
  fi
}

install_youtubedl () {
    if [ ! -x "$(command -v youtube-dl)" ] && [ ! -f "$HOME/.dotfiles/opt/bin/youtube-dl" ]; then
      echo "NOTE: youtube-dl not found, downloading to dotfiles bin location"
      echo "------------------------------------------------"
      curl -L https://yt-dl.org/downloads/latest/youtube-dl -o "$HOME/.dotfiles/opt/bin/youtube-dl"; echo ""
      chmod a+rx "$HOME/.dotfiles/opt/bin/youtube-dl"
    fi
    install_ffmpeg
    install_ffprobe
    install_phantomjs
}

install_unar () {
  if [ ! -x "$(command -v unar)" ]; then
    if [ "$OS_FAMILY" = "Darwin" ]; then
      install_generic_homebrew unar
      #install_generic_binary "https://cdn.theunarchiver.com/downloads/unarMac.zip" "unar"
    else
      echo "Unable to install unar - OS version doesn't have supported function"
    fi
  fi
}

install_ffmpeg () {
  if [ ! -x "$(command -v ffmpeg)" ]; then
    if [ "$OS_FAMILY" = "Darwin" ]; then
      install_unar
      echo "NOTE: ffmpeg not found, installing into dotfiles bin"
      echo "------------------------------------------------"
      if [ ! -x "$(command -v unar)" ]; then
        echo "Unable to install ffmpeg - missing unar"; echo ""
        return 1
      fi

      if [ ! -d "$HOME/.dotfiles/opt/tmp" ]; then
        mkdir -p "$HOME/.dotfiles/opt/tmp"
      fi

      ffmpeg="https://evermeet.cx/pub/ffmpeg/snapshots/"
      latest=$(curl $ffmpeg | grep -v ".7z.sig" | grep .7z | head -1 | sed -n 's/.*href="\([^"]*\).*/\1/p')
      curl "$ffmpeg$latest" -o "$HOME"/.dotfiles/opt/tmp/ffmpeg.7z; echo ""

      unar "$HOME/.dotfiles/opt/tmp/ffmpeg.7z" -o "$HOME/.dotfiles/opt/bin/"
      rm -r "$HOME/.dotfiles/opt/tmp/ffmpeg.7z"

      if [ -x "$(command -v ffmpeg)" ]; then
        echo "GOOD - ffmpeg is now available"
      else
        echo "BAD - ffmpeg doesn't seem to be available"
      fi
    else
      echo "Unable to install ffmpeg - OS version doesn't have supported function"
    fi
    unset ffmpeg; unset latest;
  fi
}

install_ffprobe () {
  if [ ! -x "$(command -v ffprobe)" ]; then
    if [ "$OS_FAMILY" = "Darwin" ]; then
      install_unar
      echo "NOTE: ffprobe not found, installing into dotfiles bin"
      echo "------------------------------------------------"
      if [ ! -x "$(command -v unar)" ]; then
        echo "Unable to install ffprobe - missing unar"; echo ""
        return 1
      fi

      if [ ! -d "$HOME/.dotfiles/opt/tmp" ]; then
        mkdir -p "$HOME/.dotfiles/opt/tmp"
      fi

      ffprobe="https://evermeet.cx/pub/ffprobe/snapshots/"
      latest=$(curl $ffprobe | grep -v ".7z.sig" | grep .7z | head -1 | sed -n 's/.*href="\([^"]*\).*/\1/p')
      curl "$ffprobe/$latest" -o "$HOME/.dotfiles/opt/tmp/ffprobe.7z"; echo ""

      unar "$HOME/.dotfiles/opt/tmp/ffprobe.7z" -o "$HOME/.dotfiles/opt/bin/"
      rm -r "$HOME/.dotfiles/opt/tmp/ffprobe.7z"

      if [ -x "$(command -v ffprobe)" ]; then
        echo "GOOD - ffprobe is now available"
      else
        echo "BAD - ffprobe doesn't seem to be available"
      fi
    else
      echo "Unable to install ffprobe - OS version doesn't have supported function"
    fi
    unset ffprobe; unset latest;
  fi
}

install_phantomjs () {
    if [ ! -x "$(command -v phantomjs)" ]; then
      if [ "$OS_FAMILY" = "Darwin" ]; then
        echo "NOTE: phantomjs not found, installing into dotfiles bin"
        echo "------------------------------------------------"

        if [ ! -d "$HOME/.dotfiles/opt/tmp" ]; then
          mkdir -p "$HOME/.dotfiles/opt/tmp"
        fi

        phantomjs="http://phantomjs.org/download.html"
        latest=$(curl -L $phantomjs | sed -n 's/.*href="\([^"]*\).*/\1/p' | grep osx.zip)
        curl -L "$latest" -o "$HOME/.dotfiles/opt/tmp/phantomjs.zip"; echo ""

        unzip -j "$HOME/.dotfiles/opt/tmp/phantomjs.zip" "*/bin/phantomjs" -d "$HOME/.dotfiles/opt/bin/"
        rm -r "$HOME/.dotfiles/opt/tmp/phantomjs.zip"

        if [ -x "$(command -v phantomjs)" ]; then
          echo "GOOD - phantomjs is now available"
        else
          echo "BAD - phantomjs doesn't seem to be available"
        fi
      else
        echo "Unable to install phantomjs - OS version doesn't have supported function"
      fi
      unset phantomjs; unset latest;
    fi
}

install_jq () {
  if [ ! -x "$(command -v jq)" ]; then
    if [ "$OS_FAMILY" = "Darwin" ]; then
      install_generic_github "stedolan/jq" "jq" "osx"
    elif [ "$OS_FAMILY" = "Linux" ] && [ "$OS_ARCH" = "x64" ]; then
      install_generic_github "stedolan/jq" "jq" "linux64"
    elif [ "$OS_FAMILY" = "Linux" ] && [ "$OS_ARCH" = "x32" ]; then
      install_generic_github "stedolan/jq" "jq" "linux32"
    else
      echo "Unable to install jq - OS version doesn't have supported function"
    fi
  fi
}

install_shellcheck () {
  if [ ! -x "$(command -v shellcheck)" ]; then
    if [ "$OS_FAMILY" = "Darwin" ]; then
      install_generic_homebrew "shellcheck"
    else
      echo "Unable to install shellcheck - OS version doesn't have supported function"
    fi
  fi
}

install_shfmt () {
  if [ ! -x "$(command -v shfmt)" ]; then
    if [ "$OS_FAMILY" = "Darwin" ]; then
      install_generic_github "mvdan/sh" "shfmt" "darwin_amd64"
    else
      echo "Unable to install shfmt - OS version doesn't have supported function"
    fi
  fi
}

install_nerdfonts () {
    fontname="Droid Sans Mono for Powerline Nerd Font Complete.otf"
    if [ ! -f "$HOME/.dotfiles/opt/fonts/$fontname" ] && [ ! -f "$HOME/Library/Fonts/dotfiles/$fontname" ]; then
      if [ "$OS_FAMILY" = "Darwin" ]; then
        echo "NOTE: nerd-fonts not found, availing into $HOME/Library/Fonts/dotfiles/"
        echo "------------------------------------------------------------------------"

        if [ ! -d "$HOME/Library/Fonts/dotfiles" ]; then mkdir "$HOME/Library/Fonts/dotfiles"; fi

        curl -fLo "$HOME/Library/Fonts/dotfiles/$fontname" \
          https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/DroidSansMono/complete/Droid%20Sans%20Mono%20Nerd%20Font%20Complete.otf

        if [ -f "$HOME/Library/Fonts/dotfiles/$fontname" ]; then
          echo "GOOD - nerd-fonts are now available"
        else
          echo "BAD - nerd-fonts don't seem to be available"
        fi
      else
        echo "Unable to install nerd-fonts - OS version doesn't have supported function"
      fi
    fi
    unset fontname;
}

install_lsd () {
  if [ ! -x "$(command -v lsd)" ]; then
    if [ "$OS_FAMILY" = "Darwin" ]; then
      install_generic_homebrew "lsd"
    else
      echo "Unable to install lsd - OS version doesn't have supported function"
    fi
  fi
}

install_prettyping () {
    if [ ! -x "$(command -v prettyping)" ]; then
      if [ "$OS_FAMILY" = "Darwin" ] || [ "$OS_FAMILY" = "Linux" ]; then
        echo "NOTE: prettyping not found, availing into dotfiles bin"
        echo "------------------------------------------------"

        curl -L https://raw.githubusercontent.com/denilsonsa/prettyping/master/prettyping -o ~/.dotfiles/opt/bin/prettyping
        chmod +x ~/.dotfiles/opt/bin/prettyping

        if [ -x "$(command -v prettyping)" ]; then
          echo "GOOD - prettyping is now available"
        else
          echo "BAD - prettyping doesn't seem to be available"
        fi
      else
        echo "Unable to install prettyping - OS version doesn't have supported function"
      fi
    fi
}

install_ohmyzsh () {
  #Super enhancement framework for ZSH shell
  if [ ! -d ~/.dotfiles/opt/ohmyzsh ]; then
    if [ -x "$(command -v zsh)" ]; then
      echo "NOTE: OhMyZSH not found, installing to dotfiles opt location"
      echo "------------------------------------------------"
      echo ""; echo "Calling OhMyZSH installer script (w/ options)..."

      ZSH=~/.dotfiles/opt/ohmyzsh \
      CHSH="no" \
      RUNZSH="no" \
      KEEP_ZSHRC="yes" \
      sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

      if [ -d ~/.dotfiles/opt/ohmyzsh ]; then
        echo "GOOD - OhMyZSH is now available"
      else
        echo "BAD - OhMyZSH doesn't seem to be available"
      fi
    # else
    #   echo "Not installing OhMyZSH: zsh is not available"
    fi
  fi
}

install_blesh () {
  echo "ble.sh installer script doesn't work, cant install, skipping for now"
  return 1
  __pkgName="ble.sh"
  __pkgsafename="blesh"
  __pkgdesc="Bash Syntax Highlighting"
  if [ ! -f "$HOME/.dotfiles/opt/bash-extras/$__pkgsafename/$__pkgName" ] && [ -x "$(command -v bash)" ]; then
    echo "NOTE: $__pkgName ($__pkgdesc) not found, availing into dotfiles bin"
    echo "------------------------------------------------"

    if [ ! -d "$HOME/.dotfiles/opt/tmp" ]; then
      mkdir -p "$HOME/.dotfiles/opt/tmp"
    fi

    __pkgurl="https://api.github.com/repos/akinomyoga/ble.sh/releases/latest"
    latest=$(curl $__pkgurl -s  | grep url | grep "tar.xz" | sed 's/.*\(http[s?]:\/\/.*[^"]\).*/\1/')
    __fileName=${latest##*/}

    curl -L "$latest" -o "$HOME/.dotfiles/opt/tmp/$__fileName"; echo ""

    mkdir "$HOME/.dotfiles/opt/tmp/$__pkgsafename"
    tar -xzf "$HOME/.dotfiles/opt/tmp/$__fileName" -C "$HOME/.dotfiles/opt/tmp/$__pkgsafename"
    mkdir -p "$HOME/.dotfiles/opt/bash-extras/$__pkgsafename"
    cp -r "$HOME"/.dotfiles/opt/tmp/$__pkgsafename/*/ ~/.dotfiles/opt/bash-extras/$__pkgsafename

    rm "$HOME/.dotfiles/opt/tmp/$__fileName"
    rm -rf "$HOME/.dotfiles/opt/tmp/$__pkgsafename"

    if [ -f "$HOME/.dotfiles/opt/bash-extras/$__pkgsafename/$__pkgName" ]; then
      echo "GOOD - $__pkgName ($__pkgdesc) is now available"
    else
      echo "BAD - $__pkgName ($__pkgdesc) doesn't seem to be available"
    fi
    unset __pkgurl; unset latest; unset __fileName;
  fi
  unset __pkgName; unset __pkgsafename; unset __pkgdesc;
}

install_ncdu () {
  if [ ! -x "$(command -v ncdu)" ]; then
    if [ "$OS_FAMILY" = "Darwin" ]; then
      install_generic_homebrew "ncdu"
    else
      echo "Unable to install ncdu - OS version doesn't have supported function"
    fi
  fi
}

install_git_delta () {
  if [ ! -x "$(command -v delta)" ]; then
    if [ "$OS_FAMILY" = "Darwin" ]; then
      install_generic_homebrew "git-delta" "delta"
    else
      echo "Unable to install git_delta - OS version doesn't have supported function"
    fi
  fi
}

install_bat () {
  if [ ! -x "$(command -v bat)" ]; then
    if [ "$OS_FAMILY" = "Darwin" ]; then
      install_generic_homebrew "bat"
    else
      echo "Unable to install bat - OS version doesn't have supported function"
    fi
  fi
}

install_ytdlp() {
  if [ ! -x "$(command -v yt-dlp)" ]; then
    if [ "$OS_FAMILY" = "Darwin" ]; then
      install_generic_github "yt-dlp/yt-dlp" "yt-dlp" "macos" "zip"
    else
      echo "Unable to install yt-dlp - OS version doesn't have supported function"
    fi
  fi
  install_ffmpeg
  install_ffprobe
  install_phantomjs
}
