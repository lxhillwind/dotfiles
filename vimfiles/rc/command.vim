" vim: fdm=marker
" UserCommand

" snippet; :Scratch [filetype] / :ScratchNew [filetype] (with new window) {{{1
command -nargs=? -complete=filetype Scratch call <SID>scratch(<q-args>)
command! -nargs=? -complete=filetype
      \ ScratchNew call <SID>snippet_in_new_window(<q-args>)

function! s:scratch(ft) abort
  enew | setl buftype=nofile noswapfile bufhidden=hide
  if !empty(a:ft)
    exe 'setl ft=' . a:ft
  endif
endfunction

function! s:snippet_in_new_window(ft) abort
  exe printf('bel %dnew', &cwh)
  setl buftype=nofile noswapfile
  setl bufhidden=hide
  if !empty(a:ft)
    exe 'setl ft=' . a:ft
  endif
endfunction

" run vim command; :KvimRun {vim_command}... {{{1
command! -nargs=+ -complete=command KvimRun call s:show_output(execute(<q-args>))

" vim expr; :KvimExpr {vim_expr}... {{{1
command! -nargs=+ -complete=expression KvimExpr call s:show_output(eval(<q-args>))

function! s:show_output(data) abort
  ScratchNew
  for line in split(a:data, "\n")
    call append('$', line)
  endfor
  norm gg"_dd
endfunction

" insert shebang based on filetype; :KshebangInsert [content after "#!/usr/bin/env "] {{{1
command! -nargs=* -complete=shellcmd KshebangInsert
      \ call <SID>shebang_insert(<q-args>)

let g:vimrc_shebang_lines = {
      \'awk': 'awk -f', 'javascript': 'node', 'lua': 'lua',
      \'perl': 'perl', 'python': 'python', 'ruby': 'ruby',
      \'scheme': 'chez --script', 'sh': 'sh', 'zsh': 'zsh'
      \}

function! s:shebang_insert(args) abort
  let first_line = getline(1)
  if len(first_line) >= 2 && first_line[0:1] ==# '#!'
    " shebang exists
    throw 'shebang exists!'
  endif
  let shebang = '#!/usr/bin/env'
  if !empty(a:args)
    let shebang = shebang . ' ' . a:args
  elseif has_key(g:vimrc_shebang_lines, &ft)
    let shebang = shebang . ' ' . g:vimrc_shebang_lines[&ft]
  else
    throw 'shebang: which interpreter to run?'
  endif
  " insert at first line and leave cursor here (for further modification)
  normal ggO<Esc>
  let ret = setline(1, shebang)
  if ret == 0 " success
    normal $
  else
    throw 'setting shebang error!'
  endif
endfunction

" match long line; :KmatchLongLine {number} {{{1
" Refer: https://stackoverflow.com/a/1117367
command! -nargs=1 KmatchLongLine exe '/\%>' . <args> . 'v.\+'

" `J` with custom seperator; <visual>:J sep... {{{1
command! -nargs=1 -range J call s:join_line(<q-args>)
function! s:join_line(sep)
  let buf = @"
  try
    norm gv
    norm x
    let @" = substitute(@", "\n", a:sep, 'g')
    norm P
  finally
    let @" = buf
  endtry
endfunction

" edit selected line / column; :Kjump {{{1
command! -nargs=+ Kjump call <SID>jump_line_col(<f-args>)
function! s:jump_line_col(line, ...) abort
  execute 'normal' a:line . 'gg'
  if a:0 > 0
    let col = a:1
    if col > 1
      execute 'normal 0' . (col-1) . 'l'
    endif
  endif
endfunction

" Selection() {{{1
function! Selection() abort
  let tmp = @"
  try
    silent normal gvy
    return @"
  finally
    let @" = tmp
  endtry
endfunction

" :SetCmdText / SetCmdText() {{{1
function! SetCmdText(text) abort
  call feedkeys(':' .. a:text, 't')
endfunction

command! -nargs=+ SetCmdText call SetCmdText(<q-args>)

" `*` / `#` in visual mode (like `g*` / `g#`); dep: Selection() {{{1
vnoremap * :<C-u>call feedkeys('/\V' .. substitute(escape(Selection(), '\/'), "\n", '\\n', 'g') .. "\n", 't')<CR>
vnoremap # :<C-u>call feedkeys('?\V' .. substitute(escape(Selection(), '\/'), "\n", '\\n', 'g') .. "\n", 't')<CR>

