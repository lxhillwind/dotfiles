" vim:fdm=marker
" pkg list.
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

if exists(':Pack') != 2
  finish
endif

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

" globpath() polyfill {{{
function! s:globpath(a, b, c, d) abort
  if has('patch-7.4.654')
    return globpath(a:a, a:b, a:c, a:d)
  else
    return split(globpath(a:a, a:b), "\n")
  endif
endfunction
" }}}

" best to have {{{2
if s:enable('base', 1)
  Pack 'https://github.com/justinmk/vim-dirvish', {'commit': '9c0dc32af9235d42715751b30cf04fa0584c1798'}

  " dirvish
  let g:loaded_netrwPlugin = 1
endif

" basic completion {{{2
if s:enable('basic-comp', 1) && v:version >= 800
  Pack 'https://github.com/skywind3000/vim-auto-popmenu', {'commit': 'ea64a79b23401f48e95b9bce65ba39c6c020a291'}
  " enable this plugin for filetypes, '*' for all files.
  "let g:apc_enable_ft = {'text':1, 'markdown':1, 'php':1}
  let g:apc_enable_ft = {'*': 1}

  " source for dictionary, current or other loaded buffers, see ':help cpt'
  set cpt=.,k,w,b

  " don't select the first item.
  set completeopt=menu,menuone,noselect

  " suppress annoy messages.
  set shortmess+=c

  Pack 'https://github.com/skywind3000/vim-dict', {'commit': 'c97d404977edb3d5197c025ffaa12b685ac5963c'}
  " File type override
  "let g:vim_dict_config = {'html':'html,javascript,css', 'markdown':'text'}
  let g:vim_dict_config = {'markdown':'text'}

  " Disable certain types
  "let g:vim_dict_config = {'text': ''}
endif

" coc {{{2
if s:enable('coc', 0) && v:version >= 800
  let g:apc_enable_ft = {}

  Pack 'neoclide/coc.nvim', {'branch': 'release'}

  " vim completion
  Pack 'Shougo/neco-vim'
  Pack 'neoclide/coc-neco'

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
