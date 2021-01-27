if v:version < 702
  echoerr 'minimum supported vim version: 7.2' | finish
endif

execute 'set rtp^=' . fnameescape(expand('<sfile>:p:h'))
if exists('&pp')
  execute 'set pp^=' . fnameescape(expand('<sfile>:p:h'))
endif

let mapleader = 's'  " assign before use
let maplocalleader = "\<Space>"
noremap s <Nop>
noremap <Space> <Nop>

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
  if exists('&rnu')
    set rnu
  endif
  if has('nvim')
    au TermOpen * setl nonu | setl nornu
  elseif exists('##TerminalOpen')
    " nvim paste in terminal mode will leave cursor position not changed;
    " try to simulate this in vim, but failed.
    au TerminalOpen * setl nonu | setl nornu | nnoremap <buffer> p i<C-w>""<C-\><C-n>
  endif
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
if exists('&bo')
  set bo=all
endif
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
function! s:echoerr(msg)
  echohl ErrorMsg
  echon a:msg
  echohl None
endfunction

function! s:execute(arg)
  if exists('*execute')
    return execute(a:arg)
  endif
  let l:res = ''
  try
    " exception message will be thrown away.
    redir => l:res
    exe a:arg
  finally
    redir END
  endtry
  return l:res
endfunction
" }}}

" add checklist to markdown file; <LocalLeader><Space> {{{
au FileType markdown call s:task_pre_func() | nnoremap <buffer>
      \ <LocalLeader>c :call <SID>toggle_task_status()<CR>

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
    let output = s:execute(code)
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

" snippet; :Ksnippet [filetype] {{{
if v:version > 702
  command! -bang -nargs=? -complete=filetype
        \ Ksnippet call <SID>snippet_in_new_window('<bang>', <q-args>)
else
  command! -bang -nargs=?
        \ Ksnippet call <SID>snippet_in_new_window('<bang>', <q-args>)
endif

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

" run command (via :terminal), output to a separate window; :Krun [cmd]... {{{
command! -nargs=* -complete=shellcmd Krun call <SID>run(<q-args>)

function! s:krun_cb(...) dict
  if self.buffer_nr == winbufnr(0) && mode() == 't'
    " vim 8 behavior: exit to normal mode after TermClose.
    call feedkeys("\<C-\>\<C-n>", 'n')
  endif
endfunction

function! s:has_pty()
  if has('unix') || has('nvim')
    return 1
  endif
  if !has_key(s:, 'v_has_pty')
    " Windows XP winpty is buggy
    let s:v_has_pty = match(system('cmd /c ver'), 'Windows XP') < 0
  endif
  return s:v_has_pty
endfunction

function! s:run(args) abort
  if match(a:args, '\v(^|[&|;])\s*\%') >= 0 && executable(expand('%')) && system('head -c 2 ' . shellescape(expand('%'))) !=# '#!'
    call s:echoerr('shebang not set!') | return
  endif
  " expand %
  let cmd = substitute(a:args, '\v(^|\s)@<=(\%(\:[phtre])*)',
        \'\=shellescape(expand(submatch(2)))', 'g')
  " remove trailing whitespace (nvim, [b]ash on Windows)
  let cmd = substitute(cmd, '\v^(.{-})\s*$', '\1', '')

  if !has('unix') && !has('nvim') && !empty(cmd) &&
        \ match(&shell, '\v(pw)@<!sh(|.exe)$') >= 0
    " sh / bash / ..., but not pwsh;
    " To make quote work reliably, it is worth reading:
    " <https://daviddeley.com/autohotkey/parameters/parameters.htm>
    "
    " double all \ before "
    let cmd = substitute(cmd, '\v\\([\\]*")@=', '\\\\', 'g')
    " double trailing \
    let cmd = substitute(cmd, '\v\\([\\]*$)@=', '\\\\', 'g')
    " escape " with \
    let cmd = '"' . escape(cmd, '"') . '"'
  endif

  if !s:has_pty()
    let shell = &shell
    let shellcmdflag = &shellcmdflag
    try
      let &shell = 'cmd.exe'
      let &shellcmdflag = '/s /c'
      if empty(cmd)
        exe '!start' shell
      else
        exe '!start vimrun' shell shellcmdflag cmd
      endif
    finally
      let &shell = shell
      let &shellcmdflag = shellcmdflag
    endtry

    return
  endif

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
    if empty(cmd)
      let args = &shell
    else
      if has('unix')
        let args = [
              \ executable(&shell) && &shellcmdflag ==# '-c' ? &shell : 'sh',
              \ '-c', cmd]
      else
        let args = printf('%s %s %s', &shell, &shellcmdflag, cmd)
      endif
    endif
    call term_start(args, {'curwin': 1})
  endif
