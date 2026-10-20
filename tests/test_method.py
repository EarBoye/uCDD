#!/usr/bin/env python3
"""Self-tests for the hook, the guard and the planner.

    UCDD_REPO=<a uCDD clone> UCDD_REF=irq-counters python3 tests/test_method.py

The hook tests make commits in a temporary worktree of UCDD_REF (default
HEAD) and remove it afterwards; nothing else in the clone changes. Without
UCDD_REPO they use the clone the current directory is in, and are skipped
outside one.
"""

from pathlib import Path
import datetime
import hashlib
import itertools
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest

PACKAGE = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PACKAGE / 'matrix'))
import plan  # noqa: E402

GOOD = """IRQ: a change

Issue: {row}
Evidence: data sheet: SBG 6-12
Evidence: emulator: 86Box, D10, by hand
Family: none: the interrupt path, every engine
"""
LEDGER = tempfile.TemporaryDirectory(prefix='method-ledger-')
os.environ['UCDD_LEDGER'] = LEDGER.name


def repository():
    root = os.environ.get('UCDD_REPO') or subprocess.run(
        ['git', 'rev-parse', '--show-toplevel'], capture_output=True, text=True).stdout.strip()
    if not root or not (Path(root) / '.git').exists():
        return None
    ref = os.environ.get('UCDD_REF', 'HEAD')
    probe = subprocess.run(['git', '-C', root, 'cat-file', '-e', f'{ref}:src/audio/irq.asm'],
                           capture_output=True)
    return (root, ref) if not probe.returncode else None


