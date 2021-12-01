" vim: ft=vim fdm=marker
" UserCommand, but in vim9.

if !has('patch-8.2.3020')
  finish
endif

vim9script noclear

# :Jobrun / :Jobstop / :Joblist / :Jobclear {{{1
command! -range=0 -nargs=+ Jobrun
| s:job_run(<q-args>, {range: <range>, line1: <line1>, line2: <line2>})
command! -nargs=* -bang -complete=custom,s:job_stop_comp Jobstop
| s:job_stop(<q-args>, <bang>0 ? 'kill' : 'term')
command! Joblist call s:job_list()
command! -count Jobclear call s:job_clear(<count>)

var s:job_dict = {}

legacy function! s:job_exit_cb(job, ret) dict abort
  let buf = self.bufnr
  call appendbufline(buf, '$', '')
  call appendbufline(buf, '$', '===========================')
  call appendbufline(buf, '$', 'command finished with code ' .. a:ret)
endfunction

def s:job_run(cmd_a: string, opt: dict<any>)
  if exists(':Sh') != 2
    throw 'depends on vim-sh plugin!'
  endif
  if exists(':ScratchNew') != 2
    throw 'depends on `:ScratchNew`!'
  endif
  var cmd: string = cmd_a
  var flag: string = '-n'
  if match(cmd, '^-') >= 0
    var tmp = matchlist(cmd, '\v^(-\S+)\s+(.*)$')
    cmd = tmp[2]
    flag = tmp[1] .. 'n'
  endif
  var cmd_short = cmd
  if opt.range != 0
    cmd = printf('%s,%sSh %s %s', opt.line1, opt.line2, flag, cmd)
  else
    cmd = printf('Sh %s %s', flag, cmd)
  endif
  var job_d = json_decode(execute(cmd))
  ScratchNew
  var bufnr = bufnr()
  var d = {bufnr: bufnr, func: function('s:job_exit_cb')}
  wincmd p
  extend(s:job_dict, {
    [bufnr]: {
     job: job_start(
       job_d.cmd, extend(job_d.opt, {
         out_io: 'buffer', err_io: 'buffer',
         out_buf: bufnr, err_buf: bufnr,
         exit_cb: d.func,
       })
      ),
     cmd: cmd_short,
     }
    })
enddef

def s:job_stop(id_a: string, sig: string)
  var id = empty(id_a) ? bufnr() : str2nr(matchstr(id_a, '\v^\d+'))
  if has_key(s:job_dict, id)
    job_stop(s:job_dict[id].job, sig)
  else
    throw 'job not found: buffer id ' .. id
  endif
enddef

legacy function! s:job_stop_comp(A, L, P) abort
  let result = []
  for [k, v] in items(s:job_dict)
    if v.job->job_status() == 'run'
      call add(result, printf('%s: %s', k, v.cmd))
    endif
  endfor
  return join(result, "\n")
endfunction

def s:job_list()
  for [k, v] in items(s:job_dict)
    echo printf("%s:\t%s\t%s", k, v.job, v.cmd)
  endfor
enddef

def s:job_clear(num: number)
  for item in num > 0 ? [num] : keys(s:job_dict)
    var job = get(s:job_dict, item)
    if !empty(job)
      if job.job->job_info().status != 'run'
        remove(s:job_dict, item)
      endif
    endif
  endfor
enddef

# :Mpc {{{1
if executable('mpc')
  command! Mpc s:mpc_main()

  var s:mpc_prop_type = 'song'

  def s:mpc_main()
    enew | setl filetype=mpc buftype=nofile noswapfile nobuflisted
    var buf = bufnr()
    prop_type_add(s:mpc_prop_type, {bufnr: buf})
    var i = 1
    for line in split(system('mpc playlist'), "\n")
      setline(i, line)
      prop_add(i, 1, {type: s:mpc_prop_type, id: i, bufnr: buf})
      i += 1
    endfor
    nnoremap <buffer> <CR> <cmd>call <SID>mpc_play()<CR>
  enddef

  def s:mpc_play()
    var props = prop_list(line('.'))
    if len(props) == 0
      return
    endif

    var prop = props[-1]
    if prop['type'] ==# s:mpc_prop_type
      silent call job_start(printf('mpc play %d', prop.id))
    endif
  enddef
