execute 'set rtp^=' . fnameescape(expand('<sfile>:p:h'))
execute 'set rtp+=' . fnameescape(expand('<sfile>:p:h') . '/after')

runtime lx/vim-vimserver/plugin/vimserver.vim
call vimserver#main()

let mapleader = ' '  " assign before use
let maplocalleader = ' ;'
noremap <Space> <Nop>

" default {{{
if has('vim_starting')
  syntax on

  augroup vimrc_terminal
    au!
    function! s:terminal_paste()
      echo @"
      if @"[-1:] == "\n"
        echohl WarningMsg
        echo '<Newline> at end!'
        echohl NONE
      endif
      echo 'paste in terminal? (cursor may be at wrong place!) [y/N] '
      if tolower(nr2char(getchar())) == 'y'
        if has('nvim')
          call feedkeys('p', 'n')
        else
          call feedkeys("i\<C-w>" . '""' . "\<C-\>\<C-n>", 'n')
        endif
        redraws | echon 'pasted.'
      else
        redraws | echon 'cancelled.'
      endif
    endfunction
    function! s:terminal_init()
      " NOTE: keymap defined here (terminal [p]aste).
      if &buftype ==# 'terminal'
        setl nonu | setl nornu
        " vim-jump
        nmap <buffer> <CR> <Plug>(jump_to_file)
        vmap <buffer> <CR> <Plug>(jump_to_file)
        nnoremap <buffer> p :<C-u>call <SID>terminal_paste()<CR>
        nnoremap <buffer> P :<C-u>call <SID>terminal_paste()<CR>
      endif
    endfunction
    if exists('##TerminalOpen')
      au TerminalOpen * call s:terminal_init()
    elseif exists('##TermOpen')
      au TermOpen * call s:terminal_init()
    endif
  augroup END
endif

" statusline
if has('patch-8.2.2854')
  " %{% expr %}
  let &stl = '[%{winnr()},%{mode()}' . '%{% empty(&buftype) ? "%M%R" : "" %}]'
        \ . '%{ empty(&ft) ? "" : " [".&ft."]" }'
        \ . ' %<%F'
        \ . ' %=<%B>'
        \ . ' [%l:' . (exists('*charcol') ? '%{charcol(".")}' : '%cb')
        \ . '%{% &buftype == "terminal" ? "" : "/%L" %}' . ']'
else
  let &stl = '[%{winnr()},%{mode()}%M%R]'
        \ . '%{ empty(&ft) ? "" : " [".&ft."]" }'
        \ . ' %<%F'
        \ . ' %=<%B>'
        \ . ' [%l:' . (exists('*charcol') ? '%{charcol(".")}' : '%cb')
        \ . '/%L]'
endif

" set locale
if has('unix')
  lang en_US.UTF-8
else
  let $LANG = 'en'
endif

" disable default plugin
let g:loaded_2html_plugin = 1
let g:loaded_getscriptPlugin = 1
let g:loaded_gzip = 1
let g:loaded_logiPat = 1
let g:loaded_netrwPlugin = 1
let g:loaded_tarPlugin = 1
let g:loaded_vimballPlugin = 1
let g:loaded_zipPlugin = 1
" }}}

" various tmpfile {{{
" copy from https://github.com/mhinz/vim-galore#temporary-files (modified)
" backup files
set backup
let &backupdir = expand('~/.vim/files/backup/')
set backupext=-vimbackup
set backupskip=
" swap files
let &directory = expand('~/.vim/files/swap' . '//')
" use default value
"set updatecount =100
" undo files
set undofile
let &undodir = expand('~/.vim/files/undo/')
" viminfo files
if exists('&viminfofile')
  let &viminfofile = expand('~/.vim/files/viminfo')
endif

" create directory if needed
for s:t_dir in [&backupdir, &directory, &undodir]
  if !isdirectory(s:t_dir)
    call mkdir(s:t_dir, 'p')
  endif
endfor

" disable some feature
set nobackup
set noundofile
" }}}

" colorscheme, term setting {{{
"  only set colorscheme on start
if has('vim_starting')

" terminal statusline tweak
hi! link StatusLineTermNC StatusLineNC
augroup vimrc_statuslinetermnc
  au!
  " colorscheme may not change at startup.
  au ColorScheme * hi! link StatusLineTermNC StatusLineNC
augroup END

" terminal 16color
augroup vimrc_terminal_ansi_color
  function! s:vimrc_terminal_ansi_color()
    " https://github.com/lxhillwind/base16-dynamic.vim
    if &bg == 'dark'
      let g:terminal_ansi_colors = ["#263238","#F07178","#C3E88D","#FFCB6B","#82AAFF","#C792EA","#89DDFF","#EEFFFF","#546E7A","#F07178","#C3E88D","#FFCB6B","#82AAFF","#C792EA","#89DDFF","#FFFFFF"]
    else
      let g:terminal_ansi_colors = ["#fafafa","#ca1243","#50a14f","#c18401","#4078f2","#a626a4","#0184bc","#383a42","#a0a1a7","#ca1243","#50a14f","#c18401","#4078f2","#a626a4","#0184bc","#090a0b"]
    endif

    if has('nvim')
      for l:i in range(0, 15)
        execute printf('let g:terminal_color_%s = g:terminal_ansi_colors[%s]', l:i, l:i)
      endfor
    endif
  endfunction

  au!
  au ColorScheme * call s:vimrc_terminal_ansi_color()
