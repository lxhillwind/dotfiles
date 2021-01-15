" use g:vimrc to store functions which can be accessed outside of vimrc.
if !exists('g:vimrc')
    let g:vimrc = {}
endif

" echo msg with error highlight.
function! g:vimrc.echoerr(msg) " {{{
    echohl ErrorMsg
    echon a:msg
    echohl None
endfunction
" }}}

" return cwd. (works if acd / noacd)
function! g:vimrc.getcwd() " {{{
    let path = expand('%:p:h')
    if empty(path) || &buftype == 'terminal'
        let path = getcwd()
    endif
    return path
endfunction
" }}}

" return project dir (or '' if .git not found).
" {{{
function! g:vimrc.get_project_dir()
    let path = g:vimrc.getcwd()
    while 1
        if isdirectory(path . '/.git')
            return path
        endif
        let parent = fnamemodify(path, ':h')
        if path == parent
            return ''
        endif
        let path = parent
    endwhile
endfunction
" }}}

" exchange data between system clipboard and vim @"
" Usage:
"   call g:vimrc.clipboard_copy("cmd") to copy from @" to system clipboard;
"   call g:vimrc.clipboard_paste("cmd") to paste to @" from system clipboard;
"   try to use mappings.
" Note: passing "" as function argument to use default system clipboard.
" {{{
function! g:vimrc.clipboard_copy(cmd)
    if empty(a:cmd)
        if has('clipboard')
            let @+ = @"
            return
        endif
        if executable('pbcopy')
            let l:cmd = 'pbcopy'
        elseif executable('xsel')
            let l:cmd = 'xsel -ib'
        elseif exists('$TMUX')
            let l:cmd = 'tmux loadb -'
        else
            return
        endif
        call system(l:cmd, @")
    else
        call system(a:cmd, @")
    endif
endfunction

function! g:vimrc.clipboard_paste(cmd)
    if empty(a:cmd)
        if has('clipboard')
            let @" = @+
            return
        endif
        if executable('pbpaste')
            let l:cmd = 'pbpaste'
        elseif executable('xsel')
            let l:cmd = 'xsel -ob'
        elseif exists('$TMUX')
            let l:cmd = 'tmux saveb -'
        else
            return
        endif
        let @" = system(l:cmd)
    else
        let @" = system(a:cmd)
    endif
endfunction
" }}}

" gx related {{{
function! g:vimrc.gx_cmd(s)
    if executable('qutebrowser') && !filereadable(a:s)
        return ['qutebrowser', a:s]
    elseif executable('xdg-open')
        return ['xdg-open', a:s]
    elseif executable('open')
        return ['open', a:s]
    elseif has('win32')
        " TODO fix open for win32
        return ['cmd', '/c', 'start', a:s]
    else
        call g:vimrc.echoerr('do not know how to open')
        return
    endif
endfunction

function! g:vimrc.open(s)
    let open_cmd = g:vimrc.gx_cmd(a:s)
    if empty(open_cmd)
        return
    endif
    if has('nvim')
        call jobstart(open_cmd, {'detach': 1})
    else
        call job_start(open_cmd, {'stoponexit': ''})
    endif
endfunction
" }}}

" vim:fdm=marker
