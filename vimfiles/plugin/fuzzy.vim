vim9script

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

def g:Pick(Title: string = '', Cmd: string = '', Lines: list<string> = [], Callback: func(any) = v:none)  # {{{1
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
                Callback(res)
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
                execute 'Lf' fnameescape(chosen)
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
