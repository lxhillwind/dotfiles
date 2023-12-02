vim9script

nnoremap <Space><Space> <ScriptCmd>WhichKey()<CR>

def WhichKey()
    var mappings = execute('nmap <Space>')->split("\n")
        # remove mapping to <Nop>
        ->filter((_, i) => i->match('^n') >= 0)
        # example:
        #   n  <Space>y    * <ScriptCmd>ClipboardCopy("")<CR>
        #   n  <Space>y    *@<ScriptCmd>ClipboardCopy("")<CR>
        #      1             2
        # (*@ means buffer mapping)
        ->mapnew((_, i) => i->matchlist('\vn\s+(\S+)\s+(\*\@|)\s*(.+)')->slice(1, 4))
        ->mapnew((_, i) => ({
            lhs: i[0]->substitute('^\V<Space>', '', ''),
            rhs: i[2],
            buffer: i[1]->match('@') >= 0,
        }))
        # remove special mapping, like <Space> / <CR> / <C-.>.
        ->filter((_, i) => i.lhs->match('<') < 0)
    const all_locals = mappings->copy()->filter((_, i) => i.buffer)->mapnew((_, i) => i.lhs)
    mappings->filter((_, i) => !(index(all_locals, i.lhs) >= 0 && !i.buffer))

    var prefix = ''
    while true
        const matched = GetMatched(mappings, prefix)
        if matched->len() == 1
            feedkeys("\<Space>" .. prefix, 'm')
            return
        elseif matched->len() == 0
            echon 'cancelled.'
            break
        endif
        EchoMatched(mappings, prefix)
        prefix ..= getcharstr()
        echo | redrawstatus  # this is required to make feedkeys() work...
    endwhile
enddef

def EchoMatched(mappings: list<dict<any>>, prefix: string)
    redrawstatus
    var group = {}
    for i in mappings
        if i.lhs->match($'^{prefix}') < 0
            continue
        endif
        const next_ch = i.lhs[prefix->len()]
        if !group->has_key(next_ch)
            group[next_ch] = []
        endif
        group[next_ch]->add(i)
    endfor
    for ch in group->keys()->sort()
        echo ''
        echohl Comment
        echon prefix
        echohl String
        if group[ch]->len() == 1
            const i = group[ch][0]
            echon i.lhs[prefix->len() : ]
            echohl None
            echon $' {i.rhs}'
        else
            echon ch
            echohl Function
            echon '...'
            echohl None
        endif
    endfor
enddef

def GetMatched(mappings: list<dict<any>>, prefix: string): list<string>
    var result = []
    for i in mappings
        if i.lhs->match($'^{prefix}') >= 0
            result->add(i.rhs)
        endif
    endfor
    return result
enddef
