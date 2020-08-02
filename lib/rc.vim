" set rtp early to allow access to custom lib code.
set rtp^=~/lib/vim
set rtp+=~/lib/vim/after

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" default {{{

set nomodeline

" options which should not be reloaded
if !get(g:, 'vimrc#loaded')
    syntax on
    " backspace
    set bs=2
    " expandtab
    set et
    " shiftwidth
    set sw=4
    " (relative)number
    set nu
    set rnu
    if has('nvim')
        au TermOpen * setl nonu | setl nornu
    elseif has('terminal')
        au TerminalOpen * setl nonu | setl nornu
    endif
    " hlsearch
    set hls
    let g:vimrc#loaded = 1
endif

" autochdir
set acd
" filetype / syntax
filetype on
filetype plugin on
filetype indent on
" belloff
set bo=all
" incsearch
set is
" ttimeoutlen
set ttm=0
" cursorcolumn & cursorline
set cuc
set cul
" laststatus
set ls=2
" statusline
let &stl = '[%{mode()}%M%R] [%{&ft},%{&ff},%{&fenc}] %<%F ' .
            \'%=<%B> [%p%%~%lL,%cC]'
" showcmd
set sc
" wildmenu
set wmnu
" completeopt
set cot-=preview

"
" encoding
"

" set locale
if has('unix')
    lang en_US.UTF-8
else
    let $LANG='en'
endif
" menu
set enc=utf-8
" fileencodings
" See: http://edyfox.codecarver.org/html/vim_fileencodings_detection.html
set fencs=ucs-bom,utf-8,cp936,gb18030,big5,euc-jp,euc-kr,latin1

" }}}
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" function & command {{{

