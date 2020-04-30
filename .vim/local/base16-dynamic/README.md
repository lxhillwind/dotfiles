# base16-dynamic.vim

# Install
Use your favorite Vim plugin manager.

# Usage
```vim
" Optional: if you want to disable italic font (enabled by default):
let g:base16#enable_italics = 0

" Required: set base16 pallet (base00 to base0F)
" example (material)
" https://github.com/ntpeters/base16-materialtheme-scheme/blob/master/material.yaml
let g:base16#pallet = {"base00": "263238", "base01": "2E3C43", "base02": "314549", "base03": "546E7A", "base04": "B2CCD6", "base05": "EEFFFF", "base06": "EEFFFF", "base07": "FFFFFF", "base08": "F07178", "base09": "F78C6C", "base0A": "FFCB6B", "base0B": "C3E88D", "base0C": "89DDFF", "base0D": "82AAFF", "base0E": "C792EA", "base0F": "FF5370"}

" After setting these variables
colorscheme base16-dynamic
```

# License
original software ([chriskempson/base16-vim](https://github.com/chriskempson/base16-vim)):
[MIT](https://github.com/chriskempson/base16-vim/blob/master/LICENSE.md)

The [original file](templates/default.mustache) is also included.
