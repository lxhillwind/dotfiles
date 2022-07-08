" vim: fdm=marker sw=2
"
" :Pack
" a simple plugin manager (for vim8). doc: {{{1
"
" usage:
"   Pack [url][, {opt}]
"
" example:
"   Pack 'tpope/vim-sensible'
"
"   " as: install with a different folder name
"   Pack 'https://github.com/dracula/vim', #{as: 'dracula'}
"
"   " branch: tag or branch
"   Pack 'https://github.com/Shougo/ddc.vim', #{branch: 'v0.14.0'}
"
"   " after: install to after sub directory of plugin folder
"   " commit: checkout a special commit.
"   Pack 'https://github.com/ciaranm/securemodelines', #{after: 1, commit: '9751f29699186a47743ff6c06e689f483058d77a'}
"
"   " skip: do not load plugin.
"   Pack 'a-plugin-to-packadd-on-demand', #{skip: 1}
"
"   " load local dir / file
"   Pack '~/dir/local'
"   Pack '$HOME/dir/local'
"   " same as :source
"   Pack '~/file/local'
"
"   " management (interactive): select function.
"   Pack
"
" opt:
"   as; branch; commit; after; skip.
"
" complete workflow:
"   after running `:Pack`, run the new buffer content with sh with
"   `:%!sh`, or other way to run external command.
"
" after vim is started, ":Pack {url}" can be used to load skipped plugin.
" command completion returns plugins (not loaded) list.
"
" ":Pack {url}[, {opt}]" can be re-run for the same url ({opt} can change),
" once package is not actually available (not downloaded).

" prepare {{{1
if exists('loaded_pack')
  finish
endif
let g:loaded_pack = 1

if exists(':packadd') != 2
  " ignore old version vim.
  command! -bar -nargs=* Pack
  finish
endif

function! s:TrSlash(s) abort
  if has('win32')
    return substitute(a:s, '\', '/', 'g')
  else
    return a:s
  endif
endfunction

" clear list on (re)loading vimrc.
let s:plugins = {}
" plugin list for local dir; this is to be used in ":PackHelpTags"
let s:plugins_local = []
" ensure plugins root is in rtp.
let s:plugins_root = ''
let s:rtp = map(split(&rtp, ','), 's:TrSlash(v:val)')

for s:root in exists('g:plugins_root') ? [g:plugins_root] : []
      \ + [expand('~/vimfiles'), expand('~/.vim')]
  if index(s:rtp, s:TrSlash(s:root)) >= 0
    let s:plugins_root =  s:root . '/pack/rc/opt'
    break
  endif
endfor
if empty(s:plugins_root)
  throw '`g:plugins_root` is not in runtimepath!'
endif

" entrypoint {{{1
command! -bar -nargs=* -complete=custom,s:pack_comp Pack call s:pack(<args>)

" s:pack() {{{1
function! s:pack(...) abort
  if a:0 == 0
    for [k, v] in items(s:function_dict)
      echon '['
      echohl Special | echon k | echohl None
      echon '] '
      echon v.help
      echon "\n"
    endfor
    echo '(press any other key to cancel) > '
    let l:input = tolower(nr2char(getchar()))
    if has_key(s:function_dict, l:input)
      call call(function(s:function_dict[l:input].fn), [])
      redrawstatus
    else
      redrawstatus | echon 'cancelled.'
    endif
  else
    call call(function('s:pack_add'), a:000)
  endif
endfunction

let s:function_dict = #{
      \ s: #{fn: 's:pack_status', help: 'generate command to get plugin repo status'},
      \ u: #{fn: 's:pack_update', help: 'generate command to do "git fetch"'},
      \ c: #{fn: 's:pack_clean', help: 'prompt to cleanup unused repo'},
      \ h: #{fn: 's:pack_help_tags', help: 'run :helptags for managed plugins'},
      \ g: #{fn: 's:pack_commit_gen', help: 'generate command to get plugin commits (snapshot)'},
      \ a: #{fn: 's:pack_commit_apply', help: 'generate command to do "git checkout"'},
      \ }

