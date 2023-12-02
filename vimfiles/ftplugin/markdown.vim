vim9script

setl tw=78

# checkbox
hi link CheckboxUnchecked Type
hi link CheckboxChecked Comment
syn match CheckboxUnchecked '\v^\s*- \[ \] '
syn match CheckboxChecked '\v^\s*- \[X\] '

# markdown ``` `` ``` hl fix. TODO: not work
#syn region markdownCode matchgroup=markdownCodeDelimiter start=/.\+\zs```/ end=/.\+\zs```/

# Q: / T: / L: highlight TODO: not work
syntax region markdownQuestion start='\v<Q:' end='\v(\n(^((\s*-)|([0-9]+\.)) .+|)\n)@=' | hi link markdownQuestion Error
syntax region markdownToday start='\v<T:' end='\v(\n(^((\s*-)|([0-9]+\.)) .+|)\n)@=' | hi link markdownToday TODO
syntax region markdownLowPriority start='\v<L:' end='\v(\n(^((\s*-)|([0-9]+\.)) .+|)\n)@=' | hi link markdownLowPriority Comment

# strikethrough TODO: not work
hi def StrikeoutColor ctermbg=darkblue ctermfg=black guibg=darkblue guifg=blue cterm=strikethrough gui=strikethrough
syntax match StrikeoutMatch /\~\~.*\~\~/
hi link StrikeoutMatch StrikeoutColor

# TODO
syntax match Todo /\v(^|\W)\zsTODO\ze(\W|$)/

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
