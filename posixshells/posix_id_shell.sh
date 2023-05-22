#!/bin/sh

#Identify running shell
## busybox hacky solution:
whichShellRunning=$(exec 2>/dev/null; readlink "/proc/$$/exe")
case "$whichShellRunning" in
  */busybox) BUSYBOX_VERSION="$(busybox | head -1 | sed 's/.*\(v[0-9\.]*\).*/\1/')"; export BUSYBOX_VERSION;;
  #*) RUNNINGSHELLVERSION=$($SHELL --version);; #PROBLEMATIC/Not needed currently: Doesn't work with ASH
esac

if [ -n "$ZSH_VERSION" ]; then
  export RUNNINGSHELL='zsh'
  RUNNINGSHELLVERSION=$ZSH_VERSION
elif [ -n "$BASH_VERSION" ]; then
  export RUNNINGSHELL='bash'
  RUNNINGSHELLVERSION=$BASH_VERSION
elif [ -n "$BUSYBOX_VERSION" ]; then
  # Calling BusyBox in itself is sometimes destructive
  # so its often aliased to ash/sh and that can be run without exiting busybox
  if [ "$SHELL" = "/bin/ash" ]; then
    export RUNNINGSHELL='ash'
  else
    export RUNNINGSHELL="$SHELL"
  fi
  RUNNINGSHELLVERSION="via BusyBox $BUSYBOX_VERSION"
else
  if contains "$SHELL" "/sh"; then
    export RUNNINGSHELL='sh'
  else
    export RUNNINGSHELL="$SHELL"
  fi
fi
export RUNNINGSHELLVERSION;

# Identify TMUX pane
if [ -n "$TMUX_PANE" ]; then
  TMUX_PANE_INDEX=$(tmux list-panes | grep "$TMUX_PANE" | cut -d: -f1 | sed 's/%//')
  export TMUX_PANE_INDEX
  [ "$TMUX_PANE_INDEX" -eq 1 ] && export TMUX_FIRST_PANE=true
fi
[ -z "$TMUX" ] || [ "$TMUX_FIRST_PANE" ] && export NOT_SECONDARY_SESSION=true
