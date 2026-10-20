# Miles: AIL 2 and the Miles Sound System 3

John Miles' Audio Interface Library (Miles Design, from 1991) and its
successor, the Miles Sound System (from 1994, RAD Game Tools from 1996).
The largest family in the libraries: about 130 games (see
[inventory](inventory.md)). Two generations that look alike from a
distance and work differently up close.

| | AIL 2 (1991-1994) | MSS 3 (1994-1997) |
|---|---|---|
| Driver files | `*.ADV`: one per device, digital and music separate (SBDIG.ADV, SBPDIG.ADV, SBFM.ADV, ADLIB.ADV, MT32MPU.ADV, PCSPKR48.ADV) [file] | `*.DIG` (digital) and `*.MDI` (music), header `AIL3DIG` / `AIL3MDI` [file] |
| Configuration | the game's own file, often binary (CASTLES2.CFG: ten bytes) [file] | `DIG.INI` and `MDI.INI`, plain text, written by SETSOUND or the game's setup [file] |
| Runs in | real mode; a protected-mode game calls it through the extender | real mode too: the .DIG is a 16-bit driver called through a real-mode thunk from the 32-bit library [recall] |
| Music data | XMIDI (`.XMI`), the AIL's extended MIDI | XMIDI, also MIDI through the same .MDI drivers |
| Games here | Castles II, SimCity Enhanced, Wing Commander Armada, Lemmings 2, Ultima VII; Kyrandia and Dune II have its SB Pro driver built in ([own-code.md](own-code.md)); the 32-bit AIL/32 below (LBA, Serf City) | Theme Hospital, System Shock, Mortal Kombat, Albion, Dungeon Keeper, Warcraft, Heroes 2... |

