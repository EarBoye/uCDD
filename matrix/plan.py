#!/usr/bin/env python3
"""Turn a change into the matrix runs it needs.

    plan.py [plan] [--base REF | --files F ...] [--area A] [--group G]
                   [--test T] [--family F [--driver FILE]] [--baseline]
                   [--save] [--format md|tsv|json]
    plan.py check

A plan takes the changed files to their areas in matrix.toml, the areas to
their tests, and each test to the configurations it runs in: every value
of a varied axis, every pair of values across two varied axes, and every
combination of an area's "full" axes. Run it from the uCDD worktree.

Other programs read the matrix through load():

    sys.path.insert(0, '<this directory>')
    import plan
    matrix = plan.load()
    for name in matrix.group('families'): ...
"""

from pathlib import Path
import argparse
import fnmatch
import itertools
import json
import re
import subprocess
import sys
import tomllib

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / 'lib'))
import methodlib  # noqa: E402
PHASES = {'probe': 1, 'recording': 2, 'hardware': 3}
PHASE_TITLES = {
    1: 'probes, up to {parallel} at a time',
    2: 'recordings, one at a time with nothing else running (L6)',
    3: 'hardware, on the PC',
}
PRODUCT_LIMIT = 5000


def load(path=None):
    return Matrix(tomllib.loads(Path(path or HERE / 'matrix.toml').read_text()))


def matches(when, config):
    return all(config.get(axis) in values for axis, values in when.items())


