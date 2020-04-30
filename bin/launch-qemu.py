#!/usr/bin/env python3

# pass env DEBUG=1 to print generated cmd;
#
# config.yml (contains profiles definition) is put in QEMU_IMG_DIR;
#
# example:
#
# ```yaml
# profile-1:
# - qemu-system-x86_64
# - -nic user
# - -m 1g
# - -hda alpine.qcow2
# profile-2:  # with port forwarding
# - qemu-system-x86_64
# - -nic user,hostfwd=tcp:127.0.0.1:2333-:22
# - -m 1g
# - -hda alpine.qcow2
# ```

import os
import sys
import shlex
import yaml

QEMU_IMG_DIR = os.path.expanduser('~/qemu/')

if len(sys.argv) != 2:
    print(f'usage: {sys.argv[0]} <profile>')
    sys.exit(1)

os.chdir(QEMU_IMG_DIR)

with open('config.yml') as f:
    config = yaml.load(f, Loader=yaml.SafeLoader)

if str(os.environ.get('DEBUG')).lower() in ['1', 'yes', 'on', 'true']:
    action = lambda x: print(f'chdir {shlex.quote(QEMU_IMG_DIR)}\n{shlex.join(x)}')
else:
    action = lambda x: os.execvp(x[0], x)


def flat_cmd(l):
    result = []
    for i in l:
        result.extend(shlex.split(i))
    return result


try:
    action(flat_cmd(config[sys.argv[1]]))
except KeyError as e:
    print(f'profile not found: {e}')
    sys.exit(1)