endfunction
" }}}

" run vim command; :KvimRun {vim_command}... {{{
command! -nargs=+ -complete=command KvimRun call <SID>vim_run(<q-args>)

function! s:vim_run(args)
  let buf = @"
  sil! let @" = s:execute(a:args)
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

" open a new tmux window (with current directory); :Tmux c/s/v {{{
command! -nargs=1 -bar Tmux call <SID>open_tmux_window(<q-args>)

function! s:open_tmux_window(args)
  let options = {'c': 'neww', 's': 'splitw -v', 'v': 'splitw -h'}
  let option = get(options, a:args)
  if empty(option)
    call s:echoerr('unknown option: ' . a:args . '; valid: ' . join(keys(options), ' / ')) | return
  endif
  if exists("$TMUX")
    call system("tmux " . option . " -c " . shellescape(getcwd()))
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
  let path = getcwd()  " if removed, `:Cd xxx :Krg yyy` will not work.
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
    let buf = bufnr(0)
    try
      " use buffer variable to store cwd if `exe` switch to new window
      let b:vimrc_old_cwd = old_cwd
      exe 'lcd' path
      exe cmd
    finally
      if buf == bufnr(0)
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

" open file from list (order by opened times); <Leader>f {{{
if exists('*json_encode')  " vim8- not supported
  nnoremap <Leader>f :call <SID>choose_filelist()<CR>
  augroup vimrc_filelist
    au!
    au BufNewFile,BufRead,BufWritePost * call s:save_filelist()
  augroup end
endif

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
  setl buftype=nofile noswapfile
  call append(0, map(s:load_filelist(), 'v:val[1]'))
  if empty(getline('.'))
    norm "_dd
  endif
  norm gg
  nnoremap <buffer> <LocalLeader><CR> :call <SID>cd_cur_line()<CR>
  nnoremap <buffer> <CR> :call <SID>edit_cur_line()<CR>
endfunction

let s:filelist_path = get(g:, 'filelist_path', expand('<sfile>:p:h') . '/filelist_path.cache')

function! s:load_filelist()
  try
    let files = readfile(s:filelist_path)
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
  call writefile(f_list[:10000], s:filelist_path)
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
if exists(':tnoremap') == 2
  tnoremap <Nul> <C-\><C-n>
  tnoremap <C-Space> <C-\><C-n>
  if !has('nvim')
    tnoremap <C-w> <C-w>.
  endif
endif

vnoremap <Leader><Tab> :<C-u>KexpandWithCmd

nnoremap <Leader>e :Cdbuffer e <cfile><CR>
nnoremap <Leader>E :e#<CR>

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

" render; write k: v in working buffer and then s/k/v/g;
" <Leader>r or :Render var-name-regex {{{
command! -nargs=? Render call <SID>render(<q-args>)
nnoremap <Leader>r :Render<Space>

" regex \v; this is used to search var in source buffer;
" it's ok to specify var name in render working buffer.
"
" NOTE if var name ends with '_', then eat a char after it;
" e.g. foo_ bar -> :s/foo_./xxx/g
let g:vimrc_render_var = 'XXX[a-z_]+'

function! s:render(...) abort
  if a:0 > 0 && !empty(a:1)
    let var_regex = a:1
  else
    let var_regex = g:vimrc_render_var
  endif
  if exists('b:render_source_buf')
    let buflist = tabpagebuflist()
    let bufidx = index(buflist, b:render_source_buf)
    if bufidx < 0
      " source buffer not found
      return
    endif
    let rules = []
    for line in getline(1, '$')
      let key = matchstr(line, '\v^.{-}(: )@=')
      let value = substitute(line, '\v^.{-}(: )@=: ', '', '')
      if !empty(key) && value !=# line
        call add(rules, [key, value])
      endif
    endfor
    exe bufidx+1 'wincmd w'
    for i in rules
      if !empty(matchstr(i[0], '_$'))
        let eat = '.'
      else
        let eat = ''
      endif
      exe '%' . printf('s/%s%s/%s/g', i[0], eat, escape(i[1], '\&~/'))
    endfor
  else
    let buf = winbufnr(0)
    let vars = []
    for line in getline(1, '$')
      call substitute(line, '\v'.var_regex, '\=add(vars, submatch(0))', 'g')
    endfor
    Ksnippet | setl bufhidden=wipe
    nnoremap <buffer> <LocalLeader>r :call <SID>render()<CR>
    let b:render_source_buf = buf
    let appeared = []
    for i in vars
      if index(appeared, i) < 0
        call append('$', printf('%s: ', i))
        call add(appeared, i)
      endif
    endfor
    norm gg"_dd
  endif
