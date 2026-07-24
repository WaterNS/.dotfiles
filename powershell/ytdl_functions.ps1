# yt-dlp helpers and JavaScript runtime selection.

function Get-YtdlpJsRuntimePath {
  param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("deno", "node", "qjs")]
    [string] $Name
  )

  # Resolve applications directly so a same-named alias/function cannot hide
  # them, then include managed runtimes even if opt/bin is not yet on PATH.
  $runtimePaths = @(
    Get-Command -Name $Name -CommandType Application -All -ErrorAction SilentlyContinue |
      ForEach-Object { $_.Path }
  )

  $managedBinPath = Join-Path $HOME ".dotfiles\opt\bin"
  foreach ($runtimeFileName in @($Name, "$Name.exe")) {
    $managedRuntimePath = Join-Path $managedBinPath $runtimeFileName
    if (Test-Path -LiteralPath $managedRuntimePath -PathType Leaf) {
      $managedRuntimePath = (Get-Item -LiteralPath $managedRuntimePath).FullName
      if ($runtimePaths -notcontains $managedRuntimePath) {
        $runtimePaths += $managedRuntimePath
      }
    }
  }

  foreach ($runtimePath in $runtimePaths) {
    if (Test-YtdlpJsRuntime -Name $Name -Path $runtimePath) {
      return $runtimePath
    }
  }

  return $null
}

function Test-YtdlpJsRuntimeVersion {
  param(
    [Parameter(Mandatory=$true)]
    [string] $Version,

    [Parameter(Mandatory=$true)]
    [int[]] $MinimumVersion
  )

  $versionMatch = [regex]::Match($Version, "^v?(\d+)(?:[.-](\d+))?(?:[.-](\d+))?$")
  if (!$versionMatch.Success) {
    return $false
  }

  $versionParts = @(
    [int] $versionMatch.Groups[1].Value,
    $(if ($versionMatch.Groups[2].Success) { [int] $versionMatch.Groups[2].Value } else { 0 }),
    $(if ($versionMatch.Groups[3].Success) { [int] $versionMatch.Groups[3].Value } else { 0 })
  )

  $partCount = [Math]::Max($versionParts.Count, $MinimumVersion.Count)
  for ($partIndex = 0; $partIndex -lt $partCount; $partIndex++) {
    $versionPart = if ($partIndex -lt $versionParts.Count) { $versionParts[$partIndex] } else { 0 }
    $minimumPart = if ($partIndex -lt $MinimumVersion.Count) { $MinimumVersion[$partIndex] } else { 0 }

    if ($versionPart -gt $minimumPart) {
      return $true
    }
    if ($versionPart -lt $minimumPart) {
      return $false
    }
  }

  return $true
}

function Test-YtdlpJsRuntime {
  param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("deno", "node", "qjs")]
    [string] $Name,

    [string] $Path
  )

  if (!$Path) {
    return [bool](Get-YtdlpJsRuntimePath -Name $Name)
  }

  $previousErrorActionPreference = $ErrorActionPreference
  try {
    # Runtime probes should report false rather than inheriting a caller's
    # preference for turning native stderr/nonzero exits into exceptions.
    $ErrorActionPreference = "Continue"

    switch ($Name) {
      "deno" {
        $runtimeOutput = @(& $Path --version 2>&1)
        $runtimeExitCode = $LASTEXITCODE
        $runtimeText = $runtimeOutput -join "`n"
        if (($runtimeExitCode -eq 0) -and ($runtimeText -match "(?m)^deno\s+(\S+)")) {
          return Test-YtdlpJsRuntimeVersion -Version $Matches[1] -MinimumVersion @(2, 3, 0)
        }
      }
      "node" {
        $runtimeOutput = @(& $Path --version 2>&1)
        $runtimeExitCode = $LASTEXITCODE
        $runtimeText = $runtimeOutput -join "`n"
        if (($runtimeExitCode -eq 0) -and ($runtimeText -match "(?m)^v(\S+)")) {
          return Test-YtdlpJsRuntimeVersion -Version $Matches[1] -MinimumVersion @(22, 0, 0)
        }
      }
      "qjs" {
        # Both QuickJS variants print their version in --help output. The
        # original QuickJS deliberately exits nonzero after showing help.
        $runtimeOutput = @(& $Path --help 2>&1)
        $runtimeText = $runtimeOutput -join "`n"
        if ($runtimeText -match "(?m)^QuickJS(-ng)?\s+version\s+(\S+)") {
          if ($Matches[1]) {
            return Test-YtdlpJsRuntimeVersion -Version $Matches[2] -MinimumVersion @(0, 0, 1)
          }

          return Test-YtdlpJsRuntimeVersion -Version $Matches[2] -MinimumVersion @(2023, 12, 9)
        }
      }
    }
  }
  catch {
    return $false
  }
  finally {
    $ErrorActionPreference = $previousErrorActionPreference
  }

  return $false
}

function Test-YtdlpJsRuntimeCommand {
  foreach ($runtimeName in @("deno", "node", "qjs")) {
    if (Test-YtdlpJsRuntime -Name $runtimeName) {
      return $true
    }
  }

  return $false
}

function Test-YtdlpJsRuntimeOption {
  param(
    [AllowEmptyCollection()]
    [object[]] $YtdlpArguments = @()
  )

  foreach ($argument in $YtdlpArguments) {
    $argumentText = [string] $argument
    if ($argumentText -eq "--") {
      break
    }

    if ($argumentText -match "^--(?:no-)?js-runtimes?(?:=|$)") {
      return $true
    }
  }

  return $false
}

