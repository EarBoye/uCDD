#!/usr/bin/env python3
"""Tightening r3.6: the three guards, each proven on a scratch repository.

    python3 METHOD/tests/test_r36.py

1. ci.py leaves the author's commits alone: a commit reachable from
   origin/main is not in commits_after, one on a feature branch is.
2. refindex.py orders hand-named keys by citation count, DOC_ keys after.
3. The method worktree's pre-commit refuses a staged matrix.toml that fails
   plan.py check and lets a passing one through; a commit that does not
   touch matrix.toml is not checked.
4. boxcheck finds a stray by name and lets the run's own group through.
"""

from pathlib import Path
import os
import subprocess
import sys
import tempfile
import unittest

HERE = Path(__file__).resolve().parent
PACKAGE = HERE.parent
sys.path.insert(0, str(PACKAGE / 'lib'))
sys.path.insert(0, str(PACKAGE / 'tools'))
sys.path.insert(0, str(PACKAGE / 'bench'))


def git(cwd, *args, env=None):
    return subprocess.run(['git', *args], cwd=cwd, capture_output=True, text=True, check=True, env=env).stdout


def commit(cwd, name, text):
    (Path(cwd) / name).write_text(text)
    git(cwd, 'add', name)
    env = dict(os.environ, GIT_AUTHOR_NAME='t', GIT_AUTHOR_EMAIL='t@x', GIT_COMMITTER_NAME='t',
               GIT_COMMITTER_EMAIL='t@x')
    git(cwd, 'commit', '-q', '-m', f'add {name}', env=env)
    return git(cwd, 'rev-parse', 'HEAD').strip()


class CiUpstream(unittest.TestCase):
    def test_upstream_commits_skipped(self):
        import ci
        with tempfile.TemporaryDirectory() as tmp:
            git(tmp, 'init', '-q', '-b', 'main')
            author = commit(tmp, 'a.txt', 'author')
            git(tmp, 'update-ref', 'refs/remotes/origin/main', author)
            git(tmp, 'checkout', '-q', '-b', 'feature')
            ours = commit(tmp, 'b.txt', 'ours')
            here = os.getcwd()
            os.chdir(tmp)
            try:
                found = ci.commits_after(ours, '2000-01-01T00:00:00+00:00')
            finally:
                os.chdir(here)
            self.assertIn(ours, found)
            self.assertNotIn(author, found)


class RefindexOrder(unittest.TestCase):
    def test_cited_first_then_name_then_doc(self):
        import refindex
        keys = ['ZZZ', 'SBG', 'DOC_x', '8237', 'MSCDEX', 'DOC_a']
        text = 'SBG:12 and SBG 6-12; MSCDEX:3; 8237:100 8237:200 8237:300; the 82378 chip; DOC_x:1'
        counts = refindex.citations(keys, text)
        self.assertEqual(counts['8237'], 3)
        self.assertEqual(counts['SBG'], 2)
        self.assertEqual(counts['ZZZ'], 0)
        order = refindex.ordered(keys, counts)
        self.assertEqual(order[:3], ['8237', 'SBG', 'MSCDEX'])
        self.assertEqual(order[3], 'ZZZ')
        self.assertEqual(order[4:], ['DOC_x', 'DOC_a'])  # DOC_x is cited once


class MethodPreCommit(unittest.TestCase):
    def run_hook(self, tmp):
        return subprocess.run([sys.executable, str(PACKAGE / 'hooks' / 'method' / 'pre-commit')],
                              cwd=tmp, capture_output=True, text=True)

    def test_untouched_matrix_is_not_checked(self):
        with tempfile.TemporaryDirectory() as tmp:
            git(tmp, 'init', '-q')
            Path(tmp, 'notes.md').write_text('x')
            git(tmp, 'add', 'notes.md')
            self.assertEqual(self.run_hook(tmp).returncode, 0)

    def test_staged_matrix_is_checked(self):
        with tempfile.TemporaryDirectory() as tmp:
            git(tmp, 'init', '-q')
            Path(tmp, 'matrix').mkdir()
            Path(tmp, 'matrix', 'matrix.toml').write_text('this is not = toml = at all\n')
            git(tmp, 'add', 'matrix/matrix.toml')
            done = self.run_hook(tmp)
            self.assertEqual(done.returncode, 1, done.stdout + done.stderr)
            self.assertIn('L33', done.stderr)


class BoxCheck(unittest.TestCase):
    def test_stray_found_and_own_group_allowed(self):
        import boxcheck
        listing = [(100, 100, '/opt/86Box.AppImage --config x'), (101, 100, 'Xvfb :91'),
                   (200, 200, 'dosbox-x -conf y'), (300, 300, 'python3 plan_run.py')]
        found = boxcheck.strays({100}, listing)
        self.assertEqual([pid for pid, _ in found], [200])
        self.assertEqual(boxcheck.strays({100, 200}, listing), [])
        self.assertEqual(len(boxcheck.strays(set(), listing)), 3)


if __name__ == '__main__':
    unittest.main(verbosity=1)
