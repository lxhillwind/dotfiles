" vim: fdm=marker
" keymap and related command

" common def {{{1
let s:is_unix = has('unix')
let s:is_win32 = has('win32')
let s:has_gui = has('gui_running') || has('mac')
      \ || (has('linux') && (!empty($DISPLAY) || !(empty($WAYLAND_DISPLAY))))

" :echoerr will raise exception (?)
function! s:echoerr(msg)
  echohl ErrorMsg
  echon a:msg
  echohl None
endfunction
" }}}1

" clipboard (see keymap) {{{1
" use pbcopy / pbpaste in $PATH as clipboard; wayland / x11 / tmux ...
" detection is defined there. (~/bin/{pbcopy,pbpaste})

function! s:clipboard_copy(cmd)
  if empty(a:cmd)
    if has('clipboard') && !s:is_unix
      " unix: X11 clipboard content will disapper when program exits.
      let @+ = @"
      return
    endif
    if executable('pbcopy')
      let l:cmd = 'pbcopy'
    else
      call s:echoerr('clipboard not found!') | return
    endif
    call system(l:cmd, @")
  else
    call system(a:cmd, @")
  endif
endfunction

function! s:clipboard_paste(cmd)
  if empty(a:cmd)
    if has('clipboard') && !s:is_unix
      let @" = @+
      return
    endif
    if executable('pbpaste')
      let l:cmd = 'pbpaste'
    else
      call s:echoerr('clipboard not found!') | return
    endif
    let @" = system(l:cmd)
  else
    let @" = system(a:cmd)
  endif
endfunction

" execute current line (or select lines), comment removed (see keymap) {{{1
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
    redraws | execute result
  else
    redraws | echon 'cancelled.'
  endif
endfunction

" gx related (NOTE: key `gx` overwritten) {{{1
nnoremap <silent> gx :call <SID>gx('n')<CR>
vnoremap <silent> gx :<C-u>call <SID>gx('v')<CR>

" TODO fix quote / escape
function! s:gx_open_cmd(s)
  if executable('xdg-open')
    return ['xdg-open', a:s]
  elseif executable('open')
    return ['open', a:s]
  elseif s:is_win32
    " TODO fix open for win32
    return ['cmd', '/c', isdirectory(a:s) ? 'explorer' : 'start', a:s]
  else
    call s:echoerr('do not know how to open') | return
  endif
endfunction

" TODO show error?
function! s:gx_open(...)
  let text = join(getline(1, '$'), "\n")
  if empty(text)
    return
  endif
  if empty(a:0)
    let open_cmd = s:gx_open_cmd(text)
  else
    let open_cmd = [a:1, text]
  endif
  if empty(open_cmd)
    return
  endif
  call job_start(open_cmd, {'stoponexit': ''})
endfunction

function! s:gx_open_gx(...)
  if a:0 == 1
    call s:gx_open(a:1)
  else
    call s:gx_open()
  endif
  let winnr = winnr()
  wincmd p
  execute winnr . 'wincmd c'
endfunction

function! s:gx_vim(...)
  " a:1 -> cmd; a:2 -> text modifier; a: 3 -> post string.
  let text = join(getline(1, '$'), "\n")
  if empty(text)
    return
  endif
  if empty(a:0)
    let cmd = text
  else
    if a:0 >= 2 && !empty(a:2)
      let text = function(a:2)(text)
    endif
    let cmd = a:1 . ' ' . text
    if a:0 >= 3 && !empty(a:3)
      let cmd .= a:3
    endif
  endif
  exe cmd
endfunction

function! s:gx(mode) abort
  if a:mode == 'v'
    let t = @"
    silent normal gvy
    let text = @"
    let @" = t
  else
    let text = expand(get(g:, 'netrw_gx', '<cfile>'))
  endif
  exe printf('bel %dnew', &cwh)
  " a special filetype
  setl ft=gx
  for line in split(text, "\n")
    call append('$', line)
  endfor
  norm gg"_dd
endfunction

" switch number / relativenumber {{{1
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

" keymap {{{1
" terminal <C-Space>
map <Nul> <C-Space>
map! <Nul> <C-Space>
if exists(':tmap') == 2
  tmap <Nul> <C-Space>
endif

tnoremap <M-h> <C-w>h
tnoremap <M-j> <C-w>j
tnoremap <M-k> <C-w>k
tnoremap <M-l> <C-w>l

nnoremap <M-h> <C-w>h
nnoremap <M-j> <C-w>j
nnoremap <M-k> <C-w>k
nnoremap <M-l> <C-w>l

inoremap <M-h> <C-o><C-w>h
inoremap <M-j> <C-o><C-w>j
inoremap <M-k> <C-o><C-w>k
inoremap <M-l> <C-o><C-w>l

tnoremap <C-Tab> <C-w>gt
tnoremap <S-C-Tab> <C-w>gT

nnoremap <C-Tab> gt
nnoremap <S-C-Tab> gT

inoremap <C-Tab> <C-o>gt
inoremap <S-C-Tab> <C-o>gT

tnoremap <M-t> <C-w>:tabe<CR>
nnoremap <M-t> :tabe<CR>
inoremap <M-t> <C-o>:tabe<CR>

for s:i in range(1, 9)
  execute printf("tnoremap \<M-%d> \<C-w>%dgt", s:i, s:i)
  execute printf("nnoremap \<M-%d> %dgt", s:i, s:i)
  execute printf("inoremap \<M-%d> \<C-o>\<C-w>%dgt", s:i, s:i)
endfor

" completion
inoremap <C-Space> <C-x><C-o>

" clear hlsearch
nnoremap <silent> <Leader>l :noh<CR>

" custom text object
vnoremap aa :<C-u>normal! ggVG<CR>
onoremap aa :<C-u>normal! ggVG<CR>
vnoremap al :<C-u>normal! 0v$h<CR>
onoremap al :<C-u>normal! 0v$h<CR>
vnoremap il :<C-u>normal! ^vg_<CR>
onoremap il :<C-u>normal! ^vg_<CR>

" clipboard
nnoremap <Leader>y :call <SID>clipboard_copy("")<CR>
nnoremap <Leader>p :call <SID>clipboard_paste("")<CR>

" filelist buffer; vim-filelist
nmap <Leader>f <Plug>(filelist_show)

" simple tasks: tasks.vim
nmap <Leader>r <Plug>(tasks-select)
vmap <Leader>r <Plug>(tasks-select)

" execute current line
nnoremap <Leader><CR> :call <SID>execute_lines('n')<CR>
vnoremap <Leader><CR> :<C-u>call <SID>execute_lines('v')<CR>

" terminal escape
if exists(':tnoremap')
  tnoremap <C-Space> <C-\><C-n>
  if !has('nvim')
    tnoremap <C-w> <C-w>.
  endif
endif

" switch nu / rnu
nnoremap <silent> <Leader>n :call <SID>switch_nu_rnu()<CR>

" filetype related keymap setting {{{1
augroup vimrc_keymap
  au!

  " viml completion
  au FileType vim inoremap <buffer> <C-Space> <C-x><C-v>

  " markdown checkbox {{{
  function! s:markdown_checkbox()
    hi link CheckboxUnchecked Type
    hi link CheckboxChecked Comment
    syn match CheckboxUnchecked '\v^\s*- \[ \] '
    syn match CheckboxChecked '\v^\s*- \[X\] '
  endfunction

  function! s:markdown_toggle_task_status()
    let lineno = line('.')
    let line = getline(lineno)
    if line =~# '\v^\s*- \[X\] '
      let line = substitute(line, '\v(^\s*- )@<=\[X\] ', '', '')
    elseif line =~# '\v^\s*- \[ \] '
      let line = substitute(line, '\v(^\s*- \[)@<= ', 'X', '')
    elseif line =~# '\v^\s*- '
      let line = substitute(line, '\v(^\s*-)@<= ', ' [ ] ', '')
    endif
    call setline(lineno, line)
  endfunction
  " }}}
  au FileType markdown call s:markdown_checkbox() | nnoremap <buffer>
        \ <LocalLeader>c :call <SID>markdown_toggle_task_status()<CR>

  " simple filelist (vim-filelist)
  function! s:filelist_init()
    nmap <buffer> <LocalLeader><CR> <Plug>(filelist_cd)
    nmap <buffer> <CR> <Plug>(filelist_edit)
  endfunction
  au FileType filelist call <SID>filelist_init()

  " gx
  function! s:gx_init()
    setl buftype=nofile noswapfile
    setl bufhidden=hide
    if executable('qutebrowser')
      nnoremap <buffer> <LocalLeader>s :call <SID>gx_open('qutebrowser')<CR>
    endif
    nnoremap <buffer> gx :call <SID>gx_open_gx()<CR>
    if executable('qutebrowser') && s:has_gui
      nnoremap <buffer> gs :call <SID>gx_open_gx('qutebrowser')<CR>
    endif
    nnoremap <buffer> <LocalLeader>f :call <SID>gx_open()<CR>
    nnoremap <buffer> <LocalLeader>v :call <SID>gx_vim('wincmd p \|')<CR>
  endfunction
  au FileType gx call <SID>gx_init()
augroup END

" finally {{{1
" e.g. <Space><Space>
nnoremap <Leader><Leader> :nmap <Char-60>Leader<Char-62><CR>
" e.g. <Space>;; / \\
execute 'nnoremap <LocalLeader>' .
      \ (len(maplocalleader) > 1 ? matchstr(maplocalleader, '.$') : '<LocalLeader>') .
      \ ' :nmap <Char-60>LocalLeader<Char-62><CR>'

" }}}1
