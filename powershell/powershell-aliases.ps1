Set-Alias vscode code

if (Check-Command cht) {
  if (Test-Path Function:\help) {
    Remove-Item Function:\help
  }
  function chtpagenated ($cmd) {
    if (Check-Command less) {
      cht $cmd | less -FX
    } else {
      cht $cmd
    }
  }
  Set-Alias help chtpagenated
  Set-Alias tldr help
}