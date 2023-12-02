vim9script
if !executable('mpc')
    finish
endif

command! Mpc Mpc()

const mpc_prop_type = 'song'

def Mpc()
    enew | setl filetype=mpc buftype=nofile noswapfile nobuflisted
    const buf = bufnr()
    prop_type_add(mpc_prop_type, {bufnr: buf})
    var i = 1
    for line in split(system('mpc playlist'), "\n")
        setline(i, line)
        prop_add(i, 1, {type: mpc_prop_type, id: i, bufnr: buf})
        i += 1
    endfor
    const nr = str2nr(system('mpc current -f "%position%"'))
    execute 'norm' nr .. 'G'
    nnoremap <buffer> <CR> <ScriptCmd>MpcPlay()<CR>
    # should we map <2-LeftMouse> to <CR> globally?
    nnoremap <buffer> <2-LeftMouse> <ScriptCmd>MpcPlay()<CR>
    nnoremap <buffer> <C-l> <ScriptCmd>MpcJumpToPlay()<CR>
    nnoremap <buffer> <C-g> <ScriptCmd>MpcStatus()<CR>
enddef

def MpcPlay()
    const props = prop_list(line('.'))
    if len(props) == 0
        return
    endif

    const prop = props[-1]
    if prop['type'] == mpc_prop_type
        job_start(printf('mpc play %d', prop.id))
    endif
enddef

def MpcJumpToPlay()
    const id: number = system('mpc --format %position% current')->str2nr()
    var ctx: dict<any>
    for direction in ['f', 'b']
        ctx = prop_find({id: id}, direction)
        if !empty(ctx)
            execute ':' .. ctx.lnum
            return
        endif
    endfor
enddef

def MpcStatus()
    const status: string = system('mpc status "%currenttime%/%totaltime%%percenttime%"')->trim()
    const song: string = system('mpc --format "[[%artist% - ]%title%]|[%file%]" current')->trim()
    echo status " ~ " song
enddef
