if get(g:, 'loaded_filelist')
  finish
endif
let g:loaded_filelist = 1

nnoremap <Plug>(filelist_show) :<C-u>call <SID>choose_filelist()<CR>
nnoremap <Plug>(filelist_cd) :<C-u>call <SID>cd_cur_line()<CR>
nnoremap <Plug>(filelist_edit) :<C-u>call <SID>edit_cur_line()<CR>

" {{{
augroup filelist
  au!
  au BufNewFile,BufRead,BufWritePost * call s:save_filelist()
augroup END

function! s:cd_cur_line()
  let name = getline('.')
  if empty(name)
    return
  endif
  let name = fnamemodify(name, ':h')
  exe 'lcd' fnameescape(name)
  echo 'cwd: ' . getcwd()
endfunction

function! s:edit_cur_line()
  let name = getline('.')
  if empty(name)
    return
  endif
  exe 'e' fnameescape(name)
endfunction

function! s:match_any(patterns, file) abort
  let file = substitute(a:file, '^\~', $HOME, '')
  for patt in a:patterns
    if match(file, patt) >= 0
      return 1
    endif
  endfor
  return 0
endfunction

function! s:choose_filelist() abort
  enew
  " a special filetype
  setl ft=filelist buftype=nofile noswapfile nobuflisted
  let l:list = map(s:load_filelist(), 'v:val[1]')
  call reverse(l:list)
  call append(0, l:list)
  call append(0, '')
  let doc_pattern = map(globpath(&rtp, 'doc', 0, 1),
        \ 'glob2regpat(resolve(v:val) . "/*.txt")')
  call append(0, filter(
        \ map(copy(v:oldfiles), 's:filename_tweak(v:val)'),
        \   '!s:match_any(doc_pattern, v:val)'))
  norm gg
endfunction

function! s:filelist_path()
  return get(g:, 'filelist_path', s:filelist_path_default)
endfunction
let s:filelist_path_default =
      \ ( empty(&viminfofile) ?
      \   ( expand('<sfile>:p:h:h') . '/cache' ) :
      \   fnamemodify(&viminfofile, ':h') )
      \ . '/filelist_path.cache'

let s:is_win32 = has('win32')
function! s:filename_tweak(filename) abort
  return s:is_win32 ? substitute(a:filename, '\', '/', 'g') : a:filename
endfunction

function! s:load_filelist()
  try
    let files = readfile(s:filelist_path())
  catch /^Vim\%((\a\+)\)\=:E484:/
    let files = []
  endtry
  let result = []
  for i in files
    try
      " [number, filename]
      let record = json_decode(i)
    catch /^Vim\%((\a\+)\)\=:E474:/
      " json decode err
      continue
    endtry
    let record = [record[0], s:filename_tweak(record[1])]
    let result = add(result, record)
  endfor
  return result
endfunction

function! s:save_filelist() abort
  " do not save if `vim -i NONE`
  if &viminfofile ==# 'NONE'
    return
  endif

  " only save normal file
  if !empty(&buftype)
    return
  endif

  let current = expand('%:p')
  let result = {}
  for i in s:load_filelist()
    let result[i[1]] = i[0]
  endfor
  if !has_key(result, current)
    let result[current] = 0
  endif
  let result[current] += 1

  " shrink list if too long.
  if len(result) >= 10000
    let l:fact = 0.1
  else
    let l:fact = 1
  endif

  let f_list = []
  for [name, n] in items(result)
    let l:count = float2nr(n * l:fact)
    if l:count > 0
      let f_list = add(f_list, [l:count, name])
    endif
  endfor
  " `{a, b -> a[0] < b[0]}` is not correct! `:help sort()` for details
  let f_list = sort(f_list, {a, b -> a[0] < b[0] ? 1 : -1})
  let f_list = map(f_list, 'json_encode(v:val)')
  " file record limit
  call writefile(f_list, s:filelist_path())
endfunction
" }}}

" vim:fdm=marker
