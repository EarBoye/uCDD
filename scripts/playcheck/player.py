# SPDX-License-Identifier: GPL-3.0-only

"""UCDDPLAY in an emulator: its own routines run in Unicorn on its own image.

Player loads a build of src/play.asm as DOS would load UCDDPLAY.EXE and calls
any routine by name. Session drives a scripted run of the player through its
routines and records, after every frame, everything a later frame or the user
can see, so that two builds can be compared frame by frame. profile() counts
instructions per routine with rough clock estimates.
"""

import bisect, hashlib, json, math, os, random, re, struct, subprocess
from unicorn import Uc, UC_ARCH_X86, UC_MODE_16, UC_HOOK_CODE, UC_HOOK_INSN, UC_HOOK_MEM_WRITE
from unicorn import x86_const as X

PSP = 0x1000
STUB = 0xFFF0


def read_defines(src):
    """The numeric %defines of the player, evaluated as NASM would."""
    names = {}
    for rel in ('src/play/assets.inc', 'src/play/defs.inc', 'src/play.asm'):
        with open(os.path.join(src, rel)) as f:
            for line in f:
                m = re.match(r'%define\s+(\w+)\s+(.+?)\s*(;.*)?$', line)
                if not m:
                    continue
                expr = m.group(2).replace('/', '//')
                try:
                    names[m.group(1)] = int(eval(expr, {'__builtins__': {}}, dict(names)))
                except Exception:
                    pass
    return names


def build(out, src):
    """Assemble SRC/src/play.asm into OUT with a symbol map; copy the assets
    and the constants next to it."""
    os.makedirs(out, exist_ok=True)
    wrap = os.path.join(out, 'wrap.asm')
    with open(wrap, 'w') as f:
        f.write('[map all %s]\n%%include "play.asm"\n' % os.path.join(out, 'play.map'))
    subprocess.run(['nasm', '-f', 'bin', '-I', os.path.join(src, 'src') + '/', wrap,
                    '-o', os.path.join(out, 'play.bin')], check=True)
    with open(os.path.join(src, 'src/play/assets.bin'), 'rb') as f:
        assets = f.read()
    with open(os.path.join(out, 'assets.bin'), 'wb') as f:
        f.write(assets)
    with open(os.path.join(out, 'defines.json'), 'w') as f:
        json.dump(read_defines(src), f)


def read_map(path):
    with open(path) as f:
        part = f.read().split('-- Symbols')[1]
    syms = {}
    for line in part.splitlines():
        m = re.match(r'\s*([0-9A-F]+)\s+([0-9A-F]+)\s+(\S+)$', line)
        if m:
            syms[m.group(3)] = int(m.group(1), 16)
    return syms


def reg(name):
    return getattr(X, 'UC_X86_REG_' + name.upper())


