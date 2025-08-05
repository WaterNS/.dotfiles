Function updateGitRepo {
  param (
    $repoName=$($args[0]),
    $description=$($args[1]),
    $repoLocation=$($args[2])
  )

  $oldDir=$PWD
  ""
  "-Check updates: $repoName ($description)"
  cd "$repoLocation"
  git fetch

  if ((git rev-list --count master..origin/master) -gt 0) {
    Write-Host "--Updating $repoName $description repo " -NoNewline
    Write-Host "(from $(git rev-parse --short master) to " -NoNewline
    Write-Host "$(git rev-parse --short origin/master))" -NoNewline

    #HACK FIX for Azure Hosted Shell
    if ($env:ACC_CLOUD) {
      #Azure Shell like to inject crap into .bashrc. Hack fix for now
      "HACKFIX for AzureShell: Reverting 'posixshells/bash/.bashrc' to HEAD to allow updating..."
      git checkout HEAD -- posixshells/bash/.bashrc
    }


    git pull --quiet

    # Restart the init script if it self updated
    if ("$repoName" -eq "dotfiles") {
      cd $oldDir
      ""
      ""
      Invoke-Expression -Command ("$SCRIPTPATH $cmdArgs")
    }
  }

  cd $oldDir
}
Function Check-Command($cmdname)
{
    return [bool](Get-Command -Name $cmdname -ErrorAction SilentlyContinue)
}

Function Check-Installed($name, $type = "binary", $path) {
  switch ($type) {
    {$_ -like "*binary*"} { return Check-Command($name) }
    {$_ -like "*folder*" -and $path} { return [bool](Test-Path "$path") }
    {$_ -like "*folder*"} { return [bool](Test-Path "$HOME/.dotfiles/opt/bin/$name") }
    Default { Write-Warning "Check-Installed: Unexpected type ($type)"; return $false }
  }
}

Function Check-OS() {
  $os = "$([System.Environment]::OSVersion.Platform)"
  if ([System.Environment]::Is64bitProcess) {
    $os += " x64"
  } else {
    $os += " x32"
  }
  return "$os"
}

#Function to convert seconds to human friendly time format
Function seconds2time {

param (
 [parameter(Mandatory=$true,Position=0)]
 [ValidateNotNullOrEmpty()]
 [Alias('t')]
 [int]$time
)

 $t=$time
 $D=[math]::Truncate($t/60/60/24)
 $H=[math]::Truncate($t/60/60%24)
 $M=[math]::Truncate($t/60%60)
 $S=[math]::Truncate($t%60)

 $output=""

 #Print the days, if any
 if ($D -gt 0) {
   $output= $output + "$D day"; if ($D -gt 1) {$output= $output + "s"}
 }

 #Print the hours, if any
 if ($H -gt 0) {
   if ($D -gt 0) {$output= $output + ", "}
   if (($M -lt 1) -AND ($D -gt 0)) {$output= $output + "and "}
   $output= $output + "$H hour"; if ($H -gt 1) {$output= $output + "s"}
 }

 #Print the minutes, if any
 if ($M -gt 0) {
   if (($D -gt 0) -OR ($H -gt 0)) {$output= $output + ", "}
   if (($S -lt 1) -AND ($H -gt 0)) {$output= $output + "and "}
   $output= $output + "$M minute"; if ($M -gt 1) {$output= $output + "s"}
 }

 #Print the seconds, if any
 if ($S -gt 0) {
   if (($D -gt 0) -OR ($H -gt 0) -OR ($M -gt 0)) {$output= $output + ", "}
   if (($M -gt 0)) {$output= $output + "and "}
   $output= $output + "$S second"; if ($s -gt 1) {$output= $output + "s"}
 }

  if ($t -eq 0) {
    $output = "0 seconds"
  }

Write-Output $output
}

Function Test-InScript {
  if ( ((Get-PSCallStack).Command -like "*.ps1*") ) {
    return $true
  }

  return $false

}

Function Test-NotInScript {
  if (-NOT (Test-InScript)) {
    return $true
  }

  return $false

}

