vim9script

def Main()
    nnoremap <C-c> :q<CR>
    const keys_quit = ["\<C-c>", "\<C-d>", "\<Esc>", "\<C-[>", 'q']
    const keys_move = {h: 'L', j: 'D', k: 'U', l: 'R'}
    echon 'h/j/k/l to resize; <C-c>/<C-d>/<Esc>/q to quit'
    while true
        const ch = getcharstr()
        if keys_quit->index(ch) >= 0
            quit
        endif
        if keys_move->has_key(ch)
            job_start(['tmux', 'resize-pane', '-' .. keys_move[ch]])
        endif
    endwhile
enddef

Main()
