" vim: fdm=marker

" colorscheme, syntax on, term setting {{{1
if has('vim_starting')
" only set colorscheme on start {{{2
syntax on

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
