vim9script

setl tw=78

# function
nnoremap <buffer> <Space>;c <ScriptCmd>MarkdownToggleTaskStatus()<CR>
nnoremap <buffer> gO <ScriptCmd>ShowToc()<CR>

def MarkdownToggleTaskStatus() # {{{
    const lineno = line('.')
    var line = getline(lineno)
    if line =~ '\v^\s*- \[X\] '
        line = substitute(line, '\v(^\s*- )@<=\[X\] ', '', '')
    elseif line =~ '\v^\s*- \[ \] '
        line = substitute(line, '\v(^\s*- \[)@<= ', 'X', '')
    elseif line =~ '\v^\s*- '
        line = substitute(line, '\v(^\s*-)@<= ', ' [ ] ', '')
    endif
    setline(lineno, line)
enddef # }}}

def ShowToc() # {{{
    var bufname = bufname('%')
    var info = getloclist(0, {'winid': 1})
    if !empty(info) && getwinvar(info.winid, 'qf_toc') ==# bufname
        lopen
        return
    endif

    var toc = []
    var lnum = 1
    var last_line = line('$') - 1
    # TODO ignore toc in fenced code
    # TODO nested toc?
    while lnum > 0 && lnum < last_line
        var text = getline(lnum)
        if text =~# '\v^#{1,} .+'
            add(toc, {'bufnr': bufnr('%'), 'lnum': lnum, 'text': text})
        endif
        lnum = nextnonblank(lnum + 1)
    endwhile

    setloclist(0, toc, ' ')
    setloclist(0, [], 'a', {'title': 'Markdown TOC'})
    lopen
    w:qf_toc = bufname
enddef # }}}
