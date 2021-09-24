## Usage

Add in vimrc:

```vim
" change the path to the actual path, if this repo is not cloned in $HOME.

" for vim8 / neovim (+eval):
source ~/vimfiles/vimrc.main

" for old version vim or without +eval feature:
source ~/vimfiles/vimrc.tiny
```

[vimrc.pkgs](vimrc.pkgs) defines some plugins to install (with `:Pack` command
defined in [vimrc.main](vimrc.main)), and it is sourced if file `vimrc.local`
is not readable;

To customize plugin installation, add a file named `vimrc.local`,
and call `:Pack` here.
