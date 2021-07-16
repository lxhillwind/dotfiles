# vim-jump

simulate click in terminal.

## Usage

Add this to your vimrc:

```vim
au TerminalOpen * if &buftype ==# 'terminal'
\ | nmap <buffer> <CR> <Plug>(jump_to_file)
\ | vmap <buffer> <CR> <Plug>(jump_to_file)
\ | endif
```

Then in vim embeded terminal, `<CR>` will prompt you to open the related file
under the cursor.

You don't need to move cursor to the line / column number. (this is like in
quickfix window)

You can also map key in buffer of other buftype surely.

## Support jump type

vim-jump supports jump to:

- file; (requires you move cursor to the file; e.g., `ls` output)
- line of file; (e.g., `rg` search in directory)
- line / column of file; (e.g., `pylint` / `rg -H --column`)
