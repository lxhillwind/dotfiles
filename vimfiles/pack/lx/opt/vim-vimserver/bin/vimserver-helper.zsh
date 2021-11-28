#!/usr/bin/env zsh

set -e

# server
if [ "$2" = 'listen' ]; then
    zmodload zsh/net/socket
    zsocket -l "$1"
    listen=$REPLY
    while :; do
        zsocket -a $listen
        fd=$REPLY
        {
            <&$fd
        }
    done
    exit 0
fi

# client (use stdin as raw params)
if [ $# -eq 1 ]; then
    zmodload zsh/net/socket
    zsocket "$1"
    fd=$REPLY
    >&$fd
    exit 0
fi

# client (terminal-api style)
if :; then
    zmodload zsh/net/socket
    zsocket "$1"
    fd=$REPLY
    shift
    funcname="$1"
    shift
    {
        # escape \ and "
        printf '["call", "%s", [' ${${funcname//\\/\\\\}//\"/\\\"}
        for ((i=1; i <= $#; i++)); do
            if [[ $i -ne 1 ]]; then
                printf ', '
            fi
            printf '"%s"' ${${@[i]//\\/\\\\}//\"/\\\"}
        done
        printf ']'
        if [[ -n "$VIMSERVER_CLIENT_PID" ]]; then
            printf ', "%s"' "${${VIMSERVER_CLIENT_PID//\\/\\\\}//\"/\\\"}"
        fi
        printf ', "%s"' "${${TTY//\\/\\\\}//\"/\\\"}"
        printf ']\n'
    } >&$fd
    exit 0
fi
