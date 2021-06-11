" TODO impl for win32 (socat is not available).

if &cp
  finish
endif

" common func {{{
function! s:echoerr(msg)
  echohl ErrorMsg
  echon a:msg
  echohl None
endfunction
" }}}

function! vimserver#main() abort
  if !has('vim_starting')
    return
  endif
  if !executable('socat')
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

function! s:server_handler(channel, msg) abort
  let data = json_decode(a:msg)
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
  endif

  " requied to make BufHidden match it; TODO handle multiple files.
  setl bufhidden=hide
  let b:vimserver_post_func = { ->
        \ system(
        \ printf('socat stdin unix-connect:%s', shellescape(client)),
        \ json_encode({'CLIENT_ID': client}) . "\n")
        \ }
endfunction

function! s:server() abort
  let bind_name = tempname()
  let job = job_start(['socat', printf('unix-l:%s,fork', bind_name), 'stdout'],
        \ #{callback: function('s:server_handler')})
  let $VIMSERVER_ID = bind_name

  augroup vimserver_bufhidden_client
    au!
    function! s:post_action()
      if exists('b:vimserver_post_func')
        call b:vimserver_post_func()
      endif
    endfunction
    au BufHidden * call s:post_action()
  augroup END
endfunction

function! s:client_handler(channel, msg) abort
  let job = ch_getjob(a:channel)
  call job_stop(job)
endfunction

function! s:client(server_id) abort
  let bind_name = tempname()
  let job = job_start(['socat', printf('unix-l:%s,fork', bind_name), 'stdout'],
        \ #{callback: function('s:client_handler')})
  let client = bind_name
  call system(
        \ printf('socat stdin unix-connect:%s', shellescape(a:server_id)),
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
