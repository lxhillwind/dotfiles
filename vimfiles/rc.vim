if v:version < 702
  echoerr 'minimum supported vim version: 7.2' | finish
endif

execute 'set rtp^=' . fnameescape(expand('<sfile>:p:h'))
execute 'set rtp+=' . fnameescape(expand('<sfile>:p:h') . '/after')

let mapleader = ' '  " assign before use
let maplocalleader = ' ;'
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
  augroup vimrc_terminal
    au!
    if has('nvim')
      au TermOpen * setl nonu | setl nornu
    elseif exists('##TerminalOpen')
      " nvim paste in terminal mode will leave cursor position not changed;
      " try to simulate this in vim, but failed.
      " NOTE: keymap defined here (terminal [p]aste).
      au TerminalOpen * setl nonu | setl nornu | nnoremap <buffer> p i<C-w>""<C-\><C-n>
    endif
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
" shortmess; show search count message (default in neovim)
set shm-=S

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

" common platform detection
let s:is_unix = has('unix')
let s:is_win32 = has('win32')
let s:is_nvim = has('nvim')
let s:has_gui = has('gui_running')
      \ || (has('unix') && system('uname -s') =~? 'Darwin')
      \ || (!empty($DISPLAY) || !(empty($WAYLAND_DISPLAY)))

" common func {{{
" :echoerr will raise exception (?)
function! s:echoerr(msg)
  echohl ErrorMsg
  echon a:msg
  echohl None
endfunction

" execute() is introduced in Vim 7.4
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

function! s:cmd_exe_quote(arg)
  " escape for cmd.exe
  return substitute(a:arg, '\v[<>^|&()"]', '^&', 'g')
endfunction

" return selected content as a list (preserve visual mode)
function! s:get_lines_in_visual_mode()
  let result = []
  let line_begin = line('v')
  let line_end = line('.')
  let col_begin = col('v')
  let col_end = col('.')
  let mode_ = mode()[0]

  if line_begin > line_end
    let [line_begin, line_end] = [line_end, line_begin]
    if mode_ ==# 'v'
      let [col_begin, col_end] = [col_end, col_begin]
    endif
  endif
  if col_begin > col_end && mode_ ==# "\x16"  " <C-v>
    let [col_begin, col_end] = [col_end, col_begin]
  endif

  for l:line in range(line_begin, line_end)
    if mode_ ==# 'V'
      let result = add(result, getline(l:line))
    elseif mode_ ==# "\x16"  " <C-v>
      let result = add(result, getline(l:line)[col_begin-1:col_end-1])
    else
      if l:line == line_begin
        let result = add(result, getline(l:line)[col_begin-1:])
      elseif l:line == line_end
        let result = add(result, getline(l:line)[:col_end-1])
      else
        let result = add(result, getline(l:line))
      endif
    endif
  endfor
  return result
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

" win32 shell helper {{{
if s:is_win32
  let s:shell_opt_cmd = {
        \ 'shell': 'cmd.exe',
        \ 'shellcmdflag': '/s /c',
        \ 'shellquote': '',
        \ }

  let s:shell_opt_sh = {
        \ 'shell': 'busybox sh',
        \ 'shellcmdflag': '-c',
        \ 'shellquote': s:is_nvim ? '"' : '',
        \ }

  " win32 vim from unix shell will set &shell incorrectly, so restore it
  if match(&shell, '\v(pw)@<!sh(|.exe)$') >= 0
    let &shell = s:shell_opt_cmd.shell
    let &shellcmdflag = s:shell_opt_cmd.shellcmdflag
    let &shellquote = s:shell_opt_cmd.shellquote
    silent! let &shellxquote = ''
  endif
endif

" true if on win32 and posix sh is available
let s:sh_on_win32 = s:is_win32 && executable('busybox')
" }}}

" run command (via :terminal), output to a separate window; :Sh [cmd]...
" On Windows XP (pty doesn't work), a seperate window is used.
" It also fixes quote for sh on win32 {{{
if has('patch-8.0.1089')
  command! -bang -range -nargs=* -complete=shellcmd Sh call Sh(<q-args>, {'bang': <bang>0, 'range': <range>, 'line1': <line1>, 'line2': <line2>})
