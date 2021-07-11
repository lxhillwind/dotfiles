" vim:fdm=marker
"
" set g:vimrc#pkgs before source this file; example:
"
"     let g:vimrc#pkgs = {'base': 1, 'coc': 0}
"
" to get available pkgs:
"
"     echo g:vimrc#pkgs
"
" or copy it via <Leader><CR> (see rc.vim):
"
"     let @" = 'let g:vimrc#pkgs = ' . string(g:vimrc#pkgs) | echo 'copied:' @"
"
" plug#begin(...) / plug#end() should be called explicitly.
" {{{
let g:vimrc#pkgs = get(g:, 'vimrc#pkgs', {})
if type(g:vimrc#pkgs) != type({})
  let g:vimrc#pkgs = {}
  echoerr '`g:vimrc#pkgs` should be dict! fallback to {}.'
endif
" }}}

" check if enable this feature; also set dict.
" optinoal arg: default value (1 / 0).
function! s:enable(pkg, ...)  " {{{
  let default = a:0 > 0 ? a:1 : 0
  let g:vimrc#pkgs[a:pkg] = !empty(get(g:vimrc#pkgs, a:pkg, default))
  return !empty(g:vimrc#pkgs[a:pkg])
endfunction
" }}}

if s:enable('lx', 1)
  for s:i in globpath(expand('<sfile>:p:h'), 'lx/*', 0, 1)
    if isdirectory(s:i) && match(s:i, "'") < 0
      " ensure "'" is not in path.
      execute printf("Plug '%s'", s:i)
    endif
  endfor
endif

if s:enable('base', 1)
  Plug 'https://github.com/justinmk/vim-dirvish'

  " dirvish
  let g:loaded_netrwPlugin = 1
endif

if s:enable('coc', 0)
  Plug 'neoclide/coc.nvim', {'branch': 'release'}

  " vim completion
  Plug 'Shougo/neco-vim'
  Plug 'neoclide/coc-neco'

  " run the following vim command to install coc plugins:
  "   CocInstall coc-go
  "   CocInstall coc-html
  "   CocInstall coc-pyright

  au FileType go,html,python,vim call <SID>init_coc_lang()

  " coc keymap {{{
  function! s:init_coc_lang()
    " GoTo code navigation.
    nmap <silent> <buffer> <LocalLeader>d <Plug>(coc-definition)
    nmap <silent> <buffer> <LocalLeader>y <Plug>(coc-type-definition)
    nmap <silent> <buffer> <LocalLeader>i <Plug>(coc-implementation)
    nmap <silent> <buffer> <LocalLeader>r <Plug>(coc-references)

    " completion
    inoremap <silent> <buffer> <expr> <C-Space> coc#refresh()

    " diagnostic
    nmap <buffer> ]e <cmd>call CocAction('diagnosticNext')<CR>
    nmap <buffer> [e <cmd>call CocAction('diagnosticPrevious')<CR>

    " Use K to show documentation in preview window.
    nnoremap <silent> <buffer> K :call <SID>show_documentation()<CR>

    nnoremap <silent> <buffer> <C-]> <cmd>call <SID>coc_definition_with_tag_list()<CR>
  endfunction

  function! s:show_documentation()
    if (index(['vim','help'], &filetype) >= 0)
      execute 'h '.expand('<cword>')
    elseif (coc#rpc#ready())
      call CocActionAsync('doHover')
    else
      execute '!' . &keywordprg . " " . expand('<cword>')
    endif
  endfunction

  " https://github.com/neoclide/coc.nvim/issues/576#issuecomment-632446784
  function! s:coc_definition_with_tag_list() abort
    " Cribbed from :h tagstack-examples
    let tag = expand('<cword>')
    let pos = [bufnr()] + getcurpos()[1:]
    let item = {'bufnr': pos[0], 'from': pos, 'tagname': tag}
    if CocAction('jumpDefinition')
      " Jump was successful, write previous location to tag stack.
      let winid = win_getid()
      let stack = gettagstack(winid)
      let stack['items'] = [item]
      " TODO nvim
      call settagstack(winid, stack, 't')
    endif
  endfunction
  " }}}
endif

" from vim-plug :PlugSnapshot
silent! let g:plugs['vim-dirvish'].commit = '9c0dc32af9235d42715751b30cf04fa0584c1798'
