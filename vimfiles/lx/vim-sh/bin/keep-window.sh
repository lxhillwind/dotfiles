#!/bin/sh

"$@"

stty sane
echo
echo 'Press any key to continue...'

# NOTE -n option is not in posix standard, but it works for at least
# zsh, bash, busybox ash.
read -n 1
