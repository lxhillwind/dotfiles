vim9script

# utility (copied from ~/vimfiles/vimrc) {{{
const is_win32 = has('win32')
const has_gui = has('gui_running') || has('mac')
|| (has('linux') && (!empty($DISPLAY) || !(empty($WAYLAND_DISPLAY))))
# }}}

# snippet; :Scratch [filetype] / :ScratchNew [filetype] (with new window) {{{1
command -nargs=? -complete=filetype Scratch Scratch(<q-args>)
command! -nargs=? -complete=filetype ScratchNew SnippetInNewWindow(<q-args>)

def Scratch(ft: string)
    enew | setl buftype=nofile noswapfile bufhidden=hide
    if !empty(ft)
        exe 'setl ft=' .. ft
    endif
enddef

def SnippetInNewWindow(ft: string)
    exe printf('bel :%dnew', &cwh)
    setl buftype=nofile noswapfile
    setl bufhidden=hide
    if !empty(ft)
        exe 'setl ft=' .. ft
    endif
enddef

# run vim command; :KvimRun {vim_command}... {{{1
command! -nargs=+ -complete=command KvimRun ShowOutput(execute(<q-args>))

# vim expr; :KvimExpr {vim_expr}... {{{1
command! -nargs=+ -complete=expression KvimExpr ShowOutput(eval(<q-args>))

def ShowOutput(...data_: list<any>)
    # eval() return type may not be string, so use list<any> here.
    const data = type(data_[0]) == type('') ? data_[0] : string(data_[0])
    ScratchNew
    for line in split(data, "\n")
        append('$', line)
    endfor
    norm gg"_dd
enddef

# insert shebang based on filetype; :KshebangInsert [content after "#!/usr/bin/env "] {{{1
command! -nargs=* -complete=shellcmd KshebangInsert ShebangInsert(<q-args>)

g:vimrc_shebang_lines = {
    'awk': 'awk-f',  # awk: wrapper executing "awk -f" is required.
    'javascript': 'node', 'lua': 'lua',
    'perl': 'perl', 'python': 'python', 'ruby': 'ruby',
    'scheme': 'scheme-run',  # scheme: see ~/bin/scheme-run
    'sh': '/bin/sh', 'zsh': 'zsh',
}

def ShebangInsert(args: string)
    const first_line = getline(1)
    if len(first_line) >= 2 && first_line[0 : 1] == '#!'
        throw 'shebang exists!'
    endif
    var shebang: string
    if !empty(args)
        shebang = args
    elseif has_key(g:vimrc_shebang_lines, &ft)
        shebang = g:vimrc_shebang_lines[&ft]
    else
        throw 'shebang: which interpreter to run?'
    endif
    if match(shebang, '^/') >= 0
        shebang = '#!' .. shebang
    else
        shebang = '#!/usr/bin/env ' .. shebang
    endif
    # insert at first line and leave cursor here (for further modification)
    normal ggO<Esc>
    var ret = setline(1, shebang)
    if ret == 0  # success
        normal $
    else
        throw 'setting shebang error!'
    endif
enddef

# match long line; :KmatchLongLine {number} {{{1
# Refer: https://stackoverflow.com/a/1117367
command! -nargs=1 KmatchLongLine exe ':/\%>' .. <args> .. 'v.\+'

# `J` with custom seperator; <range>:J sep... {{{1
command! -nargs=1 -range J JoinLines(<q-args>, <range>, <line1>, <line2>)
def JoinLines(sep: string, range: number, line1: number, line2: number)
    const result = getline(line1, line2)->join(sep)
    deletebufline('%', line1, line2)
    append(max([line1 - 1, 0]), result)
    normal k
enddef

# edit selected line / column; :Kjump {{{1
command! -nargs=+ Kjump JumpToLineCol(<args>)
def JumpToLineCol(line: number, col: number = 0)
    execute 'normal' line .. 'gg'
    if col > 1
        execute 'normal 0' .. (col - 1) .. 'l'
    endif
enddef

# Selection() {{{1
def g:Selection(): string
    const tmp = @"
    var result = ''
    var success = false
    try
        silent normal gvy
        success = true
    finally
        result = @"
        @" = tmp
        if !success
            throw 'g:Selection() failed!'
        endif
    endtry
    return result
