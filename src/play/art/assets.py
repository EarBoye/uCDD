# SPDX-FileCopyrightText: 2026 vorvek
# SPDX-License-Identifier: GPL-3.0-only

"""Make the UCDDPLAY graphics and tables.

python assets.py <faceplate.png> <logo.png>

The inputs come from faceplate.py and logo.py. The script writes
../assets.bin and ../assets.inc. It needs Pillow. The program build does not
run this script.
"""

import math
import struct
import sys
from pathlib import Path

from PIL import Image

W, H = 320, 200
HERE = Path(__file__).resolve().parent

# Screen layout. The program includes these values from assets.inc.
LOGO_WIN = (68, 6, 251, 37)
LCD_WIN = (11, 47, 158, 97)
ANA_WIN = (169, 47, 308, 97)
SCROLL_WIN = (12, 172, 307, 192)
VU_WINS = ((12, 8, 50, 35), (269, 8, 307, 35))
VU_PIVOT_DY = 14
VU_RADIUS = 40
SLIDER_X0, SLIDER_STEP, SLIDERS = 70, 23, 11
SLIDER_TOP, SLIDER_BOTTOM = 110, 134
KNOB_X, KNOB_Y = 33, 119
JEWEL_X, JEWEL_Y = 16, 141
BUTTONS = [(7, 26), (37, 30), (71, 26), (101, 26), (131, 40), (175, 46), (225, 40), (269, 44)]
BUTTON_Y0, BUTTON_Y1 = 152, 166
DIGIT_X = (14, 27, 52, 65, 85, 98)
DIGIT_Y = 56
COLON_X = 80
ANNUNCIATOR_Y = 77
PROGRESS_X, PROGRESS_Y, PROGRESS_CELLS = 14, 83, 35
CALENDAR_X, CALENDAR_Y = 14, 87
ANA_BARS, ANA_X0, ANA_STEP, ANA_BAR_W = 20, 171, 7, 5
ANA_TOP, ANA_BOTTOM = 49, 84

# Fixed interface colors at palette indices 1 to 24.
UI_COLORS = [
    ('ENGRAVE', (6, 6, 14)), ('LABEL', (150, 160, 230)), ('TEXT', (220, 230, 255)),
    ('GOLD_HI', (255, 236, 160)), ('GOLD', (220, 160, 60)), ('GOLD_LO', (110, 64, 16)),
    ('ORANGE', (255, 190, 70)), ('NAVY0', (14, 16, 64)), ('NAVY1', (10, 12, 48)),
    ('NAVY2', (6, 8, 34)), ('NAVY3', (2, 2, 20)), ('BURG0', (150, 24, 44)),
    ('BURG1', (110, 14, 30)), ('BURG2', (64, 4, 14)), ('SEL0', (255, 224, 130)),
    ('SEL1', (230, 180, 80)), ('SEL2', (200, 140, 50)), ('SEL3', (170, 100, 20)),
    ('DIR', (255, 200, 90)), ('FILE', (170, 220, 255)), ('INFO', (120, 130, 200)),
    ('FIELD', (0, 0, 12)), ('STUD', (30, 36, 100)), ('DARKTEXT', (40, 20, 0)),
]
STATIC_COLORS = 159
KEY = 159
TRANSPARENT = KEY
COPPER, COPPER_SHADES = 160, 9
RAINBOW = 187
HEAT = 203
SPECTRUM = 219
REFLECT = 235
LCD_WHITE, LCD_ON, LCD_MID, LCD_PRINT = 239, 240, 241, 242
STARS = 243
STRIPE, STRIPE_PRE, EQ_LINE = 246, 247, 248
KNOB_CHROME = 249
RED, WHITE = 254, 255

