# About:
"Tool belt" of the tech age.

A portable .dotfiles for configuring an environment across devices, disparate operating systems, locally and in cloud based containers.

Built for:
- Portability of preferred setup
- Learning & regular tweaks/improvements
- Small enough to debug and self-contained (mostly)
  - (mostly) = Downloaded helpers or super shell enhancements will live in `~/.dotfiles/opt/`, as a kind of installed extension/plugin/binary blob.

## Target:
- Various shells:
  - Powershell
  - POSIX-like: sh, bash, zsh (possibly others)
- Tools: VS Code, git, vim
- Installers (try to) support x64 Windows / Linux / MacOS (Intel/Apple Silicon)

## What it does

### Enhances command line experience:
- Prompt: Colorize, Git status, node_modules/.bin to PATH

- PATH: Download some handy tools, if needed (jq, pretty ping, lsd)
  - Doesn't use `apt`, `brew`, `chocolatey` - just plain  scripts w/ `curl`/`wget` and `git`.

- Aliases:
  - Override standard commands with preferred defaults (e.g. `ls` -> `ls -ahl`)
  - When available, replace tool with modern counterpart (e.g. `ls` might be replaced by exa, lsd, etc )
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
