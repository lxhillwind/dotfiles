if get(g:, 'loaded_sh') || v:version < 703
  finish
endif
let g:loaded_sh = 1

" main {{{1
" common var def {{{2
let s:is_unix = has('unix')
let s:is_win32 = has('win32')
let s:is_nvim = has('nvim')
let s:has_job = exists('*jobstart') || exists('*job_start')
" use job instead of system()
let s:use_job = !s:is_nvim && s:has_job && exists('*bufadd')

function! s:echoerr(msg)
  echohl ErrorMsg
  echon a:msg
  echohl None
endfunction

let s:job_start = s:is_nvim ? 'jobstart' : 'job_start'
let s:term_start = s:is_nvim ? 'termopen' : 'term_start'

let s:file = expand('<sfile>')

" :command def {{{2
" patch-8.0.1089: <range> support.
let s:range_native = has('nvim') || has('patch-8.0.1089')

if s:range_native
  if s:is_win32
    command! -bang -range=0 -nargs=* -complete=custom,s:win32_cmd_list Sh
          \ call s:sh(<q-args>, {'bang': <bang>0,
          \ 'range': <range>, 'line1': <line1>, 'line2': <line2>})
    command! -range=0 -nargs=* -complete=custom,s:win32_cmd_list Terminal
          \ call s:sh(<q-args>, { 'tty': 1, 'newwin': 0,
          \ 'range': <range>, 'line1': <line1>, 'line2': <line2>})
  else
    command! -bang -range=0 -nargs=* -complete=shellcmd Sh
          \ call s:sh(<q-args>, {'bang': <bang>0,
          \ 'range': <range>, 'line1': <line1>, 'line2': <line2>})
    command! -range=0 -nargs=* -complete=shellcmd Terminal
          \ call s:sh(<q-args>, { 'tty': 1, 'newwin': 0,
          \ 'range': <range>, 'line1': <line1>, 'line2': <line2>})
  endif
else
  if s:is_win32
    command! -bang -range=0 -nargs=* -complete=custom,s:win32_cmd_list Sh
          \ call s:sh(<q-args>, {'bang': <bang>0,
          \ 'line1': <line1>, 'line2': <line2>})
    command! -range=0 -nargs=* -complete=custom,s:win32_cmd_list Terminal
          \ call s:sh(<q-args>, { 'tty': 1, 'newwin': 0,
          \ 'line1': <line1>, 'line2': <line2>})
  else
    command! -bang -range=0 -nargs=* -complete=shellcmd Sh
          \ call s:sh(<q-args>, {'bang': <bang>0,
          \ 'line1': <line1>, 'line2': <line2>})
    command! -range=0 -nargs=* -complete=shellcmd Terminal
          \ call s:sh(<q-args>, { 'tty': 1, 'newwin': 0,
          \ 'line1': <line1>, 'line2': <line2>})
  endif
endif

" vimserver tweak {{{2
" store vimserver.vim related environment variable, and delete them from env;
" so that ":!" / "system()" / "job_start()" will not be affected by vimserver.
let s:vimserver_envs = get(s:, 'vimserver_envs', {})
for s:i in ['VIMSERVER_ID', 'VIMSERVER_BIN', 'VIMSERVER_CLIENT_PID']
  if exists('$'.s:i)
    if exists('*getenv')
      let s:vimserver_envs[s:i] = getenv(s:i)
    endif
    execute 'unlet' '$'.s:i
  endif
endfor

" polyfill {{{2
function! s:trim(s, p) abort
  if exists('*trim')
    return trim(a:s, a:p)
  else
    let end = match(a:s, '\V' . escape(a:p, '\/') . '\+\$')
    if end >= 0
      return a:s[0:end-1]
    else
      return a:s
    endif
  endif
endfunction

function! s:nvim_exit_cb(...) dict
  if self.buffer_nr == winbufnr(0) && mode() == 't'
    " vim 8 behavior: exit to normal mode after TermClose.
    call feedkeys("\<C-\>\<C-n>", 'n')
  endif
  if self.close
    let buffers = tabpagebuflist()
    let idx = index(buffers, self.buffer_nr)
    if idx >= 0
      if len(buffers) == 1 && tabpagenr('$') == 1
        quit
      else
        execute idx+1 'wincmd c'
      endif
    endif
  endif
