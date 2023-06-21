vim9script

# utility (copied from ~/vimfiles/vimrc) {{{
const is_win32 = has('win32')
const has_gui = has('gui_running') || has('mac')
|| (has('linux') && (!empty($DISPLAY) || !(empty($WAYLAND_DISPLAY))))
# }}}

# misc (filetype related) {{{1
# NOTE: "au BufNewFile,BufRead XXX setl ft=YYY" should be put in ftdetect/;
# otherwise "au FileType YYY .*" stmt won't work.
au FileType yaml setl indentkeys-=0#
au FileType zig setl fp=zig\ fmt\ --stdin
# ":h ft-sh-syntax"
g:is_posix = 1
# quickfix window {{{1
au FileType qf nnoremap <buffer> <C-n> <Cmd>cnewer<CR>
au FileType qf nnoremap <buffer> <C-p> <Cmd>colder<CR>
au FileType qf nnoremap <buffer> <C-j> <CR><C-w>p
au FileType qf nnoremap <buffer> <Space>;l <Cmd>chistory<CR>

# markdown {{{1
au FileType markdown {
    setl tw=78

    hi link CheckboxUnchecked Type
    hi link CheckboxChecked Comment
    syn match CheckboxUnchecked '\v^\s*- \[ \] '
    syn match CheckboxChecked '\v^\s*- \[X\] '
}

# markdown checkbox {{{
def MarkdownToggleTaskStatus()
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
enddef
# }}}
au FileType markdown nnoremap <buffer>
            \ <Space>;c <Cmd>call <SID>MarkdownToggleTaskStatus()<CR>

# binary file editing. (ft=binary) {{{1
# ReadBin / WriteBin impl {{{
# avoid using busybox xxd. To use busybox xxd: `sed -E 's/  .*//' | xxd -r`;
# since contents after 0x blocks are also parsed by busybox xxd.
var xxd_path = 'xxd'
# possible paths are from my vim-bin repo. (unix: $VIM/bin/xxd; win32:
# $VIM/xxd.exe)
const xxd_possible =<< eval trim END
    {$VIM}/bin/xxd
    {$VIM}/xxd.exe
END
for i in xxd_possible
    if filereadable(i)
        xxd_path = i
        break
    endif
endfor

def ReadBin(name: string)
    # we do not set 'shelltemp' option (to no); see relevant comment in
    # ~/vimfiles/vimrc.
    silent normal gg"_dG
    silent execute printf('r !%s %s', shellescape(xxd_path), shellescape(name))
    normal gg"_dd
    setl nomodified
enddef

def WriteBin(name: string)
    silent execute printf('w !%s -r > %s', shellescape(xxd_path), shellescape(name))
    if !empty(v:shell_error)
        return
    endif
    setl nomodified
    redrawstatus | echon 'written.'
enddef
# }}}

command BinaryEditThis {
    const filename = expand('%:p')
    if !filename->filereadable()
        throw 'file associated to this buffer is not readable!'
    endif
    setl ft=binary
}
au FileType binary {
    if &modified
        throw 'file is changed! unable to set filetype to binary.'
    endif
    # if we don't set BufReadCmd, then re-edit file will not load binary data,
    # while BufWriteCmd still run xxd on write;
    # this will cause serious problem.
    au BufReadCmd <buffer> ReadBin(expand('<afile>'))
    # use do... since BufReadCmd will not take effect when defined after :e.
    do BufReadCmd
    au BufWriteCmd <buffer> WriteBin(expand('<amatch>'))
}

# network (non-local) file editing {{{1
au BufReadCmd ftp://*,http://*,https://* {
    setl buftype=nofile
    execute 'Sh -r curl -sL --' shellescape(expand('<amatch>'))
    normal gg"_dd
    setl nomodifiable
}
# gx related (NOTE: key `gx` overwritten) {{{1
nnoremap <silent> gx <Cmd>call <SID>Gx('n')<CR>
vnoremap <silent> gx :<C-u>call <SID>Gx('v')<CR>

# TODO show error?
def GxOpen(...arg: list<string>)
    var text = join(getline(1, '$'), "\n")
    if empty(text)
        return
    endif
    if text->match('\v^[~$]') >= 0
        # expand ~ and $ (env).
        text = g:ExpandHead(text)
    endif
    const open_cmd = empty(arg) ? [text] : [arg[0], text]
    if empty(open_cmd)
        return
    endif
    execute 'Sh -g' open_cmd->mapnew((_, s) => shellescape(s))->join(' ')
