" Always require latest vim. (not neovim!)

execute 'set rtp^=' . fnameescape(expand('<sfile>:p:h'))
execute 'set rtp+=' . fnameescape(expand('<sfile>:p:h') . '/after')

let mapleader = ' '  " assign before use
let maplocalleader = ' ;'
noremap <Space> <Nop>

" default {{{
" if run vim with `-u xxx`, then &cp is set; disable it with `set nocp`.
if &compatible
  set nocompatible
endif

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
  augroup vimrc_terminal
    au!
    " NOTE: keymap defined here (terminal [p]aste).
    au TerminalOpen * setl nonu | setl nornu | nnoremap <buffer> p i<C-w>""<C-\><C-n>
  augroup END
  " hlsearch
  set hls
  let g:vimrc#loaded = 1
  let g:vimrc#loaded_gui = 0
endif

" filetype / syntax
filetype on
filetype plugin on
filetype indent on
" belloff
set bo=all
" incsearch
set is
" timeoutlen
set tm=5000
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
" shortmess; show search count message (default in neovim)
set shm-=S
" sessionoptions; better :mksession option.
set ssop=blank,curdir,folds,tabpages,winsize

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

" disable default plugin
let g:loaded_2html_plugin = 1
let g:loaded_getscriptPlugin = 1
let g:loaded_gzip = 1
let g:loaded_logiPat = 1
let g:loaded_netrwPlugin = 1
let g:loaded_tarPlugin = 1
let g:loaded_vimballPlugin = 1
let g:loaded_zipPlugin = 1

" }}}

" common platform detection
let s:is_unix = has('unix')
let s:is_win32 = has('win32')
let s:has_gui = has('gui_running')
      \ || (has('unix') && system('uname -s') =~? 'Darwin')
      \ || (!empty($DISPLAY) || !(empty($WAYLAND_DISPLAY)))

" various tmpfile {{{
" copy from https://github.com/mhinz/vim-galore#temporary-files (modified)
" backup files
set backup
let &backupdir = expand('~/.vim/files/backup/')
set backupext=-vimbackup
set backupskip=
" swap files
let &directory = expand('~/.vim/files/swap' . '//')
" use default value
"set updatecount =100
" undo files
set undofile
let &undodir = expand('~/.vim/files/undo/')
" viminfo files
let &viminfofile = expand('~/.vim/files/viminfo')

" create directory if needed
for s:t_dir in [&backupdir, &directory, &undodir]
  if !isdirectory(s:t_dir)
    call mkdir(s:t_dir, 'p')
  endif
endfor

" disable some feature
set nobackup
set noundofile
" }}}

" common func {{{
" :echoerr will raise exception (?)
function! s:echoerr(msg)
  echohl ErrorMsg
  echon a:msg
  echohl None
endfunction

function! s:win32_quote(arg)
  " To make quote work reliably, it is worth reading:
  " <https://daviddeley.com/autohotkey/parameters/parameters.htm>
  let cmd = a:arg
  " double all \ before "
  let cmd = substitute(cmd, '\v\\([\\]*")@=', '\\\\', 'g')
  " double trailing \
  let cmd = substitute(cmd, '\v\\([\\]*$)@=', '\\\\', 'g')
  " escape " with \
  let cmd = escape(cmd, '"')
  " quote it
  let cmd = '"' . cmd . '"'
  return cmd
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
    call s:echoerr(printf('edit_map: "%s" not found', a:arg)) | return
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

" snippet; :Scratch [filetype] / :Ksnippet [filetype] (with new window) {{{
command -nargs=? -complete=filetype Scratch call <SID>scratch(<q-args>)
command! -bang -nargs=? -complete=filetype
      \ Ksnippet call <SID>snippet_in_new_window('<bang>', <q-args>)

function! s:scratch(ft) abort
  enew | setl buftype=nofile noswapfile bufhidden=hide
  if !empty(a:ft)
    exe 'setl ft=' . a:ft
  endif
endfunction

function! s:snippet_in_new_window(bang, ft) abort
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
      setl buftype=nofile noswapfile
      setl bufhidden=hide
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

