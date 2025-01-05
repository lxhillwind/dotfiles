vim9script

# do not save anything during this session.
set viminfo=

def Main()
    setl buftype=nofile

    var current_x = $CURRENT_X->str2nr()
    var current_y = $CURRENT_Y->str2nr()
    var target_x = $TARGET_X->str2nr()
    var target_y = $TARGET_Y->str2nr()
    const pane_width = $PANE_WIDTH->str2nr()
    const tmp_file = $TMP_FILE

    # Here is a quite strange behavior:
    # If &columns is in the middle of a double width char,
    # then there will be a placeholder (displayed as ">>") created by vim
    # (it will only influence %v-like regex);
    # Then using %123v (where 123 > &columns) will match the column with
    # offset 1.
    # So we need to ensure that there are enough columns.
    &columns = pane_width

    var cursor_over_string = false

    # start search
    {
        # Why "gg0"? See "v0" below.
        normal! gg0
        var y = current_y + 1
        var x = min([strdisplaywidth(getline(y)), current_x + 1])
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
        var y = target_y + 1
        var x = min([strdisplaywidth(getline(y)), target_x + 1])
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
    [string(result)]
        ->writefile(tmp_file)
enddef

Main()
quit