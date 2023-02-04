" additional vimrc, but in legacy vimscript (not vim9script).

" setup {{{1
let s:save_cpo = &cpo
set cpo&vim

" :CopyMatches; {{{1
" https://vim.fandom.com/wiki/Copy_search_matches#Copy_matches
" original snippet does not work...
function! s:CopyMatches() abort
  let hits = []
  %s//\=add(hits, submatch(0))/gne
  let @" = join(hits, "\n") .. "\n"
endfunction
command! CopyMatches call s:CopyMatches()

" finish. {{{1
let &cpo = s:save_cpo
unlet s:save_cpo