class Player:
    """A build in emulated memory. shadow=False leaves shadow_seg 0, as when
    DOS has no room for the screen copy."""

    def __init__(self, d, shadow=True):
        with open(os.path.join(d, 'play.bin'), 'rb') as f:
            self.prog = f.read()
        with open(os.path.join(d, 'assets.bin'), 'rb') as f:
            assets = f.read()
        with open(os.path.join(d, 'defines.json')) as f:
            self.k = json.load(f)
        self.asset_bytes = len(assets) - 64000
        assets += bytes(-len(assets) % 16)
        self.sym = read_map(os.path.join(d, 'play.map'))
        k = self.k
        self.work_bytes = k['ENTRIES'] + k['ENTRY_MAX'] * k['ENTRY_SIZE']
        # The segments as the player's start code would set them up.
        self.face = PSP + 0x10
        self.code = self.face + len(assets) // 16
        self.extra = self.face + 4000
        self.back = self.code + 0x1000
        self.work = self.back + 4000
        self.shadow_area = self.work + (self.work_bytes + 15) // 16
        self.gsbuf = self.shadow_area + 4000
        mu = self.mu = Uc(UC_ARCH_X86, UC_MODE_16)
        mu.mem_map(0, 0x110000)
        mu.mem_write(self.face * 16, assets)
        mu.mem_write(self.code * 16, self.prog)
        mu.mem_write(self.code * 16 + STUB, b'\xf4')
        self.ports = []
        mu.hook_add(UC_HOOK_INSN, self._out, None, 1, 0, X.UC_X86_INS_OUT)
        mu.hook_add(UC_HOOK_INSN, self._in, None, 1, 0, X.UC_X86_INS_IN)
        for name, seg in (('psp_seg', PSP), ('back_seg', self.back), ('work_seg', self.work),
                          ('face_seg', self.face), ('extra_seg', self.extra)):
            self.w16(name, seg)
        if 'shadow_seg' in self.sym and shadow:
            self.w16('shadow_seg', self.shadow_area)

    # Port I/O: OUTs are recorded (the palette); 3DAh reads as in retrace.
    def _out(self, mu, port, size, value, data):
        self.ports.append((port, value & 0xff))

    def _in(self, mu, port, size, data):
        return 0x08 if port == 0x3da else 0

    def addr(self, name):
        return self.code * 16 + self.sym[name]

    def w8(self, name, v, off=0):
        self.mu.mem_write(self.addr(name) + off, struct.pack('<B', v & 0xff))

    def w16(self, name, v, off=0):
        self.mu.mem_write(self.addr(name) + off, struct.pack('<H', v & 0xffff))

    def w32(self, name, v, off=0):
        self.mu.mem_write(self.addr(name) + off, struct.pack('<I', v & 0xffffffff))

    def r8(self, name, off=0):
        return self.mu.mem_read(self.addr(name) + off, 1)[0]

    def r16(self, name, off=0):
        return struct.unpack('<H', self.mu.mem_read(self.addr(name) + off, 2))[0]

    def call(self, name, far=False, **regs):
        """Call a routine with CS = DS = SS = the program, ES = the back
        buffer, FS = the faceplate, GS = the other assets unless given."""
        mu = self.mu
        sp = self.sym['stack_top'] - 0x100
        for r, v in (('cs', self.code), ('ds', self.code), ('ss', self.code),
                     ('es', regs.pop('es', self.back)), ('fs', regs.pop('fs', self.face)),
                     ('gs', regs.pop('gs', self.extra))):
            mu.reg_write(reg(r), v)
        if far:
            sp -= 2
            mu.mem_write(self.code * 16 + sp, struct.pack('<H', self.code))
        sp -= 2
        mu.mem_write(self.code * 16 + sp, struct.pack('<H', STUB))
        mu.reg_write(X.UC_X86_REG_ESP, sp)
        for r, v in regs.items():
            mu.reg_write(reg(r), v)
        mu.emu_start(self.code * 16 + self.sym[name], self.code * 16 + STUB)


# ------------------------------------------------------------- comparison

# Variables that hold addresses in the program: compared as symbol + offset,
# since the layout moves between builds.
POINTERS = {'preset_name', 'message_text', 'label_text', 'eq_set', 'hook_set',
            'block_state', 'block_v'}

# Mutable variables outside the zero area, with their sizes.
DATA = {'disc_timer': 1, 'poll_timer': 1, 'eq_on': 1, 'eq_band': 1, 'volume': 1,
        'vis_choice': 1, 'drive_text': 3, 'browse_title_drive': 3}

# Temporaries that every user sets before reading: their value between calls
# is not state. Each entry says why.
SCRATCH = {
    'sprite_rows',  # row counter, set at the start of every sprite call
    'fft_half',     # FFT loop variables, set by analyze before use
    'fft_k',
}


def layout(p):
    """Name -> (offset, size) of every variable in the zero area and DATA."""
    items = sorted((a, n) for n, a in p.sym.items() if '.' not in n)
    lo, hi = p.sym['bss_start'], p.sym['stack_bottom']
    out = {}
    for a, n in items:
        if lo <= a < hi:
            nxt = min(x for x, _ in items if x > a)
            out[n] = (a, min(nxt, hi) - a)
    for n, size in DATA.items():
        out[n] = (p.sym[n], size)
    return out


def symbolic(p, value):
    best = None
    for n, a in p.sym.items():
        if '.' not in n and a <= value and (best is None or a > best[1]):
            best = (n, a)
    return '%s+%d' % (best[0], value - best[1]) if best else str(value)


def same_value(a, b):
    """Equal, allowing a longer hex value only by zero alignment padding."""
    if a == b:
        return True
    if not (isinstance(a, str) and isinstance(b, str)) or '+' in a or '+' in b:
        return False
    n = min(len(a), len(b))
    return a[:n] == b[:n] and set(a[n:] + b[n:]) <= {'0'}


