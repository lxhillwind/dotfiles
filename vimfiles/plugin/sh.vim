" :Sh / :Terminal / Sh()
"
" Run shell cmd;
" It also fixes quote for sh on win32.
" ":Sh [cmd]..." (use job by default; unless -t is given, which shows output
" in new window)
" or ":Terminal [cmd]..." (use term; use current window)
"
" win32 only: replace ':!' &shell with busybox sh.

" common {{{
let s:is_unix = has('unix')
let s:is_win32 = has('win32')

function! s:echoerr(msg)
  echohl ErrorMsg
  echon a:msg
  echohl None
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
        \ 'shellquote': '',
        \ }

  " win32 vim from unix shell will set &shell incorrectly, so restore it
  if match(&shell, '\v(pw)@<!sh(|.exe)$') >= 0
    let &shell = s:shell_opt_cmd.shell
    let &shellcmdflag = s:shell_opt_cmd.shellcmdflag
    let &shellquote = s:shell_opt_cmd.shellquote
    silent! let &shellxquote = ''
  endif

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
endif
" }}}

command! -bang -range -nargs=* -complete=shellcmd Sh call Sh(<q-args>, {'bang': <bang>0, 'range': <range>, 'line1': <line1>, 'line2': <line2>, 'echo': 1})
command! -range -nargs=* -complete=shellcmd Terminal call Sh(<q-args>, {'range': <range>, 'line1': <line1>, 'line2': <line2>, 'tty': 1, 'newwin': 0})

" Sh() impl {{{
function! s:sh_echo_check(str, cond)
  if !empty(a:cond)
    redraws | echon trim(a:str, "\n")
    return 0
  else
    return a:str
  endif
endfunction

function! Sh(cmd, ...) abort
  let opt = {'visual': 0, 'bang': 0, 'echo': 0,
        \ 'tty': 0, 'close': 0, 'newwin': 1,
        \ 'stdin': 0,}
  " -vtc
  let opt_string = matchstr(a:cmd, '\v^\s*-[a-zA-Z]*')
  let opt.visual = match(opt_string, 'v') >= 0
  let opt.tty = match(opt_string, 't') >= 0
  let opt.close = match(opt_string, 'c') >= 0

  let stdin = 0
  if a:0 > 0
    " a:1: string (stdin) or dict.
    if type(a:1) == type('')
      let stdin = a:1
    else
      let opt = extend(opt, a:1)
      if type(opt.stdin) == type('')
        let stdin = opt.stdin
      endif
    endif
  endif
  if opt.visual
    let tmp = @"
    silent normal gvy
    let stdin = @"
    let @" = tmp
    unlet tmp
  else
    if get(opt, 'range') == 2
      let stdin = getline(opt.line1, opt.line2)
    elseif get(opt, 'range') == 1
      let stdin = getline(opt.line1)
    endif
  endif
  if type(stdin) == type('')
    let stdin = split(stdin, "\n")
  endif

  if opt.tty
    let opt.echo = 0
  endif

  let cmd = a:cmd[len(opt_string):]
  " expand %
  let slash = &shellslash
  try
    if s:is_win32 | set shellslash | endif
    let cmd = substitute(cmd, '\v(^|\s)@<=(\%(\:[phtre])*)',
          \'\=shellescape(expand(submatch(2)))', 'g')
  finally
    if s:is_win32 | let &shellslash = slash | endif
  endtry
  let cmd = substitute(cmd, '\v^\s+', '', '')
  " remove trailing whitespace
  let cmd = substitute(cmd, '\v^(.{-})\s*$', '\1', '')

  if empty(cmd) && stdin isnot# 0
    call s:echoerr('pipe to empty cmd is not allowed!') | return
  endif

  if empty(cmd) && !opt.tty
    call s:echoerr('empty cmd (without tty) is not allowed!') | return
  endif

  if !opt.tty && s:is_unix
    if stdin is# 0
      return s:sh_echo_check(system(cmd), opt.echo)
    else
      " add final [''] to add final newline
      return s:sh_echo_check(system(cmd, stdin + ['']), opt.echo)
    endif
  endif

  if s:is_win32
    let shell = s:shell_opt_sh.shell
    let shellcmdflag = s:shell_opt_sh.shellcmdflag

    if empty(cmd)
      let cmd = shell
    else
      let cmd = s:win32_quote(cmd)
      let cmd = printf('%s %s %s', shell, shellcmdflag, cmd)
    endif
  endif

  let tmpbuf = ''
  if stdin isnot# 0
    let tmpbuf = bufadd('')
    call bufload(tmpbuf)
    let l:idx = 1
    for l:line in stdin
      call setbufline(tmpbuf, l:idx, l:line)
      let l:idx += 1
    endfor
    unlet l:idx
  endif
  let job_opt = {}
  if !empty(tmpbuf)
    let job_opt = extend(job_opt, {'in_io': 'buffer', 'in_buf': tmpbuf})
    if s:is_win32 && opt.tty
      " <C-z>
      let job_opt = extend(job_opt, {'eof_chars': "\x1a"})
    endif
  endif

  if s:is_unix
    if empty(cmd)
      let cmd = split(&shell)
    else
      let cmd =  ['sh', '-c', cmd]
    endif
  endif
  if opt.tty
    let buf_idx = -1
    if !empty(opt.bang)
      let buffers = get(s:, 'sh_buf_cache', [])
      let buflist = tabpagebuflist()
      for buf in buffers
        let buf_idx = index(buflist, buf)
        if buf_idx >= 0
          exe buf_idx + 1 . 'wincmd w'
          break
        endif
      endfor
    endif
    if opt.newwin && buf_idx < 0
      execute 'bot' &cmdwinheight . 'split'
    endif
    let job_opt = extend(job_opt, {'curwin': 1})
    if opt.close
      let job_opt = extend(job_opt, {'term_finish': 'close'})
    endif
    let job = term_start(cmd, job_opt)
    if !empty(opt.bang)
      let s:sh_buf_cache = add(get(s:, 'sh_buf_cache', []), bufnr())
      call filter(s:sh_buf_cache, 'bufexists(v:val)')
    endif
  else
    " TODO handle non-tty stderr
    let job_opt = extend(job_opt, {'out_io': 'buffer', 'out_msg': 0})
    let job = job_start(cmd, job_opt)
  endif
  if !empty(tmpbuf)
    if s:is_win32
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

" win32: replace :! && :'<,'>! with busybox shell {{{
if s:is_win32
  cnoremap <CR> <C-\>e<SID>shell_replace()<CR><CR>
  command! -nargs=+ -range FilterV call <SID>filterV(<q-args>, <range>, <line1>, <line2>)
endif

function! s:shell_replace()
  let cmd = getcmdline()
  if match(cmd, '\v^!') >= 0
    let cmd = 'Sh ' . cmd[1:]
  elseif match(cmd, printf('\v%s\<,%s\>\!', "'", "'")) >= 0
    let cmd = "'<,'>FilterV " . cmd[6:]
  endif
  return cmd
endfunction

function! s:filterV(cmd, range, line1, line2)
  let previous = @"
  try
    let @" = trim(Sh(a:cmd, {'range': a:range, 'line1': a:line1, 'line2': a:line2}), "\n")
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

" vim:fdm=marker