if get(g:, 'loaded_sh')
  finish
endif
let g:loaded_sh = 1

" common {{{
let s:is_unix = has('unix')
let s:is_win32 = has('win32')
let s:is_nvim = has('nvim')

function! s:echoerr(msg)
  echohl ErrorMsg
  echon a:msg
  echohl None
endfunction

let s:job_start = s:is_nvim ? 'jobstart' : 'job_start'
let s:term_start = s:is_nvim ? 'termopen' : 'term_start'

let s:file = expand('<sfile>')
" }}}

if s:is_win32
  command! -bang -range -nargs=* -complete=custom,s:win32_cmd_list Sh
        \ call s:sh(<q-args>, {'bang': <bang>0,
        \ 'range': <range>, 'line1': <line1>, 'line2': <line2>})
  command! -range -nargs=* -complete=custom,s:win32_cmd_list Terminal
        \ call s:sh(<q-args>, { 'tty': 1, 'newwin': 0,
        \ 'range': <range>, 'line1': <line1>, 'line2': <line2>})
else
  command! -bang -range -nargs=* -complete=shellcmd Sh
        \ call s:sh(<q-args>, {'bang': <bang>0,
        \ 'range': <range>, 'line1': <line1>, 'line2': <line2>})
  command! -range -nargs=* -complete=shellcmd Terminal
        \ call s:sh(<q-args>, { 'tty': 1, 'newwin': 0,
        \ 'range': <range>, 'line1': <line1>, 'line2': <line2>})
endif

" s:sh() impl {{{

" store vimserver.vim related environment variable, and delete them from env;
" so that ":!" / "system()" / "job_start()" will not be affected by vimserver.
let s:vimserver_envs = get(s:, 'vimserver_envs', {})
for s:i in ['VIMSERVER_ID', 'VIMSERVER_BIN', 'VIMSERVER_CLIENT_PID']
  if exists('$'.s:i)
    let s:vimserver_envs[s:i] = getenv(s:i)
    execute 'unlet' '$'.s:i
  endif
endfor

function! s:echo(str, echo) abort
  if a:echo
    redraws | echon trim(a:str, "\n")
    return 0
  else
    return a:str
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

function! s:sh(cmd, opt) abort
  let opt = {'bang': 0, 'newwin': 1}
  " -vtwcb
  let opt_string = matchstr(a:cmd, '\v^\s*-[a-zA-Z]*')

  " visual mode (char level)
  let opt.visual = match(opt_string, 'v') >= 0

  " use builtin terminal
  let opt.tty = match(opt_string, 't') >= 0

  " use external terminal
  let opt.window = match(opt_string, 'w') >= 0

  " close terminal after execution
  let opt.close = match(opt_string, 'c') >= 0

  " focus on current buffer (implies opt.tty)
  let opt.background = match(opt_string, 'b') >= 0

  let opt = extend(opt, a:opt)

  " used in win32 FilterV
  let opt.echo = get(opt, 'echo', 1)

  if opt.background
    let opt.tty = 1
  endif

  if opt.bang
    let opt.tty = 1
  endif

  let stdin = 0
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

  let cmd = a:cmd[len(opt_string):]
  let l:term_name = cmd
  " expand %
  let cmd = substitute(cmd, '\v%(^|\s)\zs(\%(\:[phtre])*)\ze%($|\s)',
        \ s:is_win32 ?
        \'\=s:shellescape(s:tr_slash(expand(submatch(1))))' :
        \'\=shellescape(expand(submatch(1)))',
        \ 'g')
  let cmd = substitute(cmd, '\v^\s+', '', '')
  " remove trailing whitespace
  let cmd = substitute(cmd, '\v^(.{-})\s*$', '\1', '')

  if empty(cmd) && stdin isnot# 0
    call s:echoerr('pipe to empty cmd is not allowed!') | return
  endif

  if empty(cmd) && !opt.tty && !opt.window
    call s:echoerr('empty cmd (without tty) is not allowed!') | return
  endif

  let shell = exists('g:sh_path') ? g:sh_path :
        \ (s:is_win32 ? 'busybox' : &shell)

  " if set shell to busybox, then call sh with `busybox sh`
  let shell_arg_patch = (match(shell, '\vbusybox(.exe|)$') >= 0) ? ['sh'] : []

  if !opt.tty && !opt.window && (s:is_unix || s:is_nvim)
    if s:is_win32
      let cmd = [shell] + shell_arg_patch + ['-c', cmd]
    endif

    if stdin is# 0
      return s:echo(system(cmd), opt.echo)
    else
      " add final [''] to add final newline
      return s:echo(system(cmd, stdin + ['']), opt.echo)
    endif
  endif

  let job_opt = {}
  let tmpfile = ''
  if stdin isnot# 0
    let tmpfile = tempname()
    call writefile(stdin, tmpfile)
  endif

  let keep_window_path = fnamemodify(s:file, ':p:h:h') . '/bin/keep-window.sh'

  if empty(cmd)
    let l:term_name = shell
    let cmd = [shell] + shell_arg_patch
  else
    if !empty(tmpfile)
      if s:is_unix
        let cmd = [shell] + shell_arg_patch + ['-c', printf('sh -c %s < %s',
              \ shellescape(cmd), shellescape(tmpfile))]
      else
        let cmd = [shell] + shell_arg_patch + ['-c', printf('sh -c %s < %s',
              \ s:shellescape(cmd), s:shellescape(s:tr_slash(tmpfile)))]
      endif
    else
      let cmd = [shell] + shell_arg_patch + ['-c', cmd]
    endif
  endif

  if opt.window
    let context = {'shell': shell, 'shell_arg_patch': shell_arg_patch,
          \ 'cmd': cmd, 'close': opt.close,
          \ 'start_fn': s:is_win32 ? function('s:win32_start') : function(s:job_start),
          \ 'term_name': l:term_name,
          \ 'keep_window_path': keep_window_path}

    for s:program in (exists('g:sh_programs') ? g:sh_programs :
          \ ['alacritty', 'urxvt', 'mintty', 'cmd',]
          \ )
      if type(s:program) == v:t_func
        :
      elseif type(s:program) == v:t_string
        let s:program = 's:program_' .. s:program
        if !exists('*' .. s:program)
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

  if s:is_win32 && !s:is_nvim
    let cmd = s:win32_cmd_list_to_str(cmd)
  endif

  if opt.tty
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

  " no tty
  let bufnr = bufadd('')
  call bufload(bufnr)
  let job_opt = extend(job_opt, {
        \'out_io': 'buffer', 'out_msg': 0, 'out_buf': bufnr,
        \'err_io': 'buffer', 'err_msg': 0, 'err_buf': bufnr,
        \})
  let job = job_start(cmd, job_opt)

  while job_status(job) ==# 'run'
    sleep 1m
  endwhile
  let result = join(getbufline(bufnr, 1, '$'), "\n")
  execute bufnr . 'bwipeout!'
  return s:echo(result, opt.echo)
