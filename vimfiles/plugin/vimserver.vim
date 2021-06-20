" Intro:
"   - inside terminal, open vim buffer in outside vim.
"   - communicate with vim from terminal inside vim.
"
" Requirement:
"   - vim 8 (job feature);
"
"   - vimserver-helper binary;
"   see vimserver-helper/README.md for build instruction.
"   - socat is also supported as fallback
"   (jq may be useful for json serialization).
"
" Usage: none. It just works (once requirements meet).
"
" TODO
" - allow passing non-string argument in terminal-api mode.

if &cp
  set nocp
endif

" common func {{{
let s:is_win32 = has('win32')

if s:is_win32
  let s:vimserver_exe = expand('<sfile>:p:h') . '\vimserver-helper\vimserver-helper.exe'
  " fallback to vimserver-helper in $PATH if not found in sfile
  if !executable(s:vimserver_exe)
    let s:vimserver_exe = 'vimserver-helper'
  endif
else
  let s:vimserver_exe = expand('<sfile>:p:h') . '/vimserver-helper/vimserver-helper'
  if !executable(s:vimserver_exe)
    let s:vimserver_exe = 'socat'
  endif
endif

if s:vimserver_exe != 'socat'
  let $VIMSERVER_BIN = s:vimserver_exe
endif

function! s:cmd_server(id)
  if s:vimserver_exe != 'socat'
    return [s:vimserver_exe, a:id, 'listen']
  else
    return ['socat', printf('unix-l:%s,fork', a:id), 'stdout']
  endif
endfunction

function! s:cmd_client(id)
  if s:vimserver_exe != 'socat'
    return [s:vimserver_exe, a:id]
  else
    return ['socat', 'stdin', 'unix-connect:' . a:id]
  endif
endfunction

function! s:echoerr(msg)
  echohl ErrorMsg
  echon a:msg
  echohl None
endfunction

function! s:system(cmd, stdin)
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

function! vimserver#main() abort
  if !has('vim_starting')
    return
  endif
  if !executable(s:vimserver_exe)
    echoerr 'vimserver executable not found!'
    return
  endif
  if empty($VIMSERVER_ID)
    call s:server()
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

function! s:server_clients_cleaner(...)
  for key in keys(s:clients)
    if winbufnr(key) == -1
      call s:clients[key]()
      call remove(s:clients, key)
    endif
  endfor
endfunction

function! s:server_handler(channel, msg) abort
  let data = json_decode(a:msg)

  " terminal-api
  if type(data) == type([])
    if len(data) < 3 || data[0] != 'call' || type(data[2]) != type([])
      echoerr 'vimserver: invalid format!' | return
    endif
    if match(data[1], '^Tapi_') < 0
      echoerr 'vimserver: function not in whitelist!' | return
    endif
    " data: ['call', funcname, argument, optional-pid]
    " pid SHOULD NOT be trusted!
    let pid = len(data) == 4 ? str2nr(data[3]) : -1
    let buffer = -1
    for l:i in term_list()
      if job_info(term_getjob(l:i)).process == pid
        let buffer = l:i
        break
      endif
    endfor
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
  let job = job_start(s:cmd_server(bind_name),
        \ #{callback: function('s:server_handler')})
  let $VIMSERVER_ID = bind_name
  augroup vimserver_clients_cleaner
    au!
    au WinEnter * call s:server_clients_cleaner()
  augroup END
endfunction

function! s:client_handler(channel, msg) abort
  let job = ch_getjob(a:channel)
  call job_stop(job)
endfunction

function! s:client(server_id) abort
  let bind_name = tempname()
  let job = job_start(s:cmd_server(bind_name),
        \ #{callback: function('s:client_handler')})
  let client = bind_name
  call s:system(
        \ s:cmd_client(a:server_id),
        \ json_encode({
        \  'CLIENT_ID': client, 'ARGV': v:argv, 'CWD': getcwd(),
        \  'ARGU': argv(),
        \ }) . "\n")
  try
    while job_status(job) ==# 'run'
      sleep 1m
    endwhile
  finally
    qall
  endtry
endfunction

" vim:fdm=marker
