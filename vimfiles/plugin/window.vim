" open a new tmux window (with current directory); :Tmux c/s/v

if exists("$TMUX")
  command! -nargs=1 -bar Tmux call <SID>open_tmux_window(<q-args>)
endif

function! s:echoerr(msg)
  echohl ErrorMsg
  echon a:msg
  echohl None
endfunction

function! s:open_tmux_window(args)
  let options = {'c': 'neww', 's': 'splitw -v', 'v': 'splitw -h'}
  let ch = match(a:args, '\s')
  if ch == -1
    let [option, args] = [a:args, '']
  else
    let [option, args] = [a:args[:ch], a:args[ch:]]
  endif
  let option = get(options, trim(option))
  if empty(option)
    call s:echoerr('unknown option: ' . a:args . '; valid: ' . join(keys(options), ' / ')) | return
  endif
  call system("tmux " . option . " -c " . shellescape(getcwd()) . args)
endfunction
