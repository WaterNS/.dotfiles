Set-Alias vscode code

if (Check-Command cht) {
  if (Test-Path Function:\help) {
    Remove-Item Function:\help
  }
  Set-Alias help cht
}