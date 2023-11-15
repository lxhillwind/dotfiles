" vim:fdm=marker sw=2
"
" TODO:
"   - Sh -S (skip_shell) needs more test.
"     - win32 not-existed command (including .com file without suffix) error
"     info is not available;

if get(g:, 'loaded_sh')
  finish
endif
let g:loaded_sh = 1

" "item" or "item|alias"
let s:sh_programs_builtin = ['kitty', 'alacritty|alac', 'konsole|kde', 'xfce4Terminal|xfce', 'urxvt', 'ConEmu|conemu', 'mintty', 'cmd', 'tmux', 'tmuxc', 'tmuxs', 'tmuxv']

" main {{{1
" common var def {{{2
let s:is_win32 = has('win32')

" set s:sh_path_default for win32 later.
let s:sh_path_default = s:is_win32 ? '' : &shell

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
else
  command! -bang -range=0 -nargs=* -complete=shellcmd Sh
        \ call s:sh(<q-args>, {'bang': <bang>0,
        \ 'range': <range>, 'line1': <line1>, 'line2': <line2>})
endif

" polyfill {{{2
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
  let opt = {'bang': 0}

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
        let [k, v] = split(i, '\v^[^=]+\zs\=\ze', 1)
        if len(k) == 1
          " only add short option.
          let opt_string = opt_string . k
        endif
        let opt_dict[k] = add(get(opt_dict, k, []), v)
      endif
    endfor
  endif
  let help = ['Usage: [range]Sh[!] [-flags] [cmd...]']
  call extend(help, ['', 'Example:', '  Sh uname -o'])
  call extend(help, ['', 'Flags parsing rule:', '  "," delimited; if item contains "=", it is used as sub opt; else it is combination of flags'])
  call extend(help, ['', 'Supported flags:'])

  call add(help, '  h: display this help')
  let opt.help = match(opt_string, 'h') >= 0

  call add(help, '  !: (:Sh! ...); try to reuse terminal window (implies -t)')

  call add(help, '  v: visual mode (char level)')
  let opt.visual = match(opt_string, 'v') >= 0

  call add(help, '  t: use builtin terminal (support sub opt, like this: -t=7split)')
  call add(help, '     sub opt is used as action to prepare terminal buffer')
  let opt.tty = match(opt_string, 't') >= 0

  call add(help, '  w: use external terminal (support sub opt, like this: -w=urxvt,w=cmd)')
  call add(help, '     currently supported: ' . join(s:sh_programs_builtin, ', '))
  call add(help, '     order can be controlled by variable `g:sh_programs`')
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

  call add(help, '  S: run command directly, skipping shell')
  let opt.skip_shell = match(opt_string, 'S') >= 0

  call add(help, '  g: open file or run command in background / gui context')
  call add(help, '     implies -S / -w option; use ":!start" in win32, job_start in other systems')
  call add(help, '     when using job_start, open / xdg-open is used when only one arg given.')
  let opt.gui = match(opt_string, 'g') >= 0
  if opt.gui
    let opt.skip_shell = 1
    let opt.window = 1
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

  let opt.range = get(opt, 'range', 0)
  let opt.bang = get(opt, 'bang', 0)

  if opt.bang
    let opt.tty = 1
  endif

  if empty(opt.range) && empty(a:cmd)
    let opt.help = 1
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

  " remove leading whitespace before setting title.
  " trailing whitespace will be trimmed by shell. no need to trim here.
  let cmd = substitute(cmd, '\v^\s+', '', '')
  let l:term_name = has_key(opt_dict, 'title') ? opt_dict.title[-1] : cmd

  " win32 :!start is run without cwd, so give full path.
  " other systems may or may not; but adding :p is not bad.
  if opt.gui && match(cmd, '\v^\%(\:[htreS])*\s*$') >= 0
    let cmd = '%:p' .. matchstr(cmd, '\v^\%\zs(\:[htreS])*\ze\s*$')
  endif

  " expand %
  let cmd = substitute(cmd, '\v%(^|\s)\zs(\%(\:[phtreS])*)\ze%($|\s)',
        \ s:is_win32 ?
        \'\=s:shellescape(s:tr_slash(expand(s:trim_S(submatch(1)))))' :
        \'\=shellescape(expand(s:trim_S(submatch(1))))',
        \ 'g')

  if empty(cmd)
    if stdin_flag isnot# 0
      call s:echoerr('pipe to empty cmd is not allowed!') | return
    endif
    if !opt.tty && !opt.window && !opt.dryrun
      call s:echoerr('empty cmd (without tty) is not allowed!') | return
    endif
    if opt.gui
      call s:echoerr('empty cmd (with -g option) is not allowed!') | return
    endif
    if opt.skip_shell
      call s:echoerr('empty cmd (with -S option) is not allowed!') | return
    endif
  endif

  let shell = exists('g:sh_path') ? g:sh_path : s:sh_path_default
  " if shell is already quoted (executable(shell) is much likely false),
  " then split it to get executable path.
  let shell_list = executable(shell) ? [shell] : s:ShellSplitUnix(shell)

  if !executable(shell_list->get(0, '')) && !opt.skip_shell
    " shell_list may be empty if shell is empty (e.g. win32 when unix shell
    " not found).
    call s:echoerr(printf('Unix shell is not found! (`%s`)', shell)) | return
  endif

  " opt.visual: yank text by `norm gv`;
  " opt.window: communicate stdin by file;
  " opt.tty: buffer would be destroyed before using (if no newwin);
  if !opt.visual && !opt.window && !opt.tty
    let stdin_flag = get(opt, 'range') != 0 && !has('nvim') ? 2 : stdin_flag
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
    if opt.window && opt.skip_shell
      throw '-w / -S option with char-level-input cannot be used together!'
    endif

    let tmpfile = tempname()
    call writefile(stdin, tmpfile, 'b')

    if opt.skip_shell
      let job_opt = extend(job_opt, #{
            \ in_io: 'file',
            \ in_name: tmpfile,
            \ })
    endif
  endif

  let interactive_shell = empty(cmd)
  if interactive_shell
    if empty(l:term_name)
      " it may be set by title opt already.
      let l:term_name = shell
    endif
    let cmd_new = shell_list
  else
    if opt.skip_shell
      let cmd_new = s:ShellSplitUnix(cmd)
    else
      if !empty(tmpfile)
        if !s:is_win32
          let cmd_new = shell_list + ['-c', printf('sh -c %s < %s',
                \ shellescape(cmd), shellescape(tmpfile))]
        else
          let cmd_new = shell_list + ['-c', printf('sh -c %s < %s',
                \ s:shellescape(cmd), s:shellescape(s:tr_slash(s:wsl_path(shell, tmpfile))))]
        endif
      else
        let cmd_new = shell_list + ['-c', cmd]
      endif
    endif
  endif
  unlet cmd
  let cmd = cmd_new
  unlet cmd_new
  " }}}

  if opt.gui " {{{
    if s:is_win32
      if windowsversion() == '5.1'
        let name = cmd[-1]
        if isdirectory(name) || filereadable(name)
          " Windows XP does not like / in path.
          " check isdirectory / filereadable, since s may be url.
          let name = substitute(name, '/', '\', 'g')
          let cmd = add(cmd[ : -2], name)
        endif
      endif
      call s:win32_start(cmd)
      return
    endif

    if len(cmd) == 1
      let cmd_0 = cmd[0]
      if !(executable(cmd_0) && match(cmd_0, '^/') < 0)
        " avoid add open / xdg-open for executable;
        "   like this: Sh -g xfce4-terminal
        if has('mac')
          let cmd = add(['open', '--'], cmd_0)
        elseif executable('xdg-open') && match(cmd_0, '^-') < 0
          " xdg-open does not support --; so let's check if cmd_0 is started
          " with -.
          let cmd = add(['xdg-open'], cmd_0)
        else
          call s:echoerr("don't know how to open. (xdg-open is missing)")
          return
        endif
      endif
    endif
    call s:unix_start(cmd)

    return
  endif
  " }}}

  if opt.window " {{{
    " skip_shell does not care of close option, since it is complex.
    let cmd = opt.close || opt.skip_shell ? cmd : s:cmdlist_keep_window(shell_list, cmd)
    let context = {'shell': shell,
          \ 'interactive_shell': interactive_shell,
          \ 'cmd': cmd,
          \ 'close': opt.close, 'background': opt.background,
          \ 'start_fn': s:is_win32 ? function('s:win32_start') : function('s:unix_start'),
          \ 'term_name': l:term_name}

    let program_set = []
    if has_key(opt_dict, 'w')
      " opt_dict value is list; so here use opt_dict.w instead of
      " [opt_dict.w].
      let program_set = opt_dict.w
    elseif exists('g:sh_programs')
      let program_set = g:sh_programs
    else
      let program_set = s:sh_programs_builtin
    endif
    for s:program in program_set
      if type(s:program) == type(function('tr'))
        :
      elseif type(s:program) == type('')
        for i in s:sh_programs_builtin
          if match(i, '\<' .. s:program .. '\>') >= 0
            let s:program = i
            break
          endif
        endfor
        let s:program = 's:program_' . matchstr(s:program, '\v[^|]+')
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

  " only job api left; for win32 vim, use string instead of list.
  if s:is_win32 && !opt.skip_shell && !has('nvim')
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
      else
        bel split
      endif
    endif

    let job_opt = extend(job_opt, {'curwin': 1, 'term_name': l:term_name})
    if opt.close
      let job_opt = extend(job_opt, {'term_finish': 'close'})
    endif
    " use g:vimserver_env (set in vim-vimserver)
    let job_opt = extend(job_opt, {'env': exists('g:vimserver_env') ? g:vimserver_env : {}})
    if has('nvim')
      enew
    endif
    let job = function(has('nvim') ? 'termopen' : 'term_start')(cmd, job_opt)
    if has('nvim')
      startinsert
    endif
    if opt.background
      wincmd p
      if has('nvim')
	call feedkeys("\<Esc>")
      endif
    endif

    return job
  endif
  " }}}

  if opt.dryrun
    echo json_encode(#{cmd: cmd, opt: job_opt})
    return
  endif

  " no tty && nvim {{{
  if has('nvim')
    " system() in nvim, when args is list, will not call shell (then not
    " affected by &shell setting); so it's ok to use here.
    let result = system(cmd)
    return s:post_func(result, opt)
  endif
  " }}}

  " no tty && !nvim {{{
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

  " line buffer workaround.
  " get 30m in this way:
  "   " in an empty scratch buffer
  "   call job_start(['printf', 'ok'], #{out_io: 'buffer', out_buf: bufnr()}) | sleep 30m | echo getbufline(bufnr(), 1, '$')
  sleep 30m
  let result = getbufline(bufnr, 1, '$')
  execute bufnr . 'bwipeout!'
  return s:post_func(result, opt)
  " }}}
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
  if has('nvim')
    call jobstart(a:cmdlist, {'detach': 1})
  else
    call job_start(a:cmdlist, #{stoponexit: '', in_io: 'null', out_io: 'null', err_io: 'null'})
  endif
endfunction

" win32 console version does not set tenc; so we try to get it explicitly.
let s:tenc = ''

function! s:post_func(result, opt) abort
  let opt = a:opt

  if s:is_win32
        \ && !has('gui_running') && empty(&tenc)
        \ && empty(s:tenc)
    " learned from fzf.vim
    let s:tenc = 'cp' .. libcallnr('kernel32.dll', 'GetACP', 0)
  endif

  if s:is_win32
    let tenc = !empty(&tenc) ? &tenc : s:tenc
    if match(exists('g:sh_path') ? g:sh_path : s:sh_path_default, 'busybox') < 0
      " skip iconv if not using busybox;
      " busybox / mingit has encoding issue; but mingit is not easy to detect.
      let tenc = ''
    endif
  endif

  if opt.filter || opt.read_cmd
    let result = type(a:result) == type('') ? split(a:result, "\n") : a:result

    " fix encoding for non-utf-8
    if s:is_win32 && !empty(tenc)
          \ && opt.read_cmd
      " unable to get tenc in console version vim;
      " just use ":!{cmd}" / ":range!{cmd}" then.
      "
      " only do translation in read_cmd mode, since filter mode input is
      " usually valid utf8 string.
      call map(result, 'iconv(v:val, tenc, &enc)')
    endif

    if opt.filter
      call s:filter(result, opt)
    elseif opt.read_cmd
      call s:read_cmd(result, opt)
    endif
  else
    let result = type(a:result) == type([]) ? join(a:result, "\n") : a:result

    " fix encoding for non-utf-8
    if s:is_win32 && !empty(tenc)
      let result = iconv(result, tenc, &enc)
    endif
    redraws | echon trim(result, "\n")
    return 0
  endif
endfunction

function! s:cmdlist_keep_window(shell_list, cmd) abort
  return a:shell_list + ['-c',
        \ '"$@"; if command -v stty >/dev/null; then stty sane; fi; '
        \ . 'echo; echo "Press any key to continue..."; '
        \ . 'if command -v zstyle >/dev/null; then read -q; else read -n 1; fi',
        \ ''] + a:cmd
endfunction

" util func, pure {{{2
function! s:ShellSplitUnix(s)
    " shlex.split() with unix rule for unix and win32.
    let str = a:s

    let state = 'whitespace'
    let idx = 0
    let ch = ''
    let token = ''
    let result = []

    while idx < len(str)
        let ch = str[idx]
        let idx += 1

        if ch == "'"
            if state == 'raw' || state == 'whitespace'
                let state = 'quote_single'
            elseif state == 'quote_single'
                let state = 'raw'
            else
                let token ..= ch
                if state == 'backslash'
                    let state = 'raw'
                endif
            endif
        elseif ch == '"'
            if state == 'raw' || state == 'whitespace'
                let state = 'quote_double'
            elseif state == 'quote_double'
                let state = 'raw'
            elseif state == 'quote_backslash'
                let token ..= ch
                let state = 'quote_double'
            else
                let token ..= ch
                if state == 'backslash'
                    let state = 'raw'
                endif
            endif
        elseif ch == '\'
            if state == 'quote_double'
                let state = 'quote_backslash'
            elseif state == 'raw' || state == 'whitespace'
                let state = 'backslash'
            elseif state == 'backslash'
                let token ..= '\'
                let state = 'raw'
            elseif state == 'quote_single'
                let token ..= '\'
            elseif state == 'quote_backslash'
                let token ..= '\'
                let state = 'quote_double'
            else
                throw 'vim-sh: invalid state: \'
            endif
        elseif ch =~ '\s'
            if state == 'whitespace'
                " nop
            elseif index(
		  \ ['quote_double', 'quote_single', 'quote_backslash', 'backslash'],
		  \ state) >= 0
                if state == 'quote_backslash'
                    let token ..= '\'
                endif
                let token ..= ch
                if state == 'backslash'
                    let state = 'raw'
                elseif state == 'quote_backslash'
                    let state = 'quote_double'
                endif
            elseif state == 'raw'
                call add(result, token)
                let token = ''
                let state = 'whitespace'
            else
                throw 'vim-sh: invalid state: \s'
            endif
        else
            if state == 'whitespace' || state == 'backslash'
                let state = 'raw'
            elseif state == 'quote_backslash'
                let token ..= '\'
                let state = 'quote_double'
            endif
            let token ..= ch
        endif
    endwhile

    if state == 'raw'
        call add(result, token)
    elseif state == 'whitespace'
        " nop
    else
        throw 'input not legal: state at finish: ' .. state
    endif

    return result
endfunction

" -w program {{{2
function! s:program_kitty(context) abort
  let cmd = a:context.cmd
  if executable('kitty')
    if a:context.interactive_shell
      call a:context.start_fn(['kitty'] + cmd)
    else
      call a:context.start_fn(['kitty', '-T', a:context.term_name] + cmd)
    endif
    return 1
  endif
endfunction

function! s:program_alacritty(context) abort
  let cmd = a:context.cmd
  if executable('alacritty')
    call a:context.start_fn(['alacritty', '--working-directory', getcwd(), '-t', a:context.term_name, '-e'] + cmd)
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
  if !s:is_win32 | return 0 | endif

  call a:context.start_fn(a:context.cmd, {'term_name': a:context.term_name})
  return 1
endfunction

function! s:program_ConEmu(context) abort
  if !s:is_win32 | return 0 | endif
  if executable('ConEmu64')
    let conemu = 'ConEmu64'
  elseif executable('ConEmu')
    let conemu = 'ConEmu'
  else
    return 0
  endif

  call a:context.start_fn([conemu, '-title', a:context.term_name, '-run'] + a:context.cmd)
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

function! s:program_xfce4Terminal(context) abort
  let cmd = a:context.cmd
  if executable('xfce4-terminal')
    let joined_cmd = join(map(cmd, 'shellescape(v:val)'), ' ')
    if a:context.interactive_shell
      call a:context.start_fn(['xfce4-terminal', '-e', joined_cmd])
    else
      call a:context.start_fn(['xfce4-terminal', '-T', a:context.term_name, '-e', joined_cmd])
    endif
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

" default shell detect {{{2
for s:i in [
      \ &shell,
      \ 'C:/msys64/usr/bin/zsh.exe',
      \ 'C:/msys64/usr/bin/bash.exe',
      \ 'C:/msys32/usr/bin/zsh.exe',
      \ 'C:/msys32/usr/bin/bash.exe',
      \ 'C:/Program Files/Git/usr/bin/bash.exe',
      \ 'C:/Program Files (x86)/Git/usr/bin/bash.exe',
      \ 'busybox sh',
      \ ]
  " &shell: check sh but not pwsh.
  if (s:i ==# &shell && match(s:i, '\v(pw)@2<!sh') >= 0)
        \ || (s:i !=# &shell && executable(s:i))
        \ || (s:i ==# 'busybox sh' && executable('busybox'))
    let s:sh_path_default = s:i
    break
  endif
endfor

" win32 quote related {{{2
function! s:shellescape(cmd) abort
  return "'" . substitute(a:cmd, "'", "'\"'\"'", 'g') . "'"
endfunction

function! s:tr_slash(text) abort
  return substitute(a:text, '\', '/', 'g')
endfunction

function! s:win32_start(cmdlist, ...) abort
  let cmd = s:win32_cmd_list_to_str(a:cmdlist)

  if has('nvim')
    let term_name = a:0 > 0 ? get(a:1, 'term_name', '') : ''
    " cmd.exe start <title> <program>: quote in <title> seems buggy, so just
    " remove " from it.
    let term_name = substitute(term_name, '"', '', 'g')
    let term_name = s:win32_quote(term_name)

    " escape rule for cmd.exe
    let cmd = substitute(cmd, '\v[<>^|&()"]', '^&', 'g')

    call jobstart(['cmd', '/s /c start', term_name, cmd])
    return
  endif

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

  " finally, ":!" will interpret '!', '%', '#' specially. let's escape them.
  " :help :!
  let cmd = substitute(cmd, '\v[!%#]', '\\&', 'g')

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

function! s:wsl_path(shell, file) abort
  let [shell, file] = [a:shell, a:file]
  if executable('wsl') && match(shell, 'wsl') >= 0
    let drive = matchstr(file, '\v^[a-zA-Z]\:')->tolower()
    let without_drive = substitute(file, '\v^[a-zA-Z]\:', '', '')
    return '/mnt/' .. drive[ : -2] .. s:tr_slash(without_drive)
  endif
  return file
endfunction
finish  " tests. {{{1
vim9script
# usage: copy these (and function s:ShellSplitUnix definition) to a vim buffer;
# then run with :%source

# data is from cpython source, which "was from shellwords, by Hartmut Goebel".
# "foo#bar\nbaz|foo|baz|" is removed, since we don't support comment.
const posix_data =<< trim END
x|x|
foo bar|foo|bar|
 foo bar|foo|bar|
 foo bar |foo|bar|
foo   bar    bla     fasel|foo|bar|bla|fasel|
x y  z              xxxx|x|y|z|xxxx|
\x bar|x|bar|
\ x bar| x|bar|
\ bar| bar|
foo \x bar|foo|x|bar|
foo \ x bar|foo| x|bar|
foo \ bar|foo| bar|
foo "bar" bla|foo|bar|bla|
"foo" "bar" "bla"|foo|bar|bla|
"foo" bar "bla"|foo|bar|bla|
"foo" bar bla|foo|bar|bla|
foo 'bar' bla|foo|bar|bla|
'foo' 'bar' 'bla'|foo|bar|bla|
'foo' bar 'bla'|foo|bar|bla|
'foo' bar bla|foo|bar|bla|
blurb foo"bar"bar"fasel" baz|blurb|foobarbarfasel|baz|
blurb foo'bar'bar'fasel' baz|blurb|foobarbarfasel|baz|
""||
''||
foo "" bar|foo||bar|
foo '' bar|foo||bar|
foo "" "" "" bar|foo||||bar|
foo '' '' '' bar|foo||||bar|
\"|"|
"\""|"|
"foo\ bar"|foo\ bar|
"foo\\ bar"|foo\ bar|
"foo\\ bar\""|foo\ bar"|
"foo\\" bar\"|foo\|bar"|
"foo\\ bar\" dfadf"|foo\ bar" dfadf|
"foo\\\ bar\" dfadf"|foo\\ bar" dfadf|
"foo\\\x bar\" dfadf"|foo\\x bar" dfadf|
"foo\x bar\" dfadf"|foo\x bar" dfadf|
\'|'|
'foo\ bar'|foo\ bar|
'foo\\ bar'|foo\\ bar|
"foo\\\x bar\" df'a\ 'df"|foo\\x bar" df'a\ 'df|
\"foo|"foo|
\"foo\x|"foox|
"foo\x"|foo\x|
"foo\ "|foo\ |
foo\ xx|foo xx|
foo\ x\x|foo xx|
foo\ x\x\"|foo xx"|
"foo\ x\x"|foo\ x\x|
"foo\ x\x\\"|foo\ x\x\|
"foo\ x\x\\""foobar"|foo\ x\x\foobar|
"foo\ x\x\\"\'"foobar"|foo\ x\x\'foobar|
"foo\ x\x\\"\'"fo'obar"|foo\ x\x\'fo'obar|
"foo\ x\x\\"\'"fo'obar" 'don'\''t'|foo\ x\x\'fo'obar|don't|
"foo\ x\x\\"\'"fo'obar" 'don'\''t' \\|foo\ x\x\'fo'obar|don't|\|
'foo\ bar'|foo\ bar|
'foo\\ bar'|foo\\ bar|
foo\ bar|foo bar|
:-) ;-)|:-)|;-)|
áéíóú|áéíóú|
END

# put s:ShellSplitUnix definition here!
#

var line_nr = 7  # the line of "trim END"
for line in posix_data
    line_nr += 1
    const fields: list<string> = line->split('|')[ : -1]
    try
        const result = ShellSplitUnix(fields[0])
        const expected = fields[1 : ]
        if result != expected
            echo $'line {line_nr}: expected: {string(expected)}; result: {string(result)}'
        endif
    catch /.*/
        echohl Error
        echo $'line {line_nr}: {v:exception}'
        echohl None
    endtry
endfor
