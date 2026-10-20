#!/usr/bin/env python3
"""A Claude Code PreToolUse hook: the method's seatbelts.

Refuses, with exit 2 and the reason shown to Claude:
- a git command that skips or moves the hooks: commit -n or --no-verify,
  merge --no-verify, core.hooksPath on the command line or set with config;
- a write to the results ledger other than by a runner: an edit of its
  files, a shell command that names them, or ledger.py record typed by hand;
- anything that reaches the upstream author: a push to his repository, a
  pull request, issue or comment there (gh or the GitHub tools), and a gh
  pr create that does not name the fork.
A person who needs the escape types the command in their own shell.
"""

from pathlib import Path
import json
import shlex
import subprocess
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / 'lib'))
import methodlib  # noqa: E402

WHY = 'Refused by the method guard: {what}. {advice}'
HOOKS = ('Commits go through the commit-msg hook. If the hook is wrong, say so and fix '
         'the hook, or ask Michael to make the commit in his own shell.')
LEDGER = ('Only the runners write the ledger, after a run is judged. Read it with '
          'ledger.py show, spot or audit.')
UPSTREAM = ('Nothing from this fork goes to the upstream author (Michael, 20 Oct 2026). '
            'Pull requests, if any, go to {fork} only.')
# git commit's short options that take a value: the rest of the cluster is
# that value, so an "n" after one of them is not --no-verify.
COMMIT_VALUE_OPTIONS = set('mFCctSu')
GH_WRITES = {'create', 'comment', 'edit', 'close', 'reopen', 'merge', 'review', 'ready',
             'lock', 'unlock', 'delete', 'transfer', 'pin', 'develop'}
READ_PREFIXES = ('get_', 'list_', 'search_')
OWNER = methodlib.CONFIG['upstream']['owner'].lower()
FORK = methodlib.CONFIG['upstream']['fork']


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


def upstream_remote(name, cwd):
    if OWNER in name.lower():
        return True
    url = subprocess.run(['git', 'remote', 'get-url', name], cwd=cwd or None,
                         capture_output=True, text=True).stdout
    return OWNER in url.lower()


def git_refusal(args, cwd):
    while args and args[0].startswith('-'):
        option = args.pop(0)
        value = option.split('=', 1)[1] if '=' in option else (
            args.pop(0) if option in ('-c', '-C', '--git-dir', '--work-tree') and args else '')
        if option.startswith('-c') and value.lower().startswith('core.hookspath'):
            return 'core.hooksPath set on the command line', HOOKS
        if option == '-C':
            cwd = value
    if not args:
        return None
    command, rest = args[0], args[1:]
    reading = {'--get', '--get-all', '--get-regexp', '-l', '--list', 'get', 'list'}
    if (command == 'config' and any(word.lower() == 'core.hookspath' for word in rest)
            and not reading & set(rest)):
        return 'a change to core.hooksPath', HOOKS
    if command in ('commit', 'merge', 'pull', 'cherry-pick', 'revert', 'am') and '--no-verify' in rest:
        return f'git {command} --no-verify', HOOKS
    if command == 'commit':
        for word in rest:
            if word == '--':
                break
            if word.startswith('-') and not word.startswith('--'):
                for char in word[1:]:
                    if char == 'n':
                        return 'git commit -n (--no-verify)', HOOKS
                    if char in COMMIT_VALUE_OPTIONS:
                        break
    if command == 'push':
        targets = [word for word in rest if not word.startswith('-')]
        if targets and upstream_remote(targets[0], cwd):
            return f'a push to {targets[0]}, the upstream repository', UPSTREAM
    return None


def gh_refusal(args):
    named_fork = any(FORK.lower() == word.lower() for word in args)
    upstream = any(OWNER in word.lower() for word in args)
    if args[:2] == ['pr', 'create'] and not named_fork:
        return 'gh pr create without --repo ' + FORK + ' (in a fork gh may pick the upstream)', UPSTREAM
    if upstream and len(args) > 1 and args[0] in ('pr', 'issue', 'release', 'repo') and args[1] in GH_WRITES:
        return f'gh {args[0]} {args[1]} on the upstream repository', UPSTREAM
    if upstream and args[:1] == ['api'] and any(
            word in ('-f', '-F', '--field', '--raw-field', '--input') or
            (word in ('-X', '--method') and index + 1 < len(args) and args[index + 1].upper() != 'GET')
            for index, word in enumerate(args)):
        return 'a gh api write to the upstream repository', UPSTREAM
    return None


def names_ledger(words):
    ledger = methodlib.ledger_dir()
    marks = (str(ledger), 'runs.jsonl', f'{ledger.name}/plans')
    return any(mark in word for word in words for mark in marks)


def bash_refusal(line, cwd):
    for words in commands(line):
        while words and '=' in words[0] and not words[0].startswith('-'):
            words = words[1:]
        if not words:
            continue
        program = words[0].split('/')[-1]
        if program == 'git':
            found = git_refusal(words[1:], cwd)
        elif program == 'gh':
            found = gh_refusal(words[1:])
        elif any(word.endswith('ledger.py') for word in words) and 'record' in words:
            found = 'ledger.py record typed by hand', LEDGER
        elif names_ledger(words) and not any(word.endswith(('ledger.py', 'plan.py')) for word in words):
            found = 'a shell command on the ledger files', LEDGER
        else:
            found = None
        if found:
            return found
    return None


def refusal(call):
    tool, given = call.get('tool_name', ''), call.get('tool_input', {})
    if tool == 'Bash':
        try:
            return bash_refusal(given.get('command', ''), call.get('cwd'))
        except ValueError:
            return None
    if tool in ('Write', 'Edit', 'MultiEdit', 'NotebookEdit'):
        path = given.get('file_path') or given.get('notebook_path') or ''
        if path and Path(path).resolve().is_relative_to(methodlib.ledger_dir().resolve()):
            return f'an edit of {path}', LEDGER
    name = tool.split('__')[-1]
    if tool.startswith('mcp__github__') and not (name.startswith(READ_PREFIXES) or name.endswith('_read')):
        if OWNER in str(given.get('owner', '')).lower() or OWNER in str(given.get('repo', '')).lower():
            return f'{name} on the upstream repository', UPSTREAM
    return None


def main():
    found = refusal(json.load(sys.stdin))
    if not found:
        return 0
    what, advice = found
    print(WHY.format(what=what, advice=advice.format(fork=FORK)), file=sys.stderr)
    return 2


if __name__ == '__main__':
    sys.exit(main())
