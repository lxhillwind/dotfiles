#!/bin/sh

"$@"

if command -v stty >/dev/null; then
    stty sane
fi
echo
echo 'Press any key to continue...'

# NOTE -n option is not in posix standard, but it works for at least
# zsh, bash, busybox ash.
read -n 1
