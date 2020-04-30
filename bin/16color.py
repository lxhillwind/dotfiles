#!/usr/bin/env python3

for idx, name in enumerate(
        ['black', 'red', 'green', 'yellow', 'blue', 'magenta', 'cyan', 'white']
        ):
    print(f'\x1b[{30+idx}m{name}\t\x1b[1mbold\x1b[0m')
