#!/usr/bin/env python3
"""Turn a change into the matrix runs it needs.

    plan.py [plan] [--base REF | --files F ...] [--area A] [--group G]
                   [--test T] [--baseline] [--format md|tsv|json]
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
    files |= set(git('ls-files', '--others', '--exclude-standard').split())
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
    if plan['blocked']:
        out += ['## Blocked: needed, but not runnable yet', '']
        for test, reason, rows, repeat in plan['blocked']:
            findings = matrix.tests[test].get('findings')
            note = f' ({", ".join(findings)})' if findings else ''
            out.append(f'- {test}{note}: {reason}; would run {len(rows) * repeat} times')
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
    for name, entry in matrix.tests.items():
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
    asked = args.area or args.group or args.test
    base = args.base or 'HEAD'
    files = args.files or ([] if asked and not args.base else changed_files(base))
    if not files and not asked:
        raise SystemExit(f'nothing changed against {base}: give --base, --files, --area, --group or --test')
    chosen, hit, unmatched, cover, todo = select(matrix, files, args.area, args.group, args.test)
    if not chosen:
        raise SystemExit('the change reaches no test (notes only?)')
    plan = build_plan(matrix, chosen, args.baseline)
    if args.save:
        saved = methodlib.save_plan({'tag': plan['tag'], 'files': files, 'runs': plan['runs']})
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
