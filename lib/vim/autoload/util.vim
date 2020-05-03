fun! util#shell_split(args)
    let result = []
    let idx = 0
    let char_idx = 0
    " valid state: normal, backslash, quote, quote_backslash, space
    let state = 'normal'
    while char_idx < len(a:args)
        let char = a:args[char_idx]
        let char_idx += 1
        let eat_ch = v:false
        " Windows use backslash as path seperator.
        let last_backslash = v:false
        if state == 'normal'
            if char == '"'
                let state = 'quote'
            elseif match(char, '\s') != -1
                let state = 'space'
            elseif char == '\'
                let state = 'backslash'
            else
                let eat_ch = v:true
            endif
        elseif state == 'backslash'
            let state = 'normal'
            let eat_ch = v:true
            let last_backslash = v:true
        elseif state == 'quote'
            if char == '\'
                let state = 'quote_backslash'
            elseif char == '"'
                let state = 'normal'
                if len(result) == idx
                    " "" in string
                    let result = add(result, '')
                endif
            else
                let eat_ch = v:true
            endif
        elseif state == 'quote_backslash'
            let state = 'quote'
            let eat_ch = v:true
            let last_backslash = v:true
        elseif state == 'space'
            let idx = len(result)
            if match(char, '\s') == -1
                if char == '"'
                    let state = 'quote'
                elseif char == '\'
                    let state = 'backslash'
                else
                    let state = 'normal'
                    let eat_ch = v:true
                endif
            endif
        else
            throw 'shell_split: unreachable 1'
        endif
        if eat_ch
            if last_backslash && match(char, '\v("|\s|\\)') == -1
                let char = '\' . char
            endif
            if idx == len(result)
                let result = add(result, char)
            else
                let result[idx] .= char
            endif
        endif
    endwhile
    if state == 'backslash'
        throw 'trailing backslash found'
    elseif state == 'quote'
        throw 'unfinished quote string'
    elseif state == 'quote_backslash'
        throw 'unfinished backslash in quote string'
    endif
    return result
endfun


fun! util#shell_split_test()
    echo util#shell_split('"arg 1" arg\ 2 \ arg3 ar "" g4')
    echo util#shell_split('"arg 1 arg\ 2 \\ arg3 arg4\""   ')
    echo util#shell_split('c:\program\ files\unix\sh.exe')
    echo util#shell_split('"c:\program files\unix\sh.exe" -f')
endfun