enddef

# :SetCmdText / SetCmdText() {{{1
def g:SetCmdText(text: string)
    feedkeys(':' .. text, 't')
enddef

command! -nargs=+ SetCmdText g:SetCmdText(<q-args>)

# :KqutebrowserEditCmd {{{1
if !empty($QUTE_FIFO)
    command! KqutebrowserEditCmd KqutebrowserEditCmd()

    def KqutebrowserEditCmd()
        setl buftype=nofile noswapfile
        setline(1, $QUTE_COMMANDLINE_TEXT[1 :])
        setline(2, '')
        setline(3, 'hit `<Space>q` to save cmd (first line) and quit')
        # weired bug with `map ... \| q...` in vim9script.
        legacy nnoremap <buffer> <Space>q :call writefile(['set-cmd-text -s :' .. getline(1)], $QUTE_FIFO) \| q<CR>
    enddef
endif

# :Tmux {{{1
if exists("$TMUX")
    command! -nargs=1 -bar Tmux TmuxOpenWindow(<q-args>)

    def TmuxOpenWindow(args_: string)
        var args: string = args_
        const options = {'c': 'neww', 's': 'splitw -v', 'v': 'splitw -h'}
        var ch = match(args, '\s')
        var option: string
        if ch == -1
            [option, args] = [args, '']
        else
            [option, args] = [args[: ch], args[ch :]]
        endif
        option = get(options, trim(option))
        if empty(option)
            throw 'unknown option: ' .. args .. '; valid: ' .. join(keys(options), ' / ')
        endif
        call system("tmux " .. option .. " -c " .. shellescape(getcwd()) .. args)
    enddef
endif

# terminal-api related user function {{{1
# sync terminal path to buffer path.
# TODO follow cd even when terminal buffer not in focus (with event?).
def g:Tapi_cd(nr: number, arg: list<string>)
    if bufnr() == nr
        var p = arg[0]
        if is_win32 && match(p, '^/') >= 0
            # why not using shellescape() here?
            p = execute(printf("Sh cygpath -w '%s'", substitute(p, "'", "'\\\\''", 'g')))
        endif
        silent execute 'lcd' fnameescape(p)
    endif
enddef

# :Jobrun / :Jobqfrun / :Jobstop / :Joblist / :Jobclear {{{1
command! -range=0 -nargs=+ Jobrun
| JobRun(<q-args>, {range: <range>, line1: <line1>, line2: <line2>, qf: false})
command! -range=0 -nargs=+ Jobqfrun
| JobRun(<q-args>, {range: <range>, line1: <line1>, line2: <line2>, qf: true})
command! -nargs=* -bang -complete=custom,JobStopComp Jobstop
| JobStop(<q-args>, <bang>0 ? 'kill' : 'term')
command! Joblist call JobList()
command! -count Jobclear call JobClear(<count>)

var job_dict = exists('job_dict') ? job_dict : {}

def JobOutCb(ctx: dict<any>, _: channel, msg: string)
    const buf = ctx.bufnr
    setqflist([], 'a', {nr: buf, lines: [msg]})
enddef

def JobExitCb(ctx: dict<any>, job: job, ret: number)
    const buf = ctx.bufnr
    var data = []
    add(data, '')
    add(data, '===========================')
    add(data, 'command finished with code ' .. ret)
    if ctx.qf
        setqflist([], 'a', {nr: buf, lines: data})
    else
        appendbufline(buf, '$', data)
    endif
enddef

def JobRun(cmd_a: string, opt: dict<any>)
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
        cmd = printf(':%s,%sSh %s %s', opt.line1, opt.line2, flag, cmd)
    else
        cmd = printf('Sh %s %s', flag, cmd)
    endif
    var job_d = json_decode(execute(cmd))

    # in case running with ":Cd... [path]"
    extend(job_d.opt, {cwd: getcwd()})

    var bufnr: number
    if opt.qf
        var current_max = getqflist({nr: '$'}).nr
        bufnr = current_max + 1
        setqflist([], ' ',
        {
                title: '(:Joblist to check state) ' .. cmd_short, nr: bufnr,
        })
        extend(job_d.opt, {
            out_cb: function(JobOutCb, [{bufnr: bufnr}]),
            err_cb: function(JobOutCb, [{bufnr: bufnr}]),
        })
    else
        ScratchNew
        bufnr = bufnr()
        wincmd p
        extend(job_d.opt, {
            out_io: 'buffer', err_io: 'buffer',
            out_buf: bufnr, err_buf: bufnr,
        })
    endif
    extend(job_d.opt, {
        exit_cb: function(JobExitCb, [{bufnr: bufnr, qf: opt.qf}]),
    })

    extend(job_dict, {
        [bufnr]: {
            job: job_start(job_d.cmd, job_d.opt),
            cmd: cmd_short,
        }
        })
