"""What the hook, the planner, the ledger and the guard share."""

from pathlib import Path
import fnmatch
import hashlib
import json
import os
import tomllib

PACKAGE = Path(__file__).resolve().parent.parent
CONFIG = tomllib.loads((PACKAGE / 'method.toml').read_text())
# The bench's own settings, never committed (its paths, its account name as a
# banned word): tables merge into method.toml's, [[banned]] entries add to it.
LOCAL = Path(os.environ.get('UCDD_METHOD_LOCAL') or PACKAGE / 'method.local.toml')
if LOCAL.exists():
    for table, values in tomllib.loads(LOCAL.read_text()).items():
        if isinstance(values, list):
            CONFIG.setdefault(table, []).extend(values)
        else:
            CONFIG.setdefault(table, {}).update(values)
MATRIX = tomllib.loads((PACKAGE / 'matrix' / 'matrix.toml').read_text())


def ledger_dir():
    path = Path(os.environ.get('UCDD_LEDGER') or CONFIG['ledger']['path']).expanduser()
    return path if path.is_absolute() else PACKAGE / path


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def binaries(directory):
    """The hash of each file a build compares, by its path inside the directory."""
    directory = Path(directory)
    return {str(path.relative_to(directory)): sha256(path)
            for path in sorted(directory.rglob('*'))
            if path.is_file() and any(fnmatch.fnmatchcase(path.name, pattern)
                                      for pattern in CONFIG['identical']['compare'])}


def plan_tag(runs):
    """A plan's tag: the hash of its runs, so an edited plan no longer matches."""
    text = json.dumps([(run['test'], run['config'], run['repeat']) for run in runs], sort_keys=True)
    return hashlib.sha256(text.encode()).hexdigest()[:8]


def saved_plan(tag):
    path = ledger_dir() / 'plans' / f'{tag}.json'
    return json.loads(path.read_text()) if path.exists() else None


def save_plan(plan):
    path = ledger_dir() / 'plans' / f'{plan["tag"]}.json'
    path.parent.mkdir(parents=True, exist_ok=True)
    if not path.exists():
        path.write_text(json.dumps(plan, indent=1) + '\n')
    return path


def entries(tag=None):
    path = ledger_dir() / 'runs.jsonl'
    if not path.exists():
        return []
    found = [json.loads(line) for line in path.read_text().splitlines() if line.strip()]
    return [entry for entry in found if tag is None or entry['plan'] == tag]


def is_evidence(entry):
    """A run counts as evidence only with the dynamic recompiler off, recorded as such
    (dynarec False). On (True) or unknown (None) is a comparison. Tightening r3, T2."""
    return entry.get('dynarec') is False


def latest(tag, spot=False):
    """The newest entry for each run of a plan, the originals or the spot checks."""
    newest = {}
    for entry in entries(tag):
        if entry.get('spot', False) == spot:
            newest[entry['run']] = entry
    return newest


def append(entry):
    path = ledger_dir() / 'runs.jsonl'
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, 'a') as file:
        file.write(json.dumps(entry, sort_keys=True) + '\n')
