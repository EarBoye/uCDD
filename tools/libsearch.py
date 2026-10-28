#!/usr/bin/env python3
"""Search the whole reference library before a row says "silent".

    python3 METHOD/tools/libsearch.py TERM [TERM ...] [--all] [--max N] [--searched]

Every text file in the reference worktree ([references].worktree) and the
fork's own specifications on the row refs (docs/*.md) is searched,
case-insensitively, for lines holding any TERM (--all: every TERM on the
line). Hits print as KEY:line: text where the file has a key, else as
path:line: text. At the end, one summary line per document with its count.

--searched prints the line a row carries in place of a search nobody can
check (r3.7):

    searched = "terms: first byte, silent byte, stereo; hits: 14 in 3 documents (SBG 9, ES1868 4, SB202SPEC 1); 28 Oct 2026"

A row whose decides says "silent" must carry that line; plan.py check
refuses one without it once [matrix].searched_required is on. The point is
not the format: it is that "silent" means "searched and not found", never
"I did not need to look". PICHOLD12's D3h sat in two chipset sheets for 29
hours under a silent that was never searched (LIBAUDIT, 28 Oct 2026).
"""

from pathlib import Path
import argparse
import datetime
import re
import subprocess
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / 'lib'))
import methodlib  # noqa: E402
import refcheck  # noqa: E402

TEXT = ('.txt', '.md', '.asm', '.inc', '.h', '.c')
BY_FILE = {v: k for k, v in refcheck.KEYS.items()}
ROW_REFS = list(methodlib.CONFIG.get('rows', {}).get('refs', []))


def library_files(tree):
    for path in sorted(tree.rglob('*')):
        if path.is_file() and path.suffix.lower() in TEXT and '.git' not in path.parts:
            yield path


def key_of(tree, path):
    rel = str(path.relative_to(tree)) if tree in path.parents else str(path)
    return BY_FILE.get(rel, rel)


def search_file(path, terms, need_all, limit):
    pattern = [re.compile(re.escape(t), re.I) for t in terms]
    hits = []
    try:
        with open(path, errors='replace') as file:
            for number, line in enumerate(file, 1):
                found = [bool(p.search(line)) for p in pattern]
                if (all(found) if need_all else any(found)):
                    hits.append((number, line.rstrip()[:140]))
                    if len(hits) >= limit:
                        break
    except OSError:
        pass
    return hits


def row_ref_docs(terms, need_all, limit):
    """docs/*.md on the row refs (the fork's own specifications), via git show."""
    out = {}
    seen = set()
    for ref in ROW_REFS:
        listed = subprocess.run(['git', 'ls-tree', '--name-only', '-r', ref, '--', 'docs'],
                                capture_output=True, text=True)
        for name in listed.stdout.split():
            if not name.endswith('.md') or name in seen:
                continue
            seen.add(name)
            shown = subprocess.run(['git', 'show', f'{ref}:{name}'], capture_output=True, text=True,
                                   errors='replace')
            if shown.returncode:
                continue
            pattern = [re.compile(re.escape(t), re.I) for t in terms]
            hits = []
            for number, line in enumerate(shown.stdout.splitlines(), 1):
                found = [bool(p.search(line)) for p in pattern]
                if (all(found) if need_all else any(found)):
                    hits.append((number, line.rstrip()[:140]))
                    if len(hits) >= limit:
                        break
            if hits:
                out[BY_FILE.get(name, name)] = hits
    return out


def search(terms, need_all=False, limit=20):
    tree = refcheck.worktree()
    results = {}
    if tree and tree.is_dir():
        for path in library_files(tree):
            hits = search_file(path, terms, need_all, limit)
            if hits:
                results[key_of(tree, path)] = hits
    results.update(row_ref_docs(terms, need_all, limit))
    return results


def searched_line(terms, results):
    total = sum(len(h) for h in results.values())
    top = sorted(results.items(), key=lambda kv: (-len(kv[1]), kv[0]))[:6]
    docs = ', '.join(f'{key} {len(hits)}' for key, hits in top)
    today = datetime.date.today().strftime('%-d %b %Y')
    return (f'searched = "terms: {", ".join(terms)}; hits: {total} in {len(results)} documents'
            f'{" (" + docs + ")" if docs else ""}; {today}"')


def main():
    parser = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    parser.add_argument('terms', nargs='+')
    parser.add_argument('--all', action='store_true', help='every term on the line, not any')
    parser.add_argument('--max', type=int, default=20, help='hits per document to print')
    parser.add_argument('--searched', action='store_true', help='print the row line only')
    args = parser.parse_args()
    results = search(args.terms, args.all, args.max)
    if args.searched:
        print(searched_line(args.terms, results))
        return 0
    for key, hits in sorted(results.items(), key=lambda kv: (-len(kv[1]), kv[0])):
        for number, text in hits:
            print(f'{key}:{number}: {text}')
    print()
    if not results:
        print(f'no hits for: {", ".join(args.terms)}')
    else:
        print('; '.join(f'{key} {len(hits)}' for key, hits in sorted(results.items(), key=lambda kv: -len(kv[1]))))
    print(searched_line(args.terms, results))
    return 0


if __name__ == '__main__':
    sys.exit(main())