enddef

def JobStop(id_a: string, sig: string)
    var id = empty(id_a) ? bufnr() : str2nr(matchstr(id_a, '\v^\d+'))
    if has_key(job_dict, id)
        job_stop(job_dict[id].job, sig)
    else
        throw 'job not found: buffer id ' .. id
    endif
enddef

def JobStopComp(...arg: list<any>): string
    var result = []
    for [k, v] in items(job_dict)
        if v.job->job_status() == 'run'
            add(result, printf('%s: %s', k, v.cmd))
        endif
    endfor
    return join(result, "\n")
enddef

def JobList()
    for [k, v] in items(job_dict)
        echo printf("%s:\t%s\t%s", k, v.job, v.cmd)
    endfor
enddef

def JobClear(num: number)
    for item in num > 0 ? [num] : keys(job_dict)
        var job = get(job_dict, item)
        if !empty(job)
            if job.job->job_info().status != 'run'
                remove(job_dict, item)
            endif
        endif
    endfor
enddef

# :ChdirTerminal [path]; default path: selection / <cfile>; expand() is applied; use existing terminal if possible; bang: using Sh -w (default: Sh -t) {{{1
# depends on g:Selection().
command! -bang -nargs=* -range=0 ChdirTerminal ChdirTerminal(<bang>false, <range>, <q-args>)

def ChdirTerminal(bang: bool, range: number, path_a: string)
    var path = path_a ?? ( range > 0 ? g:Selection() : expand('<cfile>') )
    if match(path, '\v^[~$<%]') >= 0
        path = g:ExpandHead(path)
    endif
    path = fnamemodify(path, ':p')
    if filereadable(path)
        path = fnamemodify(path, ':h')
    endif
    if !isdirectory(path)
        throw 'is not directory or not readable: ' .. path
    endif

    const bufs: list<number> = tabpagebuflist()
    if !bang
        for i in term_list()->filter(
            (_, x) => x->term_getstatus() == 'running'
            )
            const idx: number = index(bufs, i)
            if idx >= 0
                echo printf('chdir in window [%d]? [y/N] ', idx + 1)
                if nr2char(getchar())->tolower() == 'y'
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

# :vim-fuzzy config {{{1
# ProjectListCmd() {{{2
# NOTE: this variable is directly put after `find` command,
# using shell syntax. QUOTE IT IF NECESSARY!
g:project_dirs = get(g:, 'project_dirs', '~/repos/ ~/vimfiles/')

# accept list<string>; every item is put after -name (or -path, if / included)
g:project_blacklist = get(g:, 'project_blacklist', ['venv', 'node_modules'])

def ProjectListCmd(): string
    if empty(g:project_dirs)
        throw '`g:project_dirs` is not set or empty!'
    endif
    if type(g:project_blacklist) != type([])
        throw '`g:project_blacklist` should be list<string>!'
    endif

    var blacklist = ''
    for i in g:project_blacklist
        if match(i, is_win32 ? '\v[/\\]' : '/') >= 0
            blacklist ..= printf('-path %s -prune -o ', shellescape(i))
        else
            blacklist ..= printf('-name %s -prune -o ', shellescape(i))
        endif
    endfor
    # https://github.com/lxhillwind/utils/tree/main/find-repo
    var find_repo_bin = exepath('find-repo' .. (is_win32 ? '.exe' : ''))
    if !find_repo_bin->empty()
        return printf('%s %s', shellescape(find_repo_bin), g:project_dirs)
    endif
    return printf(
    "find %s %s -name .git -prune -print0 2>/dev/null"
    .. " | { if [ -x /usr/bin/cygpath ]; then xargs -r -0 cygpath -w; else xargs -r -0 -n 1; fi; }"
    .. " | sed -E 's#[\\/].git$##'",
    g:project_dirs, blacklist,
    )
