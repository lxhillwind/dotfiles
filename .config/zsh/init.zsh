export EDITOR=vim

# this may not work as expected if rhs is a substring.
if ! [[ $PATH =~ ~/bin: ]]; then
    export PATH=~/bin:$PATH
fi
if ! [[ $PYTHONPATH =~ ~/lib/python: ]]; then
    export PYTHONPATH=~/lib/python:$PYTHONPATH
fi

if ! [[ $- =~ i ]]; then
    return
fi

#
# zshrc
#

# Command completion
typeset -U fpath
fpath=(~/.zsh_comp $fpath[@])
autoload -Uz compinit promptinit

# arrow-key driven autocompletion
zstyle ':completion:*' menu select

# cd
export DIRSTACKSIZE=16
setopt auto_pushd pushd_ignore_dups pushd_minus

# vi insert mode
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

# readline keybindings
bindkey -e
bindkey \^U backward-kill-line

# '#' at begin-of-line as comment
setopt interactivecomments

# simple PS1
PS1='%B%(?..%F{red}[%?] )%F{green}[%D{%Y-%m-%d %H:%M:%S}] %F{yellow}%~'$'\n''%F{green}%#%f%b '

compinit

man() {
    PAGER="sh -c 'sed -E s/[—−‐]/-/g | less'" \
    LESS_TERMCAP_md=$'\e[01;31m' \
    LESS_TERMCAP_me=$'\e[0m' \
    LESS_TERMCAP_se=$'\e[0m' \
    LESS_TERMCAP_so=$'\e[01;44;33m' \
    LESS_TERMCAP_ue=$'\e[0m' \
    LESS_TERMCAP_us=$'\e[01;32m' \
    command man "$@"
}

# alias & functions
alias exa='exa -F --color=always'
alias less='less -R'
alias diff='diff --color=auto'
alias grep='grep --color=auto'
alias ls='ls --color=auto -F'
