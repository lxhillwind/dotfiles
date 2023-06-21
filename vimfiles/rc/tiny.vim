" if run vim with `-u xxx`, then &cp is set; disable it with `set nocp`.
" lines between `:if` and `:endif` will be ignored by vim tiny.
if &compatible
    set nocompatible
endif
set nomodeline
" backspace
set bs=2
" expandtab
set et
" shiftwidth
set sw=4
" (relative)number
set nu
set rnu
" hlsearch
set hls
" incsearch
set is
" timeoutlen
set tm=5000
" ttimeoutlen
set ttm=0
" cursorcolumn & cursorline
set cuc
set cul
" laststatus
set ls=1
" showcmd
set sc
" wildmenu
set wmnu
" completeopt
set cot-=preview
" shortmess; show search count message (default in neovim)
set shm-=S
" set locale in vimrc.vim, since vim tiny doesn't support :if.
" menu
set enc=utf-8
" fileencodings
" See: http://edyfox.codecarver.org/html/vim_fileencodings_detection.html
set fencs=ucs-bom,utf-8,cp936,gb18030,big5,euc-jp,euc-kr,latin1
" prefer using unix style newline (fileformats).
set ffs=unix,dos
" runtimepath
" for tiny version, set rtp to empty string to avoid loading any file.
"set rtp=
