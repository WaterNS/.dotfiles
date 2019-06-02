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

Function Check-Command($cmdname)
{
    return [bool](Get-Command -Name $cmdname -ErrorAction SilentlyContinue)
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
    git branch -vv |
      Select-String -Pattern ": gone]" |
      Where-Object { $_.toString().Trim().Split(" ")[0]} |
      Where-Object {git branch -D $_}
  } else {
    Write-Host "gitRemoveOrphanBranches:" -NoNewline -BackgroundColor Black -ForegroundColor White
    Write-Host " Error - Not a git repo" -ForegroundColor Yellow
  }
}