endfunction

function! s:get_fin_term_buffer() abort
  let result = []
  if has('nvim')
    for buffer in getbufinfo()
      let jid = get(buffer.variables, 'terminal_job_id', 0)
      if jid > 0 && jobwait([jid], 0)[0] != -1
        let result = add(result, buffer.bufnr)
      endif
    endfor
  else
    for bufnr in term_list()
      if match(term_getstatus(bufnr), 'finished') >= 0
        let result = add(result, bufnr)
      endif
    endfor
  endif
  return result
endfunction

function! s:sh(cmd, opt) abort " {{{2
  " opt parse {{{
  let opt = {'bang': 0, 'newwin': 1}
  let opt_string = matchstr(a:cmd, '\v^\s*-[a-zA-Z]*')
  let help = ['Usage: [range]Sh [-flags] [cmd...]']
  call extend(help, ['', 'Example:', '  Sh uname -o'])
  call extend(help, ['', 'Supported flags:'])

  call add(help, '  h: display this help')
  let opt.help = match(opt_string, 'h') >= 0

  call add(help, '  v: visual mode (char level)')
  let opt.visual = match(opt_string, 'v') >= 0

  call add(help, '  t: use builtin terminal')
  let opt.tty = match(opt_string, 't') >= 0

  call add(help, '  w: use external terminal')
  let opt.window = match(opt_string, 'w') >= 0

  call add(help, '  c: close terminal after execution')
  let opt.close = match(opt_string, 'c') >= 0

  call add(help, '  b: focus on current buffer (implies -t flag)')
  let opt.background = match(opt_string, 'b') >= 0

  call add(help, '  f: filter, like ":{range}!cmd"')
  let opt.filter = match(opt_string, 'f') >= 0

  call add(help, '  r: like ":[range]read !cmd"')
  let opt.read_cmd = match(opt_string, 'r') >= 0

  let opt = extend(opt, a:opt)

  if opt.background
    let opt.tty = 1
  endif

  if opt.bang
    let opt.tty = 1
  endif

  if opt.help
    echo join(help, "\n")
    return
  endif

  if !s:range_native
    " TODO differ no range / current-line range.
    " use opt.line1 < opt.line2 (instead of !=) since in some version of vim,
    " <line2> is 1 (or 0) unless specified.
    let opt.range = opt.line1 < opt.line2 ?
          \ 2
          \ : (opt.line1 != line('.') ? 1 : 0)
  endif
  " }}}

  " use different variable name for different type; see vim tag 7.4.1546
  let stdin_flag = 0 " {{{
  if opt.visual
    let tmp = @"
    silent normal gvy
    let stdin_s = @"
    let @" = tmp
    unlet tmp
    let stdin = split(stdin_s, "\n")
    if stdin_s[-1:] == "\n"
      let stdin = add(stdin, '')
    endif
    let stdin_flag = 1
    unlet stdin_s
  else
    if get(opt, 'range') == 2
      let stdin = getline(opt.line1, opt.line2)
      let stdin_flag = 1
      let stdin = add(stdin, '')
    elseif get(opt, 'range') == 1
      let stdin = [getline(opt.line1)]
      let stdin_flag = 1
      let stdin = add(stdin, '')
    endif
  endif
  " }}}

  let cmd = a:cmd[len(opt_string):]
  let l:term_name = cmd
  " expand %
  let cmd = substitute(cmd, '\v%(^|\s)\zs(\%(\:[phtreS])*)\ze%($|\s)',
        \ s:is_win32 ?
        \'\=s:shellescape(s:tr_slash(expand(s:trim_S(submatch(1)))))' :
        \'\=shellescape(expand(s:trim_S(submatch(1))))',
        \ 'g')
  let cmd = substitute(cmd, '\v^\s+', '', '')
  " remove trailing whitespace
  let cmd = substitute(cmd, '\v^(.{-})\s*$', '\1', '')

  if empty(cmd) && stdin_flag isnot# 0
    call s:echoerr('pipe to empty cmd is not allowed!') | return
  endif

  if empty(cmd) && !opt.tty && !opt.window
    call s:echoerr('empty cmd (without tty) is not allowed!') | return
  endif

  let shell = exists('g:sh_path') ? g:sh_path :
        \ (s:is_win32 ? 'busybox' : &shell)

  " if set shell to busybox, then call sh with `busybox sh`
  let shell_arg_patch = (match(shell, '\vbusybox(.exe|)$') >= 0) ? ['sh'] : []

  " using system() in vim with stdin will cause writing temp file.
  " on win32, system() will open a new cmd window.
  " so do not use system() if possible.
  if !opt.tty && !opt.window && !s:use_job
    if s:is_win32
      " use new variable is required for old version vim (like 7.2.051),
      " since it has strong type checking for variable redeclare.
      " see tag 7.4.1546
      let cmd_new = [shell] + shell_arg_patch + ['-c', cmd]
      if s:is_nvim
        let cmd = cmd_new
      else
        " ^" is required for system().
        " e.g. system('"busybox" "sh" "-c" "echo"') won't work,
        " but system('^""busybox" "sh" "-c" "echo"') would.
        let cmd = '^"' . s:win32_cmd_list_to_str(cmd_new)
      endif
      unlet cmd_new
    endif

    if stdin_flag is# 0
      return s:post_func(system(cmd), opt)
    else
      " add final [''] to add final newline
      return s:post_func(system(cmd,
            \ has('patch-7.4.247') ? stdin : join(stdin, "\n")
            \ ), opt)
    endif
  endif

  " opt.visual: yank text by `norm gv`;
  " opt.window: communicate stdin by file;
  " s:is_nvim: no in_buf job-option;
  " opt.tty && !opt.newwin: buffer would be destroyed before using;
  if !opt.visual && !opt.window && !s:is_nvim && !(opt.tty && !opt.newwin)
    let stdin_flag = get(opt, 'range') != 0 ? 2 : stdin_flag
  endif
  let job_opt = {}
  if stdin_flag is# 2
    let job_opt = extend(job_opt, #{
          \ in_io: 'buffer',
          \ in_buf: bufnr(),
          \ in_top: opt.line1,
          \ in_bot: opt.line2,
          \ })
  endif

  let tmpfile = '' " {{{
  if stdin_flag is# 1
    let tmpfile = tempname()
    call writefile(stdin, tmpfile, 'b')
  endif

  let keep_window_path = fnamemodify(s:file, ':p:h:h') . '/bin/keep-window.sh'

  if empty(cmd)
    let l:term_name = shell
    let cmd_new = [shell] + shell_arg_patch
  else
    if !empty(tmpfile)
      if s:is_unix
        let cmd_new = [shell] + shell_arg_patch + ['-c', printf('sh -c %s < %s',
              \ shellescape(cmd), shellescape(tmpfile))]
      else
        let cmd_new = [shell] + shell_arg_patch + ['-c', printf('sh -c %s < %s',
              \ s:shellescape(cmd), s:shellescape(s:tr_slash(tmpfile)))]
      endif
    else
      let cmd_new = [shell] + shell_arg_patch + ['-c', cmd]
    endif
  endif
  unlet cmd
  let cmd = cmd_new
  unlet cmd_new
  " }}}

  if opt.window " {{{
    let context = {'shell': shell, 'shell_arg_patch': shell_arg_patch,
          \ 'cmd': cmd, 'close': opt.close,
          \ 'start_fn': s:is_win32 ? function('s:win32_start') : function('s:unix_start'),
          \ 'term_name': l:term_name,
          \ 'keep_window_path': keep_window_path}

    for s:program in (exists('g:sh_programs') ? g:sh_programs :
          \ ['alacritty', 'urxvt', 'mintty', 'cmd',]
          \ )
      if type(s:program) == type(function('tr'))
        :
      elseif type(s:program) == type('')
        let s:program = 's:program_' . s:program
        if !exists('*' . s:program)
          continue
        endif
      else
        continue
      endif
      if call(s:program, [context])
        return
      endif
    endfor

    call s:echoerr('Sh: -w option not supported! wrong `g:sh_programs`?')
    return
  endif
  " }}}

  if s:is_win32 && !s:is_nvim
    let cmd_new = s:win32_cmd_list_to_str(cmd)
    unlet cmd
    let cmd = cmd_new
    unlet cmd_new
  endif

  if opt.tty " {{{
    let buf_idx = -1
    if opt.bang
      let term_buffers = s:get_fin_term_buffer()
      let buflist = tabpagebuflist()
      for buf in term_buffers
        let buf_idx = index(buflist, buf)
        if buf_idx >= 0
          exe buf_idx + 1 . 'wincmd w'
          break
        endif
      endfor
    endif
    if opt.newwin && buf_idx < 0
      execute 'bel' &cmdwinheight . 'split'
    endif

    let job_opt = extend(job_opt, {'curwin': 1, 'term_name': l:term_name})
    if opt.close
      let job_opt = extend(job_opt, {'term_finish': 'close'})
    endif
    let job_opt = extend(job_opt, {'env': s:vimserver_envs})
    if s:is_nvim
      enew
      let job_opt = extend(job_opt,
            \{'buffer_nr': winbufnr(0),
            \'close': opt.close,
            \'on_exit': function('s:nvim_exit_cb')})
    endif
    let job = function(s:term_start)(cmd, job_opt)
    if s:is_nvim
      if opt.background
        " use au to trigger entering insert mode.
        let b:sh_enter_insert_mode = 1
      else
        startinsert " comment to fix hl
      endif
    endif
    if opt.background
      wincmd p
    endif

    return job
  endif
  " }}}

  " no tty {{{
  let bufnr = bufadd('')
  call bufload(bufnr)
  let job_opt = extend(job_opt, {
        \'out_io': 'buffer', 'out_msg': 0, 'out_buf': bufnr,
        \'err_io': 'buffer', 'err_msg': 0, 'err_buf': bufnr,
        \})
  let job = job_start(cmd, job_opt)

  try
    while job_status(job) ==# 'run'
      sleep 1m
    endwhile
  catch /^Vim:Interrupt$/
    call s:stop_job(job)
  endtry
  if job_status(job) ==# 'run'
    sleep 50m
    if job_status(job) ==# 'run'
      echo 'job is still running. press <C-c> again to force kill it.'
      try
        while job_status(job) ==# 'run'
          sleep 1m
        endwhile
        redrawstatus | echon ' job finished.'
      catch /^Vim:Interrupt$/
        call s:stop_job(job, 1)
        redrawstatus | echon ' job force killed.'
      endtry
    endif
  endif
  " }}}

  " line buffer workaround.
  " get 30m in this way:
  "   " in an empty scratch buffer
  "   call job_start(['printf', 'ok'], #{out_io: 'buffer', out_buf: bufnr()}) | sleep 30m | echo getbufline(bufnr(), 1, '$')
  sleep 30m
  let result = getbufline(bufnr, 1, '$')
  execute bufnr . 'bwipeout!'
  return s:post_func(result, opt)
