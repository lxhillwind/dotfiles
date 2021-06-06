" TODO impl for win32 (socat is not available).

if !executable('socat')
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
  if empty($VIMSERVER_ID)
    call s:server()
  else
    if v:argv[0] ==# 'vim'
      call s:client($VIMSERVER_ID)
    endif
  endif
endfunction

function! s:server_handler(channel, msg) abort
  let data = json_decode(a:msg)
  let client = data.CLIENT_ID
  " TODO handle vimdiff
  let argv = data.ARGV[1:]
  if len(argv) > 0 && index(['+vs', '+sp', '+tabe'], argv[0]) >= 0
    execute argv[0][1:]
    let argv = argv[1:]
  else
    " split by default
    sp
  endif

  if len(argv) > 0
    execute 'e' fnameescape(argv[0])
    let argv = argv[1:]
  else
    enew
  endif
  " requied to make BufHidden match it.
  setl bufhidden=hide
  let b:vimserver_post_func = { ->
        \ system(
        \ printf('socat stdin unix-connect:%s', shellescape(client)),
        \ json_encode({'CLIENT_ID': client}) . "\n")
        \ }
  if !empty(argv)
    echoerr 'open multiple files is not supported!'
  endif
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
        \ json_encode({'CLIENT_ID': client, 'ARGV': v:argv}) . "\n")
  try
    while job_status(job) ==# 'run'
      sleep 1m
    endwhile
  finally
    qall
  endtry
endfunction

" vim:fdm=marker
