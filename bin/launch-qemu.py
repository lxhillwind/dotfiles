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


def abort(msg):
    print(msg, file=sys.stderr)
    sys.exit(1)


def main():
    if len(sys.argv) < 2:
        abort(f'usage: {sys.argv[0]} <profile> [replace args] [--] [append args]')

    os.chdir(QEMU_IMG_DIR)

    with open('config.yml') as f:
        config = yaml.load(f, Loader=yaml.SafeLoader)

    if sys.argv[1] not in config:
        abort(f'profile not found: {sys.argv[1]}')

    if str(os.environ.get('DEBUG')).lower() in ['1', 'yes', 'on', 'true']:
        action = lambda x: print(f'chdir {shlex.quote(QEMU_IMG_DIR)}\n{shlex.join(x)}')
    else:
        action = lambda x: os.execvp(x[0], x)

    argv = []

    replace_argv = []
    append_argv = []
    double_slash = False
    for i in sys.argv[2:]:
        if i == '--':
            double_slash = True
        else:
            if double_slash:
                append_argv.append(i)
            else:
                replace_argv.append(i)

    overwrite = cmd_group(replace_argv)
    i0_to_idx = {}
    for idx, item in enumerate(overwrite):
        i0_to_idx[item[0]] = idx
    for i in config[sys.argv[1]]:
        ls = shlex.split(i)
        if (idx := i0_to_idx.get(ls[0])) is not None:
            argv.extend(overwrite[idx])
            i0_to_idx.pop(ls[0])
        else:
            argv.extend(ls)

    if unused := i0_to_idx.values():
        abort('ERROR: unused options: %s\nConsider to add them after "--"'
                % [overwrite[i] for i in unused])

    argv.extend(append_argv)

    action(argv)


def cmd_group(ls):
    result = []
    found_option = False
    for i in ls:
        if i.startswith('-'):
            result.append([])
            found_option = True
        if not found_option:
            abort('ERROR: found option value before option flag! "-" is missing?')
        result[-1].append(i)
    return result


if __name__ == '__main__':
    main()
