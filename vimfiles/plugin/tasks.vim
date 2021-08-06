" tasks defenition is loaded from list of files:
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
" # match all files.
" @glob = *
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
" profile: key is &ft, value is corresponding ex cmd to execute; empty value
" will be ignored; key '*' will match all other filetype.
"
" profile special key:
" @key: required; assign key to this profile (if this profile is used).
" @glob: required; ',' delimited; if does not match %, then skip this profile.
"   '*' matches char sequence longer than 0 (except '/');
"   '**' matches char sequence with any length (include '/');
"   '*' standalone matches anything.
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
" key / value is delimited by the first ':' or '=' character;
" key_without_value is NOT allowed; use `key =` instead.

function! s:raise(msg, line) abort
  throw printf('%s %s', a:msg, a:line)
endfunction

function! s:parse(lines) abort
  let result = {}

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
        let result[l:section] = l:kv
      endif

      let l:section = p_section[1]
      if has_key(result, l:section)
        call s:raise('found duplicate section:', l:i)
      endif
      let l:kv = {}
      continue
    endif
    if empty(l:section)
      call s:raise('find line before section:', l:i)
    endif
    " k / v is delimited using '=' or ';';
    " spaces around the delimiter is ignored.
    let p_kv = matchlist(l:line, '\v^([^:=]{-})\s*[:=]\s*(.*)$')
    if !len(p_kv) || !len(p_kv[1])
      call s:raise('parse "k = v" error at line:', l:i)
    endif
    let l:kv[p_kv[1]] = p_kv[2]
  endfor

  if !empty(l:section)
    let result[l:section] = l:kv
  endif

  return result
endfunction

function! s:ctx(mode) abort
  let l:filename = expand('%:p')
  if empty(l:filename) || &buftype == 'terminal'
    let l:filename = getcwd()
    if !empty(l:filename)
      " add suffix to match glob.
      let l:filename = l:filename .. (has('win32') ? '\' : '/')
    endif
  endif
  let result = #{
        \ filetype: &ft,
        \ filename: l:filename,
        \ mode: a:mode,
        \ }
  return result
endfunction

function! s:file_matched(path, pattern) abort
  if a:pattern == '*'
    return 1
  endif
  for pattern in split(a:pattern, ',')
    let pattern = substitute(pattern, '\v^\~\ze(/|$)', expand('~'), '')
    let pattern = substitute(pattern, '\v[+=?{@>!<^$.\\]', '\\&', 'g')
    let pattern = substitute(pattern, '\v[^*]\zs\*\ze[^*]', '[^/]*', 'g')
    let pattern = substitute(pattern, '\v\*\*', '.*', 'g')
    if match(a:path, '\v^' . pattern . '$') >= 0
      return 1
    endif
  endfor
  return 0
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
let s:config_paths = get(g:, 'tasks_config_paths',
      \ [fnamemodify(s:file, ':p:h') . '/tasks.ini'])

function! s:read_config() abort
  let result = {}
  for item in s:config_paths
    let result = extend(result, s:parse(readfile(expand(item))))
  endfor
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
  let result = {}
  let ctx = s:ctx(a:mode)
  let config = s:read_config()
  for [k, v] in items(config)
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
      let new_list = add(new_list, item)
    endfor
    if used
      continue
    endif
    let result[key] = add(new_list, #{
          \ origin: key_sec, section: k, cmd: cmd,
          \ workdir: workdir})
  endfor

  let filtered = {}
  for [key, list] in items(result)
    " remove empty cmd.
    call filter(list, '!empty(v:val.cmd)')
    if !empty(list)
      let filtered[key] = list
    endif
  endfor
  return filtered
endfunction

" execute cmd with different dir {{{
function! s:cd_exe(workdir, cmd) abort
  let old_cwd = getcwd()
  let buf = bufnr()
  try
    " use buffer variable to store cwd if `exe` switch to new window
    let b:tasks_old_cwd = old_cwd
    exe 'lcd' a:workdir
    redrawstatus | exe a:cmd
  finally
    if buf == bufnr()
      if exists('b:tasks_old_cwd')
        unlet b:tasks_old_cwd
      endif
      exe 'lcd' old_cwd
    endif
  endtry
endfunction

function! s:cd_reset()
  if exists('b:tasks_old_cwd')
    try
      exe 'lcd' b:tasks_old_cwd
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
  let result = s:check(a:mode)
  if empty(result)
    redrawstatus | echon 'task not found.' | return
  endif
  for [key, list] in items(result)
    for item in list
      echo key "\t" item.cmd "\t" item.section
    endfor
  endfor
  echo "select task by its key: "
  let choice = nr2char(getchar())
  if !has_key(result, tolower(choice))
    redrawstatus | echon 'task not selected.' | return
  endif
  let result = result[tolower(choice)]
  if len(result) > 1
    redrawstatus
    let idx = 0
    for item in result
      let idx += 1
      echon idx . ')' "\t" item.cmd "\t" item.section "\n"
    endfor
    echo "select task by its index (1-based): "
    let choice = nr2char(getchar())
    if choice !~ '[1-9]'
      redrawstatus | echon 'task not selected.' | return
    endif
    let choice = str2nr(choice)
    if choice > len(result) || choice == 0
      redrawstatus | echon 'task not selected.' | return
    endif
    let result = result[choice-1]
  else
    let result = result[0]
  endif
  redrawstatus
  let workdir = get(result, 'workdir', 0)
  if !empty(workdir)
    call s:cd_exe(workdir, result.cmd)
  else
    execute result.cmd
  endif
endfunction

nnoremap <Plug>(tasks-select) :call <SID>ui('n')<CR>
vnoremap <Plug>(tasks-select) :<C-u>call <SID>ui('v')<CR>

" vim:fdm=marker