FONT8 = {
    ' ': ['........'] * 8,
    'A': ['..###...', '.##.##..', '##...##.', '#######.', '##...##.', '##...##.', '##...##.', '........'],
    'B': ['######..', '##...##.', '##...##.', '######..', '##...##.', '##...##.', '######..', '........'],
    'C': ['.#####..', '##...##.', '##......', '##......', '##......', '##...##.', '.#####..', '........'],
    'D': ['#####...', '##..##..', '##...##.', '##...##.', '##...##.', '##..##..', '#####...', '........'],
    'E': ['#######.', '##......', '##......', '######..', '##......', '##......', '#######.', '........'],
    'F': ['#######.', '##......', '##......', '######..', '##......', '##......', '##......', '........'],
    'G': ['.#####..', '##...##.', '##......', '##.####.', '##...##.', '##...##.', '.######.', '........'],
    'H': ['##...##.', '##...##.', '##...##.', '#######.', '##...##.', '##...##.', '##...##.', '........'],
    'I': ['.####...', '..##....', '..##....', '..##....', '..##....', '..##....', '.####...', '........'],
    'J': ['....###.', '.....##.', '.....##.', '.....##.', '##...##.', '##...##.', '.#####..', '........'],
    'K': ['##...##.', '##..##..', '##.##...', '####....', '##.##...', '##..##..', '##...##.', '........'],
    'L': ['##......', '##......', '##......', '##......', '##......', '##......', '#######.', '........'],
    'M': ['##...##.', '###.###.', '#######.', '##.#.##.', '##...##.', '##...##.', '##...##.', '........'],
    'N': ['##...##.', '###..##.', '####.##.', '##.####.', '##..###.', '##...##.', '##...##.', '........'],
    'O': ['.#####..', '##...##.', '##...##.', '##...##.', '##...##.', '##...##.', '.#####..', '........'],
    'P': ['######..', '##...##.', '##...##.', '######..', '##......', '##......', '##......', '........'],
    'Q': ['.#####..', '##...##.', '##...##.', '##...##.', '##.#.##.', '##..##..', '.###.##.', '........'],
    'R': ['######..', '##...##.', '##...##.', '######..', '##.##...', '##..##..', '##...##.', '........'],
    'S': ['.#####..', '##...##.', '##......', '.#####..', '.....##.', '##...##.', '.#####..', '........'],
    'T': ['######..', '..##....', '..##....', '..##....', '..##....', '..##....', '..##....', '........'],
    'U': ['##...##.', '##...##.', '##...##.', '##...##.', '##...##.', '##...##.', '.#####..', '........'],
    'V': ['##...##.', '##...##.', '##...##.', '##...##.', '.##.##..', '..###...', '...#....', '........'],
    'W': ['##...##.', '##...##.', '##...##.', '##.#.##.', '#######.', '###.###.', '##...##.', '........'],
    'X': ['##...##.', '.##.##..', '..###...', '..###...', '..###...', '.##.##..', '##...##.', '........'],
    'Y': ['##..##..', '##..##..', '##..##..', '.####...', '..##....', '..##....', '..##....', '........'],
    'Z': ['#######.', '....##..', '...##...', '..##....', '.##.....', '##......', '#######.', '........'],
    '0': ['.#####..', '##..###.', '##.####.', '####.##.', '###..##.', '##...##.', '.#####..', '........'],
    '1': ['..##....', '.###....', '..##....', '..##....', '..##....', '..##....', '.####...', '........'],
    '2': ['.#####..', '##...##.', '.....##.', '...###..', '.###....', '##......', '#######.', '........'],
    '3': ['.#####..', '##...##.', '.....##.', '..####..', '.....##.', '##...##.', '.#####..', '........'],
    '4': ['...###..', '..####..', '.##.##..', '##..##..', '#######.', '....##..', '....##..', '........'],
    '5': ['#######.', '##......', '######..', '.....##.', '.....##.', '##...##.', '.#####..', '........'],
    '6': ['..####..', '.##.....', '##......', '######..', '##...##.', '##...##.', '.#####..', '........'],
    '7': ['#######.', '.....##.', '....##..', '...##...', '..##....', '..##....', '..##....', '........'],
    '8': ['.#####..', '##...##.', '##...##.', '.#####..', '##...##.', '##...##.', '.#####..', '........'],
    '9': ['.#####..', '##...##.', '##...##.', '.######.', '.....##.', '....##..', '.####...', '........'],
    '.': ['........'] * 5 + ['..##....', '..##....', '........'],
    ',': ['........'] * 5 + ['..##....', '..##....', '.##.....'],
    ':': ['........', '..##....', '..##....', '........', '..##....', '..##....', '........', '........'],
    ';': ['........', '..##....', '..##....', '........', '..##....', '..##....', '.##.....', '........'],
    '-': ['........'] * 3 + ['.#####..'] + ['........'] * 4,
    '+': ['........', '..##....', '..##....', '######..', '..##....', '..##....', '........', '........'],
    '/': ['.....##.', '....##..', '...##...', '..##....', '.##.....', '##......', '........', '........'],
    '\\': ['##......', '.##.....', '..##....', '...##...', '....##..', '.....##.', '........', '........'],
    '(': ['...##...', '..##....', '.##.....', '.##.....', '.##.....', '..##....', '...##...', '........'],
    ')': ['.##.....', '..##....', '...##...', '...##...', '...##...', '..##....', '.##.....', '........'],
    '[': ['.####...', '.##.....', '.##.....', '.##.....', '.##.....', '.##.....', '.####...', '........'],
    ']': ['.####...', '...##...', '...##...', '...##...', '...##...', '...##...', '.####...', '........'],
    '{': ['...###..', '..##....', '..##....', '.##.....', '..##....', '..##....', '...###..', '........'],
    '}': ['.###....', '...##...', '...##...', '....##..', '...##...', '...##...', '.###....', '........'],
    '!': ['..##....', '..##....', '..##....', '..##....', '..##....', '........', '..##....', '........'],
    '?': ['.#####..', '##...##.', '....##..', '...##...', '...##...', '........', '...##...', '........'],
    "'": ['..##....', '..##....', '.##.....', '........', '........', '........', '........', '........'],
    '`': ['.##.....', '..##....', '...##...', '........', '........', '........', '........', '........'],
    '"': ['.##.##..', '.##.##..', '.#..#...', '........', '........', '........', '........', '........'],
    '<': ['....##..', '...##...', '..##....', '.##.....', '..##....', '...##...', '....##..', '........'],
    '>': ['.##.....', '..##....', '...##...', '....##..', '...##...', '..##....', '.##.....', '........'],
    '=': ['........', '........', '######..', '........', '######..', '........', '........', '........'],
    '_': ['........'] * 6 + ['#######.', '........'],
    '*': ['........', '.##.##..', '..###...', '#######.', '..###...', '.##.##..', '........', '........'],
    '#': ['.##.##..', '#######.', '.##.##..', '.##.##..', '#######.', '.##.##..', '........', '........'],
    '&': ['..###...', '.##.##..', '..###...', '.###.##.', '##.###..', '##..##..', '.###.##.', '........'],
    '%': ['##...##.', '##..##..', '...##...', '..##....', '.##.....', '##..##..', '#...##..', '........'],
    '$': ['...#....', '.#####..', '##.#....', '.#####..', '...#.##.', '.#####..', '...#....', '........'],
    '@': ['.#####..', '##...##.', '##.####.', '##.####.', '##.###..', '##......', '.#####..', '........'],
    '^': ['...#....', '..###...', '.##.##..', '........', '........', '........', '........', '........'],
    '~': ['.###.##.', '##.###..', '........', '........', '........', '........', '........', '........'],
    '|': ['..##....'] * 7 + ['........'],
    '\x7f': ['........', '..##....', '.####...', '######..', '.####...', '..##....', '........', '........'],
    'u': ['........', '........', '##...##.', '##...##.', '##...##.', '##..###.', '.###.##.', '........'],
}

