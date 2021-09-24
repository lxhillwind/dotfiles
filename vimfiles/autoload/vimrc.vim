" vim:fdm=marker

" if !executable('mpc')
"   finish
" endif
" command! Mpc call <SID>mpc()
" select song to play (mpd / mpc) {{{1

let s:type = 'song'

function! vimrc#mpc() abort
  enew | setl filetype=mpc buftype=nofile noswapfile nobuflisted
  let l:buf = bufnr()
  call prop_type_add(s:type, {'bufnr': l:buf})
  let l:i = 1
  for line in split(system('mpc playlist'), "\n")
    call setline(l:i, line)
    call prop_add(l:i, 1, {'type': s:type, 'id': l:i, 'bufnr': l:buf})
    let l:i += 1
  endfor
  nnoremap <buffer> <CR> <cmd>call <SID>play()<CR>
endfunction

function! s:play() abort
  let prop = prop_list(line('.'))
  if len(prop) == 0
    return
  endif

  let prop = prop[-1]
  if prop['type'] ==# s:type
    let l:id = prop['id']
    silent call job_start(printf('mpc play %d', l:id))
  endif
endfunction
" }}}

" if empty($QUTE_FIFO)
"   finish
" endif
" command! KqutebrowserEditCmd call s:qutebrowser_edit_cmd()
" {{{1
function! vimrc#qutebrowser_edit_cmd()
  setl buftype=nofile noswapfile
  call setline(1, $QUTE_COMMANDLINE_TEXT[1:])
  call setline(2, '')
  call setline(3, 'hit `<Space>q` to save cmd (first line) and quit')
  nnoremap <buffer> <Space>q :call writefile(['set-cmd-text -s :' . getline(1)], $QUTE_FIFO) \| q<CR>
endfunction
" }}}

" if exists("$TMUX")
"   command! -nargs=1 -bar Tmux call <SID>open_tmux_window(<q-args>)
" endif
" open a new tmux window (with current directory); :Tmux c/s/v {{{1
function! vimrc#open_tmux_window(args)
  let options = {'c': 'neww', 's': 'splitw -v', 'v': 'splitw -h'}
  let ch = match(a:args, '\s')
  if ch == -1
    let [option, args] = [a:args, '']
  else
    let [option, args] = [a:args[:ch], a:args[ch:]]
  endif
  let option = get(options, trim(option))
  if empty(option)
    throw 'unknown option: ' . a:args . '; valid: ' . join(keys(options), ' / ')
  endif
  call system("tmux " . option . " -c " . shellescape(getcwd()) . args)
endfunction
