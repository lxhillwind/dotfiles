import pathlib
this_file = pathlib.Path(__file__)

# this is required for win32. but why?
import sys
sys.path.insert(0, this_file.parent.parent)

from pyvim.libvim import Client

if this_file.parent.joinpath('worker.py').exists():
    from pyvim.worker import Worker
else:
    with this_file.parent.joinpath('worker.py.example').open() as f:
        exec(f.read())


client = Client()
client._loop(Worker)