" run vim command; :KvimRun {vim_command}... {{{
command! -nargs=+ -complete=command KvimRun call <SID>vim_run(<q-args>)

function! s:vim_run(args) abort
  Scratch
  put =execute(a:args)
endfunction
" }}}

" vim expr; :KvimExpr {vim_expr}... {{{
command! -nargs=+ -complete=expression KvimExpr call <SID>vim_expr(<q-args>)

function! s:vim_expr(args) abort
  Scratch
  put =eval(a:args)
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
    call s:echoerr('shebang exists!') | return
  endif
  let shebang = '#!/usr/bin/env'
  if !empty(a:args)
    let shebang = shebang . ' ' . a:args
  elseif has_key(g:vimrc#shebang_lines, &ft)
    let shebang = shebang . ' ' . g:vimrc#shebang_lines[&ft]
  else
    call s:echoerr('shebang: which interpreter to run?') | return
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

" clipboard (see keymap) {{{
" use pbcopy / pbpaste in $PATH as clipboard; wayland / x11 / tmux ...
" detection is defined there. (~/bin/{pbcopy,pbpaste})

function! s:clipboard_copy(cmd)
  if empty(a:cmd)
    if has('clipboard') && !s:is_unix
      " unix: X11 clipboard content will disapper when program exits.
      let @+ = @"
      return
    endif
    if executable('pbcopy')
      let l:cmd = 'pbcopy'
    else
      call s:echoerr('clipboard not found!') | return
    endif
    call system(l:cmd, @")
  else
    call system(a:cmd, @")
  endif
endfunction

function! s:clipboard_paste(cmd)
  if empty(a:cmd)
    if has('clipboard') && !s:is_unix
      let @" = @+
      return
    endif
    if executable('pbpaste')
      let l:cmd = 'pbpaste'
    else
      call s:echoerr('clipboard not found!') | return
    endif
    let @" = system(l:cmd)
  else
    let @" = system(a:cmd)
  endif
endfunction
" }}}

" cd; :Cd <path> / :Cdhome / :Cdbuffer / :Cdproject [:]cmd... {{{
command! -nargs=1 -complete=dir Cd call <SID>cd('', <q-args>)
command! -nargs=* -complete=command Cdhome call <SID>cd('home', <q-args>)
command! -nargs=* -complete=command Cdbuffer call <SID>cd('buffer', <q-args>)
command! -nargs=* -complete=command Cdproject call <SID>cd('project', <q-args>)

function! s:cd(flag, args)
  let cmd = a:args
  if a:flag ==# 'home'
    let path = expand('~')
  elseif a:flag ==# 'project'
    let path = s:get_project_dir()
  elseif a:flag ==# 'buffer'
    let path = s:get_buf_dir()
  else
    if a:args =~ '^:'
      call s:echoerr('path argument is required!')
    endif
    " Cd: split argument as path & cmd
    let path = substitute(a:args, '\v^(.{}) :.+$', '\1', '')
    let cmd = a:args[len(path)+1:]
  endif

  if !isdirectory(path)
    let path = expand(path)
  endif
  if !isdirectory(path)
    let path = fnamemodify(path, ':h')
  endif
  if !isdirectory(path)
    call s:echoerr('not a directory: ' . a:args) | return
  endif

  if !empty(cmd)
    let old_cwd = getcwd()
    let buf = bufnr()
    try
      " use buffer variable to store cwd if `exe` switch to new window
      let b:vimrc_old_cwd = old_cwd
      exe 'lcd' path
      exe cmd
    finally
      if buf == bufnr()
        if exists('b:vimrc_old_cwd')
          unlet b:vimrc_old_cwd
        endif
        exe 'lcd' old_cwd
      endif
    endtry
  else
    exe 'lcd' path
  endif
endfunction

function! s:cd_reset()
  if exists('b:vimrc_old_cwd')
    try
      exe 'lcd' b:vimrc_old_cwd
    finally
      unlet b:vimrc_old_cwd
    endtry
  endif
endfunction

augroup vimrc_cd
  au!
  au BufEnter * call s:cd_reset()
augroup end

function! s:get_buf_dir()
  let path = expand('%:p:h')
  if empty(path) || &buftype == 'terminal'
    let path = getcwd()
  endif
  return path
endfunction

function! s:get_project_dir()
  let path = s:get_buf_dir()
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

" open file from filelist (order by opened times) (see keymap) {{{
augroup vimrc_filelist
  au!
  au BufNewFile,BufRead,BufWritePost * call s:save_filelist()
augroup end

function! s:cd_cur_line()
  let name = getline('.')
  if empty(name)
    return
  endif
  let name = fnamemodify(name, ':h')
  exe 'lcd' fnameescape(name)
  echo 'cwd: ' . getcwd()
endfunction

function! s:edit_cur_line()
  let name = getline('.')
  if empty(name)
    return
  endif
  exe 'e' fnameescape(name)
endfunction

function! s:choose_filelist() abort
  enew
  " a special filetype
  setl ft=filelist buftype=nofile noswapfile nobuflisted
  let l:list = map(s:load_filelist(), 'v:val[1]')
  call reverse(l:list)
  call append(0, l:list)
  call append(0, '')
  call append(0, filter(v:oldfiles, 'stridx(expand(v:val), fnamemodify($VIMRUNTIME, ":h")) != 0'))
  norm gg
endfunction

function! s:filelist_path()
  return get(g:, 'filelist_path', s:filelist_path_default)
endfunction
let s:filelist_path_default =
      \ ( empty(&viminfofile) ? expand('<sfile>:p:h') : fnamemodify(&viminfofile, ':h') )
      \ . '/filelist_path.cache'

function! s:load_filelist()
  try
    let files = readfile(s:filelist_path())
  catch /^Vim\%((\a\+)\)\=:E484:/
    let files = []
  endtry
  let result = []
  for i in files
    try
      " [number, filename]
      let record = json_decode(i)
    catch /^Vim\%((\a\+)\)\=:E474:/
      " json decode err
      continue
    endtry
    let result = add(result, record)
  endfor
  return result
endfunction

function! s:save_filelist() abort
  " do not save if `vim -i NONE`
  if &viminfofile ==# 'NONE'
    return
  endif

  " only save normal file
  if !empty(&buftype)
    return
  endif

  let current = expand('%:p')
  let result = {}
  for i in s:load_filelist()
    let result[i[1]] = i[0]
  endfor
  if !has_key(result, current)
    let result[current] = 0
  endif
  let result[current] += 1
  let f_list = []
  for [name, n] in items(result)
    let f_list = add(f_list, [n, name])
  endfor
  " `{a, b -> a[0] < b[0]}` is not correct! `:help sort()` for details
  let f_list = sort(f_list, {a, b -> a[0] < b[0] ? 1 : -1})
  let f_list = map(f_list, 'json_encode(v:val)')
  " file record limit
  call writefile(f_list[:10000], s:filelist_path())
endfunction
" }}}

" `J` with custom seperator; <visual>:J sep... {{{
command! -nargs=1 -range J call s:join_line(<q-args>)
function! s:join_line(sep)
  let buf = @"
  try
    norm gv
    norm x
    let @" = substitute(@", "\n", a:sep, 'g')
    norm P
  finally
    let @" = buf
  endtry
endfunction
" }}}

" execute current line (or select lines), comment removed (see keymap) {{{
function! s:execute_lines(mode)
  if a:mode == 'n'
    let lines = [getline('.')]
  elseif a:mode == 'v'
    let t = @"
    silent normal gvy
    let lines = split(@", "\n")
    let @" = t
  endif
  let result = []
  for l:i in lines
    " TODO add more comment (or based on filetype).
    let result = add(result, substitute(l:i, '\v^\s*(//|#|"|--)+', '', ''))
  endfor
  let result = join(result, "\n")
  echom result
  echo 'execute? y/N '
  if nr2char(getchar()) ==? 'y'
    redraws | execute 'Cdbuffer' result
  else
    redraws | echon 'cancelled.'
  endif
endfunction
" }}}

" gx related (NOTE: key `gx` overwritten) {{{
nnoremap <silent> gx :call <SID>gx('n')<CR>
vnoremap <silent> gx :<C-u>call <SID>gx('v')<CR>

" TODO fix quote / escape
function! s:gx_open_cmd(s)
  if executable('xdg-open')
    return ['xdg-open', a:s]
  elseif executable('open')
    return ['open', a:s]
  elseif s:is_win32
    " TODO fix open for win32
    return ['cmd', '/c', isdirectory(a:s) ? 'explorer' : 'start', a:s]
  else
    call s:echoerr('do not know how to open') | return
  endif
endfunction

" TODO show error?
function! s:gx_open(...)
  let text = join(getline(1, '$'), "\n")
  if empty(text)
    return
  endif
  if empty(a:0)
    let open_cmd = s:gx_open_cmd(text)
  else
    let open_cmd = [a:1, text]
  endif
  if empty(open_cmd)
    return
  endif
  call job_start(open_cmd, {'stoponexit': ''})
endfunction

function! s:gx_vim(...)
  " a:1 -> cmd; a:2 -> text modifier; a: 3 -> post string.
  let text = join(getline(1, '$'), "\n")
  if empty(text)
    return
  endif
  if empty(a:0)
    let cmd = text
  else
    if a:0 >= 2 && !empty(a:2)
      let text = function(a:2)(text)
    endif
    let cmd = a:1 . ' ' . text
    if a:0 >= 3 && !empty(a:3)
      let cmd .= a:3
    endif
  endif
  exe cmd
endfunction

function! s:gx(mode) abort
  if a:mode == 'v'
    let t = @"
    silent normal gvy
    let text = @"
    let @" = t
  else
    let text = expand(get(g:, 'netrw_gx', '<cfile>'))
  endif
  Ksnippet!
  " a special filetype
  setl ft=gx
  for line in split(text, "\n")
    call append('$', line)
  endfor
  norm gg"_dd
endfunction
" }}}

" colorscheme {{{
if !s:is_unix && !has('gui_running')  " win32 cmd
  set nocursorcolumn
  color pablo
elseif (s:is_unix && $TERM ==? 'linux')  " linux tty
  set bg=dark
else
  if !has('gui_running') && exists('&tgc') && $TERM !~ 'xterm'
    " make tgc work; :help xterm-true-color
    let &t_8f = "\<Esc>[38:2:%lu:%lu:%lum"
    let &t_8b = "\<Esc>[48:2:%lu:%lu:%lum"
  endif
  silent! set termguicolors
  if $BAT_THEME =~? 'light'
    set bg=light
  else
    set bg=dark
  endif
  try
    color base16-dynamic
  catch
    if has('gui_running') || exists('&tgc')
      color desert
    endif
  endtry
endif
" }}}

" gui init {{{
function! s:gui_init()
  if get(g:, 'vimrc#loaded_gui')
    return
  endif
  set guioptions=
  set lines=32
  set columns=128

  let g:vimrc#loaded_gui = 1
endfunction

if has('gui_running')
  call s:gui_init()
endif
" }}}

" edit selected line / column; :Kjump {{{
command! -nargs=+ Kjump call <SID>jump_line_col(<f-args>)
function! s:jump_line_col(line, ...) abort
  execute 'normal' a:line . 'gg'
  if a:0 > 0
    let col = a:1
    if col > 1
      execute 'normal 0' . (col-1) . 'l'
    endif
  endif
endfunction
" }}}

" export SID (:h SID); variable: g:vimrc_sid {{{
function! s:get_sid(filename)
  for i in split(execute('scriptnames'), "\n")
    let id = substitute(i, '\v^\s*(\d+): .*$', '\1', '')
    let file = substitute(i, '\v^\s*\d+: ', '', '')
    if a:filename ==# expand(file)
      return id
    endif
  endfor
  return 0
endfunction
" hide execute output.
silent let g:vimrc_sid = s:get_sid(expand('<sfile>'))
" }}}

" keymap {{{
" terminal <C-Space>
map <Nul> <C-Space>
map! <Nul> <C-Space>
tmap <Nul> <C-Space>

" completion
inoremap <C-Space> <C-x><C-o>

" clear hlsearch
nnoremap <silent> <Leader>l :noh<CR>

" custom text object
vnoremap aa :<C-u>normal! ggVG<CR>
onoremap aa :<C-u>normal! ggVG<CR>
vnoremap al :<C-u>normal! 0v$h<CR>
onoremap al :<C-u>normal! 0v$h<CR>
vnoremap il :<C-u>normal! ^vg_<CR>
onoremap il :<C-u>normal! ^vg_<CR>

" clipboard
nnoremap <Leader>y :call <SID>clipboard_copy("")<CR>
nnoremap <Leader>p :call <SID>clipboard_paste("")<CR>

" filelist buffer
nnoremap <Leader>f :call <SID>choose_filelist()<CR>

" execute current line
nnoremap <Leader><CR> :call <SID>execute_lines('n')<CR>
vnoremap <Leader><CR> :<C-u>call <SID>execute_lines('v')<CR>

" terminal escape
tnoremap <C-Space> <C-\><C-n>
tnoremap <C-w> <C-w>.
" }}}

" filetype setting {{{
augroup vimrc_filetype
  au!
  au BufNewFile,BufRead *.gv setl ft=dot
  au FileType vim setl sw=2
  au FileType yaml setl sw=2 indentkeys-=0#
  au FileType zig setl fp=zig\ fmt\ --stdin
  au FileType markdown setl tw=120

  " open plugin directory
  au FileType vim nnoremap <buffer> <LocalLeader>e <cmd>e ~/vimfiles/plugin<CR>

  " quickfix window
  au FileType qf nnoremap <buffer> <silent>
        \ <CR> <CR>:setl nofoldenable<CR>zz<C-w>p
        \| nnoremap <buffer> <leader><CR> <CR>

  " viml completion
  au FileType vim inoremap <buffer> <C-Space> <C-x><C-v>

  " markdown checkbox {{{
  function! s:markdown_checkbox()
    hi link CheckboxUnchecked Type
    hi link CheckboxChecked Comment
    syn match CheckboxUnchecked '\v^\s*- \[ \] '
    syn match CheckboxChecked '\v^\s*- \[X\] '
  endfunction

  function! s:markdown_toggle_task_status()
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
  au FileType markdown call s:markdown_checkbox() | nnoremap <buffer>
        \ <LocalLeader>c :call <SID>markdown_toggle_task_status()<CR>

  " simple filelist
  function! s:filelist_init()
    nnoremap <buffer> <LocalLeader><CR> :call <SID>cd_cur_line()<CR>
    nnoremap <buffer> <CR> :call <SID>edit_cur_line()<CR>
  endfunction
  au FileType filelist call <SID>filelist_init()

  " gx
  function! s:gx_init()
    setl buftype=nofile noswapfile
    setl bufhidden=hide
    if executable('qutebrowser')
      nnoremap <buffer> <LocalLeader>s :call <SID>gx_open('qutebrowser')<CR>
    endif
    nnoremap <buffer> <LocalLeader>f :call <SID>gx_open()<CR>
    nnoremap <buffer> <LocalLeader>v :call <SID>gx_vim('wincmd p \|')<CR>
  endfunction
  au FileType gx call <SID>gx_init()
augroup END

" :h ft-sh-syntax
let g:is_posix = 1
" }}}

" finally
" e.g. <Space><Space>
nnoremap <Leader><Leader> :nmap <Char-60>Leader<Char-62><CR>
" e.g. <Space>;; / \\
execute 'nnoremap <LocalLeader>' .
      \ (len(maplocalleader) > 1 ? matchstr(maplocalleader, '.$') : '<LocalLeader>') .
      \ ' :nmap <Char-60>LocalLeader<Char-62><CR>'

" vim: fdm=marker
