#!/bin/sh
# Source me, don't execute me.
# Return 0 -> caller should no-op the rest of its rc.
# Return 1 -> caller should continue loading normally.

# 1) Non-interactive? (defensive; .bashrc/.zshrc are usually interactive)
case $- in *i*) : ;; *) return 0 ;; esac

# 2) Fast path: Codex already marked the env
if [ "${CODEX_CLI:-}" = "1" ] \
   || [ -n "${CODEX_MANAGED_BY_NPM+x}" ] \
   || [ -n "${CODEX_SANDBOX_NETWORK_DISABLED+x}" ]; then
  return 0
fi

# 3) Slow path: look for Codex in the ancestor chain (macOS/Linux)
_codex_ancestor_present() {
  # POSIX sh; macOS BSD ps & GNU ps compatible
  pidCheck="${2:-$$}"
  hopsCount=0
  max_hops_count=25

  # helper: get full command line without header; try args then command
  _ps_cmd() {
    ps -p "$1" -o args= 2>/dev/null || ps -p "$1" -o command= 2>/dev/null
  }

  while :; do
    ppidCheck="$(ps -p "$pidCheck" -o ppid= 2>/dev/null | tr -d ' ')"
    [ -z "$ppidCheck" ] && return 1
    [ "$ppidCheck" -le 1 ] && return 1

    cmdCheck="$(_ps_cmd "$ppidCheck")"
    case $cmdCheck in
      *[Cc][Oo][Dd][Ee][Xx]*|*codex-cli*|*codex\ cli*|*openai-codex*)
        return 0
        ;;
    esac

    pidCheck="$ppidCheck"
    hopsCount=$((hopsCount + 1))
    [ "$hopsCount" -gt "$max_hops_count" ] && return 1
  done
}

if _codex_ancestor_present; then
  export CODEX_CLI=1
  return 0
fi

# Otherwise, proceed with normal rc loading
return 1
