" vim: ft=vim fdm=marker
" UserCommand, but in vim9.

if !has('patch-8.2.3020')
  finish
endif

vim9script

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