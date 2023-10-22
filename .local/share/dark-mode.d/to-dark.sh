#!/bin/sh

# depends on:
# - darkman
# - xfce-theme-manager
# - arc-gtk-theme
# - papirus-icon-theme
#
# optional dep:
# - xfce4-terminal
# - git-delta

case "${0##*/}" in
    *dark*)
        theme=dark ;;
    *light*)
        theme=light ;;
    *)
        echo 'unexpected basename!' >&2
        exit 1 ;;
esac

# xfce-theme-manager: set --panels=0 to avoid reset other panels' size.
#   (may not work; try to set in xfce-theme-manager -> Advanced -> "Panel Size")
# xfce-theme-manager: set icons in a separate line, since it won't work if set with other options.
if [ "$theme" = dark ]; then
    xfce-theme-manager --theme=Arc-Dark-solid --wmborder=Arc-Dark-solid --controls=Arc-Dark-solid --panel=0
else
    xfce-theme-manager --theme=Arc-Lighter-solid --wmborder=Arc-Lighter-solid --controls=Arc-Lighter-solid --panel=0
fi
xfce-theme-manager --icons=Papirus

# git-delta {{{
if [ "$theme" = dark ]; then
    git config --global delta.light false
else
    git config --global delta.light true
fi
# }}}

# xfce4-terminal (>=1.1.0), using xfconf {{{
#
# How to get color config for light / dark theme?
# Switch theme manually, and inspect config.
if [ -n "$(xfconf-query -c xfce4-terminal -l 2>/dev/null)" ]; then
    if [ "$theme" = dark ]; then
        xfconf-query -c xfce4-terminal -p /color-foreground -r
        xfconf-query -c xfce4-terminal -p /color-background -r
        xfconf-query -c xfce4-terminal -p /color-palette -s "#000000;#cc0000;#4e9a06;#c4a000;#3465a4;#75507b;#06989a;#d3d7cf;#555753;#ef2929;#8ae234;#fce94f;#739fcf;#ad7fa8;#34e2e2;#eeeeec"
    else
        xfconf-query -c xfce4-terminal -p /color-foreground -s "#000000" -n -t string
        xfconf-query -c xfce4-terminal -p /color-background -s "#ffffff" -n -t string
        xfconf-query -c xfce4-terminal -p /color-palette -s "rgb(0,0,0);rgb(205,0,0);rgb(0,205,0);rgb(205,205,0);rgb(0,0,205);rgb(205,0,205);rgb(0,205,205);rgb(229,229,229);rgb(127,127,127);rgb(255,0,0);rgb(36,179,36);rgb(191,191,31);rgb(92,92,255);rgb(255,0,255);rgb(0,255,255);rgb(255,255,255)"
    fi
fi
# }}}

# xfce4-terminal (<1.1.0), using config file {{{
# config path:
# ~/.config/xfce4/terminal/terminalrc
config_path=~/.config/xfce4/terminal/terminalrc
old_config=$(grep -Ev '^Color' "$config_path" 2>/dev/null)
if [ -e "$config_path" ] && [ -n "$old_config" ]; then
    {
        printf %s "$old_config"
        echo
        if [ "$theme" = dark ]; then
            printf '%s\n' 'ColorPalette=#000000;#cc0000;#4e9a06;#c4a000;#3465a4;#75507b;#06989a;#d3d7cf;#555753;#ef2929;#8ae234;#fce94f;#739fcf;#ad7fa8;#34e2e2;#eeeeec'
        else
            printf '%s\n' 'ColorForeground=#000000'
            printf '%s\n' 'ColorBackground=#ffffff'
            printf '%s\n' 'ColorPalette=rgb(0,0,0);rgb(205,0,0);rgb(0,205,0);rgb(205,205,0);rgb(0,0,205);rgb(205,0,205);rgb(0,205,205);rgb(229,229,229);rgb(127,127,127);rgb(255,0,0);rgb(36,179,36);rgb(191,191,31);rgb(92,92,255);rgb(255,0,255);rgb(0,255,255);rgb(255,255,255)'
        fi
    } > "$config_path"
fi
# }}}

# vim / gvim {{{
pgrep -x 'vim|gvim' | xargs -r kill -SIGUSR1
# }}}
