# About:
"Tool belt" of the tech age.

A portable .dotfiles for configuring an environment across devices, disparate operating systems, locally and in cloud based containers. Heavy focus on command line tweaks, but niceties outside of CMDline included (when I find them useful)

Built for:
- Portability of preferred setup (bringing preferred defaults, helpful functions, general power user tweaks)
- Learning & regular tweaks/improvements
- Small enough to debug and self-contained (mostly)
  - (mostly) = Downloaded helpers or super shell enhancements will live in `~/.dotfiles/opt/`, as a kind of installed extension/plugin/binary blob.

## Target:
- Various shells:
  - POSIX-like: sh, BusyBox/"ash", bash, zsh (possibly others)
  - Powershell
- Tools: VS Code, git, vim
- Installers (try to) support x64 Windows / Linux / MacOS (Intel/Apple Silicon) / iOS (via apps like iSH/aShell)

## What it does

### Enhances command line experience:
- Prompt: Colorize, Git status, node_modules/.bin to PATH

- PATH: Download some handy tools, if needed (jq, pretty ping, lsd, etc)
  - Prefers single binary/statically compiled versions. Avoids using `apt`, `apk`, `brew`, `chocolatey` - just plain  scripts w/ `curl`/`wget` and `git`.
    - Package managers (ala `brew`) are kept in `~/.dotfiles/opt` (in effort to keep deployment self contained)

- Aliases:
  - Override standard commands with preferred defaults (e.g. `ls` -> `ls -ahl`)
  - When available, alias standard command to modern counterpart (e.g. `ls` might point to by exa, lsd, etc )
- Functions: Some polyfills, some neat little tricks

- Environment: Colorize, set session parameters (default editors), import all the functions/aliases, set prompts, etc.
- Self Updating: Each session will check and auto update (if timer expired).

### Bundles in support for tweaks for tools outside the command line:
- VS Code Settings

## Where:
All this lands in `$HOME/.dotfiles`.

Symlinks created for config files found in $HOME, pointing to ones in this repo.

Cache and downloaded binaries stored in `$HOME/.dotfiles/opt/`.


# POSIX OS bootstrap (OSX/Linux):
1. Install git (if needed): https://git-scm.com/download/

2. Init dotfiles
```
git clone https://github.com/WaterNS/.dotfiles.git ~/.dotfiles && \
  cd ~/.dotfiles && ./init_posix.sh
```

3. [Optional] Add SSH pubkey to github account:
```
pubkey WaterNS
```

4. [Optional] Update local repo with SSH remote:
```
cd ~/.dotfiles && git remote set-url origin git@github.com:WaterNS/.dotfiles.git
```

# Windows bootstrap:
1. Install git (if needed): https://git-scm.com/download/

2. Init dotfiles - Run Powershell window **as Administrator** (needed for symbolic links/Execution Policy)
```
git clone https://github.com/WaterNS/.dotfiles.git $HOME/.dotfiles
cd ~/.dotfiles
Set-ExecutionPolicy Unrestricted -force
./init_powershell.ps1
```

3. [Optional] Add SSH pubkey to github account:
```
pubkey WaterNS
```

4. [Optional] Update local repo with SSH remote:
```
cd ~/.dotfiles && git remote set-url origin git@github.com:WaterNS/.dotfiles.git
```
