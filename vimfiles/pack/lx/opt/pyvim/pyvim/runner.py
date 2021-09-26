from pyvim.libvim import Client
from pyvim.worker import Worker


client = Client()
client._loop(Worker)