@unittest.skipUnless(repository(), 'needs a uCDD clone (UCDD_REPO, UCDD_REF)')
class HookTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        root, ref = repository()
        cls.root = root
        cls.tmp = tempfile.TemporaryDirectory(prefix='method-test-')
        cls.tree = Path(cls.tmp.name) / 'tree'
        subprocess.run(['git', '-C', root, 'worktree', 'add', '-q', '--detach', str(cls.tree), ref],
                       check=True)

    @classmethod
    def tearDownClass(cls):
        subprocess.run(['git', '-C', cls.root, 'worktree', 'remove', '--force', str(cls.tree)],
                       check=True)
        cls.tmp.cleanup()

    def setUp(self):
        self.git('reset', '-q', '--hard')
        self.start = self.git('rev-parse', 'HEAD').stdout.strip()

    def tearDown(self):
        self.git('reset', '-q', '--hard', self.start)

    def tool(self, *args):
        return subprocess.run([sys.executable, *map(str, args)], cwd=self.tree,
                              capture_output=True, text=True)

    def build(self, options='--resident-audio --no-refill-hint --audio-period-frames 128'):
        shutil.rmtree(self.tree / 'build', ignore_errors=True)
        subprocess.run([sys.executable, 'scripts/build.py', *options.split()], cwd=self.tree,
                       capture_output=True, check=True)
        return self.tree / 'build'

    def saved_plan(self):
        result = self.tool(PACKAGE / 'matrix/plan.py', '--test', 'SBT16', '--save', '--format', 'json')
        plan = json.loads(result.stdout)
        return plan['tag'], plan['runs'][0]['id']

    def git(self, *args, input=None, check=True):
        return subprocess.run(['git', '-c', f'core.hooksPath={PACKAGE / "hooks"}',
                               '-c', 'user.name=Test', '-c', 'user.email=test@example.com',
                               *args], cwd=self.tree, input=input, capture_output=True,
                              text=True, check=check)

    def commit(self, message):
        self.git('add', '-A')
        return self.git('commit', '-q', '-F', '-', input=message, check=False)

    def append(self, name, text):
        with open(self.tree / name, 'a') as file:
            file.write(text)

    def add_row(self, row):
        self.append('ISSUES.md', f'\n| `{row}` | a test row |\n')
        self.assertEqual(self.commit(f'ISSUES: {row}\n').returncode, 0)

    def test_code_needs_trailers(self):
        self.append('src/audio/irq.asm', '; x\n')
        result = self.commit('IRQ: a change\n')
        self.assertEqual(result.returncode, 1)
        self.assertIn('no Issue: trailer', result.stderr)
        self.assertIn('no Evidence: trailer', result.stderr)

    def test_row_committed_first(self):
        self.add_row('test-row-a')
        self.append('src/audio/irq.asm', '; x\n')
        self.assertEqual(self.commit(GOOD.format(row='test-row-a')).returncode, 0)

    def test_row_in_the_same_commit_is_refused(self):
        self.append('ISSUES.md', '\n| `test-row-b` | a test row |\n')
        self.append('src/audio/irq.asm', '; x\n')
        result = self.commit(GOOD.format(row='test-row-b'))
        self.assertEqual(result.returncode, 1)
        self.assertIn('commit the row first', result.stderr)

    def test_data_sheet_needed(self):
        self.add_row('test-row-c')
        self.append('src/audio/irq.asm', '; x\n')
        result = self.commit('IRQ: x\n\nIssue: test-row-c\nEvidence: emulator: 86Box\n')
        self.assertEqual(result.returncode, 1)
        self.assertIn('data sheet', result.stderr)

    def test_unknown_grade(self):
        self.add_row('test-row-d')
        self.append('src/audio/irq.asm', '; x\n')
        result = self.commit('IRQ: x\n\nIssue: test-row-d\nEvidence: hunch: it felt right\n')
        self.assertEqual(result.returncode, 1)
        self.assertIn('the grade must be one of', result.stderr)

    def test_none_with_a_comment(self):
        self.add_row('test-row-e')
        self.append('src/audio/irq.asm', '; only a comment\n')
        result = self.commit('IRQ: a comment\n\nIssue: test-row-e\nEvidence: none: a comment\n')
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_none_with_code(self):
        self.add_row('test-row-f')
        path = self.tree / 'src/audio/irq.asm'
        text = path.read_text()
        path.write_text(text.replace('\n    ret\n', '\n    nop\n    ret\n', 1))
        result = self.commit('IRQ: sneak\n\nIssue: test-row-f\nEvidence: none: just a nop\n')
        self.assertEqual(result.returncode, 1)
        self.assertIn('builds different binaries', result.stderr)

    def test_none_beside_other_grades(self):
        self.add_row('test-row-g')
        self.append('src/audio/irq.asm', '; x\n')
        result = self.commit('IRQ: x\n\nIssue: test-row-g\nEvidence: none: x\n'
                             'Evidence: data sheet: y\n')
        self.assertEqual(result.returncode, 1)

    def touch_join(self):
        path = self.tree / 'src/audio/sb16.asm'
        lines = path.read_text().splitlines(keepends=True)
        for number, line in enumerate(lines):
            if line.startswith('.acknowledged:'):
                lines.insert(number + 1, '    ; touched\n')
                path.write_text(''.join(lines))
                return
        self.skipTest('no .acknowledged join in sb16.asm at this ref')

    def test_join_needs_paths(self):
        self.add_row('test-row-h')
        self.touch_join()
        result = self.commit(GOOD.format(row='test-row-h'))
        self.assertEqual(result.returncode, 1)
        self.assertIn('audio_irq.acknowledged, a join', result.stderr)

    def test_join_named_in_paths(self):
        self.add_row('test-row-i')
        self.touch_join()
        message = GOOD.format(row='test-row-i') + 'Paths: .acknowledged, all four paths checked\n'
        self.assertEqual(self.commit(message).returncode, 0)

    def test_join_comment_only_with_none(self):
        self.add_row('test-row-j')
        self.touch_join()
        result = self.commit('IRQ: a comment\n\nIssue: test-row-j\nEvidence: none: a comment\n')
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_ledger_pass_on_these_binaries(self):
        self.add_row('test-row-k')
        tag, run = self.saved_plan()
        record = self.tool(PACKAGE / 'tools/ledger.py', 'record', tag, run, 'pass',
                           '--build-dir', self.build())
        self.assertEqual(record.returncode, 0, record.stderr)
        self.append('src/audio/irq.asm', '; a comment only: the binaries stay the same\n')
        message = GOOD.format(row='test-row-k').replace('86Box, D10, by hand', f'plan {tag}, 1 run')
        result = self.commit(message)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_ledger_other_binaries(self):
        self.add_row('test-row-l')
        tag, run = self.saved_plan()
        self.tool(PACKAGE / 'tools/ledger.py', 'record', tag, run, 'pass', '--build-dir', self.build())
        path = self.tree / 'src/audio/irq.asm'
        path.write_text(path.read_text().replace('\n    ret\n', '\n    nop\n    ret\n', 1))
        message = GOOD.format(row='test-row-l').replace('86Box, D10, by hand', f'plan {tag}, 1 run')
        result = self.commit(message)
        self.assertEqual(result.returncode, 1)
        self.assertIn('ran other binaries', result.stderr)

    def test_ledger_failed_run(self):
        self.add_row('test-row-m')
        tag, run = self.saved_plan()
        build = self.build()
        self.tool(PACKAGE / 'tools/ledger.py', 'record', tag, run, 'pass', '--build-dir', build)
        self.tool(PACKAGE / 'tools/ledger.py', 'record', tag, run, 'fail', '--build-dir', build)
        self.append('src/audio/irq.asm', '; x\n')
        message = GOOD.format(row='test-row-m').replace('86Box, D10, by hand', f'plan {tag}, 1 run')
        result = self.commit(message)
        self.assertEqual(result.returncode, 1)
        self.assertIn('did not pass', result.stderr)

    def test_ledger_unknown_plan(self):
        self.add_row('test-row-n')
        self.append('src/audio/irq.asm', '; x\n')
        message = GOOD.format(row='test-row-n').replace('86Box, D10, by hand', 'plan abcdef12, 1 run')
        result = self.commit(message)
        self.assertEqual(result.returncode, 1)
        self.assertIn('not in the ledger', result.stderr)

    def test_ledger_edited_plan(self):
        self.add_row('test-row-o')
        tag, run = self.saved_plan()
        path = Path(LEDGER.name) / 'plans' / f'{tag}.json'
        plan = json.loads(path.read_text())
        plan['runs'][0]['repeat'] = 9
        path.write_text(json.dumps(plan))
        self.append('src/audio/irq.asm', '; x\n')
        message = GOOD.format(row='test-row-o').replace('86Box, D10, by hand', f'plan {tag}, 1 run')
        result = self.commit(message)
        path.unlink()
        self.assertEqual(result.returncode, 1)
        self.assertIn('no longer matches', result.stderr)

    def test_record_needs_a_saved_plan_and_run(self):
        self.assertNotEqual(self.tool(PACKAGE / 'tools/ledger.py', 'record', 'abcdef12', 'x', 'pass',
                                      '--build-dir', '.').returncode, 0)
        tag, _ = self.saved_plan()
        result = self.tool(PACKAGE / 'tools/ledger.py', 'record', tag, f'{tag}-999', 'pass',
                           '--build-dir', '.')
        self.assertIn('has no run', result.stderr)

    def test_upstream_reference_refused(self):
        self.append('ISSUES.md', '\nSee vorvek/uCDD#3 for the original report.\n')
        result = self.commit('ISSUES: a note\n')
        self.assertEqual(result.returncode, 1)
        self.assertIn('upstream author', result.stderr)
        self.git('reset', '-q', '--hard')
        self.append('ISSUES.md', '\nThanks to vorvek for the driver.\n')
        self.assertEqual(self.commit('ISSUES: thanks\n').returncode, 0)

    def since(self):
        moment = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(seconds=2)
        return moment.isoformat(timespec='seconds')

    def test_ci_flags_a_commit_made_without_the_hook(self):
        since = self.since()
        self.append('src/audio/irq.asm', '; x\n')
        self.git('add', '-A')
        subprocess.run(['git', '-c', 'core.hooksPath=/dev/null', '-c', 'user.name=Test',
                        '-c', 'user.email=test@example.com', 'commit', '-q', '-m', 'IRQ: no trailers'],
                       cwd=self.tree, check=True)
        head = self.git('rev-parse', 'HEAD').stdout.strip()
        result = self.tool(PACKAGE / 'tools/ci.py', '--dry-run', '--branch', head, '--check-after', since)
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn('no Issue: trailer', result.stdout)
        self.assertIn('1 checked, 1 with problems', result.stdout)

    def test_ci_passes_the_row_and_its_fix(self):
        since = self.since()
        self.add_row('test-row-p')
        self.append('src/audio/irq.asm', '; x\n')
        self.assertEqual(self.commit(GOOD.format(row='test-row-p')).returncode, 0)
        head = self.git('rev-parse', 'HEAD').stdout.strip()
        result = self.tool(PACKAGE / 'tools/ci.py', '--dry-run', '--branch', head, '--check-after', since)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('2 checked, 0 with problems', result.stdout)
        self.assertIn('UCDDHOST.BIN', result.stdout)

    def test_family_needed(self):
        self.add_row('test-row-q')
        self.append('src/audio/irq.asm', '; x\n')
        message = GOOD.format(row='test-row-q').replace('Family: none: the interrupt path, every engine\n', '')
        result = self.commit(message)
        self.assertEqual(result.returncode, 1)
        self.assertIn('no Family: trailer', result.stderr)

    def family_message(self, row, family='creative'):
        return GOOD.format(row=row).replace('Family: none: the interrupt path, every engine',
                                            f'Family: {family}: its CT-VOICE path')

    def test_family_page_must_name_the_row(self):
        self.add_row('test-row-r')
        self.append('src/audio/irq.asm', '; x\n')
        result = self.commit(self.family_message('test-row-r'))
        self.assertEqual(result.returncode, 1)
        self.assertIn('is not on docs/sound-engines/creative.md', result.stderr)

    def test_family_page_written_first(self):
        self.add_row('test-row-s')
        (self.tree / 'docs/sound-engines').mkdir(parents=True, exist_ok=True)
        self.append('docs/sound-engines/creative.md', '\nSeen on this family: test-row-s.\n')
        self.assertEqual(self.commit('Sound engine library: test-row-s on its family\n').returncode, 0)
        self.append('src/audio/irq.asm', '; x\n')
        result = self.commit(self.family_message('test-row-s'))
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_family_unknown(self):
        self.add_row('test-row-t')
        self.append('src/audio/irq.asm', '; x\n')
        result = self.commit(self.family_message('test-row-t', family='nosuch'))
        self.assertEqual(result.returncode, 1)
        self.assertIn('is not a family', result.stderr)

    def test_family_survey_in_the_cited_plan(self):
        self.add_row('test-row-u')
        (self.tree / 'docs/sound-engines').mkdir(parents=True, exist_ok=True)
        self.append('docs/sound-engines/creative.md', '\nSeen on this family: test-row-u.\n')
        self.commit('Sound engine library: test-row-u on its family\n')
        build = self.build()
        tag, run = self.saved_plan()
        self.tool(PACKAGE / 'tools/ledger.py', 'record', tag, run, 'pass', '--build-dir', build)
        self.append('src/audio/irq.asm', '; a comment only\n')
        message = self.family_message('test-row-u').replace('86Box, D10, by hand', f'plan {tag}, 1 run')
        result = self.commit(message)
        self.assertEqual(result.returncode, 1)
        self.assertIn('no cited plan surveys creative', result.stderr)
        survey = self.tool(PACKAGE / 'matrix/plan.py', '--family', 'creative', '--save', '--format', 'json')
        if survey.returncode:
            self.skipTest('no census on the library refs here')
        plan = json.loads(survey.stdout)
        for each in plan['runs']:
            self.tool(PACKAGE / 'tools/ledger.py', 'record', plan['tag'], each['id'], 'pass',
                      '--build-dir', build)
        message = self.family_message('test-row-u').replace(
            '86Box, D10, by hand', f'plan {tag}, 1 run; plan {plan["tag"]}, the creative survey')
        result = self.commit(message)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_game_file_refused(self):
        (self.tree / 'GAMES/SOUND').mkdir(parents=True)
        (self.tree / 'GAMES/SOUND/SB16.DIG').write_bytes(b'not really a driver')
        result = self.commit('Notes: a driver to study\n')
        self.assertEqual(result.returncode, 1)
        self.assertIn('a program, driver or disc file; we never ship game code', result.stderr)

    def test_listing_refused(self):
        listing = ''.join(f'0000{n:04X}  B8 00 4C  mov ax,0x4c00\n' for n in range(3))
        self.append('ISSUES.md', '\n' + listing)
        result = self.commit('ISSUES: the probe\n')
        self.assertEqual(result.returncode, 1)
        self.assertIn('a disassembly listing', result.stderr)
        self.git('reset', '-q', '--hard')
        self.append('ISSUES.md', '\nThe probe writes D1h, then 40h and the time constant A5h.\n')
        self.assertEqual(self.commit('ISSUES: the probe in words\n').returncode, 0)

    def test_game_named_in_driver_code(self):
        self.add_row('test-row-v')
        self.append('src/audio/irq.asm', "special db 'DOOM.EXE',0\n")
        result = self.commit(GOOD.format(row='test-row-v'))
        self.assertEqual(result.returncode, 1)
        self.assertIn('names DOOM.EXE in driver code', result.stderr)

    def test_game_named_in_a_comment(self):
        self.add_row('test-row-w')
        self.append('src/audio/irq.asm', "; Seen first in DOOM.EXE's DMX path (F4).\n")
        result = self.commit(GOOD.format(row='test-row-w'))
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_notes_are_exempt(self):
        self.append('ISSUES.md', '\nA note from the 86Box run, the original trigger.\n')
        self.assertEqual(self.commit('ISSUES: a note\n').returncode, 0)

    def test_nickname_refused(self):
        word = 'r' + 'ig'
        self.append('ISSUES.md', f'\nA note from the {word} run.\n')
        result = self.commit('ISSUES: a note\n')
        self.assertEqual(result.returncode, 1)
        self.assertIn('ISSUES.md:', result.stderr)
        self.assertEqual(self.commit(f'ISSUES: the {word}86 note\n').returncode, 1)


