" select song to play (mpd / mpc)

if !executable('mpc')
  finish
endif

command! Mpc call <SID>mpc()

let s:type = 'song'

function! s:mpc() abort
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
