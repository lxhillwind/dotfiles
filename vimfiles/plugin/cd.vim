vim9script

# Cd <path> / :Cdalternate / :Cdhome / :Cdbuffer / :Cdproject [:]cmd...
command! -nargs=1 -complete=dir Cd Cd('', <q-args>)
command! -nargs=* -complete=command Cdalternate Cd('alternate', <q-args>)
command! -nargs=* -complete=command Cdhome Cd('home', <q-args>)
command! -nargs=* -complete=command Cdbuffer Cd('buffer', <q-args>)
command! -nargs=* -complete=command Cdproject Cd('project', <q-args>)

nnoremap <Space>c <ScriptCmd>GotoWhichDir()<CR>

# utility (copied from ~/vimfiles/vimrc) {{{
const is_win32 = has('win32')
# }}}

def GotoWhichDir()  # {{{1
    const dir_buffer: string = Get_buf_dir()
    var dir_project: string
    try
        dir_project = Get_project_dir()
    catch
    endtry
    const dir_home: string = expand('~')
    const dir_cwd: string = getcwd()

    # echo {{{
    if dir_cwd == dir_home
        echon '*'
    endif
    echohl Directory
    echon '[a] home' | echohl None | echon ' '

    if dir_cwd == dir_project
        echon '*'
    endif
    if empty(dir_project)
        echohl WarningMsg
    else
        echohl Directory
    endif
    echon '[d] project' | echohl None | echon ' '

    if dir_cwd == dir_buffer
        echon '*'
    endif
    echohl Directory
    echon '[f] buffer' | echohl None | echon ' '
    # }}}

    echon dir_cwd .. ' > '
    const ch = getcharstr()
    # avoid press enter to continue msg.
    echo "\n" | redrawstatus

    if ch == ' '
        # use <Space> key as escape (like vim-sneak).
    elseif ch == 'a'
        Cdhome
    elseif ch == 'd'
        if !empty(dir_project)
            Cdproject
        else
            echohl Error
            echon 'project dir not available!'
            echohl None
        endif
    elseif ch == 'f'
        Cdbuffer
    else
        # sneak like behavior.
        feedkeys(ch, 't')
    endif
enddef
# }}}
def Cd(flag: string, args: string)  # {{{1
    var cmd = args
    var path: string
    if flag == 'alternate'
        path = fnamemodify(bufname('#'), '%:p:h')
    elseif flag == 'home'
        path = expand('~')
    elseif flag == 'project'
        path = Get_project_dir()
        if empty(path)
            throw 'project dir not found!'
        endif
    elseif flag == 'buffer'
        path = Get_buf_dir()
    else
        if args =~ '^:'
            throw 'path argument is required!'
        endif
        # Cd: split argument as path & cmd
        path = substitute(args, '\v^(.{}) :.+$', '\1', '')
        cmd = args[len(path) + 1 :]
    endif

    if !empty(cmd)
        var old_cwd = getcwd()
        var buf = bufnr('')
        try
            # use buffer variable to store cwd if `exe` switch to new window
            b:vimrc_old_cwd = old_cwd
            silent exe 'lcd' fnameescape(path)
            exe cmd
        finally
            if buf == bufnr('')
                if exists('b:vimrc_old_cwd')
                    unlet b:vimrc_old_cwd
                endif
                silent exe 'lcd' fnameescape(old_cwd)
            endif
        endtry
    else
        exe 'lcd' fnameescape(path)
        if &buftype == 'terminal'
            term_sendkeys(bufnr(''), 'cd ' .. shellescape(path))
            if mode() == 'n'
                feedkeys('i', 't')
            endif
        endif
    endif
enddef

augroup vimrc  # {{{1
    au BufEnter * {
        # reset cd
        if exists('b:vimrc_old_cwd')
            try
                silent exe 'lcd' fnameescape(b:vimrc_old_cwd)
            finally
                unlet b:vimrc_old_cwd
            endtry
        endif
    }
augroup END

# func {{{1
def Get_buf_dir(): string
    var path = expand('%:p:h')
    path = path->substitute('\v^(file://)', '', '')
    if empty(path) || &buftype == 'terminal'
        path = getcwd()
    endif
    return path
enddef

def Get_project_dir(): string
    var path = Get_buf_dir()
    var parent: string
    while 1
        if is_win32 && !isdirectory(path)
            # UNC; isdirectory('//XXX/.git') is extremely slow, so return
            # early if already in dir root.
            return ''
        endif
        if isdirectory(path .. '/.git')
            return path
        endif
        if filereadable(path .. '/.git')
            # git submodule
            return path
        endif
        parent = fnamemodify(path, ':h')
        if path == parent
            return ''
        endif
        path = parent
    endwhile
    # unrechable
    return path
enddef

defc
