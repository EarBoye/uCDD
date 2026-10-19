# DMX (Digital Expressions)

Paul Radek's DMX library, licensed by id Software and Raven: Doom, Doom II,
Final Doom, Heretic, Hexen, Strife, Raptor. Eight games here, and four
more carry it on their discs. See [inventory](inventory.md).

Grades as in the [README](README.md#evidence-grades).

## Configuration

The game's own `DEFAULT.CFG` (Doom) or `HERETIC.CFG`/`HEXEN.CFG` [file,
Doom]:

```
snd_musicdevice   3      (3: Sound Blaster, its OPL)
snd_sfxdevice     3      (3: Sound Blaster)
snd_sbport        544    (decimal: 220h)
snd_sbirq         7
snd_sbdma         1
snd_mport         816    (decimal: 330h, the MPU-401)
snd_channels      8
```

The device numbers are the setup program's list [recall: 0 none,
1 PC speaker, 2 AdLib, 3 Sound Blaster, 4 Pro Audio Spectrum, 5 GUS,
6 WaveBlaster, 7 Sound Canvas, 8 General MIDI]. The ports are decimal.
GUS patches come from `DMXGUS.INI`.

## What the Sound Blaster driver does [trace]

Doom, Doom II, Hexen, Raptor, and Strife after its own preamble; all on a
virtual SB16 at 220h, IRQ 7, DMA 1. The sequence is identical in all of
them:

1. Reset, AAh. **E1h**: the version picks the SB16 path (4.xx) or the
   older one.
2. **The IRQ test, on every candidate line at once.** The PIC mask steps
   B8h, B0h, A0h, 80h, 00h: IRQ 3, 4, 5 and 7 are unmasked one after
   another with a handler on each, then F2h is sent twice; the handler
   that runs names the line. The mask then steps back 08h, 18h, 38h, B8h
   and only the found line is opened (38h for IRQ 7). The configured
   `snd_sbirq` does not stop the test.
3. E1h again.
4. The 8237: DMA 1, **mode 19h: demand mode**, auto-init, read; 4096 bytes.
5. 41h: 11025 Hz.
6. **C6h mode 20h, length 255**: 8-bit stereo, auto-init, FIFO on,
   256 samples (128 stereo frames, 11.6 ms) per block, sixteen blocks
   in the buffer.
7. **The handler**, once per block: mixer 82h, 2xEh (acknowledge), then
   the 8237 count twice (flip-flop, low, high, two times), which it uses
   to find the block being played.

On a card older than the SB16 the same driver uses the SB Pro path: the
output filter bit (mixer 0Eh, bit 5) and a time constant, 128 stereo
frames at 11.1 kHz, 11.5 ms a block (ISSUES.md, output period table).
Doom also wrote mixer 0Eh=20h on the SB16, a register the CT1745 does not
have (harmless).

### Strife's preamble

Before DMX starts, Strife runs a different detection [trace]: time
constant 04h with **80h** (a DMA-less silence of length 0, used to see the
interrupt), time constant B3h and a 10-byte **14h** single-cycle transfer
(the DMA check), E1h, D0h, then 1469 samples of 8-bit mono at 22050 Hz
(C6h mode 00h), D0h twice. Then DMX's own steps 1 to 7 follow. Who owns
the preamble (the game's voice code or a launcher) is not known.

## What uCDD needs for DMX

| Item | What DMX does | What it needs | Where |
|---|---|---|---|
| Short blocks | 11.5-11.6 ms blocks | the output period at most half that: 128 frames works, 256 is silent on a virtual SB Pro | ISSUES.md, output period table |
| All lines open for F2h | unmasks four IRQs at once and fires F2h twice | exactly one interrupt per F2h, on the card's line only | miles.md, F2h |
| Demand mode | 8237 mode 19h | demand accepted as single (the emulation moves data a period at a time) | host-cdrom-spec.md D4 |
| Count read in the handler | twice, to find the block | a count that is not ahead of the mix | ISSUES.md `virtual-timing` |
| IRQ 7 timing | Doom's timedemo, used as uCDD's speed check | | 1807/1787 realtics on the PC (ES22), about 1640 in 86Box |

## Music and timer [trace]

The timer at **140.0 Hz** (mode 3, reload 8522), the same in Doom and
Hexen. Music on the **OPL2 only** (no second bank, even on an OPL3), 30
status reads per write, the whole instrument rewritten for every note.
Detail in [music-and-timers.md](music-and-timers.md).

## On the cards before the SB16 [trace]

On an SB Pro DMX switches to stereo high speed after a 12-byte priming transfer, on an SB 2.0 to mono 1Ch; under uCDD its SB Pro stereo stalls when both cards share IRQ 7 (findings F4). See [pre-sb16.md](pre-sb16.md).

## Quick reference

| | DMX (SB16 path) |
|---|---|
| Detect | reset, E1h |
| IRQ found by | F2h with IRQ 3, 4, 5, 7 open together |
| DMA | DMA 1, demand mode, auto-init, 4096 bytes |
| Rate | 41h 11025 Hz (SB16), time constant (older cards) |
| Format | 8-bit stereo, 128-frame blocks |
| Acknowledge | 82h, then 2xEh |
| Position | interrupt per block, plus two count reads in the handler |
| Music | OPL through its own code, or MPU-401, or GUS |