endfunction
" }}}

" gx related {{{
nnoremap <silent> gx :call <SID>gx('n')<CR>
vnoremap <silent> gx :<C-u>call <SID>gx('v')<CR>

" TODO fix quote / escape
function! s:gx_open_cmd(s)
  if executable('xdg-open')
    return ['xdg-open', a:s]
  elseif executable('open')
    return ['open', a:s]
  elseif has('win32')
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
    let open_cmd = a:1 . ' ' . shellescape(text)
  endif
  if empty(open_cmd)
    return
  endif
  if has('nvim')
    call jobstart(open_cmd, {'detach': 1})
  else
    call job_start(open_cmd, {'stoponexit': ''})
  endif
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
  for line in split(text, "\n")
    call append('$', line)
  endfor
  norm gg"_dd

  " NOTE custom map here.
  if executable('qutebrowser')
    nnoremap <buffer> <LocalLeader>s :call <SID>gx_open('qutebrowser')<CR>
  endif
  nnoremap <buffer> <LocalLeader>f :call <SID>gx_open()<CR>
  nnoremap <buffer> <LocalLeader>e :call <SID>gx_vim('e', 'fnameescape')<CR>
  nnoremap <buffer> <LocalLeader>v :call <SID>gx_vim('wincmd p \|')<CR>
  nnoremap <buffer> <LocalLeader>tc :call <SID>gx_vim('Cd', '', ' :Tmux c \| close')<CR>
  nnoremap <buffer> <LocalLeader>ts :call <SID>gx_vim('Cd', '', ' :Tmux s \| close')<CR>
  nnoremap <buffer> <LocalLeader>tv :call <SID>gx_vim('Cd', '', ' :Tmux v \| close')<CR>
endfunction
" }}}

" colorscheme {{{
if !has('unix') && !has('gui_running')  " win32 cmd
  set nocursorcolumn
  color pablo
elseif (has('unix') && $TERM ==? 'linux')  " linux tty
  set bg=dark
else
  if !has('nvim') && !has('gui_running') && exists('&tgc') && $TERM !~ 'xterm'
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
  silent! color base16-dynamic
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

  if has('nvim')
    GuiTabline 0
  endif

  " light theme
  set bg=light
  let g:vimrc#loaded_gui = 1
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

" remote system() {{{
function! System(cmd, ...) abort
  let host = get(g:, 'vimrc_system_host', '10.0.2.2')
  let port = get(g:, 'vimrc_system_port', '8001')
  if !has('unix')
    " on Windows, busybox-w32 is easier to get than curl
    if match(&shell, 'busybox\s*sh') >= 0
      let arg = printf('nc %s %s | tail -n 1', host, port)
    elseif executable('busybox')
      let arg = printf('busybox sh -c "nc %s %s | tail -n 1"', host, port)
    else
      call s:echoerr('busybox is required!') | return ''
    endif
  else
    " on mac os, curl is easier to get than busybox
    if executable('curl')
      let arg = printf('curl -s %s:%s -H "Content-Type: application/json" -d @-', host, port)
    else
      call s:echoerr('curl is required!') | return ''
    endif
  endif
  let payload = json_encode({'cmd': a:cmd, 'input': a:0 >= 1 ? a:1 : ''})
  if match(arg, '^curl') < 0
    let payload = [
          \ 'POST / HTTP/1.0',
          \ 'Content-Type: application/json',
          \ 'Content-Length: ' . len(payload),
          \ '',
          \ payload,
          \ ]
    let payload = join(payload, "\r\n")
  endif
  let resp = json_decode(system(arg, payload))
  if type(resp) != type({})
    call s:echoerr('response is invalid!') | return ''
  endif
  if resp['exit_code'] == 0
    return resp['stdout']
  else
    call s:echoerr(printf('[%s] %s', resp['exit_code'], resp['stderr'])) | return ''
  endif
endfunction
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
  setl buftype=nofile noswapfile
  call setline(1, $QUTE_COMMANDLINE_TEXT[1:])
  call setline(2, '')
  call setline(3, 'hit `;q` to save cmd (first line) and quit')
  nnoremap <buffer> ;q :call writefile(['set-cmd-text -s :' . getline(1)], $QUTE_FIFO) \| q<CR>
endfunction

" dirvish
let g:loaded_netrwPlugin = 1
au FileType dirvish nmap <buffer> H <Plug>(dirvish_up) | nmap <buffer> L i
" }}}

" finally
nnoremap <Leader><Leader> :nmap <Char-60>Leader<Char-62><CR>
nnoremap <LocalLeader><LocalLeader> :nmap <Char-60>LocalLeader<Char-62><CR>

" vim: fdm=marker
