" tasks defenition is loaded from list of files:  {{{1
"   g:tasks_config_paths (default: [<sfile>:h/tasks.ini])
"
" available command:
"   " trigger tasks selection with this keymap:
"   <Plug>(tasks-select) (support normal mode and visual mode)
"
" EXAMPLE CONFIG:
" # vim:ft=dosini
" [run]
" # press r to trigger this task
" @key = r
" # match all files, but not directory.
" @glob = *,!**/
" # execute ex cmd '!python %:S' if &ft is python
" python = !python %:S
"
" [run:rust]
" # match if one of its parents contains Cargo.toml.
" @marker = Cargo.toml
" # execute cmd from project dir
" @workdir = @project
" # execute '!cargo run' for any file in this directory (and nested sub directory).
" * = !cargo run
"
" [run:rust:disable]
" @glob = /a/special/dir
" # this profile will overwrite run:rust, so excmd defined here is used;
" # but since it is empty, it is not shown finally.
" rust =
"
" [cat:selection]
" @key = c
" @glob = *
" # only matches visual mode
" @mode = v
" # visual selection must be done in provided ex cmd, which is a lot of work.
" # so here is an example using cmd from external plugin.
" sh = Sh -v cat
"
" TASKS SPEC:
"
" file format: dosini
"
" section: defines a profile.
"
" section can be re-defined.
"
" profile: key is &ft, value is corresponding ex cmd to execute; empty value
" will be ignored; key '*' will match all other filetype.
"
" profile special key:
" @key: required; assign key to this profile (if this profile is used).
" @glob: required; ',' delimited; if does not match %, then skip this profile.
"   '*' matches any char sequence (excludes '/');
"   '**' behaves like in gitignore;
"   '*' standalone matches anything;
"   if any pattern starting with '!' matches, then skip this profile.
"   use '/' as pathsep even on Windows.
" @mode: default 'n', skip if not in normal mode; 'v' matches visual mode.
" @marker: define project_dir; ',' delimited; '/' in it is allowed;
"   if defined, skip if not match.
" @workdir: ex cmd will be executed in this dir; default cwd; special value:
"   '@project' means project dir defined by @marker;
"   '@buffer' means buffer's parent dir;
"   others will be expanded using `expand()`.
"
" profile inherit:
" profile `x:y:z` will inherit keys from `x:y`, which inherit keys from `x`;
" if `x:y:z` is matched, then `x:y`, `x` will be skipped.
" But '*' defined cmd has higher priority than matched filetype cmd defined in
" its parents.
"
" empty value:
" set @marker / @workdir / @mode to empty value is like unset them, without
" inheriting from its parent.
" set @glob / @key to empty value will cause error.
" set value of &ft key to empty value is like disable cmd for it.
"
" INI SPEC:
" '#' / ';' starts comment (prefix spaces are allowed);
" section name are inside '[' and ']';
" key / value is delimited by the first '=' character;
" key_without_value is NOT allowed; use `key =` instead. }}}1

if v:version < 703
  finish
endif

nmap <Space>r <Plug>(tasks-select)
xmap <Space>r <Plug>(tasks-select)

" impl {{{1
function! s:raise(msg, line) abort
  throw printf('%s %s', a:msg, a:line)
endfunction

function! s:parse(lines) abort
  let result = []

  let l:section = ''
  let l:kv = {}
  let l:i = 0

  for l:line in a:lines
    let l:i += 1
    " comment starts with '#' or ';'; empty line is also ignored.
    if match(l:line, '\v^\s*(([#;].+)|)$') >= 0
      continue
    endif
    let p_section = matchlist(l:line, '\v^\[(.+)\]\s*%($|#.+)$')
    if len(p_section) && len(p_section[1])
      " store last section
      if !empty(l:section)
        let result = add(result, [l:section, l:kv])
      endif

      let l:section = p_section[1]
      let l:kv = {}
      continue
    endif
    if empty(l:section)
      call s:raise('find line before section:', l:i)
    endif
    " k / v is delimited using '=';
    " spaces around the delimiter is ignored.
    let p_kv = matchlist(l:line, '\v^([^=]{-})\s*[=]\s*(.*)$')
    if !len(p_kv) || !len(p_kv[1])
      call s:raise('parse "k = v" error at line:', l:i)
    endif
    let l:kv[p_kv[1]] = p_kv[2]
  endfor

  if !empty(l:section)
    let result = add(result, [l:section, l:kv])
  endif

  return result
endfunction

