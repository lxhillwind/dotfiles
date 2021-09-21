" vim:fdm=marker

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

let g:vimrc#shebang_lines = {
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
  elseif has_key(g:vimrc#shebang_lines, &ft)
    let shebang = shebang . ' ' . g:vimrc#shebang_lines[&ft]
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

" vim9 part {{{1 }}}
if exists(':def') != 2 | finish | endif

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
