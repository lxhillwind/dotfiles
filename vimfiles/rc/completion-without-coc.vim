vim9script

# basic part, which works even if no plugin is installed. {{{3
# source for dictionary, current or other loaded buffers, see ':help cpt'
set cpt=.,k,w,b
# don't select the first item.
set completeopt=menu,menuone,noselect
# suppress annoy messages.
set shortmess+=c

# vim-mucomplete. {{{3
packadd! vim-mucomplete
# disable its imap <Tab> (and some others)
g:mucomplete#enable_auto_at_startup = 1
g:mucomplete#no_mappings = 1
imap <expr> <Tab> (pumvisible() ? "\<plug>(MUcompleteCycFwd)" : "\<plug>(MUcompleteFwd)")
imap <expr> <S-Tab> (pumvisible() ? "\<plug>(MUcompleteCycBwd)" : "\<plug>(MUcompleteBwd)")
# disable keyn / dict: included in c-n via option 'complete' ('cpt');
# about these chains description: help 'mucomplete-methods'
g:mucomplete#chains = {
    default: ['path', 'omni', 'user', 'c-n', 'uspl'],
    vim:     ['path', 'cmd',  'user', 'c-n', 'uspl'],
    # sql: disable omni, since it causes trouble. (sth missing?)
    sql:     ['path',         'user', 'c-n', 'uspl'],
}
# make <CR> always add newline.
inoremap <expr> <cr> pumvisible() ? "<c-y><cr>" : "<cr>"

# dict-completion sources. {{{3
packadd! vim-dict
# always enable dict completion. (i_<Ctrl-x><Ctrl-k>)
execute 'set dict+=' .. globpath(&rtp, 'dict/text.dict', 0, 1)->get(0, '')->fnameescape()
# File type override
#g:vim_dict_config = {'html':'html,javascript,css', 'markdown':'text'}
# Disable certain types
#g:vim_dict_config = {'text': ''}
