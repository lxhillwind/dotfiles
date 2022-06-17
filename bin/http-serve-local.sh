#!/bin/sh

if [ "$PWD" = "$HOME" ]; then
    echo 'at $HOME. exiting...'
    exit 1
fi

echo
pwd
echo
python -m http.server --bind 127.0.0.1 "${1:-8000}"