" :Jobrun / :Jobstop / :Joblist / :Jobclear {{{1
if exists('*job_start')
  command! -range=0 -nargs=+ Jobrun call
        \ s:job_run(<q-args>, #{range: <range>, line1: <line1>, line2: <line2>})
  command! -nargs=* -bang -complete=custom,s:job_stop_comp Jobstop call
        \ s:job_stop(<q-args>, <bang>0 ? 'kill' : 'term')
  command! Joblist call s:job_list()
  command! -count Jobclear call s:job_clear(<count>)
endif

let s:job_dict = {}

function! s:job_exit_cb(job, ret) dict abort
  let buf = self.bufnr
  call appendbufline(buf, '$', '')
  call appendbufline(buf, '$', '===========================')
  call appendbufline(buf, '$', 'command finished with code ' . a:ret)
endfunction

function! s:job_run(cmd, opt) abort " {{{2
  if exists(':Sh') != 2
    throw 'depends on vim-sh plugin!'
  endif
  if exists(':ScratchNew') != 2
    throw 'depends on `:ScratchNew`!'
  endif
  let [cmd, opt] = [a:cmd, a:opt]
  if match(cmd, '^-') >= 0
    let tmp = matchlist(cmd, '\v^(-\S+)\s+(.*)$')
    let cmd = tmp[2]
    let flag = tmp[1] . 'n'
  else
    let flag = '-n'
  endif
  let cmd_short = cmd
  if opt.range != 0
    let cmd = printf('%s,%sSh %s %s', opt.line1, opt.line2, flag, cmd)
  else
    let cmd = printf('Sh %s %s', flag, cmd)
  endif
  let job_d = json_decode(execute(cmd))
  ScratchNew
  let bufnr = bufnr()
  let d = #{bufnr: bufnr, func: function('s:job_exit_cb')}
  wincmd p
  call extend(s:job_dict, {
        \ bufnr: #{
        \  job: job_start(
        \    job_d.cmd, extend(job_d.opt, #{
        \      out_io: 'buffer', err_io: 'buffer',
        \      out_buf: bufnr, err_buf: bufnr,
        \      exit_cb: d.func,
        \    })
        \   ),
        \  cmd: cmd_short,
        \  }
        \ })
endfunction

function! s:job_stop(id, sig) abort " {{{2
  if empty(a:id)
    let id = bufnr()
  else
    let id = str2nr(matchstr(a:id, '\v^\d+'))
  endif
  if has_key(s:job_dict, id)
    call job_stop(s:job_dict[id].job, a:sig)
  else
    throw 'job not found: buffer id ' . id
  endif
endfunction
" }}}

function! s:job_stop_comp(A, L, P) abort
  let result = []
  for [k, v] in items(s:job_dict)
    if v.job->job_status() == 'run'
      call add(result, printf('%s: %s', k, v.cmd))
    endif
  endfor
  return join(result, "\n")
endfunction

function! s:job_list() abort
  for [k, v] in items(s:job_dict)
    echo printf("%s:\t%s\t%s", k, v.job, v.cmd)
  endfor
endfunction

function! s:job_clear(num) abort
  for item in a:num ? [a:num] : keys(s:job_dict)
    let job = get(s:job_dict, item)
    if !empty(job)
      if job.job->job_info().status != 'run'
        call remove(s:job_dict, item)
      endif
    endif
  endfor
endfunction

" :Mpc {{{1
if executable('mpc')
  command! Mpc call s:mpc_main()

  let s:mpc_prop_type = 'song'

  function! s:mpc_main() abort
    enew | setl filetype=mpc buftype=nofile noswapfile nobuflisted
    let l:buf = bufnr()
    call prop_type_add(s:mpc_prop_type, {'bufnr': l:buf})
    let l:i = 1
    for line in split(system('mpc playlist'), "\n")
      call setline(l:i, line)
      call prop_add(l:i, 1, {'type': s:mpc_prop_type, 'id': l:i, 'bufnr': l:buf})
      let l:i += 1
    endfor
    nnoremap <buffer> <CR> <cmd>call <SID>mpc_play()<CR>
  endfunction

  function! s:mpc_play() abort
    let prop = prop_list(line('.'))
    if len(prop) == 0
      return
    endif

    let prop = prop[-1]
    if prop['type'] ==# s:mpc_prop_type
      let l:id = prop['id']
      silent call job_start(printf('mpc play %d', l:id))
    endif
  endfunction
endif

" :KqutebrowserEditCmd {{{1
if !empty($QUTE_FIFO)
  command! KqutebrowserEditCmd call s:qutebrowser_edit_cmd()

  function! s:qutebrowser_edit_cmd()
    setl buftype=nofile noswapfile
    call setline(1, $QUTE_COMMANDLINE_TEXT[1:])
    call setline(2, '')
    call setline(3, 'hit `<Space>q` to save cmd (first line) and quit')
    nnoremap <buffer> <Space>q :call writefile(['set-cmd-text -s :' . getline(1)], $QUTE_FIFO) \| q<CR>
  endfunction
