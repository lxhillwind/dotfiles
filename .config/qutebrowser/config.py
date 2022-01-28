# main config in subdir;
# so we can sync modification to sandbox without restart it.
# (by sharing dir)

import pathlib
rc = pathlib.Path(__file__).parent.joinpath('rc/config.py')
with rc.open() as f:
    exec(f.read())
