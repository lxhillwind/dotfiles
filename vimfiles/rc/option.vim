" vim: fdm=marker

" before doing thing {{{1

" map early
let mapleader = ' '  " assign before use
let maplocalleader = ' ;'
noremap <Space> <Nop>

" vim-vimserver {{{1
if !exists('g:vimserver_ignore')
  let g:vimserver_ignore = 1
endif
runtime pack/lx/opt/vim-vimserver/plugin/vimserver.vim

" +eval version vimrc default {{{1
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

" various tmpfile {{{1
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

" colorscheme, term setting {{{1
if has('vim_starting')
" only set colorscheme on start {{{2
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
" }}}2
endif

" gvimrc {{{1
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
