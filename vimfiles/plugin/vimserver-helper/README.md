# vimserver-helper
binary to be used in Vim session (plugin: [../vimserver.vim](../vimserver.vim)).

## usage
```sh
# server
$0 {server_filename} listen

# client
$0 {funcname} [args...]
# client (use stdin)
$0 {funcname}
```