enddef

def GxOpenGx(...arg: list<string>)
    if len(arg) == 1
        GxOpen(arg[0])
    else
        GxOpen()
    endif
    const winnr = winnr()
    wincmd p
    execute ':' .. winnr .. 'wincmd c'
enddef

def GxVim(...arg: list<string>)
    # a:1 -> cmd; a:2 -> text modifier; a:3 -> post string.
    var text = join(getline(1, '$'), "\n")
    if empty(text)
        return
    endif
    var cmd: string
    if len(arg) == 0
        cmd = text
    else
        if len(arg) >= 2 && !empty(arg[1])
            var Fun = arg[1]
            text = function(Fun)(text)
        endif
        cmd = arg[1] .. ' ' .. text
        if len(arg) >= 3 && !empty(arg[2])
            cmd ..= arg[2]
        endif
    endif
    exe cmd
enddef

def Gx(mode: string)
    var text: string
    if mode == 'v'
        var t = @"
        silent normal gvy
        text = @"
        @" = t
    else
        text = expand(get(g:, 'netrw_gx', '<cfile>'))
    endif
    exe printf('bel :%dnew', &cwh)
    # a special filetype
    setl ft=gx
    for line in split(text, "\n")
        append('$', line)
    endfor
    norm gg"_dd
enddef

def GxInit()
    setl buftype=nofile noswapfile
    setl bufhidden=hide
    if executable('qutebrowser')
        nnoremap <buffer> <Space>;s <Cmd>call <SID>GxOpen('qutebrowser')<CR>
    endif
    nnoremap <buffer> gx <Cmd>call <SID>GxOpenGx()<CR>
    if executable('qutebrowser') && has_gui
        nnoremap <buffer> gs <Cmd>call <SID>GxOpenGx('qutebrowser')<CR>
    endif
    nnoremap <buffer> <Space>;f <Cmd>call <SID>GxOpen()<CR>
    nnoremap <buffer> <Space>;v <Cmd>call <SID>GxVim("wincmd p \\|")<CR>
enddef
au FileType gx GxInit()

# Remember the positions in files with some git-specific exceptions {{{1
au BufReadPost * {
    # copied from /usr/share/vim/vim82/suse.vimrc
    if line("'\"") > 0 && line("'\"") <= line("$")
                \ && expand("%") !~ "COMMIT_EDITMSG"
                \ && expand("%") !~ "ADD_EDIT.patch"
                \ && expand("%") !~ "addp-hunk-edit.diff"
                \ && expand("%") !~ "git-rebase-todo"
        exe "normal g`\""
    endif
}

# open {file}:{line}[:{col}] automatically (provided by linter, etc). {{{1
au BufNewFile * ReopenAsFileLineCol()

def ReopenAsFileLineCol()
    var filename: string = bufname('%')
    var line: number = 0
    var column: number = 0
    if filename->filereadable()
        return
    endif
    if filename->matchstr('\v^.*\ze:[0-9]+:?$')->filereadable()
        line = filename->matchstr('\v.*:\zs[0-9]+\ze:?$')->str2nr()
        filename = filename->matchstr('\v^.*\ze:[0-9]+:?$')
    elseif filename->matchstr('\v^.*\ze:[0-9]+:[0-9]+:?$')->filereadable()
        column = filename->matchstr('\v.*:\zs[0-9]+\ze:?$')->str2nr()
        line = filename->matchstr('\v.*:\zs[0-9]+\ze:[0-9]+:?$')->str2nr()
        filename = filename->matchstr('\v^.*\ze:[0-9]+:[0-9]+:?$')
    endif
    if filename->filereadable()
        execute 'edit' filename->fnameescape()
        # this is used to make ftdetect (and many other things) work
        do BufRead
        if line > 0
            execute 'normal' line .. 'G'
            if column > 0
                execute 'normal 0' (column - 1) .. 'l'
            endif
        endif
    endif
enddef

# fix % in cmdwin when matchit plugin enabled. {{{1
au BufEnter * {
    if win_gettype() == 'command' && maparg('%', 'x') =~ 'Matchit'
        xnoremap <buffer> % %
    endif
}
