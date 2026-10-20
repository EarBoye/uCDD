"""The change loop's checks on a commit, staged (the hook) or made (on GitHub).

A code commit (method.toml, [commit] code) must name its row in an Issue:
trailer, and the row must already be committed (step 5: the row before the
fix). It must carry Evidence: trailers with a grade, one of them the data
sheet (rule 1). A plan named in an emulator line must be in the results
ledger with every run passed on the binaries this commit builds. "Evidence:
none" claims no change in behaviour, and the check proves it by building the
parent and the commit. A commit that changes a join names it in Paths:. A
commit names its sound engine family in Family:, whose library page must
already name the row, and a plan it cites must survey that family.
Notes commits are exempt from those. Every commit is refused banned patterns
in its message and added lines, and game code: a program or driver file, a
disassembly listing, a game named in driver code.
"""

from pathlib import Path
import fnmatch
import hashlib
import re
import shutil
import subprocess
import sys
import tempfile

import methodlib

CONFIG = methodlib.CONFIG
PLAN_TAG = re.compile(r'\bplan ([0-9a-f]{8})\b')
LABEL = re.compile(r'^(\.?[A-Za-z_?][\w.?@$#~]*):')
EMPTY_TREE = '4b825dc642cb6eb9a060e54bf8d69288fbee4904'


def git(*args, input=None, check=True):
    # errors='replace': a diff may hold bytes that are not UTF-8 (DOS text, CP437 art).
    result = subprocess.run(['git', *args], input=input, capture_output=True,
                            encoding='utf-8', errors='replace')
    if check and result.returncode:
        raise SystemExit(f'git {" ".join(args)} failed:\n{result.stderr}')
    return result


def ref_exists(ref):
    return not git('rev-parse', '--verify', '-q', ref + '^{commit}', check=False).returncode


class Target:
    """What the checks read: the staged tree (commit None) or a commit."""

    def __init__(self, commit=None):
        self.commit = commit
        if commit:
            self.parents = git('rev-list', '--parents', '-n', '1', commit).stdout.split()[1:]
            self.date = git('log', '-1', '--format=%cI', commit).stdout.strip()

    def merging(self):
        if self.commit:
            return len(self.parents) > 1
        return Path(git('rev-parse', '--git-path', 'MERGE_HEAD').stdout.strip()).exists()

    def parent(self):
        """The commit this one is compared with, or None for a first commit."""
        if self.commit:
            return self.parents[0] if self.parents else None
        return 'HEAD' if ref_exists('HEAD') else None

    def diff(self, *args):
        base = ['--cached'] if not self.commit else [self.parent() or EMPTY_TREE, self.commit]
        return git('diff', *base, '--no-color', '--no-ext-diff', *args).stdout

    def files(self):
        return [name for name in self.diff('--name-only', '-z').split('\0') if name]

    def blob(self, name):
        shown = subprocess.run(['git', 'cat-file', 'blob', f'{self.commit or ""}:{name}'],
                               capture_output=True)
        return None if shown.returncode else shown.stdout

    def show(self, name):
        shown = git('show', f'{self.commit or ""}:{name}', check=False)
        return None if shown.returncode else shown.stdout

    def export(self, target, parent=False):
        target.mkdir()
        if not parent and not self.commit:
            git('checkout-index', '-a', f'--prefix={target}/')
            return
        archive = subprocess.run(['git', 'archive', self.parent() if parent else self.commit],
                                 capture_output=True, check=True).stdout
        subprocess.run(['tar', '-x', '-C', str(target)], input=archive, check=True)

    def row_refs(self, refs=None):
        """Refs as they stood when the commit was made: the parent for HEAD."""
        found = []
        for ref in CONFIG['rows']['refs'] if refs is None else refs:
            if ref == 'HEAD':
                ref = self.parent()
            elif self.commit and ref_exists(ref):
                ref = git('rev-list', '-1', f'--before={self.date}', ref).stdout.strip() or None
            if ref and ref_exists(ref) and ref not in found:
                found.append(ref)
        return found


def trailers(message):
    parsed = git('interpret-trailers', '--parse', input=message).stdout
    found = []
    for line in parsed.splitlines():
        key, _, value = line.partition(':')
        found.append((key.strip().lower(), value.strip()))
    return found


def grade_of(value):
    head, _, text = value.partition(':')
    word = head.split(',')[0].strip().lower()
    for grade, words in CONFIG['grades'].items():
        if word in words:
            return grade, text.strip()
    return None, value