enddef

# TabWinLines() {{{2
def TabWinLines(): list<string>
    var buf_list = []  # preserve order
    var key: string
    for i in range(tabpagenr('$'))
        var j = 0
        for buf in tabpagebuflist(i + 1)
            key = printf('%d %d', i + 1, j + 1)
            buf_list->add(key .. ' ' .. bufname(buf))
            j = j + 1
        endfor
    endfor
    return buf_list
enddef

# config {{{2
g:fuzzy#config->extend({
buffer: {
    excmd: 'ls',
    Callback: (chosen: string) => {
        const bufnr = chosen->matchstr('\v^\s*\zs(\d+)\ze')
        execute ':' .. bufnr .. 'b'
    }
    },
color: {
    LinesFn: () => globpath(&rtp, "colors/*.vim", 0, 1)
                ->mapnew((_, i) => i->split('[\/.]')->get(-2)),
    Callback: (chosen: string) => {
        execute 'color' fnameescape(chosen)
    }
    },
project_dir: {
    shell: ProjectListCmd(),
    ExtractInfoFn: (line) => ({filename: line->split('\t')[0]}),
    Callback: (chosen: string) => {
        execute 'lcd' fnameescape(chosen)
        if exists(':Dirvish') == 2
            execute 'Dirvish' fnameescape(chosen)
        endif
    }
    },
tabwin: {
    LinesFn: TabWinLines,
    Callback: (chosen: string) => {
        const res = chosen->trim()->split(' ')
        const [tab, win] = [res[0], res[1]]
        execute printf(':%stabn', tab)
        execute printf(':%swincmd w', win)
    }
    },
})

# (keymap) popup to select from sources. {{{2
nnoremap <Space>a <Cmd>call <SID>SelectFromSources()<CR>

def SelectFromSources()
    # TODO highlight
    const selection = [
        # [key, g:fuzzy#config]
        ['c', 'color'],
        ['e', 'project_dir'],
        ['b', 'buffer'],
        ['t', 'tabwin'],
        ]
    # some sources may be missing, so check it.
                ->filter((_, i) => !empty(g:fuzzy#config->get(i->get(1))))

    # Is is possible to use ordered dict, so we migrate selection /
    # selection_dict?
    var selection_dict = {}
    var lists = []
    for [k, v] in selection
        add(lists, printf('[%s] %s', k, v))
        selection_dict[k] = v
    endfor
    popup_create(lists, {
        pos: 'center',
        title: 'Select... (any other key to quit)',
        minwidth: min([40, &columns / 2]),
        border: [1, 1, 1, 1],
        mapping: false,
        filter: (winid: number, key: string): bool => {
            const res = get(selection_dict, key)
            if !empty(res)
                g:fuzzy#Main($'User.{res}')
            endif
            # finally.
            popup_close(winid)
            return true
        }
        }
    )
enddef

# sv() helper (in vim embedded terminal) {{{1
def g:Tapi_shell_sv_helper(...arg: list<any>)
    feedkeys("\<C-\>\<C-n>", 'n')
enddef

def g:NoteIdNew(): string # {{{1
    return strftime('%Y%m%d_%H%M%S')
enddef

# :PluginReadme {plugin}; open README file for specified plugin. {{{1
command! -nargs=1 -complete=custom,PluginReadmeComp PluginReadme
| PluginReadme(<q-args>)

def PluginReadme(plugin: string)
    for i in PluginReadmeCache()
        if i->match(plugin) >= 0
            exec 'edit' i->fnameescape()
            return
        endif
    endfor
    echoerr 'plugin README not found: ' .. plugin
enddef

def PluginReadmeComp(..._: list<any>): string
    return PluginReadmeCache()
                ->mapnew((_, i) => i->substitute('\v.*/\ze[^/]+/[^/]+$', '', ''))
                ->join("\n")
enddef

var plugin_readme_cache: list<string> = []
var plugin_readme_set: bool = false
def PluginReadmeCache(): list<string>
    if !plugin_readme_set
        plugin_readme_cache = globpath(&rtp, 'README*', 0, 1)
        plugin_readme_set = true
    endif
    return plugin_readme_cache
enddef
