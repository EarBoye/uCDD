#!/usr/bin/env python3
"""A Claude Code PreToolUse hook: recall at the moment of change.

Before the first edit of a driver source file in a session (Edit, Write,
MultiEdit on src/*.asm, src/*.inc or scripts/build.py inside a uCDD
worktree), the hook refuses the edit once (exit 2) and prints what the notes
already say about that file and about the ports, DSP commands, labels and
issue IDs in the edited region:

- rows in ISSUES.md and docs/*.md on the refs the method names ([rows].refs
  and [recall].refs in method.toml), and in the worktree's own files;
- FIXED.md, the generated index of every fix already made (tools/fixed.py);
- the lessons register and the handoff log in the top folder (found by
  walking up from the worktree to the directory that holds context/LESSONS.md).

The second edit of the same file in the same session goes through. A new
session, or a compaction that changes the session id, shows the notice
again. This is recall, not evidence: the hook makes the notes arrive when
they apply, so a fix that exists is cited or cherry-picked instead of
rewritten.

Settings: method.toml [recall] (refs, paths, lessons_tags, max_lines).
Markers: $XDG_RUNTIME_DIR or /tmp, ucdd-recall-<uid>/<session>/<file hash>.
"""

from pathlib import Path
import hashlib
import json
import os
import re
import subprocess
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / 'lib'))
import methodlib  # noqa: E402

RECALL = methodlib.CONFIG.get('recall', {})
ROW_REFS = list(methodlib.CONFIG.get('rows', {}).get('refs', [])) + list(RECALL.get('refs', []))
ROW_PATHS = list(RECALL.get('paths', methodlib.CONFIG.get('rows', {}).get('paths', ['ISSUES.md', 'docs/*.md'])))
LESSON_TAGS = list(RECALL.get('lessons_tags', ['code', 'fix']))
MAX_LINES = int(RECALL.get('max_lines', 80))
CODE_GLOBS = tuple(methodlib.CONFIG.get('commit', {}).get('code', ['src/*', 'scripts/build.py']))
SOURCE_SUFFIXES = ('.asm', '.inc')

HEX = re.compile(r'\b(?:0[0-9A-Fa-f]{1,3}h|[0-9A-Fa-f]{2,4}h|0x[0-9A-Fa-f]{2,4})\b')
LABEL = re.compile(r'^\s*([A-Za-z_][A-Za-z0-9_.]{3,}):', re.M)
ISSUE = re.compile(r'\b(?:UPA\d+|[A-Z]{1,4}-?\d{1,3})\b')
HEADER = re.compile(r'^## ')


def git(cwd, *args):
    done = subprocess.run(['git', '-C', str(cwd), *args], capture_output=True, text=True)
    return done.stdout if done.returncode == 0 else ''


def toplevel(path):
    top = git(path.parent, 'rev-parse', '--show-toplevel').strip()
    return Path(top) if top else None


def is_code(top, path):
    import fnmatch
    rel = str(path.resolve().relative_to(top))
    return any(fnmatch.fnmatchcase(rel, glob) for glob in CODE_GLOBS)


def top_folder(start):
    """The folder that holds context/LESSONS.md, walking up from start."""
    for parent in [start, *start.parents]:
        if (parent / 'context' / 'LESSONS.md').exists():
            return parent
    return None


def marker(session, path):
    base = Path(os.environ.get('XDG_RUNTIME_DIR') or '/tmp') / f'ucdd-recall-{os.getuid()}' / (session or 'nosession')
    base.mkdir(parents=True, exist_ok=True)
    return base / hashlib.sha1(str(path.resolve()).encode()).hexdigest()


def edited_text(tool, given):
    if tool == 'Write':
        return '', given.get('content', '')
    if tool == 'MultiEdit':
        olds = '\n'.join(edit.get('old_string', '') for edit in given.get('edits', []))
        news = '\n'.join(edit.get('new_string', '') for edit in given.get('edits', []))
        return olds, news
    return given.get('old_string', ''), given.get('new_string', '')


def terms_for(path, old, new):
    found = [path.name]
    seen = set(found)

    def add(items, cap):
        count = 0
        for item in items:
            if item not in seen and count < cap:
                seen.add(item)
                found.append(item)
                count += 1
    add((m.group(0) for m in HEX.finditer(old + '\n' + new)), 10)
    add((m.group(1) for m in LABEL.finditer(old)), 6)
    add((m.group(0) for m in ISSUE.finditer(old)), 6)
    return found


def existing_refs(top):
    refs = []
    for ref in ROW_REFS:
        if git(top, 'rev-parse', '--verify', '-q', ref).strip():
            refs.append(ref)
    return refs


def grep_rows(top, terms, refs):
    """ref:path:line:text for each row line that names a term, on each ref."""
    lines = []
    args = ['grep', '-n', '-i', '-I']
    for term in terms:
        args += ['-e', term]
    for ref in refs:
        lines += [line for line in git(top, *args, ref, '--', *ROW_PATHS).splitlines() if line.strip()]
    # The working tree's own copies, for uncommitted rows.
    work = git(top, *args, '--', *ROW_PATHS).splitlines()
    lines += [f'worktree:{line}' for line in work if line.strip()]
    return dedupe(lines)


