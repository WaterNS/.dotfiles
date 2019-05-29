Function install-jq {
  if (!(Check-Command jq)) {
    "NOTE: jq not found, availing into dotfiles bin"
    "------------------------------------------------"
    [Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"
    $local:jq="https://api.github.com/repos/stedolan/jq/releases/latest"
    $local:latest=$(Invoke-WebRequest $jq | Select-Object content | Get-URLs | Select-String "win64" | Select-Object -ExpandProperty line)

    Invoke-WebRequest "$latest" -OutFile "$HOME/.dotfiles/opt/bin/jq.exe"

    if (Check-Command jq) {
      "GOOD - jq is now available"
    } else {
      "BAD - jq doesn't seem to be available"
    }
  }
}