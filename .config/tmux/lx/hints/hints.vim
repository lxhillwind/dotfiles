vim9script

# emulate kitty's hint mode.
# usage:
#   cat {content-to-hint-on} | vim - --clean -S {path-to-this-file}

# enable :Open command.
runtime plugin/openPlugin.vim

def Main()
    setlocal buftype=nofile filetype=
    setlocal nofoldenable
    setlocal nowrap # if some line is full, vim display incorrectly; avoid it.

    hi hints_grey cterm=bold ctermbg=lightgrey ctermfg=black gui=bold guibg=lightgrey guifg=black

    # getcharstr() cannot catch <C-c>; so map it to quit.
    nnoremap <buffer> <C-c> <Cmd>quit<CR>
    const ch = GetChar('hint: [i]nside [l]ine [w]ord [u]rl ')
    if ch == 'i'
        LabelInside()
    elseif ch == 'l'
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

    # filter out items not visible.
    {
        const line_top = line('w0')
        const line_bot = line('w$')
        param.items->filter(
            (_, item) => item.pos[0] <= line_bot && item.pos[0] >= line_top
        )
    }

    if param.items->len() == 0
        quit
    endif

    setlocal concealcursor=ncv conceallevel=3
    # bold: make it more viewable
    hi Conceal guibg=blue guifg=white gui=bold ctermbg=blue ctermfg=white cterm=bold

    var item_idx = 0
    const items_size = param.items->len()
    var label_length = 1
    {
        while items_size > pow(hint_size, label_length)->float2nr()
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
        if param.items->len() == 0
            quit
        endif
        # move check here, so even only one item is hinted, we still need to
        # confirm.
        if param.items->len() == 1 && len(input) == label_length
            break
        endif
    endwhile
    param.Callback(param.items[0].text)
enddef

# helper {{{1
var matched_items = []
def AddToList(line: number, col: number, text: string): string
    matched_items->add({line: line, col: col, text: text})
    return ''
enddef

def CopyText(text: string)
    # Avoid using "@+ = text" directly, since it cannot compile when +
    # register is not available. (E354 is raised)
    #
    # Wrap !has('linux') with (): see:
    # https://github.com/vim/vim/issues/14265 (patch 9.1.0197)
    #
    # use b: var, since it is available in both vim9 content and execute().
    if has('clipboard') && (!has('linux'))
        # do not use @+ on linux, since clipboard content is not available
        # after gvim exits.
        b:hints_text = text
        execute('@+ = b:hints_text')
    else
        # replace with e.g. 'xsel -ib' if desired.
        system('pbcopy', text)
    endif
enddef

def GetChar(prompt: string): string
    redrawstatus
    echon prompt
    const resp = getcharstr()
    if resp == "\x1b"  #  (^[)
        quit
    endif
    # avoid press enter to continue msg.
    echo "\n" | redrawstatus
    return resp
enddef

def LabelInside() # {{{1
    var param = {
        items: [],
        Callback: CopyText,
    }
    const inside_char = GetChar('input delimiter char: ')
    const ch_l = escape(inside_char, '\]')
    const ch_r = {
        '<': '>',
        '(': ')',
        '[': '\]',
        '{': '}',
    }->get(ch_l, ch_l)
    LabelWord('(' ..
        $'[{ch_l}]\zs[^{ch_l}{ch_r}]+\ze[{ch_r}]'
        .. ')|(' ..
        $'([{ch_l}]|\s|^)\zs[^{ch_l}{ch_r} ]+\ze[{ch_r}]'
        .. ')|(' ..
        $'[{ch_l}]\zs[^{ch_l}{ch_r} ]+\ze([{ch_r}]|\s|$)'
        .. ')')
enddef

def LabelLine() # {{{1
    var param = {
        items: [],
        Callback: CopyText,
    }

    var linenr = 0
    prop_type_add('reverse', {highlight: 'hints_grey'})
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

def LabelWord(regex: string = '') # {{{1
    var param = {
        items: [],
        Callback: CopyText,
    }

    const word_pattern = (
        regex->empty() ? (
            '[a-zA-Z0-9./_@~#:\\-]{4,}'  # only collect words at least 4+1 chars long.
            .. '[a-zA-Z0-9./_-]'  # avoid @ at end (e.g. `ls -F` output)
        ) : regex
    )->substitute('/', '\\/', 'ge')

    matched_items = []
    execute $'keeppatterns :%s/\v{word_pattern}/\=AddToList(line("."), col("."), submatch(0))/gne'

    prop_type_add('word', {highlight: 'hints_grey'})
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
            execute ':Open' fnameescape(text)
            # since Vim commit 4b83d5ca76573373c0b57238b221a6a504bdb50b,
            # url is opened in background;
            # Sleep to avoid quiting vim before opening url (hopefully).
            sleep 200m
        }
    }
    const url_pattern = (
        '(' # == normal url
        .. 'https?\://'  # protocol
        .. '(\[::[0-9]+\]|[a-zA-Z0-9._-]+[a-zA-Z0-9])'  # domain; no . at end.
        .. '(\:[0-9]+|)'  # port
        .. '(/[a-zA-Z0-9_/%?#.=&:~-]+[a-zA-Z0-9_/=~-]|/|)'  # path; some char not at end.
        .. ')|(' # == <> quoted url
        .. '\<\zshttps?\://[^>]+\ze\>'
        .. ')|(' # == () quoted url in markdown
        .. '\]\(\zshttps?\://[^)]+\ze\)'
        .. ')|(' # == "" url in html attr
        .. '\="\zshttps?\://[^"]+\ze"'
        .. ')'
    )->substitute('/', '\\/', 'ge')

    matched_items = []
    execute $'keeppatterns :%s/\v{url_pattern}/\=AddToList(line("."), col("."), submatch(0))/gne'

    prop_type_add('url', {highlight: 'hints_grey'})
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

# start {{{1
Main()
