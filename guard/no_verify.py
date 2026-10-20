#!/usr/bin/env python3
"""A Claude Code PreToolUse hook for Bash: commits go through the hooks.

Refuses a git command that would skip or move them: commit with -n or
--no-verify, merge with --no-verify, and core.hooksPath set on the command
line or with git config. Exit 2 refuses the call and shows Claude why. A
person who needs the escape types the command in their own shell.
"""

import json
import shlex
import sys

WHY = ('Refused by the change-loop guard: {what}. Commits go through the '
       'commit-msg hook. If the hook is wrong, say so and fix the hook, or ask '
       'Michael to make the commit in his own shell.')
# git commit's short options that take a value: the rest of the cluster is
# that value, so an "n" after one of them is not --no-verify.
COMMIT_VALUE_OPTIONS = set('mFCctSu')


def commands(line):
    """The words of each simple command in a shell line."""
    lexer = shlex.shlex(line, posix=True, punctuation_chars=';&|()')
    lexer.whitespace_split = True
    words = []
    for token in lexer:
        if token and all(char in ';&|()' for char in token):
            if words:
                yield words
            words = []
        else:
            words.append(token)
    if words:
        yield words


def refusal(words):
    while words and '=' in words[0] and not words[0].startswith('-'):
        words = words[1:]
    if not words or words[0].split('/')[-1] != 'git':
        return None
    args = words[1:]
    while args and args[0].startswith('-'):
        option = args.pop(0)
        value = option.split('=', 1)[1] if '=' in option else (
            args.pop(0) if option in ('-c', '-C', '--git-dir', '--work-tree') and args else '')
        if option.startswith('-c') and value.lower().startswith('core.hookspath'):
            return 'core.hooksPath set on the command line'
    if not args:
        return None
    command, rest = args[0], args[1:]
    reading = {'--get', '--get-all', '--get-regexp', '-l', '--list', 'get', 'list'}
    if (command == 'config' and any(word.lower() == 'core.hookspath' for word in rest)
            and not reading & set(rest)):
        return 'a change to core.hooksPath'
    if command in ('commit', 'merge', 'pull', 'cherry-pick', 'revert', 'am') and '--no-verify' in rest:
        return f'git {command} --no-verify'
    if command == 'commit':
        for word in rest:
            if word == '--':
                break
            if word.startswith('-') and not word.startswith('--'):
                for char in word[1:]:
                    if char == 'n':
                        return 'git commit -n (--no-verify)'
                    if char in COMMIT_VALUE_OPTIONS:
                        break
    return None


def main():
    call = json.load(sys.stdin)
    line = call.get('tool_input', {}).get('command', '')
    try:
        found = [refusal(words) for words in commands(line)]
    except ValueError:
        return 0
    for what in found:
        if what:
            print(WHY.format(what=what), file=sys.stderr)
            return 2
    return 0


if __name__ == '__main__':
    sys.exit(main())
