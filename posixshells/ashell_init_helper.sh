#!/bin/sh

# This doesn't work in a-Shell because a-Shell doesn't currently support scripts or even `if`

if [ "$TERM_PROGRAM" = "a-Shell" ]; then
  pkg install "basename"
  pkg install "column"
  pkg install "cut"
  pkg install "dirname"
  pkg install "expand"
  pkg install "false"
  pkg install "fold"
  pkg install "getopt"
  pkg install "join"
  pkg install "mktemp"
  pkg install "printf"
  pkg install "split"
  pkg install "which"
  pkg install "xz"
  pkg install "lzmadec"
  pkg install "zip"
  pkg install "git"
fi
