vim9script

# TODO start / end pattern tweak. I don't know if current impl is desired.
#
# NOTE: although key binding is <C-n>, we usually should press <C-e> first:
#   otherwise it will not get triggered. (why?)

inoremap <expr> <C-n> pumvisible() ? "\<C-n>" : "\<C-r>=<SID>BBYacMain()\<CR>"

def BBYacMain(): string
    const [_, pos] = searchpos('\v%.l\S*%.c', 'bn')
    if pos == 0
        return ''
    endif
    const word = getline('.')->strpart(pos - 1, col('.') - pos + 1)
    var pattern = ''
    var is_first = true
    for i in word->split('\zs')
        if !is_first
            pattern ..= '.*'
        endif
        is_first = false
        pattern ..= printf('[%s]', escape(i, '\'))
    endfor
    pattern = '\v\c<' .. pattern .. '>'
    var result = matchbufline('', pattern, 1, '$')
        ->mapnew((_, i) => i.text)

    const tmux_cmd =<< trim END
    for i in $(tmux list-panes | grep -Ev active | grep -Eo '^[0-9]+'); do
        tmux capture -p -t "$i"
    done
    END

    const result_tmux = !empty($TMUX) ? (
        matchstrlist(systemlist(tmux_cmd->join("\n")), pattern)
        ->mapnew((_, i) => i.text)
    ) : []

    result = result->extend(result_tmux)
        ->sort()->uniq()
        ->filter((_, i) => i != word)
    complete(pos, result)
    return ''
enddef