def dedupe(lines):
    seen, kept = set(), []
    for line in lines:
        key = line.split(':', 1)[1] if ':' in line else line
        key = re.sub(r'^[^:]*:\d+:', '', key).strip()
        if key and key not in seen:
            seen.add(key)
            kept.append(line.rstrip())
    return kept


def grep_file(path, terms, headers_only=False, limit=12):
    if not path or not path.exists():
        return []
    text = path.read_text(errors='replace').splitlines()
    pattern = re.compile('|'.join(re.escape(term) for term in terms), re.I)
    if not headers_only:
        return [f'{path.name}:{n}: {line.strip()}' for n, line in enumerate(text, 1) if pattern.search(line)][:limit * 4]
    found, header = [], None
    for line in text:
        if HEADER.match(line):
            header = line.strip()
        elif pattern.search(line) and header and header not in found:
            found.append(header)
    return found[:limit]


def lessons(top_dir):
    script = top_dir / 'context' / 'lessons.py'
    if not script.exists():
        return []
    out = []
    for tag in LESSON_TAGS:
        done = subprocess.run([sys.executable, str(script), tag], cwd=str(top_dir),
                              capture_output=True, text=True)
        if done.returncode == 0:
            out += [line.rstrip() for line in done.stdout.splitlines() if line.strip()][:10]
    return dedupe_plain(out)


def dedupe_plain(lines):
    seen, kept = set(), []
    for line in lines:
        if line not in seen:
            seen.add(line)
            kept.append(line)
    return kept


def fixed_rows(top, top_dir, terms):
    candidates = [top / 'FIXED.md']
    if top_dir:
        candidates += [top_dir / 'context' / 'FIXED.md', top_dir / 'FIXED.md']
    for path in candidates:
        rows = grep_file(path, terms)
        if rows:
            return rows[:12]
    return []


def section(title, lines, budget, hint=''):
    if not lines:
        return [], budget
    out = [title]
    shown = lines[:max(0, min(len(lines), budget - 1))]
    out += ['  ' + line[:160] for line in shown]
    if len(lines) > len(shown):
        out.append(f'  (+{len(lines) - len(shown)} more{": " + hint if hint else ""})')
    return out, budget - len(out)


def notice(path, top, top_dir, terms, session):
    refs = existing_refs(top)
    rows = grep_rows(top, terms, refs)
    fixed = fixed_rows(top, top_dir, terms)
    handoff = grep_file(top_dir / 'context' / 'HANDOFF.md', terms, headers_only=True) if top_dir else []
    register = grep_file(top_dir / 'context' / 'LESSONS.md', terms) if top_dir else []
    checklist = lessons(top_dir) if top_dir else []

    budget = MAX_LINES
    out = [f'Recall before editing {path.name} (once per file per session; make the same edit again to proceed).',
           'Terms: ' + ', '.join(terms),
           f'Refs searched: {", ".join(refs) or "none found"}; worktree files too.']
    budget -= len(out)
    for title, lines, hint in (
            ('Rows already written (ISSUES.md, docs):', rows, 'git grep the terms on the refs above'),
            ('Fixes already made (FIXED.md):', fixed, 'read FIXED.md'),
            ('Handoff entries that name these terms:', handoff, 'context/HANDOFF.md'),
            ('Lessons that name these terms:', register, 'context/LESSONS.md'),
            (f'Checklist (lessons.py {" ".join(LESSON_TAGS)}):', checklist, 'run it')):
        block, budget = section(title, lines, budget, hint)
        out += block
        if budget <= 2:
            break
    if not (rows or fixed or handoff or register):
        out.append('Nothing in the notes names these terms. Write the row first (change loop step 5), then edit.')
    out.append('If a row or fix above covers this change: cite it and work from it. If the fix exists on another '
               'branch: cherry-pick it; a rewrite of an existing fix is a lesson hit.')
    return '\n'.join(out)


def main():
    call = json.load(sys.stdin)
    tool, given = call.get('tool_name', ''), call.get('tool_input', {})
    if tool not in ('Edit', 'Write', 'MultiEdit'):
        return 0
    raw = given.get('file_path') or ''
    if not raw:
        return 0
    path = Path(raw).expanduser()
    if path.suffix.lower() not in SOURCE_SUFFIXES and path.name != 'build.py':
        return 0
    top = toplevel(path)
    if not top or not (top / 'src').is_dir() or not is_code(top, path):
        return 0
    mark = marker(call.get('session_id', ''), path)
    if mark.exists():
        return 0
    old, new = edited_text(tool, given)
    terms = terms_for(path, old, new)
    text = notice(path, top, top_folder(top), terms, call.get('session_id', ''))
    mark.write_text(json.dumps({'terms': terms}))
    print(text, file=sys.stderr)
    return 2


if __name__ == '__main__':
    sys.exit(main())
