vim9script

export def FminiSnip(findstart: number, base: string): any # {{{
    if findstart == 1
        const line = getline('.')->strpart(0, col('.') - 1)
        const prefix = line->matchstr('\w\+$')
        const startcol = col('.') - prefix->strlen()
        if prefix->len() < 1
            # {{{ when used in builtin completion (not vimcomplete plugin):
            # if use 2 (trigger completion when length >= 2),
            # second call to this function does not update a:base.
            # So use 1 here (DO NOT use 0, since it would trigger completion
            # even on dot / space, which is quite annoying).
            # }}}
            return -2
        else
            return startcol
        endif
    else
        return miniSnip#completeFunc(findstart, base)
    endif
enddef # }}}

export def Fpath(findstart: number, base: string): any # {{{
    if findstart == 1
        const line = getline('.')->strpart(0, col('.') - 1)
        const prefix = line->matchstr(
            '\v(^|\W)\zs'
            .. (has('win32') ? '(\w\:|\.)[\/]' : '\.?/')
            .. '\S*$'
        )
        const startcol = col('.') - prefix->strlen() - 1
        if prefix->len() < 1
            return -2
        else
            return startcol
        endif
    else
        if base->slice(-1)->match(has('win32') ? '\v[\/]' : '/') >= 0 && isdirectory(base)
            var items = []
            try
                items = readdir(base)
            catch /.*:E484:/
            endtry
            path_cache.items = items->mapnew((_, i) => ({
                # remove '/\zs.' from base, e.g. ./. + .config => ./.config
                word: base->substitute('/\zs.$', '', '') .. i, abbr: i,
                kind: 'f', menu: '[path]',
            }))
        endif
        return path_cache.items
    endif
enddef

var path_cache = {
    items: [],
}
# }}}
