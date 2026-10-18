# SPDX-License-Identifier: GPL-3.0-only

"""Check UCDDPLAY against an earlier build of itself, in an emulator.

    playcheck.py compare REF       the session, frame by frame, REF against the
                                   working tree; also with the screen copy and
                                   the logo tables refused
    playcheck.py fuzz REF          the pixel routines and the analyzer on
                                   random inputs, REF against the working tree
    playcheck.py hardware [TARGET...]  the physical output and the EQ
                                   calibration against a scripted machine
    playcheck.py profile TARGET    instructions and estimated clocks a frame
    playcheck.py shot TARGET FRAMES OUT.png   the screen after those frames

REF and TARGET are git revisions; TARGET may also be "work", the working
tree. Builds go to build/playcheck. compare and fuzz exit with 1 on any
difference.
"""

import argparse, json, os, re, shutil, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import player
import checks

ROOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(ROOT, 'build', 'playcheck')
DISPLAYS = ['warp', 'scope', 'waterfall', 'fire', 'bubbles', 'plasma', 'tunnel']


def build(target):
    """Assemble TARGET; return its build directory."""
    name = re.sub(r'[^A-Za-z0-9_.-]', '_', target)
    out = os.path.join(OUT, name)
    if target == 'work':
        src = ROOT
    else:
        src = os.path.join(OUT, name + '-src')
        shutil.rmtree(src, ignore_errors=True)
        os.makedirs(src)
        archive = subprocess.run(['git', '-C', ROOT, 'archive', target, 'src'],
                                 check=True, capture_output=True).stdout
        subprocess.run(['tar', '-x', '-C', src], input=archive, check=True)
    player.build(out, src)
    return out


def trace(d, frames, **options):
    return player.Session(player.Player(d, shadow=options.pop('shadow', True)),
                          frames, **options).run()


def compare(args):
    ref, work = build(args.ref), build('work')
    expected = trace(ref, args.frames)
    bad = 0
    for label, options in (('as built', {}), ('no screen copy', {'shadow': False}),
                           ('no logo tables', {'logo_runs': False})):
        n = player.diff(expected, trace(work, args.frames, **options))
        print('%s: %d frames, %d differences' % (label, args.frames, n))
        bad += n
    return 1 if bad else 0


def fuzz(args):
    ref, work = build(args.ref), build('work')
    n = checks.pixels(ref, work, args.cases)
    print('pixel routines: %d cases, %d differences' % (args.cases, n))
    m = checks.analyzer(ref, work, args.rings)
    print('analyze: %d rings, %d differences' % (args.rings, m))
    return 1 if n or m else 0


def hardware(args):
    for target in args.targets:
        d = build(target)
        print(target + ':')
        checks.physical(d)
        checks.midnight(d)
    return 0


def profile(args):
    force = None
    if args.state:
        vis, play = args.state.split(',')
        force = (DISPLAYS.index(vis) if vis in DISPLAYS else int(vis), int(play))
    stats, screen = player.profile(build(args.target), args.frames, args.skip, force)
    total = [sum(v[i] for v in stats.values()) for i in range(3)]
    print('a frame: %d instructions, 386 ~%d clocks, Pentium ~%d clocks, %d bytes to the screen'
          % (total[0], total[1], total[2], screen))
    for name, v in sorted(stats.items(), key=lambda kv: -kv[1][1])[:args.top]:
        print('%-22s %9d ins %10d c386 (%4.1f%%) %9d cP5 (%4.1f%%)' % (
            name, v[0], v[1], 100.0 * v[1] / total[1], v[2], 100.0 * v[2] / total[2]))
    return 0


def shot(args):
    from PIL import Image
    p = player.Player(build(args.target))
    s = player.Session(p, 0)
    s.setup()
    wanted = sorted(int(x) for x in args.frames.split(','))
    images = []
    for f in range(wanted[-1] + 1):
        s.frame(f)
        if f in wanted:
            pal = bytearray(p.mu.mem_read(p.extra * 16 + p.k['A_PALETTE'], 768))
            dyn = p.mu.mem_read(p.addr('dynamic_palette'), (3 * p.k['COPPER_SHADES'] + 16) * 3)
            pal[p.k['C_COPPER'] * 3:p.k['C_COPPER'] * 3 + len(dyn)] = dyn
            im = Image.frombytes('P', (320, 200), bytes(p.mu.mem_read(0xa0000, 64000)))
            im.putpalette([min(255, c * 4) for c in pal])
            images.append(im.convert('RGB').resize((640, 400), Image.NEAREST))
    sheet = Image.new('RGB', (640 * min(2, len(images)), 400 * ((len(images) + 1) // 2)))
    for i, im in enumerate(images):
        sheet.paste(im, ((i % 2) * 640, (i // 2) * 400))
    sheet.save(args.out)
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest='command', required=True)
    c = sub.add_parser('compare')
    c.add_argument('ref')
    c.add_argument('--frames', type=int, default=1500)
    c.set_defaults(run=compare)
    c = sub.add_parser('fuzz')
    c.add_argument('ref')
    c.add_argument('--cases', type=int, default=4000)
    c.add_argument('--rings', type=int, default=300)
    c.set_defaults(run=fuzz)
    c = sub.add_parser('hardware')
    c.add_argument('targets', nargs='*', default=['work'])
    c.set_defaults(run=hardware)
    c = sub.add_parser('profile')
    c.add_argument('target')
    c.add_argument('--state', help='DISPLAY,PLAY: hold a display (a name or 0-6) and a play '
                   'state (0 stopped, 1 playing, 2 paused) with nothing over it')
    c.add_argument('--skip', type=int, default=30)
    c.add_argument('--frames', type=int, default=20)
    c.add_argument('--top', type=int, default=25)
    c.set_defaults(run=profile)
    c = sub.add_parser('shot')
    c.add_argument('target')
    c.add_argument('frames', help='frame numbers, comma separated')
    c.add_argument('out')
    c.set_defaults(run=shot)
    args = ap.parse_args()
    sys.exit(args.run(args))


if __name__ == '__main__':
    main()
