export EDITOR=vim

# this may not work as expected if rhs is a substring.
if ! [[ $PATH =~ ~/bin: ]]; then
    export PATH=~/bin:$PATH
fi
if ! [[ $PYTHONPATH =~ ~/lib: ]]; then
    export PYTHONPATH=~/lib:$PYTHONPATH
fi

if [[ $OSTYPE =~ linux ]]; then
    # fix pycharm in wayland:
    # https://github.com/swaywm/sway/wiki#issues-with-java-applications
    # source: https://github.com/swaywm/sway/issues/595
    export _JAVA_AWT_WM_NONREPARENTING=1
    export XDG_SESSION_TYPE=wayland
    # https://github.com/swaywm/sway/wiki#disabling-client-side-qt-decorations
    export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
    export QT_STYLE_OVERRIDE=kvantum
    # also from sway wiki
    export SDL_VIDEODRIVER=wayland
fi
