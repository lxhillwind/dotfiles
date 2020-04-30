"""
Usage:
    locate ipython profile dir with:
        ipython locate profile
        # maybe you need to create a default profile first:
        # ipython profile create
    then link this file to the profile's `startup` directory.
"""


from IPython.core.magic import register_line_magic
import os
import subprocess
import tempfile
from urllib.request import urlopen


@register_line_magic
def download_file(url, name=None):
    """if name is not given, then basename of url will be used."""
    if not name:
        name = os.path.basename(url)
    with open(name, 'wb') as f:
        f.write(urlopen(url).read())


@register_line_magic
def vim():
    """edit a temporary file with vim, and then return the file content"""
    result = ''
    with tempfile.NamedTemporaryFile(mode="w+", delete=False) as f:
        f.write('')
        tempname = f.name
    try:
        subprocess.call(['vim', tempname])
        with open(tempname) as f:
            result = f.read()
    finally:
        os.remove(tempname)
    return result
