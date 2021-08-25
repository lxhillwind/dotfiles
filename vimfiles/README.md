## Usage

Add in vimrc:

```vim
source ~/vimfiles/vimrc.tiny
source ~/vimfiles/vimrc.vim

call plug#begin('~/vimfiles/bundle')
source ~/vimfiles/vimrc.pkgs
call plug#end()
```