" s:pack_add() {{{1
function! s:pack_add(url, ...) abort
  " TODO check input.
  let l:plugin = a:url

  if match(l:plugin, '\v^[~$]') >= 0
    let l:path = expand(l:plugin)
  else
    let l:path = fnamemodify(l:plugin, ':p')
  endif
  " local dir; it is hard to inject path to correct place in &rtp,
  " so just insert it at begin.
  if isdirectory(l:path)
    exec 'set rtp^=' .. fnameescape(l:path)
    if isdirectory(l:path .. '/after')
      exec 'set rtp+=' .. fnameescape(l:path) .. '/after'
    endif
    call add(s:plugins_local, l:path)
    return
  endif
  " local file; source it immediately.
  if filereadable(l:path)
    exec 'source' fnameescape(l:path)
    return
  endif

  let l:opt = a:0 > 0 ? a:1 : {}
  if type(l:opt) == type('')
    if !has_key(s:plugins, l:plugin)
      return
    endif
    let l:opt = {'commit': l:opt}
  else
    " only set when l:opt is not string (":Pack url, commit")
    if !has_key(l:opt, 'skip')
      let l:opt.skip = 0
    endif
  endif
  if has_key(s:plugins, l:plugin)
    let l:opt = extend(s:plugins[l:plugin], l:opt)
  endif
  let l:url = s:pack_construct_url(l:plugin)
  let l:dir = get(l:opt, 'as', s:pack_extract_git_dir(l:url))
  let l:opt.branch = get(l:opt, 'branch', '')
  let l:opt.commit = get(l:opt, 'commit', '')
  let l:opt.after = get(l:opt, 'after', 0)
  let l:opt.dir = l:dir
  let l:opt.url = l:url
  if !l:opt.skip
    if has('vim_starting')
      silent! execute 'packadd!' l:dir
      call s:pack_ftdetect(l:opt.after, l:dir)
    else
      if index(map(split(&rtp, ','), {_, i -> split(i, '\v[\/]')[-1]}), l:opt.dir) < 0
        " only load if not in rtp.
        execute 'packadd' l:dir
        call s:pack_ftdetect(l:opt.after, l:dir)
      endif
    endif
  endif
  let s:plugins[l:plugin] = l:opt
endfunction

" s:pack_update() {{{1
function! s:pack_update() abort
  let l:lines = []
  if !isdirectory(s:plugins_root)
    echo printf('plugin directory `%s` is not created;', s:plugins_root)
    echo 'create it? [y/N] '
    let l:yes = nr2char(getchar()) ==? 'y'
    if l:yes
      if mkdir(s:plugins_root, 'p') != 1
        throw 'create dir failed!'
      endif
    else
      redraws | echon 'cancelled.'
      return
    endif
  endif

  call s:pack_check_exists()

  " generate command.
  for [l:k, l:v] in items(s:plugins)
    " TODO check quote in various fields.
    call add(l:lines, printf('## %s', l:k))
    if has_key(l:v, 'path')
      if isdirectory(l:v.path . '/.git') || filereadable(l:v.path . '/.git')
        call add(l:lines, printf('git -C %s fetch --update-shallow', shellescape(l:v.path)))
      else
        call add(l:lines, '# is not git repository, skip.')
      endif
    else
      " l:v.path is not available if plugin is not installed yet.
      let l:real_dir = l:v.after ? printf('%s/after', l:v.dir) : l:v.dir
      if !empty(l:v.commit)
        call add(l:lines,
              \ printf('git -C %s clone -n %s %s && git -C %s/%s checkout %s',
              \ shellescape(s:plugins_root), l:v.url, l:real_dir,
              \ shellescape(s:plugins_root), l:real_dir, l:v.commit,
              \ ))
      elseif !empty(l:v.branch)
        call add(l:lines,
              \ printf('git -C %s clone --depth 1 -b %s %s %s',
              \ shellescape(s:plugins_root), l:v.branch, l:v.url, l:real_dir))
      else
        call add(l:lines, printf('git -C %s clone --depth 1 %s %s',
              \ shellescape(s:plugins_root), l:v.url, l:real_dir))
      endif
    endif
    call add(l:lines, '')
  endfor

  " output report.
  call s:pack_report(l:lines,
        \ ['#!/bin/sh',
        \ "{ grep -Ev '^(#|$)'" .
        \ ' | tr "\n" "\0" | xargs -r -0 -n 1 -P 5 sh -c; } <<\EOF']
        \ + [''],
        \ ['EOF'])
