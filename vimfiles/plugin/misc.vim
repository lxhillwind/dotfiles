" vim:fdm=marker

" insert shebang based on filetype; :KshebangInsert [content after "#!/usr/bin/env "] {{{
command! -nargs=* -complete=shellcmd KshebangInsert
      \ call <SID>shebang_insert(<q-args>)

let g:vimrc#shebang_lines = {
      \'awk': 'awk -f', 'javascript': 'node', 'lua': 'lua',
      \'perl': 'perl', 'python': 'python', 'ruby': 'ruby',
      \'scheme': 'chez --script', 'sh': 'sh', 'zsh': 'zsh'
      \}

function! s:shebang_insert(args) abort
  let first_line = getline(1)
  if len(first_line) >= 2 && first_line[0:1] ==# '#!'
    " shebang exists
    throw 'shebang exists!'
  endif
  let shebang = '#!/usr/bin/env'
  if !empty(a:args)
    let shebang = shebang . ' ' . a:args
  elseif has_key(g:vimrc#shebang_lines, &ft)
    let shebang = shebang . ' ' . g:vimrc#shebang_lines[&ft]
  else
    throw 'shebang: which interpreter to run?'
  endif
  " insert at first line and leave cursor here (for further modification)
  normal ggO<Esc>
  let ret = setline(1, shebang)
  if ret == 0 " success
    normal $
  else
    throw 'setting shebang error!'
  endif
endfunction
" }}}

" match long line; :KmatchLongLine {number} {{{
" Refer: https://stackoverflow.com/a/1117367
command! -nargs=1 KmatchLongLine exe '/\%>' . <args> . 'v.\+'
" }}}

" `J` with custom seperator; <visual>:J sep... {{{
command! -nargs=1 -range J call s:join_line(<q-args>)
function! s:join_line(sep)
  let buf = @"
  try
    norm gv
    norm x
    let @" = substitute(@", "\n", a:sep, 'g')
    norm P
  finally
    let @" = buf
  endtry
endfunction
" }}}

" Selection() {{{
function! Selection() abort
  let tmp = @"
  try
    silent normal gvy
    return @"
  finally
    let @" = tmp
  endtry
endfunction
" }}}

" :SetCmdText / SetCmdText() {{{
function! SetCmdText(text) abort
  call feedkeys(':' .. a:text, 't')
endfunction

command! -nargs=+ SetCmdText call SetCmdText(<q-args>)
" }}}
