#!/usr/bin/env python3
"""No other emulator on the box while a plan records (lesson L6, r3.6).

    python3 METHOD/bench/boxcheck.py [--allow PID ...] [--list]

Exits 1 and prints every emulator or display process on the host that does
not belong to this run: 86Box, DOSBox-X, Bochs, QEMU, Xvfb, by command name.
A run's own processes are passed with --allow (each PID and everything in
its process group is allowed). Exit 0 means the box is clear.

The runners call this before every recording and refuse to start on 1; the
stray DOSBox-X of 24 to 26 Oct ran beside two days of captures because
nothing looked. A stray is stopped by Michael, never by the runner.
"""

from pathlib import Path
import argparse
import os
import re
import sys

NAMES = re.compile(r'(86box|dosbox|bochs|qemu-system|xvfb)', re.I)


def processes():
    """(pid, pgid, command line) for every process /proc lists."""
    found = []
    for entry in Path('/proc').iterdir():
        if not entry.name.isdigit():
            continue
        try:
            stat = (entry / 'stat').read_text()
            cmdline = (entry / 'cmdline').read_bytes().replace(b'\0', b' ').decode('utf-8', 'replace').strip()
        except OSError:
            continue
        fields = stat[stat.rindex(')') + 2:].split()
        pgid = int(fields[2])
        found.append((int(entry.name), pgid, cmdline or stat[stat.index('(') + 1:stat.rindex(')')]))
    return found


def strays(allow, listing=None):
    listing = processes() if listing is None else listing
    allowed_pgids = {pgid for pid, pgid, _ in listing if pid in allow}
    out = []
    for pid, pgid, cmd in listing:
        if pid == os.getpid() or pid in allow or pgid in allowed_pgids:
            continue
        if NAMES.search(cmd):
            out.append((pid, cmd))
    return out


def main():
    parser = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    parser.add_argument('--allow', type=int, action='append', default=[], help='a PID of this run')
    parser.add_argument('--list', action='store_true', help='print matches, exit 0 regardless')
    args = parser.parse_args()
    found = strays(set(args.allow))
    for pid, cmd in found:
        print(f'{pid}\t{cmd[:160]}')
    if found and not args.list:
        print(f'boxcheck: {len(found)} emulator or display process(es) not of this run; '
              'nothing records until Michael stops them (kill <pid>)', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
