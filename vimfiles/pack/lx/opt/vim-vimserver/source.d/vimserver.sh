if [ -n "$VIM" ] && [ -n "$VIMSERVER_ID" ] && { \
    [ -x "$VIMSERVER_BIN" ] || command -v "$VIMSERVER_BIN" >/dev/null; }; then
    :
else
    return
fi

if [ -f /msys2.exe ] || [ -f /git-bash.exe ] || [ -d /cygdrive ]; then
    _vimserver_is_cygwin=1
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

# set env VIMSERVER_CLIENT_PID
if [ -z "$VIMSERVER_CLIENT_PID" ]; then
    export VIMSERVER_CLIENT_PID=$$

    # msys2: get WINPID from ps output.
    # `/` will be translated to `C:/msys64` correctly, don't know why.
    #
    # git-bash (g:win32_unix_sh_path):
    # use <gitdir>/usr/bin/bash instead of <gitdir>/bin/bash,
    # so that child pid of vim will be set in bash correctly.
    if [ -n "$_vimserver_is_cygwin" ]; then
        export VIMSERVER_CLIENT_PID=$(ps -p $$ | awk '{ print $4 }' | tail -n 1)
    fi
fi

# adjust $PATH for cygwin (git for windows), to make win32 vim win.
if [ -n "$_vimserver_is_cygwin" ] && command -v which >/dev/null; then
    _vimserver_win32_vim_path=$({ which -a vim | grep -E '[/\]vim[/\]vim(|.exe)$'; } 2>/dev/null || true)
    if [ -x "$_vimserver_win32_vim_path" ] && [ "$(command -v vim)" = "/usr/bin/vim" ]; then
        _vimserver_win32_vim_path="${_vimserver_win32_vim_path%.exe}"
        _vimserver_win32_vim_path="${_vimserver_win32_vim_path%vim}"
        PATH="$_vimserver_win32_vim_path:$PATH"
    fi
    unset _vimserver_win32_vim_path
fi


# PS1 for bash, busybox, etc.
if ! command -v zstyle >/dev/null; then
    if printf %s "$PS1" | grep _vimserver_cd >/dev/null; then
        :
    else
        PS1="${PS1}${_vimserver_ps1}"
    fi
fi

if [ -n "$_vimserver_is_cygwin" ]; then
    unset _vimserver_is_cygwin
fi

if ! command -v zstyle >/dev/null; then
    # return here to avoid syntax error.
    return
fi

# zsh
if printf %s "$precmd_functions" | grep _vimserver >/dev/null; then
    :
else
    precmd_functions+=(_vimserver)
fi