def diff(a, b, limit=20, out=print):
    """Compare two traces. Return the number of differences."""
    bad = 0
    for i, (x, y) in enumerate(zip(a, b)):
        for key in x:
            if key == 'state':
                for n in x[key]:
                    if n in SCRATCH or n not in y[key]:
                        continue
                    if not same_value(x[key][n], y[key][n]):
                        out('frame %d: %s %s -> %s' % (i, n, str(x[key][n])[:40], str(y[key][n])[:40]))
                        bad += 1
            elif x[key] != y.get(key):
                out('frame %d: %s differs' % (i, key))
                bad += 1
        if bad > limit:
            break
    if len(a) != len(b):
        out('frames: %d against %d' % (len(a), len(b)))
        bad += 1
    return bad


# ---------------------------------------------------------------- session

class Session:
    """A scripted session: CD audio through the real eq_hook, every bottom
    display, the scroller, the label, the messages, the requester, the help
    over the requester, play, pause and stop, no disc, EQ changes and
    presets, the cursor across every screen edge.

    logo_runs=False refuses the logo tables (the old sprite path). force =
    (display, play state) holds that display with nothing over it."""

    def __init__(self, p, frames, logo_runs=True, force=None):
        self.p = p
        self.frames = frames
        self.logo_runs = logo_runs
        self.force = force
        self.rng = random.Random(1234)
        self.layout = layout(p)
        self.sample_pos = 0
        self.eq_acc = hashlib.sha1()

    def setup(self):
        p = self.p
        p.w32('random_seed', 0x1234567)
        p.mu.mem_write(0x46c, struct.pack('<I', 1000))
        p.call('init_bitreverse')
        p.call('init_visuals')
        if not self.logo_runs and 'logo_runs_ok' in p.sym:
            p.w8('logo_runs_ok', 0)
        # A disc of 12 tracks, two of them data, one with pre-emphasis.
        p.w8('disc_present', 1)
        p.w8('first_track', 1)
        p.w8('last_track', 12)
        start = 0
        for t in range(1, 14):
            p.w32('track_start', start, 4 * t)
            p.w32('track_index0', start - (0 if t == 1 else 150), 4 * t)
            start += 15000 + 997 * t
        p.w32('leadout', p.r16('track_start', 4 * 13) | p.r16('track_start', 4 * 13 + 2) << 16)
        p.w8('track_data', 1, 1)
        p.w8('track_data', 1, 7)
        p.w8('track_pre', 0x10, 4)
        p.w8('first_audio', 2)
        p.w8('audio_count', 10)
        p.w8('track', 3)
        p.call('build_order')
        p.w8('play_state', 1)
        p.w8('hook_active', 1)
        p.w8('mouse_present', 1)
        p.w8('eq_slow', 0)
        p.call('eq_preset', eax=0)
        # The requester's entries.
        k = p.k
        names = ['C: CD-ROM', '..', 'GAMES', 'MUSIC', 'DOOM.CUE', 'QUAKE.BIN', 'TOMB.ISO',
                 'A.MDM', 'B.CUE', 'C.ISO', 'D.BIN', 'E.CUE']
        for i, n in enumerate(names):
            t = 0 if i == 0 else 1 if i == 1 else 2 if i < 4 else 3
            e = bytes([t]) + n.encode().ljust(13, b'\0') + struct.pack('<H', i * 37)
            p.mu.mem_write(p.work * 16 + k['ENTRIES'] + i * k['ENTRY_SIZE'], e)
        p.w16('entry_count', len(names))
        p.w16('entry_selected', 5)
        p.w16('entry_top', 2)
        for i, c in enumerate(b'C:\\GAMES\\CD\\\0'):
            p.w8('browse_path', c, i)

    def audio(self, frame):
        """One video frame of CD audio through eq_hook, in driver-sized calls:
        64 frames mostly, odd sizes sometimes, full-scale squares at times."""
        p = self.p
        total = 630
        while total > 0:
            n = min(total, self.rng.choice([64, 64, 64, 32, 17, 100, 64]))
            buf = bytearray()
            for i in range(n):
                t = self.sample_pos / 44100.0
                level = 0.5 + 0.5 * math.sin(t * 0.7)
                l = 9000 * math.sin(2 * math.pi * 110 * t) + 5000 * math.sin(2 * math.pi * 2500 * t)
                r = 7000 * math.sin(2 * math.pi * 440 * t) + 3000 * math.sin(2 * math.pi * 9000 * t)
                l = l * level + self.rng.randint(-1500, 1500)
                r = r * level + self.rng.randint(-1500, 1500)
                if frame % 300 > 280:
                    l, r = 32767 * (1 if i & 8 else -1), -32768
                buf += struct.pack('<hh', max(-32768, min(32767, int(l))), max(-32768, min(32767, int(r))))
                self.sample_pos += 1
            p.mu.mem_write(p.gsbuf * 16, bytes(buf))
            p.call('eq_hook', far=True, gs=p.gsbuf, ebx=0, ecx=len(buf), edx=self.sample_pos * 4 - len(buf))
            self.eq_acc.update(p.mu.mem_read(p.gsbuf * 16, len(buf)))
            total -= n

    def events(self, f):
        p = self.p
        if f % 90 == 0:
            p.call('set_visual', eax=(f // 90) % 7)
        if f % 90 == 45:
            p.call('select_visual')
        if f % 400 == 200:
            p.call('show_message', esi=p.sym['message_bad_mdm'])
        if f % 400 == 230:
            p.call('show_message', esi=p.sym['message_no_disc'])
        if f % 37 == 0:
            p.call('eq_change', eax=((f // 37) % 11) | ((1 if f % 74 else -3) & 0xff) << 8)
        if f % 211 == 100:
            p.w8('eq_on', p.r8('eq_on') ^ 1)
            p.call('eq_apply')
        for start, end, name in ((120, 170, 'browser_active'), (140, 160, 'help_active'),
                                 (300, 330, 'help_active')):
            if f % 500 == start:
                p.w8(name, 1)
            if f % 500 == end:
                p.w8(name, 0)
        if f % 600 == 400:
            p.w8('play_state', 2)
        if f % 600 == 440:
            p.w8('play_state', 0)
        if f % 600 == 470:
            p.w8('play_state', 1)
        if f % 700 == 600:
            p.w8('disc_present', 0)
        if f % 700 == 640:
            p.w8('disc_present', 1)
        if f % 53 == 0:
            p.w8('button_flash', 6, (f // 53) % 8)
        if f % 77 == 10:
            p.w8('shuffle', p.r8('shuffle') ^ 1)
            p.w8('repeat_mode', (p.r8('repeat_mode') + 1) % 3)
            p.w8('volume', (p.r8('volume') + 61) & 0xff)
        if 650 <= f % 700 < 690:
            # Stopped, nothing over the bottom window: the scroller.
            p.w8('play_state', 0)
            p.w8('label_active', 0)
            p.w16('message_timer', 0)
        if f % 700 == 690:
            p.w8('play_state', 1)
        p.w16('mouse_x', int(160 + 170 * math.sin(f * 0.031)) & 0xffff)
        p.w16('mouse_y', int(100 + 110 * math.cos(f * 0.023)) & 0xffff)
        p.w32('relative', f * 5 - 40)
        p.w32('position', 20000 + f * 5)
        p.w8('track', 3 + (f // 250) % 9)
        p.mu.mem_write(0x46c, struct.pack('<I', 1000 + f * 182 // 700))
        if self.force:
            vis, state = self.force
            if p.r8('vis_mode') != vis:
                p.call('set_visual', eax=vis)
            p.w8('play_state', state)
            p.w16('message_timer', 0)
            for name in ('label_active', 'browser_active', 'help_active'):
                p.w8(name, 0)
            p.w8('disc_present', 1)

    def frame(self, f):
        """One turn of main_loop, without the keyboard, mouse and drive."""
        p = self.p
        self.events(f)
        if p.r8('play_state') == 1:
            self.audio(f)
        if not (p.r16('frame') & 1):
            if p.r8('play_state') == 1 and p.r8('hook_active'):
                p.call('analyze')
            else:
                p.call('analyze_idle')
        p.call('render')
        p.call('animate_palette')
        p.call('present')
        p.w16('frame', p.r16('frame') + 1)

    def state(self):
        p = self.p
        out = {}
        for n, (a, size) in self.layout.items():
            raw = bytes(p.mu.mem_read(p.code * 16 + a, size))
            if n in POINTERS:
                out[n] = symbolic(p, struct.unpack('<H', raw[:2])[0])
            else:
                out[n] = raw.hex()
        return out

    def work_digest(self):
        p, k = self.p, self.p.k
        work = bytearray(p.mu.mem_read(p.work * 16, p.work_bytes))
        w, h = k['SCROLL_W'], k['SCROLL_H']
        # The fire's colour buffer: the old draw_fire wrote it and draw_buffer
        # read it in the same frame; nothing else reads it.
        lo = k['W_FIRE'] + k['FIRE_ROWS'] * w
        work[lo:lo + w * h] = bytes(w * h)
        # The plasma's rows: the old draw_plasma wrote them and draw_buffer
        # read them in the same frame; set_visual clears them.
        if p.r8('vis_mode') == 5:
            lo = k['W_FIRE'] + w
            work[lo:lo + w * h] = bytes(w * h)
        return hashlib.sha1(work).hexdigest()

    def run(self):
        """The session; a digest of what is visible after each frame."""
        p = self.p
        self.setup()
        rows = []
        for f in range(self.frames):
            self.frame(f)
            rows.append({
                'screen': hashlib.sha1(p.mu.mem_read(0xa0000, 64000)).hexdigest(),
                'ports': hashlib.sha1(json.dumps(p.ports).encode()).hexdigest(),
                'back': hashlib.sha1(p.mu.mem_read(p.back * 16, 64000)).hexdigest(),
                'work': self.work_digest(),
                'eq': self.eq_acc.hexdigest(),
                'state': self.state(),
            })
            p.ports = []
        return rows


# ---------------------------------------------------------------- profile

# Rough clock counts: 386 from the 80386 programmer's reference (no wait
# states, mid-range for data-dependent ones), Pentium from the Pentium
# manual, ignoring pairing. Estimates for ranking, not timing.
# mnemonic: (386 register form, 386 with memory, Pentium register, Pentium memory)
CLOCKS = {
    'mov': (2, 4, 1, 1), 'movzx': (3, 6, 3, 3), 'movsx': (3, 6, 3, 3), 'lea': (2, 2, 1, 1),
    'add': (2, 7, 1, 3), 'sub': (2, 7, 1, 3), 'and': (2, 7, 1, 3), 'or': (2, 7, 1, 3),
    'xor': (2, 7, 1, 3), 'cmp': (2, 6, 1, 2), 'test': (2, 5, 1, 2), 'adc': (2, 7, 1, 3),
    'sbb': (2, 7, 1, 3), 'inc': (2, 6, 1, 3), 'dec': (2, 6, 1, 3), 'neg': (2, 6, 1, 3),
    'not': (2, 6, 1, 3), 'push': (2, 5, 1, 2), 'pop': (4, 5, 1, 3), 'pushal': (18, 18, 5, 5),
    'popal': (24, 24, 5, 5), 'pushaw': (18, 18, 5, 5), 'popaw': (24, 24, 5, 5),
    'pusha': (18, 18, 5, 5), 'popa': (24, 24, 5, 5), 'pushf': (4, 4, 4, 4), 'popf': (5, 5, 6, 6),
    'shl': (3, 7, 1, 3), 'shr': (3, 7, 1, 3), 'sar': (3, 7, 1, 3), 'rol': (3, 7, 1, 3),
    'ror': (3, 7, 1, 3), 'rcl': (9, 10, 7, 8), 'rcr': (9, 10, 7, 8), 'shrd': (3, 7, 4, 4),
    'shld': (3, 7, 4, 4), 'bt': (3, 12, 4, 9), 'bts': (6, 13, 7, 13), 'bsr': (20, 20, 10, 10),
    'imul': (22, 25, 10, 10), 'mul': (22, 25, 10, 11), 'div': (30, 33, 25, 25), 'idiv': (35, 38, 30, 30),
    'jmp': (8, 11, 1, 2), 'call': (8, 11, 1, 2), 'ret': (11, 11, 2, 2), 'retf': (18, 18, 4, 4),
    'loop': (12, 12, 6, 6), 'jcxz': (9, 9, 6, 6), 'jecxz': (9, 9, 6, 6),
    'xchg': (3, 5, 3, 3), 'cwd': (2, 2, 2, 2), 'cdq': (2, 2, 2, 2), 'cbw': (3, 3, 3, 3),
    'cwde': (3, 3, 3, 3), 'aam': (17, 17, 18, 18), 'aad': (19, 19, 10, 10),
    'clc': (2, 2, 2, 2), 'stc': (2, 2, 2, 2), 'cld': (2, 2, 2, 2), 'cli': (3, 3, 7, 7),
    'sti': (3, 3, 7, 7), 'nop': (3, 3, 1, 1), 'cmc': (2, 2, 2, 2),
    'stosb': (4, 4, 3, 3), 'stosw': (4, 4, 3, 3), 'stosd': (4, 4, 3, 3), 'lodsb': (5, 5, 2, 2),
    'lodsw': (5, 5, 2, 2), 'lodsd': (5, 5, 2, 2), 'movsb': (7, 7, 4, 4), 'movsw': (7, 7, 4, 4),
    'movsd': (7, 7, 4, 4), 'cmpsd': (10, 10, 5, 5), 'cmpsb': (10, 10, 5, 5), 'cmpsw': (10, 10, 5, 5),
    'scasb': (7, 7, 4, 4), 'in': (12, 12, 7, 7), 'out': (10, 10, 12, 12), 'outsb': (14, 14, 13, 13),
    'xlatb': (5, 5, 4, 4), 'lds': (7, 7, 4, 4), 'les': (7, 7, 4, 4), 'lfs': (7, 7, 4, 4),
    'lgs': (7, 7, 4, 4), 'hlt': (0, 0, 0, 0),
}

# Clocks per iteration of the string instructions under REP: (386, Pentium).
REP_CLOCKS = {'movsd': (4, 1), 'movsw': (4, 1), 'movsb': (4, 1), 'stosd': (5, 1), 'stosw': (5, 1),
              'stosb': (5, 1), 'cmpsd': (9, 4), 'cmpsb': (9, 4), 'cmpsw': (9, 4), 'outsb': (5, 13),
              'scasb': (8, 4), 'lodsb': (5, 2)}


def profile(d, frames=40, skip=12, force=None, shadow=True):
    """Run the session for SKIP frames, then count FRAMES. Return
    {routine: [instructions, 386 clocks, Pentium clocks]} per frame and the
    bytes written to video memory per frame."""
    import capstone
    p = Player(d, shadow=shadow)
    s = Session(p, skip + frames, force=force)
    md = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_16)
    names = sorted((a, n) for n, a in p.sym.items() if '.' not in n)
    addrs = [a for a, _ in names]
    base = p.code * 16
    cache, stats, vga, last, on = {}, {}, [0], [None], [False]

    def decode(ip):
        if ip not in cache:
            ins = next(md.disasm(bytes(p.mu.mem_read(base + ip, 15)), ip))
            mnem = ins.mnemonic
            rep = mnem.startswith('rep')
            mnem = mnem.split()[-1]
            c = CLOCKS.get(mnem, (7, 7, 1, 1) if mnem.startswith('j') else (5, 8, 2, 3))
            memop = '[' in ins.op_str
            owner = names[bisect.bisect_right(addrs, ip) - 1][1]
            cache[ip] = (owner, mnem, rep, c[1] if memop else c[0], c[3] if memop else c[2])
        return cache[ip]

    # The hook is added before the first instruction runs: code translated
    # before a hook exists is not instrumented.
    def hook(mu, address, size, data):
        if not on[0]:
            return
        ip = address - base
        if not 0 <= ip < len(p.prog):
            return
        owner, mnem, rep, c386, cp5 = decode(ip)
        st = stats.setdefault(owner, [0, 0, 0])
        if rep:
            # The hook sees every iteration of a REP instruction.
            r386, rp5 = REP_CLOCKS.get(mnem, (5, 2))
            if last[0] != ip:
                st[0] += 1
                st[1] += 5
                st[2] += 3
            st[1] += r386
            st[2] += rp5
        else:
            st[0] += 1
            st[1] += c386
            st[2] += cp5
        last[0] = ip

    def screen_write(mu, access, address, size, value, data):
        if on[0]:
            vga[0] += size

    p.mu.hook_add(UC_HOOK_CODE, hook, None, base, base + len(p.prog))
    p.mu.hook_add(UC_HOOK_MEM_WRITE, screen_write, None, 0xa0000, 0xaffff)
    s.setup()
    for f in range(skip):
        s.frame(f)
    on[0] = True
    for f in range(skip, skip + frames):
        s.frame(f)
    return {n: [v / frames for v in st] for n, st in stats.items()}, vga[0] / frames
