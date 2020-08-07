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

Function install-jq {
  if (!(Check-Command jq)) {
    if ((Check-OS) -like "*win*") {
      "NOTE: jq not found, availing into dotfiles bin"
      "------------------------------------------------"
      [Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"
      $local:jq="https://api.github.com/repos/stedolan/jq/releases/latest"
      $local:latest=$(Invoke-WebRequest $jq -UseBasicParsing | Select-Object content | Get-URLs | Select-String "win64" | Select-Object -ExpandProperty line)

      "Downloading jq..."
      Powershell-FileDownload "$latest" -o "$HOME/.dotfiles/opt/bin/jq.exe"

      if (Check-Command jq) {
        "GOOD - jq is now available"
      } else {
        "BAD - jq doesn't seem to be available"
      }
    }
  }
}

Function install-shellcheck {
  if (!(Check-Command shellcheck)) {
    if ((Check-OS) -like "*win*") {
      "NOTE: shellcheck not found, availing into dotfiles bin"
      "------------------------------------------------"
      [Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"
      $local:latest="https://shellcheck.storage.googleapis.com/shellcheck-latest.exe"

      "Downloading shellcheck..."
      Powershell-FileDownload "$latest" -o "$HOME/.dotfiles/opt/bin/shellcheck.exe"

      if (Check-Command shellcheck) {
        "GOOD - shellcheck is now available"
      } else {
        "BAD - shellcheck doesn't seem to be available"
      }
    }
  }
}

Function install-shfmt {
  if (!(Check-Command shfmt)) {
    if ((Check-OS) -like "*win*") {
      "NOTE: shfmt not found, availing into dotfiles bin"
      "------------------------------------------------"
      [Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"
      $local:shfmt="https://api.github.com/repos/mvdan/sh/releases/latest"
      $local:latest=$(Invoke-WebRequest $shfmt -UseBasicParsing | Select-Object content | Get-URLs | Select-String "windows_amd64" | Select-Object -ExpandProperty line)

      "Downloading shfmt..."
      Powershell-FileDownload "$latest" -o "$HOME/.dotfiles/opt/bin/shfmt.exe"

      if (Check-Command shfmt) {
        "GOOD - shfmt is now available"
      } else {
        "BAD - shfmt doesn't seem to be available"
      }
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