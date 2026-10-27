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

## Resumable file sharing with `simpleserver`

Run `simpleserver` and open `http://<server-address>:8000/` on another device. PowerShell serves the current directory; POSIX shells serve `/tmp`; a-Shell serves `$HOME/tmp`. The helper uses Python 3's standard library and requires no additional packages.

Each file has a **Resume options** link alongside the existing download and media controls. Open it to choose:

- **Resumable HTTP URL:** a stable attachment URL for a download manager that retains partial files and supports HTTP byte ranges. Copy this URL into the client. It has no temporary browser download session to expire, and remains usable after a server restart while the file and its address stay the same.
- **`.torrent`:** a single-file torrent with piece hashes and a [BEP 19 HTTP web seed](https://www.bittorrent.org/beps/bep_0019.html). A compatible torrent client downloads the same file from this server, checks each piece, and can retain completed pieces across interruptions. No separate torrent daemon or tracker is needed.
- **Magnet:** a magnet link with the torrent metadata URL (`xs`) and HTTP web seed (`ws`). Clients differ in support for fetching metadata this way. If the magnet stays at “retrieving metadata,” download and open the `.torrent` instead.

For a command-line download, use the resumable HTTP URL and repeat the same command after an interruption:

```sh
curl -fL -C - -o "video.mp4" "http://192.168.1.10:8000/video.mp4?download=1"
```

Keep the local partial file and serve the same unchanged source file when resuming. HTTP resume requires the client to preserve and verify its partial download; the torrent option also verifies content against piece hashes. The first torrent request reads and hashes the source file, which can take time for large files; subsequent requests reuse a bounded in-memory cache. Restarting the server clears that cache.

The wrappers forward a custom port and additional options such as `--directory`, `--bind`, and `--public-url`:

```sh
simpleserver --directory "/path/to/share" --public-url "http://192.168.1.10:8000"
```

Normally links use the address through which the client opened the server. Set `--public-url` to the address clients can reach when advertising a different host or a reverse proxy prefix, for example `https://files.example.com/share`. Keep the server reachable at that host, port, and prefix until the transfer finishes. To select another port, run `simpleserver 9000`; otherwise the default is 8000.

On iOS, screen-off and background behavior depends on the client app. These options let a capable client resume after it is suspended; they do not make Safari or another app continue running in the background. Use a client that saves its partial download or torrent progress, then resume when it becomes active again.


# POSIX OS bootstrap

## macOS, Linux, and iSH
```sh
d=~/.dotfiles u=https://github.com/WaterNS/.dotfiles/tarball/master;
mkdir -p $d && (curl -fsSL $u||wget -qO- $u) | \
  tar xzC $d --strip 1 && \
  $d/init_posix.sh
```

## a-Shell
```sh
sh -c 'DOTFILES_PLATFORM=ashell curl -fsSLo ~/tmp/1.sh https://raw.githubusercontent.com/WaterNS/.dotfiles/master/bootstrap_posix.sh && dash ~/tmp/1.sh && rm -f ~/tmp/1.sh'
```


## Optional follow-up

1. Add an SSH public key to the GitHub account:

```
pubkey WaterNS
```

2. [Optional] Update local repo with SSH remote:
```
cd ~/.dotfiles && git remote set-url origin git@github.com:WaterNS/.dotfiles.git
```

## a-Shell behavior (iOS/iPadOS):

For Apple Shortcuts that invoke yt-dlp, Python, or FFmpeg, configure the a-Shell action to run **In App**. Using `ytdl --shortcut=MODE ...` directly is independent of alias loading; supported modes are `hq`, `hq-mkv`, `hq-mp4`, `mp3`, and `raw`. Shortcut output otherwise uses a-Shell's Shortcuts working directory unless an explicit output path is supplied.

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
