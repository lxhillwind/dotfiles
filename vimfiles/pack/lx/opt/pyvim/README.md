## Usage

create file `pyvim/worker.py` (template: [pyvim/worker.py.example](pyvim/worker.py.example)),
and define method here.

Then you can run vim command `:Py3 {method-name}`.

## special method (not passed to python process)

- help: display method `__doc__`.
- restart: restart python process.

## TODO
- async is buggy (vim ex cmd may block, e.g. call `vim.sleep` in worker will
  block subsequent ex cmd)

Currently, the main goal of this plugin is to take advantage of Python's expressiveness.