endif

# :ChdirTerminal [path]; default path: selection / <cfile>; expand() is applied; use existing terminal if possible; bang: using Sh -w (default: Sh -t) {{{1
command! -bang -nargs=* -range=0 ChdirTerminal call s:chdir_terminal(<bang>false, <range>, <q-args>)

def s:chdir_terminal(bang: bool, range: number, path_a: string)
  var path = path_a ?? ( range > 0 ? Selection() : expand('<cfile>') )
  if match(path, '\v^[~$<%]') >= 0
    path = expand(path)
  endif
  path = fnamemodify(path, ':p')
  if filereadable(path)
    path = fnamemodify(path, ':h')
  endif
  if !isdirectory(path)
    throw 'is not directory: ' .. path
  endif

  const bufs: list<number> = tabpagebuflist()
  if !bang
    for i in term_list()->filter(
      (_, x) => x->term_getstatus() == 'running'
      )
      const idx: number = index(bufs, i)
      if idx >= 0
        echo printf('chdir in window [%d]? [y/N] ', idx + 1)
        if nr2char(getchar()) ==? 'y'
          execute ':' .. (idx + 1) 'wincmd w'
          call feedkeys(printf('%scd %s', mode() == 'n' ? 'i' : '', shellescape(path)), 't')
        else
          redrawstatus | echon 'cancelled.'
        endif
        return
      endif
    endfor
  endif
  const cmd = bang ? 'Sh -w' : 'Sh -t'
  execute 'Cd' path ':' .. cmd
enddef

# g:Popup(cmd: string, cb: fn<list<string>>, ctx : dict = {}); {{{1

# variable used in popup terminal;
var s:popup_tmpfile: string = ''
var s:win: number

# variable used in Sh -w popup program;
var s:tmpfiles_dict: dict<func> = {}

def g:Popup(cmd: string, cb: func, ...args: list<dict<any>>)
  var exec_pre: string = 'exec'
  var range: string = ''
  var kwargs: dict<any> = args->get(0) ?? {}
  if kwargs->has_key('input') || kwargs->has_key('ex')
    const stdin_f: string = tempname()
    if kwargs->has_key('input')
      writefile(kwargs.input->split("\n"), stdin_f)
    else
      writefile(execute(kwargs.ex)->split("\n"), stdin_f)
    endif
    exec_pre ..= (' < ' .. shellescape(stdin_f))
  endif
  if kwargs->get('range', 0) > 0
    range = printf(':%d,%d', kwargs.line1, kwargs.line2)
  endif
  var tmpfile: string = tempname()
  exec_pre ..= (' > ' .. shellescape(tmpfile))
  var res: dict<any> = json_decode(execute(printf('%sSh -n %s; %s', range, exec_pre, cmd)))

  # use Sh -w as popup, then we set s:tmpfiles_dict.
  if kwargs->has_key('program')
    const program: string = kwargs.program
    if match(program, '\v[^a-z]') >= 0
      throw printf('invalid program: "%s"', program)
    endif

    if !exists('g:vimserver_env')
      || match(get(g:vimserver_env, 'VIMSERVER_BIN', '.sh'), '\v\.sh$') >= 0
      throw 'vimserver-helper (.exe) not available!'
    endif

    var exe: string = g:vimserver_env['VIMSERVER_BIN']
    var server: string = g:vimserver_env['VIMSERVER_ID']

    s:tmpfiles_dict[tmpfile] = cb
    exe = shellescape(exe)
    server = shellescape(server)
    tmpfile = shellescape(tmpfile)
    var title: string = kwargs->get('title', '') ?? 'Selection'
    if match(title, '\v[^a-zA-Z_-]') >= 0
      # Sh -title=xxx does not accept too many type of char.
      title = 'Selection'
    endif
    execute(printf("%sSh -c,w=%s,title=%s %s; sh -c '\"$@\" && %s %s %s %s' - %s",
                    range, program, title, exec_pre,    exe, server, 'Tapi_popup_cb', tmpfile, cmd))
    # exit now!
    return
  endif

  # use builtin popup, then s:tmpfile can be set safely.
  # (popup terminal steals focus).
  s:popup_tmpfile = tmpfile
  var buf = term_start(res.cmd, extendnew(res.opt, {exit_cb: function('s:term_exit_cb'), hidden: 1}))
  const width: number = min([&columns - 10, 80])
  const height: number = min([&lines - 5, 24])
  s:win = popup_create(buf, {minwidth: width, maxwidth: width, minheight: height, maxheight: height, callback: function('s:popup_close_cb', [cb])})