endfunction

" s:pack_status() {{{1
function! s:pack_status() abort
  call s:pack_check_exists()
  let l:lines = []
  for [l:k, l:v] in items(s:plugins)
    " TODO check quote in various fields.
    call add(l:lines, '')
    call add(l:lines, printf('## %s', l:k))
    if has_key(l:v, 'path')
      if isdirectory(l:v.path . '/.git') || filereadable(l:v.path . '/.git')
        call add(l:lines, printf('printf "%%s\n" %s', shellescape(l:v.path)))
        call add(l:lines, printf('git -C %s log %s --oneline; echo',
              \ shellescape(l:v.path),
              \ shellescape('..origin/' .. (empty(l:v.branch) ? 'head' : l:v.branch))
              \ ))
      else
        call add(l:lines, '# is not git repository, skip.')
      endif
    else
      call add(l:lines, '# not downloaded, skip.')
    endif
  endfor

  call s:pack_report(l:lines, ['#!/bin/sh'], [])
endfunction

" s:pack_clean() {{{1
function! s:pack_clean() abort
  let l:keep = {}
  " it actually matches both files and dirs.
  let l:dir_clean = []
  for [l:k, l:v] in items(s:plugins)
    call extend(l:keep, {l:v.dir : l:k})
  endfor
  for l:i in globpath(s:plugins_root, '*', 0, 1)
    let l:name = get(l:keep, split(l:i, '\v[\/]')[-1])
    if !empty(l:name)
      let l:check_dir = s:plugins[l:name].after ? (l:i . '/after') : l:i
      if !isdirectory(l:check_dir)
            \ || (isdirectory(l:check_dir) && index([ ['.git'], [] ], readdir(l:check_dir)) >= 0)
        " remove empty (/ broken .git) dir;
        call add(l:dir_clean, l:i)
      endif
    else
      " remove dir not defined as plugin;
      call add(l:dir_clean, l:i)
    endif
  endfor
  if empty(l:dir_clean)
    echo 'no dir / file to clean.'
    return
  endif

  echo 'dir / file to clean:'
  for l:i in l:dir_clean
    echohl WarningMsg | echo l:i | echohl None
  endfor
  echo 'clean them? [y/N] '
  let l:yes = nr2char(getchar()) ==? 'y'
  let l:failed = 0
  if l:yes
    for l:i in l:dir_clean
      let l:failed += (delete(l:i, 'rf') != 0)
    endfor
    echo printf('dirs / files removed. %s', l:failed > 0 ? l:failed . ' failed.' : '')
  else
    redraws | echon 'cancelled.'
  endif
endfunction

" s:pack_help_tags() {{{1
function! s:pack_help_tags() abort
  let l:paths = []
  for l:v in values(s:plugins)
    if l:v.after
      let l:i = globpath(&pp, printf('pack/*/opt/%s/after', l:v.dir), 0, 1)
    else
      let l:i = globpath(&pp, printf('pack/*/opt/%s', l:v.dir), 0, 1)
    endif
    if !empty(l:i)
      call add(l:paths, l:i[0])
    endif
  endfor
  for l:i in extend(l:paths, s:plugins_local)
    let l:path = l:i .. '/doc'
    if isdirectory(l:path)
      execute 'helptags' fnameescape(l:path)
    endif
  endfor
