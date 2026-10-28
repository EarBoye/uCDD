#!/usr/bin/env python3
"""Tightening r3.7: "silent" means searched and not found.

    python3 METHOD/tests/test_r37.py

1. libsearch finds a planted term in a scratch library and names the file
   by its key; the --searched line carries the terms and the hit count.
2. plan.py check warns about a silent row without a searched line (a
   problem once [matrix].searched_required is on, the decides_required
   pattern); a silent row with the line passes; a keyed row needs none.
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

MINIMAL = """
[axes]
build = ["pinC2"]
[defaults]
build = "pinC2"
[runners.probe]
kind = "probe"
[[area]]
name = "all"
paths = ["src/*"]
groups = ["g"]
tests = ["{name}"]
[[test]]
name = "{name}"
decides = "{decides}"
{searched}
runner = "probe"
groups = ["g"]
"""


class LibSearch(unittest.TestCase):
    def test_finds_planted_term_by_key(self):
        import libsearch
        with tempfile.TemporaryDirectory() as tmp:
            tree = Path(tmp)
            (tree / 'Chips').mkdir()
            (tree / 'Chips' / 'kbc.txt').write_text('line one\nD3h Write Mouse Output Buffer\nline three\n')
            old_keys = dict(libsearch.BY_FILE)
            libsearch.BY_FILE.clear()
            libsearch.BY_FILE['Chips/kbc.txt'] = 'KBC'
            try:
                hits = {}
                for path in libsearch.library_files(tree):
                    found = libsearch.search_file(path, ['mouse output'], False, 5)
                    if found:
                        hits[libsearch.key_of(tree, path)] = found
            finally:
                libsearch.BY_FILE.clear()
                libsearch.BY_FILE.update(old_keys)
            self.assertEqual(list(hits), ['KBC'])
            self.assertEqual(hits['KBC'][0][0], 2)
            line = libsearch.searched_line(['mouse output'], hits)
            self.assertIn('terms: mouse output; hits: 1 in 1 documents (KBC 1)', line)


class SilentNeedsSearched(unittest.TestCase):
    def run_check(self, decides, searched=''):
        plan = PACKAGE / 'matrix' / 'plan.py'
        with tempfile.TemporaryDirectory() as tmp:
            matrix = Path(tmp) / 'm.toml'
            matrix.write_text(MINIMAL.format(name='T', decides=decides, searched=searched))
            done = subprocess.run([sys.executable, str(plan), 'check', '--matrix', str(matrix)],
                                  capture_output=True, text=True, cwd=tmp)
            return done.returncode, done.stdout + done.stderr

    def test_silent_without_searched_warns(self):
        code, out = self.run_check('silent: the bench decides')
        self.assertIn('without a "searched" line', out)
        self.assertIn('warning', out)

    def test_silent_with_searched_passes(self):
        code, out = self.run_check('silent: the bench decides',
                                   'searched = "terms: a, b; hits: 0 in 0 documents; 28 Oct 2026"')
        self.assertNotIn('without a "searched" line', out)

    def test_keyed_row_needs_no_searched(self):
        code, out = self.run_check('SBG:1 decides')
        self.assertNotIn('searched', out)


if __name__ == '__main__':
    unittest.main(verbosity=1)
