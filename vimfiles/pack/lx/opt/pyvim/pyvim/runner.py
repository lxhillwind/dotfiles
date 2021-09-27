# this is required for win32. but why?
import sys
from os.path import dirname
sys.path.insert(0, dirname(dirname(__file__)))

from pyvim.libvim import Client
from pyvim.worker import Worker


client = Client()
client._loop(Worker)
