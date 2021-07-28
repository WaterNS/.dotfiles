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

# alias common git commands to shorthand
if (Check-Command git) {
  Function AliasGitStatus {git status}
  Set-Alias status AliasGitStatus

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
