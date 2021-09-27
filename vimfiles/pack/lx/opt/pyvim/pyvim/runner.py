import pathlib
this_file = pathlib.Path(__file__)

# this is required for win32. but why?
import sys
# str() is required.
sys.path.insert(0, str(this_file.parent.parent))

from pyvim.libvim import Client, vim

if this_file.parent.joinpath('worker.py').exists():
    from pyvim.worker import Worker
else:
    with this_file.parent.joinpath('worker.py.example').open() as f:
        exec(f.read())


client = Client()
vim.register(client)
client._loop(Worker)
