#!/bin/zsh

## .zshenv: Non-interactive shell
### .zshenv → [.zprofile if login] → [.zshrc if interactive] → [.zlogin if login] → [.zlogout sometimes]

# Don't save/restore sessions on exit - Non-interactive sessions tend to throw warnings without this
export SHELL_SESSIONS_DISABLE=1;
