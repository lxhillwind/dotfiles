if has('unix')
    let s:vimrc = expand('~/.vimrc')
    let s:vimfiles = expand('~/.vim')
else
    if expand('<sfile>:p') == expand('$VIM/sysinit.vim')
        " Windows; portable; use "$VIM/sysinit.vim" as config file
        let s:vimrc = expand('$VIM/_vimrc')
        let s:vimfiles = expand('$VIM/vimfiles')
    else
        let s:vimrc = expand('~/_vimrc')
        let s:vimfiles = expand('~/vimfiles')
    endif
endif
let &rtp .= ',' . s:vimfiles
let &packpath = &rtp
if filereadable(s:vimrc)
    exe 'source' s:vimrc
endif
