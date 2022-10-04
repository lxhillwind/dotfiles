if exists('g:loaded_vimserver') || !exists('v:argv')
  finish
endif
let g:loaded_vimserver = 1

if &cp
  set nocp
endif

" common func and env prepare {{{
let s:is_nvim = has('nvim')
let s:is_win32 = has('win32')

let s:job_start = function(s:is_nvim ? 'jobstart': 'job_start')
let s:job_stop = function(s:is_nvim ? 'jobstop': 'job_stop')

let s:vimserver_sh_source = expand('<sfile>:p:h:h') . '/source.d/vimserver.sh'
let s:vimserver_exe = expand('<sfile>:p:h:h') . '/vimserver-helper/vimserver-helper'
" fallback to vimserver-helper in $PATH
if !executable(s:vimserver_exe)
  let s:vimserver_exe = 'vimserver-helper'
endif
" fallback to vimserver-helper.zsh
if !executable(s:vimserver_exe)
  if (!s:is_win32 && executable('zsh')) ||
        \ (s:is_win32 && exists('g:vimserver_zsh_path'))
    let s:vimserver_exe = expand('<sfile>:p:h:h') . '/bin/vimserver-helper.zsh'
  else
    " TODO report error?
    finish
  endif
endif

function! s:cmd_server(id) abort
  let sh = match(s:vimserver_exe, '\.zsh$') >= 0 && s:is_win32 ? [g:vimserver_zsh_path] : []
  return sh + [s:vimserver_exe, a:id, 'listen']
endfunction

function! s:cmd_client(id) abort
  let sh = match(s:vimserver_exe, '\.zsh$') >= 0 && s:is_win32 ? [g:vimserver_zsh_path] : []
  return sh + [s:vimserver_exe, a:id]
endfunction

function! s:system(cmd, stdin)
  if s:is_nvim
    return system(a:cmd, a:stdin)
  endif

  " use job instead of system(), since the latter does not work on Windows.
  let tmpbuf = bufadd('')
  call bufload(tmpbuf)
  let l:idx = 1
  for l:line in split(a:stdin, "\n")
    call setbufline(tmpbuf, l:idx, l:line)
    let l:idx += 1
  endfor
  unlet l:idx
  call job_start(a:cmd, {'in_io': 'buffer', 'in_buf': tmpbuf})
  if s:is_win32
    sleep 1m
  endif
  silent execute tmpbuf . 'bd!'
endfunction
" }}}

function! s:reset_vimserver_env()
  unlet $VIMSERVER_SH_SOURCE
  unlet $VIMSERVER_ID
  unlet $VIMSERVER_BIN
  unlet $VIMSERVER_CLIENT_PID
endfunction

function! s:main() abort
  " has('vim_starting') check doesn't work for nvim. bug?
  if get(s:, 'called_main', 0)
    return
  endif
  let s:called_main = 1

  " gvim always starts a vimserver.
  if has('gui_running')
    " unlet env here will execute unconditionally for nvim. bug?
    call s:reset_vimserver_env()
  endif
  if empty($VIMSERVER_ID)
    augroup vimserver
      au!
      au VimEnter * call s:server()
    augroup END
  else
    if !&diff
      call s:client($VIMSERVER_ID)
    endif
  endif
endfunction

function! s:escape(name)
  " fnameescape and escape ~
  return substitute(fnameescape(a:name), '\v^\~(/|$)', '\\&', '')
endfunction

" handle reloading
let s:clients = get(s:, 'clients', {})

function! s:server_clients_cleaner_new(id)
  if !empty(get(s:clients, a:id))
    call s:clients[a:id]()
    call remove(s:clients, a:id)
  endif
endfunction

function! s:server_clients_cleaner(...)
  for key in keys(s:clients)
    if winbufnr(key) == -1
      call s:clients[key]()
      call remove(s:clients, key)
    endif
  endfor
endfunction

