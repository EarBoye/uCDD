# LucasArts: iMUSE and the SCUMM drivers

LucasArts wrote its own sound code. iMUSE (Michael Land and Peter
McConnell's interactive music system, 1991-1998) drives the music in the
SCUMM adventures from Monkey Island 2 on and in the Star Wars flight and
action games; digital effects and speech go through LucasArts' own
digital drivers. The scan found iMUSE in X-Wing CD, TIE Fighter CD and
Dark Forces; the SCUMM games of the disc-only kind (Sam & Max, The Dig,
Indiana Jones and the Fate of Atlantis) carry it on their discs. Monkey
Island 1 and Day of the Tentacle show Creative's detection code. See
[inventory](inventory.md).

Grades as in the [README](README.md#evidence-grades).

## Files and configuration

| File | What it is |
|---|---|
| `IMUSE.INI` / `SETMUSE.INI` | Binary: driver file names and settings: `FM4.MDR` (OPL3), `FM2.MDR` (OPL2), `GMIDI.MDR` (General MIDI), `AWEMID.MDR`, each with a settings word (0330h after GMIDI.MDR, the MPU-401's port), and `SB16.WDR` (the digital driver) followed by a word whose meaning is not known (0Fh, 0Bh) [file, TIE Fighter CD and floppy] |
| `*.MDR` | Music drivers |
| `*.WDR` | Wave (digital) drivers |
| `TIE2.ADV` | TIE Fighter's floppy edition carries a Miles AIL 2 driver as well [file] |

## What the digital driver does

Dark Forces, TIE Fighter CD [trace]:

1. **Mixer 80h and 81h read before anything else**, even before the
   reset: the IRQ and DMA come from the card (F4h: IRQ 7; 22h: DMA 1
   and 5).
2. Reset, AAh, E1h (4.13), D1h (Dark Forces; TIE Fighter's kept trace starts at D1h).
3. The 8237: DMA 1, mode 59h, 2048 bytes (Dark Forces) or 1024 (TIE
   Fighter).
4. **A time constant (40h A5h, 10989 Hz) with the SB16's C6h**: 8-bit
   stereo (mode 20h), auto-init, FIFO on, 1024 samples (Dark Forces) or
   512 (TIE Fighter). On a 4.xx the time constant sets the same rate
   register as 41h (vsb-spec.md section 13).
5. **The position by count, read twice**: clear the flip-flop, low, high,
   low, high; the two values are compared. Interrupts are taken (2xEh)
   but the mixing follows the count.

X-Wing CD's detection (also the older SCUMM games') is Creative's: E0h
C6h (expects 39h), F2h with every master line masked but the timer (mask
FEh), D3h, E0h AAh, E1h [trace].

## What uCDD needs for LucasArts

| Item | What it does | What it needs |
|---|---|---|
| 80h/81h first | trusts the card's own IRQ/DMA registers | the card's real settings in 80h/81h |
| Time constant on a 4.xx | 40h with C6h | the 4.xx rate register shared by 40h and 41h |
| Count read twice | compares two counts | a count that never moves backwards (see [findings](findings.md), F2: Dark Forces' count rose by 104 bytes 19 times; on `count-position` since 24 Oct the count cannot step back and the clock no longer aliases [86Box], yet Dark Forces' sound check is unchanged: its fault is elsewhere) |
| Mask FEh during F2h | only the timer open | the F2h interrupt must wait for the game to open the line, as a real PIC holds the request |

## Music and timer [trace]

Monkey Island 1 switches the timer between 170.5 Hz and 18.2 Hz
repeatedly and writes the OPL2 with no status reads (800 writes in a
one-second burst). TIE Fighter's run used General MIDI (no FM). Detail in
[music-and-timers.md](music-and-timers.md).

## On the cards before the SB16 [trace]

On an SB Pro or SB 2.0 the iMUSE games read mixer 80h/81h and then make no card traffic at all. See [pre-sb16.md](pre-sb16.md).

## Quick reference

| | LucasArts digital (SB16) |
|---|---|
| Detect | 80h/81h, reset, E1h (older: E0h C6h) |
| IRQ found by | mixer 80h (older: F2h) |
| DMA | 8-bit auto-init |
| Rate | time constant, also on the SB16 |
| Acknowledge | 2xEh |
| Position | **the count, read twice and compared** |
| Music | iMUSE through .MDR drivers (OPL2/OPL3/GM/AWE) |
