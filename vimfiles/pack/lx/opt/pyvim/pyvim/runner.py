import os
import pathlib
import asyncio
this_file = pathlib.Path(__file__)

# this is required for win32. but why?
import sys
# str() is required.
sys.path.insert(0, str(this_file.parent.parent))

from pyvim.libvim import Client, vim

pyvim_rc = os.getenv('PYVIM_RC')
if pyvim_rc:
    with pathlib.Path(pyvim_rc).open() as f:
        exec(f.read())
elif this_file.parent.joinpath('worker.py').exists():
    from pyvim.worker import Worker
else:
    with this_file.parent.joinpath('worker.py.example').open() as f:
        exec(f.read())


client = Client()
vim._register(client)
asyncio.run(client._loop(Worker))
