" vim:fdm=marker

" mainly used in vscode-neovim extension;
" config (except VSCodeMap) is from my ~/vimfiles/vimrc

set pp^=~/vimfiles

packadd! vim-sneak
let g:sneak#label = 1
xmap S <Plug>Sneak_S
omap s <Plug>Sneak_s
omap S <Plug>Sneak_S

nnoremap <Space>l <Cmd>nohl<CR>
nnoremap <Space>y <Cmd>let @+ = @"<CR>
nnoremap <Space>p <Cmd>let @" = @+<CR>

" custom text object {{{
" <silent> to avoid "Press Enter..." msg in too narrow screen.

" all
xnoremap <silent> aa :<C-u>normal! ggVG<CR>
onoremap <silent> aa :<C-u>normal! ggVG<CR>
" line
xnoremap <silent> al :<C-u>normal! 0v$h<CR>
onoremap <silent> al :<C-u>normal! 0v$h<CR>
" line, strip space
xnoremap <silent> il :<C-u>normal! ^vg_<CR>
onoremap <silent> il :<C-u>normal! ^vg_<CR>
" fold
xnoremap <silent> az V]zo[zo
onoremap <silent> az :<C-u>normal! V]zo[zo<CR>
" fold, without marker. (trailing marker is not un-select. press k if it
" exists.)
xnoremap <silent> iz V]zo[zjo
onoremap <silent> iz :<C-u>normal! V]zo[zjo<CR>
" }}}

" non-vscode config; finish. {{{
if !exists('g:vscode')
	color shine
	nnoremap <Space>fr <Cmd>e ~/.config/nvim/init.vim<CR>

	finish
endif
" }}}

" avoid endless output panel popup caused by vim-sneak.
" ref: https://github.com/vscode-neovim/vscode-neovim/issues/2099
set cmdheight=10

command! -nargs=+ VSCodeMap call s:vscodeMapHelper('call', <args>)
command! -nargs=+ VSCodeMapAsync call s:vscodeMapHelper('action', <args>)
function! s:vscodeMapHelper(fn, key, ...) abort
	execute $'nnoremap {a:key} <Cmd>call luaeval("require(\"vscode\").{a:fn}(unpack(_A))", {a:000})<CR>'
endfunction

" fix folding: {{{
" https://github.com/vscode-neovim/vscode-neovim/issues/58#issuecomment-2663266989
nmap j gj
nmap k gk
VSCodeMap 'zM', 'editor.foldAll'
VSCodeMap 'zR', 'editor.unfoldAll'
VSCodeMap 'zc', 'editor.fold'
VSCodeMap 'zC', 'editor.foldRecursively'
VSCodeMap 'zo', 'editor.unfold'
VSCodeMap 'zO', 'editor.unfoldRecursively'
VSCodeMap 'za', 'editor.toggleFold'
" }}}

VSCodeMap '[c', 'workbench.action.editor.previousChange'
VSCodeMap ']c', 'workbench.action.editor.nextChange'
VSCodeMap '[g', 'editor.action.marker.prev'
VSCodeMap ']g', 'editor.action.marker.next'
VSCodeMap '<Space><Space>', 'workbench.action.quickOpen'

VSCodeMapAsync '<Space>o', 'workbench.action.tasks.runTask', #{args: ['project in current window']}
VSCodeMapAsync '<Space>O', 'workbench.action.tasks.runTask', #{args: ['project in new window']}
VSCodeMapAsync '<Space>r', 'workbench.action.tasks.runTask'
VSCodeMapAsync '<Space>v', 'workbench.action.tasks.runTask', #{args: ['vim']}
endif
