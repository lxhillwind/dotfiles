" vim:fdm=marker

" snippet; :Scratch [filetype] / :ScratchNew [filetype] (with new window) {{{
command -nargs=? -complete=filetype Scratch call <SID>scratch(<q-args>)
command! -nargs=? -complete=filetype
      \ ScratchNew call <SID>snippet_in_new_window(<q-args>)

function! s:scratch(ft) abort
  enew | setl buftype=nofile noswapfile bufhidden=hide
  if !empty(a:ft)
    exe 'setl ft=' . a:ft
  endif
endfunction

function! s:snippet_in_new_window(ft) abort
  exe printf('bel %dnew', &cwh)
  setl buftype=nofile noswapfile
  setl bufhidden=hide
  if !empty(a:ft)
    exe 'setl ft=' . a:ft
  endif
endfunction
" }}}

" run vim command; :KvimRun {vim_command}... {{{
command! -bang -nargs=+ -complete=command KvimRun call <SID>vim_run(<q-args>, <bang>0)

function! s:vim_run(args, reuse) abort
  call s:show_output(execute(a:args), a:reuse)
endfunction
" }}}

" vim expr; :KvimExpr {vim_expr}... {{{
command! -bang -nargs=+ -complete=expression KvimExpr call <SID>vim_expr(<q-args>, <bang>0)

function! s:vim_expr(args, reuse) abort
  call s:show_output(eval(a:args), a:reuse)
endfunction

function! s:show_output(data, reuse) abort
  if a:reuse
    Scratch
    put =a:data
  else
    ScratchNew
    for line in split(a:data, "\n")
      call append('$', line)
    endfor
  endif
  norm gg"_dd
endfunction
" }}}

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

" edit selected line / column; :Kjump {{{
command! -nargs=+ Kjump call <SID>jump_line_col(<f-args>)
function! s:jump_line_col(line, ...) abort
  execute 'normal' a:line . 'gg'
  if a:0 > 0
    let col = a:1
    if col > 1
      execute 'normal 0' . (col-1) . 'l'
    endif
  endif
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
