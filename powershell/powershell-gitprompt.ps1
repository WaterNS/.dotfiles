Function Prompt {

$SYMBOL_GIT_BRANCH='⑂'
$SYMBOL_GIT_MODIFIED='*'
$SYMBOL_GIT_PUSH='↑'
$SYMBOL_GIT_PULL='↓'

if (git rev-parse --git-dir 2> $null) {

  $symbolicref = $(git symbolic-ref --short HEAD 2>$NULL)

  if ($symbolicref) {#For branches append symbol
    $branch = $symbolicref.substring($symbolicref.LastIndexOf("/") +1)
    $branchText=$SYMBOL_GIT_BRANCH + ' ' + $branch
  } else {#otherwise use tag/SHA
      $symbolicref=$(git describe --tags --always 2>$NULL)
      $branch=$symbolicref
      $branchText=$symbolicref
  }

} else {$symbolicref = $NULL}


if ($symbolicref -ne $NULL) {
  # Tweak: 
  # When WSL and Powershell terminals concurrently viewing same repo
  # Stops from showing CRLF/LF differences as updates
  git status > $NULL
  
  $differences = $(git diff-index --name-status HEAD)
  
  If ($differences -ne $NULL) {
    $git_create_count = [regex]::matches($differences, "A`t").count
    $git_update_count = [regex]::matches($differences, "M`t").count
    $git_delete_count = [regex]::matches($differences, "D`t").count
  }
  else {
    $git_create_count = 0
    $git_update_count = 0
    $git_delete_count = 0
  }

  #Identify how many commits ahead and behind we are
  #by reading first two lines of `git status`
  $marks=$NULL
  (git status --porcelain --branch 2>$NULL) | ForEach-Object { 
  
      If ($_ -match '^##') {
        If ($_ -match 'ahead\ ([0-9]+)') {$git_ahead_count=[int]$Matches[1]}
        If ($_ -match 'behind\ ([0-9]+)') {$git_behind_count=[int]$Matches[1]}
      }
  }
  $branchText+="$marks"


}

if (test-path variable:/PSDebugContext) { 
  Write-Host '[DBG]: ' -nonewline -foregroundcolor Yellow
}

Write-Host "PS " -nonewline -foregroundcolor White
Write-Host $($executionContext.SessionState.Path.CurrentLocation) -nonewline -foregroundcolor White

if ($symbolicref -ne $NULL) {
  Write-Host (" [ ") -nonewline -foregroundcolor Magenta

  #Output the branch in prettier colors
  If ($branch -eq "master") {
    Write-Host ($branchText) -nonewline -foregroundcolor White
  }
  else {Write-Host $branchText -nonewline -foregroundcolor Red}

  #Output commits ahead/behind, in pretty colors
  If ($git_ahead_count -gt 0) {
      Write-Host (" $SYMBOL_GIT_PUSH") -nonewline -foregroundcolor White
      Write-Host ($git_ahead_count) -nonewline -foregroundcolor Green
  }
  If ($git_behind_count -gt 0) {
      Write-Host (" $SYMBOL_GIT_PULL") -nonewline -foregroundcolor White
      Write-Host ($git_behind_count) -nonewline -foregroundcolor Yellow
  }
  
  #Output unstaged changes count, if any, in pretty colors   
  If ($git_create_count -gt 0) {
      Write-Host (" c:") -nonewline -foregroundcolor White
      Write-Host ($git_create_count) -nonewline -foregroundcolor Green
  }
  
  If ($git_update_count -gt 0) {
    Write-Host (" u:") -nonewline -foregroundcolor White
    Write-Host ($git_update_count) -nonewline -foregroundcolor Yellow
  }
  
  If ($git_delete_count -gt 0) {
    Write-Host (" d:") -nonewline -foregroundcolor White
    Write-Host ($git_delete_count) -nonewline -foregroundcolor Red
  }
  
  Write-Host (" ]") -nonewline -foregroundcolor Magenta

}

$(Write-Host $('>' * ($nestedPromptLevel + 1)) -nonewline -foregroundcolor White)



return " "}#Powershell requires a return, otherwise defaults to factory prompt