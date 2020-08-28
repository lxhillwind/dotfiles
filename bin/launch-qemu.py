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


def main():
    if len(sys.argv) < 2:
        print(f'usage: {sys.argv[0]} <profile> [optional args append to qemu host]')
        sys.exit(1)

    os.chdir(QEMU_IMG_DIR)

    with open('config.yml') as f:
        config = yaml.load(f, Loader=yaml.SafeLoader)

    if sys.argv[1] not in config:
        print(f'profile not found: {e}', file=sys.stderr)
        sys.exit(1)

    if str(os.environ.get('DEBUG')).lower() in ['1', 'yes', 'on', 'true']:
        action = lambda x: print(f'chdir {shlex.quote(QEMU_IMG_DIR)}\n{shlex.join(x)}')
    else:
        action = lambda x: os.execvp(x[0], x)

    argv = []
    overwrite = cmd_group(sys.argv[2:])
    i0_to_idx = {}
    for idx, item in enumerate(overwrite):
        i0_to_idx[item[0]] = idx
    for i in config[sys.argv[1]]:
        ls = shlex.split(i)
        if (idx := i0_to_idx.get(ls[0])) is not None:
            argv.extend(overwrite[idx])
        else:
            argv.extend(ls)

    action(argv)


def cmd_group(ls):
    result = []
    for i in ls:
        if i.startswith('-'):
            result.append([])
        result[-1].append(i)
    return result


if __name__ == '__main__':
    main()
