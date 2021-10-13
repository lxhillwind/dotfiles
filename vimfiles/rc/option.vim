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
          call feedkeys('pi', 'n')
        else
          call feedkeys("i\<C-w>" . '""', 'n')
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

" various vim dir & file {{{1
" copy from https://github.com/mhinz/vim-galore#temporary-files (modified)
" backup files
set backup
let &backupdir = expand('~/.vim/files/backup' . '//')
set backupext=-vimbackup
set backupskip=
" swap files
let &directory = expand('~/.vim/files/swap' . '//')
" use default value
"set updatecount =100
" undo files
set undofile
let &undodir = expand('~/.vim/files/undo/')
" viewdir (:mkview / :loadview)
let &viewdir = expand('~/.vim/files/view/')
" viminfo files
if exists('&viminfofile')
  let &viminfofile = expand('~/.vim/files/viminfo')
endif

" create directory if needed
for s:t_dir in [&backupdir, &directory, &undodir, &viewdir]
  if !isdirectory(s:t_dir)
    call mkdir(s:t_dir, 'p')
  endif
endfor

" disable some feature
set nobackup
set noundofile

" term & gui (but not colorscheme) {{{1
" TODO g:terminal_ansi_colors works even if (no gui && no tgc). is this a bug?
if has('vim_starting')
  if has('gui_running')
    set guioptions=
    set lines=32
    set columns=128
  else
    if has('unix')
      if $TERM ==? 'linux'
        " linux tty
        set bg=dark
      else
        " 256color or tgc
        if exists('&tgc') && $TERM !~ 'xterm'
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
      endif

      if $TERM =~? 'xterm' && executable('/mnt/c/Windows/notepad.exe')
        " wsl; fix vim start in replace mode;
        " Refer: https://superuser.com/a/1525060
        set t_u7=
      endif
    else
      " win32 cmd
      set nocursorcolumn
    endif
  endif
endif

" alt key in terminal {{{1
if !has('gui_running') && has('unix')
  " see ":set-termcap"
  for s:i in 'abcdefghijklmnopqrstuvwxyz1234567890'
    exec printf("set <M-%s>=\<Esc>%s", s:i, s:i)
  endfor
  set ttimeoutlen=100
endif
