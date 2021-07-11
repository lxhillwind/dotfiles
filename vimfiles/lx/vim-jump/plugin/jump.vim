if get(g:, 'loaded_jump')
  finish
endif
let g:loaded_jump = 1

nnoremap <Plug>(jump_to_file) :<C-u>call <SID>jump_to_file(v:count)<CR>
vnoremap <Plug>(jump_to_file) :<C-u>call <SID>jump_to_file(v:count, 'v')<CR>

" impl {{{
function! s:jump_to_file(nr, ...) abort
  if a:0 > 0
    try
      let p = @"
      silent normal gvy
      let chunk = @"
    finally
      let @" = p
    endtry
  else
    let chunk = getline('.')
  endif

  let [file, line, col] = ['', '', '']

  if a:nr != 0
    let group = matchlist(chunk, '\v^([0-9]+)\:([0-9]+)\:')
    if !empty(group)
      let [line, col] = [group[1], group[2]]
    else
      let group = matchlist(chunk, '\v^([0-9]+)\:')
      if !empty(group)
        let line = group[1]
      endif
    endif

    if !empty(line)
      let nr = a:nr
      if nr <= len(tabpagebuflist())
        execute nr . 'wincmd w'
      else
        wincmd p
      endif
      call s:jump_lc(line, col)
    else
      redraws | echon 'line / col not found.'
    endif

    return
  endif

  let group = matchlist(chunk, '\v^\s*(..{-})\:([0-9]+)\:([0-9]+)\:')
  if !empty(group)
    let [file, line, col] = [group[1], group[2], group[3]]
    call s:jump_flc(file, line, col)
    return
  endif

  " it also matches line:col:, so need to check if it is file or linenr.
  let group = matchlist(chunk, '\v^\s*(..{-})\:([0-9]+)\:')
  if !empty(group)
    let [file, line] = [group[1], group[2]]
    if filereadable(file)
      call s:jump_flc(file, line, col)
      return
    endif
  endif

  let group = matchlist(chunk, '\v^(\d+)\:(\d+)\:')
  if !empty(group)
    let [line, col] = [group[1], group[2]]
    let file = s:find_filename_above()
    call s:jump_flc(file, line, col)
    return
  endif

  let group = matchlist(chunk, '\v^(\d+)\:')
  if !empty(group)
    let line = group[1]
    let file = s:find_filename_above()
    call s:jump_flc(file, line, col)
    return
  endif

  if a:0 > 0
    redraws | echon 'file not readable / not found.'
    return
  endif

  let file = expand('<cfile>')
  call s:jump_flc(file, line, col)
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
    redraws | echon 'file not readable / not found.'
    return 0
  endif

  echo printf('[%s] file not listed.', name)
  let job_finished = match(term_getstatus(bufnr()), 'finished') >= 0
  if job_finished
    echo 'open it? [s/v/t/N] r[e]use '
  else
    echo 'open it? [s/v/t/N] '
  endif
  let action = tolower(nr2char(getchar()))
  let actions = {'v': 'vs', 's': 'sp', 't': 'tabe'}
  if job_finished
    " 'e' -> dummy
    let actions = extend(actions, {'e': ':'})
  endif
  let cmd = get(actions, action, '')
  if empty(cmd)
    redraws | echon 'cancelled.'
    return 0
  else
    redraws | execute cmd
  endif
  execute 'e' fnameescape(name)
  return 1
endfunction

" line, column
function! s:jump_lc(line, col) abort
  if a:line > 0
    execute 'normal' a:line . 'G0'
  else
    return
  endif
  if a:col > 1
    execute 'normal' a:col-1 . 'l'
  endif
endfunction

" file, line, column
function! s:jump_flc(file, line, col) abort
  if s:open_file(a:file)
    call s:jump_lc(a:line, a:col)
  endif
endfunction

" rg: find filename
function! s:find_filename_above() abort
  let linenr = line('.')
  let l:i = 0
  while l:i <= 1000
    let l:i = l:i + 1
    let filename = getline(linenr - l:i)
    if match(filename, '^\v[0-9]+:') < 0 && filereadable(filename)
      " check if filereadable() to avoid breaking on long line;
      " example (first line above 3:xxx should be skipped):
      " filename
      " 1:xxx
      " 2:xxxxxx-
      " xxx
      " 3:xxx
      return filename
    endif
  endwhile
  return ''
endfunction

" }}}

" vim:fdm=marker
