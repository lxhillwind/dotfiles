if has('vim_starting')
  " openSUSE set mapping to make <Ctrl-[> look buggy. so we clear it.
  " /usr/share/vim/vim82/suse.vimrc
  mapclear
  mapclear!
endif

if 1
  " skip if +eval is not available.
  source ~/vimfiles/vimrc.main
  finish
endif

" load if +eval is not available.
source ~/vimfiles/vimrc.tiny