TINY = {
    ' ': ['...'] * 5,
    '0': ['###', '#.#', '#.#', '#.#', '###'], '1': ['.#.', '##.', '.#.', '.#.', '###'],
    '2': ['###', '..#', '###', '#..', '###'], '3': ['###', '..#', '.##', '..#', '###'],
    '4': ['#.#', '#.#', '###', '..#', '..#'], '5': ['###', '#..', '###', '..#', '###'],
    '6': ['###', '#..', '###', '#.#', '###'], '7': ['###', '..#', '..#', '.#.', '.#.'],
    '8': ['###', '#.#', '###', '#.#', '###'], '9': ['###', '#.#', '###', '..#', '###'],
    'A': ['.#.', '#.#', '###', '#.#', '#.#'], 'B': ['##.', '#.#', '##.', '#.#', '##.'],
    'C': ['.##', '#..', '#..', '#..', '.##'], 'D': ['##.', '#.#', '#.#', '#.#', '##.'],
    'E': ['###', '#..', '##.', '#..', '###'], 'F': ['###', '#..', '##.', '#..', '#..'],
    'G': ['.##', '#..', '#.#', '#.#', '.##'], 'H': ['#.#', '#.#', '###', '#.#', '#.#'],
    'I': ['###', '.#.', '.#.', '.#.', '###'], 'J': ['..#', '..#', '..#', '#.#', '.#.'],
    'K': ['#.#', '#.#', '##.', '#.#', '#.#'], 'L': ['#..', '#..', '#..', '#..', '###'],
    'M': ['#.#', '###', '###', '#.#', '#.#'], 'N': ['##.', '#.#', '#.#', '#.#', '#.#'],
    'O': ['.#.', '#.#', '#.#', '#.#', '.#.'], 'P': ['##.', '#.#', '##.', '#..', '#..'],
    'Q': ['.#.', '#.#', '#.#', '##.', '.##'], 'R': ['##.', '#.#', '##.', '#.#', '#.#'],
    'S': ['.##', '#..', '.#.', '..#', '##.'], 'T': ['###', '.#.', '.#.', '.#.', '.#.'],
    'U': ['#.#', '#.#', '#.#', '#.#', '###'], 'V': ['#.#', '#.#', '#.#', '#.#', '.#.'],
    'W': ['#.#', '#.#', '###', '###', '#.#'], 'X': ['#.#', '#.#', '.#.', '#.#', '#.#'],
    'Y': ['#.#', '#.#', '.#.', '.#.', '.#.'], 'Z': ['###', '..#', '.#.', '#..', '###'],
    '+': ['...', '.#.', '###', '.#.', '...'], '-': ['...', '...', '###', '...', '...'],
    ':': ['...', '.#.', '...', '.#.', '...'], '.': ['...', '...', '...', '...', '.#.'],
    '/': ['..#', '..#', '.#.', '#..', '#..'], '!': ['.#.', '.#.', '.#.', '...', '.#.'],
    ',': ['...', '...', '...', '.#.', '#..'], "'": ['.#.', '.#.', '...', '...', '...'],
    '(': ['.#.', '#..', '#..', '#..', '.#.'], ')': ['.#.', '..#', '..#', '..#', '.#.'],
    '=': ['...', '###', '...', '###', '...'], '?': ['##.', '..#', '.#.', '...', '.#.'],
    '_': ['...', '...', '...', '...', '###'], '<': ['..#', '.#.', '#..', '.#.', '..#'],
    '>': ['#..', '.#.', '..#', '.#.', '#..'], '*': ['...', '#.#', '.#.', '#.#', '...'],
    '\\': ['#..', '#..', '.#.', '..#', '..#'], '%': ['#.#', '..#', '.#.', '#..', '#.#'],
    '#': ['#.#', '###', '#.#', '###', '#.#'], '[': ['##.', '#..', '#..', '#..', '##.'],
    ']': ['.##', '..#', '..#', '..#', '.##'],
    'u': ['...', '#.#', '#.#', '#.#', '.##'],
}