class Matrix:
    def __init__(self, data):
        self.data = data
        self.axes = data['axes']
        self.parked = data.get('parked', {})
        self.opt_in = data.get('opt_in', {})
        self.defaults = data['defaults']
        self.tests = {test['name']: test for test in data.get('test', [])}
        self.areas = data.get('area', [])
        self.runners = data.get('runner', {})

    def group(self, name):
        """The tests in a group, in file order; "findings" holds every test with findings."""
        return [test for test, entry in self.tests.items()
                if name in entry.get('groups', []) or (name == 'findings' and entry.get('findings'))]

    def kind(self, test):
        return self.runners[self.tests[test]['runner']]['kind']

    def is_parked(self, axis, value):
        return value in self.parked.get(axis, [])

    def domain(self, test, axis):
        """The values a test may be varied over on an axis."""
        entry = self.tests[test]
        values = [value for value in self.axes[axis] if not self.is_parked(axis, value)]
        allowed = entry.get('allow', {}).get(axis)
        if allowed is not None:
            return [value for value in values if value in allowed]
        return [value for value in values if value not in self.opt_in.get(axis, [])]

    def config(self, test, chosen=None):
        """The whole configuration: chosen values, then the test's own, then defaults."""
        entry = self.tests[test]
        config = dict(chosen or {})
        config.update(entry.get('fixed', {}))
        if 'client' in entry:
            config['client'] = entry['client']
        for rule in self.data.get('default', []):
            if matches(rule['when'], {**self.defaults, **config}):
                for axis, value in rule['set'].items():
                    config.setdefault(axis, value)
        for axis, value in self.defaults.items():
            config.setdefault(axis, value)
        return {axis: config[axis] for axis in self.axes}

    def broken(self, config):
        """Why a configuration cannot exist, or None."""
        for rule in self.data.get('constraint', []):
            if matches(rule['when'], config):
                for axis, values in rule['need'].items():
                    if config[axis] not in values:
                        return rule['why']
        return None

    def parked_values(self, config):
        return [f'{axis} {value}' for axis, value in config.items() if self.is_parked(axis, value)]

    def env(self, test, config):
        parts = []
        for axis, table in self.data.get('env', {}).items():
            value = config[axis]
            text = table.get(str(value), table.get('*', '').replace('{}', str(value)))
            if text:
                parts.append(text)
        if self.tests[test].get('env'):
            parts.append(self.tests[test]['env'])
        return ' '.join(parts)

    def command(self, run):
        entry = self.tests[run['test']]
        fields = {**run['config'], 'id': run['id'], 'tag': run['tag'], 'test': run['test'],
                  'env': run['env'], 'game': entry.get('game', run['test']),
                  'library': entry.get('library', '')}
        for axis, words in self.data.get('words', {}).items():
            fields[f'{axis}_word'] = words.get(str(run['config'][axis]), run['config'][axis])
        fields['build'] = run['build']
        # the build's directory as bset.sh names it ($UCDD_TREE and
        # $UCDD_SUFFIX are the caller's: the worktree and bset's suffix)
        fields['build_dir'] = '-' if run['build'] == '-' else \
            self.data.get('build_dirs', {}).get(run['build'], run['build'])
        # a test's own arguments for its runner (SBT16's case list)
        fields['args'] = entry.get('args', '')
        runner = self.runners[entry['runner']]
        template = runner['command']
        if run['config']['mode'] == 'base':
            template = runner.get('base_command', template)
        return template.format_map(Missing(fields)).strip()

    def rows(self, test, vary=(), full=()):
        """The configurations a test runs in, or (rows, reason) when there are none."""
        entry = self.tests[test]
        fixed = set(entry.get('fixed', {})) | {'client'}
        defaults = self.config(test)
        axes = []
        for axis in self.axes:
            if axis in fixed:
                continue
            domain = self.domain(test, axis)
            if axis in vary or defaults[axis] not in domain:
                axes.append(axis)
        domains = {axis: self.domain(test, axis) for axis in axes}
        size = 1
        for axis in axes:
            size *= max(len(domains[axis]), 1)
        if size > PRODUCT_LIMIT:
            raise SystemExit(f'{test}: {size} combinations of {", ".join(axes)}; narrow the area')
        candidates, reasons = [], set()
        for values in itertools.product(*(domains[axis] for axis in axes)):
            chosen = dict(zip(axes, values))
            config = self.config(test, chosen)
            reason = self.broken(config)
            if reason:
                reasons.add(reason)
            else:
                candidates.append((chosen, config))
        if not candidates:
            return [], '; '.join(sorted(reasons)) or 'an axis it needs has no usable value'
        varied = [axis for axis in axes if len(domains[axis]) > 1]
        full = [axis for axis in full if axis in varied]

        def elements(chosen):
            found = {(axis, chosen[axis]) for axis in varied}
            found |= {(a, chosen[a], b, chosen[b]) for a, b in itertools.combinations(varied, 2)}
            if len(full) > 2:
                found.add(tuple(chosen[axis] for axis in full))
            return found

        if not varied:
            return [candidates[0][1]], None
        uncovered = set().union(*(elements(chosen) for chosen, _ in candidates))
        picked = []
        while uncovered:
            best = max(range(len(candidates)),
                       key=lambda i: (len(elements(candidates[i][0]) & uncovered), -i))
            picked.append(candidates[best][1])
            uncovered -= elements(candidates[best][0])
        return picked, None


class Missing(dict):
    def __missing__(self, key):
        return '{' + key + '}'


def git(*args):
    result = subprocess.run(['git', *args], capture_output=True, text=True)
    if result.returncode:
        raise SystemExit(f'git {" ".join(args)}: {result.stderr.strip()}')
    return result.stdout


def changed_files(base):
    files = set(git('diff', '--name-only', base).split())
    # new files not yet added count only when they are code: bset.sh leaves
    # its build directories and logs untracked in the worktree
    files |= {name for name in git('ls-files', '--others', '--exclude-standard').split() if is_code(name)}
    return sorted(files)


def is_code(name):
    return name.startswith('src/') or name == 'scripts/build.py'


