#!/bin/sh

if [ "$PWD" = "$HOME" ]; then
    echo 'at $HOME. exiting...'
    exit 1
fi

echo
pwd
echo
ip a | grep -w inet
echo
python -m http.server "${1:-8000}"
