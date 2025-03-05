vim9script

command! -nargs=+ -complete=shellcmd Pick PickAnyCli(<q-args>)

nnoremap <Space>ff <ScriptCmd>PickCwdFiles()<CR>
nnoremap <Space>fr <ScriptCmd>PickRecentFiles()<CR>
nnoremap <Space>fp <ScriptCmd>PickGotoProject()<CR>
nnoremap <Space>fc <ScriptCmd>PickUserCommand()<CR>
nnoremap <Space>fm <ScriptCmd>PickUserMapping()<CR>
nnoremap <Space>fa :Pick<Space>
nnoremap <Space>fl <ScriptCmd>PickLines()<CR>
nnoremap <Space>fb <ScriptCmd>PickBuffer()<CR>
nnoremap <Space>ft <ScriptCmd>PickGotoTabWin()<CR>

# common var {{{1
const is_win32 = has('win32')

def PickAnyCli(cli: string) # {{{1
    g:Pick(
        v:none,
        cli,
        v:none,
        (s) => {
            execute('e ' .. fnameescape(s))
        }
    )
enddef

# g:Pick() implementation using builtin fuzzy function. {{{1
var state: dict<any> = {}

const CHUNK_SIZE = 5'000

def g:Pick(Title: string = '', Cmd: string = '', Lines: list<string> = [], Callback: func(any) = v:none)
    if has_key(state, 'job_id')
        state->remove('job_id')
    endif
    state.callback = Callback
    state.lines_all = []  # list<string>
    state.lines_matched = []  # list<string>
    state.input = ''
    state.line_offset = 0
    state.current_line = 1
    state.move_cursor = ''
    const height = max([&lines / 2, 10])
    state.height = height
    state.title_base = printf(' %s ', empty(Title) ? Cmd : Title)
    state.winid = popup_create('', {
        title: state.title_base,
        pos: 'botleft',  # use bot instead of top, since latter hides tab info.
        minwidth: &columns,
        minheight: height,
        maxheight: height,
        line: &lines,  # use 1 if use top as pos.
        highlight: 'Normal',
        border: [1, 0, 0, 0],
        borderhighlight: ['Pmenu'],
        mapping: false,
        filter: PopupFilter,
        callback: (_, _) => {
            StateCleanup()
        },
    })
    const buf = winbufnr(state.winid)
    state.timer = timer_start(0, (_) => SourceRefresh())
    if empty(Cmd)
        state.lines_all = Lines
    else
        var cmd_opt = execute($'Sh -n {Cmd}')->json_decode()
        cmd_opt.opt.out_mode = 'nl'
        cmd_opt.opt.out_cb = (_, msg) => {
            if !empty(state)  # in case of StateCleanup() is called.
                state.lines_all->add(msg)
                # when timer callback is called, timer_info() will return [].
                if empty(timer_info(state.timer))
                    SourceRefresh()
                endif
            endif
        }
        state.job_id = job_start(cmd_opt.cmd, cmd_opt.opt)
    endif
    # match id: use it + 1000 as line number.
    matchadd('Function', '\%1l', 10, 1000 + 1, {window: state.winid})
enddef

def PopupFilter(winid: number, key: string): bool
    state.move_cursor = ''
    if key == "\<Esc>" || key == "\<C-c>"
        winid->popup_close()
        return true
    elseif key == "\<Cr>"
        # lines_shown is 0 based.
        const line = state.lines_shown[state.current_line - 1]
        const current_line = state.current_line
        const Fn = state.callback
        winid->popup_close()
        redraws  # required to make msg / exception display
        if current_line >= 2
            Fn(line)
        endif
        return true
    elseif key == "\<C-d>"
        if state.input == ''
            winid->popup_close()
        endif
        return true
    elseif key == "\<Backspace>" || key == "\<C-h>"
        state.input = state.input[ : -2]
    elseif key == "\<C-u>"
        state.input = ''
    elseif key == "\<C-w>"
        if state.input->match('\s') >= 0
            state.input = state.input->substitute('\v(\S+|)\s*$', '', '')
        else
            state.input = ''
        endif
    elseif key == "\<C-k>" || key == "\<C-p>"
        MoveCursor('up')
        return true
    elseif key == "\<C-j>" || key == "\<C-n>"
        MoveCursor('down')
        return true
    elseif key->matchstr('^.') == "\x80"
        # like <MouseUp> / <CursorHold> ...
        return true
    else
        state.input ..= key
    endif

    timer_stop(state.timer)
    state.line_offset = 0
    state.lines_matched = []
    SourceRefresh()

    return true
