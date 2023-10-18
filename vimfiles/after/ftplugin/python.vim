vim9script

# we have defined '&keywordprg' in vimrc;
# but bundled ftplugin/python.vim overrides '&keywordprg';
# redo it when mapping gd is defined (e.g. lsp.vim plugin is enabled).
if !empty(maparg('gd', 'n'))
    &l:keywordprg = ':LspHover'
endif
