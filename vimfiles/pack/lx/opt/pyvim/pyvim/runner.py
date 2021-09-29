import os
import pathlib
import traceback
import asyncio
this_file = pathlib.Path(__file__)

# this is required for win32. but why?
import sys
# str() is required.
sys.path.insert(0, str(this_file.parent.parent))

from pyvim.libvim import Client, vim

loaded = True

pyvim_rc = os.getenv('PYVIM_RC')
try:
    if pyvim_rc:
        with pathlib.Path(pyvim_rc).open() as f:
            exec(f.read())
    elif this_file.parent.joinpath('worker.py').exists():
        from pyvim.worker import Worker
    else:
        loaded = False
except:
    print(traceback.format_exc() + '\nload default config instead.',
            file=sys.stderr)
    loaded = False

if not loaded:
    with this_file.parent.joinpath('worker.py.example').open() as f:
        exec(f.read())


client = Client()
vim._register(client)
asyncio.run(client._loop(Worker))
