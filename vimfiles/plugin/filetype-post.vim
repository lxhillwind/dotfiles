" vim: fdm=marker
" vimrc after filetype.vim.

if !exists('g:syntax_on')
  syntax on
endif

" this also enables filetype.
filetype plugin indent on

" filetype setting {{{1
augroup vimrc_filetype
  au!
  au BufNewFile,BufRead *.gv setl ft=dot
  au FileType vim setl sw=2
  au FileType yaml setl sw=2 indentkeys-=0#
  au FileType zig setl fp=zig\ fmt\ --stdin
  au FileType markdown setl tw=78 | call s:markdown_checkbox_hl()

  function! s:markdown_checkbox_hl()
    hi link CheckboxUnchecked Type
    hi link CheckboxChecked Comment
    syn match CheckboxUnchecked '\v^\s*- \[ \] '
    syn match CheckboxChecked '\v^\s*- \[X\] '
  endfunction

  " quickfix window
  au FileType qf let &l:stl = &g:stl
augroup END

" ":h ft-sh-syntax"
let g:is_posix = 1

" colorscheme {{{1
" only set colorscheme if not set yet. {{{2
" using `trim(execute('color')) == 'default'` is not valid.
if !exists('g:colors_name')
  if has('gui_running') || &t_Co >= 256
    color base16-dynamic
  else
    if has('win32')
      " win32 cmd
      color pablo
    else
      " no 256color
      color default
    endif
  endif
endif

" terminal statusline tweak {{{2
augroup vimrc_statuslinetermnc
  au!
  " colorscheme may not change at startup.
  au ColorScheme * hi! link StatusLineTermNC StatusLineNC
augroup END
hi! link StatusLineTermNC StatusLineNC

" terminal 16color {{{2
function! s:vimrc_terminal_ansi_color()
  if !(has('gui_running') || &tgc)
    return
  endif
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

augroup vimrc_terminal_ansi_color
  au!
  au ColorScheme * call s:vimrc_terminal_ansi_color()
augroup END
call s:vimrc_terminal_ansi_color()