enddef

def s:term_exit_cb(_: job, code: number)
  popup_close(s:win, code == 0 ? readfile(s:popup_tmpfile) : [])
enddef

def s:popup_close_cb(cb: func, _: number, result: list<string>)
  # TODO is this check required?
  if !empty(result)
    call(cb, [result])
  endif
enddef

# it will be called from g:Tapi_popup_cb (also defined in this file).
def PopupCallback(tmpfile: string)
  if s:tmpfiles_dict->has_key(tmpfile)
    # -1 is random.
    # TODO check exitcode? (seems not necessary)
    s:popup_close_cb(s:tmpfiles_dict[tmpfile], -1, readfile(tmpfile))
    remove(s:tmpfiles_dict, tmpfile)
  endif
enddef

# :Select {buffer|filelist|color} {{{1
command! -nargs=1 -range=0 -complete=custom,s:SelectComp Select
| call s:Select(<q-args>, {range: <range>, line1: <line1>, line2: <line2>})

# platform dependent setting
# TODO win32: check if tty is available (conpty or winpty)
const ctx_use_w_program: bool = has('win32')

# Select() and it's comp {{{2
def SelectComp(..._: list<any>): string
  return s:sources->keys()->join("\n")
enddef

def Select(source: string, ctx: dict<any>)
  if s:sources->has_key(source)
    call(s:sources[source], [ctx])
  else
    throw printf('selection not implemented: "%s"!', source)
  endif
enddef

# buffers / LsBuffers() {{{2
def LsBuffers(ctx: dict<any>)
  g:Popup(
    'fzf',
    (s: list<string>) => {
      const bufnr = s[0]->matchstr('\v^\s*\zs(\d+)\ze')
      execute ':' .. bufnr .. 'b'
      },
    extendnew({ex: 'ls', title: 'select-buffer'},
      ctx_use_w_program ? {program: 'cmd'} : {}),
    )
enddef

# color / Color() {{{2
def Color(ctx: dict<any>)
  g:Popup(
  'fzf',
  (s: list<string>) => {
    execute 'color' fnameescape(s[0])
    },
  extendnew({
      title: 'select-color',
      input: globpath(&rtp, "colors/*.vim", 0, 1)
        ->mapnew((_, i) => i->split('[\/.]')->get(-2))->join("\n")},
    ctx_use_w_program ? {program: 'cmd'} : {}),
    )
enddef

# filelist / FileList() {{{2
def FileList(ctx: dict<any>)
  if ctx.range == 0
    throw 'range is required!'
  endif
  g:Popup(
  'fzf',
  (s: list<string>) => {
    execute 'e' fnameescape(s[0])
    },
  extendnew(
    extendnew(ctx, {title: 'select-filelist'}),
    ctx_use_w_program ? {program: 'cmd'} : {}),
    )
enddef

# register new source here! {{{2
const s:sources: dict<func> = {
  buffer: LsBuffers,
  color: Color,
  filelist: FileList,
  }

# g:Tapi_popup_cb() {{{2
def g:Tapi_popup_cb(nr: number, arg: list<string>)
  const tmpfile = arg->get(0, '')
  if !empty(tmpfile)
    PopupCallback(tmpfile)
  endif
enddef
