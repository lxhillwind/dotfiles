#!/bin/sh

# requirements: jq, socat

set -e

# server
if [ "$2" = 'listen' ]; then
    exec socat "unix-l:${1},fork" stdout
fi

# client (use stdin as raw params)
if [ $# -eq 1 ]; then
    exec socat stdin "unix-connect:${1}"
fi

# client (terminal-api style)
# $1 is $VIMSERVER_ID, which is not used.
shift
funcname="$1"
shift
printf '\x1b]51;%s\x07' \
    "$(jq --indent 0 -n \
    --arg func "$funcname" --args \
    '["call", $func, $ARGS.positional]' \
    "$@")"
