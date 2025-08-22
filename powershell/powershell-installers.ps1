Function install-winget {
param(
  [Alias("u")][Switch]$Uninstall
)

  if (!(Check-Command winget)) {
    if ((Check-OS) -like "*win*") {
      install-generic-github -repo "microsoft/winget-cli" -searchstring ".msixbundle" -executablename "winget"
    }
  } elseif ($Uninstall) {
    Get-AppPackage | Where-Object {$_.PackageFullName -like "*DesktopAppInstaller*"} | Remove-AppPackage
  }
}

Function install-generic-chocolatey {
  param(
      [Parameter(Mandatory=$true)]
      [string] $pkgname,

      [string] $executablename = $pkgname
  )

  if (!$pkgname -and !$executablename) {
    Write-Warning "install-generic-chocolatey: No PkgName was provided, doing nothing..."
    return
  }

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

    [ValidateSet("binary","folder")]
    [string] $type = "binary",
    [string] $path,

    [string] $searchstring = "windows",
    [string] $excludeString,

    [Switch] $folderInstall
  )

  if (!$pkgname -and !$executablename) {
    Write-Warning "install-generic-github: No PkgName was provided, doing nothing..."
    return
  }

  if (!(Check-Installed -name $executablename -type $type -path $path)) {
    if ((Check-OS) -like "*win*") {
      "NOTE: $executablename not found, availing into dotfiles bin"
      "------------------------------------------------"
      [Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"
      $local:pkgrepo="https://api.github.com/repos/$repo/releases/latest"
      $local:assetsURL = $(Invoke-WebRequest $pkgrepo -UseBasicParsing | ConvertFrom-Json | Select-Object assets_url)[0].assets_url;
      $local:latest = $(
        Invoke-WebRequest $assetsURL -UseBasicParsing | ConvertFrom-Json | ForEach-Object { $_.browser_download_url } | Select-String $searchstring | Where-Object { -not ($excludeString -and ($_ -match $excludeString)) } | Out-String
      ).Trim();
      $local:ext = $null
      if ($latest.Split("/")[-1] -match "\.") {$ext = $latest.Split("/")[-1].Split(".")[-1]}


      "Downloading $executablename...";
      "$latest";
      if ($ext -eq "exe" -or $null -eq $ext) {
        Powershell-FileDownload "$latest" -o "$HOME/.dotfiles/opt/bin/$executablename$(If ($ext) {".$ext"})"
      } else {
        mkdir -p "$HOME/.dotfiles/opt/tmp" | Out-Null
        Powershell-FileDownload "$latest" -o "$HOME/.dotfiles/opt/tmp/$pkgname$(If ($ext) {".$ext"})"

        if ($ext -like "zip") {
          Expand-Archive -LiteralPath "$HOME/.dotfiles/opt/tmp/$pkgname.$ext" -DestinationPath "$HOME/.dotfiles/opt/tmp/$pkgname"

          if ($type -like "*folder*") {
            Move-Item "$HOME/.dotfiles/opt/tmp/$pkgname" "$HOME/.dotfiles/opt/bin/$pkgname"
          } else {
            $local:binary = Get-ChildItem "$HOME/.dotfiles/opt/tmp/$pkgname/" -Recurse -Filter "$executablename*.exe"
            Move-Item $binary.FullName "$HOME/.dotfiles/opt/bin/$executablename.exe"
          }
        } elseif ($ext -like "msixbundle") {
          Add-AppPackage -path "$HOME/.dotfiles/opt/tmp/$pkgname$(If ($ext) {".$ext"})"
        } else {
          Write-Warning "Don't know what to do with extension ($ext) from $pkgname$(If ($ext) {".$ext"})"
        }

        Remove-Item -Path "$HOME/.dotfiles/opt/tmp" -Recurse
      }

      if (Check-Installed -name $executablename -type $type -path $path) {
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
      install-generic-github "jqlang/jq" -searchstring "win64"
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
      install-generic-github -repo "AlDanial/cloc" -searchstring ".exe"
    }
  }
}

Function install-Powershell {
param (
  [Switch][Alias("g")]$global,
  [Alias("u")][Switch]$Uninstall
)

  if ($Uninstall) {
    if ((Get-Package | Where-Object {$_.Name -like "*Powershell*"}) -and $global) {
      winget uninstall --name PowerShell --exact
    }

    if (Check-Installed -name "Powershell" -type "folder") {
      if (Test-Path "$HOME/.dotfiles/opt/bin/Powershell") {
        Remove-Item "$HOME/.dotfiles/opt/bin/Powershell" -Recurse -Force
      }
    }
  }


  if ($global -and !$Uninstall) {
    if (!(Get-Package | Where-Object {$_.Name -like "*Powershell*"})) {
      install-winget
      winget install --name "PowerShell" --exact
    }
  } elseif (!$Uninstall) {
    if (!(Check-Installed -name "Powershell" -type "folder")) {
      if ((Check-OS) -like "*win*") {
        install-generic-github -repo "PowerShell/PowerShell" -searchstring "win-x64.zip" -type "folder"
      }
    }
  }
}

Function install-ntop {
  if (!(Check-Command ntop)) {
    if ((Check-OS) -like "*win*") {
      install-generic-github "gsass1/NTop" -searchstring "exe"
    }
  }
}

Function install-monitorian {
  if (!(Check-Command "Monitorian")) {
    if ((Check-OS) -like "*win*") {
      install-winget "Monitorian"
    }
  }
}

Function install-aria2 {
  if (!(Check-Command "aria2")) {
    if ((Check-OS) -like "*win*") {
      install-generic-github -repo "aria2/aria2" -searchstring "win-64bit"
    }
  }
}

Function install-classicNotepad {
  if (!(Test-Path "c:\windows\system32\notepad.exe")) {
    if ((Check-OS) -like "*win*") {
      dism /Online /add-Capability /CapabilityName:Microsoft.Windows.Notepad.System~~~~0.0.1.0
      reg import "$HOME/.dotfiles/windows/Win11-RestoreClassicNotepad.reg"
    }
  }
}

Function install-diffsofancy {
  if (!(Test-Path "$HOMEREPO/opt/bin/diff-so-fancy")) {
    install-generic-github -repo "so-fancy/diff-so-fancy" -searchstring "diff-so-fancy"
  }
}

Function install-vswhere {
  if (!(Test-Path "$HOMEREPO/opt/bin/vswhere.exe")) {
    install-generic-github -repo "microsoft/vswhere" -searchstring "vswhere"
  }
}

Function install-nuget {
  if (!(Check-Command nuget)) {
    if ((Check-OS) -like "*win*") {
      "NOTE: Nuget not found, availing into dotfiles bin"
      "------------------------------------------------"
      $local:latest="https://dist.nuget.org/win-x86-commandline/latest/nuget.exe"

      "Downloading Nuget ..."
      mkdir -p "$HOME/.dotfiles/opt/tmp" | Out-Null
      Powershell-FileDownload "$latest" -o "$HOME/.dotfiles/opt/bin/nuget.exe"

      if (Check-Command nuget) {
        "GOOD - nuget is now available"
      } else {
        "BAD - nuget doesn't seem to be available"
      }
    }
  }
}

Function install-vsBuildTools {
  param (
    [Alias("u")][Switch]$Uninstall
  )
  $local:winGetID = "Microsoft.VisualStudio.2022.BuildTools"

    if ($Uninstall) {
      if (winget list --id "$winGetID" | Select-String "$winGetID") {
        winget uninstall --id "$winGetID"
      }
    }

    if (!$Uninstall) {
      if (!(winget list --id "$winGetID" | Select-String "$winGetID")) {
        install-winget
        winget install --id "$winGetID" --silent
      }
    }
}

Function install-sed {
  if (!(Check-Command "sed")) {
    if ((Check-OS) -like "*win*") {
      install-generic-github -repo "mbuilov/sed-windows" -executablename "sed" -searchstring "x64.exe"
    }
  }
}

Function install-grep {
  if (!(Check-Command grep)) {
    if ((Check-OS) -like "*win*") {
      "NOTE: Grep not found, availing into dotfiles bin"
      "------------------------------------------------"
      $local:latest="https://github.com/mbuilov/grep-windows/raw/refs/heads/master/grep-3.11-x64.exe"
      # Alt: https://github.com/Genivia/ugrep

      "Downloading Grep ..."
      #mkdir -p "$HOME/.dotfiles/opt/tmp" | Out-Null
      Powershell-FileDownload "$latest" -o "$HOME/.dotfiles/opt/bin/grep.exe"

      if (Check-Command grep) {
        "GOOD - grep is now available"
      } else {
        "BAD - grep doesn't seem to be available"
      }
    }
  }
}

Function install-ripgrep {
  if (!(Check-Command "rg")) {
    if ((Check-OS) -like "*win*") {
      install-generic-github -repo "BurntSushi/ripgrep" -executablename "rg" -searchstring "64-pc-windows-msvc.zip" -excludeString "sha256"
    }
  }
}

Function install-msls {
  if (!(Check-Installed ls)) {
    if ((Check-OS) -like "*win*") {
      "NOTE: ls not found, availing into dotfiles bin"
      "------------------------------------------------"
      $local:latest="https://u-tools.com/files/msls350.exe"

      "Downloading ls ..."
      mkdir -p "$HOME/.dotfiles/opt/tmp" | Out-Null
      Powershell-FileDownload "$latest" -o "$HOME/.dotfiles/opt/tmp/mslsArchive.zip"
      Expand-Archive -LiteralPath "$HOME/.dotfiles/opt/tmp/mslsArchive.zip" -DestinationPath "$HOME/.dotfiles/opt/tmp/msls"
      Move-Item "$HOME/.dotfiles/opt/tmp/msls/ls.exe" "$HOME/.dotfiles/opt/bin/"
      Move-Item "$HOME/.dotfiles/opt/tmp/msls/dircolors.exe" "$HOME/.dotfiles/opt/bin/"

      Remove-Item -Path "$HOME/.dotfiles/opt/tmp" -Recurse

      if (Check-Command ls) {
        "GOOD - ls is now available"
      } else {
        "BAD - ls doesn't seem to be available"
      }
    }
  }
}