endfunction

" s:pack_commit_gen() {{{1
function! s:pack_commit_gen() abort
  call s:pack_check_exists()
  let l:lines = []
  for [l:k, l:v] in items(s:plugins)
    if has_key(l:v, 'path')
          \ && (isdirectory(l:v.path . '/.git') || filereadable(l:v.path . '/.git'))
      call add(l:lines, printf('printf %%s %s',
            \ shellescape("Pack '" .. l:k .. "', '")))
      call add(l:lines, printf('git -C %s log -n 1 --format=%%H%s',
            \ shellescape(l:v.path), shellescape("'")))
    endif
  endfor
  call s:pack_report(l:lines, ['#!/bin/sh', '{'], ['}'])
endfunction

" s:pack_commit_apply() {{{1
function! s:pack_commit_apply() abort
  call s:pack_check_exists()
  let l:lines = []
  for [l:k, l:v] in items(s:plugins)
    if has_key(l:v, 'path')
          \ && (isdirectory(l:v.path . '/.git') || filereadable(l:v.path . '/.git'))
          \ && has_key(l:v, 'commit')
      call add(l:lines, printf('git -C %s checkout %s',
            \ shellescape(l:v.path), shellescape(l:v.commit)))
    endif
  endfor
  call s:pack_report(l:lines, ['#!/bin/sh', '{'], ['}'])
endfunction

" helper functions. {{{1
function! s:pack_construct_url(name) abort
  let name = a:name
  if name =~ '\v^(https|http|git|ssh)\://.+'
    return name
  else
    " TODO handle dirname as param, like vim-sh.
    return printf('https://github.com/%s', name)
  endif
endfunction

function! s:pack_ftdetect(after, name) abort
  if !exists("g:did_load_filetypes")
    " :filetype is off, so we can use :packadd to load ftdetect.
    return
  endif

  if empty(a:after)
    let l:path = globpath(&pp, printf('pack/*/opt/%s/ftdetect/*.vim', a:name), 0, 1)
  else
    let l:path = globpath(&pp, printf('pack/*/opt/%s/after/ftdetect/*.vim', a:name), 0, 1)
  endif
  for l:file in l:path
    execute 'silent source' fnameescape(l:file)
  endfor
endfunction

function! s:pack_extract_git_dir(url) abort
  let result = matchstr(a:url, '\v[^/]+$')
  let result = substitute(result, '\v\.git$', '', '')
  return result
endfunction

" used in Pack / PackStatus
function! s:pack_check_exists() abort
  " check is plugin is already available.
  for [l:k, l:v] in items(s:plugins)
    if l:v.after
      let l:i = globpath(&pp, printf('pack/*/opt/%s/after', l:v.dir), 0, 1)
    else
      let l:i = globpath(&pp, printf('pack/*/opt/%s', l:v.dir), 0, 1)
    endif
    if empty(l:i)
      if has_key(l:v, 'path')
        call remove(l:v, 'path')
      endif
    else
      let l:v['path'] = l:i[0]
    endif
  endfor
endfunction

" used in Pack / PackStatus
function! s:pack_report(lines, pre, post) abort
  let l:lines = a:lines
  enew | setl buftype=nofile
  let l:lines = a:pre + l:lines + a:post
  setl ft=sh
  call setline(1, l:lines)
endfunction

function! s:pack_comp(A, L, P) abort
  let l:loaded = map(split(&rtp, ','), {_, i -> split(i, '\v[\/]')[-1]})
  let l:result = []
  for [l:k, l:v] in items(s:plugins)
    if index(l:loaded, l:v.dir) < 0
      call add(l:result, string(l:k))
    endif
  endfor
  return join(l:result, "\n")
endfunction