endfunction

" util func {{{2
function! s:trim_S(modifier) abort
  return substitute(a:modifier, ':S$', '', '')
endfunction

function! s:stop_job(job, ...) abort
  if a:0 > 0 && a:1 == 1
    call job_stop(a:job, 'kill')
  else
    call job_stop(a:job, 'int')
  endif
endfunction

function! s:unix_start(cmdlist, ...) abort
  if s:has_job
    call function(s:job_start)(a:cmdlist)
  else
    let bg_helper_path = fnamemodify(s:file, ':p:h:h') . '/bin/background.sh'
    let cmdlist = [bg_helper_path] + a:cmdlist
    call system(join(map(cmdlist, 'shellescape(v:val)'), ' '))
  endif
endfunction

function! s:post_func(result, opt) abort
  let opt = a:opt
  if opt.filter || opt.read_cmd
    let result = type(a:result) == type('') ? split(a:result, "\n") : a:result
    if opt.filter
      call s:filter(result, opt)
    elseif opt.read_cmd
      call s:read_cmd(result, opt)
    endif
  else
    let result = type(a:result) == type([]) ? join(a:result, "\n") : a:result
    redraws | echon s:trim(result, "\n")
    return 0
  endif
endfunction

" -w program {{{2
function! s:program_alacritty(context) abort
  let [cmd, close, keep_window_path] = [a:context.cmd, a:context.close, a:context.keep_window_path]
  if executable('alacritty')
    let cmd = close ? cmd : [keep_window_path] + cmd
    call a:context.start_fn(['alacritty', '-e'] + cmd)
    return 1
  endif
