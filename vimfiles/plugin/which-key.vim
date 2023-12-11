vim9script

nnoremap <Space><Space> <ScriptCmd>WhichKey()<CR>

# Why do we use popupwin (textprop) instead of just echo (echohl)?
#
# Because if using echo, when there are many lines (choices), it is easy to
# trigger a 'more-prompt'.
#
# (after refactoring to popupwin, I found that this behavior can be skipped by
# setting 'more' option.
# Anyway, keep this change. And it's easier to do more customize, like
# highlight with "Search")

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
    const winid = popup_create([], {
        title: ' Which Key ',
        pos: 'botleft',
        line: &lines,
        border: [1, 1, 1, 1],
        minwidth: &columns - 2, # 2: border
        mapping: false,
        filter: (winid, key) => {
            prefix ..= key
            const matched = GetMatched(mappings, prefix)
            if matched->len() == 1
                winid->popup_close()
                feedkeys("\<Space>" .. prefix, 'm')
            elseif matched->len() == 0
                winid->popup_close()
                redrawstatus | echon 'cancelled.'
            else
                winid->popup_settext(
                    mappings->GetMatched(prefix)->ToProps(prefix)
                )
            endif
            return 1
        }
        }
    )
    const bufnr = winbufnr(winid)
    prop_type_add('String', {bufnr: bufnr, highlight: 'String'})
    prop_type_add('Search', {bufnr: bufnr, highlight: 'Search'})
    prop_type_add('Comment', {bufnr: bufnr, highlight: 'Comment'})
    prop_type_add('Function', {bufnr: bufnr, highlight: 'Function'})
    winid->popup_settext(mappings->GetMatched(prefix)->ToProps(prefix))
enddef

def ToProps(mappings: list<dict<any>>, prefix: string): list<dict<any>>
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
    var result = []
    for ch in group->keys()->sort()
        var props = []
        if prefix != ''
            props->add({type: 'Comment', col: 1, length: len(prefix)})
        endif
        if group[ch]->len() == 1
            const i = group[ch][0]
            const text = $'{i.lhs} ' .. (i.rhs
                ->substitute('\v^\*\s+', '', '')
                ->substitute('\v^\<ScriptCmd\>(.*)\<CR\>$', '\1', '')
            )
            props->add({type: 'String', col: len(prefix) + 1, length: len(i.lhs) - len(prefix)})
            var idx = len(i.lhs)
            while true
                var idx_new = stridx(text, ch, idx)
                if idx_new < 0
                    if ch->match('[a-z]') >= 0
                        idx_new = stridx(text, ch->toupper(), idx)
                    elseif ch->match('[A-Z]') >= 0
                        idx_new = stridx(text, ch->tolower(), idx)
                    endif
                    if idx_new < 0
                        break
                    else
                        idx = idx_new
                        props->add({type: 'Search', text: $'({ch})', col: idx + 1})
                    endif
                else
                    idx = idx_new
                    props->add({type: 'Search', col: idx + 1, length: 1})
                endif
                idx += 1
            endwhile
            result->add({
                text: text,
                props: props,
            })
        else
            const text = $'{prefix}{ch}...'
            props->add({type: 'String', col: len(prefix) + 1, length: 1})
            # 3: '...'->len()
            props->add({type: 'Function', col: len(text) + 1 - 3, length: 3})
            result->add({
                text: text,
                props: props,
            })
        endif
    endfor
    return result
enddef

def GetMatched(mappings: list<dict<any>>, prefix: string): list<dict<any>>
    var result = []
    for i in mappings
        if i.lhs->match($'^{prefix}') >= 0
            result->add(i)
        endif
    endfor
    return result
enddef