else
  " not support <range>
  command! -bang -nargs=* -complete=shellcmd Sh call Sh(<q-args>, {'bang': <bang>0})
endif

function! s:krun_cb(...) dict
  if self.buffer_nr == winbufnr(0) && mode() == 't'
    " vim 8 behavior: exit to normal mode after TermClose.
    call feedkeys("\<C-\>\<C-n>", 'n')
  endif
endfunction

function! s:has_pty()
  if s:is_nvim
    return 1
  endif
  if s:is_unix
    if has('terminal')
      return 1
    else
      return 0
    endif
  endif
  if !has_key(s:, 'v_has_pty')
    " Windows XP winpty is buggy
    " call Sh() with -ST and not stdin to avoid recursive call
    let s:v_has_pty = has('terminal') && match(Sh('-ST cmd /c ver'), 'Windows XP') < 0
  endif
  return s:v_has_pty
endfunction

function! s:sh_echo_check(str, cond)
  if !empty(a:cond)
    redraws | echon trim(a:str, "\n")
    return 0
  else
    return a:str
  endif
endfunction

function! s:unix_cmd_to_list(cmd)
  if empty(a:cmd)
    return split(&shell)
  else
    return ['sh', '-c', a:cmd]
  endif
endfunction

function! s:unix_cmd_to_str(cmd)
  return empty(a:cmd) ? &shell : a:cmd
endfunction

function! s:dispatch(cmd)
  if has('nvim')
    return jobstart(a:cmd, {'detach': 1})
  else
    return job_start(a:cmd, {'stoponexit': ''})
  endif
endfunction

