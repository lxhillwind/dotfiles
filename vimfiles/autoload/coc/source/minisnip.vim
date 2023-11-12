def g:coc#source#minisnip#init(): dict<any>
    return {
        shortcut: 'snip',
    }
enddef

def g:coc#source#minisnip#complete(option: dict<any>, Cb: func)
    var result = miniSnip#completeFunc(0, option.input)
    Cb(result)
enddef
