if [ -n "$VIM" ] && [ -n "$VIMSERVER_ID" ] && { \
    [ -x "$VIMSERVER_BIN" ] || command -v "$VIMSERVER_BIN" >/dev/null; }; then
    _vimserver_in_use=1
else
    _vimserver_in_use=
fi

# var used in _vimserver_ps1 & _vimserver()
_vimserver_cd=

_vimserver_ps1='$(
    if [ "$PWD" != "$_vimserver_cd" ]; then
        _vimserver_cd="$PWD"
        "$VIMSERVER_BIN" "$VIMSERVER_ID" Tapi_cd "$_vimserver_cd"
    fi
)'

_vimserver()
{
    if [ "$PWD" != "$_vimserver_cd" ]; then
        _vimserver_cd="$PWD"
        "$VIMSERVER_BIN" "$VIMSERVER_ID" Tapi_cd "$_vimserver_cd"
    fi
}

if [ -n "$_vimserver_in_use" ]; then
    # set env VIMSERVER_CLIENT_PID
    if [ -z "$VIMSERVER_CLIENT_PID" ]; then
        export VIMSERVER_CLIENT_PID=$$

        # msys2: get WINPID from ps output.
        # `/` will be translated to `C:/msys64` correctly, don't know why.
        #
        # git-bash (g:win32_unix_sh_path):
        # use <gitdir>/usr/bin/bash instead of <gitdir>/bin/bash,
        # so that child pid of vim will be set in bash correctly.
        if [ -f /msys2.exe ] || [ -f /git-bash.exe ] || [ -d /cygdrive ]; then
            export VIMSERVER_CLIENT_PID=$(ps -p $$ | awk '{ print $4 }' | tail -n 1)
        fi
    fi

    # PS1 for bash, busybox, etc.
    if ! command -v zstyle >/dev/null; then
        if printf %s "$PS1" | grep _vimserver_cd >/dev/null; then
            :
        else
            PS1="${_vimserver_ps1}${PS1}"
        fi
    fi
fi

if ! command -v zstyle >/dev/null; then
    # return here to avoid syntax error.
    return
fi

# zsh
if [ -n "$_vimserver_in_use" ]; then
    if printf %s "$precmd_functions" | grep _vimserver >/dev/null; then
        :
    else
        precmd_functions+=(_vimserver)
    fi
fi