" Type: function
" action on choices (open a buffer, input a mapped letter to do something);
" accept:
" msg: string to display / operate on;
" data: dict; key: letter to map; value: dict;
"   data value:
"     desc: ...;
"     func: optional; 1 argument func;
"     cmd: optional; msg is appended after cmd (no whitespace);
""" call Choices('xxx', {...}) {{{{
function! s:choices_do(flag, action, text) abort
    close
    if a:flag == 'e'
        execute a:action . a:text
    elseif a:flag == 'f'
        call a:action(a:text)
    else
        call s:echoerr('unknown flag: ' . a:flag)
    endif
endfunction

function! Choices(text, data) abort
    if has('nvim')
        let buf = nvim_create_buf(v:false, v:true)
        let opts = {
                    \'relative': 'editor', 'style': 'minimal',
                    \'col': &columns / 4, 'row': &lines / 4,
                    \'width': &columns / 2, 'height': &lines / 2,
                    \}
        call nvim_open_win(buf, 1, opts)
    else
        " TODO vim popup
        Ksnippet
        setl nonu
        setl nornu
    endif

    mapclear <buffer>
    mapclear! <buffer>
    if !empty(a:text)
        let width = 0
        let nr = 1
        for i in split(a:text, '\n')
            call setline(nr, i)
            let nr += 1
            let width = max([width, len(i)])
        endfor
        call setline(nr, repeat('=', min([winwidth(0), width])))
    endif
    let delim = nr
    let nr += 1

    let b:text = a:text
    let b:cmds = {}
    let b:funcs = {}
    for [k, v] in items(a:data)
        if !empty(get(v, 'cmd'))
            let b:cmds[k] = v.cmd
            exe 'nnoremap <buffer> <silent>' k
                        \ ':<C-u>call <SID>choices_do("e",
                        \ b:cmds["' . escape(k, '"') . '"], b:text)<CR>'
        elseif !empty(get(v, 'func'))
            let b:funcs[k] = v.func
            exe 'nnoremap <buffer> <silent>' k
                        \ ':<C-u>call <SID>choices_do("f",
                        \ b:funcs["' . escape(k, '"') . '"], b:text)<CR>'
        else
            continue
        endif
        call setline(nr, printf('[%s] %s', k, v.desc))
        let nr += 1
    endfor
    call setline(nr, '[q / <Esc>] quit')

    syntax clear
    exe 'syn region delim start=/\%' . delim . 'l/ end=/\%' . (delim + 1) . 'l/'
    syn match shortCut /\v^\[(.{-})\]/
    hi def link delim Special
    hi def link shortCut Label
    setl ro
    nnoremap <buffer> <silent> q :<C-u>close<CR>
    nnoremap <buffer> <silent> <Esc> :<C-u>close<CR>
endfunction
" }}}

" Type: keybinding
" add checklist to markdown file;
" lines beginning with '\v\s+- ' can be toggled to:
" '- ', '- [ ] ', '- [X] ' with <LocalLeader><Space>
" <LocalLeader><Space> {{{
function! s:task_pre_func()
    hi CheckboxUnchecked ctermfg=yellow guifg=yellow
    hi CheckboxChecked ctermfg=grey guifg=grey cterm=italic gui=italic
    call matchadd('CheckboxUnchecked', '\v^\s*- \[ \] ')
    call matchadd('CheckboxChecked', '\v^\s*- \[X\] ')
endfunction

function! s:toggle_task_status()
    let lineno = line('.')
    let line = getline(lineno)
    if line =~# '\v^\s*- \[X\] '
        let line = substitute(line, '\v(^\s*- )@<=\[X\] ', '', '')
    elseif line =~# '\v^\s*- \[ \] '
        let line = substitute(line, '\v(^\s*- \[)@<= ', 'X', '')
    elseif line =~# '\v^\s*- '
        let line = substitute(line, '\v(^\s*-)@<= ', ' [ ] ', '')
    endif
    call setline(lineno, line)
endfunction

au FileType markdown call s:task_pre_func() | nnoremap <buffer>
            \ <LocalLeader><Space> :<C-u>call <SID>toggle_task_status()<CR>
" }}}

" Type: keybinding
" Various expansion using external programs (visual mode).
" Inspired by ultisnips.
"
" (similar to vim's *filter*,  but provide char level of selection
" instead of line level)
" {VISUAL}<Leader><Tab> {{{
command! -bang -nargs=+ -complete=shellcmd
            \ KexpandWithCmd call <SID>expand_with_cmd('<bang>', <q-args>)

function! s:expand_with_cmd(bang, cmd)
    let previous = @"
    sil normal gvy
    let code = @"
    if a:cmd ==# 'vim'
        let output = execute(code)
    else
        let output = system(a:cmd, code)
        if v:shell_error
            call s:echoerr('command failed: ' . a:cmd)
        endif
    endif
    let @" = substitute(output, '\n\+$', '', '')
    if empty(a:bang)
        KvimRun echon @"
    else
        normal gvp
    endif
    let @" = previous
endfunction
" }}}

" Type: command
" quick edit (with completion)
" :Ke {shortcut} {{{
function! s:echoerr(msg)
    echohl ErrorMsg
    echon a:msg
    echohl None
endfunction

let g:vimrc#edit_map = {
            \'zshenv': ['~/.config/zsh/env.zsh'],
            \'zshrc': ['~/.config/zsh/init.zsh', '~/.config/zsh/rc.zsh'],
            \'vim': [$MYVIMRC, '~/.config/nvim/rc.vim'],
            \ }

function! s:f_edit_map(arg)
    let arr = get(g:vimrc#edit_map, a:arg)
    if empty(arr)
        call s:echoerr(printf('edit_map: "%s" not found', a:arg))
        return
    endif
    if filereadable(expand(arr[-1]))
        exe 'e' arr[-1]
    else
        exe 'e' arr[0]
    endif
endfunction

function! s:complete_edit_map(A, L, P)
    return join(keys(g:vimrc#edit_map), "\n")
endfunction

command! -nargs=1 -complete=custom,<SID>complete_edit_map
            \ Ke call <SID>f_edit_map(<q-args>)
" }}}

" Type: command
" create a small window to write some code without writing to file;
" add "!" to reuse existing buffer named "[Snippet]".
" :Ksnippet [filetype] {{{
command! -bang -nargs=? -complete=filetype
            \ Ksnippet call <SID>snippet_in_new_window('<bang>', <q-args>)

function! s:snippet_in_new_window(bang, ft)
    let name = '[Snippet]'
    " :Ksnippet! may use existing buffer.
    let create_buffer = v:true
    let create_window = v:true
    if empty(a:bang)
        let idx = 1
        let raw_name = name
        let name = printf('%s (%d)', raw_name, idx)
        while bufexists(name)
            let idx += 1
            let name = printf('%s (%d)', raw_name, idx)
        endwhile
    else
        let s:ksnippet_bufnr = get(s:, 'ksnippet_bufnr', -1)
        if bufexists(s:ksnippet_bufnr) && bufname(s:ksnippet_bufnr) ==# name
            let create_buffer = v:false
            let buflist = tabpagebuflist()
            let buf_idx = index(buflist, s:ksnippet_bufnr)
            if buf_idx >= 0
                exe buf_idx + 1 . 'wincmd w'
                let create_window = v:false
            endif
        endif
    endif
    if create_window
        exe printf('bo %dnew', &cwh)
        if create_buffer
            setl buftype=nofile
            setl bufhidden=hide
            setl noswapfile
            silent! exe 'f' fnameescape(name)
        else
            exe s:ksnippet_bufnr . 'b'
        endif
    endif
    if !empty(a:bang)
        sil normal gg"_dG
        let s:ksnippet_bufnr = winbufnr(0)
    endif
    if !empty(a:ft)
        exe 'setl ft=' . a:ft
    endif
endfunction
" }}}

" Type: command
" run command (via :terminal), and output to a separate window
" :Krun [cmd]... {{{
command! -nargs=* -complete=shellcmd Krun call <SID>run(<q-args>)

function! s:krun_cb(...) dict
    if self.buffer_nr == winbufnr(0) && mode() == 't'
        " vim 8 behavior: exit to normal mode after TermClose.
        call feedkeys("\<C-\>\<C-n>", 'n')
    endif
endfunction

function! s:run(args)
    if !(has('nvim') || has('terminal'))
        call s:echoerr('terminal feature not enabled!')
        return
    endif
    " expand %
    let cmd = substitute(a:args, '\v(^|\s)@<=(\%(\:[phtre])*)',
                \'\=shellescape(expand(submatch(2)))', 'g')
    " remove trailing whitespace (nvim, [b]ash on Windows)
    let cmd = substitute(cmd, '\v^(.{-})\s*$', '\1', '')
    Ksnippet
    setl nonu | setl nornu
    if has('nvim')
        let opt = {
                    \'on_exit': function('s:krun_cb'),
                    \'buffer_nr': winbufnr(0),
                    \}
        if empty(cmd)
            let cmd = &shell
        endif
        if &shellquote == '"'
            " [b]ash on win32
            call termopen(printf('"%s"', cmd), opt)
        else
            call termopen(cmd, opt)
        endif
        startinsert
    else
        let args = []
        for item in util#shell_split(&shell)
            let args = add(args, item)
        endfor
        if !empty(cmd)
            for item in util#shell_split(&shellcmdflag)
                let args = add(args, item)
            endfor
            let args = add(args, cmd)
        endif
        call term_start(args, {'curwin': v:true})
    endif
endfunction
" }}}

" Type: command
" open a new tmux window and cd to current directory
" :KtmuxOpen [shell] {{{
command! -nargs=? -complete=shellcmd KtmuxOpen
            \ call <SID>open_tmux_window(<q-args>)

function! s:open_tmux_window(args)
    if exists("$TMUX")
        call system("tmux neww -c " . shellescape(expand(("%:p:h")))
                    \. " " . a:args)
    else
        call s:echoerr('not in tmux session!')
    endif
endfunction
" }}}

" Type: command
" insert shebang based on filetype
" :KshebangInsert [content after "#!/usr/bin/env "] {{{
command! -nargs=* -complete=shellcmd KshebangInsert
            \ call <SID>shebang_insert(<q-args>)

let g:vimrc#shebang_lines = {
            \'awk': 'awk -f', 'javascript': 'node', 'lua': 'lua',
            \'perl': 'perl', 'python': 'python', 'ruby': 'ruby',
            \'scheme': 'chez --script', 'sh': 'sh', 'zsh': 'zsh'
            \}

function! s:shebang_insert(args)
    let first_line = getline(1)
    if len(first_line) >= 2 && first_line[0:1] ==# '#!'
        " shebang exists
        call s:echoerr('shebang exists!')
        return
    endif
    let shebang = '#!/usr/bin/env'
    if !empty(a:args)
        let shebang = shebang . ' ' . a:args
    elseif has_key(g:vimrc#shebang_lines, &ft)
        let shebang = shebang . ' ' . g:vimrc#shebang_lines[&ft]
    else
        call s:echoerr('shebang: which interpreter to run?')
        return
    endif
    " insert at first line and leave cursor here (for further modification)
    normal ggO<Esc>
    let ret = setline(1, shebang)
    if ret == 0 " success
        normal $
    else
        call s:echoerr('setting shebang error!')
    endif
endfunction
" }}}

" Type: command
" match long line
" Refer: https://stackoverflow.com/a/1117367
" :KmatchLongLine {number} {{{
command! -nargs=1 KmatchLongLine exe '/\%>' . <args> . 'v.\+'
" }}}

" Type: command
" run vim command, and write output to a separate buffer (using :Ksnippet)
" :KvimRun {vim_command}... {{{
command! -nargs=+ -complete=command KvimRun call <SID>vim_run(<q-args>)

function! s:vim_run(args)
    let buf = @"
    sil! let @" = execute(a:args)
    Ksnippet!
    normal p
    let @" = buf
endfunction
" }}}

" Type: command
" write vim expr result to a separate buffer (using :Ksnippet)
" :KvimExpr {vim_expr}... {{{
command! -nargs=+ -complete=expression KvimExpr call <SID>vim_expr(<q-args>)

function! s:vim_expr(args)
    let buf = @"
    let result = eval(a:args)
    if type(result) == v:t_string
        let @" = result
    else
        let @" = string(result)
    endif
    Ksnippet!
    normal p
    let @" = buf
endfunction
" }}}

" Type: function
" accept bufnr (default 0), return project dir (or '' if .git not found).
" {{{
function! s:get_project_dir(...)
    let bufnr = a:0 ? a:1 : 0
    let path = getcwd(bufnr)
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

" Type: command
" rg with quickfix window
" :Krg [arguments to rg]... {{{
if executable('rg') && has('nvim')
    command! -bang -nargs=+ Krg call <SID>Rg('<bang>', <q-args>)
endif

function! s:jobstop(jid)
    if jobwait([a:jid], 0)[0] == -1
        call jobstop(a:jid)
        echo 'job terminated.'
    else
        echo 'job already exit.'
    endif
endfunction

function! s:rg_stdout_cb(j, d, e) dict
    if a:d == ['']
        return
    endif
    lad a:d
    if self.counter == 0 && winbufnr(0) == self.bufnr
        lop
        let &l:stl = '[Location List] (' . self.title . ')%=' . '[%p%%~%lL,%cC]'
        " press <C-c> to terminate job.
        exe 'nnoremap <buffer> <C-c> :call <SID>jobstop(' . a:j . ')<CR>'
    endif
    let self.counter += 1
endfunction

function! s:rg_exit_cb(j, d, e) dict
    if self.counter == 0
        echo 'nothing matches.'
    else
        echo 'rg finished.'
    endif
endfunction

function! s:Rg(bang, args)
    if empty(a:bang)
        let path = s:get_project_dir()
        if empty(path)
            call s:echoerr('not in git repo!')
            return
        endif
    else
        let path = getcwd()
    endif
    let bufnr = winbufnr(0)
    let jid = jobstart(printf('rg --vimgrep %s %s', a:args, shellescape(path)),
                \{'bufnr': bufnr, 'counter': 0, 'title': 'rg ' . a:args,
                \'on_stdout': function('s:rg_stdout_cb'),
                \'on_exit': function('s:rg_exit_cb'),
                \})
endfunction
" }}}

" Type: function
" exchange data between system clipboard and vim @"
" Usage:
"   call VIMRC_clipboard_copy("cmd") to copy from @" to system clipboard;
"   call VIMRC_clipboard_paste("cmd") to paste to @" from system clipboard;
"   try to use mappings.
" Note: passing "" as function argument to use default system clipboard.
" {{{
function! VIMRC_clipboard_copy(cmd)
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

function! VIMRC_clipboard_paste(cmd)
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

" }}}
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" keymap {{{
let mapleader = 's'
let maplocalleader = 'S'
noremap s <Nop>
noremap S <Nop>
" clear hlsearch
nnoremap <silent> <Leader><Space> :noh<CR>
" custom text object
vnoremap aa :<C-u>normal! ggVG<CR>
onoremap aa :<C-u>normal! ggVG<CR>
vnoremap al :<C-u>normal! 0v$h<CR>
onoremap al :<C-u>normal! 0v$h<CR>
vnoremap il :<C-u>normal! ^vg_<CR>
onoremap il :<C-u>normal! ^vg_<CR>

" quickfix window
au FileType qf nnoremap <buffer> <silent>
            \ <CR> <CR>:setl nofoldenable<CR>zz<C-w>p
            \| nnoremap <buffer> <leader><CR> <CR>

" completion
inoremap <Nul> <C-x><C-o>
inoremap <C-Space> <C-x><C-o>
au FileType vim inoremap <buffer> <C-space> <C-x><C-v>
au FileType vim inoremap <buffer> <Nul> <C-x><C-v>

" terminal escape
tnoremap <Nul> <C-\><C-n>
tnoremap <C-Space> <C-\><C-n>
if !has('nvim') && has('terminal')
    tnoremap <C-w> <C-w>.
endif

vnoremap <Leader><Tab> :<C-u>KexpandWithCmd
nnoremap <Leader>y :call VIMRC_clipboard_copy("")<CR>
nnoremap <Leader>p :call VIMRC_clipboard_paste("")<CR>

nnoremap <Leader>e :e <cfile><CR>
nnoremap <Leader>E :e#<CR>

function! s:gx(mode)
    if a:mode == 'v'
        let t = @"
        silent normal gvy
        let text = @"
        let @" = t
    else
        let text = expand(get(g:, 'netrw_gx', '<cfile>'))
    endif
    if executable('xdg-open')
        let open_cmd = 'xdg-open'
    elseif executable('open')
        let open_cmd = 'open'
    elseif has('win32')
        let open_cmd = 'start'
    else
        call s:echoerr('do not know how to open')
        return
    endif
    " TODO fix quote / escape
    call Choices(text, {
                \'e': {'desc': 'edit in current buffer', 'func': {s -> execute('e ' . fnameescape(s))}},
                \'s': {'desc': 'split', 'func': {s -> execute('split ' . fnameescape(s))}},
                \'v': {'desc': 'vsplit', 'func': {s -> execute('vsplit ' . fnameescape(s))}},
                \'t': {'desc': 'edit in new tab', 'func': {s -> execute('tabe ' . fnameescape(s))}},
                \'o': {'desc': 'open', 'func': {s -> execute('!' . open_cmd . ' ' . shellescape(s))}},
                \})
endfunction
nnoremap <silent> gx :<C-u>call <SID>gx('n')<CR>
vnoremap <silent> gx :<C-u>call <SID>gx('v')<CR>
" }}}
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" colorscheme {{{
nnoremap <Leader>t :call <SID>toggle_theme()<CR>

function! s:toggle_theme(...)
    if a:0 > 0
        if a:1 =~? 'light'
            let s:base16_theme = 'light'
        else
            let s:base16_theme = 'dark'
        endif
    else
        if get(s:, 'base16_theme', 'light') == 'light'
            let s:base16_theme = 'dark'
        else
            let s:base16_theme = 'light'
        endif
    endif
    if s:base16_theme == 'light'
        let g:base16#pallet = {"scheme": "One Light", "author": "Daniel Pfeifer (http://github.com/purpleKarrot)", "base00": "fafafa", "base01": "f0f0f1", "base02": "e5e5e6", "base03": "a0a1a7", "base04": "696c77", "base05": "383a42", "base06": "202227", "base07": "090a0b", "base08": "ca1243", "base09": "d75f00", "base0A": "c18401", "base0B": "50a14f", "base0C": "0184bc", "base0D": "4078f2", "base0E": "a626a4", "base0F": "986801"}
    else
        let g:base16#pallet = {"scheme": "Material", "author": "Nate Peterson", "base00": "263238", "base01": "2E3C43", "base02": "314549", "base03": "546E7A", "base04": "B2CCD6", "base05": "EEFFFF", "base06": "EEFFFF", "base07": "FFFFFF", "base08": "F07178", "base09": "F78C6C", "base0A": "FFCB6B", "base0B": "C3E88D", "base0C": "89DDFF", "base0D": "82AAFF", "base0E": "C792EA", "base0F": "FF5370"}
    endif
    color base16-dynamic
endfunction

if $TERM !=? 'linux'
    silent! set termguicolors
    call s:toggle_theme($BAT_THEME)
endif
" }}}
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" misc {{{
au BufNewFile,BufRead *.gv setl ft=dot
au FileType yaml setl sw=2 indentkeys-=0#
au FileType zig setl fp=zig\ fmt\ --stdin
au FileType markdown setl tw=120

" :h ft-sh-syntax
let g:is_posix = 1
" }}}
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" vim: fdm=marker