class GuardTests(unittest.TestCase):
    def guard(self, command=None, tool='Bash', **given):
        call = {'tool_name': tool, 'tool_input': {'command': command} if command else given}
        return subprocess.run([sys.executable, str(PACKAGE / 'guard/guard.py')],
                              input=json.dumps(call), capture_output=True, text=True).returncode

    def test_ledger_refused(self):
        ledger = os.environ['UCDD_LEDGER']
        for command in (f'echo x >> {ledger}/runs.jsonl', 'sed -i 1d ledger/runs.jsonl',
                        'python3 tools/ledger.py record abc12345 abc12345-001 pass --build-dir b',
                        f'rm {ledger}/plans/abc12345.json'):
            self.assertEqual(self.guard(command), 2, command)
        self.assertEqual(self.guard(tool='Write', file_path=f'{ledger}/runs.jsonl', content='x'), 2)
        self.assertEqual(self.guard(tool='Edit', file_path=f'{ledger}/plans/a.json'), 2)
        for command in ('python3 tools/ledger.py show abc12345', 'python3 matrix/plan.py --save',
                        'bash runs/regress.sh src d10 p'):
            self.assertEqual(self.guard(command), 0, command)

    def test_game_library_refused(self):
        with tempfile.TemporaryDirectory() as library:
            game = f'{library}/DOOM'
            os.environ['UCDD_GAMES'] = library
            try:
                for command in (f'sed -i s/a/b/ {game}/DOOM.EXE', f'cp /tmp/x {game}/SB16.DIG',
                                f'echo x > {game}/DEFAULT.CFG', f'dd if=/tmp/x of={game}/DOOM.EXE',
                                f'xxd -r dump {game}/DOOM.EXE', f'rm -rf {game}'):
                    self.assertEqual(self.guard(command), 2, command)
                self.assertEqual(self.guard(tool='Write', file_path=f'{game}/X.EXE', content='x'), 2)
                for command in (f'cp {game}/DOOM.EXE /tmp/study/', f'xxd {game}/DOOM.EXE',
                                f'ndisasm {game}/DOOM.EXE > /tmp/doom.asm',
                                f'python3 runs/game_live.py ID B {library} DOOM sb16'):
                    self.assertEqual(self.guard(command), 0, command)
            finally:
                del os.environ['UCDD_GAMES']

    def test_github_file_tools_refused(self):
        for name in ('push_files', 'create_or_update_file', 'delete_file'):
            self.assertEqual(self.guard(tool=f'mcp__github__{name}', owner='EarBoye', repo='uCDD'), 2)

    def test_upstream_refused(self):
        for command in ('git push https://github.com/vorvek/uCDD fixes',
                        'gh pr create --title x --body y',
                        'gh pr create --repo vorvek/uCDD --title x',
                        'gh issue comment 3 --repo vorvek/uCDD --body hi',
                        'gh api -X POST repos/vorvek/uCDD/issues -f title=x'):
            self.assertEqual(self.guard(command), 2, command)
        self.assertEqual(self.guard(tool='mcp__github__create_pull_request', owner='vorvek',
                                    repo='uCDD', title='x'), 2)
        self.assertEqual(self.guard(tool='mcp__github__add_issue_comment', owner='Vorvek',
                                    repo='uCDD', body='x'), 2)
        for command in ('git push -u origin claude/x', 'gh pr create --repo EarBoye/uCDD --title x',
                        'gh repo view vorvek/uCDD', 'gh api repos/vorvek/uCDD',
                        'git fetch https://github.com/vorvek/uCDD'):
            self.assertEqual(self.guard(command), 0, command)
        self.assertEqual(self.guard(tool='mcp__github__create_pull_request', owner='EarBoye',
                                    repo='uCDD', title='x'), 0)
        self.assertEqual(self.guard(tool='mcp__github__pull_request_read', owner='vorvek',
                                    repo='uCDD'), 0)

    def test_refused(self):
        for command in ('git commit -n -m x', 'git commit -nm x', 'git commit -m x --no-verify',
                        'cd w && git -c core.hooksPath=/dev/null commit -m x',
                        'git config --worktree core.hooksPath /x', 'git merge --no-verify t',
                        'echo; git commit -an', 'A=1 /usr/bin/git commit -n'):
            self.assertEqual(self.guard(command), 2, command)

    def test_allowed(self):
        for command in ('git commit -m x', 'git commit -am "fix -n"', 'git merge -n t',
                        'git log -n 5', 'git config --get core.hooksPath',
                        'git status && git commit -m "a; b -n"', 'python3 x.py --no-verify'):
            self.assertEqual(self.guard(command), 0, command)


class PlannerTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.matrix = plan.load()

    def test_matrix_has_no_problems(self):
        problems, _ = plan.check(self.matrix)
        self.assertEqual(problems, [])

    def test_rows_cover_values_pairs_and_full_axes(self):
        m = self.matrix
        for area in m.areas:
            chosen, *_ = plan.select(m, [], areas=[area['name']])
            for test, why in chosen.items():
                rows, _ = m.rows(test, why['vary'], why['full'])
                fixed_parked = any(m.is_parked(axis, value)
                                   for axis, value in m.tests[test].get('fixed', {}).items())
                for row in rows:
                    self.assertIsNone(m.broken(row), (test, row))
                    if not fixed_parked:
                        self.assertEqual(m.parked_values(row), [], (test, row))
                varied = [axis for axis in m.axes if axis in why['vary']
                          and axis not in m.tests[test].get('fixed', {}) and axis != 'client'
                          and len(m.domain(test, axis)) > 1]
                possible = [m.config(test, dict(zip(varied, values)))
                            for values in itertools.product(*(m.domain(test, axis) for axis in varied))]
                possible = [row for row in possible if not m.broken(row)]
                for a, b in itertools.combinations(varied, 2):
                    wanted = {(row[a], row[b]) for row in possible}
                    got = {(row[a], row[b]) for row in rows}
                    self.assertEqual(wanted, got, (area['name'], test, a, b))
                full = [axis for axis in why['full'] if axis in varied]
                if full:
                    wanted = {tuple(row[axis] for axis in full) for row in possible}
                    got = {tuple(row[axis] for axis in full) for row in rows}
                    self.assertEqual(wanted, got, (area['name'], test, full))

    def test_held_on_unless_asked(self):
        m = self.matrix
        chosen, *_ = plan.select(m, ['src/audio/irq.asm', 'src/audio/trap.asm', 'src/host/dpmi.asm'])
        result = plan.build_plan(m, chosen)
        self.assertTrue(result['runs'])
        self.assertEqual({run['config']['mode'] for run in result['runs']}, {'engaged'})

    def test_baseline_twins(self):
        m = self.matrix
        chosen, *_ = plan.select(m, [], tests=['JILLJUNG'])
        result = plan.build_plan(m, chosen, baseline=True)
        modes = [run['config']['mode'] for run in result['runs']]
        self.assertEqual(modes.count('base'), modes.count('engaged'))
        for run in result['runs']:
            if run['config']['mode'] == 'base':
                self.assertEqual(run['build'], '-')
                self.assertIn(' refs ', run['command'])

    def test_tag_is_stable(self):
        m = self.matrix
        chosen, *_ = plan.select(m, ['src/audio/irq.asm'])
        self.assertEqual(plan.build_plan(m, chosen)['tag'], plan.build_plan(m, chosen)['tag'])

    def test_unmatched_code_gets_the_fallback(self):
        m = self.matrix
        chosen, hit, unmatched, *_ = plan.select(m, ['src/a_new_file.asm'])
        self.assertEqual(unmatched, ['src/a_new_file.asm'])
        self.assertTrue(chosen)

    def library(self):
        try:
            return plan.library_text(self.matrix, 'census.md')
        except SystemExit:
            self.skipTest('no census on the library refs here')

    def test_survey_covers_every_traced_version(self):
        census, m = self.library(), self.matrix
        for slug, family in m.data['families'].items():
            if not family.get('census'):
                continue
            tests, untraced = plan.survey(m, slug)
            versions = plan.census_versions(census, family['census'], family['survey'])
            for driver, version, traced, _ in versions:
                if traced:
                    self.assertTrue(any(f'{game}:{driver}' in tests for game in traced),
                                    (slug, driver, version))
                else:
                    self.assertIn(f'{driver} {version}', [what for what, _ in untraced])

    def test_survey_reaches_games_with_a_built_in_driver(self):
        self.library()
        tests, _ = plan.survey(self.matrix, 'creative')
        self.assertIn('JILLJUNG:creative', tests)

    def test_game_intake(self):
        sys.path.insert(0, str(PACKAGE / 'tools'))
        import game
        census = ('## Miles MSS 3, digital\n\n### SB16.DIG: 2 games\n\n| Version | Games | Traced | Games |\n'
                  '|---|---|---|---|\n| aaaaaaaa | 1 | GAMEA | GAMEA |\n| bbbbbbbb | 1 | **none** | GAMEB |\n')
        index, names = game.census_index(census)
        inventory = game.inventory_index('| GAMEA | Miles MSS 3, DigPak/MidPak | SB | | yes |\n'
                                         '| GAMEC | Brand New SS | SB | | no |\n')
        with tempfile.TemporaryDirectory() as tmp:
            for name, content in (('GAMEA', b'a'), ('GAMEB', b'b'), ('GAMEC', b'c')):
                (Path(tmp) / name).mkdir()
                (Path(tmp) / name / 'SB16.DIG').write_bytes(content)
            first = hashlib.md5(b'a').hexdigest()[:8]
            index[('SB16.DIG', first)] = ('Miles MSS 3, digital', ['GAMEA'])
            lines, missing = game.look(self.matrix, Path(tmp) / 'GAMEA', index, names, inventory, {})
            self.assertFalse(missing, lines)
            self.assertIn('  family: digpak (digpak.md); findings on its page: none', lines)
            self.assertIn('  family: miles (miles.md); findings on its page: none', lines)
            lines, missing = game.look(self.matrix, Path(tmp) / 'GAMEB', index, names, inventory, {})
            self.assertTrue(missing)
            self.assertTrue(any('not in inventory.md' in line for line in lines))
            self.assertTrue(any('NEW version' in line for line in lines))
            lines, missing = game.look(self.matrix, Path(tmp) / 'GAMEC', index, names, inventory, {})
            self.assertTrue(any('has no family' in line for line in lines))

    def test_recordings_after_probes(self):
        m = self.matrix
        chosen, *_ = plan.select(m, ['src/audio/irq.asm'])
        phases = [run['phase'] for run in plan.build_plan(m, chosen)['runs']]
        self.assertEqual(phases, sorted(phases))


if __name__ == '__main__':
    unittest.main()
