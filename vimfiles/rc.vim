execute 'set rtp^=' . fnameescape(expand('<sfile>:p:h'))
execute 'set pp^=' . fnameescape(expand('<sfile>:p:h'))

let mapleader = 's'  " assign before use
let maplocalleader = 'S'
noremap s <Nop>
noremap S <Nop>

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
  else
    au TerminalOpen * setl nonu | setl nornu
  endif
  " hlsearch
  set hls
  let g:vimrc#loaded = 1
endif

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
  let $LANG = 'en'
endif
" menu
set enc=utf-8
" fileencodings
" See: http://edyfox.codecarver.org/html/vim_fileencodings_detection.html
set fencs=ucs-bom,utf-8,cp936,gb18030,big5,euc-jp,euc-kr,latin1

" }}}

" common func {{{
function! s:getcwd()
    let path = expand('%:p:h')
    if empty(path) || &buftype == 'terminal'
        let path = getcwd()
    endif
    return path
endfunction

function! s:echoerr(msg)
    echohl ErrorMsg
    echon a:msg
    echohl None
endfunction

function! s:get_project_dir()
    let path = s:getcwd()
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

" add checklist to markdown file; <LocalLeader><Space> {{{
au FileType markdown call s:task_pre_func() | nnoremap <buffer>
      \ <LocalLeader><Space> :<C-u>call <SID>toggle_task_status()<CR>

function! s:task_pre_func()
  hi link CheckboxUnchecked Type
  hi link CheckboxChecked Comment
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

" vim's *filter*, char level; {VISUAL}<Leader><Tab> {{{
command! -bang -nargs=+ -complete=shellcmd
      \ KexpandWithCmd call <SID>expand_with_cmd('<bang>', <q-args>)

function! s:expand_with_cmd(bang, cmd) abort
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

" quick edit (with completion); :Ke {shortcut} {{{
command! -nargs=1 -complete=custom,<SID>complete_edit_map
      \ Ke call <SID>f_edit_map(<q-args>)

let g:vimrc#edit_map = {
      \'vim': [$MYVIMRC, '~/.vimrc'],
      \ }

function! s:f_edit_map(arg) abort
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
" }}}

" snippet; :Ksnippet [filetype] {{{
command! -bang -nargs=? -complete=filetype
      \ Ksnippet call <SID>snippet_in_new_window('<bang>', <q-args>)

function! s:snippet_in_new_window(bang, ft)
  let name = '[Snippet]'
  " :Ksnippet! may use existing buffer.
  let create_buffer = 1
  let create_window = 1
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
      let create_buffer = 0
      let buflist = tabpagebuflist()
      let buf_idx = index(buflist, s:ksnippet_bufnr)
      if buf_idx >= 0
        exe buf_idx + 1 . 'wincmd w'
        let create_window = 0
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

" run command (via :terminal), output to a separate window; :Krun [cmd]... {{{
command! -nargs=* -complete=shellcmd Krun call <SID>run(<q-args>)

function! s:krun_cb(...) dict
  if self.buffer_nr == winbufnr(0) && mode() == 't'
    " vim 8 behavior: exit to normal mode after TermClose.
    call feedkeys("\<C-\>\<C-n>", 'n')
  endif
endfunction

