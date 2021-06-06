" TODO impl for non-linux: /proc/xxx/fd/0, cat;

if !has('linux')
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
    call s:client($VIMSERVER_ID)
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
  endif
  " requied to make BufHidden match it.
  setl bufhidden=hide
  let b:vimserver_post_func = { ->
        \ system(
        \ printf('printf %%s"\n" %s > /proc/%s/fd/0',
        \ shellescape(json_encode({'CLIENT_ID': client})),
        \ shellescape(client)))
        \ }
  if !empty(argv)
    echoerr 'open multiple files is not supported!'
  endif
endfunction

function! s:server() abort
  let job = job_start(['cat'], #{callback: function('s:server_handler')})
  let $VIMSERVER_ID = string(job_info(job).process)

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
  let data = json_decode(a:msg)
  let job = ch_getjob(a:channel)
  if string(job_info(job).process) ==# data.CLIENT_ID
    call job_stop(job)
  endif
endfunction

function! s:client(server_id) abort
  let job = job_start(['cat'], #{callback: function('s:client_handler')})
  let client = string(job_info(job).process)
  call system(
        \ printf('printf %%s"\n" %s > /proc/%s/fd/0',
        \ shellescape(json_encode({'CLIENT_ID': client, 'ARGV': v:argv})),
        \ shellescape(a:server_id)))
  while job_status(job) ==# 'run'
    sleep 1m
  endwhile
  qall
endfunction

" vim:fdm=marker
