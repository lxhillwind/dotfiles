# vim:fdm=marker
# path: ~/.zshrc

source ~/.config/misc/env.sh

alias o=xdg-open

export MPD_HOST=~/.mpd/socket

mpc-fzf()
{
    mpc playlist | awk 'begin { i=0 } { print(++i, ")", $0) }' | fzf | awk '{ print $1 }' | xargs -r mpc play
}

# capture tmux output to put in vim (easy jump to file of rg / grep output)
# optional $1: start line from visible top; default: 1000
if [ -n "$TMUX" ]; then
sv()
{
    tmux capture -e -p -S -${1:-0} -E $(tmux display -p "#{cursor_y}") | vim - -c 'set buftype=nofile noswapfile | %Terminal cat'
}

# capture tmux output to fzf (for cd)
# optional $1: start line from visible top; default: 1
# TODO use vim's jump feature.
sc()
{
    result=$(tmux capture -p -S -${1:-1} -E $(tmux display -p "#{cursor_y}") | fzf)
    if [ -d "$result" ]; then
        cd "$result"
    else
        printf "\x1b[31mfile not reachable:\x1b[0m $result\n" >&2
    fi
}
fi

if [ -n "$DTACH_SESSION_FILE" ]; then
sv()
{
    dtach-session $1 | vim - -c 'set buftype=nofile noswapfile | %Terminal cat'
}
fi

if [ -n "$VIMSERVER_BIN" ]; then
sv()
{
    "$VIMSERVER_BIN" "$VIMSERVER_ID" Tapi_shell_sv_helper
}
fi

# x11 / wayland env {{{
if [ -z "$WAYLAND_DISPLAY" ] && [ -z "$DISPLAY" ]; then
    _common() {
        export GTK_IM_MODULE=fcitx
        export QT_IM_MODULE=fcitx
        export XMODIFIERS=@im=fcitx
        # start mpd (without daemon) in background, so it works with bwrap's
        # --die-with-parent param.
        # start mpd via xdg autostart.
        #[ -s ~/.mpd/pid ] || mpd --no-daemon &!
    }
    _start-wayland() {
        XDG_SESSION_TYPE=wayland dbus-run-session startplasma-wayland
    }
    _s() {
        _common
        export QT_QPA_PLATFORM=wayland
        export SDL_VIDEODRIVER=wayland
        _start-wayland
    }

    x() {
        # plasma has its own value.
        export QT_QPA_PLATFORMTHEME=qt5ct
        _common
        startx
    }

    s() {
        (_s)
    }
fi
# }}}

# wayland as sandbox {{{
if [ -z "$WAYLAND_DISPLAY" ] && [ -z "$DISPLAY" ]; then
    # TODO network is slow;
    # TODO pcmanfm-qt does not work;
    # TODO fcitx5;
    s-sandbox() {

    local args=(
    --clearenv
    --setenv XDG_RUNTIME_DIR "$XDG_RUNTIME_DIR"
    --setenv HOME "$HOME" --setenv USER "$USER"

    # sandbox
    --ro-bind / /
    --perms 0700 --tmpfs "$XDG_RUNTIME_DIR"
    --perms 0777 --tmpfs /tmp
    --tmpfs ~

    # sound (pipewire)
    --ro-bind /run/user/"$UID"/pipewire-0 /run/user/"$UID"/pipewire-0
    # sound (pulseaudio); use it even if using pipewire-pulse.
    --ro-bind /run/user/"$UID"/pulse /run/user/"$UID"/pulse

    # special dir
    --bind /sys /sys --proc /proc --dev-bind /dev /dev
    --unshare-all --share-net

    # qt
    --setenv QT_QPA_PLATFORM wayland

    # qutebrowser
    --ro-bind ~/.config/qutebrowser/config.py ~/.config/qutebrowser/config.py
    --ro-bind ~/.config/qutebrowser/rc/ ~/.config/qutebrowser/rc/
    --ro-bind ~/.config/qutebrowser/userscripts/ ~/.config/qutebrowser/userscripts/
    --ro-bind ~/.config/qutebrowser/greasemonkey/ ~/.config/qutebrowser/greasemonkey/

    # qemu
    --ro-bind ~/bin/vm-list ~/bin/vm-list
    --ro-bind ~/bin/vm-start ~/bin/vm-start
    --ro-bind ~/bin/launch-qemu.py ~/bin/launch-qemu.py
    --bind ~/qemu/ ~/qemu/
    --ro-bind ~/qemu/config.yml ~/qemu/config.yml

    # start compositor
    --ro-bind ~/.config/sway ~/.config/sway
    sway
)

bwrap "${args[@]}"
}
fi
# }}}

# tmux sandbox
if [ -z "$TMUX" ]; then
    :
    # cmd (works, but tweak needed):
    # bwrap --ro-bind / / --tmpfs /tmp --tmpfs ~ --ro-bind ~/.config/tmux ~/.config/tmux --dev /dev --proc /proc --clearenv --setenv TERM "$TERM" --unshare-all --share-net tmux
fi

alias pq='proxychains -q'
