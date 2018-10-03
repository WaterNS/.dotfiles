Function Prompt {

Remove-Variable symbolicref
Remove-Variable branch
Remove-Variable differences
Remove-Variable localchanges

# ToDO:
# - Capture how many commits ahead

if (Test-Path ".git" -PathType Container) {
  $symbolicref = $(git symbolic-ref HEAD)
} else {$symbolicref = $NULL}


if ($symbolicref -ne $NULL) {
  $branch = $symbolicref.substring($symbolicref.LastIndexOf("/") +1)
  
  $differences = $(git diff-index --name-status HEAD)
  
  If ($differences -ne $NULL) {
    $localchanges = $true
    $git_create_count = [regex]::matches($differences, "A`t").count
    $git_update_count = [regex]::matches($differences, "M`t").count
    $git_delete_count = [regex]::matches($differences, "D`t").count
  }
  else {
    $localchanges = $false
    $git_create_count = 0
    $git_update_count = 0
    $git_delete_count = 0
  }
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
    Write-Host ($branch) -nonewline -foregroundcolor White
  }
  else {Write-Host $branch -nonewline -foregroundcolor Red}
  
  
  #Output local changes count, if any, in pretty colors
  If ($localchanges) {
     
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
  }
  
  Write-Host (" ]") -nonewline -foregroundcolor Magenta

}

$(Write-Host $('>' * ($nestedPromptLevel + 1)) -nonewline -foregroundcolor White)



return " "
}