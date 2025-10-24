vim9script

# TODO start / end pattern tweak. I don't know if current impl is desired.
#
# Credit: https://github.com/baohaojun/bbyac (for inspiration and plugin name)

inoremap <C-x><C-y> <C-r>=<SID>BBYacMain()<CR>

def BBYacMain(): string
    const [_, pos] = searchpos('\v%.l\S*%.c', 'bn')
    if pos == 0
        return ''
    endif
    const word = getline('.')->strpart(pos - 1, col('.') - pos + 1)
    var pattern = ''
    var pattern_non_greedy = ''
    var is_first = true
    for i in word->split('\zs')
        if !is_first
            pattern ..= '.*'
            pattern_non_greedy ..= '.{-}'
        endif
        is_first = false
        pattern ..= printf('[%s]', escape(i, '\'))
        pattern_non_greedy ..= printf('[%s]', escape(i, '\'))
    endfor
    if word[0] =~ '\w'
        pattern = '\w*' .. pattern
        pattern_non_greedy = '\w*' .. pattern_non_greedy
    endif
    if word[-1] =~ '\w'
        pattern = pattern .. '\w*'
        pattern_non_greedy = pattern_non_greedy .. '\w*'
    endif
    pattern = '\v\c' .. pattern
    pattern_non_greedy = '\v\c' .. pattern_non_greedy

    var result = []

    for win in getwininfo()->filter((_, i) => i.tabnr == tabpagenr())
        result->extend(
            matchbufline(win.bufnr, pattern, win.topline, win.botline)
            ->mapnew((_, i) => i.text)
        )
    endfor

    const tmux_cmd =<< trim END
    for i in $(tmux list-panes | grep -Ev active | grep -Eo '^[0-9]+'); do
        tmux capture -p -t "$i"
    done
    END

    result->extend(!empty($TMUX) ? (
        matchstrlist(systemlist(tmux_cmd->join("\n")), pattern)
        ->mapnew((_, i) => i.text)
    ) : [])

    result = result
        ->sort()->uniq()
        ->filter((_, i) => i != word)

    result->extend(
        matchstrlist(result, pattern_non_greedy)
        ->mapnew((_, i) => i.text)
    )

    result = result
        ->sort()->uniq()
        ->filter((_, i) => i != word)

    complete(pos, result)
    return ''
enddef