function! Sh(cmd, ...) abort
  " shell (-T) only works for vim on win32
  " echo (-e) implies -T.
  " external terminal window (-w) currently only works for vim && nvim on win32.
  let opt = {'tty': 1, 'shell': 1, 'visual': 0, 'bang': 0, 'echo': 0, 'window': 0}
  let stdin = 0
  if a:0 > 0
    " a:1: string (stdin) or dict.
    if type(a:1) == type('')
      let stdin = split(a:1, "\n")
    else
      let opt = extend(opt, a:1)
    endif
  endif

  " -vSTe
  let opt_string = matchstr(a:cmd, '\v^\s*-[a-zA-Z]*')
  let opt.visual = match(opt_string, 'v') >= 0
  let opt.shell = match(opt_string, 'S') < 0
  let opt.tty = match(opt_string, 'T') < 0
  let opt.echo = match(opt_string, 'e') >= 0
  let opt.window = match(opt_string, 'w') >= 0

  if opt.echo
    let opt.tty = 0
  endif

  " NOTE check opt.tty first to avoid recursive call!
  if opt.tty && !s:has_pty()
    let opt.window = 1
  endif

  let cmd = a:cmd[len(opt_string):]
  " expand %
  let slash = &shellslash
  try
    if s:sh_on_win32 | set shellslash | endif
    let cmd = substitute(cmd, '\v(^|\s)@<=(\%(\:[phtre])*)',
          \'\=shellescape(expand(submatch(2)))', 'g')
  finally
    if s:sh_on_win32 | let &shellslash = slash | endif
  endtry
  let cmd = substitute(cmd, '\v^\s+', '', '')
  " remove trailing whitespace (nvim, [b]ash on Windows)
  let cmd = substitute(cmd, '\v^(.{-})\s*$', '\1', '')

  if opt.visual
    let tmp = @"
    silent normal gvy
    let stdin = split(@", "\n")
    let @" = tmp
    unlet tmp
  else
    if get(opt, 'range') == 2
      let stdin = getline(opt.line1, opt.line2)
    endif
  endif

  if empty(cmd) && stdin isnot# 0
    call s:echoerr('pipe to empty cmd is not allowed!') | return
  endif

  " ignore opt.shell for unix.
  if !opt.tty && s:is_unix
    if stdin is# 0
      return s:sh_echo_check(system(cmd), opt.echo)
    else
      " add final [''] to add final newline; (required for nvim?)
      return s:sh_echo_check(system(cmd, stdin + ['']), opt.echo)
    endif
  endif

  if s:is_win32
    let shell = s:shell_opt_sh.shell
    let shellcmdflag = s:shell_opt_sh.shellcmdflag

    if s:is_nvim && !opt.tty
      if opt.shell
        " TODO handle quote / space correctly; handle opt.shell;
        " in neovim, cmd must be passed as list to skip shell.
        let cmd = split(shell) + split(shellcmdflag) + [cmd]
      endif
      if stdin is# 0
        return s:sh_echo_check(system(cmd), opt.echo)
      else
        return s:sh_echo_check(system(cmd, stdin + ['']), opt.echo)
      endif
    endif

    " add a flag
    let l:win32_cmd_empty = 0
    if opt.shell
      " TODO handle cmd.exe?
      if empty(cmd)
        let cmd = shell
        let l:win32_cmd_empty = 1
      else
        let cmd = s:win32_quote(cmd)
        if opt.window || s:is_nvim
          " use cmd.exe if in nvim or vimrun (not in vim terminal)
          let cmd = s:cmd_exe_quote(cmd)
        endif
        let cmd = printf('%s %s %s', shell, shellcmdflag, cmd)
        if opt.window
          if s:is_nvim
            let cmd = 'cmd /c ' . cmd
          else
            let cmd = 'vimrun ' . cmd
          endif
        endif
      endif
    endif
  endif

  let [tmpfile, tmpbuf] = ['', '']
  if stdin isnot# 0
    if opt.window || s:is_nvim
      " from posix standard: utilities/V3_chap02.html#tag_18_02
      if match(cmd, '\v[|&;<>()$`\"' . "'" . '*?[#~=%]') >= 0 && s:is_unix
        let cmd = 'sh -c ' . shellescape(cmd)
      endif
      let tmpfile = tempname()
      call writefile(stdin, tmpfile)
      if opt.window && s:is_win32 && s:is_nvim
        let cmd_suffix = ' ^< ' . shellescape(tmpfile)
      else
        let cmd_suffix = ' < ' . shellescape(tmpfile)
      endif
      let cmd .= cmd_suffix
    else
      let tmpbuf = bufadd('')
      call bufload(tmpbuf)
      let l:idx = 1
      for l:line in stdin
        call setbufline(tmpbuf, l:idx, l:line)
        let l:idx += 1
      endfor
      unlet l:idx
    endif
  endif
  let job_opt = {}
  if !empty(tmpbuf)
    let job_opt = extend(job_opt, {'in_io': 'buffer', 'in_buf': tmpbuf})
    if !s:is_unix && opt.tty
      " <C-z>; nvim won't take job_opt below.
      let job_opt = extend(job_opt, {'eof_chars': "\x1a"})
    endif
  endif

  if opt.window
    "   :help E162
    " to know why :silent
    if s:is_win32
      if s:is_nvim
        if !l:win32_cmd_empty
          let cmd = cmd . ' ^& pause'
        endif
        call s:dispatch(cmd)
      else
        silent exe '!start' cmd
      endif
    else
      if !executable('urxvt') && s:has_gui
        call s:dispatch(['urxvt', '-e'] + s:unix_cmd_to_list(cmd))
      elseif executable('alacritty') && s:has_gui
        call s:dispatch(['alacritty', '-e'] + s:unix_cmd_to_list(cmd))
      elseif !empty($TMUX)
        call s:dispatch(['tmux', 'neww', s:unix_cmd_to_str(cmd)])
      else
        call s:echoerr('-w option is not supported')
      endif
    endif

    return
  endif

  if s:is_unix
    if has('nvim')
      let cmd = s:unix_cmd_to_str(cmd)
    else
      let cmd = s:unix_cmd_to_list(cmd)
  endif
  if opt.tty
    let buf_idx = -1
    if !empty(opt.bang)
      let buffers = get(s:, 'sh_buf_cache', [])
      let buflist = tabpagebuflist()
      for buf in buffers
        let buf_idx = index(buflist, buf)
        if buf_idx >= 0
          " TODO check previous job running
          exe buf_idx + 1 . 'wincmd w'
          break
        endif
      endfor
    endif
    if buf_idx < 0
      Ksnippet | setl bufhidden=wipe
    endif
    if s:is_nvim
      let job_opt = {
            \'on_exit': function('s:krun_cb'),
            \'buffer_nr': winbufnr(0),
            \}
      let job = termopen(cmd, job_opt)
      startinsert  " add a comment to make hl in vim work...
    else
      let job_opt = extend(job_opt, {'curwin': 1})
      let job = term_start(cmd, job_opt)
    endif
    if !empty(opt.bang)
      let s:sh_buf_cache = add(get(s:, 'sh_buf_cache', []), bufnr())
      call filter(s:sh_buf_cache, 'bufexists(v:val)')
    endif
  else
    " nvim calls system() early.
    " TODO handle non-tty stderr
    let job_opt = extend(job_opt, {'out_io': 'buffer', 'out_msg': 0})
    let job = job_start(cmd, job_opt)
  endif
  if !empty(tmpbuf)
    if !s:is_unix
      sleep 1m
    endif
    silent execute tmpbuf . 'bd!'
  endif
  if opt.tty
    return job
  endif

  while job_status(job) ==# 'run'
    sleep 1m
  endwhile
  return s:sh_echo_check(
        \join(getbufline(ch_getbufnr(job, 'out'), 1, '$'), "\n"),
        \opt.echo
        \)
endfunction

" }}}

" vim's *filter*, char level; {VISUAL}:Filter {cmd} {{{
command! -nargs=+ -range -complete=shellcmd Filter call <SID>filter(<q-args>)

function! s:filter(cmd) abort
  let previous = @"
  try
    call s:filter_impl(a:cmd)
  finally
    let @" = previous
  endtry
endfunction

function! s:filter_impl(cmd) abort
  sil normal gvy
  let code = @"
  if a:cmd ==# 'vim'
    let output = s:execute(code)
  else
    let output = Sh('-T ' . a:cmd, code)
  endif
  let @" = trim(output, "\n")
  normal gvp
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
  let ch = match(a:args, '\s')
  if ch == -1
    let [option, args] = [a:args, '']
  else
    let [option, args] = [a:args[:ch], a:args[ch:]]
  endif
  let option = get(options, trim(option))
  if empty(option)
    call s:echoerr('unknown option: ' . a:args . '; valid: ' . join(keys(options), ' / ')) | return
  endif
  if exists("$TMUX")
    call system("tmux " . option . " -c " . shellescape(getcwd()) . args)
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

" open file from list (order by opened times) (see keymap) {{{
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
  if !exists('*json_encode')  " vim8- not supported
    return
  endif
  enew
  " a special filetype
  setl ft=filelist
  call append(0, map(s:load_filelist(), 'v:val[1]'))
  if empty(getline('.'))
    norm "_dd
  endif
  norm gg
endfunction

function! s:filelist_path()
  return get(g:, 'filelist_path', s:filelist_path_default)
endfunction
let s:filelist_path_default = expand('<sfile>:p:h') . '/filelist_path.cache'

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
  if !exists('*json_encode')  " vim8- not supported
    return
  endif
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
" vim72 (linux) bundled netrw will map `gx` anyway, so skip loading it.
let g:loaded_netrwPlugin = 1

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
    let open_cmd = a:1 . ' ' . shellescape(text)
  endif
  if empty(open_cmd)
    return
  endif
  call s:dispatch(open_cmd)
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
if !s:is_unix && !has('gui_running') && !s:is_nvim  " win32 cmd
  set nocursorcolumn
  color pablo
elseif (s:is_unix && $TERM ==? 'linux')  " linux tty
  set bg=dark
else
  if !s:is_nvim && !has('gui_running') && exists('&tgc') && $TERM !~ 'xterm'
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

  if s:is_nvim
    GuiTabline 0
  endif

  let g:vimrc#loaded_gui = 1
endfunction

if s:is_nvim && exists(':GuiTabline') == 2  " nvim gui detect
  augroup vimrc_gui
    au!
    au UIEnter * call <SID>gui_init()
  augroup END
elseif has('gui_running')
  call s:gui_init()
endif
" }}}

" win32: replace :! && :'<,'>! with busybox shell {{{
if s:sh_on_win32
  cnoremap <CR> <C-\>e<SID>shell_replace()<CR><CR>
  command! -nargs=+ -range FilterV call <SID>filterV(<q-args>, <range>, <line1>, <line2>)
endif

function! s:shell_replace()
  let cmd = getcmdline()
  if match(cmd, '\v^!') >= 0
    let cmd = 'Sh -e ' . cmd[1:]
  elseif match(cmd, printf('\v%s\<,%s\>\!', "'", "'")) >= 0
    let cmd = "'<,'>FilterV " . cmd[6:]
  endif
  return cmd
endfunction

function! s:filterV(cmd, range, line1, line2)
  let previous = @"
  try
    let @" = trim(Sh('-T ' . a:cmd, {'range': a:range, 'line1': a:line1, 'line2': a:line2}), "\n")
    let first = 1 == a:line1
    let last = line('$') == a:line2
    execute 'normal' a:line1 . 'gg'
    execute 'normal' a:line2 - a:line1 + 1 . '"_dd'
    if last
      if first
        normal P
      else
        execute 'normal' "o\<Esc>P"
      endif
    else
      execute 'normal' "O\<Esc>P"
    endif
  finally
    let @" = previous
  endtry
endfunction
" }}}

" qutebrowser edit-cmd; :KqutebrowserEditCmd {{{
command! KqutebrowserEditCmd call s:qutebrowser_edit_cmd()

function! s:qutebrowser_edit_cmd()
  setl buftype=nofile noswapfile
  call setline(1, $QUTE_COMMANDLINE_TEXT[1:])
  call setline(2, '')
  call setline(3, 'hit `;q` to save cmd (first line) and quit')
  nnoremap <buffer> ;q :call writefile(['set-cmd-text -s :' . getline(1)], $QUTE_FIFO) \| q<CR>
endfunction
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
  for i in split(s:execute('scriptnames'), "\n")
    let id = substitute(i, '\v^\s*(\d+): .*$', '\1', '')
    let file = substitute(i, '\v^\s*\d+: ', '', '')
    if a:filename ==# expand(file)
      return id
    endif
  endfor
  return 0
endfunction
" hide s:execute output.
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
if exists(':tnoremap') == 2
  tnoremap <C-Space> <C-\><C-n>
  if !s:is_nvim
    tnoremap <C-w> <C-w>.
  endif
endif

nnoremap <Leader>e :Cdbuffer e <cfile><CR>
nnoremap <Leader>E :e#<CR>
" }}}

" filetype setting {{{
augroup vimrc_filetype
  au!
  au BufNewFile,BufRead *.gv setl ft=dot
  au FileType vim setl sw=2
  au FileType yaml setl sw=2 indentkeys-=0#
  au FileType zig setl fp=zig\ fmt\ --stdin
  au FileType markdown setl tw=120

  " quickfix window
  au FileType qf nnoremap <buffer> <silent>
        \ <CR> <CR>:setl nofoldenable<CR>zz<C-w>p
        \| nnoremap <buffer> <leader><CR> <CR>

  " viml completion
  au FileType vim inoremap <buffer> <C-space> <C-x><C-v>

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
    setl buftype=nofile noswapfile
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
    nnoremap <buffer> <LocalLeader>e :call <SID>gx_vim('e', 'fnameescape')<CR>
    nnoremap <buffer> <LocalLeader>v :call <SID>gx_vim('wincmd p \|')<CR>
    nnoremap <buffer> <LocalLeader>tc :call <SID>gx_vim('Cd', '', ' :Tmux c \| close')<CR>
    nnoremap <buffer> <LocalLeader>ts :call <SID>gx_vim('Cd', '', ' :Tmux s \| close')<CR>
    nnoremap <buffer> <LocalLeader>tv :call <SID>gx_vim('Cd', '', ' :Tmux v \| close')<CR>
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
