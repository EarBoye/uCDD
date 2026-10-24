#!/usr/bin/env python3
"""The results ledger: what the runners ran, on which binaries, and the verdict.

    ledger.py record PLAN RUN pass|fail --build-dir DIR [--tool FILE ...]
                     [--output FILE ...] [--note TEXT]
    ledger.py show PLAN
    ledger.py spot PLAN [-n 2]
    ledger.py audit PLAN

record is for the runners (regress.sh, sndreg, game_live.py, probe_test.py)
to call once a run is judged; the Claude Code guard refuses it typed by hand.
The plan must have been saved first (plan.py --save) and the run must be one
of its runs. --build-dir is the directory the run's UCDD.EXE came from; a run
without uCDD (mode base) has none. --tool pins the instruments by hash (the
bench is not versioned): sndreg.py, audiocmp.py, the probe program. With
UCDD_SPOT=1 in the environment the entry is a spot check, which audit
compares with the original.
"""

from pathlib import Path
import argparse
import datetime
import os
import platform
import random
import re
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / 'lib'))
import methodlib  # noqa: E402


def plan_or_exit(tag):
    plan = methodlib.saved_plan(tag)
    if not plan:
        raise SystemExit(f'ledger: plan {tag} is not saved in {methodlib.ledger_dir()}: '
                         'run plan.py with --save before running it')
    return plan


def dynarec_of(args):
    """False (off, evidence), True (on, comparison) or None (unknown, comparison)."""
    if args.config:
        text = Path(args.config).read_text(errors='replace')
        match = re.search(r'^\s*cpu_use_dynarec\s*=\s*(\d+)', text, re.M)
        if not match:
            raise SystemExit(f'ledger: {args.config} has no cpu_use_dynarec line')
        return match.group(1) != '0'
    if args.dynarec is not None:
        return args.dynarec != '0'
    value = os.environ.get('RIG_DYNAREC')
    return None if value is None else value != '0'


def record(args):
    plan = plan_or_exit(args.plan)
    runs = {run['id']: run for run in plan['runs']}
    if args.run not in runs:
        raise SystemExit(f'ledger: plan {args.plan} has no run {args.run}')
    run = runs[args.run]
    if run['config']['mode'] != 'base' and not args.build_dir:
        raise SystemExit('ledger: a run with uCDD needs --build-dir, the binaries it ran')
    entry = {
        'time': datetime.datetime.now(datetime.timezone.utc).isoformat(timespec='seconds'),
        'plan': args.plan, 'run': args.run, 'test': run['test'], 'verdict': args.verdict,
        'binaries': methodlib.binaries(args.build_dir) if args.build_dir else {},
        'tools': {name: methodlib.sha256(name) for name in args.tool},
        'outputs': {name: methodlib.sha256(name) for name in args.output},
        'note': args.note, 'spot': os.environ.get('UCDD_SPOT') == '1', 'host': platform.node(),
        'dynarec': dynarec_of(args),
    }
    if args.build_dir and not entry['binaries']:
        raise SystemExit(f'ledger: no built files in {args.build_dir}')
    methodlib.append(entry)
    print(f'ledger: {args.run} {args.verdict}' + (' (spot check)' if entry['spot'] else '')
          + ('' if methodlib.is_evidence(entry) else
             ' (comparison: the recompiler was on or not recorded; not evidence)'))


def show(args):
    plan = plan_or_exit(args.plan)
    evidence = methodlib.latest(args.plan, evidence_only=True)
    anything = methodlib.latest(args.plan)
    counts = {}
    for run in plan['runs']:
        entry = evidence.get(run['id'])
        other = anything.get(run['id'])
        if entry:
            verdict, when, dyn = entry['verdict'], entry['time'], 'dynarec off'
        elif other:
            verdict, when, dyn = other['verdict'] + '*', other['time'], 'dynarec ON' if other.get('dynarec') else 'dynarec ?'
        else:
            verdict, when, dyn = 'not run', '', ''
        counts[verdict] = counts.get(verdict, 0) + 1
        extra = ''
        if entry and other and other is not entry:
            extra = f'  (a later comparison: {other["verdict"]}, {other["time"]}, dynarec {"ON" if other.get("dynarec") else "?"})'
        print(f'{run["id"]}  {run["test"]:14} {verdict:9} {when}  {dyn}{extra}')
    print('; '.join(f'{verdict}: {count}' for verdict, count in sorted(counts.items())))
    if any(v.endswith('*') for v in counts):
        print('* comparison only: the recompiler was on or not recorded; not evidence (record with --config)')
    return 0 if counts.get('pass', 0) == len(plan['runs']) else 1


def spot(args):
    plan = plan_or_exit(args.plan)
    newest = methodlib.latest(args.plan)
    passed = [run for run in plan['runs'] if newest.get(run['id'], {}).get('verdict') == 'pass']
    if not passed:
        raise SystemExit(f'ledger: no run of {args.plan} has passed yet')
    for run in random.SystemRandom().sample(passed, min(args.n, len(passed))):
        print(f'{run["id"]}  UCDD_SPOT=1 {run["command"]}')


def audit(args):
    plan_or_exit(args.plan)
    original = methodlib.latest(args.plan, evidence_only=True)
    again = methodlib.latest(args.plan, spot=True, evidence_only=True)
    if not again:
        print(f'ledger: plan {args.plan} has no spot check')
        return 1
    disagree = 0
    for run, entry in sorted(again.items()):
        first = original.get(run, {}).get('verdict', 'not run')
        same = first == entry['verdict']
        disagree += not same
        print(f'{run}  {entry["test"]:14} first {first:8} again {entry["verdict"]:8} '
              + ('agrees' if same else 'DISAGREES: the fix or the instrument (L11)'))
    return 1 if disagree else 0


def main():
    parser = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    commands = parser.add_subparsers(dest='command', required=True)
    one = commands.add_parser('record')
    one.add_argument('plan')
    one.add_argument('run')
    one.add_argument('verdict', choices=('pass', 'fail'))
    one.add_argument('--build-dir')
    one.add_argument('--tool', action='append', default=[])
    one.add_argument('--output', action='append', default=[])
    one.add_argument('--note', default='')
    one.add_argument('--config', help="the run's 86box.cfg: cpu_use_dynarec decides evidence or comparison")
    one.add_argument('--dynarec', choices=('0', '1'), help='when no 86box.cfg is at hand')
    for name in ('show', 'spot', 'audit'):
        command = commands.add_parser(name)
        command.add_argument('plan')
        if name == 'spot':
            command.add_argument('-n', type=int, default=2)
    args = parser.parse_args()
    return {'record': record, 'show': show, 'spot': spot, 'audit': audit}[args.command](args) or 0


if __name__ == '__main__':
    sys.exit(main())
