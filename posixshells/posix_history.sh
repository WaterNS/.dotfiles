#!/bin/sh

# set +o history # Enabling will show ZERO history, not even in current session

# SH: delete history files
rm "$HISTFILE" >/dev/null 2>&1
unset HISTFILE # On exit, will not write history file
rm "$HOME/.sh_history" >/dev/null 2>&1

# ASH: delete history files
# rm "$HISTFILE" >/dev/null 2>&1
# unset HISTFILE # On exit, will not write history file
rm "$HOME/.ash_history" >/dev/null 2>&1
if [ -f "$HOME/.ash_history" ]; then
  echo "" > "$HOME/.ash_history"
fi

# BASH: delete history files/sessions
rm -f "$HOME/.bash_history" >/dev/null 2>&1
rm -rf "$HOME/.bash_sessions" >/dev/null 2>&1

# ZSH: delete history files
rm "$HOME/.zsh_history" >/dev/null 2>&1
find "$HOME" -maxdepth 1 -type f -name '.*zcompdump*' -delete # cache is relocated to ZSH cache folder
export SAVEHIST=0
export HISTSIZE=30 # Keep temporary session history
rm -rf "$HOME/.zsh_sessions" >/dev/null 2>&1
export SHELL_SESSIONS_DISABLE=1 # Don't save/restore sessions on exit

# LESS: history delete
export LESSHISTFILE=/dev/null
rm -f "$HOME/.lesshst" >/dev/null 2>&1

# Remove .rnd (seed generated by OpenSSL/PGP)
rm -f "$HOME/.rnd" >/dev/null 2>&1

# VIM: Remove history
rm -f "$HOME/.viminfo" >/dev/null 2>&1
rm -f "$HOME/.vim/.netrwhist" >/dev/null 2>&1

#SQLite: Remove history
rm -f "$HOME/.sqlite_history" >/dev/null 2>&1

#Python: Remove history
rm -f "$HOME/.python_history" >/dev/null 2>&1

# #TMUX: Clear rollback - Likely causes issue on reload
# if [ -n "$TMUX" ]; then
#   tmux clear-history #clears rollback
# fi
