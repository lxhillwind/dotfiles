" simulate click in terminal.
"
" Example:
"   au TerminalOpen * if &buftype ==# 'terminal'
"   \ | nmap <buffer> <CR> <Plug>(jump_to_file)
"   \ | endif

nnoremap <Plug>(jump_to_file) :<C-u>call <SID>jump_to_file()<CR>

" impl {{{
function! s:jump_to_file() abort
  let chunk = matchstr(getline('.'), '\v\s*.+\:[0-9]+\:[0-9]+\:')
  if !empty(chunk)
    call s:jump_flc(chunk)
    return
  endif

  let chunk = matchstr(getline('.'), '\v^\d+:')
  if !empty(chunk)
    call s:jump_rg(chunk)
    return
  endif

  if s:open_file(expand('<cfile>'))
    return
  endif
endfunction

" return 1 if opened; 0 else.
function! s:open_file(name) abort
  let name = a:name
  let name = simplify(fnamemodify(name, ':p'))

  let bufnrs = tabpagebuflist()
  for buffer in getbufinfo()
    if buffer.name !=# name
      continue
    endif
    let idx = index(bufnrs, buffer.bufnr)
    if idx >= 0
      execute idx+1 . 'wincmd' 'w'
      return 1
      break
    endif
  endfor

  " file not found in open windows
  if !filereadable(name)
    return 0
  endif

  echo printf('[%s] file not listed.', name)
  echo 'open it? [s/v/t/N] '
  let action = tolower(nr2char(getchar()))
  let cmd = get({'v': 'vs', 's': 'sp', 't': 'tabe'}, action, '')
  if empty(cmd)
    redraws | echon 'cancelled.'
    return 0
  else
    redraws | execute cmd
  endif
  execute 'e' fnameescape(name)
  return 1
endfunction

" file, line, column (f:l:c:)
function! s:jump_flc(chunk) abort
  let chunk = a:chunk
  let l:i = match(chunk, '\v[0-9]+\:[0-9]+\:$')
  let l:j = match(chunk, '\v[0-9]+\:$')
  let [name, line, col] = [chunk[0:l:i-2], chunk[l:i:l:j-2], chunk[l:j:-2]]
  if s:open_file(name)
    execute 'normal' line . 'G0'
    if col > 1
      execute 'normal' col-1 . 'l'
    endif
  endif
endfunction

" rg: line (l:)
function! s:jump_rg(chunk) abort
  let linenr = line('.')
  let line_in_file = matchstr(getline('.'), '\v^[0-9]+:')[:-2]
  let l:i = 0
  while l:i <= 1000
    let l:i = l:i + 1
    let line = getline(linenr - l:i)
    if match(line, '^\v[0-9]+:') < 0 && filereadable(line)
      " check if filereadable() to avoid breaking on long line;
      " example (first line above 3:xxx should be skipped):
      " filename
      " 1:xxx
      " 2:xxxxxx-
      " xxx
      " 3:xxx
      if s:open_file(line)
        execute 'normal' line_in_file . 'G0'
      endif
      " break even file not found.
      break
    endif
  endwhile
endfunction

" }}}

" vim:fdm=marker
