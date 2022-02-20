# Usage

Add in vimrc:

```vim
" change the path to the actual path, if this repo is not cloned in $HOME.

" for vim8 / neovim (+eval):
source ~/vimfiles/vimrc.main

" for old version vim or without +eval feature:
source ~/vimfiles/vimrc.tiny
```

[rc/pkgs.vim](rc/pkgs.vim) defines some plugins to install (with `:Pack` command
defined in [rc/pack.vim](rc/pack.vim)), and it should be sourced manually,
like:

```vim
runtime rc/pkgs.vim
```
