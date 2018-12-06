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

  #Do git fetch if no changes in last 10 minutes
  # Last Reflog: Last time upstream was updated
  # Last Fetch: Last time fetch/pull was ATTEMPTED
  # Between the two can identify when last updated or attempted a fetch.
  $MaxFetchSeconds = 600
  $upstream = $(git rev-parse --abbrev-ref "@{upstream}")
  $lastreflog = $(git reflog show --date=iso $upstream -n1)
  if ($lastreflog -eq $NULL) {
    $lastreflog = (Get-Date).AddSeconds(-$MaxFetchSeconds)
  }
  else {
    $lastreflog = [datetime]$($lastreflog | %{ [Regex]::Matches($_, "{(.*)}") }).groups[1].Value
  }
  $gitdir = $(git rev-parse --git-dir)
  $lastfetch =  (Get-Item $gitdir/FETCH_HEAD).LastWriteTime
  $TimeSinceReflog = (New-TimeSpan -Start $lastreflog).TotalSeconds
  $TimeSinceFetch = (New-TimeSpan -Start $lastfetch).TotalSeconds
  #Write-Host "Time since last reflog: $TimeSinceReflog"
  #Write-Host "Time since last fetch: $TimeSinceFetch"
  if (($TimeSinceReflog -gt $MaxFetchSeconds) -AND ($TimeSinceFetch -gt $MaxFetchSeconds)) {
    git fetch --all | Out-Null
  }

  #Identify stashes 
  $stashes = $(git stash list 2>$NULL)
  if ($stashes -ne $NULL) {
    $git_stashes_count=($stashes | Measure-Object -Line).Lines
  }
  else {$git_stashes_count=0}

  #Identify how many commits ahead and behind we are
  #by reading first two lines of `git status`
  #Identify how many untracked files (matching `?? `)
  $marks=$NULL
  (git status --porcelain --branch 2>$NULL) | ForEach-Object { 
  
      If ($_ -match '^##') {
        If ($_ -match 'ahead\ ([0-9]+)') {$git_ahead_count=[int]$Matches[1]}
        If ($_ -match 'behind\ ([0-9]+)') {$git_behind_count=[int]$Matches[1]}
      }
      #Identify Added files
      elseIf ($_ -match '^A\s\s') {
        $git_added_count++
      }
      #Identify Modified files
      elseIf ($_ -match '^\sM\s') {
        $git_modified_count++
      }
      #Identify Deleted files
      elseIf ($_ -match '^\sD\s') {
        $git_deleted_count++
      }
      #Identify untracked files
      elseIf ($_ -match '^\?\?\ ') {
        $git_untracked_count++
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
  If ($git_added_count -gt 0) {
    Write-Host (" A:") -nonewline -foregroundcolor White
    Write-Host ($git_added_count) -nonewline -foregroundcolor Green
  }
  
  If ($git_modified_count -gt 0) {
    Write-Host (" M:") -nonewline -foregroundcolor White
    Write-Host ($git_modified_count) -nonewline -foregroundcolor Yellow
  }
  
  If ($git_deleted_count -gt 0) {
    Write-Host (" D:") -nonewline -foregroundcolor White
    Write-Host ($git_deleted_count) -nonewline -foregroundcolor Red
  }

  If (($git_untracked_count -gt 0) -OR ($git_stashes_count -gt 0))  {
    Write-Host (" |") -nonewline -foregroundcolor White
  }

  If ($git_untracked_count -gt 0)  {
    Write-Host (" untracked:") -nonewline -foregroundcolor White
    Write-Host ($git_untracked_count) -nonewline -foregroundcolor Red
  }

  If ($git_stashes_count -gt 0)  {
    Write-Host (" stashes:") -nonewline -foregroundcolor White
    Write-Host ($git_stashes_count) -nonewline -foregroundcolor Yellow
  }

  Write-Host (" ]") -nonewline -foregroundcolor Magenta

}

$(Write-Host $('>' * ($nestedPromptLevel + 1)) -nonewline -foregroundcolor White)



return " "}#Powershell requires a return, otherwise defaults to factory prompt