function Add-YtdlpJsRuntimeArguments {
  param(
    [AllowEmptyCollection()]
    [object[]] $YtdlpArguments = @()
  )

  if (Test-YtdlpJsRuntimeOption -YtdlpArguments $YtdlpArguments) {
    return $YtdlpArguments
  }

  $runtimeArguments = @()

  # Passing resolved paths makes selection deterministic when an old runtime
  # appears earlier on PATH. Node and QuickJS also require explicit options.
  $denoPath = Get-YtdlpJsRuntimePath -Name "deno"
  if ($denoPath) {
    $runtimeArguments += @("--js-runtimes", "deno:$denoPath")
  }

  $nodePath = Get-YtdlpJsRuntimePath -Name "node"
  if ($nodePath) {
    $runtimeArguments += @("--js-runtimes", "node:$nodePath")
  }

  $quickJsPath = Get-YtdlpJsRuntimePath -Name "qjs"
  if ($quickJsPath) {
    $runtimeArguments += @("--js-runtimes", "quickjs:$quickJsPath")
  }

  return @($runtimeArguments) + @($YtdlpArguments)
}

function Initialize-Ytdlp {
  param(
    [AllowEmptyCollection()]
    [object[]] $YtdlpArguments = @()
  )

  $requiredDependencies = @("yt-dlp", "ffmpeg", "ffprobe")
  $missingDependencies = @($requiredDependencies | Where-Object { !(Check-Command $_ -Binary) })
  $hasExplicitJsRuntimeOption = Test-YtdlpJsRuntimeOption -YtdlpArguments $YtdlpArguments
  $hasAutomaticJsRuntime = $hasExplicitJsRuntimeOption -or (Test-YtdlpJsRuntimeCommand)

  if (($missingDependencies.Count -gt 0) -or !$hasAutomaticJsRuntime) {
    if (!(Check-Command "install-ytdlp")) {
      throw "The yt-dlp installer is unavailable. Reload your PowerShell profile and try again."
    }

    install-ytdlp -SkipJsRuntime:$hasExplicitJsRuntimeOption
  }

  $missingRequiredDependencies = @($requiredDependencies | Where-Object { !(Check-Command $_ -Binary) })
  if ($missingRequiredDependencies.Count -gt 0) {
    throw "Required yt-dlp dependencies are unavailable ($($missingRequiredDependencies -join ', ')). Run install-ytdlp to retry or inspect the installer output."
  }

  if (!$hasExplicitJsRuntimeOption -and !(Test-YtdlpJsRuntimeCommand)) {
    Write-Warning "No supported JavaScript runtime command is available; YouTube format and challenge support may be limited."
  }
}

function Invoke-YtdlpWithRetry {
  param(
    [Parameter(Mandatory=$true)]
    [object[]] $YtdlpArguments
  )

  Initialize-Ytdlp -YtdlpArguments $YtdlpArguments
  $resolvedYtdlpArguments = @(Add-YtdlpJsRuntimeArguments -YtdlpArguments $YtdlpArguments)

  do {
    & "yt-dlp" @resolvedYtdlpArguments
    $exitCode = $LASTEXITCODE

    if ($exitCode -ne 0) {
      Write-Output "DISCONNECTED"
      Start-Sleep -Seconds 5
    }
  } while ($exitCode -ne 0)
}

function youtube-dlp {
  Initialize-Ytdlp -YtdlpArguments $args
  $resolvedYtdlpArguments = @(Add-YtdlpJsRuntimeArguments -YtdlpArguments $args)
  & "yt-dlp" @resolvedYtdlpArguments
}

function ytdl-hq {
  if ($args.Count -eq 0) {
    Write-Error "ytdl-hq: A URL or other yt-dlp argument is required"
    return
  }

  $ytdlpArguments = @(
    "--embed-subs",
    "--compat-options", "no-live-chat,multistreams",
    "--embed-metadata",
    "--embed-subs",
    "--embed-thumbnail",
    "--embed-chapters",
    "--remux-video", "mkv",
    "--merge-output-format", "mkv",
    "-o", "%(title)s.%(ext)s"
  ) + @($args) + @("-c", "--socket-timeout", "5")

  Invoke-YtdlpWithRetry -YtdlpArguments $ytdlpArguments
}

function ytdl {
  ytdl-hq @args
}

function ytdl-hq-mkv {
  if ($args.Count -eq 0) {
    Write-Error "ytdl-hq-mkv: A URL or other yt-dlp argument is required"
    return
  }

  ytdl-hq @args
}

function ytdl-hq-mp4 {
  if ($args.Count -eq 0) {
    Write-Error "ytdl-hq-mp4: A URL or other yt-dlp argument is required"
    return
  }

  $ytdlpArguments = @(
    "--embed-subs",
    "--compat-options", "no-live-chat,multistreams",
    "--embed-metadata",
    "--embed-subs",
    "--embed-thumbnail",
    "--embed-chapters",
    "-f", "bv*[ext=mp4][vcodec^=avc]+ba[ext=m4a]/b[ext=mp4] / bv*+ba/b",
    "-o", "%(title)s.%(ext)s"
  ) + @($args) + @("-c", "--socket-timeout", "5")

  Invoke-YtdlpWithRetry -YtdlpArguments $ytdlpArguments
}

function ytdl-mp3 {
  if ($args.Count -eq 0) {
    Write-Error "ytdl-mp3: A URL or other yt-dlp argument is required"
    return
  }

  $ytdlpArguments = @(
    "--embed-metadata",
    "--compat-options", "no-live-chat,multistreams",
    "--embed-thumbnail",
    "--extract-audio",
    "--audio-format", "mp3",
    "-o", "%(title)s.%(ext)s"
  ) + @($args) + @("-c", "--socket-timeout", "5")

  Invoke-YtdlpWithRetry -YtdlpArguments $ytdlpArguments
}