def select(matrix, files, areas=(), groups=(), tests=()):
    """Tests to run and why, the axes to vary, and what to report."""
    chosen, hit, unmatched, cover, todo = {}, {}, [], set(), []
    known = {
        'area': {area['name'] for area in matrix.areas},
        'group': {group for entry in matrix.tests.values() for group in entry.get('groups', [])}
                 | {'findings'},
    }
    for kind, names in (('area', areas), ('group', groups)):
        for name in names:
            if name not in known[kind]:
                raise SystemExit(f'no {kind} "{name}" in the matrix: {", ".join(sorted(known[kind]))}')

    def take(test, why, vary=(), full=()):
        entry = chosen.setdefault(test, {'why': [], 'vary': set(), 'full': set()})
        if why not in entry['why']:
            entry['why'].append(why)
        entry['vary'] |= set(vary)
        entry['full'] |= set(full)

    def take_area(area, why):
        cover.update(area.get('cover', []))
        if area.get('todo'):
            todo.append(f'area "{area["name"]}": {area["todo"]}')
        for group in area.get('groups', []):
            for test in matrix.group(group):
                take(test, why, area.get('vary', []), area.get('full', []))
        for test in area.get('tests', []):
            take(test, why, area.get('vary', []), area.get('full', []))

    for name in files:
        found = [area for area in matrix.areas
                 if any(fnmatch.fnmatchcase(name, pattern) for pattern in area['paths'])]
        for area in found:
            hit.setdefault(area['name'], []).append(name)
        if not found and is_code(name):
            unmatched.append(name)
    for area in matrix.areas:
        if area['name'] in hit or area['name'] in areas:
            take_area(area, area['name'])
    if unmatched:
        take_area({'name': 'fallback', **matrix.data.get('fallback', {})}, 'no area')
    for group in groups:
        for test in matrix.group(group):
            take(test, f'group {group}')
    for test in tests:
        if test not in matrix.tests:
            raise SystemExit(f'no test "{test}" in the matrix')
        take(test, 'asked for')
    if hit or unmatched or areas:
        for test in matrix.group('core'):
            take(test, 'core')
    return chosen, hit, unmatched, cover, todo


def library_text(matrix, name):
    """A page of the sound engine library, from the first library ref that has it."""
    library = matrix.data['library']
    for ref in library['refs']:
        shown = subprocess.run(['git', 'show', f'{ref}:{library["dir"]}/{name}'],
                               capture_output=True, text=True)
        if not shown.returncode:
            return shown.stdout
    raise SystemExit(f'{library["dir"]}/{name} is on none of {", ".join(library["refs"])}: '
                     'fetch the library branch')


def census_versions(text, sections, files):
    """(file, version, traced games, carriers) for each driver version in the sections."""
    found, section, driver = [], None, None
    for line in text.splitlines():
        if line.startswith('## '):
            section = line[3:].strip()
        elif line.startswith('### '):
            driver = line[4:].split(':')[0].strip()
        elif line.startswith('| ') and section in sections and driver in files:
            cells = [cell.strip() for cell in line.strip().strip('|').split('|')]
            if len(cells) == 4 and re.fullmatch(r'[0-9a-f]{8}', cells[0]):
                traced = [] if 'none' in cells[2] else [game.strip() for game in cells[2].split(',')]
                found.append((driver, cells[0], traced, cells[3]))
    return found


def census_text(text, sections, files):
    """The census's text under the family's sections and the given files."""
    kept, section, driver = [], None, None
    for line in text.splitlines():
        if line.startswith('## '):
            section, driver = line[3:].strip(), None
        elif line.startswith('### '):
            driver = line[4:].split(':')[0].strip()
        if section in sections and driver in files:
            kept.append(line)
    return '\n'.join(kept)


def inventory_games(text, names):
    """The traced games whose engine is one of the names."""
    games = []
    for line in text.splitlines():
        cells = [cell.strip() for cell in line.strip().strip('|').split('|')]
        if len(cells) >= 5 and re.fullmatch(r'[A-Z0-9!_-]+', cells[0]):
            engines = {engine.replace('(on its disc)', '').strip() for engine in cells[1].split(',')}
            if engines & set(names) and cells[4].startswith('yes'):
                games.append(cells[0])
    return games


