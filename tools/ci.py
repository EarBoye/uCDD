#!/usr/bin/env python3
"""The method's checks on GitHub: build every branch head, check new commits.

    ci.py [--branch NAME ...] [--dry-run]

Run by the workflow on fixes (ci/method.yml), on every push and every hour.
For each branch (every branch on origin, or those named) that has
scripts/build.py and is not in [ci] skip_branches:
- the head is built with every variant in [identical] variants, and its
  headroom reported against [ci] limits;
- every commit made after [ci] check_after gets lib/checks.py's checks,
  apart from the ledger, which lives on the bench.
Each result is posted as a commit status (method/build on the head,
method/commits on each commit), and one that has a status already is not
checked again. --dry-run posts nothing and checks everything. A summary goes
to $GITHUB_STEP_SUMMARY when it is set, and to the output.
"""

from pathlib import Path
import argparse
import datetime
import fnmatch
import json
import os
import re
import subprocess
import sys
import tempfile

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / 'lib'))
import checks  # noqa: E402

CONFIG = checks.CONFIG
SIZE = re.compile(r'^(\S+): (\d+) bytes$', re.M)


class Statuses:
    """Commit statuses on GitHub, or nothing at all in a dry run."""

    def __init__(self, repo, dry):
        self.repo, self.dry = repo, dry

    def has(self, sha, context):
        if self.dry:
            return False
        out = subprocess.run(['gh', 'api', f'repos/{self.repo}/commits/{sha}/statuses',
                              '--jq', '.[].context'], capture_output=True, text=True)
        return context in out.stdout.split()

    def post(self, sha, context, ok, description):
        if self.dry:
            return
        subprocess.run(['gh', 'api', '-X', 'POST', f'repos/{self.repo}/statuses/{sha}',
                        '-f', f'state={"success" if ok else "failure"}', '-f', f'context={context}',
                        '-f', f'description={description[:139]}'], capture_output=True, check=True)


def branches(named):
    if named:
        return named
    refs = checks.git('for-each-ref', '--format=%(refname:short)', 'refs/remotes/origin').stdout.split()
    return [ref.removeprefix('origin/') for ref in refs if ref not in ('origin', 'origin/HEAD')]


def resolve(branch):
    for ref in (f'origin/{branch}', branch):
        if checks.ref_exists(ref):
            return checks.git('rev-parse', ref + '^{commit}').stdout.strip()
    return None


def label(options):
    """A short name for a build: p128, verify-mix p128, virtual-ess p32."""
    words = options.split()
    period = words[words.index('--audio-period-frames') + 1] if '--audio-period-frames' in words else ''
    extra = [word.removeprefix('--') for word in words
             if word.startswith('--') and word not in ('--resident-audio', '--audio-period-frames')]
    return ' '.join([*extra, f'p{period}' if period else '']).strip() or options


def build_head(sha):
    """Each variant's result, and the least headroom seen for each limited file, with its build."""
    results, headroom = [], {}
    with tempfile.TemporaryDirectory(prefix='method-ci-') as tmp:
        tree = Path(tmp) / 'tree'
        checks.Target(sha).export(tree)
        for options in CONFIG['identical']['variants']:
            run = subprocess.run([sys.executable, 'scripts/build.py', *options.split()],
                                 cwd=tree, capture_output=True, text=True)
            if run.returncode and 'unrecognized arguments' in run.stderr:
                results.append((options, 'skipped', 'not an option on this branch'))
                continue
            if run.returncode:
                last = (run.stderr.strip().splitlines() or ['no output'])[-1]
                results.append((options, 'failed', last))
                continue
            results.append((options, 'built', ''))
            sizes = {}
            for name, size in SIZE.findall(run.stdout):
                sizes.setdefault(name, int(size))
            for name, limit in CONFIG['ci']['limits'].items():
                if name in sizes and limit - sizes[name] < headroom.get(name, (limit + 1,))[0]:
                    headroom[name] = (limit - sizes[name], label(options))
    return results, headroom


def commits_after(sha, cutoff):
    if not cutoff:
        return []
    since = datetime.datetime.fromisoformat(cutoff)
    if since.tzinfo is None:
        since = since.replace(tzinfo=datetime.timezone.utc)
    found = []
    for line in checks.git('log', '--format=%H %cI', sha).stdout.splitlines():
        commit, date = line.split()
        if datetime.datetime.fromisoformat(date) >= since:
            found.append(commit)
    return list(reversed(found))


def main():
    parser = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    parser.add_argument('--branch', action='append', default=[])
    parser.add_argument('--dry-run', action='store_true')
    parser.add_argument('--repo', default=os.environ.get('GITHUB_REPOSITORY', ''))
    parser.add_argument('--check-after', help='instead of [ci] check_after')
    args = parser.parse_args()
    statuses = Statuses(args.repo, args.dry_run or not args.repo)
    cutoff = args.check_after if args.check_after is not None else CONFIG['ci'].get('check_after', '')
    report, failed = [], False
    for branch in branches(args.branch):
        sha = resolve(branch)
        if (not sha or any(fnmatch.fnmatchcase(branch, pattern) for pattern in CONFIG['ci']['skip_branches'])
                or checks.git('cat-file', '-e', f'{sha}:scripts/build.py', check=False).returncode):
            continue
        line = {'branch': branch, 'head': sha[:7], 'build': 'checked before', 'headroom': '',
                'commits': 'off' if not cutoff else 'none new', 'problems': []}
        if not statuses.has(sha, 'method/build'):
            results, headroom = build_head(sha)
            bad = [f'{options}: {why}' for options, state, why in results if state == 'failed']
            built = sum(state == 'built' for _, state, _ in results)
            free = ', '.join(f'{name} {room} free ({build})' for name, (room, build) in headroom.items())
            line['build'] = f'{built} built' + (f', {len(bad)} failed' if bad else '') + (
                f', {len(results) - built - len(bad)} skipped' if len(results) - built - len(bad) else '')
            line['headroom'] = free
            line['problems'] += bad
            statuses.post(sha, 'method/build', not bad, (bad[0] if bad else f'{built} builds; {free}'))
            failed |= bool(bad)
        checked = bad_commits = 0
        for commit in commits_after(sha, cutoff):
            if statuses.has(commit, 'method/commits'):
                continue
            message = checks.git('log', '-1', '--format=%B', commit).stdout
            problems, _ = checks.check(message, checks.Target(commit), ledger=False)
            checked += 1
            bad_commits += bool(problems)
            line['problems'] += [f'{commit[:7]}: {problem}' for problem in problems]
            statuses.post(commit, 'method/commits', not problems,
                          problems[0] if problems else 'the method\'s checks pass (the ledger is not on GitHub)')
        if checked:
            line['commits'] = f'{checked} checked, {bad_commits} with problems'
        failed |= bool(bad_commits)
        report.append(line)
    summary = ['| Branch | Head | Builds | Headroom | Commits |', '|---|---|---|---|---|']
    summary += [f'| {line["branch"]} | {line["head"]} | {line["build"]} | {line["headroom"]} | '
                f'{line["commits"]} |' for line in report]
    for line in report:
        if line['problems']:
            summary += ['', f'**{line["branch"]}**', ''] + [f'- {problem}' for problem in line['problems']]
    text = '\n'.join(summary) + '\n'
    print(text)
    if os.environ.get('GITHUB_STEP_SUMMARY'):
        with open(os.environ['GITHUB_STEP_SUMMARY'], 'a') as file:
            file.write(text)
    if args.dry_run:
        print(json.dumps({'branches': len(report), 'failed': failed}))
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
