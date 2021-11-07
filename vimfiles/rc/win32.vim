" vim: fdm=marker
" setup for win32. (not cygwin)

let s:nix_default = fnamemodify(expand('<sfile>'), ':p:h:h:h')
let s:nix_dir = get(s:, 'nix_dir', s:nix_default)
unlet s:nix_default

" set $HOME (for unix shell), $PATH, $VIM ... {{{1
function! s:tr_slash(s)
  return substitute(a:s, '\', '/', 'g')
endfunction
let s:nix_dir = s:tr_slash(s:nix_dir)

" make it work in cygwin vim.
let $VIM = s:tr_slash($VIM)
let $VIMRUNTIME = s:tr_slash($VIMRUNTIME)
let $MYVIMRC = s:tr_slash($MYVIMRC)

if !exists('$HOME')
  let $HOME = s:tr_slash($USERPROFILE)
else
  let $HOME = s:tr_slash($HOME)
endif

let s:path = map(split($PATH, ';'), 's:tr_slash(v:val)')
for s:i in [
      \ s:nix_dir . '/vimfiles/bin',
      \ s:nix_dir . '/MinGit/usr/bin',
      \ s:nix_dir . '/MinGit/cmd',
      \ s:nix_dir . '/bin',
      \ ]
  if index(s:path, s:i) < 0 && isdirectory(s:i)
    let $PATH = s:i . ';' . $PATH
  endif
endfor
" cygwin vim -> vim -> others.
let $PATH = '/usr/bin;/bin;' . $VIMRUNTIME . ';' . $PATH
unlet s:path
unlet s:i

" vim-sh config {{{1
" busybox sh rc
let $ENV = expand(s:nix_dir . '/.config/env.sh')
let $SH_RC_LOCAL = expand(s:nix_dir . '/local.sh')
" }}}