function! s:ctx(mode) abort
  let l:filename = expand('%:p')
  if empty(l:filename) || index(['terminal', 'nofile'], &buftype) >= 0
    let l:filename = getcwd()
    if !empty(l:filename)
      " add suffix to match glob.
      let l:filename = l:filename . '/'
    endif
  endif
  if has('win32')
    " use / as pathsep even on Windows.
    let l:filename = substitute(l:filename, '\', '/', 'g')
  endif
  let result = {
        \ 'filetype': &ft,
        \ 'filename': l:filename,
        \ 'mode': a:mode,
        \ }
  return result
endfunction

function! s:file_matched(path, pattern) abort
  let matched = 0
  for pattern in split(a:pattern, ',')
    if pattern[0] == '!'
      let reverse = 1
      let pattern = pattern[1:]
    else
      let reverse = 0
    endif

    if pattern != '*'
      " expand ~
      let pattern = substitute(pattern, '\v^\~\ze(/|$)', expand('~'), '')
      " escape special char
      let pattern = substitute(pattern, '\v[+=?{@>!<^$.\\]', '\\&', 'g')
      " '*'
      let pattern = substitute(pattern, '\v[^*]\zs\*\ze[^*]', '[^/]*', 'g')
      " gitignore like '**'
      let pattern = substitute(pattern, '\v/\*\*/', '/(|.*/)', 'g')
      let pattern = substitute(pattern, '\v^\*\*/', '.*/', 'g')
      let pattern = substitute(pattern, '\v/\*\*$', '/.*', 'g')
    endif

    if pattern == '*' || match(a:path, '\v^' . pattern . '$') >= 0
      if reverse
        return 0
      else
        let matched = 1
      endif
    endif
  endfor
  return matched
endfunction

function! s:check_marker(path, marker) abort
  for marker in split(a:marker, ',')
    let path = a:path
    while 1
      if isdirectory(path . '/' . marker) || filereadable(path . '/' . marker)
        return path
      endif
      let parent = fnamemodify(path, ':h')
      if path == parent
        break
      endif
      let path = parent
    endwhile
  endfor
  return 0
endfunction

let s:file = expand('<sfile>')
function! s:config_paths() abort
  return get(g:, 'tasks_config_paths',
      \ [fnamemodify(s:file, ':p:h') . '/tasks.ini'])
endfunction

function! s:read_config() abort
  let result = []
  let config_exists = 0
  for item in s:config_paths()
    if filereadable(item)
      let result = extend(result, s:parse(readfile(item)))
      let config_exists = 1
    endif
  endfor
  if !config_exists
    throw 'no g:tasks_config_paths specified (or readable)!'
  endif
  return result
endfunction

function! s:find_key(cfg, section, key) abort
  " returns [section, key]; key == 0 or empty(section) means not found.
  let [cfg, section, key] = [a:cfg, a:section, a:key]
  if !has_key(cfg, section)
    return ['', 0]
  endif
  if has_key(cfg[section], key)
    return [section, cfg[section][key]]
  endif
  let final_col = match(section, '\v^.+\zs:\ze[^:]+$')
  if final_col >= 0
    return s:find_key(cfg, section[0:final_col-1], key)
  else
    return ['', 0]
  endif
endfunction

function! s:check(mode) abort
  let order = []
  let result = {}
  let ctx = s:ctx(a:mode)
  let config_list = s:read_config()
  let config = {}
  for [k, v] in config_list
    let config[k] = v
  endfor

  for [k, v] in config_list
    " check mode
    let [_, mode] = s:find_key(config, k, '@mode')
    if empty(mode)
      let mode = 'n'
    endif
    if ctx.mode != mode
      continue
    endif
    " check key
    let [key_sec, key] = s:find_key(config, k, '@key')
    if empty(key)
      echoerr '@key not defined! section:' k
      continue
    endif
    " check %
    let [_, glob] = s:find_key(config, k, '@glob')
    if empty(glob)
      echoerr '@glob not defined! section:' k
      continue
    endif
    if !s:file_matched(ctx.filename, glob)
      continue
    endif
    " check marker
    let [_, marker] = s:find_key(config, k, '@marker')
    if !empty(marker)
      let project_dir = s:check_marker(ctx.filename, marker)
      if empty(project_dir)
        continue
      endif
    else
      let project_dir = 0
    endif
    " check &ft
    let [sec, cmd] = s:find_key(config, k, ctx.filetype)
    let [sec_glob, cmd_glob] = s:find_key(config, k, '*')
    if cmd is# 0 && cmd_glob is# 0
      continue
    endif
    if cmd is# 0
      let cmd = cmd_glob
    elseif cmd_glob is# 0
      :
    else
      " glob in longer section wins.
      if len(sec_glob) > len(sec)
        let cmd = cmd_glob
      endif
    endif
    " check @workdir
    let [_, workdir] = s:find_key(config, k, '@workdir')
    if workdir == '@project'
      let workdir = project_dir
    elseif workdir == '@buffer'
      let workdir = fnamemodify(ctx.filename, ':p:h')
    elseif !empty(workdir)
      let workdir = expand(workdir)
    endif

    " store by key
    let new_list = []
    " check if longer section already in it.
    let used = 0
    for item in get(result, key, [])
      if len(item.section) > len(k) && item.section[0:len(k)] == k . ':'
        let used = 1
        break
      endif
      if len(k) > len(item.section) && k[0:len(item.section)] == item.section . ':'
        " ignore item
        continue
      endif
      if item.section !=# k
        let new_list = add(new_list, item)
      endif
    endfor
    if used
      continue
    endif
    if index(order, key) < 0
      let order = add(order, key)
    endif
    let result[key] = add(new_list, {
          \ 'origin': key_sec, 'section': k, 'cmd': cmd,
          \ 'workdir': workdir})
  endfor

  let filtered = {}
  for [key, list] in items(result)
    " remove empty cmd.
    call filter(list, '!empty(v:val.cmd)')
    if !empty(list)
      let filtered[key] = list
    endif
  endfor
  return [order, filtered]
endfunction

" execute cmd with different dir {{{
function! s:cd_exe(workdir, cmd) abort
  let old_cwd = getcwd()
  let buf = bufnr('')
  try
    " use buffer variable to store cwd if `exe` switch to new window
    let b:tasks_old_cwd = old_cwd
    exe 'lcd' fnameescape(a:workdir)
    redrawstatus | exe a:cmd
  finally
    if buf == bufnr('')
      if exists('b:tasks_old_cwd')
        unlet b:tasks_old_cwd
      endif
      exe 'lcd' fnameescape(old_cwd)
    endif
  endtry
endfunction

function! s:cd_reset()
  if exists('b:tasks_old_cwd')
    try
      exe 'lcd' fnameescape(b:tasks_old_cwd)
    finally
      unlet b:tasks_old_cwd
    endtry
  endif
endfunction

augroup tasks_cd
  au!
  au BufEnter * call s:cd_reset()
augroup END
" }}}

function! s:ui(mode) abort
  let l:more = &more
  try
    set nomore
    call s:ui_impl(a:mode)
  finally
    if l:more
      set more
    endif
  endtry
endfunction

function! s:ui_impl(mode) abort
  let [order, result_d] = s:check(a:mode)
  if empty(result_d)
    redrawstatus | echon 'task not found.' | return
  endif
  for key in order
    let items = get(result_d, key, [])
    if len(items) >= 1
      let item = items[0]
      echo ' '
      echohl String
      echon key
      if len(items) > 1
        echohl Function
        echon '...'
      endif
      echohl Comment
      if len(items) > 1
        echon "\t" .. item.origin
        echohl None
      else
        echon "\t" .. item.section
        echohl None
        echon "\t" item.cmd
      endif
    endif
  endfor
  echo "select task by its key: "
  let choice = nr2char(getchar())
  if !has_key(result_d, choice)
    redrawstatus | echon 'task not selected.' | return
  endif
  let result_l = result_d[choice]
  if len(result_l) > 1
    redrawstatus
    let idx = 0
    for item in result_l
      let idx += 1
      echo ' '
      echohl String
      echon idx
      echohl Comment
      echon "\t" .. item.section
      echohl None
      echon "\t" .. item.cmd
    endfor
    echo "select task by its index (1-based): "
    let choice = nr2char(getchar())
    if choice !~ '[1-9]'
      redrawstatus | echon 'task not selected.' | return
    endif
    let choice = str2nr(choice)
    if choice > len(result_l) || choice == 0
      redrawstatus | echon 'task not selected.' | return
    endif
    let result = result_l[choice-1]
  else
    let result = result_l[0]
  endif
  redrawstatus
  let workdir = get(result, 'workdir', 0)
  if !empty(workdir)
    call s:cd_exe(workdir, result.cmd)
  else
    try
      execute result.cmd
    finally
    endtry
  endif
endfunction

nnoremap <Plug>(tasks-select) :call <SID>ui('n')<CR>
xnoremap <Plug>(tasks-select) :<C-u>call <SID>ui('v')<CR>

" vim:fdm=marker:sw=2