def survey(matrix, slug, drivers=()):
    """Tests for a family survey (rule 10), and the driver versions nothing can run yet.

    A family with driver files gets the fewest traced games that cover every
    traced version of its survey files, each run as its driver's card, and
    every traced game of its engine the census does not name (its driver is
    built into the game). An engine built into every game gets every traced
    game. A census row names the games traced on a version, so a game listed
    on two versions of one file is taken to cover both; the census shortens
    long game lists, so a game it names only past "and N more" is surveyed
    again from the inventory.
    """
    families = matrix.data.get('families', {})
    if slug not in families:
        raise SystemExit(f'no family "{slug}" in the matrix: {", ".join(families)}')
    family, chosen, untraced = families[slug], [], []
    if family.get('census'):
        census, files = library_text(matrix, 'census.md'), drivers or family.get('survey', [])
        versions = census_versions(census, family['census'], files)
        untraced = [(f'{driver} {version}', f'no traced game; carried by {carriers}')
                    for driver, version, traced, carriers in versions if not traced]
        uncovered = {(driver, version) for driver, version, traced, _ in versions if traced}
        while uncovered:
            reach = {}
            for driver, version, traced, _ in versions:
                if (driver, version) in uncovered:
                    for game in traced:
                        reach.setdefault((game, driver), set()).add((driver, version))
            pick = max(sorted(reach), key=lambda key: len(reach[key]))
            uncovered -= reach[pick]
            chosen.append(pick)
        named = set(re.findall(r'[A-Z0-9!_-]{3,}', census_text(census, family['census'], files)))
    else:
        named = set()
    if not drivers:
        chosen += [(game, None) for game in inventory_games(library_text(matrix, 'inventory.md'),
                                                          family.get('inventory', []))
                   if game not in named]
    launchers = matrix.data.get('launchers', {})
    tests = {}
    for game, driver in chosen:
        tests[f'{game}:{driver or slug}'] = {
            'name': f'{game}:{driver or slug}', 'runner': 'game', 'game': launchers.get(game, game),
            'family': slug, 'groups': ['survey'], 'secs': 90,
            'fixed': dict(matrix.data.get('census_files', {}).get(driver, {})),
        }
    return tests, untraced


def build_plan(matrix, chosen, baseline=False):
    runs, blocked, skipped = [], [], []
    for test, why in chosen.items():
        entry = matrix.tests[test]
        rows, reason = matrix.rows(test, why['vary'], why['full'])
        parked = sorted({value for row in rows for value in matrix.parked_values(row)})
        if not rows or parked:
            skipped.append((test, reason or 'parked: ' + ', '.join(parked)))
            continue
        if entry.get('todo'):
            blocked.append((test, entry['todo'], rows, entry.get('repeat', 1)))
            continue
        configs = list(rows)
        if baseline:
            for row in rows:
                twin = dict(row, mode='base')
                if twin not in configs and not matrix.broken(twin):
                    configs.append(twin)
        for config in configs:
            for repeat in range(entry.get('repeat', 1)):
                runs.append({'test': test, 'config': config, 'repeat': repeat + 1,
                             'kind': matrix.kind(test), 'why': why['why'],
                             'secs': entry.get('secs', 60)})
    runs.sort(key=lambda run: (PHASES[run['kind']], list(matrix.tests).index(run['test'])))
    tag = methodlib.plan_tag(runs)
    for number, run in enumerate(runs, 1):
        run['phase'] = PHASES[run['kind']]
        run['id'] = f'{tag}-{number:03d}'
        run['tag'] = tag
        run['env'] = matrix.env(run['test'], run['config'])
        run['build'] = '-' if run['config']['mode'] == 'base' else run['config']['build']
        run['build_options'] = matrix.data.get('builds', {}).get(run['config']['build'], '')
        run['command'] = matrix.command(run)
    return {'tag': tag, 'runs': runs, 'blocked': blocked, 'skipped': skipped}


