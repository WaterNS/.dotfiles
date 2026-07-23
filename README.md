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
- Installers (try to) support x64 Windows / Linux / macOS (Intel/Apple Silicon) / iOS (e,g, a-Shell,iSH)

## What it does

Bootstraps a new machine/environment with basics and points configurations to ones stored in dotfiles.

### Enhances command line experience:
- Prompt/Env: Colorize, Git status, set session parameters (default editors), import all the functions/aliases, add node_modules/.bin (and others) to PATH, set some saner tighter defaults for history etc.

- Preload some handy tools (`jq`, `prettyping`, `lsd`, etc)

- Aliases:
  - Override standard commands with preferred defaults (e.g. `ls` -> `ls -ahl`)
  - When available, alias standard command to modern counterpart (e.g. `ls` might point to `exa`, `lsd`, etc )
- Functions: Some polyfills, some neat little tricks/helper functions

- Self Updating: Desktop and iSH sessions check and auto update when the timer expires. a-Shell uses an explicit archive/Working Copy refresh because `lg2` is not treated as fully compatible Git.

### Bundles in:
- Configs for tools outside the command line (e.g. VS Code profile, OS shortcuts)

- Tweaks OS preferences and experience

## Where:
On desktop systems and iSH, this lands in `$HOME/.dotfiles`. Cache and downloaded binaries/tools are stored in `$HOME/.dotfiles/opt/`.

a-Shell is the exception: writable user files live below Documents, so the repository belongs at `$HOME/Documents/.dotfiles` and its managed tools at `$HOME/Documents/.dotfiles/opt/`.

Symlinks created for config files found in $HOME, pointing to ones in this repo.


# POSIX OS bootstrap (macOS/Linux/iSH/a-Shell):
1. Pull & Init dotfiles

```sh
echo 'set -e;umask 077;q(){ command -v "$1">/dev/null;};if [ -r /proc/ish/version ]||[ -r /ish/version ]||uname -r|grep -q -e -ish;then q curl&&q tar||apk add --no-cache curl tar;fi;b=$HOME/tmp/d.$$;mkdir -p "${b%/*}";x(){ rm -f "$b";};trap x 0;u=https://raw.githubusercontent.com/WaterNS/.dotfiles/master/bootstrap_posix.sh;if q curl;then curl -fsSLo "$b" "$u";elif q wget;then wget -qO "$b" "$u";else echo "Install curl or wget.">&2;exit 1;fi;[ -s "$b" ];sh "$b"'|sh
```

2. [Optional] Add SSH pubkey to github account:
```
pubkey WaterNS
```

3. [Optional] Update local repo with SSH remote:
```
cd ~/.dotfiles && git remote set-url origin git@github.com:WaterNS/.dotfiles.git
```

## a-Shell behavior (iOS/iPadOS):

For Apple Shortcuts that invoke yt-dlp, Python, or FFmpeg, configure the a-Shell action to run **In App**. Using `ytdl --shortcut=MODE ...` directly is independent of alias loading. Shortcut output otherwise uses a-Shell's Shortcuts working directory unless an explicit output path is supplied.

To update a-Shell, rerun the same bootstrap command above. The normal timed updater requires real Git commands and repository metadata, so it cannot use `lg2` as a drop-in replacement. The shared bootstrap instead refreshes the GitHub archive and then runs the existing a-Shell initializer.

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