ICONS = {
    'prev': ['#.....#...#', '#....##..##', '#...###.###', '#..########', '#...###.###', '#....##..##', '#.....#...#'],
    'play': ['##.....', '####...', '######.', '#######', '######.', '####...', '##.....'],
    'pause': ['##.##', '##.##', '##.##', '##.##', '##.##', '##.##', '##.##'],
    'stop': ['#######'] * 7,
    'next': ['#...#.....#', '##..##....#', '###.###...#', '########..#', '###.###...#', '##..##....#', '#...#.....#'],
}

SEGMENTS = {
    '0': 'abcdef', '1': 'bc', '2': 'abged', '3': 'abgcd', '4': 'fgbc', '5': 'afgcd',
    '6': 'afgedc', '7': 'abc', '8': 'abcdefg', '9': 'abcdfg', '-': 'g',
}

CURSOR = [
    'O...........',
    'OO..........',
    'OWO.........',
    'OWGO........',
    'OWGGO.......',
    'OWGGGO......',
    'OWGGGGO.....',
    'OWGGGGGO....',
    'OWGGGGGGO...',
    'OWGGGGGGGO..',
    'OWGGGGGGGGO.',
    'OWGGGLOOOOOO',
    'OWGLOLLO....',
    'OWLO.OLLO...',
    'OLO..OLLO...',
    'OO....OLLO..',
    'O.....OLLO..',
    '.......OO...',
]


def vga(color):
    return tuple(round(round(v * 63 / 255) * 255 / 63) for v in color)