enddef

def GenHeader(): string
    return '> ' .. state.input .. '|'
enddef

def MoveCursor(pos: string)
    const current_line_old = state.current_line
    if pos == 'up'
        state.current_line -= 1
    elseif pos == 'down'
        state.current_line += 1
    endif

    if state.current_line < 2
        state.current_line = 2
    endif
    if state.current_line > state.lines_shown->len()
        state.current_line = state.lines_shown->len()
    endif

    if current_line_old != state.current_line
        if current_line_old >= 2
            matchdelete(1000 + current_line_old, state.winid)
        endif
        if state.current_line >= 2
            matchadd('PmenuSel', $'\%{state.current_line}l', 10, 1000 + state.current_line, {window: state.winid})
        endif
    endif
enddef

def StateCleanup()
    # do clean up in timer instead of popup callback, so timer / job can be
    # stopped cleanly.
    timer_stop(state.timer)
    if state->has_key('job_id')
        job_stop(state.job_id)
        sleep 100m
        if job_status(state.job_id) == 'run'
            job_stop(state.job_id, 'kill')
        endif
    endif
    state = {}
enddef

def UIRefresh()
    var lines: list<string> = []
    lines->add(GenHeader())
    # 2: height - line[0] - offset
    lines->extend(state.lines_matched[ : state.height - 2])
    state.lines_shown = lines
    # TODO omit middle if line too long.
    const text = lines->mapnew((_, i) => strdisplaywidth(i) <= &columns ? i : i->strpart(0, &columns))
    state.winid->popup_settext(text)
    state.winid->popup_setoptions({
        # when state.lines_matched (fuzzy) length is more than CHUNK_SIZE, the
        # number is not accurate (since it is cut off).
        title: state.title_base .. $'({state.lines_matched->len()}/{state.lines_all->len()}) '
    })
    # if current_line is out of range, move it to the last line.
    MoveCursor('')
enddef

def SourceRefresh()
    if state.input->empty()
        state.lines_matched = state.lines_all
    else
        const matched = matchfuzzy(state.lines_all[state.line_offset : state.line_offset + CHUNK_SIZE], state.input)
        # TODO limit lines to test.
        state.lines_matched = matchfuzzy(matched + state.lines_matched, state.input)
        # omit contents with too low score.
        state.lines_matched = state.lines_matched[ : CHUNK_SIZE]
        state.line_offset += CHUNK_SIZE
    endif
    UIRefresh()
    if state.line_offset <= state.lines_all->len()
        state.timer = timer_start(100, (_) => SourceRefresh())
    endif
enddef

# various pick function {{{1
def PickGotoProject() # {{{2
    g:Pick(
        'Project',
        ProjectListCmd(),
        v:none,
        (chosen) => {
            execute 'lcd' fnameescape(chosen)
            if exists(':Lf') == 2
                # use ":silent" to avoid prompt when using PickFallback.
                silent execute 'Lf .'
            endif
        }
    )
enddef

# NOTE: this variable is directly put after `find` command,
# using shell syntax. QUOTE IT IF NECESSARY!
const project_dirs = '~/repos/ ~/vimfiles/'

# every item is put after -name (or -path, if / included)
const project_blacklist = ['venv', 'node_modules']

def ProjectListCmd(): string
    var blacklist = ''
    for i in project_blacklist
        if match(i, is_win32 ? '\v[/\\]' : '/') >= 0
            blacklist ..= printf('-path %s -prune -o ', shellescape(i))
        else
            blacklist ..= printf('-name %s -prune -o ', shellescape(i))
        endif
    endfor
    # https://github.com/lxhillwind/utils/tree/main/find-repo
    var find_repo_bin = exepath('find-repo' .. (is_win32 ? '.exe' : ''))
    if !find_repo_bin->empty()
        return printf('%s %s', shellescape(find_repo_bin), project_dirs)
    endif
    return (
        $'find {project_dirs} {blacklist} -name .git -prune -print0 2>/dev/null'
        .. ' | { if [ -x /usr/bin/cygpath ]; then xargs -r -0 cygpath -w; else xargs -r -0 -n 1; fi; }'
        .. " | sed -E 's#[\\/].git$##'"
    )
