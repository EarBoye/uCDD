# SPDX-License-Identifier: GPL-3.0-only

"""Checks beside the session: the drawing routines and the analyzer on random
inputs, and the physical-output and calibration code against a scripted
machine. Each takes two build directories, A and B."""

import math, random, struct
from unicorn import UC_HOOK_INTR, UC_HOOK_MEM_READ
from unicorn import x86_const as X
from player import Player, Session

REGS = [X.UC_X86_REG_EAX, X.UC_X86_REG_EBX, X.UC_X86_REG_ECX, X.UC_X86_REG_EDX,
        X.UC_X86_REG_ESI, X.UC_X86_REG_EDI, X.UC_X86_REG_EBP]

ROUTINES = {'sprite': 'draw_sprite', 'shade': 'shade_sprite', 'span': 'masked_span',
            'offset': 'pixel_offset', 'put': 'put_pixel', 'masked': 'put_masked',
            'fill': 'fill_rect', 'shaderect': 'shade_rect', 'text': 'draw_text',
            'tiny': 'draw_tiny', 'line': 'draw_line'}


def pixels(a, b, cases=4000, seed=7, out=print):
    """The pixel routines with random arguments on random back buffers: the
    same pixels and the same registers. Return the number of differences."""
    A, B = Player(a), Player(b)
    for p in (A, B):
        Session(p, 1).setup()
    rng = random.Random(seed)
    sprite_end = min(A.asset_bytes, B.asset_bytes)
    starts = [A.k[n] for n in ('A_LOGO', 'A_DIGITS', 'A_KNOB', 'A_CURSOR')]

    def coord():
        r = rng.random()
        if r < 0.6:
            return rng.randint(-40, 360) & 0xffff
        if r < 0.8:
            return rng.choice([0, 1, 199, 200, 318, 319, 320, 0xffff, 0x8000, 0x7fff, 65530])
        return rng.randint(0, 0xffff)

    bad = 0
    for n in range(cases):
        back = bytes(rng.getrandbits(8) for _ in range(64000))
        kind = rng.choice(sorted(ROUTINES))
        regs = dict(eax=coord(), ebx=coord(), ecx=rng.randint(1, 200), edx=rng.randint(1, 30),
                    esi=rng.choice(starts) + rng.randint(0, 40),
                    edi=rng.getrandbits(16), ebp=rng.getrandbits(16))
        # A sprite stays inside the assets: past them lies the program,
        # which differs between builds.
        regs['edx'] = max(1, min(regs['edx'], (sprite_end - regs['esi']) // regs['ecx']))
        if kind in ('fill', 'shaderect'):
            # Unclipped: their callers keep them on the screen.
            regs['eax'] = rng.randint(0, 319)
            regs['ebx'] = rng.randint(0, 199)
            regs['ecx'] = rng.randint(1, 330 - regs['eax'])
            regs['edx'] = rng.randint(1, 200 - regs['ebx'])
        if kind in ('text', 'tiny'):
            text = bytes(rng.randint(1, 255) for _ in range(rng.randint(0, 40))) + b'\0'
        if kind == 'line':
            for r in ('eax', 'ebx', 'ecx', 'edx'):
                regs[r] = rng.randint(-400, 700) & 0xffff
            clip = [rng.choice([0, rng.randint(-50, 330)]) for _ in range(4)]
        mask = rng.randint(0, 1)
        results = []
        for p in (A, B):
            p.mu.mem_write(p.back * 16, back)
            p.w8('sprite_mask', mask)
            p.w8('draw_color', regs['edx'] * 7 & 0xff)
            if kind == 'line':
                for name, v in zip(('clip_left', 'clip_top', 'clip_right', 'clip_bottom'), clip):
                    p.w16(name, v)
            if kind in ('text', 'tiny'):
                p.mu.mem_write(p.addr('message_buffer'), text)
                regs['esi'] = p.sym['message_buffer']
            p.call(ROUTINES[kind], **regs)
            rv = [p.mu.reg_read(r) & 0xffff for r in REGS]
            if kind in ('text', 'tiny'):
                rv[4] = 0  # SI: the buffer's address differs between builds
            results.append((bytes(p.mu.mem_read(p.back * 16, 64000)), rv))
        if results[0] != results[1]:
            bad += 1
            out('differs: %s %s mask %d' % (kind, {k: hex(v) for k, v in regs.items()}, mask))
            if bad > 10:
                break
    return bad


def analyzer(a, b, rings=300, seed=3):
    """analyze on random rings (noise, full-scale squares, sweeps): the same
    FFT arrays, bars and needle targets. Return the number of differences."""
    A, B = Player(a), Player(b)
    for p in (A, B):
        Session(p, 1).setup()
    rng = random.Random(seed)
    bad = 0
    for n in range(rings):
        if n % 3 == 0:
            ring = bytes(rng.getrandbits(8) for _ in range(4096))
        elif n % 3 == 1:
            ring = b''.join(struct.pack('<hh', rng.choice([32767, -32768]), rng.choice([32767, -32768]))
                            for _ in range(1024))
        else:
            f = rng.random()
            ring = b''.join(struct.pack('<hh', int(32767 * math.sin(i * f)), int(-32768 * math.cos(i * 0.1)))
                            for i in range(1024))
        pos = rng.randint(0, 1023)
        results = []
        for p in (A, B):
            p.mu.mem_write(p.addr('ring'), ring)
            p.w16('ring_pos', pos)
            p.call('analyze')
            results.append((bytes(p.mu.mem_read(p.work * 16, p.k['W_BITREV'])),
                            bytes(p.mu.mem_read(p.addr('bar_level'), 3 * p.k['ANA_BARS'])),
                            bytes(p.mu.mem_read(p.addr('vu_target'), 2))))
        bad += results[0] != results[1]
    return bad


class ScriptedSB16(Player):
    """A Sound Blaster 16 at 220h as physical_config reads it, a driver
    control entry that answers 0, BLASTER in the environment, and an MSCDEX
    that records the request it gets and answers done."""

    def __init__(self, d, mixer80, mixer81):
        self.mixer = {0x80: mixer80, 0x81: mixer81, 0x32: 0xc0, 0x33: 0xc0}
        self.replies, self.index, self.writes, self.request = [], 0, [], None
        super().__init__(d)
        self.mu.hook_add(UC_HOOK_INTR, self._int)
        self.mu.mem_write(0x6000, b'\x31\xc0\xcb')  # XOR AX,AX / RETF at 0600:0000
        self.w32('audio_control_entry', 0x0600 << 16)
        self.mu.mem_write(0x7000, b'COMSPEC=C:\\COMMAND.COM\0BLASTER=A220 I5 D1 H5 T6\0\0')
        self.mu.mem_write(0x1000 * 16 + 0x2c, struct.pack('<H', 0x700))

    def _out(self, mu, port, size, value, data):
        value &= 0xff
        self.writes.append((port, value))
        if port == 0x226 and value == 0:
            self.replies = [0xaa]
        elif port == 0x22c and value == 0xe1:
            self.replies = [4, 13]
        elif port == 0x224:
            self.index = value

    def _in(self, mu, port, size, data):
        if port == 0x22e:
            return 0x80 if self.replies else 0
        if port == 0x22a:
            return self.replies.pop(0) if self.replies else 0xff
        if port == 0x225:
            return self.mixer.get(self.index, 0)
        return 0

    def _int(self, mu, intno, data):
        if intno == 0x2f and mu.reg_read(X.UC_X86_REG_AX) == 0x1510:
            es, bx = mu.reg_read(X.UC_X86_REG_ES), mu.reg_read(X.UC_X86_REG_BX)
            self.request = bytes(mu.mem_read(es * 16 + bx, 28))
            mu.mem_write(es * 16 + bx + 3, struct.pack('<H', 0x0100))


def physical(d, out=print):
    """Report physical_config's reading of mixer 80h/81h, the volume writes
    and the READ LONG request, for one build."""
    for m80, m81 in ((2, 0x22), (4, 0x40), (0xf2, 0x22), (0xf4, 0x82), (8, 0x22),
                     (6, 0x22), (1, 0x22), (2, 0x60)):
        p = ScriptedSB16(d, m80, m81)
        p.call('physical_config')
        cf = p.mu.reg_read(X.UC_X86_REG_EFLAGS) & 1
        out('  mixer 80h=%02Xh 81h=%02Xh: %s' % (
            m80, m81, 'refused' if cf else 'IRQ %d, DMA %d' % (p.r8('phy_irq'), p.r8('phy_dma'))))
    p = ScriptedSB16(d, 2, 0x22)
    p.call('physical_config')
    p.w8('phy_running', 1)
    p.w8('volume', 0xff)
    p.writes = []
    p.call('physical_volume')
    out('  volume 255 writes: ' + ' '.join('%03Xh=%02Xh' % w for w in p.writes))
    p.w16('phy_segment', 0x8000)
    p.w32('phy_lba', 1000)
    p.w32('range_end', 2000)
    p.w8('first_track', 1)
    p.w8('last_track', 1)
    for i in range(16):
        p.w8('control_block', 11, i)  # the last IOCTL code, as after read_disc
    p.call('physical_fill', gs=p.gsbuf)
    out('  READ LONG request: ' + p.request.hex(' '))


def midnight(d, out=print):
    """eq_calibrate started mid-day and two ticks before the midnight wrap,
    the tick advancing as the loop polls it."""
    for start in (0x10000, 0x1800ae):
        p = Player(d)
        Session(p, 1).setup()
        p.w8('eq_slow', 0)
        tick = [start, 0]
        p.mu.mem_write(0x46c, struct.pack('<I', start))

        def read(mu, access, address, size, value, data):
            if address == 0x46c:
                tick[1] += 1
                if tick[1] % 300 == 0:
                    tick[0] = (tick[0] + 1) % 0x1800b0
                    mu.mem_write(0x46c, struct.pack('<I', tick[0]))

        p.mu.hook_add(UC_HOOK_MEM_READ, read, None, 0x46c, 0x46f)
        p.call('eq_calibrate')
        out('  started at %06Xh: eq_slow %d after %d polls' % (start, p.r8('eq_slow'), tick[1]))
