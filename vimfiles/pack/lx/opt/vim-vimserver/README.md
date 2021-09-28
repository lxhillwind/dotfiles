# vimserver

## Feature
- inside terminal, open vim buffer in outside vim.

## Requirement
- vim 8.1.2233+ (job feature) or neovim 0.5.0+; (`v:argv`)

- vimserver-helper binary (*optional*; required for Windows OS; see below for
  installation method);

- `socat` (*optional*; required for bundled shell script
  [bin/vimserver-helper.sh](bin/vimserver-helper.sh) if vimserver-helper
binary is not available).

## Setup
```vim
" source plugin/vimserver.vim at very top of your vimrc (or use ":runtime").
" If using ":runtime", then you should set &rtp correctly.
runtime vim-vimserver/plugin/vimserver.vim
```

To ignore startup error (`vimserver executable not found!`), set variable like
this:

```vim
let g:vimserver_ignore = 1
```

## Usage
- Inside terminal session, call `vim [filename]...` to open buffer in outside
  vim.
- `vim +vs [filename]...` will split window vertically.
- `vim +sp [filename]...` will split window horizontally.
- `vim +tabe [filename]...` will open window in new tab.

(replace vim with nvim if using neovim)

If no filename argument is provided, vim will just open a new empty window.

If multiple filename arguments are provided, only the first one will be shown,
other files can be accessed with `:next` / `:prev` (`:help arglist` for help).

## Info
This plugin defines variable `g:vimserver_env` (dict of string), which can be
passed to other functions (like `term_start`) in case environment variables
`VIMSERVER_*` are unset in some place.

## vimserver-helper binary
It should work on all major platforms, including at least Windows, Linux, Mac.

(to produce a binary targeting at Windows XP, Go compiler 1.10- is required.)

### Installation

```sh
cd vimserver-helper/

# pass GOOS / GOARCH env to compile binary for other platform.
go build
```

<details>
<summary>
vimserver-helper internal Usage (`:help terminal-api`)
</summary>

```sh
# server
$0 {server_filename} listen

# client (terminal-api style)
$0 {server_filename} {funcname} [args...]
# client (use stdin as raw params)
$0 {server_filename}
```

- Since vimserver sets `VIMSERVER_BIN` environment variable, you can replace
  `$0` above with `"$VIMSERVER_BIN"`.

- Replace `{server_filename}` with `$VIMSERVER_ID`.

- For terminal-api style client (bundled shell script), `jq` is required.

TODO: allow passing non-string argument in terminal-api mode.

</details>