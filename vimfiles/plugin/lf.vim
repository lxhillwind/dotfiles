vim9script

# emulate lf's basic movement function;
# mainly used for directory traveling when lf executable is not available.
#
# # this shell function is extracted from my zshrc;
# # named l() (instead of lf()) to avoid conflict with lf executable.
# l()
# {
#     local x
#     if ! command -v lf >/dev/null; then
#         # use my "lf" vim-plugin.
#         local LF_TARGET="$(mktemp)"
#         if [ $? -ne 0 ]; then
#             return 1
#         fi
#         LF_SELECT="$1" LF_TARGET="$LF_TARGET" vim +Lf
#         x="$(cat -- "$LF_TARGET")"
#     else
#         x=$(command lf -print-last-dir "$@"; printf x)
#         # ? => lf always outputs "\n" at end; x => final char we add via printf.
#         x="${x%?x}"
#     fi
#     if [ "$x" != "$PWD" ]; then
#         cd "$x"
#     fi
# }

def SetupUI()
    set buftype=nofile
    const buf = bufnr()
    prop_type_add(prop_dir, {bufnr: buf, highlight: 'Function'})
    prop_type_add(prop_not_dir, {bufnr: buf, highlight: 'Normal'})

    nnoremap q <ScriptCmd>Quit()<CR>
    nnoremap h <ScriptCmd>Up()<CR>
    nnoremap l <ScriptCmd>Down()<CR>
    nnoremap f <ScriptCmd>Find('f')<CR>
    nnoremap F <ScriptCmd>Find('F')<CR>
    nnoremap ; <ScriptCmd>Find(';')<CR>
    nnoremap , <ScriptCmd>Find(',')<CR>
enddef

def Quit()
    # cwd always ends with /;
    # so it is safe to use it from shell like this:
    # cd "$(cat "$LF_TARGET")"
    if has('win32')
        # convert file encoding, so shell can use the content.
        const encoding = 'cp' .. libcallnr('kernel32.dll', 'GetACP', 0)
        cwd = cwd->iconv('utf-8', encoding)
    endif
    # use split("\n") (then join implicitly via writefile()),
    # since cwd may contain "\n".
    cwd->split("\n")->writefile($LF_TARGET)
    quit
enddef

def Up()
    # '/': unix; '[drive CDE...]:/': win32
    if cwd->count('/') <= 1
        echohl Normal | echo $'Already at root.' | echohl None
        return
    endif
    const old_cwd = cwd
    cwd = cwd->substitute('[^/]\+/$', '', '')
    if !RefreshDir()
        cwd = old_cwd
    else
        # move cursor to the dir entry where we go from.
        const target_name = old_cwd->substitute('/$', '', '')
            ->substitute('\v.*/', '', '')
            .. '/'
        for i in range(line('$'))
            const line_no = i + 1
            if getline(line_no) == target_name
                execute $':{line_no}'
                break
            endif
        endfor
    endif
enddef

def Down()
    const entry = entries[line('.') - 1]
    if !entry.type->TypeIsDir()
        return
    endif
    const old_cwd = cwd
    cwd = cwd .. entry.name .. '/'
    if !RefreshDir()
        cwd = old_cwd
    endif
enddef

var find_char: string = ''
def Find(key: string)
    if key == 'f' || key == 'F'
        find_char = getcharstr()
        if find_char == ''
            find_char = ''
            return
        endif
    endif
    if find_char->empty()
        return
    endif
    const search = '\V\^' .. escape(find_char, '\/')
    const order = (key == 'f' || key == ';') ? '/' : '?'
    # ':' is required in vim9.
    # 'silent!' to avoid not-found pattern causing break.
    silent! execute 'keeppattern' ':' .. order .. search
enddef

def TypeIsDir(ty: string): bool
    const types_dir = ['linkd', 'dir']
    return types_dir->index(ty) >= 0
enddef

def RefreshDir(): bool
    if !isdirectory(cwd)
        echohl ErrorMsg | echo $'not directory: "{cwd}"' | echohl None
        return false
    endif
    entries = readdirex(cwd)
    normal! gg"_dG
    entries->sort((a, b) => {
        const type_a = TypeIsDir(a.type) ? 1 : 0
        const type_b = TypeIsDir(b.type) ? 1 : 0
        if xor(type_a, type_b) > 0
            return type_a > type_b ? -1 : 1
        endif

        return a.name < b.name ? -1 : 1
    })
    const buf = bufnr()
    for i in range(len(entries))
        const entry = entries[i]
        const is_dir = TypeIsDir(entry.type)
        append(i, entry.name .. (is_dir ? '/' : ''))
        prop_add(i + 1, 1, {length: len(entry.name) + 1, type: is_dir ? prop_dir : prop_not_dir,  bufnr: buf})
    endfor
    normal! "_ddgg

    silent execute 'lcd' fnameescape(cwd)
    # when cwd is long, "Press ENTER..." msg will show.
    #echo cwd
    return true
enddef

# assume that cwd is always end with '/'.
var cwd = ($LF_SELECT ?? '.')->fnamemodify(':p')
if cwd[-1] != '/'
    # $LF_SELECT is provided and is not a directory.
    cwd = cwd->substitute('\v[^/]+$', '', '')
endif

var entries: list<any> = []
const prop_dir = 'dir'
const prop_not_dir = 'not_dir'

def Main()
    if $LF_TARGET->empty()
        echohl ErrorMsg | echo 'lf.vim: $LF_TARGET is not set! plugin stopped.' | echohl None
        return
    endif
    if has('win32')
        # always use '/' as path sep.
        set shellslash
    endif
    SetupUI()
    RefreshDir()
enddef

command Lf Main()