endfunction

function! s:program_urxvt(context) abort
  let [cmd, close, keep_window_path] = [a:context.cmd, a:context.close, a:context.keep_window_path]
  if executable('urxvt')
    let cmd = close ? cmd : [keep_window_path] + cmd
    call a:context.start_fn(['urxvt', '-e'] + cmd)
    return 1
  endif
endfunction

function! s:program_cmd(context) abort
  if s:is_unix | return 0 | endif

  let [shell, shell_arg_patch, cmd, close, keep_window_path] = [a:context.shell, a:context.shell_arg_patch, a:context.cmd, a:context.close, a:context.keep_window_path]
  if !close
    let cmd = [shell] + shell_arg_patch + [keep_window_path] + cmd
  endif
  call a:context.start_fn(cmd, {'term_name': a:context.term_name})
  return 1
endfunction

function! s:program_mintty(context) abort
  let [shell, cmd, close, keep_window_path] = [a:context.shell, a:context.cmd, a:context.close, a:context.keep_window_path]
  " prefer mintty in the same dir of shell.
  let mintty_path = substitute(shell, '\v([\/]|^)\zs(zsh|bash)\ze(\.exe|"?$)', 'mintty', '')
  if mintty_path ==# shell || !executable(mintty_path)
    let mintty_path = 'mintty'
  endif

  if executable(mintty_path)
    let cmd = [mintty_path] + (close ? [] : [keep_window_path]) + cmd
    call a:context.start_fn(cmd)
    return 1
  endif