def added_lines(target):
    """File, line number and text of every line the commit adds."""
    name, number = None, 0
    for line in target.diff('-U0').splitlines():
        if line.startswith('+++ '):
            name = line[6:] if line.startswith('+++ b/') else None
        elif line.startswith('@@'):
            number = int(re.search(r'\+(\d+)', line).group(1))
        elif line.startswith('+') and name:
            yield name, number, line[1:]
            number += 1


def banned_problems(message, target, files_too):
    problems = []
    for rule in CONFIG.get('banned', []):
        pattern = re.compile(rule['pattern'])
        if pattern.search(message):
            problems.append(f'the message has "{pattern.search(message).group(0)}": {rule["why"]}')
        if files_too:
            for name, number, text in added_lines(target):
                match = pattern.search(text)
                if match:
                    problems.append(f'{name}:{number} adds "{match.group(0)}": {rule["why"]}')
    return problems


def changed_lines(target, name):
    """Line numbers in the new file that the commit adds or deletes beside."""
    lines = set()
    for match in re.finditer(r'^@@ -\S+ \+(\d+)(?:,(\d+))? @@', target.diff('-U0', '--', name), re.M):
        start, count = int(match.group(1)), int(match.group(2) or 1)
        lines.update(range(start, start + count) if count else {max(start, 1)})
    return lines


def joins_touched(target, files):
    """The joins whose code or comment the commit changes: file, line, label, comment."""
    marker = re.compile(CONFIG['joins']['marker'])
    found = []
    for name in files:
        if not any(fnmatch.fnmatchcase(name, pattern) for pattern in CONFIG['joins']['files']):
            continue
        shown = target.show(name)
        changed = changed_lines(target, name) if shown is not None else set()
        if not changed:
            continue
        text = shown.splitlines()
        labels = []
        for number, line in enumerate(text, 1):
            match = LABEL.match(line)
            if match:
                top = number
                while top > 1 and text[top - 2].lstrip().startswith(';'):
                    top -= 1
                labels.append((number, top, match.group(1)))
        scope = ''
        for index, (number, top, label) in enumerate(labels):
            scope = scope if label.startswith('.') else label
            full = scope + label if label.startswith('.') else label
            comment = ' '.join(line.strip().lstrip(';').strip() for line in text[top - 1:number - 1])
            end = labels[index + 1][1] - 1 if index + 1 < len(labels) else len(text)
            if marker.search(comment) and changed & set(range(top, end + 1)):
                found.append((name, number, full, comment))
    return found


def named(label, text):
    local = label.rsplit('.', 1)[-1] if '.' in label else label
    return bool(re.search(rf'(?<![\w.])({re.escape(label)}|\.?{re.escape(local)})(?![\w])', text))


def row_committed(row, refs):
    paths = CONFIG['rows']['paths']
    return any(not git('grep', '-q', '-w', '-F', '-e', row, ref, '--', *paths, check=False).returncode
               for ref in refs)


def build(tree, options):
    """Build a tree; the hash of each binary by name, or the exit code of a failed build."""
    shutil.rmtree(tree / 'build', ignore_errors=True)
    result = subprocess.run([sys.executable, 'scripts/build.py', *options.split()],
                            cwd=tree, capture_output=True, text=True)
    if result.returncode:
        return result.returncode
    return methodlib.binaries(tree / 'build')


def listed(names):
    return ', '.join(names[:5]) + (f' and {len(names) - 5} more' if len(names) > 5 else '')


def ledger_problems(target, evidence):
    """A plan named as emulator evidence must have passed, on these binaries."""
    problems, tags = [], []
    for value in evidence:
        grade, text = grade_of(value)
        if grade != 'emulator':
            continue
        found = PLAN_TAG.findall(text)
        if not found and CONFIG['ledger'].get('require'):
            problems.append(f'Evidence: {value}: name the plan the runners recorded ("plan <tag>"); '
                            'emulator evidence comes from the ledger')
        tags += found
    if not tags:
        return problems
    with tempfile.TemporaryDirectory(prefix='method-') as tmp:
        tree = Path(tmp) / 'commit'
        target.export(tree)
        built = {}
        for tag in tags:
            plan = methodlib.saved_plan(tag)
            if not plan:
                problems.append(f'plan {tag} is not in the ledger ({methodlib.ledger_dir()}): '
                                'save it with plan.py --save and let the runners record it')
                continue
            if methodlib.plan_tag(plan['runs']) != tag:
                problems.append(f'plan {tag}: the saved plan no longer matches its tag (edited?)')
                continue
            newest = methodlib.latest(tag)
            missing, failed, unknown, other = [], [], [], []
            for run in plan['runs']:
                entry = newest.get(run['id'])
                if not entry:
                    missing.append(run['id'])
                elif entry['verdict'] != 'pass':
                    failed.append(run['id'])
                elif run['config']['mode'] != 'base':
                    options = run.get('build_options', '')
                    if options not in built:
                        built[options] = build(tree, options)
                    expected = built[options]
                    if not entry.get('binaries'):
                        unknown.append(run['id'])
                    elif isinstance(expected, int) or any(
                            expected.get(name) != digest for name, digest in entry['binaries'].items()):
                        other.append(run['id'])
            for names, what in ((missing, 'have no result'), (failed, 'did not pass'),
                                (unknown, 'recorded no binaries'),
                                (other, 'ran other binaries than this commit builds')):
                if names:
                    problems.append(f'plan {tag}: {len(names)} of {len(plan["runs"])} runs {what}: '
                                    f'{listed(names)}')
    return problems


