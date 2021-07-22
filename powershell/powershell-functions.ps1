Function updategitrepo {
  param (
    $reponame=$($args[0]),
    $description=$($args[1]),
    $repolocation=$($args[2])
  )

  $olddir=$PWD
  ""
  "-Check updates: $reponame ($description)"
  cd "$repolocation"
  git fetch

  if ((git rev-list --count master..origin/master) -gt 0) {
    Write-Host "--Updating $reponame $description repo " -NoNewline
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
    if ("$reponame" -eq "dotfiles") {
      cd $olddir
      ""
      ""
      Invoke-Expression -Command ("$SCRIPTPATH $cmdargs")
    }
  }

  cd $olddir
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
  $wc = new-object system.net.webclient
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
