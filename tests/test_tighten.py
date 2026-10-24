#!/usr/bin/env python3
"""Self-tests for the tightening tools: recall.py, fixed.py, refcheck.py,
session-recall.sh. Builds a throwaway top folder and uCDD worktree that
mimic the real layout, then drives each tool the way Claude Code would.

    python3 METHOD/tests/test_tighten.py

Exit 0 when every check passes. Needs git and python3 only.
"""

from pathlib import Path
import json
import os
import shutil
import subprocess
import sys
import tempfile

METHOD = Path(__file__).resolve().parent.parent
PY = sys.executable
FAILS = []


def check(cond, what):
    print(('ok   ' if cond else 'FAIL ') + what)
    if not cond:
        FAILS.append(what)


def git(repo, *args, env=None):
    base = {'GIT_AUTHOR_NAME': 't', 'GIT_AUTHOR_EMAIL': 't@t', 'GIT_COMMITTER_NAME': 't',
            'GIT_COMMITTER_EMAIL': 't@t', 'GIT_AUTHOR_DATE': '2026-10-23T10:00:00+11:00',
            'GIT_COMMITTER_DATE': '2026-10-23T10:00:00+11:00', **os.environ, **(env or {})}
    done = subprocess.run(['git', '-C', str(repo), *args], capture_output=True, text=True, env=base)
    if done.returncode:
        raise SystemExit(f'git {args}: {done.stderr}')
    return done.stdout


def commit(repo, message, env=None):
    git(repo, 'add', '-A')
    git(repo, 'commit', '-q', '-m', message, env=env)
    return git(repo, 'rev-parse', '--short', 'HEAD').strip()


def build_world(root):
    top = root / 'Claude'
    (top / 'context').mkdir(parents=True)
    (top / 'ledger').mkdir()
    (top / 'context' / 'LESSONS.md').write_text(
        '# Lessons\n\n- L2 (18): Code on a shared path keeps what every path into it carries.\n'
        '- L7 (18): A driver test must engage the driver.\n- L30 (4): trap.asm port 22Ch reads must see the busy bit.\n')
    (top / 'context' / 'HANDOFF.md').write_text(
        '# Handoff log\n\n## 23 Oct 2026: the busy bit on 22Ch (F13)\n- trap.asm: the DSP busy bit read\n\n'
        '## 22 Oct 2026: bench rebuilt\n- nothing about ports\n')
    (top / 'context' / 'lessons.py').write_text(
        'import sys\nprint("L2 (18): shared path keeps what every path carries [" + sys.argv[1] + "]")\n')
    # a uCDD worktree with code, rows, trailers, a notes branch and a refs worktree
    wt = top / 'rig86' / 'runs' / 'src' / 'cpos'
    (wt / 'src' / 'audio').mkdir(parents=True)
    (wt / 'docs').mkdir()
    git(wt, 'init', '-q', '-b', 'main')
    (wt / 'src' / 'audio' / 'trap.asm').write_text('sb_dsp_write:\n    out dx, al   ; 22Ch\n    ret\n')
    (wt / 'README.md').write_text('upstream\n')
    commit(wt, 'Prepare Beta 0.9.4-a6 (the author, no trailers)')
    git(wt, 'checkout', '-q', '-b', 'count-position')
    (wt / 'ISSUES.md').write_text('# Issues\n\n- **F13** The DSP busy bit on 22Ch: the CT2290 is busy in 46% of idle reads.\n'
                                  '- **F14** Stray EOI marks: Mortal Kombat Trilogy at speed 2.38.\n')
    (wt / 'docs' / 'vsb-spec.md').write_text('# vsb spec\n\n## 7.8 the count\nUPA6 is the merge row.\n')
    commit(wt, 'ISSUES: F13 and F14, the rows before the fixes')
    (wt / 'src' / 'audio' / 'trap.asm').write_text('sb_dsp_write:\n    out dx, al   ; 22Ch, busy bit honoured\n    ret\n')
    commit(wt, 'Driver: the busy bit on 22Ch reads\n\nIssue: F13\nEvidence: data sheet: SBG 3-4, the busy bit\n'
               'Evidence: emulator: plan 7ed5820d, 12 runs, all passed (ledger)\nFamily: creative: CT-VOICE')
    git(wt, 'branch', 'notes')
    (wt / 'src' / 'audio' / 'irq.asm').write_text('; eoi path\n')
    untagged = commit(wt, 'Driver: an untagged code commit (must be listed)',
                      env={'GIT_AUTHOR_DATE': '2026-10-24T10:00:00+11:00', 'GIT_COMMITTER_DATE': '2026-10-24T10:00:00+11:00'})
    # the reference library, as a sibling worktree
    refs = top / 'rig86' / 'runs' / 'src' / 'refs'
    (refs / 'creative').mkdir(parents=True)
    (refs / 'creative' / 'sbg.txt').write_text('Sound Blaster Hardware Programming Guide\n')
    return top, wt, refs, untagged


