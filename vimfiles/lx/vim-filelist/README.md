# vim-filelist

Select from opened files easily.

## Intro

Shortcuts provided:

- `<Plug>(filelist_show)` to create new buffer to show filelist;
- `<Plug>(filelist_edit)` to open file (like `gf`);
- `<Plug>(filelist_cd)` to `:lcd` to directory of the file.

Every opened files' path will be recorded in the filelist file (see Config
section).

In the filelist buffer,

- most recent opened file is at top (from `v:oldfiles`);
- most frequent opened file is at bottom (from the filelist file).

## Usage

Example setup:

```vim
nmap <Leader>f <Plug>(filelist_show)

function! s:filelist_init()
  nmap <buffer> <CR> <Plug>(filelist_edit)
  nmap <buffer> <LocalLeader><CR> <Plug>(filelist_cd)
endfunction
au FileType filelist call <SID>filelist_init()
```

Then you can open filelist buffer with `<leader>f`;

operate on the content as in normal buffer, like jump, filter:

- move cursor with vim's builtin `hjkl` / search (e.g., `/pattern`, `*`);

- filter filename with `:global` / `:v` ex command;

After you positon cursor at the file you want to open, you can open it with
`<CR>`. (`gf` usually works if the filename does not contain special char)

## optional Config

set `g:filelist_path` (filename) to override filelist save path.
Directory will NOT be created.

filelist path priority:

`g:filelist_path` -> `&viminfofile` dir -> [cache/](cache/) in repo dir.
