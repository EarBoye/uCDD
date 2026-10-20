#!/usr/bin/env python3
"""Count the Issue:, Lesson: and Evidence: trailers in the history.

    trailers.py [--since DATE] [REF ...]      (default: every branch)

A row that keeps coming back in Issue: trailers is a fault that was not
fixed by family; a lesson that keeps coming back in Lesson: trailers is a
lesson the notes did not stop. Run it from a uCDD worktree; give LESSONS.md
its hits from here instead of counting by hand.
"""

from collections import defaultdict
from pathlib import Path
import argparse
import subprocess
import sys
import tomllib

KEYS = ('issue', 'lesson', 'evidence')
SEPARATOR = '\x1e'
GRADES = tomllib.loads((Path(__file__).resolve().parent.parent / 'method.toml').read_text())['grades']


def grade(value):
    word = value.split(':')[0].split(',')[0].strip().lower()
    return next((name for name, words in GRADES.items() if word in words), word)


def main():
    parser = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    parser.add_argument('refs', nargs='*', help='refs to read (default: --all)')
    parser.add_argument('--since', help='only commits after this date')
    args = parser.parse_args()
    command = ['git', 'log', '--format=%h %as%x00%(trailers:only,unfold)' + SEPARATOR,
               *(['--since', args.since] if args.since else []), *(args.refs or ['--all'])]
    log = subprocess.run(command, capture_output=True, text=True, check=True).stdout
    found = {key: defaultdict(list) for key in KEYS}
    for record in log.split(SEPARATOR):
        if '\0' not in record:
            continue
        commit, text = record.strip().split('\0', 1)
        for line in text.splitlines():
            key, _, value = line.partition(':')
            key, value = key.strip().lower(), value.strip()
            if key == 'evidence':
                value = grade(value)
            if key in found and value:
                found[key][value].append(commit)
    for key in KEYS:
        if not found[key]:
            continue
        print(f'{key.capitalize()}:')
        for value, commits in sorted(found[key].items(), key=lambda item: (-len(item[1]), item[0])):
            dates = sorted({commit.split()[1] for commit in commits})
            print(f'  {value:24} {len(commits):3}  {dates[0]}' + (f' to {dates[-1]}' if len(dates) > 1 else ''))
    return 0


if __name__ == '__main__':
    sys.exit(main())