def identical_problems(target):
    if not target.parent():
        return ['"Evidence: none" needs a parent commit to compare with']
    problems = []
    with tempfile.TemporaryDirectory(prefix='method-') as tmp:
        before, after = Path(tmp) / 'before', Path(tmp) / 'after'
        target.export(before, parent=True)
        target.export(after)
        for options in CONFIG['identical']['variants']:
            old, new = build(before, options), build(after, options)
            if old == new:
                if isinstance(old, int):
                    print(f'"{options}" builds on neither side; skipped', file=sys.stderr)
                continue
            # This machine has had memory faults: a difference counts only
            # if a second pair of builds shows it too.
            again_old, again_new = build(before, options), build(after, options)
            if again_old == again_new:
                print(f'"{options}": the first two builds differed and the second two agree; '
                      'check the machine', file=sys.stderr)
                continue
            if isinstance(again_old, int) or isinstance(again_new, int):
                side = 'the parent' if isinstance(again_old, int) else 'the commit'
                problems.append(f'"{options}" does not build from {side}')
                continue
            changed = sorted(name for name in again_old.keys() | again_new.keys()
                             if again_old.get(name) != again_new.get(name))
            problems.append(f'"{options}" builds different binaries: {", ".join(changed)}')
            break
    if problems:
        problems.append('so this is a change in behaviour: give it its grades, not "none"')
    return problems


def on_page(row, page, refs):
    return any(not git('grep', '-q', '-w', '-F', '-e', row, ref, '--', page, check=False).returncode
               for ref in refs)


def family_problems(target, found, rows, evidence, ledger):
    """Rule 10: the family is named, its page already names the row, a cited plan surveys it."""
    families, library = methodlib.MATRIX.get('families', {}), methodlib.MATRIX.get('library', {})
    values = [value for key, value in found if key == 'family']
    if not values:
        return ['no Family: trailer (rule 10): name the sound engine family whose page notes this '
                f'row ({", ".join(families)}), or "Family: none: <why it is no one family\'s>"']
    problems, named = [], []
    for value in values:
        head, _, text = value.partition(':')
        slugs = [slug.strip().lower() for slug in head.split(',') if slug.strip()]
        if slugs == ['none']:
            if not text.strip():
                problems.append('"Family: none" says why the fault is no one family\'s')
            continue
        for slug in slugs:
            if slug in families:
                named.append(slug)
            else:
                problems.append(f'Family: {slug} is not a family in matrix.toml ({", ".join(families)})')
    refs = target.row_refs(library.get('refs', []))
    for slug in named:
        page = f'{library["dir"]}/{families[slug]["page"]}'
        for row in rows:
            if not on_page(row, page, refs):
                problems.append(f'{row} is not on {page}: write it on the family\'s page first, so '
                                'the whole family knows (rule 10)')
    plans = [methodlib.saved_plan(tag) for value in evidence if grade_of(value)[0] == 'emulator'
             for tag in PLAN_TAG.findall(value)] if ledger else []
    surveyed = {slug for plan in plans if plan for slug in plan.get('families', [])}
    if any(plans):
        for slug in named:
            if slug not in surveyed:
                problems.append(f'no cited plan surveys {slug}: plan.py --family {slug} --save, '
                                'and let the runners record it')
    return problems


