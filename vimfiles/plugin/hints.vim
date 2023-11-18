vim9script

# emulate kitty's hint mode.

command! HintsMode HintsMode()

def HintsMode()
    setlocal buftype=nofile
    setlocal nonumber norelativenumber nofoldenable nocursorcolumn nocursorline
    setlocal nowrap # if some line is full, vim display incorrectly; avoid it.
    setlocal nohlsearch # avoid last search causing visual distraction
    redraw
    echon 'hint: [l]ine [u]rl <<< other key to quit '
    const ch = getcharstr()
    # avoid press enter to continue msg.
    echo "\n" | redrawstatus
    if ch == 'l'
        LabelLine()
    elseif ch == 'w'
        LabelWord()
    elseif ch == 'u'
        LabelUrl()
    else
        quit
    endif
enddef

# param data structure:
# {items: [item], Callback: cb}
# item: {pos: [x, y], label: ..., text: ..., ids: [match_ids or prop_ids]}
# Callback: (text) => lambda

# Label impl {{{1
const hintchars = 'asdfgzxcvwert'
const hint_size = hintchars->len()
prop_type_add('Conceal', {highlight: 'Conceal'})

def Label(param: dict<any>)
    # param needs to be modifiable (var)
    if param.items->len() == 0
        quit
    endif

    setlocal concealcursor=ncv conceallevel=3
    hi Conceal guifg=white guibg=blue ctermfg=white ctermfg=blue

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
    for item in param.items
        AddLabel(item, item_idx, label_length)
        item_idx += 1
    endfor
    HandleInput(param, label_length)
    quit
enddef

def AddLabel(item: dict<any>, item_idx: number, label_length: number)
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
    const pos_x = item.pos[0]
    const pos_y = item.pos[1]
    var pat = $'\%{pos_y}c.'

    # calculate padding
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

    # add label; hide overlapped string
    item.ids = []
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
enddef

def HandleInput(param: dict<any>, label_length: number)
    var input = ''
    while true
        redraw
        const ch = getcharstr()
        if hintchars->match(ch) < 0
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
enddef

# helper {{{1
var matched_items = []
def AddToList(line: number, col: number, text: string): string
    matched_items->add({line: line, col: col, text: text})
    return ''
enddef

def LabelLine() # {{{1
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

def LabelWord() # {{{1
    var param = {
        items: [],
        Callback: (text) => {
            system('pbcopy', text)
        }
    }

    const word_pattern = (
        '[a-zA-Z0-9./@\\-]{4,}'  # only collect words at least 4+1 chars long.
        .. '[a-zA-Z0-9./-]'  # avoid @ at end (e.g. `ls -F` output)
    )->substitute('/', '\\/', 'ge')

    matched_items = []
    execute $'keeppatterns :%s/\v{word_pattern}/\=AddToList(line("."), col("."), submatch(0))/gne'

    hi word cterm=bold ctermbg=lightgrey ctermfg=black gui=bold guibg=lightgrey guifg=black
    prop_type_add('word', {highlight: 'word'})
    for item in matched_items
        prop_add(item.line, item.col, {type: 'word', length: item.text->len()})
        param.items->add({pos: [item.line, item.col], text: item.text})
    endfor

    Label(param)
enddef

def LabelUrl() # {{{1
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

    matched_items = []
    execute $'keeppatterns :%s/\v{url_pattern}/\=AddToList(line("."), col("."), submatch(0))/gne'

    hi url cterm=bold ctermbg=lightgrey ctermfg=black gui=bold guibg=lightgrey guifg=black
    prop_type_add('url', {highlight: 'url'})
    for item in matched_items
        prop_add(item.line, item.col, {type: 'url', length: item.text->len()})
        param.items->add({pos: [item.line, item.col], text: item.text})
    endfor

    # debug url detection.
    #echo url_pattern
    #echo matched_items
    #return

    Label(param)
enddef
