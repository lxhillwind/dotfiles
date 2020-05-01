# Command completion
typeset -U fpath
fpath=(~/.zsh_comp $fpath[@])
autoload -Uz compinit promptinit

# arrow-key driven autocompletion
zstyle ':completion:*' menu select

# cd
export DIRSTACKSIZE=16
setopt auto_pushd pushd_ignore_dups pushd_minus

# readline keybindings
bindkey -e
bindkey \^U backward-kill-line

# '#' at begin-of-line as comment
setopt interactivecomments

# simple PS1
PS1='%B%(?..%F{red}[%?] )%F{green}[%D{%Y-%m-%d %H:%M:%S}] %F{yellow}%~'$'\n''%F{green}%#%f%b '

# window title
precmd() { printf "\e]1;$USER@$HOST\a"; }

compinit

man() {
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

if command -v lua &>/dev/null; then
    eval "$(lua $HOME/lib/foreign/z.lua --init zsh)"
fi