Function Test-IsNonInteractiveShell {
  if ([string]([Environment]::GetCommandLineArgs()) -like "*Start-EditorServices.ps1*") {
    # Hack:
    # Consider VS Code Powershell extension launched sessions as interactive
    return $false
  }
  if ([Environment]::UserInteractive) {
      foreach ($arg in [Environment]::GetCommandLineArgs()) {
          # Test each Arg for match of abbreviated '-NonInteractive' command.
          if (($arg -like '-NonI*') -OR ($arg -eq '-Command')) {
              return $true
          }
      }
  }

  return $false
}

Function find-string([String]$regex, $path) {
  if (!$path) {$path = "."}
  Get-ChildItem $path -file -recurse | Select-String -pattern ([Regex]::Escape("$regex")) | group path | select -ExpandProperty name
}

Function Get-URLs([parameter(ValueFromPipeline)][String]$Content) {
  (Select-String -AllMatches '(http[s]?)(:\/\/)([^\s,]+)(?=")' -Input $Content).Matches.Value
}

Function Powershell-FileDownload([String]$URL,$output) {
  $wc = new-object system.net.WebClient
  $wc.DownloadFile($URL,$output)
  $wc.Dispose()
}

Function gitRemoveOrphanBranches() {
  if (git rev-parse --git-dir 2> $null) {
    git checkout master;
    git remote update origin --prune;
    git branch -vv | Select-String -Pattern ": gone]" |
      ForEach-Object{ $_.toString().Trim().Split(" ")[0] } |
      ForEach-Object {git branch -D $_}
  } else {
    Write-Host "gitRemoveOrphanBranches:" -NoNewline -BackgroundColor Black -ForegroundColor White
    Write-Host " Error - Not a git repo" -ForegroundColor Yellow
  }
}

Function Add-EnvPath {
  #credit/ref/source: https://stackoverflow.com/a/34844707/7650275
  param(
      [Parameter(Mandatory=$true)]
      [string] $Path,

      [ValidateSet('Machine', 'User', 'Session')]
      [string] $Container = 'Session'
  )

  if ($Container -ne 'Session') {
      $containerMapping = @{
          Machine = [EnvironmentVariableTarget]::Machine
          User = [EnvironmentVariableTarget]::User
      }
      $containerType = $containerMapping[$Container]

      $persistedPaths = [Environment]::GetEnvironmentVariable('Path', $containerType) -split ';'
      if ($persistedPaths -notcontains $Path) {
          $persistedPaths = $persistedPaths + $Path | Where-Object { $_ }
          [Environment]::SetEnvironmentVariable('Path', $persistedPaths -join ';', $containerType)
      }
  }

  $envPaths = $env:Path -split ';'
  if ($envPaths -notcontains $Path) {
      $envPaths = $envPaths + $Path | Where-Object { $_ }
      $env:Path = $envPaths -join ';'
  }
}

Function pubkey {
  param(
      [Parameter(Mandatory=$false)]
      [string] $KeyName = "id_rsa"
  )

  if (Test-Path "$HOME/.ssh/$KeyName.pub") {
    Get-Content "$HOME/.ssh/$KeyName.pub";
    if (Check-Command "clip") {
      Get-Content "$HOME/.ssh/$KeyName.pub" | clip
      Write-Host "Copied to Clipboard!"
    }

  } else {
    Write-Host "Didn't find ~/.ssh/$KeyName.pub, aborting..."
  }
}

function foldertotal {
  param (
    [string]$Path = ".",
    [switch][Alias('r')]$rootDirOnly
  )

  $dollarRegex = '(?<=\$|-\$)\d+(\.\d{1,2})?'

  if (Test-Path -Path $Path) {
    if ($rootDirOnly) {
      $fileNames = Get-ChildItem -Path $Path -Name
    } else {
      $fileNames = Get-ChildItem -Path $Path -Name -Recurse
    }

    $sum = 0
    foreach ($fileName in $fileNames) {
      $matches = [regex]::Matches($fileName, $dollarRegex)
      foreach ($match in $matches) {
        if ($fileName.Contains("-$")) {
          $sum -= [decimal]::Parse($match.Value)
        }
        else {
          $sum += [decimal]::Parse($match.Value)
        }
      }
    }
    $sum = '{0:N2}' -f $sum
    return "`$$sum"
  }
  else {
    Write-Error "Path '$Path' not found."
  }
}

