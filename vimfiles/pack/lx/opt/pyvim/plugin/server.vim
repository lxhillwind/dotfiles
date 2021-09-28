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

def s:server_handler(channel: channel, msg: string): void
  var data: dict<any>
  try
    data = json_decode(msg)
  catch
    echomsg msg
    return
  endtry

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
    out_cb: function('s:server_handler'),
    err_cb: function('s:server_handler'),
    cwd: fnamemodify(pwd, ':h'),
    env: env,
    })
enddef

def s:send_input(...data: list<any>): void
  if data[0] == 'restart'
    s:job->job_stop()
    return
  endif
  if data[0] == 'help'
    # 0: op; 1..-2: args; -1: kwargs
    if len(data) == 3
      if s:complete_source->has_key(data[1])
        echo s:complete_source->get(data[1])
      else
        echoerr printf('worker method not found: %s', data[1])
      endif
    else
      echoerr 'usage: help {method-name}'
    endif
    return
  endif
  if s:job->job_status() != 'run'
    s:server()
  endif
  var request: dict<any> = {op: data[0], args: data[1 : ]}
  s:job->job_getchannel()->ch_sendraw(json_encode(request) .. "\n")
enddef

command! -nargs=+ -bang -range=0 -complete=custom,s:comp_func Py3
| s:send_input(<f-args>, {bang: <bang>false, range: <range>, line1: <line1>, line2: <line2>})
