#!/bin/sh

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
        if contains "$(uname)" "Darwin"; then
            echo "NOTE: unar not found, installing into dotfiles bin"
            echo "------------------------------------------------"
            curl -L https://cdn.theunarchiver.com/downloads/unarMac.zip -o /tmp/unarMac.zip; echo ""
            unzip -a -qq /tmp/unarMac.zip -d /tmp/unar

            cp /tmp/unar/unar "$HOME/.dotfiles/opt/bin/"
            rm -r /tmp/unar /tmp/unarMac.zip

            if [ -x "$(command -v unar)" ]; then
                echo "GOOD - unar is now available"
            else
                echo "BAD - unar doesn't seem to be available"
            fi
        else
            echo "Unable to install unar - OS version doesn't have supported function"
        fi
    fi
}

install_ffmpeg () {
    if [ ! -x "$(command -v ffmpeg)" ]; then
      if contains "$(uname)" "Darwin"; then
        install_unar
        echo "NOTE: ffmpeg not found, installing into dotfiles bin"
        echo "------------------------------------------------"
        ffmpeg="https://evermeet.cx/pub/ffmpeg/snapshots/"
        latest=$(curl $ffmpeg | grep -v ".7z.sig" | grep .7z | head -1 | sed -n 's/.*href="\([^"]*\).*/\1/p')
        curl "$ffmpeg$latest" -o /tmp/ffmpeg.7z; echo ""

        unar /tmp/ffmpeg.7z -o "$HOME/.dotfiles/opt/bin/"
        rm -r /tmp/ffmpeg.7z

        if [ -x "$(command -v ffmpeg)" ]; then
            echo "GOOD - ffmpeg is now available"
        else
            echo "BAD - ffmpeg doesn't seem to be available"
        fi
      else
          echo "Unable to install ffmpeg - OS version doesn't have supported function"
      fi
    fi
}

install_ffprobe () {
    if [ ! -x "$(command -v ffprobe)" ]; then
      if contains "$(uname)" "Darwin"; then
        install_unar
        echo "NOTE: ffprobe not found, installing into dotfiles bin"
        echo "------------------------------------------------"
        ffprobe="https://evermeet.cx/pub/ffprobe/snapshots/"
        latest=$(curl $ffprobe | grep -v ".7z.sig" | grep .7z | head -1 | sed -n 's/.*href="\([^"]*\).*/\1/p')
        curl "$ffprobe/$latest" -o /tmp/ffprobe.7z; echo ""

        unar /tmp/ffprobe.7z -o "$HOME/.dotfiles/opt/bin/"
        rm -r /tmp/ffprobe.7z

        if [ -x "$(command -v ffprobe)" ]; then
            echo "GOOD - ffprobe is now available"
        else
            echo "BAD - ffprobe doesn't seem to be available"
        fi
      else
          echo "Unable to install ffprobe - OS version doesn't have supported function"
      fi
    fi
}

install_phantomjs () {
    if [ ! -x "$(command -v phantomjs)" ]; then
      if contains "$(uname)" "Darwin"; then
        echo "NOTE: phantomjs not found, installing into dotfiles bin"
        echo "------------------------------------------------"
        phantomjs="http://phantomjs.org/download.html"
        latest=$(curl $phantomjs | sed -n 's/.*href="\([^"]*\).*/\1/p' | grep osx.zip)
        curl -L "$latest" -o /tmp/phantomjs.zip; echo ""

        unzip -j "/tmp/phantomjs.zip" "*/bin/phantomjs" -d "$HOME/.dotfiles/opt/bin/"
        rm -r /tmp/phantomjs.zip

        if [ -x "$(command -v phantomjs)" ]; then
            echo "GOOD - phantomjs is now available"
        else
            echo "BAD - phantomjs doesn't seem to be available"
        fi
      else
          echo "Unable to install phantomjs - OS version doesn't have supported function"
      fi
    fi
}

