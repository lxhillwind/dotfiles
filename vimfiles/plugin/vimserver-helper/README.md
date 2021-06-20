# vimserver-helper
binary to be used in Vim session (plugin: [../vimserver.vim](../vimserver.vim)).

## usage
```sh
# server
$0 {server_filename} listen

# client (terminal-api style)
$0 {server_filename} {funcname} [args...]
# client (use stdin as raw params)
$0 {server_filename}
```
