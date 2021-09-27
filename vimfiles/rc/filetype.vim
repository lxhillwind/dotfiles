" vim: fdm=marker

augroup vimrc_filetype
  au!
  au BufNewFile,BufRead *.gv setl ft=dot
  au FileType vim setl sw=2
  au FileType yaml setl sw=2 indentkeys-=0#
  au FileType zig setl fp=zig\ fmt\ --stdin
  au FileType markdown setl tw=78

  " quickfix window
  au FileType qf let &l:stl = &g:stl
augroup END

" ":h ft-sh-syntax"
let g:is_posix = 1