enddef

def PickGotoTabWin() # {{{2
    g:Pick(
        'TabWin',
        v:none,
        TabWinLines(),
        (chosen) => {
            const res = chosen->trim()->split(' ')
            const [tab, win] = [res[0], res[1]]
            execute $':{tab}tabn'
            execute $':{win}wincmd w'
        }
    )
enddef

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

def PickLines() # {{{2
    g:Pick(
        'LinesInCurrentBuffer',
        v:none,
        getline(1, '$')->mapnew((idx, i) => $'{idx + 1}: {i}'),
        (chosen) => {
            execute 'normal ' .. chosen->matchstr('\v^[0-9]+') .. 'G'
        }
    )
enddef

def PickBuffer() # {{{2
    g:Pick(
        'Buffer (:ls)',
        v:none,
        execute('ls')->split("\n"),
        (chosen) => {
            const buf = chosen->split(' ')->get(0, '')
            if buf->match('^\d\+$') >= 0
                execute $':{buf}b'
            endif
        }
    )
enddef
def PickRecentFiles() # {{{2
    const filesInCurrentTab = tabpagebuflist()
        ->mapnew((_, i) => i->getbufinfo())
        ->flattennew(1)->map((_, i) => i.name)
    const blacklistName = ["COMMIT_EDITMSG", "ADD_EDIT.patch", "addp-hunk-edit.diff", "git-rebase-todo"]
    g:Pick(
        'RecentFiles',
        v:none,
        v:oldfiles
        ->mapnew((_, i) => i)
        ->filter((_, i) => {
            const absName = i->g:ExpandHead()
            if is_win32 && absName->match('^//') >= 0
                # skip unc path, since if the file is not readable, filereadable() will hang.
                #
                # we have "set shellslash", so only check // here.
                return false
            endif
            return absName->filereadable() && filesInCurrentTab->index(absName) < 0
                && blacklistName->index(fnamemodify(absName, ':t')) < 0
        }),
        (s) => {
            execute 'e' fnameescape(s)
        }
    )
enddef

def PickCwdFiles() # {{{2
    g:Pick(
        'CurrentDirFiles',
        executable('bfs') ? "bfs '!' -type d" : "find '!' -type d",
        v:none,
        (s) => {
            execute 'e' fnameescape(s)
        }
    )
enddef

def PickUserMapping() # {{{2
    if v:lang !~ '\v^(en|C$)'
        # change lang to C, so command 'verb map' outputs like
        # "Last set from", instead of using non-English message.
        defer execute($'language messages {v:lang}')
        language messages C
    endif
    const data = execute('verb map | verb map! | verb tmap')->split("\n")
    var keys: list<string>
    var values: list<string>
    {
        var prev: string
        for i in data
            if i->match('\s*Last set from') >= 0
                keys->add(prev)
                values->add(i)
            else
                prev = i
            endif
        endfor
    }
    g:Pick(
        'UserMapping',
        v:none,
        keys,
        (s) => {
            const idx = keys->index(s)
            if idx >= 0
                const line_info = values[idx]
                    ->matchlist('\vLast set from (.*) line (\d+)$')
                if !empty(line_info)
                    const [file, line] = line_info[1 : 2]
                    if bufname() != file
                        execute 'edit' fnameescape(file)
                    endif
                    execute $'normal {line}G'
                endif
            endif
        }
    )
enddef

def PickUserCommand() # {{{2
    if v:lang !~ '\v^(en|C$)'
        # ... see above (PickUserMapping)
        defer execute($'language messages {v:lang}')
        language messages C
    endif
    const data = execute('verb command')->split("\n")
    var keys: list<string>
    var values: list<string>
    {
        var prev: string
        for i in data
            if i->match('\s*Last set from') >= 0
                keys->add(prev)
                values->add(i)
            else
                prev = i
            endif
        endfor
    }
    g:Pick(
        'UserCommand',
        v:none,
        keys,
        (s) => {
            const idx = keys->index(s)
            if idx >= 0
                const line_info = values[idx]
                    ->matchlist('\vLast set from (.*) line (\d+)$')
                if !empty(line_info)
                    const [file, line] = line_info[1 : 2]
                    if bufname() != file
                        execute 'edit' fnameescape(file)
                    endif
                    execute $'normal {line}G'
                endif
            endif
        }
    )
enddef

# finish {{{1
defc
