" action on choices (open a buffer, input mapped letter to do something);
" accept:
" msg: string to display / operate on;
" data: dict; key: letter(s) to map; value: list;
"   list: [desc (string), funcref (msg as arg)];
function! Choices(text, data) abort " {{{
    if has('nvim')
        return s:choices_impl_nvim(a:text, a:data)
    else
        return s:choices_impl_vim(a:text, a:data)
    endif
endfunction

function! s:kv_validate(k, v)
    let k = a:k
    let v = a:v
    if k !~# '\v^\S+$'
        return 0
    elseif type(v) != type([])
        return 0
    elseif len(v) < 2
        return 0
    elseif type(v[0]) != type('') || type(v[1]) != type(function('tr'))
        return 0
    else
        return 1
    endif
endfunction

function! s:shorten_text(text, ...)
    let result = []
    if a:0 == 1
        let opt = a:1
    else
        let opt = {}
    endif

    let width = get(opt, 'width', winwidth(0))
    let nr = 1
    let omit_nr = -1
    if !empty(a:text)
        let lines = split(a:text, '\n')
        let c = 0
        for i in lines
            " omit lines
            let c += 1
            if c >= 3 && c < len(lines)
                if c == 3
                    call add(result, '')
                    let omit_nr = nr
                    let nr += 1
                endif
                continue
            endif

            " omit columns in a line
            let s = i
            let v_col = width - 2
            while strdisplaywidth(s) > width
                let v_col -= 1
                let s = substitute(s, '\v(^.*%' . v_col . 'v).*$', '\1 ...', '')
            endwhile

            call add(result, s)
            let nr += 1
        endfor
        unlet c
        unlet lines

        if omit_nr > 0
            let result[omit_nr-1] = repeat('.', width / 2)
        endif
    endif
    call add(result, repeat('=', width))
    return result
endfunction

function! s:choices_impl_nvim(text, data) abort
    let buf = nvim_create_buf(v:false, v:true)
    let opts = {
                \'relative': 'editor', 'style': 'minimal',
                \'col': &columns / 4, 'row': &lines / 4,
                \'width': &columns / 2, 'height': &lines / 2,
                \}
    call nvim_open_win(buf, 1, opts)

    mapclear <buffer>
    mapclear! <buffer>

    let nr = 0
    for line in s:shorten_text(a:text)
        let nr += 1
        call setline(nr, line)
    endfor

    let delim = nr
    let nr += 1
    let b:text = a:text
    let b:funcs = {}
    for [k, v] in items(a:data)
        if !s:kv_validate(k, v)
            continue
        else
            let b:funcs[k] = v[1]
            exe 'nnoremap <buffer> <silent>' k
                        \ ':<C-u>call <SID>choices_do(
                        \ b:funcs["' . escape(k, '"') . '"], b:text)<CR>'
        endif
        call setline(nr, printf('[%s] %s', k, v[0]))
        let nr += 1
    endfor

    call setline(nr, '[q] quit')

    syntax clear
    exe 'syn region delim start=/\%' . delim . 'l/ end=/\%' . (delim + 1) . 'l/'
    syn match shortCut /\v^\[(.{-})\]/
    hi def link omit Comment
    hi def link delim Special
    hi def link shortCut Label
    setl ro
    nnoremap <buffer> <silent> q :<C-u>close<CR>
endfunction

" callback to popup_filter
function! s:vim_filter(id, key)
    if a:key == "\<Esc>"
        let s:vim_input_chars = ''
    else
        let s:vim_input_chars .= a:key
    endif
    if !empty(s:vim_input_chars)
        if s:vim_input_chars == 'q'
            call popup_close(a:id)
        else
            " funcref name limitation (E704)
            let s:action = get(s:vim_mapping, s:vim_input_chars)
            if !empty(s:action)
                call popup_close(a:id)
                call s:action(s:vim_text)
            else
                " check if clear input chars
                let found = 0
                for ch in keys(s:vim_mapping)
                    if stridx(ch, s:vim_input_chars) == 0
                        let found = 1
                        break
                    endif
                endfor
                if !found
                    let s:vim_input_chars = ''
                endif
            endif
        endif
    endif
    return 1
endfunction

function! s:choices_impl_vim(text, data) abort
    let s:vim_input_chars = ''
    let s:vim_text = a:text
    let s:vim_mapping = {}
    let text = []
    let width = &columns / 2
    " TODO === length; highlight
    for line in s:shorten_text(a:text, {'width': width})
        call add(text, line)
    endfor
    for [k, v] in items(a:data)
        if !s:kv_validate(k, v)
            continue
        else
            let s:vim_mapping[k] = v[1]
            call add(text, printf('[%s] %s', k, v[0]))
        endif
    endfor
    call add(text, '[q] quit')
    return popup_dialog(text,
                \{'filter': funcref('s:vim_filter'), 'maxwidth': width, 'minwidth': width})
endfunction

function! s:choices_do(action, text) abort
    close
    call a:action(a:text)
endfunction
