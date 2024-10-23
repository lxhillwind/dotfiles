vim9script

# set `g:fuzzy_force_builtin = true` to always use builtin fuzzy finder.

command! -nargs=+ -complete=shellcmd Pick PickAnyCli(<q-args>)

nnoremap <Space>ff <ScriptCmd>PickCwdFiles()<CR>
nnoremap <Space>fr <ScriptCmd>PickRecentFiles()<CR>
nnoremap <Space>fp <ScriptCmd>PickGotoProject()<CR>
nnoremap <Space>fc <ScriptCmd>PickUserCommand()<CR>
nnoremap <Space>fm <ScriptCmd>PickUserMapping()<CR>
nnoremap <Space>fa :Pick<Space>
nnoremap <Space>fb <ScriptCmd>PickJumpCurrentBuffer()<CR>
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

# PickFallback {{{1
var state: dict<any> = {}
def PickFallback(Title: string = '', Cmd: string = '', Lines: list<string> = [], Callback: func(any) = v:none)
    if has_key(state, 'job_id')
        state->remove('job_id')
    endif
    state.callback = Callback
    state.lines = []  # list<string>
    state.need_refresh = false
    state.input = ''
    state.current_line = 1
    state.move_cursor = ''
    const height = max([&lines / 2, 10])
    state.height = height
    const winid = popup_create('', {
        title: empty(Title) ? Cmd : Title,
        pos: 'botleft',  # use bot instead of top, since latter hides tab info.
        minwidth: &columns,
        minheight: height,
        maxheight: height,
        line: &lines,  # use 1 if use top as pos.
        mapping: false,
        filter: PickFilter,
        callback: PickCallback,
    })
    state.winid = winid
    state.timer = timer_start(1000, (_) => Refresh(), {repeat: -1})
    const buf = winbufnr(winid)
    if empty(Cmd)
        state.lines = Lines
        state.need_refresh = true
    else
        var cmd_opt = execute($'Sh -n {Cmd}')->json_decode()
        cmd_opt.opt.out_mode = 'nl'
        cmd_opt.opt.out_cb = (_, msg) => {
            state.lines->add(msg)
            state.need_refresh = true
        }
        state.job_id = job_start(cmd_opt.cmd, cmd_opt.opt)
    endif
    Refresh()
    # match id: use it + 1000 as line number.
    matchadd('Function', '\%1l', 10, 1000 + 1, {window: state.winid})
enddef

def PickFilter(winid: number, key: string): bool
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
    elseif key == "\<Backspace>" || key == "\<C-h>"
        state.input = state.input[ : -2]
    elseif key == "\<C-u>"
        state.input = ''
    elseif key == "\<C-w>"
        if state.input->match('\s') >= 0
            state.input = state.input->substitute('\v\S+\s?$', '', '')
        else
            state.input = ''
        endif
    elseif key == "\<C-k>" || key == "\<C-p>"
        state.move_cursor = 'up'
    elseif key == "\<C-j>" || key == "\<C-n>"
        state.move_cursor = 'down'
    else
        state.input ..= key
    endif
    state.need_refresh = true
    Refresh()
    return true
enddef

def PickCallback(id: number, _: any)
    if state->has_key('job_id')
        job_stop(state.job_id)
    endif
    timer_stop(state.timer)
    state = {}
enddef

def Refresh()
    if !state.need_refresh
        return
    endif
    state.need_refresh = false
    var lines: list<string> = []
    lines->add('> ' .. state.input .. '|')
    if state.input->empty()
        lines->extend(state.lines[ : state.height])
    else
        lines->extend(matchfuzzy(state.lines, state.input))
    endif
    state.winid->popup_settext(lines)
    state.lines_shown = lines
    const current_line_old = state.current_line
    if state.move_cursor == 'up'
        state.current_line -= 1
    elseif state.move_cursor == 'down'
        state.current_line += 1
    endif

    if state.current_line < 2
        state.current_line = 2
    endif
    if state.current_line > lines->len()
        state.current_line = lines->len()
    endif

    if current_line_old != state.current_line
        if current_line_old >= 2
            matchdelete(1000 + current_line_old, state.winid)
        endif
        if state.current_line >= 2
            matchadd('Visual', $'\%{state.current_line}l', 10, 1000 + state.current_line, {window: state.winid})
        endif
    endif
enddef

def g:Pick(Title: string = '', Cmd: string = '', Lines: list<string> = [], Callback: func(any) = v:none)  # {{{1
    if (exists('g:fuzzy_force_builtin') && g:fuzzy_force_builtin) || !executable('fzf')
        PickFallback(Title, Cmd, Lines, Callback)
        return
    endif
    const fzf = (
        is_win32 && windowsversion()->str2float() <= 5.1
        ? 'fzf --color=16 --sort --cycle --reverse --inline-info'  # old fzf does not support --info.
        : 'fzf --color=16 --sort --cycle --reverse --info=inline'
    )
    var shcmd = ''
    const file_result = tempname()
    if empty(Cmd)  # Lines may be empty but provided; so checking Cmd is better.
        const file_input = tempname()
        Lines->writefile(file_input)
        shcmd = printf('%s < %s > %s', fzf, shellescape(file_input), shellescape(file_result))
    else
        shcmd = printf('{ %s 2>/dev/null; } | %s > %s', Cmd, fzf, shellescape(file_result))
    endif
    # use :Sh instead of :term, since latter does not work in win32:
    # e.g. `:term ++shell ls -l` will be trimmed as `ls`.
    var cmd_opt = execute($'Sh -n {shcmd}')->json_decode()
    cmd_opt.opt->extend({term_finish: 'close', hidden: true})
    const term_buf = term_start(cmd_opt.cmd, cmd_opt.opt)
    const height = max([&lines / 2, 10])
    const winid = popup_create(term_buf, {
        title: empty(Title) ? Cmd : Title,
        pos: 'botleft',  # use bot instead of top, since latter hides tab info.
        minwidth: &columns,
        minheight: height,
        maxheight: height,
        line: &lines,  # use 1 if use top as pos.
    })
    if is_win32
        # in win32, double <Esc> exits fzf; let's make it behave same as other OS.
        tnoremap <buffer> <Esc> <C-c>
    endif
    term_getjob(term_buf)
        ->job_setoptions({ exit_cb: (_, _) => {
            popup_close(winid)
            const res: string = file_result->readfile()->get(0, '')
            if !empty(res)
                redraws  # this is required to make Exception shown; {{{
                # like editing files already opened in another instance. }}}
                if is_win32
                    # Why use timer here? {{{
                    # Reproduce:
                    # pick a file which is already opened in another vim
                    # session;
                    # then vim will show that swap file already exists.
                    # When not using timer, vim will just hang, since it
                    # cannot accept any input from user (I guess that it is
                    # the terminal buffer catching keys we input).
                    #
                    # 100ms is used; a lower value (like 50ms) may not be
                    # enough, like in conemu.
                    # }}}
                    timer_start(100, (_) => Callback(res))
                else
                    Callback(res)
                endif
            endif
        }})
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
                execute 'Lf .'
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

def PickJumpCurrentBuffer() # {{{2
    g:Pick(
        'CurrentBuffer',
        v:none,
        getline(1, '$')->mapnew((idx, i) => $'{idx + 1}: {i}'),
        (chosen) => {
            execute 'normal ' .. chosen->matchstr('\v^[0-9]+') .. 'G'
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
