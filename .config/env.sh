#!/usr/bin/env false

# # Description {{{
# shell env | rc file.
#
# # Usage
# source it, with shell's builtin command `source` or `.`.
#
# To use it in busybox ash (or other strict POSIX shell),
# just set environment variable `ENV` to point to this file.
# (`man 1p sh` for details)
#
# # Compatibility
# This file is compatible with POSIX shell
# (it will return only if it meets feature which is not available).
#
# If `ls` alias does not work (BSD ls, for example),
# just unalias / re-alias it after source this file. }}}

# env {{{
export EDITOR=vim

case "$PATH" in
    /usr/bin:*|*:/usr/bin:*) ;;
    *) export PATH=/usr/bin:$PATH ;;
esac

case "$PATH" in
    ~/bin:*|*:~/bin:*) ;;
    *) export PATH=~/bin:$PATH ;;
esac

case "$PYTHONPATH" in
    ~/lib/python:*|*:~/lib/python) ;;
    *) export PYTHONPATH=~/lib/python:$PYTHONPATH ;;
esac

# }}}
case "$-" in
    *i*) ;;
    *) return 2>/dev/null || exit 1 ;;
esac

# rc {{{
# fzf and cd
if { command -v local && command -v fd && command -v fzf; } >/dev/null; then
    _f_cd()
    {
        if [ $# -eq 0 ]; then
            \cd ~
            return
        fi
        if [ $# -eq 1 ]; then
            local p=$1
        else
            local p=$(fd "$@" | fzf)
        fi
        if [ -e "$p" ] && ! [ -d "$p" ]; then
            p=${p%/*}
        fi
        \cd "$p"
    }
    alias cd=_f_cd
fi

# colorful man
man() {
    # openSUSE requires MAN_POSIXLY_CORRECT to display without prompt.
    # openSUSE requires GROFF_NO_SGR to display color (but why?).
    # ref: https://forums.opensuse.org/showthread.php/414983-Color-Man-Pages/page2?s=7bff9fc804859ecde549a354ecaacea0
    env \
    MAN_POSIXLY_CORRECT=1 \
    GROFF_NO_SGR=yes \
    LANG=en_US.UTF-8 \
    PAGER="sh -c 'sed -E \"s/[—−‐]/-/g\" | less'" \
    LESS_TERMCAP_md=$'\e[01;31m' \
    LESS_TERMCAP_me=$'\e[0m' \
    LESS_TERMCAP_se=$'\e[0m' \
    LESS_TERMCAP_so=$'\e[01;44;33m' \
    LESS_TERMCAP_ue=$'\e[0m' \
    LESS_TERMCAP_us=$'\e[01;32m' \
    man "$@"
}

# alias & functions
alias exa='exa -F --color=always'
alias less='less -R'
alias diff='diff --color=auto'
alias grep='grep --color=auto'
alias ls='ls --color=auto -F'
# }}}

# busybox can only set rc by $ENV, so source local config if exists.
if [ -n "$ENV" ] && [ -n "$SH_RC_LOCAL" ] && [ -r "$SH_RC_LOCAL" ]; then
    source "$SH_RC_LOCAL"
fi

# simple PS1 (zsh re-defines it)
PS1='\[\e[1m\]\[\e[31m\]$(x=$?; test $x -eq 0 || echo "[$x] ")\[\e[32m\][$(date +%Y-%m-%d\ %H:%M:%S)] \[\e[33m\]\w'$'\n''\[\e[32m\]\$\[\e[0m\] '

# load vimserver related setting after PS1.
# see lxhillwind/vim-vimserver
if [ -f "$VIMSERVER_SH_SOURCE" ]; then
    source "$VIMSERVER_SH_SOURCE"
fi

# Following code may cause syntax error in strict POSIX shell
# (like array construction), so return early.
if ! command -v zstyle >/dev/null; then
    return
fi
# {{{ zshrc

# Command completion
typeset -U fpath
fpath=(~/.zsh_comp $fpath[@])
autoload -Uz compinit promptinit

# arrow-key driven autocompletion
zstyle ':completion:*' menu select

# cd
export DIRSTACKSIZE=16
setopt auto_pushd pushd_ignore_dups pushd_minus

# vi insert mode {{{2
bindkey -v \^A beginning-of-line
bindkey -v \^E end-of-line
bindkey -v \^F forward-char
bindkey -v \^B backward-char
bindkey -v \^N down-line-or-history
bindkey -v \^P up-line-or-history
bindkey -v \^D delete-char-or-list
bindkey -v \^H backward-delete-char
bindkey -v \^U backward-kill-line
bindkey -v \^K kill-line
bindkey -v \^W backward-kill-word
bindkey -v \^Y yank

zle-keymap-select()
{
    case $KEYMAP in
        vicmd) print -n '\e[1 q' ;;  # block cursor
        viins|main) print -n '\e[5 q' ;;  # less visible cursor
    esac
}
zle -N zle-keymap-select

# TODO load on `set -o emacs`
_fix_cursor()
{
    print -n '\e[1 q'
}
# }}}2

# readline keybindings
bindkey -e
bindkey \^U backward-kill-line

# '#' at begin-of-line as comment
setopt interactivecomments

# simple PS1
PS1='%B%(?..%F{red}[%?] )%F{green}[%D{%Y-%m-%d %H:%M:%S}] %F{yellow}%~'$'\n''%F{green}%#%f%b '

# edit command line
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey \^x\^e edit-command-line

compinit

# }}}

# vim:ft=zsh fdm=marker