endfunction

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
  if s:is_unix | return 0 | endif

  let [shell, cmd, close, keep_window_path] = [a:context.shell, a:context.cmd, a:context.close, a:context.keep_window_path]
  " prefer mintty in the same dir of shell.
  let mintty_path = substitute(shell, '\v([\/]|^)\zs(zsh|bash)\ze(\.exe|"?$)', 'mintty', '')
  if mintty_path ==# shell || !executable(mintty_path)
    let mintty_path = 'mintty'
  endif

  if executable(mintty_path)
    let cmd = [mintty_path] + (close ? [] : [keep_window_path]) + cmd
    call a:context.start_fn(cmd, {'gui': 1})
    return 1
  endif
endfunction

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
" }}}

" win32: s:sh() helper function; replace :! && :'<,'>! with busybox shell {{{
if !s:is_win32 | finish | endif
cnoremap <CR> <C-\>e<SID>shell_replace()<CR><CR>
command! -nargs=+ -range FilterV call <SID>filterV(<q-args>, <range>, <line1>, <line2>)

function! s:shellescape(cmd) abort
  return "'" . substitute(a:cmd, "'", "'\"'\"'", 'g') . "'"
endfunction

function! s:tr_slash(text) abort
  return substitute(a:text, '\', '/', 'g')
endfunction

function! s:win32_start(cmdlist, ...) abort
  let cmd = s:win32_cmd_list_to_str(a:cmdlist)
  let gui = a:0 > 0 ? get(a:1, 'gui', 0) : 0
  if s:is_nvim || !gui
    let term_name = a:0 > 0 ? get(a:1, 'term_name', '') : ''
    " cmd.exe start <title> <program>: quote in <title> seems buggy, so just
    " remove " from it.
    let term_name = substitute(term_name, '"', '', 'g')
    let term_name = s:win32_quote(term_name)
    call system(printf('start %s %s', term_name, s:win32_cmd_exe_quote(cmd)))
  else
    call term_start(cmd, {'hidden': 1})
  endif
endfunction

let s:busybox_cmdlist = expand('<sfile>:p:h:h') . '/asset/busybox-cmdlist.txt'
function! s:win32_cmd_list(A, L, P)
  " use busybox cmd list even when the shell is not busybox,
  " since $PATH may not contain /usr/bin before invoking shell.
  if empty(get(s:, 'win32_cmd_list_data', 0))
    let s:win32_cmd_list_data = readfile(s:busybox_cmdlist)
  endif
  let exe = globpath(substitute($PATH, ';', ',', 'g'), '*.exe', 0, 1)
  call map(exe, 'substitute(v:val, ".*\\", "", "")')
  return join(sort(extend(exe, s:win32_cmd_list_data)), "\n")
endfunction

" win32 vim from unix shell will set &shell incorrectly, so restore it
if s:is_win32 && match(&shell, '\v(pw)@<!sh(|.exe)$') >= 0
  let &shell = 'cmd.exe'
  let &shellcmdflag = '/s /c'
  let &shellquote = ''
  silent! let &shellxquote = ''
endif

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
    let cmd = printf('put =execute(\"%s\")',
          \ escape(
          \   escape('Sh ' . cmd[idx:], '"\'),
          \ '|"'))
  else
    " /{pattern}[/] and ?{pattern}[?] are not always matched since they may be
    " too complex.
    let range_str = '('
          \ . '('
          "\ number
          \ . '[0-9]+'
          "\ . $ %
          \ . '|\.|\$|\%'
          "\ 't 'T
          \ . "|'[a-zA-Z<>]"
          "\ \/ \? \&
          \ . '|\\\/|\\\?|\\\&'
          "\ /{pattern}/ / ?{pattern}?, simple case
          \ . '|/.{-}[^\\]/|\?.{-}[^\\]\?'
          "\ empty (as .)
          \ . '|'
          \ . ')'
          "\ optional [+-][num]* after range above.
          \ . '([+-][0-9]*)?'
          \ . ')'
    let l:range = matchstr(cmd,
          \ '\v^\s*' . range_str
          "\ (optional,(optional range))
          \ . '(,(' . range_str . '|))?'
          \ . '\!')
    if !empty(l:range)
      let cmd = l:range[:-2] . 'FilterV ' . cmd[len(l:range):]
    endif
  endif
  return cmd
endfunction

function! s:filterV(cmd, range, line1, line2)
  let previous = @"
  try
    let @" = trim(s:sh(a:cmd, {'range': a:range, 'line1': a:line1, 'line2': a:line2, 'echo': 0}), "\n")
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
