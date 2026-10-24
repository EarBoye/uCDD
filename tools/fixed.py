#!/usr/bin/env python3
"""FIXED.md: the index of every fix already made, generated from git.

Every code commit carries an Issue: trailer (the commit-msg hook requires
it), so git already holds the data: which issue each change served, when,
on which branches it lives, with what evidence grades and family. This
tool writes that as one table, newest first, so a fix is found by its
issue, its symptom or its file before it is written again.

    python3 METHOD/tools/fixed.py [--repo DIR] [--out FIXED.md] [--check] [--since DATE]

- Reads every commit on every branch and archive tag (not merges) that
  touches the code paths ([commit].code in method.toml).
- For each Issue ID, finds the row's own line on the row refs ([rows].refs,
  plus [recall].refs) in ISSUES.md and docs/*.md, so the table carries the
  symptom in the row's words, not the commit's.
- Lists the issue IDs no row was found for (consolidation debt), and the
  code commits without an Issue trailer made after the hook was installed
  ([ci].check_after), which should be none. The author's commits (reachable
  from [fixed].upstream_refs, default main) are not ours and are left out.
- --check: exit 1 when either list is non-empty, for the acceptance test.

Never edits anything else. Run it in any uCDD worktree; the output goes to
--out (default FIXED.md in that worktree, where the notes branch keeps it).
"""

from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path
import argparse
import fnmatch
import re
import subprocess
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / 'lib'))
import methodlib  # noqa: E402

CODE = methodlib.CONFIG.get('commit', {}).get('code', ['src/*', 'scripts/build.py'])
SKIP = methodlib.CONFIG.get('commit', {}).get('skip_branches', ['archive/*'])
ROW_REFS = list(methodlib.CONFIG.get('rows', {}).get('refs', [])) + \
    list(methodlib.CONFIG.get('recall', {}).get('refs', []))
ROW_PATHS = list(methodlib.CONFIG.get('rows', {}).get('paths', ['ISSUES.md', 'docs/*.md']))
CHECK_AFTER = methodlib.CONFIG.get('ci', {}).get('check_after', '')
# The author's own commits carry no trailers and are never ours to tag: everything reachable
# from these refs is left out of the untagged list (the fork's main holds his releases only).
UPSTREAM_REFS = list(methodlib.CONFIG.get('fixed', {}).get('upstream_refs', ['main', 'origin/main']))
# Code commits made after check_after without an Issue trailer that Michael has accepted as
# history (pushed, not amendable): listed here by short or full sha, each with a reason comment.
UNTAGGED_ALLOW = [str(s) for s in methodlib.CONFIG.get('fixed', {}).get('untagged_allow', [])]
GRADES = methodlib.CONFIG.get('grades', {})
US, RS = '\x1f', '\x1e'


def git(repo, *args, check=True):
    done = subprocess.run(['git', '-C', str(repo), *args], capture_output=True, text=True)
    if check and done.returncode:
        raise SystemExit(f'git {" ".join(args)}: {done.stderr.strip()}')
    return done.stdout


def refs(repo):
    out = git(repo, 'for-each-ref', '--format=%(refname:short)', 'refs/heads', 'refs/remotes', 'refs/tags')
    found = []
    for name in out.split():
        if name.endswith('/HEAD'):
            continue
        found.append(name)
    return found


def grade_of(value):
    head = re.split(r'[:,]', value, maxsplit=1)[0].strip().lower()
    for grade, words in GRADES.items():
        if head in [word.lower() for word in words]:
            return grade
    return head or '?'


def commits(repo, since):
    fmt = US.join(['%H', '%h', '%cI', '%s', '%(trailers:key=Issue,valueonly,separator=;)',
                   '%(trailers:key=Evidence,valueonly,separator=;)',
                   '%(trailers:key=Family,valueonly,separator=;)']) + RS
    args = ['log', '--all', '--no-merges', f'--format={fmt}']
    for ref in UPSTREAM_REFS:
        if git(repo, 'rev-parse', '--verify', '-q', ref, check=False).strip():
            args.append(f'^{ref}')
    if since:
        args.append(f'--since={since}')
    args += ['--', *CODE]
    found = []
    for record in git(repo, *args).split(RS):
        record = record.strip('\n')
        if not record.strip():
            continue
        sha, short, date, subject, issues, evidence, family = (record.split(US) + [''] * 7)[:7]
        found.append({
            'sha': sha, 'short': short, 'date': date[:10], 'stamp': date, 'subject': subject.strip(),
            'issues': [i.strip() for i in issues.replace('\n', ';').split(';') if i.strip()],
            'grades': sorted({grade_of(e) for e in evidence.replace('\n', ';').split(';') if e.strip()}),
            'family': family.strip().split(':')[0].strip(),
        })
    return found


