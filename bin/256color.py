#!/usr/bin/env python3

for i in range(256):
    print(f'\x1b[48;5;{i}m\x1b[38;5;15m {"%03d" % i} ', end='')
    print(f'\x1b[33;5;0m\x1b[38;5;{i}m {"%03d" % i} ', end='')

    if i + 1 <= 16:
        if (i + 1) % 8 == 0:
            print()
        if (i + 1) % 16 == 0:
            print()
    else:
        if (i + 1 - 16) % 6 == 0:
            print()
        if (i + 1 - 16) % 36 == 0:
            print()
