vim9script

nnoremap <Space>bb <Cmd>call <SID>BookmarkAdd()<CR>
nnoremap <Space>bo <Cmd>call fuzzy#Main('User.bookmark')<CR>
nnoremap <Space>be <Cmd>call <SID>BookmarkEdit()<CR>

# depends on ":SetCmdText", vim-fuzzy, fuzzy#config.


command! -nargs=* BookmarkAdd BookmarkAdd(<args>)
const bookmark_file = expand('~/.vim/files/bookmark.txt')

# impl {{{1
def BookmarkAdd(args: dict<any> = {})
    var current_file = bufname('%')
    if current_file->empty()
        throw 'current buffer name is empty!'
    endif
    current_file = current_file->fnamemodify(':p')
    if args->empty()
        const cmdline = printf(
        'BookmarkAdd {"file": "%s", "line": "%d", "title": ""}',
        current_file->escape('"'), line('.'),
        )
        execute 'SetCmdText' cmdline .. "\<Left>"->repeat(2)
    else
        const file: string = args.file
        const line: number = args.line->str2nr()
        const title: string = args.title
        if BookmarkAllData()
                    ->mapnew((_, i) => i->json_decode())
                    ->filter((_, i) => i.file == file && i.line == line)->len() > 0
            throw 'already bookmarked'
        endif
        [
            {file: file, line: line, title: title}->json_encode()
            ]->writefile(bookmark_file, 'a')
        echo 'bookmark created with title: ' .. title .. '.'
    endif
enddef

def BookmarkAllData(): list<string>
    if filereadable(bookmark_file)
        return bookmark_file->readfile()
    endif
    return []
enddef

def BookmarkOpenFn(): list<dict<string>>
    return BookmarkAllData()
                ->mapnew((_, i) => json_decode(i))
                ->filter((_, i) => i.file->filereadable() || i.file->isdirectory())
                ->mapnew((_, i) => ({
    text: i.file .. ':' .. i.line,
    trailer: i.title,
    location: '',
    search_trailer: '1',
                }))
enddef

def BookmarkOpenExFn(line: string): dict<string>
    const res = line->matchstr('\v.*:[0-9]+\ze\t')->split('.*\zs:')
    return {
        filename: res[0],
        lnum: res[1],
    }
enddef

g:fuzzy#config->extend({
bookmark: {
    Fn: BookmarkOpenFn,
    ExtractInfoFn: BookmarkOpenExFn,
    Callback: (chosen: string) => {
        const res = chosen->matchstr('\v.*:[0-9]+$')->split('.*\zs:')
        execute 'e' fnameescape(res[0])
        const linenr = res->get(1, 0)
        if linenr > 0
            execute $'norm {linenr}G'
        endif
    }
    }
})

def BookmarkEdit()
    execute 'edit' bookmark_file->fnameescape()
enddef