def minutes(runs, parallel):
    probes = sum(run['secs'] for run in runs if run['kind'] == 'probe')
    serial = sum(run['secs'] for run in runs if run['kind'] != 'probe')
    return round((probes / max(parallel, 1) + serial) / 60)


def coverage(matrix, runs, cover):
    seen = {axis: [] for axis in matrix.axes}
    for run in runs:
        for axis, value in run['config'].items():
            if value not in seen[axis]:
                seen[axis].append(value)
    gaps = []
    for axis in sorted(cover):
        wanted = [value for value in matrix.axes[axis] if not matrix.is_parked(axis, value)]
        missing = [str(value) for value in wanted if value not in seen[axis]]
        if missing:
            gaps.append(f'{axis}: no run covers {", ".join(missing)}')
    return seen, gaps


def show_markdown(matrix, plan, files, base, hit, unmatched, cover, todo):
    runs = plan['runs']
    parallel = matrix.data.get('run', {}).get('probe_parallel', 1)
    axes = list(matrix.axes)
    out = [f'# Test plan {plan["tag"]}', '']
    if files:
        shown = ', '.join(files[:6]) + (', ...' if len(files) > 6 else '')
        count = f'{len(files)} file' + ('s' if len(files) > 1 else '')
        out.append(f'Change: {count} {base} ({shown})')
    for area, names in hit.items():
        out.append(f'Area {area}: {", ".join(names)}')
    if unmatched:
        out.append(f'No area (fallback groups): {", ".join(unmatched)}')
    counts = {kind: sum(run['kind'] == kind for run in runs) for kind in PHASES}
    out += ['', f'Runs: {len(runs)} ({counts["probe"]} probes, {counts["recording"]} recordings, '
            f'{counts["hardware"]} on the PC), about {minutes(runs, parallel)} min', '']
    for phase in sorted(set(PHASES.values())):
        rows = [run for run in runs if run['phase'] == phase]
        if not rows:
            continue
        out += [f'## Phase {phase}: {PHASE_TITLES[phase].format(parallel=parallel)}', '',
                '| Run | Test | ' + ' | '.join(axes) + ' | Why |',
                '|---|---|' + '---|' * len(axes) + '---|']
        for run in rows:
            name = run['test'] + (f' #{run["repeat"]}' if matrix.tests[run['test']].get('repeat', 1) > 1 else '')
            shown = dict(run['config'], build=run['build'])
            out.append(f'| {run["id"]} | {name} | '
                       + ' | '.join(str(shown[axis]) for axis in axes)
                       + f' | {", ".join(run["why"])} |')
        out.append('')
    if plan['blocked'] or plan.get('untraced'):
        out += ['## Blocked: needed, but not runnable yet', '']
        for test, reason, rows, repeat in plan['blocked']:
            findings = matrix.tests[test].get('findings')
            note = f' ({", ".join(findings)})' if findings else ''
            out.append(f'- {test}{note}: {reason}; would run {len(rows) * repeat} times')
        for what, why in plan.get('untraced', []):
            out.append(f'- driver {what}: {why}; trace one of them before the family is covered')
        out.append('')
    seen, gaps = coverage(matrix, runs, cover)
    out += ['## Coverage', '']
    out += [f'- {axis}: {", ".join(map(str, values)) or "-"}' for axis, values in seen.items()]
    warnings = gaps + todo + [f'{test} skipped: {reason}' for test, reason in plan['skipped']]
    if warnings:
        out += ['', '## Warnings', ''] + [f'- {warning}' for warning in warnings]
    out += ['', 'Save it (--save) before running it. Once the runners have recorded every run as a',
            f'pass (ledger.py show {plan["tag"]}), the commit can carry:', '',
            f'    Evidence: emulator: plan {plan["tag"]}, {len(runs)} runs, <after> against <before>: <result>']
    return '\n'.join(out)


def show_tsv(plan):
    out = ['run\tphase\tkind\ttest\tbuild\tenv\tcommand']
    for run in plan['runs']:
        out.append('\t'.join([run['id'], str(run['phase']), run['kind'], run['test'],
                              run['build'], run['env'], run['command']]))
    return '\n'.join(out)


