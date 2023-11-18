vim9script

# emulate kitty's hint mode.

command! HintsMode HintsMode()

def HintsMode()
    setlocal buftype=nofile
    setlocal nonumber norelativenumber nofoldenable nocursorcolumn nocursorline
    setlocal nohlsearch
    redraw
    echon 'hint: [l]ine [u]rl <<< [q]uit '
    const ch = getcharstr()
    # avoid press enter to continue msg.
    echo "\n" | redrawstatus
    if ch == 'q' || ch == "\x1b"
        quit
    elseif ch == 'l'
        LabelLine()
    elseif ch == 'u'
        LabelUrl()
    endif
enddef

# data structure:
# {items: [item], Callback: cb}
# item: {pos: [x, y], label: ..., text: ..., ids: [match_ids or prop_ids]}
# Callback: (text) => lambda

const hintchars = 'asdfgzxcvwert'

def Label(param: dict<any>)
    # param needs to be modifiable (var)
    if param.items->len() == 0
        quit
    endif

    setlocal concealcursor=ncv conceallevel=3
    hi Conceal guifg=white guibg=blue ctermfg=white ctermfg=blue

    const hint_size = hintchars->len()
    var item_idx = 0
    const items_size = param.items->len()
    var label_length = 1
    {
        var sum = items_size
        while sum > hint_size
            sum /= hint_size
            label_length += 1
        endwhile
    }
    prop_type_add('Conceal', {highlight: 'Conceal'})
    for item in param.items
        {
            item.label = ''
            var len = label_length
            var idx = item_idx
            while len > 0
                len -= 1
                item.label = hintchars[idx % hint_size] .. item.label
                idx /= hint_size
            endwhile
        }
        item_idx += 1
        item.ids = []
        const pos_x = item.pos[0]
        const pos_y = item.pos[1]
        var pat = $'\%{pos_y}c.'
        const line = getline(pos_x)
        var to_be_hidden = line->matchstr(pat)
        while to_be_hidden->strdisplaywidth() < item.label->strdisplaywidth()
            var next_match = line->matchstr(pat .. '.')
            if empty(next_match)
                # pat span over line.
                break
            endif
            pat ..= '.'
            to_be_hidden = next_match
        endwhile
        const padding = to_be_hidden->strdisplaywidth() - item.label->strdisplaywidth()

        item.ids->add({
            type: 'prop',
            id: prop_add(pos_x, pos_y, {
                type: 'Conceal',
                text: item.label .. ' '->repeat(padding)
            })
        })

        item.ids->add({
            type: 'match',
            id: matchadd('Conceal', $'\%{pos_x}l' .. pat, 999, -1,
            {
                conceal: '&'  # any char is ok; we will hide it.
            })
        })
    endfor

    var input = ''
    while true
        redraw
        const ch = getcharstr()
        if ch == 'q' || ch == "\x1b"
            quit
        endif
        input ..= ch
        param.items->filter((_, item) => {
            if item.label->match($'^{input}') < 0
                for id in item.ids
                    if id.type == 'match'
                        matchdelete(id.id)
                    elseif id.type == 'prop'
                        prop_remove({id: id.id})
                    endif
                endfor
                return false
            endif
            return true
        })
        # move check here, so even only one item is hinted, we still need to
        # confirm.
        if param.items->len() <= 1 && len(input) == label_length
            break
        endif
    endwhile
    # if we press wrong hint char, then len will be zero.
    if param.items->len() == 1
        param.Callback(param.items[0].text)
    endif
    quit
enddef

def LabelLine()
    var param = {
        items: [],
        Callback: (text) => {
            # Avoid using "@+ = text", since it cannot compile when + register
            # is not available. (E354 is raised)
            # It's safe to use 'pbcopy', since it is available in all OS where
            # tmux is used (if tmux is available, then sh is available, then
            # ~/bin/pbpaste).
            system('pbcopy', text)
        }
    }

    var linenr = 0
    prop_type_add('reverse', {highlight: 'Visual'})
    for line in getline(1, '$')
        linenr += 1

        # make lines look easier to differ
        if linenr % 2 == 1
            prop_add(linenr, 1, { type: 'reverse', length: len(line) })
        endif

        if line->len() > 3  # too short lines does not worth hint.
            param.items->add({pos: [linenr, 1], text: line})
        endif
    endfor
    Label(param)
enddef

var urls = []
def AddUrl(line: number, col: number, text: string): string
    urls->add({line: line, col: col, url: text})
    return ''
enddef

def LabelUrl()
    var param = {
        items: [],
        Callback: (text) => {
            execute ':Sh -g' shellescape(text)
        }
    }
    const url_pattern = (
        '(' # == normal url
        .. 'http[s]\://'  # protocol
        .. '[a-zA-Z0-9._-]+[a-zA-Z0-9]'  # domain; no . at end.
        .. '((/[a-zA-Z0-9_/%?#.-]+[a-zA-Z0-9_/-])|)'  # path; some char not at end.
        .. ')|(' # == <> quoted url
        .. '\<\zs((http\://)|(https\://))[^>]+\ze\>'
        .. ')'
    )->substitute('/', '\\/', 'ge')

    urls = []
    execute $'keeppatterns :%s/\v{url_pattern}/\=AddUrl(line("."), col("."), submatch(0))/gne'

    hi url cterm=bold ctermbg=lightgrey ctermfg=black gui=bold guibg=lightgrey guifg=black
    prop_type_add('url', {highlight: 'url'})
    for item in urls
        prop_add(item.line, item.col, {type: 'url', length: item.url->len()})
        param.items->add({pos: [item.line, item.col], text: item.url})
    endfor

    # debug url detection.
    #echo url_pattern
    #echo urls
    #return

    Label(param)
enddef
