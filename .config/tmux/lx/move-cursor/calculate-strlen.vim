vim9script

# Usage: xxx | vim - -S this-file -es --not-a-term

def Main()
    # quit easily
    setl buftype=nofile
    # make "print" do not print linenr.
    setl nonu nornu

    var current_x = $CURRENT_X->str2nr()
    var current_y = $CURRENT_Y->str2nr()
    var target_x = $TARGET_X->str2nr()
    var target_y = $TARGET_Y->str2nr()
    const pane_width = $PANE_WIDTH->str2nr()

    # Here is a quite strange behavior:
    # If &columns is in the middle of a double width char,
    # then there will be a placeholder (displayed as ">>") created by vim
    # (it will only influence %v-like regex);
    # Then using %123v (where 123 > &columns) will match the column with
    # offset 1.
    # So we need to ensure that there are enough columns.
    if pane_width > 0
        &columns = pane_width
    endif

    var cursor_over_string = false
    const max_y = line('$')

    # start search
    {
        # Why "gg0"? See "v0" below.
        normal! gg0
        const y = min([current_y + 1, max_y])
        const x = min([strdisplaywidth(getline(y)), current_x + 1])
        if current_x + 1 > x
            cursor_over_string = true
        endif
        # match col 0 or col 1 is special
        const re_x = x <= 1 ? '^' : $'.%>{x}v'
        exec $'normal! /\v%{y}l{re_x}' .. "\<CR>"
    }
    # extend selection to next position,
    # and copy
    {
        const y = min([target_y + 1, max_y])
        const x = min([strdisplaywidth(getline(y)), target_x + 1])
        if target_x + 1 > x
            cursor_over_string = true
        endif
        # "0" in " v0/..." to make ".%>...v" match first visual column;
        # Why not using "%v"? because it may not match anything if cursor
        # is in middle of a double width char.
        const re_x = x <= 1 ? '^' : $'.%>{x}v'
        exec $'normal! v0/\v%{y}l{re_x}' .. "\<CR>y"
    }

    var result = @"->substitute("\n", '', 'g')->strcharlen()
    if !cursor_over_string
        result -= 1
    endif

    append('$', string(result))
    :$print
enddef

Main()
quit
