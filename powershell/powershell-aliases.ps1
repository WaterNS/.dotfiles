Set-Alias vscode code

if (Check-Command cht) {
  if (Test-Path Function:\help) {
    Remove-Item Function:\help
  }
  function chtpagenated ($cmd) {
    if (Check-Command less) {
      cht --query $cmd | less -FX
    } else {
      cht --query $cmd
    }
  }
  Set-Alias help chtpagenated
  Set-Alias tldr help
}

# alias common git commands to shorthand
if (Check-Command git) {
  Function AliasGitStatus {git status}
  Set-Alias status AliasGitStatus

  Function AliasGitLog {git customLog}
  Set-Alias log AliasGitLog

  Function AliasGitPush {git push}
  Set-Alias push AliasGitPush

  Function AliasGitReset {
    git fetch "$(git config branch.$(git name-rev --name-only HEAD).remote)";
    git reset "$(git config branch.$(git name-rev --name-only HEAD).remote)/$(git rev-parse --abbrev-ref HEAD)";
  }
  Set-Alias gitreset AliasGitReset

  Function AliasGitResetHard {
    git fetch "$(git config branch.$(git name-rev --name-only HEAD).remote)";
    git reset --hard "$(git config branch.$(git name-rev --name-only HEAD).remote)/$(git rev-parse --abbrev-ref HEAD)";
  }
  Set-Alias gitresethard AliasGitResetHard
}

if (Check-Command bat) {
  if (Test-Path Alias:\cat) {
    Remove-Item Alias:\cat
  }
  Function AliasBat {bat --tabs 2 $args}
  Set-Alias cat AliasBat
}

if (Check-Command "where.exe") {
  Function AliasWhereIs {where.exe $args}
  Set-Alias whereis AliasWhereIs
}

if (!(Check-Command tr)) {
  if (Check-Command wsl) {
    Function AliasTr {wsl tr $args}
    Set-Alias tr AliasTr
  }
}

if (!(Check-Command top)) {
  if (Check-Command ntop) {
    Function AliasTop {ntop $args}
    Set-Alias top AliasTop
  }
}

if (!(Check-Command "downloadTorrent")) {
  if (Check-Command "aria2") {
    Function AliasAria2bt {aria2 --file-allocation=none --seed-time=0 --bt-save-metadata=true --listen-port=7070-7075 --dht-listen-port=7076-7080 $args}
    Function AliasAria2btNoUp {AliasAria2bt --max-upload-limit=0k $args}

    Set-Alias downloadTorrent AliasAria2bt
    Set-Alias downloadTorrentNoUp AliasAria2btNoUp
  }
}

if (!(Check-Command "download")) {
  if (Check-Command "aria2") {
    Function AliasAria2 {aria2 $args}
    Set-Alias download AliasAria2
  }
}

if ((Check-Command "Get-Uptime")) {
  Function uptimefunc {Get-Uptime}
  Set-Alias up uptimefunc
  Set-Alias uptime uptimefunc
} else {
  Function uptimefunc {Get-CimInstance -ClassName Win32_OperatingSystem | Select-Object LastBootUpTime}
  Set-Alias up uptimefunc
  Set-Alias uptime uptimefunc
}
