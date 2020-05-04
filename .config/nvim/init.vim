" set rtp early to allow access to custom lib code.
set rtp^=~/lib/vim
set rtp+=~/lib/vim/after

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" default {{{

set nomodeline

" autochdir
set acd
" filetype / syntax
filetype on
filetype plugin on
filetype indent on
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
" belloff
set bo=all
" incsearch
set is
" hlsearch
set hls
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
" misc {{{

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Type: keybinding
" add checklist to markdown file;
" lines beginning with '\v\s+- ' can be toggled to:
" '- ', '- [ ] ', '- [X] ' with <LocalLeader><Space>
" {{{
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
" }}}
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Type: keybinding
" Various expansion using external programs (visual mode).
" Inspired by ultisnips.
"
" (similar to vim's *filter*,  but provide char level of selection
" instead of line level)
"
" Usage: select code, and press <Leader><Tab> and input program to run with.
" {{{
command! -bang -nargs=+ -complete=shellcmd
            \ KexpandWithCmd call <SID>expand_with_cmd('<bang>', <q-args>)

function! s:expand_with_cmd(bang, cmd)
    let previous = @"
    sil normal gvy
    let code = @"
    if a:cmd ==# 'vim'
        let output = execute(code)
    elseif executable(split(a:cmd, ' ')[0])
        let output = system(a:cmd, code)
    else
        " fail
        let @" = previous
        echoh ErrorMsg | echon 'command not found: ' . a:cmd | echoh None
        return
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
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Type: command
" create a small window to write some code without writing to file;
" add "!" to reuse existing buffer named "[Snippet]".
" Usage: :Ksnippet [filetype]  " <Tab> for completion
" {{{
command! -bang -nargs=? -complete=filetype
            \ Ksnippet call <SID>snippet_in_new_window('<bang>', <q-args>)

function! s:snippet_in_new_window(bang, ft)
    " TODO bufname, bufnr & :bd is buggy on Windows
    let name = '[Snippet]'
    if empty(a:bang)
        let idx = 1
        let raw_name = name
        let name = printf('%s (%d)', raw_name, idx)
        while bufexists(name)
            let idx += 1
            let name = printf('%s (%d)', raw_name, idx)
        endwhile
    else
        if bufexists(name)
            exe 'bd' fnameescape(name)
        endif
    endif
    exe printf('bo %dnew', &cwh)
    setl buftype=nofile
    setl bufhidden=hide
    silent exe 'f' fnameescape(name)
    if !empty(a:ft)
        exe 'setl ft=' . a:ft
    endif
endfunction
" }}}
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Type: command
" run command (via :terminal), and output to a separate window
" Usage: :Krun ...your command goes here...
" {{{
command! -nargs=+ -complete=shellcmd Krun call <SID>run(<q-args>)

function! s:run(args)
    if has('nvim') || has('terminal')
        Ksnippet!
        setl nonu | setl nornu
        if has('nvim')
            if &shellquote == '"'
                " [b]ash on win32
                call termopen(printf('"%s"', a:args))
            else
                call termopen(a:args)
            endif
            startinsert
        else
            let args = []
            for item in util#shell_split(&shell)
                let args = add(args, item)
            endfor
            for item in util#shell_split(&shellcmdflag)
                let args = add(args, item)
            endfor
            let args = add(args, a:args)
            call term_start(args, {'curwin': v:true})
        endif
    else
        echoh ErrorMsg | echon 'terminal feature not enabled!' | echoh None
    endif
endfunction
" }}}
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Type: command
" open a new tmux window and cd to current directory
" Usage: :KtmuxOpen [shell]
" {{{
command! -nargs=? -complete=shellcmd KtmuxOpen
            \ call <SID>open_tmux_window(<q-args>)

function! s:open_tmux_window(args)
    if exists("$TMUX")
        call system("tmux neww -c " . shellescape(expand(("%:p:h")))
                    \. " " . a:args)
    else
        echoh ErrorMsg | echon 'not in tmux session!' | echoh None
    endif