function hash256 {
  [CmdletBinding()]
  param(
      [Parameter(Mandatory = $true)]
      [string]$Path
  )

  if (-not (Test-Path -Path $Path)) {
      Write-Error "The path '$Path' does not exist."
      return
  }

  $item = Get-Item -Path $Path -ErrorAction Stop

  if ($item.PSIsContainer) {
      Write-Error "The path '$Path' is a directory, not a file."
      return
  }

  # Calculate the SHA256 hash
  $hash = Get-FileHash -Path $Path -Algorithm SHA256

  # Output the hash
  return $hash.Hash
}

function hashmd5 {
  [CmdletBinding()]
  param(
      [Parameter(Mandatory = $true)]
      [string]$Path
  )

  if (-not (Test-Path -Path $Path)) {
      Write-Error "The path '$Path' does not exist."
      return
  }

  $item = Get-Item -Path $Path -ErrorAction Stop

  if ($item.PSIsContainer) {
      Write-Error "The path '$Path' is a directory, not a file."
      return
  }

  # Calculate the MD5 hash
  $hash = Get-FileHash -Path $Path -Algorithm MD5

  # Output the hash
  return $hash.Hash
}

function ForceDelete {
  <#
      .SYNOPSIS
          Force-deletes a folder even when normal “access denied” errors occur.

      .DESCRIPTION
          • Tries a normal Remove-Item first.
          • If that fails, takes ownership, grants Administrators full control,
            clears read-only/hidden/system attributes, and tries again.
          • As a last resort, mirrors an empty temp folder over the target
            with ROBOCOPY /MIR (obliterates contents regardless of ACL),
            then removes the now-empty folder.

      .PARAMETER Path
          The folder you want to remove.

      .EXAMPLE
          Remove-FolderForce -Path "C:\LockedFolder"
  #>
  [CmdletBinding()]
  param (
    [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [Alias('FullName')]
    [string]$Path
  )

  process {
    if (-not (Test-Path -LiteralPath $Path)) {
      Write-Verbose "Path '$Path' does not exist—nothing to delete."
      return
    }

    try {
      # ---------- First, the easy way ----------
      Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
      Write-Verbose "Successfully removed '$Path' via Remove-Item."
      return
    }
    catch {
      Write-Warning "Standard removal failed: $($_.Exception.Message)"
    }

    # ---------- Escalation path ----------
    Write-Verbose "Taking ownership of '$Path' and resetting ACLs…"
    & takeown.exe /F $Path /A /R /D Y  | Out-Null   # /A = Administrators group owner
    & icacls.exe $Path /grant Administrators:F /T /C | Out-Null

    Write-Verbose "Clearing read-only/hidden/system attributes…"
    Get-ChildItem -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue |
    ForEach-Object { $_.Attributes = 'Normal' }
      (Get-Item -LiteralPath $Path).Attributes = 'Normal'

    try {
      Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
      Write-Verbose "Removed '$Path' after ownership reset."
      return
    }
    catch {
      Write-Warning "Removal still failing—invoking ROBOCOPY wipe."
    }

    # ---------- Last-ditch: ROBOCOPY mirror trick ----------
    $temp = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid())
    New-Item -ItemType Directory -Path $temp | Out-Null
    & robocopy.exe $temp $Path /MIR /NJH /NJS /R:1 /W:0 | Out-Null
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue

    if (Test-Path -LiteralPath $Path) {
      throw "Unable to delete folder '$Path' even after escalated attempts."
    }
    else {
      Write-Verbose "Folder '$Path' successfully deleted via ROBOCOPY method."
    }
  }
}
