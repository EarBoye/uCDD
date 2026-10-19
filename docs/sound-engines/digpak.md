# DigPak and MidPak (John W. Ratcliff, The Audio Solution)

DigPak plays digital sound, MidPak music; both 1992-1995, both resident
drivers loaded by the game, both called through a software interrupt.
About 35 games here: X-COM UFO Defense and Terror from the Deep, Pizza
Tycoon, Capitalism, Simon the Sorcerer 1 and 2, The 7th Guest, Eye of the
Beholder III, Ultima I-V (the eXo patches), Caesar. See
[inventory](inventory.md).

Grades as in the [README](README.md#evidence-grades).

## Files

| File | What it is |
|---|---|
| `SOUNDRV.COM` | The DigPak driver for one card: "Sound Blaster 16", "Sound Blaster Pro", "Sound Blaster or compatible"; the setup program copies the chosen one under this name [file: X-COM, Pizza Tycoon, Capitalism, Simon 1, 7th Guest] |
| `MIDPAK.COM` with `MIDPAK.ADV`, `MIDPAK.AD` | MidPak: a resident shell around a **Miles AIL 2 music driver** (the .ADV) and its timbre bank (.AD) [file: Capitalism; MIDPAK.COM names midpak.adv and midpak.ad]. So "Miles AIL 2, DigPak/MidPak" in the inventory is usually MidPak carrying an AIL 2 driver |
| `SOUND.CFG` | Binary, 18 bytes in X-COM: port 0220h, IRQ 7, DMA 1 among them [file] |

**INT 66h.** SOUNDRV.COM itself executes `INT 66h` at five places
[file, X-COM's SB16 driver]: DigPak's interface is that interrupt
[recall], and the driver checks it for a copy already resident (Pizza
Tycoon's has the messages "DIGPAK Sound Driver is already resident" and
"resident, through MIDPAK" [file]).

## What the SB16 driver does [trace]

X-COM UFO Defense, X-COM Terror from the Deep, Pizza Tycoon; all with the
1994 "Sound Blaster 16" SOUNDRV.COM:

1. Reset, AAh. **E0h AAh** (identify: expects 55h back), **E1h** (4.13).
   Pizza Tycoon also writes the test register (E4h 1Bh, E8h).
2. Reads mixer 80h and 81h, then **writes 81h = 02h**: it reprograms the
   card's DMA select to DMA 1 only. On an SB16 whose DMA is set in
   software that drops the 16-bit channel until the next set-up; on a
   jumpered card the write should do nothing. Creative's guide says 80h
   and 81h "should only be changed by system software" (SBG:1047-1052).
   The virtual SB16 ignores the write.
3. D1h, 41h 11025 Hz.
4. The 8237: mask, flip-flop (any value: 10h, 60h, A0h seen), address,
   count, page, mode 59h; the DMA buffer is 2048 bytes.
5. **C6h**, mode 20h (X-COM: 8-bit stereo) or 00h (Pizza Tycoon: mono),
   length 1023: two blocks in the buffer. **The channel is unmasked
   after the DSP command**, not before.
6. **The handler** reads 82h, then **both** 2xFh and 2xEh, every time,
   whichever bit is set.

### The master PIC mask set to 00h

In all three games the PIC mask is written FFh and then **00h**, several
times in Pizza Tycoon [trace]: everything masked, then every line on the
master controller opened, whatever was masked before. On a real PC a line
with no handler then reaches the BIOS's default handler, which masks it
again [recall]. Whether the driver or the game does it is not known from
the trace.

## The SB Pro driver (Capitalism, 1993) [trace]

Reset, E0h, E1h, D1h, **mixer 83h = 0Bh** (the same undocumented write
as HMI's), the SB Pro mixer test (0Ah written 06h, read back), time
constant D3h (22222 Hz), then **single-cycle 14h transfers chained by the
handler**: 22050, 12958, 9092 bytes, repeated as the sounds play; the
handler reads 82h and 2xEh and masks the channel. Mixer 0Eh=00h (mono)
before each block.

## Seen but not traced to the end

- **Simon the Sorcerer 1**: its launcher's DigPak loader printed
  "SoundBlaster Pro DIGPAK Driver ... Load Failed. Sound driver
  unloaded" in 86Box [trace screen], after "EMS exists, UMB Linked". The
  folder's SOUNDRV.COM is the "Sound Blaster 16" one; why the load failed
  is not known.
- Caesar, 7th Guest: the detection (D3h, 0Ah test, a 4-byte probe), then
  no sound in the 35 s of the run.

## What uCDD needs for DigPak

| Item | What DigPak does | What it needs |
|---|---|---|
| 81h written | sets DMA select to 02h | a card that ignores it keeps working; the CT2290 should be checked (read 81h before and after X-COM) |
| Both acknowledges | reads 2xFh and 2xEh on every interrupt | a 2xFh read with no 16-bit request must not disturb the 8-bit one |
| Channel unmasked after the start | DSP first, DMA unmask second | the virtual DSP must wait for the channel, not fail |
| 21h = 00h | opens every line | the driver's own IRQ handlers must cope with a line opened behind their back |

## Music and timer [trace]

MidPak in X-COM: the timer at 140.0 Hz (mode 3), OPL2 only, 40 status
reads per write. MidPak in Capitalism carries an AIL 2 OPL3 driver and
writes exactly like Miles: both banks, 14 status reads per write.
Detail in [music-and-timers.md](music-and-timers.md).

## Quick reference

| | DigPak SB16 (1994) | DigPak SB Pro (1993) |
|---|---|---|
| Detect | E0h AAh, E1h | E0h, E1h; 83h, 0Ah test |
| IRQ found by | the configuration | the configuration |
| DMA | 8-bit auto-init, two blocks | 8-bit single-cycle, chained |
| Rate | 41h | time constant |
| Acknowledge | 82h, 2xFh and 2xEh | 82h, 2xEh |
| Interface | INT 66h | INT 66h |
