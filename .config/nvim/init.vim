" vim:fdm=marker

" mainly used in vscode-neovim extension;
" config (except VSCodeMap) is from my ~/vimfiles/vimrc

" additional config in vscode:
"
" Settings (UI):
" - search "ctrlKeysForNormalMode", remove k (so ctrl+k is handled by vscode);

set pp^=~/vimfiles
set timeoutlen=5000

packadd! vim-sneak
let g:sneak#label = 1
xmap S <Plug>Sneak_S
omap s <Plug>Sneak_s
omap S <Plug>Sneak_S

nnoremap <Space>l <Cmd>nohl<CR>
nnoremap <Space>y <Cmd>let @+ = @"<CR>
nnoremap <Space>p <Cmd>let @" = @+<CR>

noremap <expr> n 'Nn'[v:searchforward]
noremap <expr> N 'nN'[v:searchforward]

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
" fFtT
xnoremap <silent> <expr> af <SID>TextObjectIfAf('a')
onoremap <silent> <expr> af <SID>TextObjectIfAf('a')
xnoremap <silent> <expr> if <SID>TextObjectIfAf('i')
onoremap <silent> <expr> if <SID>TextObjectIfAf('i')
function! s:TextObjectIfAf(type) abort
    let l:ch = getcharstr()
    if empty(l:ch)
        return ''
    endif
    let l:op = a:type == 'a' ? 'fF' : 'tT'
    return ":\<C-u>normal! " .. l:op[0] .. l:ch .. "v" .. l:op[1] .. l:ch .. "\<CR>"
endfunction
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
function! s:vscodeMapHelper(fn, key, cmd, ...) abort
	execute $'nnoremap {a:key} <Cmd>call luaeval("require(\"vscode\").{a:fn}(unpack(_A))", {[a:cmd, #{args: a:000}]})<CR>'
endfunction

" fix folding: {{{
" move based on mode: omap => logical line; nmap => viewport line.
let s:map_j = "<Cmd>call v:lua.require'vscode'.call('cursorMove', #{args: #{to: 'down', by: v:count == 0 ? 'wrappedLine' : 'line', value: v:count1}})<CR>"
let s:map_k = "<Cmd>call v:lua.require'vscode'.call('cursorMove', #{args: #{to: 'up', by: v:count == 0 ? 'wrappedLine' : 'line', value: v:count1}})<CR>"
execute $'nnoremap j {s:map_j}'
execute $'onoremap j {s:map_j}'
execute $'nnoremap k {s:map_k}'
execute $'onoremap k {s:map_k}'

" https://github.com/vscode-neovim/vscode-neovim/issues/58#issuecomment-2663266989
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

VSCodeMapAsync '<Space>o', 'workbench.action.tasks.runTask', 'project in current window'
VSCodeMapAsync '<Space>O', 'workbench.action.tasks.runTask', 'project in new window'
VSCodeMapAsync '<Space>r', 'workbench.action.tasks.runTask'
VSCodeMapAsync '<Space>v', 'workbench.action.tasks.runTask', 'vim'
