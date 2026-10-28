#!/usr/bin/env python3
"""import_hardware.py: a hardware measurement from the PC into the bench.

    python3 METHOD/tools/import_hardware.py TCTABLE.TXT --card ct2290 --source TEXT
        [--out FILE] [--compare formula|sb16]

TCTABLE.TXT is TCTABLE.EXE's output (AKIT; the bench's T2.EXE TCTABLE case
prints the same lines): one line a time constant, "TC xxh: R.R Hz (n blocks;
the formula F Hz)", or "TC xxh: no block interrupt within 2 s". The measured
rate of every constant goes into one JSON file with its provenance (the
card, the source given, the input's sha256, the date):

    {"card": ..., "source": ..., "sha256": ..., "imported": ...,
     "rates": {"0": 3739.1, ...}, "silent": [...], "one_block": [...]}

written by default to the bench's runs/rec/hw/tctable-CARD.json. tonecheck
reads tctable-ct2290.json, when it is there, as the hardware-grade table for
every pitch on the virtual SB16 (Michael, 28 Oct 2026, question 30), in place
of the DSP 4.13 firmware's.

--compare prints, against the formula 1000000/(256-TC) or the 4.13 firmware
table (tonecheck's SB16_TIME_TABLE), the constants that differ by more than
0.2 % and the largest difference; the bench's own runs of the case (86Box's
card on C0, uCDD's on C2) are checked that way before a hardware file is
trusted. Nothing is written with --compare unless --out is given too.
"""

from pathlib import Path
import argparse
import datetime
import hashlib
import json
import re
import sys

METHOD = Path(__file__).resolve().parent.parent
BENCH = METHOD.parent.parent.parent          # rig86: runs/src/method -> rig86
LINE = re.compile(r'TC ([0-9A-F]{2})h: (?:([0-9]+\.[0-9]) Hz|(no block interrupt)|(one block only))')


def parse(text):
    rates, silent, one = {}, [], []
    for m in LINE.finditer(text):
        tc = int(m.group(1), 16)
        if m.group(2):
            rates[tc] = float(m.group(2))
        elif m.group(3):
            silent.append(tc)
        else:
            one.append(tc)
    return rates, silent, one


def sb16_table():
    sys.path.insert(0, str(BENCH / 'runs' / 'rec'))
    import tonecheck
    return lambda tc: tonecheck.SB16_TIME_TABLE[min(tc, 0xeb)] * 4096 / 23


def compare(rates, against):
    model = (lambda tc: 1000000 / (256 - tc)) if against == 'formula' else sb16_table()
    worst, off = 0.0, []
    for tc, rate in sorted(rates.items()):
        due = model(tc)
        dev = abs(rate - due) / due * 100
        worst = max(worst, dev)
        if dev > 0.2:
            off.append('%02Xh %.1f against %.1f (%.2f %%)' % (tc, rate, due, dev))
    print('%d constants measured; against the %s: %d differ by more than 0.2 %%, the largest %.3f %%'
          % (len(rates), against, len(off), worst))
    for line in off:
        print('  ' + line)
    return not off


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('file')
    ap.add_argument('--card', required=True, help='the card measured, e.g. ct2290, es1868')
    ap.add_argument('--source', help='where the file came from (kit, run, date)')
    ap.add_argument('--out')
    ap.add_argument('--compare', choices=('formula', 'sb16'))
    a = ap.parse_args()
    raw = Path(a.file).read_bytes()
    rates, silent, one = parse(raw.decode('ascii', 'replace'))
    print('%s: %d rates, %d silent, %d one block only' % (a.file, len(rates), len(silent), len(one)))
    ok = True
    if a.compare:
        ok = compare(rates, a.compare)
    if a.out or not a.compare:
        if not a.source:
            sys.exit('import_hardware: --source is required to write a hardware table (its provenance)')
        out = Path(a.out) if a.out else BENCH / 'runs' / 'rec' / 'hw' / ('tctable-%s.json' % a.card)
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(json.dumps({
            'card': a.card, 'source': a.source, 'sha256': hashlib.sha256(raw).hexdigest(),
            'imported': datetime.datetime.now(datetime.timezone.utc).isoformat(timespec='seconds'),
            'rates': {str(tc): rate for tc, rate in sorted(rates.items())},
            'silent': silent, 'one_block': one}, indent=1) + '\n')
        print('written: %s' % out)
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