endif

" :Tmux {{{1
if exists("$TMUX")
  command! -nargs=1 -bar Tmux call s:tmux_open_window(<q-args>)

  function! s:tmux_open_window(args)
    let options = {'c': 'neww', 's': 'splitw -v', 'v': 'splitw -h'}
    let ch = match(a:args, '\s')
    if ch == -1
      let [option, args] = [a:args, '']
    else
      let [option, args] = [a:args[:ch], a:args[ch:]]
    endif
    let option = get(options, trim(option))
    if empty(option)
      throw 'unknown option: ' . a:args . '; valid: ' . join(keys(options), ' / ')
    endif
    call system("tmux " . option . " -c " . shellescape(getcwd()) . args)
  endfunction
endif

" Cd <path> / :Cdalternate / :Cdhome / :Cdbuffer / :Cdproject [:]cmd... {{{1
command! -nargs=1 -complete=dir Cd call <SID>cd('', <q-args>)
command! -nargs=* -complete=command Cdalternate call <SID>cd('alternate', <q-args>)
command! -nargs=* -complete=command Cdhome call <SID>cd('home', <q-args>)
command! -nargs=* -complete=command Cdbuffer call <SID>cd('buffer', <q-args>)
command! -nargs=* -complete=command Cdproject call <SID>cd('project', <q-args>)

function! s:cd(flag, args)
  let cmd = a:args
  if a:flag ==# 'alternate'
    let path = fnamemodify(bufname('#'), '%:p:h')
  elseif a:flag ==# 'home'
    let path = expand('~')
  elseif a:flag ==# 'project'
    let path = s:get_project_dir()
  elseif a:flag ==# 'buffer'
    let path = s:get_buf_dir()
  else
    if a:args =~ '^:'
      throw 'path argument is required!'
    endif
    " Cd: split argument as path & cmd
    let path = substitute(a:args, '\v^(.{}) :.+$', '\1', '')
    let cmd = a:args[len(path)+1:]
  endif

  if !isdirectory(path)
    let path = expand(path)
  endif
  if !isdirectory(path)
    let path = fnamemodify(path, ':h')
  endif
  if !isdirectory(path)
    throw 'not a directory: ' . a:args
  endif

  if !empty(cmd)
    let old_cwd = getcwd()
    let buf = bufnr('')
    try
      " use buffer variable to store cwd if `exe` switch to new window
      let b:vimrc_old_cwd = old_cwd
      exe 'lcd' fnameescape(path)
      exe cmd
    finally
      if buf == bufnr('')
        if exists('b:vimrc_old_cwd')
          unlet b:vimrc_old_cwd
        endif
        exe 'lcd' fnameescape(old_cwd)
      endif
    endtry
  else
    exe 'lcd' fnameescape(path)
    if &buftype == 'terminal'
      call term_sendkeys(bufnr(''), 'cd ' . shellescape(path))
    endif
  endif
endfunction

function! s:cd_reset()
  if exists('b:vimrc_old_cwd')
    try
      exe 'lcd' fnameescape(b:vimrc_old_cwd)
    finally
      unlet b:vimrc_old_cwd
    endtry
  endif
endfunction

augroup vimrc_cd
  au!
  au BufEnter * call s:cd_reset()
augroup END

function! s:get_buf_dir()
  let path = expand('%:p:h')
  if empty(path) || &buftype == 'terminal'
    let path = getcwd()
  endif
  return path
endfunction

function! s:get_project_dir()
  let path = s:get_buf_dir()
  while 1
    if isdirectory(path . '/.git')
      return path
    endif
    if filereadable(path . '/.git')
      " git submodule
      return path
    endif
    let parent = fnamemodify(path, ':h')
    if path == parent
      return ''
    endif
    let path = parent
  endwhile
endfunction

" terminal-api related user function {{{1
if exists(':terminal') == 2
" sync terminal path to buffer path.
" TODO follow cd even when terminal buffer not in focus (with event?).
  function! Tapi_cd(nr, arg)
    if bufnr() == a:nr
      let p = a:arg[0]
      if has('win32') && match(p, '^/') >= 0
        let p = execute(printf("Sh cygpath -w '%s'", substitute(p, "'", "'\\\\''", 'g')))
      endif
      execute 'lcd' fnameescape(p)
    endif
  endfunction
endif
