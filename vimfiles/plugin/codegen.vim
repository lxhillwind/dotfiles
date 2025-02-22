vim9script

# Usage:
#   use ":Codegen xxx" to generate text, where xxx is shell cmd;
#   generated text is put in following "Codegen begin" / "Codegen end" block
#   (the block is created if necessary).
#
# Workflow:
#   I have "<Space><CR>" mapped to execute vim command in current line
#   (comment removed); ":<C-r><C-l>" is also an option, though comment needs
#   to be removed manually.
#
# Shebang:
#   like ":Codegen #!python
#   import os
#   print(os.name)"
#   ; shebang is extended to newline.
#
# Credit: https://github.com/baohaojun/system-config for inspiration.

command! -nargs=+ Codegen Codegen(<q-args>)

const marker_begin = 'Codegen begin'
const marker_end = 'Codegen end'

def Codegen(arg: string)
    const is_visual_mode = mode() =~ "\\v[vV\<C-v>]"
    const line_nr = is_visual_mode ? max([line('v'), line('.')]) : line('.')
    const cursor_pos = getcurpos()
    if is_visual_mode
        # exit visual mode early, to avoid search() mess up selection.
        normal! :
    endif

    const result = GetCodeResult(arg)

    const block_start = search($'\v%>{line_nr}l' .. marker_begin)
    const block_end = search($'\v%>{line_nr}l' .. marker_end)
    var append_after = block_start
    if block_start > 0 && block_end > 0 && block_start < block_end
        if block_start + 1 != block_end
            # delete lines between block.
            silent execute $':{block_start + 1},{block_end - 1}d _'
        endif
    else
        # add Codegen block
        for [i, j] in [
                [line_nr, marker_begin], [line_nr + 1, marker_end],
                ]
            var s = j
            if !empty(&commentstring)
                # try to comment them; Don't know how to make "v_gc" work...
                s = printf(&commentstring, j)
            endif
            append(i, s)
        endfor
        append_after = line_nr + 1
    endif
    append(append_after, result->split("\n"))
    setpos('.', cursor_pos)
enddef


def GetCodeResult(arg: string): string
    const shebang_end = arg->matchend('\v^#\![^\n]+\n?')
    if shebang_end >= 0
        # 2: len('#!')
        const cmd = arg->strpart(2, shebang_end - 2)
        const stdin = arg->strpart(shebang_end)
        return system(cmd, stdin)
    else
        return system(arg)
    endif
enddef
