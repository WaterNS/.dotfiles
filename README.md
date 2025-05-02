# About:
"Tool belt" of the tech age.

A portable .dotfiles for bootstrapping and maintaining consistent environment across devices, disparate operating systems, locally and in cloud based containers. Heavy focus on command line tweaks, but a number of niceties outside of CMDline included.

Built for:
- Portability of preferred setup (bringing preferred defaults, helpful functions, general power user tweaks)
- Learning & regular tweaks/improvements
- Small enough to debug and self-contained (mostly)
  - (mostly) = Downloaded helpers or super shell enhancements will live in `~/.dotfiles/opt/`, as a kind of installed extension/plugin/binary blob. Minimal clutter of user directories and very minimal global or system wide changes.

## Target:
- Various shells:
  - POSIX-like: sh, BusyBox/"ash", bash, zsh (possibly others)
  - Powershell
  - Cloud environments: AWS CloudShell, Azure Cloud Shell
- Tools: VS Code, git, vim
- Installers (try to) support x64 Windows / Linux / MacOS (Intel/Apple Silicon) / iOS (via apps like iSH/aShell)

## What it does

Bootstraps a new machine/environment with basics and points configurations to ones stored in dotfiles.

### Enhances command line experience:
- Prompt/Env: Colorize, Git status, set session parameters (default editors), import all the functions/aliases, add node_modules/.bin (and others) to PATH, set some saner tighter defaults for history etc.

- Preload some handy tools (`jq`, `prettyping`, `lsd`, etc)

- Aliases:
  - Override standard commands with preferred defaults (e.g. `ls` -> `ls -ahl`)
  - When available, alias standard command to modern counterpart (e.g. `ls` might point to `exa`, `lsd`, etc )
- Functions: Some polyfills, some neat little tricks/helper functions

- Self Updating: Each session will check and auto update (if timer expired).

### Bundles in:
- Configs for tools outside the command line (e.g. VS Code profile, OS shortcuts)

- Tweaks OS preferences and experience

## Where:
All this lands in `$HOME/.dotfiles`. Cache and downloaded binaries/tools stored in `$HOME/.dotfiles/opt/`.

Symlinks created for config files found in $HOME, pointing to ones in this repo.


# POSIX OS bootstrap (OSX/Linux):
1. Pull & Init dotfiles
```
mkdir "$HOME/.dotfiles" && \
curl -L -S -s https://github.com/WaterNS/.dotfiles/tarball/master | \
  tar xz --strip 1 -C "$HOME/.dotfiles" && \
  cd $HOME/.dotfiles && ./init_posix.sh
```

2. [Optional] Add SSH pubkey to github account:
```
pubkey WaterNS
```

3. [Optional] Update local repo with SSH remote:
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
cd ~/.dotfiles; git remote set-url origin git@github.com:WaterNS/.dotfiles.git
```
