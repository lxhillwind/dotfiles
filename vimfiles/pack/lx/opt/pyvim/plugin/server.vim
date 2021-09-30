vim9script

const pwd = fnamemodify(expand('<sfile>'), ':p:h')

# key: func name; value: func doc.
var s:complete_source: dict<string>

def s:comp_func(...args: list<any>): string
  if s:job->job_status() != 'run'
    s:server()
  endif
  return s:complete_source->keys()->join("\n")
enddef

def s:server_handler(stdout: bool, msg: string)
  var data: dict<any>
  if stdout && len(msg) > 1 && msg[0] == '{'
    try
      data = json_decode(msg)
    catch
      echo msg
      return
    endtry
  else
    if stdout
      if len(msg) > 0
        echo msg
      endif
    else
      echomsg msg
    endif
    return
  endif

  var resp: any = v:none

  var code: number = 0
  try
    if index(['cmd', 'execute'], data.op) >= 0
      if !exists(':' .. substitute(data.cmd, '\v^\s*', '', '')->split(' ')[0])
        throw 'ex command not found: ' .. data.cmd
      endif
    endif

    if data.op == 'completion'
      s:complete_source = extend(data.args[0], {
        help: 'show __doc__ of worker method',
        restart: 'restart worker process',
        })
      return
    elseif data.op == 'raise'
      try
        echohl ErrorMsg
        for i in data.args[1]->split("\n")
          echomsg i
        endfor
        echomsg data.args[0]
      catch /.*/
      finally
        echohl None
      endtry
      return
    elseif data.op == 'cmd'
      execute 'legacy' data.cmd
    elseif data.op == 'key'
      feedkeys(data.cmd, 't')
    elseif data.op == 'execute'
      resp = split(execute('legacy ' .. data.cmd), "\n")
    elseif data.op == 'eval'
      resp = eval(data.cmd)
    elseif data.op == 'fn'
      resp = call(data.cmd, data.args)
    endif
  catch /.*/
    resp = v:exception
    code = -1
  endtry
  try
    json_encode(resp)
  catch /.*/
    resp = string(resp)
  endtry
  s:send_input('response', {id: get(data, 'id'), data: resp, code: code})
enddef

def s:out_cb(_: channel, data: string)
  s:server_handler(true, data)
enddef

def s:err_cb(_: channel, data: string)
  s:server_handler(false, data)
enddef

var s:job: job

var s:python_path: string = exists('g:pyvim_host') ? g:pyvim_host : 'python3'
def s:server(): void
  const pyvim_rc: string =
    exists('g:pyvim_rc') && type(g:pyvim_rc) == v:t_string ? g:pyvim_rc : ''
  if !empty(pyvim_rc) && !filereadable(pyvim_rc)
    throw 'g:pyvim_rc is specified, but not readable!'
  endif
  const env: dict<string> = {PYVIM_RC: pyvim_rc}
  s:job = job_start([s:python_path, '-u', 'pyvim/runner.py'], {
    out_cb: function('s:out_cb'),
    err_cb: function('s:err_cb'),
    cwd: fnamemodify(pwd, ':h'),
    env: env,
    })
enddef

def s:send_input(data: string, param: dict<any>): void
  # we will split it with shellsplit in python.
  const data_list: list<string> = data->split(' ')
  if len(data_list) == 0
    throw 'invalid input! requires non-empty string!'
  endif
  if data_list[0] == 'restart'
    s:job->job_stop()
    return
  endif
  if data_list[0] == 'help'
    if len(data_list) == 2
      if s:complete_source->has_key(data_list[1])
        echo s:complete_source->get(data_list[1])
      else
        echoerr printf('worker method not found: %s', data_list[1])
      endif
    else
      echoerr 'usage: help {method-name}'
    endif
    return
  endif
  if s:job->job_status() != 'run'
    s:server()
  endif
  var request: dict<any> = {op: data, args: param}
  s:job->job_getchannel()->ch_sendraw(json_encode(request) .. "\n")
enddef

command! -nargs=+ -bang -range=0 -complete=custom,s:comp_func Py3
| s:send_input(<q-args>, {bang: <bang>false, range: <range>, line1: <line1>, line2: <line2>})
