Function install-generic-chocolatey {
  param(
      [Parameter(Mandatory=$true)]
      [string] $pkgname,

      [string] $executablename = $pkgname
  )

  if (!(Check-Command $executablename)) {
    if ((Check-OS) -like "*win*") {
      "NOTE: $pkgname not found, availing into dotfiles bin"
      "------------------------------------------------"
      [Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"
      $local:latest="https://chocolatey.org/api/v2/package/$pkgname"

      "Downloading $pkgname..."
      mkdir -p "$HOME/.dotfiles/opt/tmp" | Out-Null
      Powershell-FileDownload "$latest" -o "$HOME/.dotfiles/opt/tmp/$pkgname.zip"

      Expand-Archive -LiteralPath "$HOME/.dotfiles/opt/tmp/$pkgname.zip" -DestinationPath "$HOME/.dotfiles/opt/tmp/$pkgname"

      if (Test-Path "$HOME/.dotfiles/opt/tmp/$pkgname/tools/$executablename*.zip") {
        $local:archive = (Get-ChildItem "$HOME/.dotfiles/opt/tmp/$pkgname/tools/$executablename*.zip")
        Expand-Archive -LiteralPath $archive -DestinationPath "$HOME/.dotfiles/opt/tmp/$pkgname/tools"
      }

      $local:binary = Get-ChildItem "$HOME/.dotfiles/opt/tmp/$pkgname/tools" -Recurse -Filter "$executablename.exe"
      Move-Item $binary.FullName "$HOME/.dotfiles/opt/bin/"
      Remove-Item -Path "$HOME/.dotfiles/opt/tmp" -Recurse

      if (Check-Command $executablename) {
        "GOOD - $pkgname is now available"
      } else {
        "BAD - $pkgname doesn't seem to be available"
      }
    }
  }
}

Function install-generic-github {
  param(
    [Parameter(Mandatory=$true)]
    [string] $repo,

    [string] $pkgname = $repo.Split("/")[1],
    [string] $executablename = $pkgname,

    [string] $searchstring = "windows"
  )

  if (!(Check-Command $executablename)) {
    if ((Check-OS) -like "*win*") {
      "NOTE: $executablename not found, availing into dotfiles bin"
      "------------------------------------------------"
      [Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"
      $local:pkgrepo="https://api.github.com/repos/$repo/releases/latest"
      $local:latest=$(Invoke-WebRequest $pkgrepo -UseBasicParsing | Select-Object content | Get-URLs | Select-String $searchstring | Select-Object -ExpandProperty line)
      $local:ext=$latest.Split("/")[-1].Split(".")[-1]

      "Downloading $executablename..."
      if ($ext -eq "exe") {
        Powershell-FileDownload "$latest" -o "$HOME/.dotfiles/opt/bin/$executablename.$ext"
      } else {
        mkdir -p "$HOME/.dotfiles/opt/tmp" | Out-Null
        Powershell-FileDownload "$latest" -o "$HOME/.dotfiles/opt/tmp/$pkgname.$ext"

        Expand-Archive -LiteralPath "$HOME/.dotfiles/opt/tmp/$pkgname.$ext" -DestinationPath "$HOME/.dotfiles/opt/tmp/$pkgname"

        $local:binary = Get-ChildItem "$HOME/.dotfiles/opt/tmp/$pkgname/" -Recurse -Filter "$executablename*.exe"
        Move-Item $binary.FullName "$HOME/.dotfiles/opt/bin/$executablename.exe"
        Remove-Item -Path "$HOME/.dotfiles/opt/tmp" -Recurse
      }

      if (Check-Command $executablename) {
        "GOOD - $executablename is now available"
      } else {
        "BAD - $executablename doesn't seem to be available"
      }
    }
  }
}

Function install-jq {
  if (!(Check-Command jq)) {
    if ((Check-OS) -like "*win*") {
      install-generic-github "stedolan/jq" -searchstring "win64"
    }
  }
}

Function install-shellcheck {
  if (!(Check-Command shellcheck)) {
    if ((Check-OS) -like "*win*") {
      install-generic-github "koalaman/shellcheck" -searchstring 'shellcheck-.*zip'
    }
  }
}

Function install-shfmt {
  if (!(Check-Command shfmt)) {
    if ((Check-OS) -like "*win*") {
      install-generic-github "mvdan/sh" -executablename "shfmt" -searchstring "windows_amd64"
    }
  }
}

Function install-less {
  if (!(Check-Command less)) {
    if ((Check-OS) -like "*win*") {
      install-generic-chocolatey less
    }
  }
}

Function install-cht {
  if (!(Check-Command cht)) {
    if ((Check-OS) -like "*win*") {
      "NOTE: cht not found, availing into dotfiles bin"
      "------------------------------------------------"
      #[Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"
      #$local:cht="https://api.github.com/repos/mvdan/sh/releases/latest"
      #$local:latest=$(Invoke-WebRequest $cht | Select-Object content | Get-URLs | Select-String "windows_amd64" | Select-Object -ExpandProperty line)
      $local:latest="https://github.com/tpanj/cht.exe/archive/v0.6.zip"

      "Downloading cht..."
      mkdir -p "$HOME/.dotfiles/opt/tmp" | Out-Null
      Powershell-FileDownload "$latest" -o "$HOME/.dotfiles/opt/tmp/cht.zip"

      Expand-Archive -LiteralPath "$HOME/.dotfiles/opt/tmp/cht.zip" -DestinationPath "$HOME/.dotfiles/opt/tmp/cht"

      Move-Item "$HOME/.dotfiles/opt/tmp/cht/**/bin/cht.exe" "$HOME/.dotfiles/opt/bin/"
      Remove-Item -Path "$HOME/.dotfiles/opt/tmp" -Recurse

      if (Check-Command cht) {
        "GOOD - cht is now available"
      } else {
        "BAD - cht doesn't seem to be available"
      }
    }
  }
}

Function install-delta {
  if (!(Check-Command delta)) {
    if ((Check-OS) -like "*win*") {
      install-generic-github -repo "dandavison/delta"
    }
  }
}

Function install-bat {
  if (!(Check-Command bat)) {
    if ((Check-OS) -like "*win*") {
      install-generic-github -repo "sharkdp/bat" -searchstring "x86_64-pc-windows-msvc"
    }
  }
}

Function install-cloc {
  if (!(Check-Command cloc)) {
    if ((Check-OS) -like "*win*") {
      install-generic-github -repo "AlDanial/cloc" -searchstring "exe"
    }
  }
}
