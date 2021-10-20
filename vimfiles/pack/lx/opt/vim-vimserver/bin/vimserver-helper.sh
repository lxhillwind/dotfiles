#!/bin/sh

# requirements: zsh or (jq, socat)

set -e

if command -v zmodload >/dev/null; then
    zshell=1
else
    zshell=
fi

# TODO avoid recursive call.
if [ -z "$zshell" ] && command -v zsh >/dev/null; then
    exec zsh "$0" "$@"
fi

# server
if [ "$2" = 'listen' ]; then
    if [ -n "$zshell" ]; then
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
    else
        exec socat "unix-l:${1},fork" stdout
    fi
fi

# client (use stdin as raw params)
if [ $# -eq 1 ]; then
    if [ -n "$zshell" ]; then
        zmodload zsh/net/socket
        zsocket "$1"
        fd=$REPLY
        >&$fd
        exit 0
    else
        exec socat stdin "unix-connect:${1}"
    fi
fi

# client (terminal-api style)
if :; then
    if [ -n "$zshell" ]; then
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
                printf ', "%s"' ${${VIMSERVER_CLIENT_PID//\\/\\\\}//\"/\\\"}
            fi
            printf ']\n'
        } >&$fd
        exit 0
    else
        server_id="$1"
        shift
        funcname="$1"
        shift
        # use & since socat is slow.
        printf '%s\n' \
            "$(jq --indent 0 -n \
            --arg func "$funcname" --arg id "$VIMSERVER_CLIENT_PID" --args \
            '["call", $func, $ARGS.positional] + [$id] | map(select(.|length > 0))' \
            "$@")" | exec socat stdin "unix-connect:$server_id" &
    fi
fi
