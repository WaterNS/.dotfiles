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

$goneBranch=$(git branch -vv | Select-String "$branch" | Select-String -Pattern ": gone]") 2>$NULL
#$remote = $(git config branch.$branch.remote)

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
  $TimeSinceReflog = (New-TimeSpan -Start $lastreflog).TotalSeconds
  if (Test-Path $gitdir/FETCH_HEAD) {
    $lastfetch =  (Get-Item $gitdir/FETCH_HEAD).LastWriteTime
    $TimeSinceFetch = (New-TimeSpan -Start $lastfetch).TotalSeconds
  } else {
    $TimeSinceFetch = $MaxFetchSeconds + 1
  }
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

      #Identify Added/UnTracked files
      elseIf ($_ -match '^A\s\s') {
        $git_index_added_count++
      }
      elseIf ($_ -match '^\?\?\ ') {
        $git_untracked_count++
      }

      #Identify Modified files
      elseIf ($_ -match '^MM\s') {
        $git_index_modified_count++
        $git_modified_count++
      }
      elseIf ($_ -match '^M\s\s') {
        $git_index_modified_count++
      }
      elseIf ($_ -match '^\sM\s') {
        $git_modified_count++
      }

      #Identify Renamed files
      elseIf ($_ -match '^R\s\s') {
        $git_index_renamed_count++
      }

      #Identify Deleted files
      elseIf ($_ -match '^D\s\s') {
        $git_index_deleted_count++
      }
      elseIf ($_ -match '^\sD\s') {
        $git_deleted_count++
      }

  }

  # Count commits on new branch (that doesn't have a remote)
  If (!$git_ahead_count -and !$(git config --get branch.$branch.remote)) {
    $commitsOnBranch = $(git rev-list master.. --count) #TODO: replace 'master' with looked up Parent branch
    if ($commitsOnBranch) {
      $git_ahead_count=[int]$commitsOnBranch
    }
  }

  # Count commits on branch that has remote, but remote is empty (e.g cloned empty repo and made some commits)
  if (!$git_ahead_count -and $goneBranch) {
    $commitsOnBranch = $(git rev-list $branch --count)
    if ($commitsOnBranch) {
      $git_ahead_count=[int]$commitsOnBranch
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

  #Output staged changes count, if any, in pretty colors
  If ($git_index_added_count -gt 0) {
    Write-Host (" Ai:") -nonewline -foregroundcolor White
    Write-Host ($git_index_added_count) -nonewline -foregroundcolor Green
  }

  If ($git_index_renamed_count -gt 0) {
    Write-Host (" Ri:") -nonewline -foregroundcolor White
    Write-Host ($git_index_renamed_count) -nonewline -foregroundcolor DarkGreen
  }

  If ($git_index_modified_count -gt 0) {
    Write-Host (" Mi:") -nonewline -foregroundcolor White
    Write-Host ($git_index_modified_count) -nonewline -foregroundcolor Yellow
  }

  If ($git_index_deleted_count -gt 0) {
    Write-Host (" Di:") -nonewline -foregroundcolor White
    Write-Host ($git_index_deleted_count) -nonewline -foregroundcolor Red
  }

  #Output unstaged changes count, if any, in pretty colors
  If (($git_index_added_count) -OR ($git_index_modified_count) -OR ($git_index_deleted_count)) {
    If (($git_modified_count -gt 0) -OR ($git_deleted_count -gt 0))  {
      Write-Host (" |") -nonewline -foregroundcolor White
    }
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

if (Test-Path "$PWD\node_modules\.bin") {
  Add-EnvPath "$PWD\node_modules\.bin"
}

return " "}#Powershell requires a return, otherwise defaults to factory prompt