"""Rule 1 at the hook: a data-sheet citation names a document we hold.

An "Evidence: data sheet: ..." trailer must start with a key from
method.toml [references].keys, or with "silent". Each key names a file in
the reference library worktree ([references].worktree, relative to the
method package, or absolute), in the current worktree (the fork's own
docs/*.md specs), or on one of the row refs; it must exist in one of them. A citation that
names nothing we hold is refused: the document was not open when the fix
was written, which is the failure this check exists for.

    Evidence: data sheet: SBG 6-12, a 14h block ends on its last byte   (SBG is a key)
    Evidence: data sheet: silent; 86Box and the CT2290 decide (HWPROBE 19 Oct)

Called from lib/checks.py: `problems += refcheck.problems(message)` beside
the other code-commit checks. Only the data-sheet grade is checked here;
the other grades keep their own rules.
"""

from pathlib import Path
import re
import subprocess
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import methodlib  # noqa: E402

CONFIG = methodlib.CONFIG.get('references', {})
WORKTREE = CONFIG.get('worktree', '')
KEYS = {str(k): str(v) for k, v in CONFIG.get('keys', {}).items()}
SHEET_WORDS = [w.lower() for w in methodlib.CONFIG.get('grades', {}).get('data sheet', ['data sheet'])]
TRAILER = re.compile(r'^Evidence:\s*(.+)$', re.I | re.M)


ROW_REFS = list(methodlib.CONFIG.get('rows', {}).get('refs', [])) + \
    list(methodlib.CONFIG.get('recall', {}).get('refs', []))


def worktree():
    if not WORKTREE:
        return None
    path = Path(WORKTREE).expanduser()
    return path if path.is_absolute() else (methodlib.PACKAGE / path).resolve()


def held(name, tree):
    """The document is in the reference worktree, in the current worktree (the fork's
    own specs under docs/), or on one of the row refs (a spec kept on another branch)."""
    if tree is not None and (tree / name).exists():
        return True
    if (Path.cwd() / name).exists():
        return True
    for ref in ROW_REFS:
        done = subprocess.run(['git', 'cat-file', '-e', f'{ref}:{name}'], capture_output=True)
        if done.returncode == 0:
            return True
    return False


def sheet_citations(message):
    """The text after 'data sheet:' in each Evidence trailer of that grade."""
    found = []
    for match in TRAILER.finditer(message):
        value = match.group(1).strip()
        head, sep, rest = value.partition(':')
        if sep and head.strip().lower() in SHEET_WORDS:
            found.append(rest.strip())
    return found


def problems(message):
    if not KEYS:
        return []
    out = []
    tree = worktree()
    if tree is None or not tree.is_dir():
        return [f'the reference library worktree is missing ({WORKTREE or "[references].worktree unset"}): '
                'add it (git worktree add) before a code commit cites a data sheet']
    for citation in sheet_citations(message):
        first = re.split(r'[\s,;:]', citation, maxsplit=1)[0]
        if first.lower() == 'silent':
            if len(citation.split()) < 3:
                out.append(f'"data sheet: {citation}": silent needs what decided instead (rule 1)')
            continue
        if first not in KEYS:
            out.append(f'"data sheet: {citation}": "{first}" is not a reference key '
                       f'(method.toml [references].keys: {", ".join(sorted(KEYS)) or "none"}); '
                       'cite the document we hold, or say silent and what decided')
            continue
        if not held(KEYS[first], tree):
            out.append(f'"data sheet: {citation}": key {first} names {KEYS[first]}, which is not in {tree}, '
                       'the worktree, or the row refs')
    return out