endfunction

" nvim polyfill {{{2
if s:is_nvim
  augroup sh_insert_mode_patch
    function! s:insert_mode_patch()
      if exists('b:sh_enter_insert_mode')
        unlet b:sh_enter_insert_mode
        startinsert
      endif
    endfunction

    au!
    au BufEnter term://* call s:insert_mode_patch()
  augroup END
endif

function! s:filter(result, opt) abort " {{{2
  let opt = a:opt
  let previous = @"
  try
    let @" = join(a:result, "\n")
    if opt.visual
      normal gvP
    else
      let first = 1 == opt.line1
      let last = line('$') == opt.line2
      execute 'normal' opt.line1 . 'gg'
      execute 'normal' opt.line2 - opt.line1 + 1 . '"_dd'
      if last
        if first
          normal P
        else
          execute 'normal' "o\<Esc>P"
        endif
      else
        execute 'normal' "O\<Esc>P"
      endif
    endif
  finally
    let @" = previous
  endtry
endfunction

function! s:read_cmd(result, opt) abort " {{{2
  let opt = a:opt
  let current = opt.line2
  for line in a:result
    call append(current, line)
    let current += 1
  endfor
endfunction

" win32 polyfill {{{1
if !s:is_win32 | finish | endif

" win32 quote related {{{2
function! s:shellescape(cmd) abort
  return "'" . substitute(a:cmd, "'", "'\"'\"'", 'g') . "'"
endfunction

