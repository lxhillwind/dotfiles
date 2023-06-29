vim9script

# vim-vimserver should be called early.
packadd vim-vimserver

# disable default plugin {{{
g:loaded_2html_plugin = 1
g:loaded_getscriptPlugin = 1
g:loaded_gzip = 1
g:loaded_logiPat = 1
g:loaded_netrwPlugin = 1
g:loaded_tarPlugin = 1
g:loaded_vimballPlugin = 1
g:loaded_zipPlugin = 1  # }}}

g:tasks_config_paths =<< trim END
    ~/vimfiles/config/tasks.ini
    ~/vimfiles/config/tasks-local.ini
END
g:tasks_config_paths
    ->map((_, i) => expand(i))
    ->filter((_, i) => filereadable(i))

g:markdown_folding = 1
g:markdown_fenced_languages = [
    'awk', 'python', 'sh', 'vim',
    'c', 'go', 'javascript',
    'dosini', 'json', 'yaml',
    'zig',
]

# use matchit, so vim9 filetype indent work as expected.
# https://github.com/vim/vim/issues/7628
packadd! matchit

packadd! vim-fuzzy
packadd! securemodelines
packadd! vim9-syntax
packadd! vim-tridactyl

packadd! vim-dirvish
g:loaded_netrwPlugin = 1

packadd! vim-sneak
g:sneak#label = 1
# sneak unmap f / t when one of them is pressed after sneak key. {{{
# MRE:
#   :map t <Nop><CR>
#   sssff
#   :map t
# then mapping for t disappeared.
#
# since I only map t / T (f / F not mapped), only set t / T below.
# }}}
g:sneak#f_reset = 1
g:sneak#t_reset = 0
# I do not use vim-surround, so preserve s / S for vim-sneak.
vmap S <Plug>Sneak_S
omap s <Plug>Sneak_s
omap S <Plug>Sneak_S

packadd! vim-markdown-folding
g:markdown_fold_style = 'nested'
g:markdown_fold_override_foldtext = 0

# colorscheme
packadd! sitruuna.vim