endfunction
" }}}
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Type: command
" insert shebang based on filetype
" Usage: :KshebangInsert [content after "#!/usr/bin/env "]
" {{{
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
        echoh ErrorMsg | echon 'shebang exists!' | echoh None
        return
    endif
    let shebang = '#!/usr/bin/env'
    if !empty(a:args)
        let shebang = shebang . ' ' . a:args
    elseif has_key(g:vimrc#shebang_lines, &ft)
        let shebang = shebang . ' ' . g:vimrc#shebang_lines[&ft]
    else
        echoh ErrorMsg | echon 'shebang: which interpreter to run?'
                    \| echoh None
        return
    endif
    " insert at first line and leave cursor here (for further modification)
    normal ggO<Esc>
    let ret = setline(1, shebang)
    if ret == 0 " success
        normal $
    else
        echoh ErrorMsg | echon 'setting shebang error!' | echoh None
    endif
endfunction
" }}}
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Type: command
" match long line
" Usage: :KmatchLongLine ...a number...
" Refer: https://stackoverflow.com/a/1117367
" {{{
command! -nargs=1 KmatchLongLine exe '/\%>' . <args> . 'v.\+'
" }}}
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Type: command
" run vim command, and write output to a separate buffer (using :Ksnippet)
" Usage: :KvimRun vim_command ...
" {{{
command! -nargs=+ -complete=command KvimRun call <SID>vim_run(<q-args>)

function! s:vim_run(args)
    let buf = @"
    sil! let @" = execute(a:args)
    Ksnippet!
    normal p
    let @" = buf
endfunction
" }}}
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Type: command
" write vim expr result to a separate buffer (using :Ksnippet)
" Usage: :KvimExpr vim_expr ...
" {{{
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
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Type: command
" rg with quickfix window
" Usage: :Krg [...]  # arguments to rg
" {{{
if executable('rg')
    command! -nargs=+ Krg call <SID>Rg(<q-args>)
endif

function! s:Rg(args)
    lgetexpr system('rg --vimgrep ' . a:args)
    lopen | setl ft=qf | let w:quickfix_title = 'rg ' . a:args
endfunction
" }}}
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
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
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" }}}
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" opinionated {{{

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

" markdown checkbox
au FileType markdown call s:task_pre_func() | nnoremap <buffer>
            \ <LocalLeader><Space> :<C-u>call <SID>toggle_task_status()<CR>

" quickfix window
au FileType qf nnoremap <buffer> <silent>
            \ <CR> <CR>:setl nofoldenable<CR>zz<C-w>p
            \| nnoremap <buffer> <leader><CR> <CR>

" completion
inoremap <Nul> <C-x><C-o>
inoremap <C-Space> <C-x><C-o>

" terminal escape
tnoremap <Nul> <C-\><C-n>
tnoremap <C-Space> <C-\><C-n>
if !has('nvim') && has('terminal')
    tnoremap <C-w> <C-w>.
endif

vnoremap <Leader><Tab> :<C-u>KexpandWithCmd
nnoremap <Leader>y :call VIMRC_clipboard_copy("")<CR>
nnoremap <Leader>p :call VIMRC_clipboard_paste("")<CR>

" }}}

" plugin {{{
call plug#begin(expand('<sfile>:p:h') . '/plugged')
" modeline
" Since this plugin is not updated frequently, I move it to local dir
" (~/lib/vim).
" Also see https://github.com/ciaranm/securemodelines/pull/26 (which moves it
" from dir plugin to to after/plugin).
" Plug 'ciaranm/securemodelines'
Plug 'cespare/vim-toml'
Plug 'tpope/vim-markdown'
let g:markdown_syntax_conceal = 0
let g:markdown_fenced_languages = ['python', 'vim', 'json', 'yaml', 'javascript', 'sh']
Plug 'vim-python/python-syntax'
let g:python_highlight_all = 1
Plug 'ziglang/zig.vim'
let g:zig_fmt_autosave = 0
if has('nvim')
    Plug 'Shougo/deoplete.nvim', { 'do': ':UpdateRemotePlugins' }
    Plug 'deoplete-plugins/deoplete-jedi'
    let g:jedi#completions_enabled = 0
    let g:jedi#popup_on_dot = 0
    let g:jedi#show_call_signatures = 0
    Plug 'Shougo/neco-vim'
    Plug 'Shougo/neco-syntax'
endif
call plug#end()
" }}}

" colorscheme {{{
function! ReadColor(filename)
    if !empty(a:filename)
        let content = join(readfile(expand(a:filename)), "\n")
        pyx import yaml
        pyx import vim
        return pyxeval('yaml.safe_load(vim.eval("content"))')
    endif
    " default: material
    return {"base00": "263238", "base01": "2E3C43", "base02": "314549", "base03": "546E7A", "base04": "B2CCD6", "base05": "EEFFFF", "base06": "EEFFFF", "base07": "FFFFFF", "base08": "F07178", "base09": "F78C6C", "base0A": "FFCB6B", "base0B": "C3E88D", "base0C": "89DDFF", "base0D": "82AAFF", "base0E": "C792EA", "base0F": "FF5370"}
endfunction

if $TERM !=? 'linux' &&
            \ ( has('nvim') || has('gui_running') || $TERM =~# 'xterm' )
    set tgc
    "let g:base16#pallet = ReadColor('~/base16/one-light.yml')
    let g:base16#pallet = ReadColor('')
    color base16-dynamic
else
    set bg=dark
endif
" }}}

" misc {{{
au BufNewFile,BufRead *.gv setl ft=dot
au FileType yaml setl sw=2 indentkeys-=0#
au FileType zig setl fp=zig\ fmt\ --stdin
au FileType markdown setl tw=120

nnoremap <Leader>e :e <cfile><CR>
nnoremap <Leader>E :e#<CR>

command! KdeopleteEnable call deoplete#enable()

au FileType vim inoremap <buffer> <C-space> <C-x><C-v>
au FileType vim inoremap <buffer> <Nul> <C-x><C-v>
" }}}
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" vim: fdm=marker