Grades: **[trace]** an 86Box trace through uCDD's port trap (emulator);
**[file]** read from the game's own files; **[doc]** a cited document;
**[hw]** Michael's PC; **[recall]** background knowledge not checked here.
See [README](README.md#evidence-grades).

## AIL 2

### The driver file

An `.ADV` file starts with a word 002Dh, a copyright string ending in 1Ah,
then a table of (function number, code offset) word pairs ending in FFFFh
[file, SBPDIG.ADV, SBFM.ADV, ADLIB.ADV from Castles II]:

| Numbers | In | Purpose |
|---|---|---|
| 100-104 | every driver | describe the driver, detect the device, initialise, serve (the timer call), shut down [numbers: file; purposes: recall] |
| 120-132 | digital drivers (SBPDIG has 120-132 less 103) | buffer registration, buffer status, VOC playback, start/stop/pause/resume, volume and panning [numbers: file; purposes: recall] |
| 150-194 | music drivers (SBFM, ADLIB) | XMIDI sequences: register, start, stop, volume, tempo, channel mapping, timbre cache [numbers: file; purposes: recall] |

The game loads the file into its own memory and calls the functions by
number through the AIL API, so a protected-mode game needs the extender's
real-mode call path for every call. Music drivers are serviced from the
timer (function 103) at the driver's rate [recall].

### What the SB Pro digital driver does (Castles II) [trace]

Card: virtual SB16 on IRQ 7. The game's CASTLES2.CFG named the SB Pro
driver.

1. D3h (speaker off), reset (01h, about 20 status reads, 00h, AAh).
2. **Mixer detection**: write 06h to mixer 0Ah, read it back (06h means a
   mixer, so an SB Pro or later), write 00h back.
3. 40h A6h: time constant for 11111 Hz.
4. Unmask the IRQ at the PIC (38h: IRQ 7 open).
5. **A 4-byte probe transfer from linear address 0** (DMA 1, mode 49h
   single-cycle, page 0, address 0000h, count 3): 0Eh=00h (mono), then DSP
   14h with length 3. The driver waits for the interrupt, then reads 2xEh
   once to acknowledge.
6. Steps 1 to 5 again (detect, then initialise).
7. Mixer 04h=DDh (voice volume), D1h (speaker on).

Playback then uses 14h single-cycle blocks, one per interrupt, the next
one started from the handler [recall; the 35 s run played no sound after
set-up]. The probe at address 0 sends the first four bytes of the
interrupt table to the DAC: harmless, but an emulator that checks DMA
addresses must allow page 0.

### Seen in the trace, not the driver's

Castles II masks and unmasks IRQ 1 (the keyboard) at the PIC about 500
times in 35 s (B8h/BAh pairs) [trace]. A virtual PIC that costs a trap per
mask write pays for this.

## MSS 3

### The driver files and DIG.INI

A `.DIG` starts `AIL3DIG`, 1Ah, then a header; it carries the device name
("Creative Labs Sound Blaster 16 or AWE32") and the string `BLASTER`, the
environment variable it reads [file, SB16.DIG and SBLASTER.DIG]. DIG.INI
names the driver's device and its resources; -1 means "find it yourself"
[file, Theme Hospital, Miles 3.50E]:

```
;Miles Sound System V3.50E of 24-Sep-96
DEVICE      Creative Labs Sound Blaster 16 or AWE32
IO_ADDR     220h
IRQ         -1
DMA_8_BIT   -1
DMA_16_BIT  -1
```

MDI.INI has the same layout for the music device (IO_ADDR 330h for
MPU-401, 388h for OPL).

### What the SB16 digital driver does

Three SB16 traces agree on the shape [trace: Albion and Star Command
Revolution (MSS 3, the latter recorded in host-cdrom-spec.md section 10);
LBA, whose SB16 driver is AIL/32's (see below) and follows the same
steps]:

1. Reset, E1h (version 4.xx expected).
2. **IRQ and DMA from the card itself**: reads mixer 80h (IRQ select:
   bit 0 IRQ 2, bit 1 IRQ 5, bit 2 IRQ 7, bit 3 IRQ 10) and 81h (DMA
   select: bits 0, 1, 3 for DMA 0, 1, 3; bits 5-7 for DMA 5-7). With -1
   in DIG.INI these decide; BLASTER is read as well.
3. **A one-sample 16-bit probe**: DMA 5 mode 49h single-cycle, DSP B0h
   (16-bit output, single-cycle) mode 30h, length 0; then the interrupt,
   82h read, 2xFh read (the 16-bit acknowledge). The driver tries four
   times before it gives up and the game runs without digital sound. The
   1994 SB16.DIG (2756 bytes, the same file in Warcraft and System Shock)
   loses this interrupt under uCDD when the physical card shares IRQ 7
   with the virtual one ([findings.md](findings.md), F1); 3.04 (Time
   Commando) and 3.50E (Theme Hospital, Dungeon Keeper) do not.
4. Volumes: reads then writes 30h-3Ch (LBA writes 3Ch=1Eh, 3Bh=00h,
   32h-39h, 30h/31h).
5. Playback, auto-init:

   | Game | DSP | Rate | Format | DMA buffer | Block (one interrupt) |
   |---|---|---|---|---|---|
   | LBA | 41h, B6h | 22000 Hz | 16-bit stereo signed (mode 30h) | DMA 5, 4096 words, mode 59h | 2048 samples = 46 ms |
   | Albion | 41h, C6h | 22050 Hz | 8-bit mono unsigned (mode 00h) | DMA 1, 4096 bytes, mode 59h | 2048 samples = 93 ms |

   The DMA buffer always holds two blocks: the handler refills the half
   the card has just finished (double buffering).
6. **The handler** reads 82h, then the acknowledge that matches (2xFh for
   16-bit, 2xEh for 8-bit), mixes the next block, and sends the EOI. One
   82h read and one acknowledge per interrupt, nothing else [trace].

## AIL/32

The 32-bit edition of AIL 2 for DOS-extended games (1993-1994) [file]:
drivers named `A32*.ADV` (Serf City: A32SBDG.ADV, A32SBFM.ADV, A32MT32.ADV
and so on) or `A32*.DLL` (LBA, Ravenloft 1 and 2, SimCity 2000, Al-Qadim,
Shadow Caster). Eight games here. The same function-number interface as
AIL 2 [recall]. LBA's SB16 driver [trace]: mixer 80h/81h read, 41h 22000
Hz, a 4096-word DMA buffer on DMA 5, **B6h** mode 30h (16-bit stereo) with
2048-sample blocks, and a handler that reads 82h then 2xFh: the same
shape as MSS 3's above. Its FM driver writes the
chip as MSS 3 does (music-and-timers.md).

## Notes on version 3.5

Version 3.5's ESS driver (AUDIODRV.DIG) is documented in
[miles-ess.md](../miles-ess.md): it identifies the chip by
E7h, takes IRQ and DMA from ESS registers B1h/B2h, and tests the interrupt
with F2h.

### The F2h test: one interrupt at a time

Miles' interrupt test (the ESS driver; the SB drivers use the same
method [recall]) sends F2h twice and spins until its counter reads
**exactly** 1, then sends F2h and waits for exactly 2, then 3. On real
chips each F2h raises its own interrupt about 12 us after the command
[hw: ES1868F, F2TEST]. A card model that raises the interrupt inside the
F2h write itself, so that two arrive before the spin starts, makes the
test fail and the game run silent. uCDD holds an F2h that comes within
8 accesses of the last one (fixed 15 Oct, [miles-ess.md](../miles-ess.md)).

