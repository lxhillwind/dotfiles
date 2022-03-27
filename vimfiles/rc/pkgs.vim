" vim:fdm=marker
" pkg list.
"
" set g:vimrc_pkgs before source this file; example:
"
"     let g:vimrc_pkgs = {'base': 1, 'coc': 0}
"
" to get available pkgs:
"
"     echo g:vimrc_pkgs
"
" or copy it via <Leader><CR> (see rc.vim):
"
"     let @" = 'let g:vimrc_pkgs = ' . string(g:vimrc_pkgs) | echo 'copied:' @"
"

if exists(':Pack') != 2
  finish
endif

" {{{
let g:vimrc_pkgs = get(g:, 'vimrc_pkgs', {})
if type(g:vimrc_pkgs) != type({})
  let g:vimrc_pkgs = {}
  echoerr '`g:vimrc_pkgs` should be dict! fallback to {}.'
endif
" }}}

" check if enable this feature; also set dict.
" optinoal arg: default value (1 / 0).
function! s:enable(pkg, ...)  " {{{
  let default = a:0 > 0 ? a:1 : 0
  let g:vimrc_pkgs[a:pkg] = !empty(get(g:vimrc_pkgs, a:pkg, default))
  return !empty(g:vimrc_pkgs[a:pkg])
endfunction
" }}}

" best to have {{{1
if s:enable('base', 1)
  Pack 'https://github.com/justinmk/vim-dirvish', {'commit': 'b2b5709'}
  let g:loaded_netrwPlugin = 1

  Pack 'https://github.com/justinmk/vim-sneak', #{commit: '94c2de47ab301d476a2baec9ffda07367046bec9'}
  let g:sneak#label = 1
  let g:sneak#target_labels = "qwertasdfgzxcv"

  Pack 'https://github.com/ciaranm/securemodelines', #{after: 1, commit: '9751f29699186a47743ff6c06e689f483058d77a'}
endif
" }}}1

" basic completion {{{1
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

  Pack 'https://github.com/skywind3000/vim-dict', {'commit': 'b73128b'}
  " File type override
  "let g:vim_dict_config = {'html':'html,javascript,css', 'markdown':'text'}
  let g:vim_dict_config = {'markdown':'text'}

  " Disable certain types
  "let g:vim_dict_config = {'text': ''}
endif
" }}}1

" coc {{{1
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