function! s:server_handler(channel, msg, ...) abort
  let data = json_decode(a:msg)

  " terminal-api
  if type(data) == type([])
    if len(data) < 3 || data[0] != 'call' || type(data[2]) != type([])
      echoerr 'vimserver: invalid format!' | return
    endif
    if match(data[1], '^Tapi_') < 0
      echoerr 'vimserver: function not in whitelist!' | return
    endif
    " data: ['call', funcname, argument, optional-pid, optional-tty]
    " pid / tty SHOULD NOT be trusted!
    let pid = len(data) >= 4 ? str2nr(data[3]) : -1
    let tty = len(data) == 5 ? data[4] : ''
    if pid is# 0 && len(data) == 4
      " not pid, but tty.
      let pid = -1
      let tty = data[3]
    endif
    let buffer = -1
    if s:is_nvim
      for l:i in getbufinfo()
        if get(l:i.variables, 'terminal_job_pid', 0) == pid
          let buffer = l:i.bufnr
          break
        endif
      endfor
    else
      for l:i in term_list()
        if (!empty(tty) && term_gettty(l:i) == tty)
              \ || job_info(term_getjob(l:i)).process == pid
          " term_gettty() returns empty in win10 (conpty), so also check
          " whether tty is empty here.
          let buffer = l:i
          break
        endif
      endfor
    endif
    call call(data[1], [buffer, data[2]])
    return
  endif

  let client = data.CLIENT_ID
  " TODO handle vimdiff
  let argv = data.ARGV[1:]
  let cwd = data.CWD
  if len(argv) > 0 && index(['+vs', '+sp', '+tabe'], argv[0]) >= 0
    execute argv[0][1:]
    let argv = argv[1:]
  else
    " split by default
    sp
  endif
  execute 'lcd' fnameescape(cwd)
  let argu = data.ARGU
  if !empty(argu)
    execute 'arglocal' join(map(argu, {_, val -> s:escape(val)}), ' ')
  else
    enew
    arglocal | %argdelete
  endif

  let s:clients[win_getid()] = { ->
        \ s:system(
        \ s:cmd_client(client),
        \ json_encode({'CLIENT_ID': client}) . "\n")
        \ }
endfunction

function! s:server() abort
  let bind_name = tempname()
  let job = s:job_start(s:cmd_server(bind_name),
        \ {(s:is_nvim ? 'on_stdout' : 'out_cb'):
        \ function('s:server_handler')})
  " expose variables, since vim-sh plugin will clean these env variable.
  " they may be required in other place (plugin), like popup terminal.
  let g:vimserver_env = {
        \'VIMSERVER_ID': bind_name, 'VIMSERVER_BIN': s:vimserver_exe,
        \'VIMSERVER_SH_SOURCE': s:vimserver_sh_source,
        \}

  augroup vimserver_clients_cleaner
    au!
    if exists('##WinClosed')
      au WinClosed * call s:server_clients_cleaner_new(expand('<amatch>'))
    else
      au WinEnter * call s:server_clients_cleaner()
    endif
  augroup END
endfunction

function! s:client_handler(channel, msg, ...) abort
  let job = s:is_nvim ? a:channel : ch_getjob(a:channel)
  call s:job_stop(job)
endfunction

function! s:client(server_id) abort
  let bind_name = tempname()
  let job = s:job_start(s:cmd_server(bind_name),
        \ {(s:is_nvim ? 'on_stdout' : 'out_cb'):
        \ function('s:client_handler')})
  let client = bind_name
  call s:system(
        \ s:cmd_client(a:server_id),
        \ json_encode({
        \  'CLIENT_ID': client, 'ARGV': v:argv, 'CWD': getcwd(),
        \  'ARGU': argv(),
        \ }) . "\n")
  try
    if s:is_nvim
      while jobwait([job], 0)[0] == -1
        sleep 1m
      endwhile
    else
      while job_status(job) ==# 'run'
        sleep 1m
      endwhile
    endif
  finally
    qall
  endtry
endfunction

call s:main()

" vim:fdm=marker sw=2