def check(matrix):
    """Problems with the file, and warnings about the worktree it is run in."""
    problems, warnings = [], []
    axes = matrix.axes

    def values_ok(where, table, single):
        for axis, value in table.items():
            if axis not in axes:
                problems.append(f'{where}: no axis "{axis}"')
                continue
            for item in ([value] if single else value):
                if item not in axes[axis]:
                    problems.append(f'{where}: {axis} has no value {item!r}')

    for section in ('parked', 'opt_in'):
        values_ok(section, matrix.data.get(section, {}), single=False)
    values_ok('defaults', matrix.defaults, single=True)
    for axis in axes:
        if axis not in matrix.defaults:
            problems.append(f'defaults: no value for {axis}')
        elif matrix.is_parked(axis, matrix.defaults[axis]):
            problems.append(f'defaults: {axis} {matrix.defaults[axis]} is parked')
    for number, rule in enumerate(matrix.data.get('default', []), 1):
        values_ok(f'default {number} when', rule['when'], single=False)
        values_ok(f'default {number} set', rule['set'], single=True)
    for number, rule in enumerate(matrix.data.get('constraint', []), 1):
        values_ok(f'constraint {number} when', rule['when'], single=False)
        values_ok(f'constraint {number} need', rule['need'], single=False)
    for axis, table in matrix.data.get('env', {}).items():
        if axis not in axes:
            problems.append(f'env: no axis "{axis}"')
    groups = {group for area in matrix.areas for group in area.get('groups', [])}
    groups |= {'core', 'findings', *matrix.data.get('run', {}).get('optional_groups', [])}
    # r3.5: every test names the document that decides its expected result ("decides"),
    # a key from method.toml [references.keys], or "silent: <what decides instead>".
    # Rows written before r3.5 are reported as warnings until [matrix].decides_required
    # is set, then as problems.
    import tomllib as _toml
    _method = _toml.loads((Path(__file__).resolve().parent.parent / 'method.toml').read_text())
    _keys = set(_method.get('references', {}).get('keys', {}))
    _required = bool(_method.get('matrix', {}).get('decides_required', False))
    for name, entry in matrix.tests.items():
        decides = entry.get('decides')
        if not decides:
            (problems if _required else warnings).append(
                f'test {name}: no "decides" (the key that decides its expected result, or "silent: <what decides>")')
        else:
            for item in str(decides).split(','):
                item = item.strip()
                head = re.split(r'[\s,;:]', item, maxsplit=1)[0].strip()
                if head.lower() == 'silent':
                    if ':' not in item or not item.split(':', 1)[1].strip():
                        problems.append(f'test {name}: decides "silent" needs what decides instead')
                elif _keys and head not in _keys:
                    problems.append(f'test {name}: decides "{head}" is not a key in method.toml [references.keys]')
        if entry.get('runner') not in matrix.runners:
            problems.append(f'test {name}: no runner "{entry.get("runner")}"')
        values_ok(f'test {name} fixed', entry.get('fixed', {}), single=True)
        values_ok(f'test {name} allow', entry.get('allow', {}), single=False)
        if 'client' in entry:
            values_ok(f'test {name} client', {'client': entry['client']}, single=True)
        for group in entry.get('groups', []):
            if group not in groups:
                problems.append(f'test {name}: no area uses group "{group}"')
        if matrix.broken(matrix.config(name)):
            problems.append(f'test {name}: its own configuration is impossible: '
                            f'{matrix.broken(matrix.config(name))}')
    for slug, family in matrix.data.get('families', {}).items():
        if not family.get('page') or not (family.get('census') or family.get('inventory')):
            problems.append(f'family {slug}: needs a page and census or inventory names')
    for driver, overrides in matrix.data.get('census_files', {}).items():
        values_ok(f'census_files {driver}', overrides, single=True)
    for kind in {runner.get('kind') for runner in matrix.runners.values()} - set(PHASES):
        problems.append(f'runner kind "{kind}" is not one of {", ".join(PHASES)}')
    for area in matrix.areas:
        for axis in area.get('vary', []) + area.get('full', []) + area.get('cover', []):
            if axis not in axes:
                problems.append(f'area {area["name"]}: no axis "{axis}"')
        for test in area.get('tests', []):
            if test not in matrix.tests:
                problems.append(f'area {area["name"]}: no test "{test}"')
    inside = subprocess.run(['git', 'rev-parse', '--show-toplevel'], capture_output=True, text=True)
    if not inside.returncode:
        tracked = git('ls-files', '--', 'src', 'scripts/build.py').split()
        loose = [name for name in tracked
                 if not any(fnmatch.fnmatchcase(name, pattern)
                            for area in matrix.areas for pattern in area['paths'])]
        if loose:
            warnings.append('code no area names (it gets the fallback groups): ' + ', '.join(loose))
    return problems, warnings


