## Usage

- **optional** set variable `g:pyvim_host` (default: `python3`) to path of
  Python.
- **optional** set variable `g:pyvim_rc` to alternative path of user config
  file (maybe you want to keep it in your dotfiles; access it in Python
  process with environment variable `PYVIM_RC`, if variable is set).

Then you can run vim command `:Py3 {method-name}`.

Run `:Py3 config` to open user config file (you can re-define the behavior
by rewriting the `config` method in it).

## special method (not passed to python process)

- help: display method `__doc__`.
- restart: restart python process.

## stdout / stderr
- msg in stdout, if not json deserializable (and not starts with `{`), will be
  shown with vim's ":echo" command.
- msg in stderr will be shown with vim's ":echomsg" command.

<del>

Be aware that vim handles msg line by line; if you run `print(msg + '\n')` in
Python, then `msg` in msg bar will be overwritten by `''` (empty).

</del>

Since it is too easy to output a final newline in stdout (which makes debug
harder), this plugin will ignore lines in stdout which only contains a newline
character. (newline alone in stderr is still reserved; it can be revisited
with `:messages` command)

## asyncio
- worker method should be marked as `async`.
- all `vim.XXX` method is async; be sure to call them with `await`.
