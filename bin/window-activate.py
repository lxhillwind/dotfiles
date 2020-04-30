#!/usr/bin/env python3

# focus on window with rofi. (rofi does not support wayland window yet.)

import sys
import subprocess
import i3ipc

ipc = i3ipc.Connection()


def get_windows():
    for window in ipc.get_tree():
        if window.type not in ['floating_con', 'con']:
            continue
        name = window.app_id or window.window_instance
        yield f'({window.id}) [{window.workspace().name}] {name} - {window.name}'


if len(sys.argv) == 1:
    print('\n'.join(get_windows()))
else:
    con_id = int(sys.argv[1].split(' ')[0].strip('()'))
    subprocess.run(['swaymsg', f'[con_id={con_id}] focus'], capture_output=True)