augroup END

let s:is_unix = has('unix')
if !s:is_unix && !has('gui_running')  " win32 cmd
  set nocursorcolumn
  color pablo
elseif (s:is_unix && $TERM ==? 'linux')  " linux tty
  set bg=dark
else
  if !has('gui_running') && exists('&tgc') && $TERM !~ 'xterm'
    " make tgc work; :help xterm-true-color
    let &t_8f = "\<Esc>[38:2:%lu:%lu:%lum"
    let &t_8b = "\<Esc>[48:2:%lu:%lu:%lum"
  endif
  silent! set termguicolors
  if $BAT_THEME =~? 'light'
    set bg=light
  else
    set bg=dark
  endif
  try
    color base16-dynamic
  catch
    if has('gui_running') || exists('&tgc')
      color desert
    endif
  endtry
endif

if s:is_unix && $TERM =~? 'xterm' && executable('/mnt/c/Windows/notepad.exe')
  " fix vim start in replace mode;
  " Refer: https://superuser.com/a/1525060
  set t_u7=
endif

endif
" }}}

" gvimrc {{{
function! s:gui_init()
  if !has('vim_starting')
    return
  endif
  set guioptions=
  set lines=32
  set columns=128
endfunction

if has('gui_running')
  call s:gui_init()
endif
" }}}

" common platform detection
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

" clipboard (see keymap) {{{
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
" }}}

" Cd <path> / :Cdalternate / :Cdhome / :Cdbuffer / :Cdproject [:]cmd... {{{
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
      call s:echoerr('path argument is required!') | return
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
    call s:echoerr('not a directory: ' . a:args) | return
  endif

  if !empty(cmd)
    let old_cwd = getcwd()
    let buf = bufnr()
    try
      " use buffer variable to store cwd if `exe` switch to new window
      let b:vimrc_old_cwd = old_cwd
      exe 'lcd' path
      exe cmd
    finally
      if buf == bufnr()
        if exists('b:vimrc_old_cwd')
          unlet b:vimrc_old_cwd
        endif
        exe 'lcd' old_cwd
      endif
    endtry
  else
    exe 'lcd' path
    if &buftype == 'terminal'
      call term_sendkeys(bufnr(), 'cd ' . shellescape(path))
    endif
  endif
endfunction

function! s:cd_reset()
  if exists('b:vimrc_old_cwd')
    try
      exe 'lcd' b:vimrc_old_cwd
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
" }}}

" execute current line (or select lines), comment removed (see keymap) {{{
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
    redraws | execute 'Cdbuffer' result
  else
    redraws | echon 'cancelled.'
  endif
endfunction
" }}}

" gx related (NOTE: key `gx` overwritten) {{{
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
" }}}

" export SID (:h SID); variable: g:vimrc_sid {{{
function! s:get_sid(filename)
  for i in split(execute('scriptnames'), "\n")
    let id = substitute(i, '\v^\s*(\d+): .*$', '\1', '')
    let file = substitute(i, '\v^\s*\d+: ', '', '')
    if a:filename ==# expand(file)
      return id
    endif
  endfor
  return 0
endfunction
" hide execute output.
if exists('*execute')
  silent let g:vimrc_sid = s:get_sid(expand('<sfile>'))
endif
" }}}

" switch number / relativenumber {{{
function! s:switch_nu_rnu() abort
  " no [0, 1]
  let presents = [[1, 1], [1, 0], [0, 0], [1, 1]]
  let idx = index(presents, [&l:nu, &l:rnu])
  let [&l:nu, &l:rnu] = presents[idx+1]
endfunction
" }}}

" keymap {{{
" terminal <C-Space>
map <Nul> <C-Space>
map! <Nul> <C-Space>
if exists(':tmap') == 2
  tmap <Nul> <C-Space>
endif

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
" }}}

" filetype setting {{{
augroup vimrc_filetype
  au!
  au BufNewFile,BufRead *.gv setl ft=dot
  au FileType vim setl sw=2
  au FileType yaml setl sw=2 indentkeys-=0#
  au FileType zig setl fp=zig\ fmt\ --stdin
  au FileType markdown setl tw=78

  " open plugin directory
  au FileType vim nnoremap <buffer> <LocalLeader>e <cmd>e ~/vimfiles/plugin<CR>

  " quickfix window
  au FileType qf let &l:stl = &g:stl

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

" :h ft-sh-syntax
let g:is_posix = 1
" }}}

" finally
" e.g. <Space><Space>
nnoremap <Leader><Leader> :nmap <Char-60>Leader<Char-62><CR>
" e.g. <Space>;; / \\
execute 'nnoremap <LocalLeader>' .
      \ (len(maplocalleader) > 1 ? matchstr(maplocalleader, '.$') : '<LocalLeader>') .
      \ ' :nmap <Char-60>LocalLeader<Char-62><CR>'

" vim: fdm=marker