def code_problems(message, target, code, ledger):
    found = trailers(message)
    rows = [value for key, value in found if key == 'issue']
    evidence = [value for key, value in found if key == 'evidence']
    paths = ' '.join(value for key, value in found if key == 'paths')
    problems = []
    if not rows:
        problems.append('no Issue: trailer naming the row this change answers')
    refs = target.row_refs()
    for row in rows:
        if not row_committed(row, refs):
            problems.append(f'Issue: {row} is not in a committed row ({", ".join(CONFIG["rows"]["paths"])} '
                            f'at {", ".join(CONFIG["rows"]["refs"])}): commit the row first (step 5)')
    if not evidence:
        problems.append('no Evidence: trailer')
    grades = set()
    for value in evidence:
        grade, text = grade_of(value)
        if not grade:
            problems.append(f'Evidence: {value}: the grade must be one of {", ".join(CONFIG["grades"])}')
        elif not text:
            problems.append(f'Evidence: {value}: say what the {grade} evidence is')
        else:
            grades.add(grade)
    if 'none' in grades:
        if grades != {'none'}:
            problems.append('"Evidence: none" says nothing changed; it cannot stand beside other grades')
        elif not problems:
            problems += identical_problems(target)
    elif grades and CONFIG['commit'].get('require_data_sheet') and 'data sheet' not in grades:
        problems.append('no "Evidence: data sheet:" line (rule 1): cite the document, '
                        'or write "data sheet: silent" and what decided instead')
    if ledger and not problems:
        problems += ledger_problems(target, evidence)
    if 'none' not in grades and CONFIG['commit'].get('require_family'):
        problems += family_problems(target, found, rows, evidence, ledger)
    if 'none' not in grades:
        for name, number, label, comment in joins_touched(target, code):
            if not named(label, paths):
                shown = comment if len(comment) <= 160 else comment[:157] + '...'
                problems.append(f'{name}:{number} changes {label}, a join (lesson L2): check every '
                                f'path into it against its comment, bring the comment up to date, and '
                                f'name it in a "Paths: {label}" trailer. The comment: "{shown}"')
    return problems


def library_page(target, name):
    library = methodlib.MATRIX.get('library', {})
    for ref in target.row_refs(library.get('refs', [])):
        shown = git('show', f'{ref}:{library["dir"]}/{name}', check=False)
        if not shown.returncode:
            return shown.stdout
    return ''


def strings(code):
    """The quoted strings of an assembly line, before its comment."""
    found, quote, start = [], None, 0
    for index, char in enumerate(code):
        if quote:
            if char == quote:
                found.append(code[start:index])
                quote = None
        elif char in '\'"`':
            quote, start = char, index + 1
        elif char == ';':
            break
    return found


def game_code_problems(target):
    """We never ship game code: its files, its listings, or a special case naming a game."""
    games, problems, why = CONFIG['games'], [], 'we never ship game code'
    added = [name for name in target.diff('--name-only', '--diff-filter=AM', '-z').split('\0') if name]
    census = set(re.findall(r'^\| ([0-9a-f]{8}) \|', library_page(target, 'census.md'), re.M))
    for name in added:
        if any(fnmatch.fnmatchcase(name, pattern) for pattern in games['allowed']):
            continue
        if Path(name).suffix.lower() in games['suffixes']:
            problems.append(f'{name}: a program, driver or disc file; {why}')
        elif census and hashlib.md5(target.blob(name) or b'').hexdigest()[:8] in census:
            problems.append(f'{name}: the census knows this file as a game\'s driver; {why}')
    listing, run, last = re.compile(games['listing']), 0, None
    lines = list(added_lines(target))
    for name, number, text in lines:
        run = run + 1 if listing.match(text) and last == (name, number - 1) else int(bool(listing.match(text)))
        last = (name, number)
        if run == games['listing_lines']:
            problems.append(f'{name}:{number}: a disassembly listing; say in words what the code does, '
                            f'{why}')
    inventory = set(re.findall(r'^\| ([A-Z0-9!_-]{5,}) \|', library_page(target, 'inventory.md'), re.M))
    program = re.compile(r'(?<![\w./])[A-Z0-9!_-]{1,8}\.(?:EXE|COM|OVL|DIG|MDI|ADV|DRV|386)(?![\w./])')
    for name, number, text in lines:
        if not any(fnmatch.fnmatchcase(name, pattern) for pattern in games['driver_code']) or any(
                fnmatch.fnmatchcase(name, pattern) for pattern in games['not_driver_code']):
            continue
        for string in strings(text):
            found = {word for word in re.findall(r'[A-Z0-9!_-]{5,}', string) if word in inventory}
            found |= {word for word in program.findall(string.upper()) if word not in games['own_programs']}
            if found:
                problems.append(f'{name}:{number} names {", ".join(sorted(found))} in driver code: a '
                                'special case for one game; the driver answers every game as the '
                                'hardware would (rules 1 and 10)')
    return problems


def check(message, target, ledger=True):
    """The problems with a commit, and the code files it changes."""
    merging = target.merging()
    problems = banned_problems(message, target, files_too=not merging)
    if not merging:
        problems += game_code_problems(target)
    files = [] if merging else target.files()
    code = [name for name in files
            if any(fnmatch.fnmatchcase(name, pattern) for pattern in CONFIG['commit']['code'])]
    if code:
        problems += code_problems(message, target, code, ledger)
    return problems, code
