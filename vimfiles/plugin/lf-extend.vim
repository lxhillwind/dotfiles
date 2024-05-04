vim9script

# src:
#   if in lf buffer (b:lf var exists), then use b:lf.cwd as src dir;
#   else, use getcwd().
#   use getline(line1, line2) as filename entries.
#
# dest:
#   if provided a number, then use buffer with that id as dest dir;
#   (like src, check if target dir is lf buffer).
#   if the number does not map to a buffer, then give a error
#   (prompt using ./that-number).
#   if no arg provided, then check if exactly ONE another lf buffer exists,
#   and use that buffer's cwd as dest. (like dual pane fm)
#
#  if target file existed, then prompt using bang to override;
#  all operations are with prompt messages;
#  use popup / timer for async file operation (move / copy / delete files).

command -range -nargs=* LfMoveTo LfMoveTo(<line1>, <line2>, <q-args>)
command -range -nargs=* LfCopyTo LfCopyTo(<line1>, <line2>, <q-args>)
command -range LfDelete LfDelete(<line1>, <line2>)

def LfMoveTo(line1: number, line2: number, dest: string)
    const dst_dir = GetDestDir(dest)
    # ensure dst dir ends with slash.
    if dst_dir !~ '/$'
        return
    endif
    const src_entries = GetSrcEntries(line1, line2)
    if !src_entries
        return
    endif

    echohl String | echo 'Files to operate on:' | echohl None
    EchoEntries(src_entries)
    echohl String | echo 'Will be moved to: ' | echohl None
    echohl Directory | echon dst_dir | echohl None

    echo 'Move? [y/N]'
    if getcharstr()->tolower() != 'y'
        redrawstatus | echo
        return
    endif

    var failed_items = []
    for i in src_entries
        if rename(i.dir .. i.name, dst_dir .. i.name) != 0
            failed_items->add(i)
        endif
    endfor
    if !!failed_items
        echohl ErrorMsg | echo 'failed to move:' | echohl None
        EchoEntries(failed_items)
    endif
enddef

def LfCopyTo(line1: number, line2: number, dest: string)
    const dst_dir = GetDestDir(dest)
    # ensure dst dir ends with slash.
    if dst_dir !~ '/$'
        return
    endif
    const src_entries = GetSrcEntries(line1, line2)
    if !src_entries
        return
    endif

    echohl String | echo 'Files to operate on:' | echohl None
    EchoEntries(src_entries)
    echohl String | echo 'Will be copied to: ' | echohl None
    echohl Directory | echon dst_dir | echohl None

    echo 'Copy? [y/N]'
    if getcharstr()->tolower() != 'y'
        redrawstatus | echo
        return
    endif

    throw 'COPY operation not implemented yet!'
enddef

def LfDelete(line1: number, line2: number)
    const src_entries = GetSrcEntries(line1, line2)
    if !src_entries
        return
    endif

    echohl String | echo 'Files to operate on:' | echohl None
    EchoEntries(src_entries)
    echohl WarningMsg | echo 'Will be deleted.' | echohl None

    echo 'Delete? [y/N]'
    if getcharstr()->tolower() != 'y'
        redrawstatus | echo
        return
    endif

    var failed_items = []
    for i in src_entries
        if delete(i.dir .. i.name, 'rf') != 0
            failed_items->add(i)
        endif
    endfor
    if !!failed_items
        echohl ErrorMsg | echo 'failed to delete:' | echohl None
        EchoEntries(failed_items)
    endif
enddef

def GetSrcEntries(line1: number, line2: number): list<dict<string>>
    const dir = b:->get('lf', {})->get('cwd', '') ?? getcwd()->fnamemodify(':p')->NormPath()
    var result = []
    for i in getline(line1, line2)
        if !i->empty()
            result->add({dir: dir, name: i})
        endif
    endfor
    return result
enddef

def NormPath(s: string): string
    var res = s
    if has('win32')
        res = res->substitute('\', '/', 'g')
    endif
    res = res .. '/'
    res = res->substitute('//$', '/', '')
    return res
enddef

def GetDestDir(dest: string): string
    var result: string = ''
    if dest == ''
        var lf_buffers: list<number> = []
        const buf_id = bufnr()
        for i in tabpagebuflist()
            if buf_id != i && !!getbufvar(i, 'lf', {})->get('cwd', '')
                lf_buffers->add(i)
            endif
        endfor
        if lf_buffers->len() != 1
            echohl ErrorMsg | echo $'lf-extend: target not specified, and cannot infer target lf buffer!' | echohl None
            return ''
        endif
        return getbufvar(lf_buffers[0], 'lf').cwd
    elseif dest =~ '\v^[0-9]+$'
        const buf_id = dest->str2nr()
        const lf_buffer = bufnr(buf_id)
        if lf_buffer < 0
            echohl ErrorMsg | echo $'lf-extend: buffer not found: {dest}' | echohl None
            return ''
        endif
        result = getbufvar(buf_id, 'lf', {})->get('cwd', '')
        if !result
            echohl ErrorMsg | echo $'lf-extend: is not lf buffer: {dest}' | echohl None
            return ''
        endif

        return result->NormPath()
    endif

    result = dest->simplify()->fnamemodify(':p')
    if !isdirectory(result)
        echohl ErrorMsg | echo $'lf-extend: is not directory: {dest}' | echohl None
        return ''
    endif

    return result->NormPath()
enddef

def EchoEntries(entries: list<dict<string>>)
    for i in entries
        echohl Directory | echo '  ' i.dir | echohl None
        echon i.name
    endfor
enddef
