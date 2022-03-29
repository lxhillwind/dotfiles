" vim: fdm=marker
" UserCommand / UserFunction.

" clipboard {{{1
" use pbcopy / pbpaste in $PATH as clipboard; wayland / x11 / tmux ...
" detection is defined there. (~/bin/{pbcopy,pbpaste})
nnoremap <Leader>y :call <SID>clipboard_copy("")<CR>
nnoremap <Leader>p :call <SID>clipboard_paste("")<CR>

function! s:clipboard_copy(cmd)
  if empty(a:cmd)
    if executable('pbcopy')
      let l:cmd = 'pbcopy'
    elseif has('clipboard')
      " NOTE: unix: X11 clipboard content will disapper when program exits.
      let @+ = @"
      return
    else
      throw 'clipboard not found!'
    endif
    call system(l:cmd, @")
  else
    call system(a:cmd, @")
  endif
endfunction

function! s:clipboard_paste(cmd)
  if empty(a:cmd)
    if executable('pbpaste')
      let l:cmd = 'pbpaste'
    elseif has('clipboard')
      let @" = @+
      return
    else
      throw 'clipboard not found!'
    endif
    let @" = system(l:cmd)
  else
    let @" = system(a:cmd)
  endif
endfunction

" execute current line (or select lines), comment removed {{{1
nnoremap <Leader><CR> :call <SID>execute_lines('n')<CR>
vnoremap <Leader><CR> :<C-u>call <SID>execute_lines('v')<CR>

function! s:execute_lines(mode)
  if a:mode == 'n'
    let lines = [getline('.')]
  elseif a:mode == 'v'
    let t = @"
    silent normal gvy
    let lines = split(@", "\n")
    let @" = t
  endif
  let result = []
  for l:i in lines
    " TODO add more comment (or based on filetype).
    let result = add(result, substitute(l:i, '\v^\s*(//|#|"|--)+', '', ''))
  endfor
  let result = join(result, "\n")
  echom result
  echo 'execute? y/N '
  if nr2char(getchar()) ==? 'y'
    redraws
    try
      execute result
    finally
    endtry
  else
    redraws | echon 'cancelled.'
  endif
endfunction

" switch number / relativenumber {{{1
nnoremap <silent> <Leader>n :call <SID>switch_nu_rnu()<CR>

function! s:switch_nu_rnu() abort
  " patch-7.3.1115: set one of nu / rnu will affect another.
  if v:version < 704
    " [1, 0] -> [0, 0] -> [0, 1] -> [1, 0]
    if &nu
      setl nonu
    elseif &rnu
      setl nu
    else
      setl rnu
    endif
    return
  endif
  " no [0, 1]
  let presents = [[1, 1], [1, 0], [0, 0], [1, 1]]
  let idx = index(presents, [&l:nu, &l:rnu])
  let [&l:nu, &l:rnu] = presents[idx+1]
endfunction

" switch quickfix window (open / focus or close) {{{1
nnoremap <silent> <Leader>q :call <SID>switch_quickfix_window()<CR>

function! s:switch_quickfix_window() abort
  if &ft == 'qf'
    cclose
  else
    execute 'bot' 'copen' &cwh
  endif
endfunction

" snippet; :Scratch [filetype] / :ScratchNew [filetype] (with new window) {{{1
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

" run vim command; :KvimRun {vim_command}... {{{1
command! -nargs=+ -complete=command KvimRun call s:show_output(execute(<q-args>))

" vim expr; :KvimExpr {vim_expr}... {{{1
command! -nargs=+ -complete=expression KvimExpr call s:show_output(eval(<q-args>))

function! s:show_output(data) abort
  ScratchNew
  for line in split(a:data, "\n")
    call append('$', line)
  endfor
  norm gg"_dd
endfunction

" insert shebang based on filetype; :KshebangInsert [content after "#!/usr/bin/env "] {{{1
command! -nargs=* -complete=shellcmd KshebangInsert
      \ call <SID>shebang_insert(<q-args>)

let g:vimrc_shebang_lines = {
      \'awk': '/usr/bin/awk -f', 'javascript': 'node', 'lua': 'lua',
      \'perl': 'perl', 'python': 'python', 'ruby': 'ruby',
      \'scheme': 'scheme-run', 'sh': '/bin/sh', 'zsh': 'zsh'
      \}

function! s:shebang_insert(args) abort
  let first_line = getline(1)
  if len(first_line) >= 2 && first_line[0:1] ==# '#!'
    throw 'shebang exists!'
  endif
  if !empty(a:args)
    let shebang = a:args
  elseif has_key(g:vimrc_shebang_lines, &ft)
    let shebang = g:vimrc_shebang_lines[&ft]
  else
    throw 'shebang: which interpreter to run?'
  endif
  if match(shebang, '^/') >= 0
    let shebang = '#!' . shebang
  else
    let shebang = '#!/usr/bin/env ' . shebang
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

" match long line; :KmatchLongLine {number} {{{1
" Refer: https://stackoverflow.com/a/1117367
command! -nargs=1 KmatchLongLine exe '/\%>' . <args> . 'v.\+'

" `J` with custom seperator; <visual>:J sep... {{{1
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

" edit selected line / column; :Kjump {{{1
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

" Selection() {{{1
function! Selection() abort
  let tmp = @"
  try
    silent normal gvy
    return @"
  finally
    let @" = tmp
  endtry
endfunction

" :SetCmdText / SetCmdText() {{{1
function! SetCmdText(text) abort
  call feedkeys(':' .. a:text, 't')
endfunction

command! -nargs=+ SetCmdText call SetCmdText(<q-args>)

" `*` / `#` in visual mode (like `g*` / `g#`); dep: Selection() {{{1
vnoremap <silent> * :<C-u>call feedkeys('/\V' .. substitute(escape(Selection(), '\/'), "\n", '\\n', 'g') .. "\n", 't')<CR>
vnoremap <silent> # :<C-u>call feedkeys('?\V' .. substitute(escape(Selection(), '\/'), "\n", '\\n', 'g') .. "\n", 't')<CR>

" :KqutebrowserEditCmd {{{1
if !empty($QUTE_FIFO)
  command! KqutebrowserEditCmd call s:qutebrowser_edit_cmd()

  function! s:qutebrowser_edit_cmd()
    setl buftype=nofile noswapfile
    call setline(1, $QUTE_COMMANDLINE_TEXT[1:])
    call setline(2, '')
    call setline(3, 'hit `<Space>q` to save cmd (first line) and quit')
    nnoremap <buffer> <Space>q :call writefile(['set-cmd-text -s :' . getline(1)], $QUTE_FIFO) \| q<CR>
  endfunction
endif

" :Tmux {{{1
if exists("$TMUX")
  command! -nargs=1 -bar Tmux call s:tmux_open_window(<q-args>)

  function! s:tmux_open_window(args)
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
endif

" Cd <path> / :Cdalternate / :Cdhome / :Cdbuffer / :Cdproject [:]cmd... {{{1
command! -nargs=1 -complete=dir Cd call <SID>cd('', <q-args>)
command! -nargs=* -complete=command Cdalternate call <SID>cd('alternate', <q-args>)
command! -nargs=* -complete=command Cdhome call <SID>cd('home', <q-args>)
command! -nargs=* -complete=command Cdbuffer call <SID>cd('buffer', <q-args>)
command! -nargs=* -complete=command Cdproject call <SID>cd('project', <q-args>)

function! s:cd(flag, args)
  let cmd = a:args
  if a:flag ==# 'alternate'
    let path = fnamemodify(bufname('#'), '%:p:h')
  elseif a:flag ==# 'home'
    let path = expand('~')
  elseif a:flag ==# 'project'
    let path = s:get_project_dir()
  elseif a:flag ==# 'buffer'
    let path = s:get_buf_dir()
  else
    if a:args =~ '^:'
      throw 'path argument is required!'
    endif
    " Cd: split argument as path & cmd
    let path = substitute(a:args, '\v^(.{}) :.+$', '\1', '')
    let cmd = a:args[len(path)+1:]
  endif

  if !isdirectory(path)
    let path = expand(path)
  endif
  if !isdirectory(path)
    let path = fnamemodify(path, ':h')
  endif
  if !isdirectory(path)
    throw 'not a directory: ' . a:args
  endif

  if !empty(cmd)
    let old_cwd = getcwd()
    let buf = bufnr('')
    try
      " use buffer variable to store cwd if `exe` switch to new window
      let b:vimrc_old_cwd = old_cwd
      exe 'lcd' fnameescape(path)
      exe cmd
    finally
      if buf == bufnr('')
        if exists('b:vimrc_old_cwd')
          unlet b:vimrc_old_cwd
        endif
        exe 'lcd' fnameescape(old_cwd)
      endif
    endtry
  else
    exe 'lcd' fnameescape(path)
    if &buftype == 'terminal'
      call term_sendkeys(bufnr(''), 'cd ' . shellescape(path))
    endif
  endif
endfunction

function! s:cd_reset()
  if exists('b:vimrc_old_cwd')
    try
      exe 'lcd' fnameescape(b:vimrc_old_cwd)
    finally
      unlet b:vimrc_old_cwd
    endtry
  endif
endfunction

augroup vimrc_cd
  au!
  au BufEnter * call s:cd_reset()
augroup END

function! s:get_buf_dir()
  let path = expand('%:p:h')
  if empty(path) || &buftype == 'terminal'
    let path = getcwd()
  endif
  return path
endfunction

function! s:get_project_dir()
  let path = s:get_buf_dir()
  while 1
    if isdirectory(path . '/.git')
      return path
    endif
    if filereadable(path . '/.git')
      " git submodule
      return path
    endif
    let parent = fnamemodify(path, ':h')
    if path == parent
      return ''
    endif
    let path = parent
  endwhile
endfunction

" terminal-api related user function {{{1
if exists(':terminal') == 2
" sync terminal path to buffer path.
" TODO follow cd even when terminal buffer not in focus (with event?).
  function! Tapi_cd(nr, arg)
    if bufnr() == a:nr
      let p = a:arg[0]
      if has('win32') && match(p, '^/') >= 0
        let p = execute(printf("Sh cygpath -w '%s'", substitute(p, "'", "'\\\\''", 'g')))
      endif
      execute 'lcd' fnameescape(p)
    endif
  endfunction
endif