function! s:tr_slash(text) abort
  return substitute(a:text, '\', '/', 'g')
endfunction

function! s:win32_start(cmdlist, ...) abort
  let cmd = s:win32_cmd_list_to_str(a:cmdlist)
  let term_name = a:0 > 0 ? get(a:1, 'term_name', '') : ''
  " cmd.exe start <title> <program>: quote in <title> seems buggy, so just
  " remove " from it.
  let term_name = substitute(term_name, '"', '', 'g')
  let term_name = s:win32_quote(term_name)
  " use " start" since "start" does not work for old version vim, like 7.3.
  " "start" is handled by vim internally.
  call system(printf(' start %s %s', term_name, s:win32_cmd_exe_quote(cmd)))
endfunction

function! s:win32_cmd_list_to_str(arg)
  return join(map(copy(a:arg), 's:win32_quote(v:val)'), ' ')
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

function! s:win32_cmd_exe_quote(arg)
  " escape for cmd.exe
  return substitute(a:arg, '\v[<>^|&()"]', '^&', 'g')
endfunction

" win32 completion {{{2
let s:busybox_cmdlist = expand('<sfile>:p:h:h') . '/asset/busybox-cmdlist.txt'
function! s:win32_cmd_list(A, L, P)
  " use busybox cmd list even when the shell is not busybox,
  " since $PATH may not contain /usr/bin before invoking shell.
  if empty(get(s:, 'win32_cmd_list_data', 0))
    let s:win32_cmd_list_data = readfile(s:busybox_cmdlist)
  endif
  let exe = s:globpath(substitute($PATH, ';', ',', 'g'), '*.exe', 0, 1)
  call map(exe, 'substitute(v:val, ".*\\", "", "")')
  return join(sort(extend(exe, s:win32_cmd_list_data)), "\n")
endfunction

function! s:globpath(a, b, c, d) abort
  if has('patch-7.4.654')
    return globpath(a:a, a:b, a:c, a:d)
  else
    return split(globpath(a:a, a:b), "\n")
  endif
endfunction

" win32 vim from unix shell will set &shell incorrectly, so restore it
if s:is_win32 && match(&shell, '\v(pw)@<!sh(|.exe)$') >= 0
  let &shell = 'cmd.exe'
  let &shellcmdflag = '/s /c'
  let &shellquote = ''
  silent! let &shellxquote = ''
endif

" cmap <CR> {{{2
if exists('g:sh_win32_cr') && !empty(g:sh_win32_cr)
  cnoremap <CR> <C-\>e<SID>shell_replace()<CR><CR>
else
  finish
endif

" cmdline shell_replace impl {{{2
function! s:shell_replace()
  let cmd = getcmdline()

  if getcmdtype() != ':'
    return cmd
  endif

  if match(cmd, '\v^\s+') >= 0
    " keep if begin with space
    return cmd
  endif

  if match(cmd, '\v^!') >= 0
    let cmd = 'Sh ' . cmd[1:]
  elseif match(cmd, '\v^(r|re|rea|read) !') >= 0
    let idx = matchend(cmd, '\v^(r|re|rea|read) !')
    " whitespace in "cmd[idx :]" is required for old version vim
    let cmd = 'Sh -r ' . cmd[idx :]
  else
    " /{pattern}[/] and ?{pattern}[?] are not always matched since they may be
    " too complex.
    "
    " old version vim (before v8.1.0369) does not support comment in cross line expr;
    " so doc it in one place: {{{
    "
    " ```
    " let range_str = '('
    "       \ . '('
    "       "\ number
    "       \ . '[0-9]+'
    "       "\ . $ %
    "       \ . '|\.|\$|\%'
    "       "\ 't 'T
    "       \ . "|'[a-zA-Z<>]"
    "       "\ \/ \? \&
    "       \ . '|\\\/|\\\?|\\\&'
    "       "\ /{pattern}/ / ?{pattern}?, simple case
    "       \ . '|/.{-}[^\\]/|\?.{-}[^\\]\?'
    "       "\ empty (as .)
    "       \ . '|'
    "       \ . ')'
    "       "\ optional [+-][num]* after range above.
    "       \ . '([+-][0-9]*)?'
    "       \ . ')'
    " let l:range = matchstr(cmd,
    "       \ '\v^\s*' . range_str
    "       "\ (optional,(optional range))
    "       \ . '(,(' . range_str . '|))?'
    "       \ . '\!')
    " ```
    " }}}
    let range_str = '('
          \ . '('
          \ . '[0-9]+'
          \ . '|\.|\$|\%'
          \ . "|'[a-zA-Z<>]"
          \ . '|\\\/|\\\?|\\\&'
          \ . '|/.{-}[^\\]/|\?.{-}[^\\]\?'
          \ . '|'
          \ . ')'
          \ . '([+-][0-9]*)?'
          \ . ')'
    let l:range = matchstr(cmd,
          \ '\v^\s*' . range_str
          \ . '(,(' . range_str . '|))?'
          \ . '\ze(r !|re !|rea !|read !|!)')
    if !empty(l:range)
      let cmd = cmd[len(l:range):]
      let flag = match(cmd, '!') == 0 ? '-f' : '-r'
      let cmd = cmd[match(cmd, '!')+1 :]
      let cmd = printf('%sSh %s %s', l:range, flag, cmd)
    endif
  endif
  return cmd
endfunction
" }}}

" vim:fdm=marker
