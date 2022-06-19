" vim:fdm=marker sw=2

if get(g:, 'loaded_sh') || !has('vim9script')
  finish
endif
let g:loaded_sh = 1

let s:sh_programs = ['alacritty', 'urxvt', 'WindowsTerminal', 'ConEmu', 'mintty', 'cmd', 'tmux', 'tmuxc', 'tmuxs', 'tmuxv', 'konsole']

" main {{{1
" common var def {{{2
let s:is_unix = has('unix')
let s:is_win32 = has('win32')
" TODO on macos, job is much slower than system() when output contains many lines.
" e.g. :echo execute('Sh seq 1 1000')->split("\n")->len()
" will take several seconds to complete.

function! s:echoerr(msg)
  echohl ErrorMsg
  echon a:msg
  echohl None
endfunction

" :command def {{{2
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

" polyfill {{{2
function! s:get_fin_term_buffer() abort
  let result = []
  for bufnr in term_list()
    if match(term_getstatus(bufnr), 'finished') >= 0
      let result = add(result, bufnr)
    endif
  endfor
  return result
endfunction

function! s:sh(cmd, opt) abort " {{{2
  " opt parse {{{
  let opt = {'bang': 0, 'newwin': 1}

  let opt_string = matchstr(a:cmd, '\v^\s*-[a-zA-Z_,=0-9:-]*')
  let cmd = a:cmd[len(opt_string):]
  let opt_string = substitute(opt_string, '\v^\s{-}-', '', '')

  " TODO doc about opt: title
  let opt_dict = {}
  if match(opt_string, '\v[,=]') >= 0
    let tmp = split(opt_string, '\v,+')
    let opt_string = ''
    for i in tmp
      if match(i, '=') < 0
        let opt_string = opt_string . i
      else
        try
          let [k, v] = split(i, '\v^[^=]+\zs\=\ze')
        catch /E688/
          " empty opt will raise, just ignore it.
          continue
        endtry
        if len(k) == 1
          " only add short option.
          let opt_string = opt_string . k
        endif
        let opt_dict[k] = add(get(opt_dict, k, []), v)
      endif
    endfor
  endif
  let help = ['Usage: [range]Sh [-flags] [cmd...]']
  call extend(help, ['', 'Example:', '  Sh uname -o'])
  call extend(help, ['', 'Supported flags:'])

  call add(help, '  h: display this help')
  let opt.help = match(opt_string, 'h') >= 0

  call add(help, '  v: visual mode (char level)')
  let opt.visual = match(opt_string, 'v') >= 0

  call add(help, '  t: use builtin terminal (support sub opt, like this: -t=7split)')
  call add(help, '     sub opt is used as action to prepare terminal buffer')
  let opt.tty = match(opt_string, 't') >= 0

  call add(help, '  w: use external terminal (support sub opt, like this: -w=urxvt,w=cmd)')
  call add(help, '     currently supported: ' . join(s:sh_programs, ', '))
  let opt.window = match(opt_string, 'w') >= 0

  call add(help, '  c: close terminal after execution')
  let opt.close = match(opt_string, 'c') >= 0

  call add(help, '  b: focus on current buffer / window')
  let opt.background = match(opt_string, 'b') >= 0

  call add(help, '  f: filter, like ":{range}!cmd"')
  let opt.filter = match(opt_string, 'f') >= 0

  call add(help, '  r: like ":[range]read !cmd"')
  let opt.read_cmd = match(opt_string, 'r') >= 0

  call add(help, '  n: dry run (echo options passed to job_start)')
  let opt.dryrun = match(opt_string, 'n') >= 0
  if opt.dryrun && !exists('*json_encode')
    throw '-n flag is not supported: function json_encode is missing!'
  endif

  if (opt.tty || opt.window)
    if opt.filter || opt.read_cmd || opt.dryrun
      throw '-t / -w flag is conflict with -f / -r / -n!'
    endif
  endif

  if !!opt.tty + !!opt.window >= 2
    throw '-t / -w flag cannot be used together!'
  endif

  if !!opt.filter + !!opt.read_cmd + !!opt.dryrun >= 2
    throw '-f / -r / -n flag cannot be used together!'
  endif

  let opt = extend(opt, a:opt)

  if opt.bang
    let opt.tty = 1
  endif

  if opt.help
    echo join(help, "\n")
    return
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

  let l:term_name = has_key(opt_dict, 'title') ? opt_dict.title[-1] : cmd
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

  if empty(cmd) && !opt.tty && !opt.window && !opt.dryrun
    call s:echoerr('empty cmd (without tty) is not allowed!') | return
  endif

  let shell = exists('g:sh_path') ? g:sh_path :
        \ (s:is_win32 ? 'busybox' : &shell)

  if !executable(shell)
    call s:echoerr(printf('shell is not found! (`%s`)', shell)) | return
  endif

  " if set shell to busybox, then call sh with `busybox sh`
  let shell_arg_patch = (match(shell, '\vbusybox(.exe|)$') >= 0) ? ['sh'] : []

  " opt.visual: yank text by `norm gv`;
  " opt.window: communicate stdin by file;
  " opt.tty && !opt.newwin: buffer would be destroyed before using;
  if !opt.visual && !opt.window && !(opt.tty && !opt.newwin)
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

  let interactive_shell = empty(cmd)
  if interactive_shell
    if empty(l:term_name)
      " it may be set by title opt already.
      let l:term_name = shell
    endif
    if s:is_win32
      " replace it later.
      let cmd_new = ['sh']
    else
      let cmd_new = [shell]
    endif
  else
    if !empty(tmpfile)
      if s:is_unix
        let cmd_new = ['sh', '-c', printf('sh -c %s < %s',
              \ shellescape(cmd), shellescape(tmpfile))]
      else
        let cmd_new = ['sh', '-c', printf('sh -c %s < %s',
              \ s:shellescape(cmd), s:shellescape(s:tr_slash(tmpfile)))]
      endif
    else
      let cmd_new = ['sh', '-c', cmd]
    endif
  endif
  unlet cmd
  let cmd = cmd_new
  unlet cmd_new
  " }}}

  if opt.window " {{{
    let cmd = opt.close ? cmd : s:cmdlist_keep_window(cmd)
    if s:is_win32
      let cmd = s:win32_sh_replace(shell, shell_arg_patch, cmd)
    endif
    let context = {'shell': shell,
          \ 'cmd': cmd,
          \ 'close': opt.close, 'background': opt.background,
          \ 'start_fn': s:is_win32 ? function('s:win32_start') : function('s:unix_start'),
          \ 'term_name': l:term_name}

    let program_set = []
    if has_key(opt_dict, 'w')
      let program_set = opt_dict.w
    elseif exists('g:sh_programs')
      let program_set = g:sh_programs
    else
      let program_set = s:sh_programs
    endif
    for s:program in program_set
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

  if s:is_win32
    let cmd = s:win32_sh_replace(shell, shell_arg_patch, cmd)
  endif

  if s:is_win32
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
    if buf_idx < 0
      if has_key(opt_dict, 't')
        execute opt_dict.t[-1]
      elseif opt.newwin
        execute 'bel' &cmdwinheight . 'split'
        setl winfixheight
        setl winfixwidth
      endif
    endif

    let job_opt = extend(job_opt, {'curwin': 1, 'term_name': l:term_name})
    if opt.close
      let job_opt = extend(job_opt, {'term_finish': 'close'})
    endif
    " use g:vimserver_env (set in vim-vimserver)
    let job_opt = extend(job_opt, {'env': exists('g:vimserver_env') ? g:vimserver_env : {}})
    let job = term_start(cmd, job_opt)
    if opt.background
      wincmd p
    endif

    return job
  endif
  " }}}

  if opt.dryrun
    echo json_encode(#{cmd: cmd, opt: job_opt})
    return
  endif

  " no tty {{{
  let bufnr = bufadd('')
  call bufload(bufnr)
  let job_opt = extend(job_opt, {
        \'out_io': 'buffer', 'out_msg': 0, 'out_buf': bufnr,
        \'err_io': 'buffer', 'err_msg': 0, 'err_buf': bufnr,
        \})

  let job = job_start(cmd, job_opt)

  try
    " :help dos-CTRL-Break
    " win32 cannot use Ctrl-C to interrupt :sleep, so we run getchar(0)
    " periodically to check if Ctrl-C is pressed. (getchar(0) is non-blocking)
    "
    " TODO feed input into job.
    while job_status(job) ==# 'run'
      sleep 1m
      if getchar(0) == 3
        throw 'Interrupt'
      endif
    endwhile
  catch /\v^(Vim\:|)Interrupt$/
    call s:stop_job(job)
  endtry
  if job_status(job) ==# 'run'
    sleep 50m
    if job_status(job) ==# 'run'
      echo 'job is still running. press <C-c> again to force kill it.'
      try
        while job_status(job) ==# 'run'
          sleep 1m
          if getchar(0) == 3
            throw 'Interrupt'
          endif
        endwhile
        redrawstatus | echon ' job finished.'
      catch /\v^(Vim\:|)Interrupt$/
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
  call job_start(a:cmdlist)
endfunction

" win32 console version does not set tenc; so we try to get it via command.
let s:tenc = ''
let s:tenc_checked = 0

function! s:post_func(result, opt) abort
  let opt = a:opt

  " TODO check cp utf-8?
  if s:is_win32 && !has('gui_running') && empty(&tenc)
        \ && empty(s:tenc) && empty(s:tenc_checked) && !get(opt, 'chcp')
    " set s:tenc_checked first to avoid repeated possibly failed chcp call.
    let s:tenc_checked = 1
    " use opt.chcp to avoid recursive call to s:sh().
    let s:tenc = 'cp' .. s:sh('chcp', #{chcp: 1})->matchstr('\v\d+$')
  endif

  let tenc = !empty(&tenc) ? &tenc : s:tenc

  if opt.filter || opt.read_cmd
    let result = type(a:result) == type('') ? split(a:result, "\n") : a:result

    " fix encoding for non-utf-8
    if s:is_win32 && !empty(tenc)
      " unable to get tenc in console version vim;
      " just use ":!{cmd}" / ":range!{cmd}" then.
      call map(result, 'iconv(v:val, tenc, &enc)')
    endif

    if opt.filter
      call s:filter(result, opt)
    elseif opt.read_cmd
      call s:read_cmd(result, opt)
    endif
  else
    let result = type(a:result) == type([]) ? join(a:result, "\n") : a:result

    if s:is_win32 && get(opt, 'chcp')
      return result
    endif

    if s:is_win32 && !empty(tenc)
      let result = iconv(result, tenc, &enc)
    endif
    redraws | echon trim(result, "\n")
    return 0
  endif
endfunction

function! s:cmdlist_keep_window(cmd) abort
  " NOTE `sh` here may be replaced by correct sh path later (for win32).
  return ['sh', '-c',
        \ '"$@"; if command -v stty >/dev/null; then stty sane; fi; '
        \ . 'echo; echo "Press any key to continue..."; '
        \ . 'if command -v zstyle >/dev/null; then read -q; else read -n 1; fi',
        \ ''] + a:cmd
endfunction

" -w program {{{2
function! s:program_alacritty(context) abort
  let cmd = a:context.cmd
  if executable('alacritty')
    call a:context.start_fn(['alacritty', '-t', a:context.term_name, '-e'] + cmd)
    return 1
  endif
endfunction

function! s:program_urxvt(context) abort
  let cmd = a:context.cmd
  if executable('urxvt')
    call a:context.start_fn(['urxvt', '-title', a:context.term_name, '-e'] + cmd)
    return 1
  endif
endfunction

function! s:program_tmux_main(context) abort dict
  if empty($TMUX) || !executable('tmux')
    return 0
  endif
  let cmd = a:context.cmd
  let background = a:context.background
  let opt = get(self, 'opt', ['neww'])
  if background
    let opt = add(opt, '-d')
  endif
  call a:context.start_fn(['tmux'] + opt + cmd)
  return 1
endfunction

function! s:program_tmux(context) abort
  return {'opt': ['neww'], 'fn': function('s:program_tmux_main')}.fn(a:context)
endfunction

function! s:program_tmuxc(context) abort
  return {'opt': ['neww'], 'fn': function('s:program_tmux_main')}.fn(a:context)
endfunction

function! s:program_tmuxs(context) abort
  return {'opt': ['splitw', '-v'], 'fn': function('s:program_tmux_main')}.fn(a:context)
endfunction

function! s:program_tmuxv(context) abort
  return {'opt': ['splitw', '-h'], 'fn': function('s:program_tmux_main')}.fn(a:context)
endfunction

function! s:program_cmd(context) abort
  if s:is_unix | return 0 | endif

  call a:context.start_fn(a:context.cmd, {'term_name': a:context.term_name})
  return 1
endfunction

function! s:program_WindowsTerminal(context) abort
  if s:is_unix | return 0 | endif
  if !executable('wt') | return 0 | endif
  " NOTE win32 vim seems to resolve path on exepath();
  " wt is located here (according to `busybox which`):
  "   ~/AppData/Local/Microsoft/WindowsApps/wt.exe
  " but in vim, exepath('wt') gives another result (`:p` of which is not even
  " in $PATH).
  " we can even get wt version from exepath().
  if exepath('wt')->match('WindowsTerminal') < 0 | return 0 | endif

  " wt.exe cannot handle this:
  "   wt -- busybox sh -c '"$@";' '' sh
  " because wt use ; as its own seperator.
  " TODO skip this check once
  "   https://github.com/microsoft/terminal/issues/13264
  " is resolved. (use exepath() to extract wt version, then compare)
  if a:context.cmd->match(';') >= 0 | return 0 | endif

  call a:context.start_fn(['wt', 'nt', '--title', a:context.term_name] + a:context.cmd)
  return 1
endfunction

function! s:program_ConEmu(context) abort
  if s:is_unix | return 0 | endif
  if !executable('conemu') | return 0 | endif

  call a:context.start_fn(['conemu', '-title', a:context.term_name, '-run'] + a:context.cmd)
  return 1
endfunction

function! s:program_mintty(context) abort
  let [shell, cmd] = [a:context.shell, a:context.cmd]
  " prefer mintty in the same dir of shell.
  let mintty_path = substitute(shell, '\v([\/]|^)\zs(zsh|bash)\ze(\.exe|"?$)', 'mintty', '')
  if mintty_path ==# shell || !executable(mintty_path)
    let mintty_path = 'mintty'
  endif

  if executable(mintty_path)
    let cmd = [mintty_path, '-t', a:context.term_name] + cmd
    call a:context.start_fn(cmd)
    return 1
  endif
endfunction

function! s:program_konsole(context) abort
  let cmd = a:context.cmd
  if executable('konsole')
    call a:context.start_fn(['konsole', '-p', 'tabtitle=' .. a:context.term_name, '-e'] + cmd)
    return 1
  endif
endfunction

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

function! s:win32_sh_replace(shell, args, cmd) abort
  return [a:shell] + a:args + a:cmd[1 : ]
endfunction

" guess shell if not set {{{2
if !exists('g:sh_path')
  for s:i in [
        \'C:/msys64/usr/bin/zsh.exe',
        \'C:/msys64/usr/bin/bash.exe',
        \'C:/msys32/usr/bin/zsh.exe',
        \'C:/msys32/usr/bin/bash.exe',
        \'C:/Program Files/Git/usr/bin/bash.exe',
        \'C:/Program Files (x86)/Git/usr/bin/bash.exe',
        \]
    if executable(s:i)
      let g:sh_path = s:i
      break
    endif
  endfor
endif

" win32 quote related {{{2
function! s:shellescape(cmd) abort
  return "'" . substitute(a:cmd, "'", "'\"'\"'", 'g') . "'"
endfunction

function! s:tr_slash(text) abort
  return substitute(a:text, '\', '/', 'g')
endfunction

function! s:win32_start(cmdlist, ...) abort
  let cmd = s:win32_cmd_list_to_str(a:cmdlist)

  " "!start" is handled by vim internally; not affected by &shell related
  " setting.
  "
  " but in vim internal:
  "   - escape &sxe (with "^") in user-input-excmd only when &sxq is "(";
  "   - un-escape &sxe in result above unconditionally (&sxq is not checked)
  " so we need to escape &sxe in user-input-excmd manually when &sxq IS NOT
  " "(", then the un-escape step won't un-escape unexpected char.
  "
  " example (before this patch):
  "   set sxq=
  "   " do not reset sxe; keep sxe not empty.
  "   Sh -w printf 'a^@b'  # a^@b is expected, but got a@b
  "   Sh printf 'a^@b'  # got a^@b, since we don't use "!start" here.
  if &sxq !=# "(" && !empty(&sxe)
    let cmd = substitute(cmd, '\v[' .. escape(&sxe, '\]') .. ']', '^&', 'g')
  endif

  silent execute printf('!start %s', cmd)
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

" win32 completion {{{2
function! s:win32_cmd_list(A, L, P)
  " use busybox cmd list even when the shell is not busybox, {{{
  " since $PATH may not contain /usr/bin before invoking shell.
  "
  " generate data with:
  "   busybox | sed -n '/^Cur/,$ p' | tail +2 | tr -d '\n'
  let data = '[, [[, acpid, addgroup, adduser, adjtimex, ar, arch, arp, arping, ash,	awk, base32, base64, basename, bbconfig, bc, beep, blkdiscard, blkid,	blockdev, bootchartd, brctl, bunzip2, busybox, bzcat, bzip2, cal, cat,	chat, chattr, chgrp, chmod, chown, chpasswd, chpst, chroot, chrt, chvt,	cksum, clear, cmp, comm, cp, cpio, crond, crontab, cryptpw, cttyhack,	cut, date, dc, dd, deallocvt, delgroup, deluser, depmod, df, dhcprelay,	diff, dirname, dmesg, dnsd, dnsdomainname, dos2unix, du, dumpkmap,	dumpleases, echo, ed, egrep, eject, env, envdir, envuidgid, ether-wake,	expand, expr, factor, fakeidentd, fallocate, false, fatattr, fbset,	fbsplash, fdflush, fdformat, fdisk, fgconsole, fgrep, find, findfs,	flock, fold, free, freeramdisk, fsck, fsck.minix, fsfreeze, fstrim,	fsync, ftpd, ftpget, ftpput, fuser, getopt, getty, grep, groups,	gunzip, gzip, halt, hd, hdparm, head, hexdump, hexedit, hostid,	hostname, httpd, hwclock, i2cdetect, i2cdump, i2cget, i2cset,	i2ctransfer, id, ifconfig, ifdown, ifenslave, ifplugd, ifup, inetd,	init, inotifyd, insmod, install, ionice, iostat, ip, ipaddr, ipcalc,	ipcrm, ipcs, iplink, ipneigh, iproute, iprule, iptunnel, kbd_mode,	kill, killall, killall5, klogd, less, link, linux32, linux64, linuxrc,	ln, loadfont, loadkmap, logger, login, logname, logread, losetup, lpd,	lpq, lpr, ls, lsattr, lsmod, lsof, lspci, lsscsi, lsusb, lzcat, lzma,	lzopcat, makedevs, makemime, man, md5sum, mdev, mesg, microcom, mkdir,	mkdosfs, mke2fs, mkfifo, mkfs.ext2, mkfs.minix, mkfs.vfat, mknod,	mkpasswd, mkswap, mktemp, modinfo, modprobe, more, mount, mountpoint,	mpstat, mt, mv, nameif, nbd-client, nc, netstat, nice, nl, nmeter,	nohup, nproc, nsenter, nslookup, ntpd, od, openvt, partprobe, passwd,	paste, patch, pgrep, pidof, ping, ping6, pipe_progress, pivot_root,	pkill, pmap, popmaildir, poweroff, powertop, printenv, printf, ps,	pscan, pstree, pwd, pwdx, raidautorun, rdate, rdev, readahead,	readlink, readprofile, realpath, reboot, reformime, renice, reset,	resize, resume, rev, rfkill, rm, rmdir, rmmod, route, rpm2cpio,	rtcwake, run-init, run-parts, runsv, runsvdir, rx, script,	scriptreplay, sed, sendmail, seq, setarch, setconsole, setfattr,	setfont, setkeycodes, setlogcons, setpriv, setserial, setsid,	setuidgid, sh, sha1sum, sha256sum, sha3sum, sha512sum, showkey, shred,	shuf, slattach, sleep, smemcap, softlimit, sort, split, ssl_client,	start-stop-daemon, stat, strings, stty, su, sulogin, sum, sv, svc,	svlogd, svok, swapoff, swapon, switch_root, sync, sysctl, syslogd, tac,	tail, tar, taskset, tc, tcpsvd, tee, telnet, telnetd, test, tftp,	tftpd, time, timeout, top, touch, tr, traceroute, traceroute6, true,	truncate, ts, tty, ttysize, tunctl, tune2fs, ubiattach, ubidetach,	ubimkvol, ubirename, ubirmvol, ubirsvol, ubiupdatevol, udhcpc, udhcpc6,	udhcpd, udpsvd, uevent, umount, uname, uncompress, unexpand, uniq,	unix2dos, unlink, unlzma, unlzop, unshare, unxz, unzip, uptime, usleep,	uudecode, uuencode, vconfig, vi, vlock, volname, watch, watchdog, wc,	wget, which, whoami, whois, xargs, xxd, xz, xzcat, yes, zcat, zcip'
  " }}}
  let exe = globpath(substitute($PATH, ';', ',', 'g'), '*.exe', 0, 1)
  call map(exe, 'substitute(v:val, ".*\\", "", "")')
  return join(sort(extend(exe, split(data, ',\s*'))), "\n")
endfunction