def main():
    parser = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    parser.add_argument('command', nargs='?', default='plan', choices=('plan', 'check'))
    parser.add_argument('--matrix', help='another matrix file')
    parser.add_argument('--base', help='diff the working tree against this (default HEAD)')
    parser.add_argument('--files', nargs='+', default=[], help='plan for these paths instead of a diff')
    parser.add_argument('--area', action='append', default=[], help='add an area by name')
    parser.add_argument('--group', action='append', default=[], help='add a test group')
    parser.add_argument('--test', action='append', default=[], help='add a test')
    parser.add_argument('--family', action='append', default=[],
                        help='add the survey of a sound engine family (rule 10)')
    parser.add_argument('--driver', action='append', default=[],
                        help='survey these census files instead of the family\'s own list')
    parser.add_argument('--baseline', action='store_true',
                        help='add a run without uCDD (mode base) beside each run (step 3)')
    parser.add_argument('--format', choices=('md', 'tsv', 'json'), default='md')
    parser.add_argument('--save', action='store_true',
                        help='save the plan in the ledger, so its runs can be recorded')
    args = parser.parse_args()
    matrix = load(args.matrix)
    if args.command == 'check':
        problems, warnings = check(matrix)
        for line in problems + [f'warning: {warning}' for warning in warnings]:
            print(line)
        if not problems:
            print('matrix.toml: no problems')
        return 1 if problems else 0
    asked = args.area or args.group or args.test or args.family
    base = args.base or 'HEAD'
    files = args.files or ([] if asked and not args.base else changed_files(base))
    if not files and not asked:
        raise SystemExit(f'nothing changed against {base}: give --base, --files, --area, --group or --test')
    chosen, hit, unmatched, cover, todo = select(matrix, files, args.area, args.group, args.test)
    untraced = []
    for slug in args.family:
        tests, missing = survey(matrix, slug, args.driver)
        matrix.tests.update(tests)
        for name in tests:
            chosen.setdefault(name, {'why': [], 'vary': set(), 'full': set()})['why'].append(f'family {slug}')
        untraced += [(f'{what} ({slug})', why) for what, why in missing]
    if not chosen:
        raise SystemExit('the change reaches no test (notes only?)')
    plan = build_plan(matrix, chosen, args.baseline)
    plan['families'], plan['untraced'] = args.family, untraced
    if args.save:
        saved = methodlib.save_plan({'tag': plan['tag'], 'files': files, 'families': args.family,
                                     'runs': plan['runs']})
        print(f'plan {plan["tag"]} saved: {saved}', file=sys.stderr)
    if args.format == 'json':
        print(json.dumps(plan, indent=1))
    elif args.format == 'tsv':
        print(show_tsv(plan))
    else:
        print(show_markdown(matrix, plan, files, 'as given' if args.files else f'against {base}',
                            hit, unmatched, cover, todo))
    return 0


if __name__ == '__main__':
    sys.exit(main())