def lerp(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def ramp(stops, t):
    t = max(0.0, min(1.0, t))
    for (p0, c0), (p1, c1) in zip(stops, stops[1:]):
        if t <= p1:
            return lerp(c0, c1, 0 if p1 == p0 else (t - p0) / (p1 - p0))
    return stops[-1][1]


class Canvas:
    def __init__(self, image):
        self.img = image
        self.px = image.load()

    def put(self, x, y, c):
        if 0 <= x < W and 0 <= y < H:
            self.px[x, y] = tuple(c)

    def get(self, x, y):
        return self.px[x, y]

    def rect(self, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.put(x, y, c(x, y) if callable(c) else c)

    def glyphs(self, x, y, s, font, c, step, width):
        for ch in s:
            glyph = font.get(ch, font[' '])
            for gy, row in enumerate(glyph):
                for gx, bit in enumerate(row[:width]):
                    if bit == '#':
                        self.put(x + gx, y + gy, c(gy) if callable(c) else c)
            x += step
        return x

    def tiny(self, x, y, s, c):
        return self.glyphs(x, y, s, TINY, c, 4, 3)

    def emboss_tiny(self, x, y, s, face, shadow=(0, 0, 0)):
        self.tiny(x + 1, y + 1, s, shadow)
        return self.tiny(x, y, s, face)

    def icon(self, x, y, name, c):
        for gy, row in enumerate(ICONS[name]):
            for gx, bit in enumerate(row):
                if bit == '#':
                    self.put(x + gx, y + gy, c)


GOLD_HI, GOLD, GOLD_LO = (255, 236, 160), (220, 160, 60), (110, 64, 16)
ENGRAVE = (6, 6, 14)
LCD_PRINT_RGB = (40, 130, 130)
LCD_GHOST_RGB = (0, 44, 52)


def gold_face(gy):
    return ramp([(0, GOLD_HI), (0.5, GOLD), (1, GOLD_LO)], gy / 4)


def segment_pixels(x, y, ch, w=11, h=19):
    mid = h // 2
    shapes = {
        'a': [(x + 2 + i, y + j) for i in range(w - 4) for j in range(2)],
        'd': [(x + 2 + i, y + h - 2 + j) for i in range(w - 4) for j in range(2)],
        'g': [(x + 2 + i, y + mid - 1 + j) for i in range(w - 4) for j in range(2)],
        'f': [(x + i, y + 2 + j) for i in range(2) for j in range(mid - 3)],
        'b': [(x + w - 2 + i, y + 2 + j) for i in range(2) for j in range(mid - 3)],
        'e': [(x + i, y + mid + 1 + j) for i in range(2) for j in range(h - mid - 3)],
        'c': [(x + w - 2 + i, y + mid + 1 + j) for i in range(2) for j in range(h - mid - 3)],
    }
    for name in SEGMENTS[ch]:
        for px, py in shapes[name]:
            yield px + (y + h - py) // 7, py


def details(cv):
    """Draw the pixel details on the downscaled render."""
    plate = lambda c: c[2] > c[0] + 12 and c[2] > 30 and c[0] < 90
    for y in range(3, H - 3):
        for x in range(3, W - 3):
            if (x % 8 == 4 and y % 8 == 2) or (x % 8 == 0 and y % 8 == 6):
                c = cv.get(x, y)
                if plate(c) and plate(cv.get(x - 1, y)) and plate(cv.get(x + 1, y)):
                    cv.put(x, y, lerp(c, (120, 130, 220), 0.45))
                    cv.put(x + 1, y + 1, lerp(c, (0, 0, 0), 0.5))

    for n, (x0, y0, x1, y1) in enumerate(VU_WINS):
        cx, cy = (x0 + x1) / 2, y1 + VU_PIVOT_DY
        for k10 in range(-300, 301, 5):
            a = math.radians(k10 / 10)
            red = k10 > 120
            for r in ((VU_RADIUS, VU_RADIUS + 1) if red else (VU_RADIUS,)):
                cv.put(round(cx + r * math.sin(a)), round(cy - r * math.cos(a) / 1.2),
                       (200, 30, 20) if red else (50, 36, 20))
        for k in (-30, -21, -13, -6, 0, 6, 12, 20, 30):
            a = math.radians(k)
            for r in range(VU_RADIUS + 1, VU_RADIUS + 4):
                cv.put(round(cx + r * math.sin(a)), round(cy - r * math.cos(a) / 1.2),
                       (200, 30, 20) if k > 12 else (50, 36, 20))
        cv.tiny(round(cx) - 3, y1 - 9, 'VU', (70, 48, 24))
        cv.tiny(x0 + 2, y0 + 2, '-', (50, 36, 20))
        cv.tiny(x1 - 4, y0 + 1, '+', (200, 30, 20))
        cv.tiny(x0 + 2, y1 - 6, 'LR'[n], (70, 48, 24))

    cv.tiny(14, 49, 'TRACK', LCD_PRINT_RGB)
    cv.tiny(52, 49, 'TIME', LCD_PRINT_RGB)
    cv.tiny(120, 49, 'DRIVE', LCD_PRINT_RGB)
    for x in DIGIT_X:
        for px, py in segment_pixels(x, DIGIT_Y, '8'):
            cv.put(px, py, LCD_GHOST_RGB)
    for dy in (5, 12):
        cv.rect(COLON_X, DIGIT_Y + dy, COLON_X + 1, DIGIT_Y + dy + 1, LCD_GHOST_RGB)
    x = 14
    for label in ('PLAY', 'PAUSE', 'STOP', 'SHUF', 'RPT', '1', 'ALL'):
        x = cv.tiny(x, ANNUNCIATOR_Y, label, LCD_GHOST_RGB) + (2 if label != 'RPT' else 0)
    for i in range(PROGRESS_CELLS):
        cv.rect(PROGRESS_X + i * 4, PROGRESS_Y, PROGRESS_X + 2 + i * 4, PROGRESS_Y + 1, LCD_GHOST_RGB)
    for n in range(1, 21):
        xx, yy = CALENDAR_X + ((n - 1) % 10) * 14, CALENDAR_Y + ((n - 1) // 10) * 6
        cv.tiny(xx + (4 if n < 10 else 0), yy, str(n), LCD_GHOST_RGB)

    for y in range(ANA_TOP + 3, ANA_BOTTOM + 1, 6):
        for x in range(ANA_WIN[0] + 1, ANA_WIN[2], 3):
            cv.put(x, y, (18, 24, 60))

    labels = ['PRE', '31', '62', '125', '250', '500', '1K', '2K', '4K', '8K', '16K']
    zero = (SLIDER_TOP + SLIDER_BOTTOM) // 2
    for i, label in enumerate(labels):
        cx = SLIDER_X0 + SLIDER_STEP * i
        cv.emboss_tiny(cx - len(label) * 2 + 1, 139, label, gold_face(2))
        for y, wide in ((SLIDER_TOP, 1), (zero, 2), (SLIDER_BOTTOM, 1), (zero - 6, 0), (zero + 6, 0)):
            for dx in range(3 + wide, 6):
                cv.put(cx - dx - 1, y, GOLD if wide else GOLD_LO)
                cv.put(cx + dx + 1, y, GOLD if wide else GOLD_LO)
    cv.emboss_tiny(64, 105, '+12', gold_face(1))
    cv.emboss_tiny(13, 132, 'VOLUME', (150, 160, 230))
    cv.emboss_tiny(22, 139, 'EQ', (150, 160, 230))

    legends = ['prev', None, 'stop', 'next', 'SHUF', 'REPEAT', 'OPEN', 'EJECT']
    for (x, w), name in zip(BUTTONS, legends):
        if name is None:
            for icon, ix in (('play', x + 8), ('pause', x + 18)):
                cv.icon(ix + 1, 157, icon, (255, 255, 255))
                cv.icon(ix, 156, icon, ENGRAVE)
        elif name in ICONS:
            ix = x + (w - len(ICONS[name][0])) // 2
            cv.icon(ix + 1, 157, name, (255, 255, 255))
            cv.icon(ix, 156, name, ENGRAVE)
        else:
            tx = x + (w - (len(name) * 4 - 1)) // 2
            cv.tiny(tx + 1, 158, name, (255, 255, 255))
            cv.tiny(tx, 157, name, ENGRAVE)

    text = 'uCDD PLAY   DIGITAL AUDIO REPRODUCER'
    cv.emboss_tiny(W // 2 - (len(text) * 4 - 1) // 2, 194, text, gold_face(1))


def compose(face_path):
    raw = Image.open(face_path).convert('RGB').resize((W, H), Image.LANCZOS)
    cv = Canvas(raw)
    key = set()
    for rect in (LOGO_WIN, SCROLL_WIN):
        x0, y0, x1, y1 = rect
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                r, g, b = cv.get(x, y)
                if r * 3 + g * 5 + b * 2 < 700:
                    key.add((x, y))
                    cv.put(x, y, (0, 0, 4))
    x0, y0, x1, y1 = ANA_WIN
    cv.rect(x0, y0, x1, y1, lambda x, y: (2, 4, 18) if y % 2 else (0, 2, 12))
    x0, y0, x1, y1 = LCD_WIN
    cv.rect(x0, y0, x1, y1, lambda x, y: lerp((0, 34, 40), (0, 20, 26), (y - y0) / 50) if y % 2
            else lerp((0, 30, 36), (0, 16, 22), (y - y0) / 50))
    for (x0, y0, x1, y1) in VU_WINS:
        cv.rect(x0, y0, x1, y1, lambda x, y: lerp((250, 236, 190), (214, 190, 130),
                                                  (x - x0) / (x1 - x0) * 0.4 + (y - y0) / (y1 - y0) * 0.6))
    details(cv)
    return raw, key


def load_logo(path):
    src = Image.open(path).convert('RGBA')
    box = src.getchannel('A').point(lambda a: 255 if a > 8 else 0).getbbox()
    src = src.crop(box)
    width = 178
    height = round(width * src.height / src.width / 1.2)
    logo = src.resize((width, height), Image.LANCZOS)
    rgb = Image.new('RGB', logo.size, (0, 0, 0))
    rgb.paste(logo, mask=logo.getchannel('A'))
    return rgb, logo.getchannel('A')


def static_palette(face, logo):
    """Fixed interface colors and colors shared by the faceplate and the logo."""
    sample = Image.new('RGB', (W, H + logo.height * 3))
    sample.paste(face, (0, 0))
    for i in range(3):
        sample.paste(logo, (0, H + i * logo.height))
    count = STATIC_COLORS - 1 - len(UI_COLORS)
    q = sample.quantize(colors=count, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    quantized = [tuple(q.getpalette()[i * 3:i * 3 + 3]) for i in range(count)]
    return [(0, 0, 0)] + [vga(c) for _, c in UI_COLORS] + [vga(c) for c in quantized]


def map_image(image, palette, dither):
    pal = Image.new('P', (1, 1))
    flat = [v for c in palette for v in c]
    flat += flat[:3] * (256 - len(palette))
    pal.putpalette(flat)
    mapped = image.quantize(palette=pal, dither=dither)
    data = bytearray(mapped.tobytes())
    for i, v in enumerate(data):
        if v >= len(palette):
            data[i] = 0
    return data


def dynamic_palette():
    pal = {}
    rainbow = [vga(hue(i / 64)) for i in range(64)]
    for b in range(3):
        for k in range(COPPER_SHADES):
            pal[COPPER + b * COPPER_SHADES + k] = rainbow[b * 12]
    for i in range(16):
        pal[RAINBOW + i] = rainbow[i * 4]
        pal[HEAT + i] = vga(ramp([(0, (0, 0, 0)), (0.3, (160, 0, 0)), (0.55, (255, 90, 0)),
                                  (0.8, (255, 220, 40)), (1, (255, 255, 255))], i / 15))
        pal[SPECTRUM + i] = vga(ramp([(0.0, (0, 50, 255)), (0.28, (0, 200, 255)), (0.5, (0, 255, 110)),
                                      (0.72, (255, 240, 0)), (0.86, (255, 120, 0)), (1.0, (255, 20, 60))], i / 15))
    for i in range(4):
        pal[REFLECT + i] = vga(lerp((0, 4, 20), (0, 90, 150), (4 - i) / 5))
    pal[LCD_WHITE], pal[LCD_ON], pal[LCD_MID], pal[LCD_PRINT] = (
        vga((255, 255, 255)), vga((130, 255, 245)), vga((60, 190, 180)), vga((40, 130, 130)))
    for i, c in enumerate(((40, 50, 110), (110, 130, 200), (230, 240, 255))):
        pal[STARS + i] = vga(c)
    pal[STRIPE], pal[STRIPE_PRE], pal[EQ_LINE] = vga((60, 240, 255)), vga((255, 60, 200)), vga((255, 90, 220))
    for i, c in enumerate(((255, 255, 255), (200, 215, 245), (120, 135, 185), (70, 80, 130), (190, 205, 240))):
        pal[KNOB_CHROME + i] = vga(c)
    pal[RED], pal[WHITE] = vga((255, 60, 40)), vga((255, 255, 255))
    return pal, rainbow


def hue(t):
    return ramp([(0.0, (255, 0, 80)), (0.17, (255, 140, 0)), (0.33, (255, 255, 0)), (0.5, (0, 255, 120)),
                 (0.67, (0, 180, 255)), (0.83, (120, 60, 255)), (1.0, (255, 0, 80))], t)


def nearest(palette, color, limit):
    return min(range(limit), key=lambda i: sum((palette[i][k] - color[k]) ** 2 for k in range(3)))


def sprite(rows, colors):
    return bytes(colors.get(ch, TRANSPARENT) for row in rows for ch in row)


def digit_sprites():
    data = bytearray()
    for d in '0123456789-':
        cell = [[TRANSPARENT] * 13 for _ in range(19)]
        for px, py in segment_pixels(0, 0, d):
            cell[py][px] = LCD_WHITE if py < 2 else (LCD_ON if py < 17 else LCD_MID)
        data += bytes(v for row in cell for v in row)
    return data


def knob_sprites():
    data = bytearray()
    for stripe in (STRIPE, STRIPE_PRE):
        rows = []
        for y in range(7):
            if y in (0, 6):
                rows.append([TRANSPARENT] + [0] * 11 + [TRANSPARENT])
            else:
                shade = KNOB_CHROME + y - 1
                row = [0] + [shade] * 11 + [0]
                if y == 3:
                    row[2:11] = [stripe] * 9
                rows.append(row)
        data += bytes(v for row in rows for v in row)
    return data


def font_bytes():
    data = bytearray()
    for code in range(32, 128):
        ch = chr(code)
        if ch not in FONT8:
            ch = ch.upper()
        glyph = FONT8.get(ch, FONT8['?'])
        for row in glyph:
            data.append(int(row.replace('#', '1').replace('.', '0'), 2))
    return data


def tiny_bytes():
    data = bytearray()
    for code in range(32, 128):
        ch = chr(code)
        if ch not in TINY:
            ch = ch.upper()
        glyph = TINY.get(ch, TINY['?'])
        for row in glyph:
            data.append(int(row.replace('#', '1').replace('.', '0'), 2) << 5)
    return data


def eq_tables():
    """Parallel band-pass resonators, as in eq.asm. Q28 values for each band:
    -a1, -a2, then (G - 1) * c0 for -12 to +12 dB. The four lowest bands run
    at 1/8 of 44.1 kHz on sums of 8 frames."""
    bands = [31.25, 62.5, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
    data = bytearray()
    for k, f in enumerate(bands):
        rate, scale = (44100 / 8, 1 / 8) if k < 4 else (44100, 1)
        w0 = 2 * math.pi * f / rate
        alpha = math.sin(w0) / (2 * 1.6)
        a0 = 1 + alpha
        c0 = alpha / a0 * scale
        data += struct.pack('<2i', round(2 * math.cos(w0) / a0 * (1 << 28)), round(-(1 - alpha) / a0 * (1 << 28)))
        data += struct.pack('<25i', *(round((10 ** (g / 20) - 1) * c0 * (1 << 28)) for g in range(-12, 13)))
    preamp = bytearray(struct.pack('<25i', *(round(10 ** (g / 20) * 16384) for g in range(-12, 13))))
    return data, preamp


def bar_bins():
    edges = [40 * (400 ** (i / ANA_BARS)) for i in range(ANA_BARS + 1)]
    bins = []
    for e in edges:
        b = max(1, round(e / (44100 / 1024)))
        if bins and b <= bins[-1]:
            b = bins[-1] + 1
        bins.append(b)
    return struct.pack(f'<{len(bins)}H', *bins)


def main():
    face_path, logo_path = sys.argv[1], sys.argv[2]
    face, key = compose(face_path)
    logo_rgb, logo_alpha = load_logo(logo_path)
    palette = static_palette(face, logo_rgb)
    face_data = map_image(face, palette, Image.Dither.FLOYDSTEINBERG)
    for x, y in key:
        face_data[y * W + x] = KEY
    logo_data = map_image(logo_rgb, palette, Image.Dither.NONE)
    alpha = logo_alpha.load()
    for y in range(logo_rgb.height):
        for x in range(logo_rgb.width):
            if alpha[x, y] <= 110:
                logo_data[y * logo_rgb.width + x] = TRANSPARENT
    dynamic, rainbow = dynamic_palette()
    full = palette + [(0, 0, 4)] + [dynamic[i] for i in range(160, 256)]
    assert len(full) == 256
    shade = bytes(nearest(full, tuple(round(v * 0.45) for v in full[i]), STATIC_COLORS) for i in range(256))
    ui = {name: i + 1 for i, (name, _) in enumerate(UI_COLORS)}
    cursor = sprite(CURSOR, {'O': 0, 'W': ui['GOLD_HI'], 'G': ui['GOLD'], 'L': ui['GOLD_LO']})
    eq, preamp = eq_tables()
    sine = struct.pack('<1024h', *(round(32767 * math.sin(2 * math.pi * k / 1024)) for k in range(1024)))

    extra = bytearray()
    offsets = {}

    def add(name, blob, align=2):
        while len(extra) % align:
            extra.append(0)
        offsets[name] = len(extra)
        extra.extend(blob)

    add('A_PALETTE', bytes(v >> 2 for c in full for v in c))
    add('A_RAINBOW', bytes(v >> 2 for c in rainbow for v in c))
    add('A_SHADE', shade)
    add('A_FONT8', font_bytes())
    add('A_TINY', tiny_bytes())
    add('A_LOGO', logo_data)
    add('A_DIGITS', digit_sprites())
    add('A_KNOB', knob_sprites())
    add('A_CURSOR', cursor)
    add('A_SINE', sine)
    add('A_EQ', eq, 4)
    add('A_PREAMP', preamp, 4)
    add('A_BARS', bar_bins())

    assert len(face_data) == 64000
    blob = bytes(face_data) + bytes(extra)
    (HERE.parent / 'assets.bin').write_bytes(blob)

    lines = ['; SPDX-FileCopyrightText: 2026 vorvek', '; SPDX-License-Identifier: GPL-3.0-only',
             '; Generated by src/play/art/assets.py. Do not edit.', '']
    for name, value in offsets.items():
        lines.append(f'%define {name} {value}')
    lines.append(f'%define ASSET_EXTRA_BYTES {len(extra)}')
    consts = {
        'LOGO_W': logo_rgb.width, 'LOGO_H': logo_rgb.height, 'DIGIT_W': 13, 'DIGIT_H': 19,
        'KNOB_W': 13, 'KNOB_H': 7, 'CURSOR_W': len(CURSOR[0]), 'CURSOR_H': len(CURSOR),
        'C_KEY': KEY, 'C_TRANSPARENT': TRANSPARENT, 'C_COPPER': COPPER, 'COPPER_SHADES': COPPER_SHADES,
        'C_RAINBOW': RAINBOW, 'C_HEAT': HEAT, 'C_SPECTRUM': SPECTRUM, 'C_REFLECT': REFLECT,
        'C_LCD_WHITE': LCD_WHITE, 'C_LCD_ON': LCD_ON, 'C_LCD_MID': LCD_MID, 'C_LCD_PRINT': LCD_PRINT,
        'C_STARS': STARS, 'C_STRIPE': STRIPE, 'C_STRIPE_PRE': STRIPE_PRE, 'C_EQ_LINE': EQ_LINE,
        'C_KNOB': KNOB_CHROME, 'C_RED': RED, 'C_WHITE': WHITE, 'C_BLACK': 0,
        'LOGO_X0': LOGO_WIN[0], 'LOGO_Y0': LOGO_WIN[1], 'LOGO_X1': LOGO_WIN[2], 'LOGO_Y1': LOGO_WIN[3],
        'LCD_X0': LCD_WIN[0], 'LCD_Y0': LCD_WIN[1], 'LCD_X1': LCD_WIN[2], 'LCD_Y1': LCD_WIN[3],
        'ANA_X0': ANA_WIN[0], 'ANA_Y0': ANA_WIN[1], 'ANA_X1': ANA_WIN[2], 'ANA_Y1': ANA_WIN[3],
        'SCROLL_X0': SCROLL_WIN[0], 'SCROLL_Y0': SCROLL_WIN[1], 'SCROLL_X1': SCROLL_WIN[2],
        'SCROLL_Y1': SCROLL_WIN[3],
        'VU_L_X0': VU_WINS[0][0], 'VU_R_X0': VU_WINS[1][0], 'VU_Y0': VU_WINS[0][1],
        'VU_W': VU_WINS[0][2] - VU_WINS[0][0] + 1, 'VU_Y1': VU_WINS[0][3],
        'VU_PIVOT_DY': VU_PIVOT_DY, 'VU_RADIUS': VU_RADIUS,
        'SLIDER_X0': SLIDER_X0, 'SLIDER_STEP': SLIDER_STEP, 'SLIDERS': SLIDERS,
        'SLIDER_TOP': SLIDER_TOP, 'SLIDER_BOTTOM': SLIDER_BOTTOM,
        'KNOB_X': KNOB_X, 'KNOB_Y': KNOB_Y, 'JEWEL_X': JEWEL_X, 'JEWEL_Y': JEWEL_Y,
        'BUTTON_Y0': BUTTON_Y0, 'BUTTON_Y1': BUTTON_Y1,
        'DIGIT_Y': DIGIT_Y, 'COLON_X': COLON_X, 'ANNUNCIATOR_Y': ANNUNCIATOR_Y,
        'PROGRESS_X': PROGRESS_X, 'PROGRESS_Y': PROGRESS_Y, 'PROGRESS_CELLS': PROGRESS_CELLS,
        'CALENDAR_X': CALENDAR_X, 'CALENDAR_Y': CALENDAR_Y,
        'ANA_BARS': ANA_BARS, 'ANA_BAR_X0': ANA_X0, 'ANA_STEP': ANA_STEP, 'ANA_BAR_W': ANA_BAR_W,
        'ANA_TOP': ANA_TOP, 'ANA_BOTTOM': ANA_BOTTOM,
    }
    for name, value in consts.items():
        lines.append(f'%define {name} {value}')
    for name, index in ui.items():
        lines.append(f'%define C_{name} {index}')
    lines.append('%macro BUTTON_TABLE 0')
    for x, w in BUTTONS:
        lines.append(f'    dw {x}, {w}')
    lines.append('%endmacro')
    lines.append('%macro DIGIT_TABLE 0')
    lines.append('    dw ' + ', '.join(str(x) for x in DIGIT_X))
    lines.append('%endmacro')
    (HERE.parent / 'assets.inc').write_text('\n'.join(lines) + '\n', newline='\n')
    print(f'assets.bin: {len(blob)} bytes, logo {logo_rgb.width}x{logo_rgb.height}')


if __name__ == '__main__':
    main()
