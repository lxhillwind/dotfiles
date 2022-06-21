vim9script

export def ShellSplitUnix(s: string): list<string>
    # shlex.split() with unix rule for unix and win32.
    var state: string = 'whitespace'
    var idx = 0
    var ch: string
    var token: string = ''
    var result: list<string> = []

    while idx < len(s)
        ch = s[idx]
        idx += 1

        if ch == "'"
            if state == 'raw' || state == 'whitespace'
                state = 'quote_single'
            elseif state == 'quote_single'
                state = 'raw'
            else
                token ..= ch
                if state == 'backslash'
                    state = 'raw'
                endif
            endif
        elseif ch == '"'
            if state == 'raw' || state == 'whitespace'
                state = 'quote_double'
            elseif state == 'quote_double'
                state = 'raw'
            elseif state == 'quote_backslash'
                token ..= ch
                state = 'quote_double'
            else
                token ..= ch
                if state == 'backslash'
                    state = 'raw'
                endif
            endif
        elseif ch == '\'
            if state == 'quote_double'
                state = 'quote_backslash'
            elseif state == 'raw' || state == 'whitespace'
                state = 'backslash'
            elseif state == 'backslash'
                token ..= '\'
                state = 'raw'
            elseif state == 'quote_single'
                token ..= '\'
            elseif state == 'quote_backslash'
                token ..= '\'
                state = 'quote_double'
            else
                throw 'vim-sh: invalid state: \'
            endif
        elseif ch =~ '\s'
            if state == 'whitespace'
                # nop
            elseif index(
                ['quote_double', 'quote_single', 'quote_backslash', 'backslash'],
                state) >= 0
                if state == 'quote_backslash'
                    token ..= '\'
                endif
                token ..= ch
                if state == 'backslash'
                    state = 'raw'
                elseif state == 'quote_backslash'
                    state = 'quote_double'
                endif
            elseif state == 'raw'
                add(result, token)
                token = ''
                state = 'whitespace'
            else
                throw 'vim-sh: invalid state: \s'
            endif
        else
            if state == 'whitespace' || state == 'backslash'
                state = 'raw'
            elseif state == 'quote_backslash'
                token ..= '\'
                state = 'quote_double'
            endif
            token ..= ch
        endif
    endwhile

    if state == 'raw'
        add(result, token)
    elseif state == 'whitespace'
        # nop
    else
        throw 'input not legal: state at finish: ' .. state
    endif

    return result
enddef