## What uCDD has learned from Miles

| Item | What the engine does | What it needs from a card | Where |
|---|---|---|---|
| F2h counting | expects interrupts one by one | each F2h raises one interrupt, after the command | miles-ess.md, fault 1 |
| Delivery through its own vector | hooks the IRQ through INT 21h AH=25h | the interrupt must reach the game's vector, also when card and game share IRQ 7 | miles-ess.md, fault 2 |
| ~~End of interrupt held for seconds~~ (WITHDRAWN 20 Oct) | Recorded here as Mortal Kombat Trilogy's driver leaving its interrupt without an EOI for about 3 s. Wrong: the driver sent its EOI and uCDD's host swallowed it (F14). A uCDD fault written down as an engine habit, without the run on the bare machine that would have shown it | under uCDD, F14's fix; nothing is asked of a card | [findings.md](findings.md) F14 |
| One-sample probe | B0h with length 0 at set-up | a 1-sample single-cycle 16-bit transfer must complete and interrupt | traces above |
| Shared IRQ 7 | the 1994 drivers' probe interrupt | delivery to the game's handler with the physical card on the same line | [findings.md](findings.md) F1, open |
| 80h/81h | trusted for IRQ and DMA | the card's real IRQ and DMA in 80h/81h | vsb-spec.md 9.4 |
| Smacker video with Miles | Star Command's intro stalls under the DPMI host (timer delivered 20000 times a second) | open | host-cdrom-spec.md section 10 |
| Real-mode handler under DOS/4GW | DOS/4GW passes the card's IRQ down to the driver's real-mode handler with an INT to the hardware vector; the handler sends its own EOI | that EOI counted as the game's | [findings.md](findings.md) F14: the host swallowed it; fixed on stray-eoi (D8). MKT and Theme Hospital play at 1.00 against runs without uCDD, D7 at 2.38 [86Box, 20 Oct]; PC test pending |
| SB16.DIG 0c12adc1 | the one Miles SB16 driver version never traced; only Fade to Black carries it ([census.md](census.md)) | not known yet | [findings.md](findings.md) F15: 79-84% of its block ends overrun with or without the F14 fix, no EOI swallowed [trace, 19 Oct]; open |

## Music and timer [trace]

MSS 3 sets the PIT to **200 Hz** (Albion and Dungeon Keeper in mode 2,
Warcraft in mode 3; System Shock 280 Hz) and reads the counter often
(Albion: some 500 latches a second). Its OPL3.MDI, AIL 2's OPL drivers
inside MidPak (Capitalism) and LBA's AIL/32 driver write the FM chip the
same way: **OPL3 with both banks, 14 status reads per register write**,
and the same start (the timer test, 26 writes to 06h-1Fh). Detail in
[music-and-timers.md](music-and-timers.md).

## On the cards before the SB16 [trace]

On an SB Pro or SB 2.0 the MSS 3 SB16 driver checks the version and gives up; the AIL 2 SB Pro driver needs the SB Pro's mixer and finds no SB 2.0. See [pre-sb16.md](pre-sb16.md).

## Quick reference

| | AIL 2 SB Pro | MSS 3 SB16 |
|---|---|---|
| Detect | reset, AAh; mixer 0Ah write/read | reset, AAh; E1h |
| IRQ found by | 4-byte DMA probe, wait for the interrupt | mixer 80h (or DIG.INI) then a one-sample probe |
| DMA | 8-bit, single-cycle 14h | 16-bit or 8-bit, auto-init (B6h / C6h) |
| Rate | 40h time constant | 41h in Hz |
| Acknowledge | 2xEh | 82h, then 2xFh or 2xEh |
| Position | interrupts only | interrupts only (no count reads seen) |
| Timer | the music driver's serve call (function 103) | 200 Hz (280 Hz in System Shock) |