function! s:run(args) abort
  " expand %
  let cmd = substitute(a:args, '\v(^|\s)@<=(\%(\:[phtre])*)',
        \'\=shellescape(expand(submatch(2)))', 'g')
  " remove trailing whitespace (nvim, [b]ash on Windows)
  let cmd = substitute(cmd, '\v^(.{-})\s*$', '\1', '')
  let cwd = s:getcwd()
  Ksnippet
  setl nonu | setl nornu
  if has('nvim')
    let opt = {
          \'on_exit': function('s:krun_cb'),
          \'buffer_nr': winbufnr(0),
          \'cwd': cwd,
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
    call term_start(args, {'curwin': 1, 'cwd': cwd})
  endif
endfunction
" }}}

" run vim command; :KvimRun {vim_command}... {{{
command! -nargs=+ -complete=command KvimRun call <SID>vim_run(<q-args>)

function! s:vim_run(args)
  let buf = @"
  sil! let @" = execute(a:args)
  Ksnippet!
  normal p
  let @" = buf
endfunction
" }}}

" vim expr; :KvimExpr {vim_expr}... {{{
command! -nargs=+ -complete=expression KvimExpr call <SID>vim_expr(<q-args>)

function! s:vim_expr(args)
  let buf = @"
  let result = eval(a:args)
  if type(result) == type('')
    let @" = result
  else
    let @" = string(result)
  endif
  Ksnippet!
  normal p
  let @" = buf
endfunction
" }}}

" open a new tmux window and cd to current directory; :KtmuxOpen [shell] {{{
command! -nargs=? -complete=shellcmd KtmuxOpen
      \ call <SID>open_tmux_window(<q-args>)

function! s:open_tmux_window(args)
  if exists("$TMUX")
    call system("tmux neww -c " . shellescape(s:getcwd())
          \. " " . a:args)
  else
    call s:echoerr('not in tmux session!')
  endif
endfunction
" }}}

" insert shebang based on filetype; :KshebangInsert [content after "#!/usr/bin/env "] {{{
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

" match long line; :KmatchLongLine {number} {{{
" Refer: https://stackoverflow.com/a/1117367
command! -nargs=1 KmatchLongLine exe '/\%>' . <args> . 'v.\+'
" }}}

" rg with quickfix window; :Krg [arguments to rg]... {{{
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
    let path = s:getcwd()
  endif
  let bufnr = winbufnr(0)
  let jid = jobstart(printf('rg --vimgrep %s %s', a:args, shellescape(path)),
        \{'bufnr': bufnr, 'counter': 0, 'title': 'rg ' . a:args,
        \'on_stdout': function('s:rg_stdout_cb'),
        \'on_exit': function('s:rg_exit_cb'),
        \})
endfunction
" }}}

" clipboard; <Leader>y / <Leader>p {{{
nnoremap <Leader>y :call <SID>clipboard_copy("")<CR>
nnoremap <Leader>p :call <SID>clipboard_paste("")<CR>

function! s:clipboard_copy(cmd)
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

function! s:clipboard_paste(cmd)
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

" keymap {{{
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
if !has('nvim')
  tnoremap <C-w> <C-w>.
endif

vnoremap <Leader><Tab> :<C-u>KexpandWithCmd

nnoremap <Leader>e :cd %:h \| e <cfile><CR>
nnoremap <Leader>E :e#<CR>

" }}}

" gx related {{{
" TODO fix quote / escape
function! s:gx_cmd(s)
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
        call s:echoerr('do not know how to open')
        return
    endif
endfunction

function! s:open(s)
    let open_cmd = s:gx_cmd(a:s)
    if empty(open_cmd)
        return
    endif
    if has('nvim')
        call jobstart(open_cmd, {'detach': 1})
    else
        call job_start(open_cmd, {'stoponexit': ''})
    endif
endfunction

function! s:gx(mode)
  if a:mode == 'v'
    let t = @"
    silent normal gvy
    let text = @"
    let @" = t
  else
    let text = expand(get(g:, 'netrw_gx', '<cfile>'))
  endif
  call Choices(text, g:vimrc#gx)
endfunction

let g:vimrc#gx = {
      \'fe': ['edit in current buffer', {s -> execute('e ' . fnameescape(s))}],
      \'fs': ['split', {s -> execute('split ' . fnameescape(s))}],
      \'fv': ['vsplit', {s -> execute('vsplit ' . fnameescape(s))}],
      \'ft': ['edit in new tab', {s -> execute('tabe ' . fnameescape(s))}],
      \'o': ['open', funcref('s:open')],
      \}

nnoremap <silent> gx :<C-u>call <SID>gx('n')<CR>
vnoremap <silent> gx :<C-u>call <SID>gx('v')<CR>
" }}}

" colorscheme {{{
if !has('unix') && !has('gui_running')  " win32 cmd
  set nocursorcolumn
  color pablo
elseif (has('unix') && $TERM ==? 'linux')  " linux tty
  set bg=dark
else
  silent! set termguicolors
  if $BAT_THEME =~? 'light'
    set bg=light
  else
    set bg=dark
  endif
  silent! color base16-dynamic
endif
" }}}

" gui init {{{
function! s:gui_init()
  set guioptions=
  set lines=32
  set columns=128

  if has('nvim')
    GuiTabline 0
  endif

  " light theme
  set bg=light
endfunction

if has('nvim') && exists(':GuiTabline') == 2  " nvim gui detect
  au UIEnter * call <SID>gui_init()
elseif has('gui_running')
  call s:gui_init()
endif
" }}}

" win32 sh; use busybox if possible {{{
if !has('unix')
  command! KtoggleShell call s:ToggleShell()

  function! s:ToggleShell()
    if !executable('busybox')
      return
    endif
    if &shell =~ 'sh'
      let &shell = 'cmd.exe'
      let &shellcmdflag = '/s /c'
      let &shellquote = ''
    else
      let &shell = 'busybox sh'
      let &shellcmdflag = '-c'
      if has('nvim')
        let &shellquote = '"'
      endif
    endif
  endfunction

  " avoid /bin/sh as &shell; set busybox if possible; else set cmd.exe
  KtoggleShell
  if (!executable('busybox') && stridx(&sh, 'sh') >= 0)
        \ ||
        \ (executable('busybox') && stridx(&sh, 'sh') < 0)
    KtoggleShell
  endif
endif
" }}}

" misc {{{
au BufNewFile,BufRead *.gv setl ft=dot
au FileType vim setl sw=2
au FileType yaml setl sw=2 indentkeys-=0#
au FileType zig setl fp=zig\ fmt\ --stdin
au FileType markdown setl tw=120

" :h ft-sh-syntax
let g:is_posix = 1

" qutebrowser edit-cmd
command! KqutebrowserEditCmd call s:qutebrowser_edit_cmd()

function! s:qutebrowser_edit_cmd()
  Ksnippet
  wincmd o
  call setline(1, $QUTE_COMMANDLINE_TEXT[1:])
  call setline(2, '')
  call setline(3, 'hit `;q` to save cmd (first line) and quit')
  nnoremap <buffer> ;q :<C-u> call writefile(['set-cmd-text -s :' . getline(1)], $QUTE_FIFO) \| q<CR>
endfunction

" dirvish
let g:loaded_netrwPlugin = 1
au FileType dirvish nmap <buffer> H <Plug>(dirvish_up) | nmap <buffer> L i

" gx
if exists('$SWAYSOCK')
  " swaywm
  command! -nargs=+ Search call s:open(<q-args>) | sil! !swaymsg 'workspace 2'
elseif $HOME =~# '^/Users'
  " osx
  command! -nargs=+ Search call s:open(<q-args>) | sil! !open -a 'qutebrowser'
endif

function! s:start_search(s)
  call feedkeys(":\<C-u>Search  " . a:s)
  call feedkeys("\<Home>")
  call feedkeys(repeat("\<Right>", 7))
endfunction
call extend(g:vimrc#gx, {';s': ['search', funcref('s:start_search')]})

nmap <Leader>s gx;s
vmap <Leader>s gx;s
" }}}

" vim: fdm=marker
