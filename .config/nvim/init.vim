for s:i in ['~/.vimrc', '~/_vimrc']
    if filereadable(expand(s:i))
        exe 'so' s:i
        break
    endif
endfor

if !get(g:, 'vimrc#loaded')
    so ~/lib/rc.vim
endif