install_jq () {
    if [ ! -x "$(command -v jq)" ]; then
      if contains "$(uname)" "Darwin"; then
        echo "NOTE: jq not found, availing into dotfiles bin"
        echo "------------------------------------------------"
        jq="https://api.github.com/repos/stedolan/jq/releases/latest"
        latest=$(curl $jq -s  | grep url | grep osx | sed 's/.*\(http[s?]:\/\/.*[^"]\).*/\1/')
        curl -L "$latest" -o /tmp/jq; echo ""

        chmod +x /tmp/jq
        mv /tmp/jq "$HOME/.dotfiles/opt/bin/"
        rm -r /tmp/jq >/dev/null 2>&1

        if [ -x "$(command -v jq)" ]; then
            echo "GOOD - jq is now available"
        else
            echo "BAD - jq doesn't seem to be available"
        fi
      else
          echo "Unable to install jq - OS version doesn't have supported function"
      fi
    fi
}

install_shellcheck () {
    if [ ! -x "$(command -v jq)" ]; then
        install_jq
    fi
    if [ ! -x "$(command -v shellcheck)" ]; then
      if contains "$(uname)" "Darwin"; then
        echo "NOTE: shellcheck not found, availing into dotfiles bin"
        echo "------------------------------------------------"
        shellcheck="https://formulae.brew.sh/api/formula/shellcheck.json"
        latest=$(curl -S $shellcheck | jq -r "[.bottle.stable.files[]][0]".url)
        filename=${latest##*/}
        curl -L "$latest" -o "/tmp/$filename"; echo ""

        mkdir /tmp/shellcheck
        tar -xzf "/tmp/$filename" -C /tmp/shellcheck/
        mv /tmp/shellcheck/shellcheck/*/bin/shellcheck ~/.dotfiles/opt/bin

        rm "/tmp/$filename"
        rm -r /tmp/shellcheck

        if [ -x "$(command -v shellcheck)" ]; then
            echo "GOOD - shellcheck is now available"
        else
            echo "BAD - shellcheck doesn't seem to be available"
        fi
      else
          echo "Unable to install shellcheck - OS version doesn't have supported function"
      fi
    fi
}

install_shfmt () {
    if [ ! -x "$(command -v shfmt)" ]; then
      if contains "$(uname)" "Darwin"; then
        echo "NOTE: shfmt not found, availing into dotfiles bin"
        echo "------------------------------------------------"
        shfmt="https://api.github.com/repos/mvdan/sh/releases/latest"
        latest=$(curl $shfmt -s  | grep url | grep darwin_amd64 | sed 's/.*\(http[s?]:\/\/.*[^"]\).*/\1/')

        curl -L "$latest" -o "$HOME/.dotfiles/opt/bin/shfmt"; echo ""
        chmod +x "$HOME/.dotfiles/opt/bin/shfmt"

        if [ -x "$(command -v shfmt)" ]; then
            echo "GOOD - shfmt is now available"
        else
            echo "BAD - shfmt doesn't seem to be available"
        fi
      else
          echo "Unable to install shfmt - OS version doesn't have supported function"
      fi
    fi
}

install_nerdfonts () {
    fontname="Droid Sans Mono for Powerline Nerd Font Complete.otf"
    if [ ! -f "$HOME/.dotfiles/opt/fonts/$fontname" ] && [ ! -f "$HOME/Library/Fonts/dotfiles/$fontname" ]; then
      if contains "$(uname)" "Darwin"; then
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
}

install_lsd () {
    if [ ! -x "$(command -v lsd)" ]; then
      if contains "$(uname)" "Darwin"; then
        echo "NOTE: lsd not found, availing into dotfiles bin"
        echo "------------------------------------------------"
        lsd="https://formulae.brew.sh/api/formula/lsd.json"
        latest=$(curl -S $lsd | jq -r "[.bottle.stable.files[]][0]".url)
        filename=${latest##*/}
        curl -L "$latest" -o "/tmp/$filename"; echo ""

        mkdir /tmp/lsd
        tar -xzf "/tmp/$filename" -C /tmp/lsd/
        mv /tmp/lsd/lsd/*/bin/lsd ~/.dotfiles/opt/bin

        rm "/tmp/$filename"
        rm -r /tmp/lsd

        if [ -x "$(command -v lsd)" ]; then
            echo "GOOD - lsd is now available"
        else
            echo "BAD - lsd doesn't seem to be available"
        fi
      else
          echo "Unable to install lsd - OS version doesn't have supported function"
      fi
    fi
}

install_prettyping () {
    if [ ! -x "$(command -v prettyping)" ]; then
      if contains "$(uname)" "Darwin" || contains "$(uname)" "Linux"; then
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