def install_method(root, refs):
    """A copy of the method package pointing its reference worktree at the test's refs."""
    pkg = root / 'method'
    shutil.copytree(METHOD, pkg, ignore=shutil.ignore_patterns('tests', '__pycache__'))
    (pkg / 'matrix').mkdir(exist_ok=True)
    if not (pkg / 'matrix' / 'matrix.toml').exists():
        (pkg / 'matrix' / 'matrix.toml').write_text('[families]\ncreative = "docs/sound-engines/creative.md"\n')
    toml = (pkg / 'method.toml').read_text()
    toml = toml.replace('worktree = "../refs"', f'worktree = "{refs}"')
    toml = toml.replace('[references.keys]\n', '[references.keys]\nSBG = "creative/sbg.txt"\nMISSING = "creative/none.txt"\n')
    (pkg / 'method.toml').write_text(toml)
    return pkg


def run_hook(pkg, name, payload, env):
    done = subprocess.run([PY, str(pkg / 'guard' / name)], input=json.dumps(payload),
                          capture_output=True, text=True, env={**os.environ, **env})
    return done.returncode, done.stdout, done.stderr


def main():
    root = Path(tempfile.mkdtemp(prefix='tighten-'))
    try:
        top, wt, refs, untagged = build_world(root)
        pkg = install_method(root, refs)
        env = {'XDG_RUNTIME_DIR': str(root / 'run'), 'UCDD_METHOD_LOCAL': str(root / 'none.toml')}
        (root / 'run').mkdir()

        # --- recall.py ---
        edit = {'session_id': 'sess-1', 'hook_event_name': 'PreToolUse', 'tool_name': 'Edit',
                'cwd': str(wt), 'tool_input': {'file_path': str(wt / 'src' / 'audio' / 'trap.asm'),
                                               'old_string': 'sb_dsp_write:\n    out dx, al   ; 22Ch',
                                               'new_string': 'sb_dsp_write:\n    out dx, al   ; 22Ch, 2E6h'}}
        code, out, err = run_hook(pkg, 'recall.py', edit, env)
        check(code == 2, 'recall: first edit of a src file is refused once (exit 2)')
        check('F13' in err and '22Ch' in err, 'recall: the F13 row naming 22Ch is shown')
        check('sb_dsp_write' in err, 'recall: the label under edit is a search term')
        check('23 Oct 2026: the busy bit' in err, 'recall: the HANDOFF entry header that names the terms is shown')
        check('L30' in err, 'recall: the LESSONS line naming the file is shown')
        check('shared path' in err, 'recall: lessons.py checklist output is included')
        code2, _, err2 = run_hook(pkg, 'recall.py', edit, env)
        check(code2 == 0 and not err2, 'recall: the same edit in the same session goes through')
        edit_other = dict(edit, session_id='sess-2')
        code3, _, _ = run_hook(pkg, 'recall.py', edit_other, env)
        check(code3 == 2, 'recall: a new session (or compaction) shows the notice again')
        notes = dict(edit, tool_input={'file_path': str(wt / 'ISSUES.md'), 'old_string': 'a', 'new_string': 'b'})
        code4, _, _ = run_hook(pkg, 'recall.py', notes, env)
        check(code4 == 0, 'recall: a notes file is never refused')
        outside = dict(edit, session_id='sess-3', tool_input={'file_path': str(root / 'elsewhere.asm'), 'old_string': '', 'new_string': 'x'})
        code5, _, _ = run_hook(pkg, 'recall.py', outside, env)
        check(code5 == 0, 'recall: an .asm outside a uCDD worktree is never refused')

        # --- fixed.py ---
        out_md = root / 'FIXED.md'
        done = subprocess.run([PY, str(pkg / 'tools' / 'fixed.py'), '--repo', str(wt), '--out', str(out_md), '--check'],
                              capture_output=True, text=True, env={**os.environ, **env})
        text = out_md.read_text() if out_md.exists() else ''
        check(out_md.exists(), 'fixed: FIXED.md is written')
        check('| F13 |' in text and 'busy bit' in text, 'fixed: the F13 row appears with the row text from ISSUES.md')
        check('count-position' in text and 'notes' in text, 'fixed: the branches carrying the fix are listed')
        check('data sheet' in text and 'emulator' in text, 'fixed: the evidence grades are listed')
        check(untagged in text and done.returncode == 1, 'fixed: --check fails and names the untagged code commit after check_after')
        check('Prepare Beta' not in text, "fixed: the author's own commits on main are never listed as untagged")
        # tag the untagged one and the check passes
        git(wt, 'commit', '-q', '--amend', '-m', 'Driver: the EOI path\n\nIssue: F14\nEvidence: reading\nFamily: none: the host')
        done = subprocess.run([PY, str(pkg / 'tools' / 'fixed.py'), '--repo', str(wt), '--out', str(out_md), '--check'],
                              capture_output=True, text=True, env={**os.environ, **env})
        check(done.returncode == 0, 'fixed: --check passes once every code commit has an Issue with a row')

        # --- refcheck.py ---
        sys.path.insert(0, str(pkg / 'lib'))
        os.environ.update(env)
        import importlib
        import methodlib  # noqa: F401
        importlib.reload(methodlib)
        import refcheck
        importlib.reload(refcheck)
        ok = refcheck.problems('Fix\n\nIssue: F13\nEvidence: data sheet: SBG 3-4, the busy bit\n')
        check(ok == [], 'refcheck: a citation with a known key and an existing file passes')
        bad = refcheck.problems('Fix\n\nIssue: F13\nEvidence: data sheet: BOGUS 1-2, something\n')
        check(bad and 'not a reference key' in bad[0], 'refcheck: an unknown key is refused')
        missing = refcheck.problems('Fix\n\nIssue: F13\nEvidence: data sheet: MISSING 1, x\n')
        check(missing and 'not in' in missing[0], 'refcheck: a key whose file is absent is refused')
        silent_ok = refcheck.problems('Fix\n\nEvidence: data sheet: silent; the CT2290 decides (HWPROBE 19 Oct)\n')
        check(silent_ok == [], 'refcheck: silent with what decided passes')
        silent_bad = refcheck.problems('Fix\n\nEvidence: data sheet: silent\n')
        check(silent_bad and 'what decided' in silent_bad[0], 'refcheck: a bare silent is refused')
        other = refcheck.problems('Fix\n\nEvidence: emulator: plan 1234abcd\nEvidence: hardware: the PC\n')
        check(other == [], 'refcheck: other grades are not its business')

        # --- session-recall.sh ---
        (top / 'context' / 'STATE.md').write_text('# State\n\n## Open faults\n- F2 the count steps back\n\n## Questions for Michael\n1. the gauntlet\n\n## Where things live\n- x\n')
        shutil.copy(out_md, top / 'context' / 'FIXED.md')
        done = subprocess.run(['bash', str(pkg / 'hooks' / 'session-recall.sh')], capture_output=True, text=True,
                              env={**os.environ, 'CLAUDE_PROJECT_DIR': str(wt)})
        check(done.returncode == 0, 'session-recall: exits 0')
        check('Ledger: EMPTY' in done.stdout, 'session-recall: says the ledger is empty when it is')
        check('F2 the count steps back' in done.stdout and 'the gauntlet' in done.stdout,
              'session-recall: prints the open faults and the questions')
        check('| F13 |' in done.stdout, 'session-recall: prints the fixes index rows')
    finally:
        shutil.rmtree(root, ignore_errors=True)
    print(f'\n{len(FAILS)} failures' if FAILS else '\nall passed')
    return 1 if FAILS else 0


if __name__ == '__main__':
    sys.exit(main())
