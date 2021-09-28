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

## TODO
- async is buggy (vim ex cmd may block, e.g. call `vim.sleep` in worker will
  block subsequent ex cmd)

Currently, the main goal of this plugin is to take advantage of Python's
expressiveness.
