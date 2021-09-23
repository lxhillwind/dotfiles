if get(g:, 'loaded_jump') || v:version < 703
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

  let file = a:0 > 0 ? substitute(chunk, '\v\n+$', '', '') : expand('<cfile>')
  call s:jump_flc(file, line, col)
endfunction

function! s:execute(cmd) abort
  if exists('*execute')
    return execute(a:cmd)
  else
    let l:res = ''
    try
      " exception message will be thrown away.
      redir => l:res
      silent exe a:cmd
    finally
      redir END
    endtry
    return l:res
  endif
endfunction

let s:is_win32 = has('win32')

function! s:norm_path(path) abort
  if !s:is_win32 && match(a:path, '\v^\~[^/].*') >= 0
    " e.g. ~~foo can't be expanded correctly.
    let path = getcwd() . '/' . a:path
  else
    let path = a:path
  endif
  return simplify(fnamemodify(path, ':p'))
endfunction

function! s:getbufinfo() abort
  if exists('*getbufinfo')
    return getbufinfo()
  else
    let result = []
    for line in split(s:execute('ls'), "\n")
      let item = matchlist(line, '\v^\s*(\d+).{-}"(.+)".+$')
      let result = add(result,
            \ {'bufnr': str2nr(item[1]), 'name': s:norm_path(item[2])})
    endfor
    return result
  endif
endfunction

" return 1 if opened; 0 else.
function! s:open_file(name) abort
  let name = a:name
  let name = simplify(fnamemodify(name, ':p'))
  let l:is_dir = isdirectory(name)
  if l:is_dir
    " trim final (back)slash since dir buffer name does not contain it.
    let name = substitute(name, s:is_win32 ? '\v\\$' : '\v/$', '', '')
  endif

  let bufnrs = tabpagebuflist()
  for buffer in s:getbufinfo()
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
  if !filereadable(name) && !l:is_dir
    redraws | echon 'file not readable / not found.'
    return 0
  endif

  echo printf('[%s] %s not listed.', name, l:is_dir ? 'dir' : 'file')
  if exists('*jobwait')
    let job_running = ( jobwait([&channel], 0)[0] == -1 )
  elseif exists('*term_getstatus')
    let job_running = ( match(term_getstatus(bufnr()), 'running') >= 0 )
  else
    let job_running = 0
  endif
  if job_running
    echo 'open it? [s/v/t/N] '
  else
    echo 'open it? [s/v/t/N] r[e]use '
  endif
  let action = tolower(nr2char(getchar()))
  let actions = {'v': 'vs', 's': 'sp', 't': 'tabe'}
  if !job_running
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