def branches_of(repo, sha, names):
    out = git(repo, 'branch', '-a', '--contains', sha, '--format=%(refname:short)', check=False)
    out += git(repo, 'tag', '--contains', sha, check=False)
    found = [name.strip() for name in out.split() if name.strip() and not name.endswith('/HEAD')]
    kept = [name for name in found if name in names]
    # Prefer local branch names, then remotes, then tags; drop remote twins.
    local = [n for n in kept if not n.startswith('origin/') and not n.startswith('archive/')]
    remote = [n[len('origin/'):] for n in kept if n.startswith('origin/')]
    tags = [n for n in kept if n.startswith('archive/')]
    merged = list(dict.fromkeys(local + [r for r in remote if r not in local] + tags))
    return merged


def row_line(repo, issue, cache):
    if issue in cache:
        return cache[issue]
    live = [ref for ref in ROW_REFS if git(repo, 'rev-parse', '--verify', '-q', ref, check=False).strip()]
    pattern = rf'(^#+ .*\b{re.escape(issue)}\b|^[-*] .*\*\*{re.escape(issue)}\*\*|^\*\*{re.escape(issue)}\b|^{re.escape(issue)}\b)'
    found = ''
    for ref in live:
        out = git(repo, 'grep', '-h', '-E', '-m', '1', '-e', pattern, ref, '--', *ROW_PATHS, check=False)
        if out.strip():
            found = out.strip().splitlines()[0]
            break
    if not found:
        for ref in live:
            out = git(repo, 'grep', '-h', '-w', '-m', '1', '-e', issue, ref, '--', *ROW_PATHS, check=False)
            if out.strip():
                found = out.strip().splitlines()[0]
                break
    cache[issue] = re.sub(r'\s+', ' ', found)[:140]
    return cache[issue]


def table(repo, found, names):
    by_issue = defaultdict(list)
    orphans, untagged = [], []
    cache = {}
    for commit in found:
        commit['branches'] = branches_of(repo, commit['sha'], names)
        if not commit['issues']:
            allowed = any(commit['sha'].startswith(s) for s in UNTAGGED_ALLOW)
            if CHECK_AFTER and commit['stamp'] >= CHECK_AFTER and not allowed:
                untagged.append(commit)
            continue
        for issue in commit['issues']:
            by_issue[issue].append(commit)
    rows = []
    for issue, cs in by_issue.items():
        line = row_line(repo, issue, cache)
        if not line:
            orphans.append(issue)
        newest = max(cs, key=lambda c: c['stamp'])
        grades = sorted({g for c in cs for g in c['grades']})
        branches = sorted({b for c in cs for b in c['branches']})
        rows.append((newest['stamp'], issue, line, cs, grades, branches))
    rows.sort(reverse=True)
    return rows, orphans, untagged


def render(rows, orphans, untagged, repo_name):
    now = datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%MZ')
    out = ['# Fixes already made', '',
           f'Generated by tools/fixed.py from git on {now} ({repo_name}). Do not edit: regenerate.',
           'One line per issue, newest first: the row in its own words, every code commit that served it, '
           'the branches that carry it, the evidence grades its commits cite, the family. '
           'Before changing driver code, search this file for the symptom, the file, the port or the command.',
           '', '| Issue | Last change | Row | Commits (branch) | Grades | Family |', '|---|---|---|---|---|---|']
    for stamp, issue, line, cs, grades, branches in rows:
        commit_text = '; '.join(f'{c["short"]} {c["subject"][:70]}' for c in sorted(cs, key=lambda c: c['stamp'], reverse=True)[:4])
        if len(cs) > 4:
            commit_text += f'; +{len(cs) - 4} more'
        family = next((c['family'] for c in cs if c['family']), '')
        row = line.replace('|', '\\|') or '(no row found on the row refs)'
        out.append(f'| {issue} | {stamp[:10]} | {row} | {commit_text.replace("|", "/")} | {", ".join(grades)} | {family} |'
                   + (f' branches: {", ".join(branches)}' if False else ''))
    out += ['', '## Where each issue lives', '']
    for stamp, issue, line, cs, grades, branches in rows:
        out.append(f'- {issue}: {", ".join(branches) or "no branch contains it (orphan commit)"}')
    out += ['', '## Issue IDs with no row on the row refs (consolidation debt)', '']
    out += [f'- {issue}' for issue in sorted(orphans)] or ['- none']
    out += ['', f'## Code commits without an Issue trailer after {CHECK_AFTER or "(check_after unset)"}', '']
    out += [f'- {c["short"]} {c["date"]} {c["subject"]}' for c in untagged] or ['- none']
    out.append('')
    return '\n'.join(out)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--repo', default='.')
    parser.add_argument('--out', default=None)
    parser.add_argument('--since', default=None)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    repo = Path(args.repo).resolve()
    top = Path(git(repo, 'rev-parse', '--show-toplevel').strip())
    names = [name for name in refs(top) if not any(fnmatch.fnmatchcase(name, s) for s in SKIP)]
    names += [name for name in refs(top) if name.startswith('archive/')]
    found = commits(top, args.since)
    rows, orphans, untagged = table(top, found, names)
    text = render(rows, orphans, untagged, top.name)
    out = Path(args.out) if args.out else top / 'FIXED.md'
    out.write_text(text)
    print(f'{out}: {len(rows)} issues, {len(found)} code commits, {len(orphans)} without a row, '
          f'{len(untagged)} untagged after check_after')
    if args.check and (orphans or untagged):
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
