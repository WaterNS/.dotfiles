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

Function install-python3 {
param (
  [Alias("u")][Switch]$Uninstall,
  [string]$Version,
  [Switch]$NoPip,
  [Switch]$AllowPreRelease
)

  $local:pythonFolder = Join-Path $HOME ".dotfiles\\opt\\bin\\python3"
  $local:pythonFolder = [IO.Path]::GetFullPath($local:pythonFolder)
  $local:pythonExe = Join-Path $local:pythonFolder "python.exe"
  $local:tmpRoot = Join-Path $HOME ".dotfiles\\opt\\tmp"
  $local:tmpDir = Join-Path $local:tmpRoot "python3"
  $local:arch = if ([Environment]::Is64BitOperatingSystem) { "amd64" } else { "win32" }

  if ($Uninstall) {
    if (Test-Path "$local:pythonFolder") {
      Remove-Item "$local:pythonFolder" -Recurse -Force
    }
    return
  }

  if (!(Check-Installed -name "Python" -type "folder" -path $local:pythonFolder)) {
    if ((Check-OS) -like "*win*") {
      "NOTE: Python not found, availing into dotfiles bin"
      "------------------------------------------------"
      [Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"

      $local:versionList = $null
      if (-not $Version -or $Version -match '^\d+\.\d+$') {
        try {
          $local:index = Invoke-WebRequest "https://www.python.org/ftp/python/" -UseBasicParsing
          $local:versionList = [regex]::Matches($local:index.Content, 'href="(\d+\.\d+\.\d+)/"') |
            ForEach-Object { $_.Groups[1].Value } |
            ForEach-Object { [version]$_ } |
            Sort-Object -Descending
        } catch {
          Write-Warning "Failed to query python.org for available versions."
        }
      }

      $local:candidates = @()
      if (-not $Version) {
        if ($local:versionList) {
          $local:candidates = $local:versionList | ForEach-Object { $_.ToString() }
        } else {
          Write-Warning "install-python3: Version is required when python.org cannot be reached."
          return
        }
      } elseif ($Version -match '^\d+\.\d+$') {
        if ($local:versionList) {
          $local:minorVersion = [version]$Version
          $local:candidates = $local:versionList |
            Where-Object { $_.Major -eq $local:minorVersion.Major -and $_.Minor -eq $local:minorVersion.Minor } |
            ForEach-Object { $_.ToString() }
          if (-not $local:candidates) {
            Write-Warning "install-python3: Could not find a patch version for $Version."
            return
          }
        } else {
          Write-Warning "install-python3: Version is missing a patch number (example: 3.12.8)."
          return
        }
      } else {
        $local:candidates = @($Version)
      }

      $local:embedMatch = $null
      $local:embedStable = $false
      $local:downloadBase = $null
      $local:selectedVersion = $null
      foreach ($local:candidate in $local:candidates) {
        $local:downloadBase = "https://www.python.org/ftp/python/$local:candidate/"
        try {
          $local:dirIndex = Invoke-WebRequest $local:downloadBase -UseBasicParsing
        } catch {
          continue
        }

        $local:stablePattern = 'href="(python-{0}-embed-{1}\.zip)"' -f $local:candidate, $local:arch
        $local:embedMatch = [regex]::Matches(
          $local:dirIndex.Content,
          $local:stablePattern
        ) | ForEach-Object { $_.Groups[1].Value } | Select-Object -First 1

        if ($local:embedMatch) {
          $local:embedStable = $true
          $local:selectedVersion = $local:candidate
          break
        }

        if (-not $AllowPreRelease) {
          continue
        }

        $local:prePattern = 'href="(python-{0}[a-z0-9\.]*-embed-{1}\.zip)"' -f $local:candidate, $local:arch
        $local:embedMatch = [regex]::Matches(
          $local:dirIndex.Content,
          $local:prePattern
        ) | ForEach-Object { $_.Groups[1].Value } | Select-Object -First 1

        if ($local:embedMatch) {
          $local:embedStable = $false
          $local:selectedVersion = $local:candidate
          break
        }
      }

      if (-not $local:embedMatch) {
        if ($AllowPreRelease) {
          Write-Warning "install-python3: No embeddable zip found for the requested version(s) ($local:arch)."
        } else {
          Write-Warning "install-python3: No stable embeddable zip found. Use -AllowPreRelease to accept prerelease builds."
        }
        return
      }

      $Version = $local:selectedVersion
      $local:downloadUrl = "$local:downloadBase$local:embedMatch"
      $local:resolvedTag = $local:embedMatch -replace '^python-','' -replace ("-embed-{0}\.zip$" -f $local:arch),''
      if (-not $local:embedStable) {
        Write-Warning "install-python3: Resolved prerelease build '$local:resolvedTag' under $Version."
      }

      if (Test-Path "$local:pythonFolder") {
        Remove-Item "$local:pythonFolder" -Recurse -Force
      }

      if (Test-Path "$local:tmpDir") {
        Remove-Item "$local:tmpDir" -Recurse -Force
      }

      New-Item -ItemType Directory -Path "$local:pythonFolder" -Force | Out-Null
      New-Item -ItemType Directory -Path "$local:tmpDir" -Force | Out-Null

      "Downloading Python $Version (portable)..."
      Write-Host "URL: $local:downloadUrl"
      Powershell-FileDownload "$local:downloadUrl" -o "$local:tmpDir\\python-embed.zip"
      Expand-Archive -LiteralPath "$local:tmpDir\\python-embed.zip" -DestinationPath "$local:pythonFolder"
      Remove-Item "$local:tmpDir\\python-embed.zip" -Force

      $local:pthFile = Get-ChildItem "$local:pythonFolder" -Filter "python*._pth" | Select-Object -First 1
      if ($local:pthFile) {
        $local:pthLines = Get-Content $local:pthFile.FullName
        $local:pthLines = $local:pthLines | ForEach-Object {
          if ($_ -match '^\s*#\s*import site') { 'import site' } else { $_ }
        }
        if (-not ($local:pthLines -match '^\s*Lib\\site-packages\s*$')) {
          $local:pthLines += 'Lib\\site-packages'
        }
        Set-Content -Path $local:pthFile.FullName -Value $local:pthLines -Encoding ASCII
      }

      New-Item -ItemType Directory -Path (Join-Path $local:pythonFolder "Lib\\site-packages") -Force | Out-Null

      if (-not $NoPip) {
        $local:getPip = Join-Path $local:tmpDir "get-pip.py"
        Powershell-FileDownload "https://bootstrap.pypa.io/get-pip.py" -o "$local:getPip"
        & $local:pythonExe "$local:getPip" --no-warn-script-location
        Remove-Item "$local:getPip" -Force
      }

      Remove-Item -Path "$local:tmpDir" -Recurse -Force

      if (Test-Path "$local:pythonExe") {
        "GOOD - Python3 is now available"
        # Python3 helper for Windows
        if ((Test-Path "$HOME\.dotfiles\opt\bin\python3\python.exe")) {
          if (!($env:PATH -like "*.dotfiles\opt\bin\python3*")) {
            $env:PATH += ";$HOME\.dotfiles\opt\bin\python3\"
            $env:PATH += ";$HOME\.dotfiles\opt\bin\python3\Scripts"
          }
          Set-Alias python "$HOME\.dotfiles\opt\bin\python3\python.exe"
          Set-Alias python3 "$HOME\.dotfiles\opt\bin\python3\python.exe"
        }
      } else {
        "BAD - Python3 doesn't seem to be available"
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

      Remove-Item -Path "$HOME/.dotfiles/opt/tmp" -Recurse

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
      install-generic-github -repo "BurntSushi/ripgrep" -executablename "rg" -searchstring "x86_64-pc-windows-msvc.zip" -excludeString "sha256"
    }
  }
}

Function install-msls {
  if (!(Check-Command -Binary msls)) {
    if ((Check-OS) -like "*win*") {
      "NOTE: msls not found, availing into dotfiles bin"
      "------------------------------------------------"
      $local:latest="https://u-tools.com/files/msls350.exe"

      "Downloading msls ..."
      mkdir -p "$HOME/.dotfiles/opt/tmp" | Out-Null
      Powershell-FileDownload "$latest" -o "$HOME/.dotfiles/opt/tmp/mslsArchive.zip"
      Expand-Archive -LiteralPath "$HOME/.dotfiles/opt/tmp/mslsArchive.zip" -DestinationPath "$HOME/.dotfiles/opt/tmp/msls"
      Move-Item "$HOME/.dotfiles/opt/tmp/msls/ls.exe" "$HOME/.dotfiles/opt/bin/msls.exe"
      #Copy-Item "$HOME/.dotfiles/opt/bin/msls.exe" "$HOME/.dotfiles/opt/bin/ls.exe"
      Move-Item "$HOME/.dotfiles/opt/tmp/msls/dircolors.exe" "$HOME/.dotfiles/opt/bin/"

      Remove-Item -Path "$HOME/.dotfiles/opt/tmp" -Recurse

      if (Check-Command -Binary msls) {
        "GOOD - msls is now available"
      } else {
        "BAD - msls doesn't seem to be available"
      }
    }
  }
}

Function install-coreutils-uutils {
  if (!(Check-Command "coreutils" -Binary)) {
    if ((Check-OS) -like "*win*") {
      install-generic-github -repo "uutils/coreutils" -executablename "coreutils" -searchstring "64-pc-windows-msvc.zip" -excludeString "aarch64"
    }
  }
}

Function install-tail-uutils {
  if (!(Check-Command "tail" -Binary)) {
    if ((Check-OS) -like "*win*") {
      install-coreutils-uutils

      "Copying coreutils-uutils as tail.exe ..."
      Copy-Item "~/.dotfiles/opt/bin/coreutils.exe" "~/.dotfiles/opt/bin/tail.exe"

      if (Check-Command "tail" -Binary) {
        "GOOD - tail is now available"
      } else {
        "BAD - tail doesn't seem to be available"
      }
    }
  }
}

Function install-head-uutils {
  if (!(Check-Command "head" -Binary)) {
    if ((Check-OS) -like "*win*") {
      install-coreutils-uutils

      "Copying coreutils-uutils as head.exe ..."
      Copy-Item "~/.dotfiles/opt/bin/coreutils.exe" "~/.dotfiles/opt/bin/head.exe"

      if (Check-Command "head" -Binary) {
        "GOOD - head is now available"
      } else {
        "BAD - head doesn't seem to be available"
      }
    }
  }
}

Function install-ls-uutils {
  if (!(Check-Command "ls" -Binary)) {
    if ((Check-OS) -like "*win*") {
      install-coreutils-uutils

      "Copying coreutils-uutils as ls.exe ..."
      Copy-Item "~/.dotfiles/opt/bin/coreutils.exe" "~/.dotfiles/opt/bin/ls.exe"

      if (Check-Command "ls" -Binary) {
        "GOOD - ls is now available"
      } else {
        "BAD - ls doesn't seem to be available"
      }
    }
  }
}

Function install-less-uutils {
  if (!(Check-Command "less" -Binary)) {
    if ((Check-OS) -like "*win*") {
      install-coreutils-uutils

      "Copying coreutils-uutils as less.exe ..."
      Copy-Item "~/.dotfiles/opt/bin/coreutils.exe" "~/.dotfiles/opt/bin/less.exe"

      if (Check-Command "less" -Binary) {
        "GOOD - less is now available"
      } else {
        "BAD - less doesn't seem to be available"
      }
    }
  }
}

Function install-busybox {
  if (!(Check-Command "busybox" -Binary)) {
    if ((Check-OS) -like "*win*") {
      "NOTE: busybox not found, availing into dotfiles bin"
      "------------------------------------------------"
      $local:latest="https://frippery.org/files/busybox/busybox64u.exe" # x64 + Unicode support

      "Downloading busybox ..."
      #mkdir -p "$HOME/.dotfiles/opt/tmp" | Out-Null
      Powershell-FileDownload "$latest" -o "$HOME/.dotfiles/opt/bin/busybox.exe"

      if (Check-Command busybox -Binary) {
        "GOOD - busybox is now available"
      } else {
        "BAD - busybox doesn't seem to be available"
      }
    }
  }
}

Function install-tail-busybox {
  if (!(Check-Command "tail" -Binary)) {
    if ((Check-OS) -like "*win*") {
      install-busybox

      #"Copying busybox as tail.exe ..."
      Copy-Item "~/.dotfiles/opt/bin/busybox.exe" "~/.dotfiles/opt/bin/tail.exe"

      if (Check-Command "tail" -Binary) {
        "GOOD - tail is now available"
      } else {
        "BAD - tail doesn't seem to be available"
      }
    }
  }
}

Function install-head-busybox {
  if (!(Check-Command "head" -Binary)) {
    if ((Check-OS) -like "*win*") {
      install-busybox

      #"Copying busybox as head.exe ..."
      Copy-Item "~/.dotfiles/opt/bin/busybox.exe" "~/.dotfiles/opt/bin/head.exe"

      if (Check-Command "head" -Binary) {
        "GOOD - head is now available"
      } else {
        "BAD - head doesn't seem to be available"
      }
    }
  }
}

Function install-nl-busybox {
  if (!(Check-Command "nl" -Binary)) {
    if ((Check-OS) -like "*win*") {
      install-busybox

      #"Copying busybox as nl.exe ..."
      Copy-Item "~/.dotfiles/opt/bin/busybox.exe" "~/.dotfiles/opt/bin/nl.exe"

      if (Check-Command "nl" -Binary) {
        "GOOD - nl is now available"
      } else {
        "BAD - nl doesn't seem to be available"
      }
    }
  }
}

Function install-wget {
  if (!(betterWhereIs wget -WarningAction SilentlyContinue | Where-Object {$_.Type -eq "Executable"})) {
    if ((Check-OS) -like "*win*") {
      "NOTE: wget not found, availing into dotfiles bin"
      "------------------------------------------------"
      $local:latest="https://eternallybored.org/misc/wget/1.21.4/64/wget.exe" # x64

      "Downloading wget ..."
      #mkdir -p "$HOME/.dotfiles/opt/tmp" | Out-Null
      Powershell-FileDownload "$latest" -o "$HOME/.dotfiles/opt/bin/wget.exe"

      if (betterWhereIs wget -WarningAction SilentlyContinue | Where-Object {$_.Type -eq "Executable"}) {
        "GOOD - wget is now available"
      } else {
        "BAD - wget doesn't seem to be available"
      }
    }
  }
}
