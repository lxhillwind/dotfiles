vim9script

# disable default plugin {{{1
g:loaded_2html_plugin = 1
g:loaded_getscriptPlugin = 1
g:loaded_gzip = 1
g:loaded_logiPat = 1
g:loaded_netrwPlugin = 1
g:loaded_tarPlugin = 1
g:loaded_vimballPlugin = 1
g:loaded_zipPlugin = 1

# bundled plugin config. {{{1
g:tasks_config_paths =<< trim END
    ~/vimfiles/config/tasks.ini
    ~/vimfiles/config/tasks-local.ini
END
g:tasks_config_paths
    ->map((_, i) => expand(i))
    ->filter((_, i) => filereadable(i))

g:markdown_folding = 1

# keep sync with https://lxhillwind.gitee.io/ highlight.
# NOTE: zig is not available in hljs right now.
g:markdown_fenced_languages = [
    'awk', 'python', 'sh', 'vim',
    'c', 'go', 'javascript',
    'dosini', 'json', 'yaml',
    'zig',
]

# lx {{{1
packadd! vim-jump
packadd! vim-sh
packadd! pyvim
g:pyvim_rc = expand('~/vimfiles/config/pyvim.py')

# vim dist. {{{1
# plugin here should not be loaded with ":Pack", since ":PackHelpTags" does
# not have enough permission to gen tag for them.
# use ":packadd!" (with !) to only add them to &rtp.
#
# use matchit, so vim9 filetype indent work as expected.
# https://github.com/vim/vim/issues/7628
packadd! matchit

# vender. {{{1
# Pack 'https://github.com/lacygoill/vim-fuzzy', {'commit': 'fa6a719'}
packadd! vim-fuzzy

# from network {{{1
Pack 'https://github.com/justinmk/vim-dirvish'
g:loaded_netrwPlugin = 1
Pack 'https://github.com/justinmk/vim-sneak'
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
Pack 'https://github.com/ciaranm/securemodelines', {'after': 1}
Pack 'https://github.com/masukomi/vim-markdown-folding'
g:markdown_fold_style = 'nested'
g:markdown_fold_override_foldtext = 0
Pack 'https://github.com/lacygoill/vim9-syntax'
Pack 'https://github.com/tridactyl/vim-tridactyl'
# colorscheme
Pack 'https://github.com/eemed/sitruuna.vim'
