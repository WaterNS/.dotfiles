# Register Powershell Logout Commands
Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
  Write-Output "Logging out..."
  . "$HOMEREPO\powershell\powershell-history.ps1"
} | Out-Null
