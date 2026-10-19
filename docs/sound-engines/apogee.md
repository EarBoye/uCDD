# Apogee Sound System (Jim Dosé)

Jim Dosé's library for Apogee and 3D Realms, versions 1.0 to 1.1x
(1994-1997): Duke Nukem 3D, Rise of the Triad, Shadow Warrior, Blood,
Hocus Pocus, Realms of Chaos, Boppin', Redneck Rampage, KKND. Thirteen
games found by the scan, plus Hocus Pocus, whose packed executable hides
the strings but whose trace is this engine's. Raptor carries both this
and DMX; its trace shows DMX. The source was published later and grew
into the jfaudiolib of the source ports [recall]. See
[inventory](inventory.md).

Grades as in the [README](README.md#evidence-grades).

## Configuration

`DUKE3D.CFG` (and the like), section `[Sound Setup]` [file, Duke Nukem 3D
1.3D]:

```
FXDevice = 0            (the setup program's card list)
MusicDevice = 0
NumVoices = 8
NumChannels = 2
NumBits = 16
MixRate = 22000
BlasterAddress = 0x220
BlasterType = 6         (6: SB16 [recall])
BlasterInterrupt = 7
BlasterDma8 = 1
BlasterDma16 = 5
BlasterEmu = 0x620      (the AWE32's EMU8000)
MidiPort = 0x330
```

The game mixes in software into a ring of small blocks; the card plays
the ring with auto-init.

## What the SB16 path does [trace]

Duke Nukem 3D, Rise of the Triad, Shadow Warrior, Blood and Boppin', at
220h, IRQ 7, DMA 1 and 5:

1. Reset, **E1h**, then **41h and 42h both set to 11000 Hz**, **D0h**
   (pause), **D3h**: done two or three times (the card check, then the
   set-up; ROTT and Duke do it three times).
2. Volumes: mixer 32h/33h (voice) read and written F8h, 34h/35h (MIDI).
3. 41h and 42h with the mix rate (Duke and Shadow Warrior 22000 Hz,
   ROTT 11000 Hz, Boppin' 11025 Hz, Blood 44000 Hz), **D1h**.
4. The 8237: DMA 5, mode 59h, a buffer of 2048 words.
5. **B6h mode 30h, length 511**: 16-bit stereo, auto-init, FIFO on,
   512 samples (256 frames) per block: four blocks in the buffer.
   At 22000 Hz a block is 11.6 ms; at Blood's 44000 Hz the same block
   would be 5.8 ms (Blood's trace stopped before its B6h).
6. **The handler**: mixer 82h, 2xFh (acknowledge), then **reads the 8237's
   current address** of channel 5 (C4h, low and high) **and the page
   register** 8Bh, not the count. The position in the ring comes from the
   address.

Older versions, smaller blocks [trace]:

| Game | Version era | DSP | Format | Block |
|---|---|---|---|---|
| Hocus Pocus | 1994 | 41h 10000 Hz, B6h mode 10h, length 63 | 16-bit mono | 64 samples: **6.4 ms** |
| Realms of Chaos | 1995 | 41h 10980 Hz, C6h mode 00h, length 127 | 8-bit mono | 128 samples: 11.7 ms |
| Duke Nukem 3D | 1996 | 41h 22000 Hz, B6h mode 30h, length 511 | 16-bit stereo | 256 frames: 11.6 ms |
| Blood | 1997 | 41h 44000 Hz (the trace ends there) | | 5.8 ms if its blocks are Duke's 256 frames |

## What uCDD needs for the Apogee Sound System

| Item | What it does | What it needs | Where |
|---|---|---|---|
| Very short blocks | 6.4 ms (Hocus Pocus), probably 5.8 ms (Blood at 44 kHz) | the output period at most half the block: 128 frames (2.9 ms) just covers 5.8 ms; 256 frames does not | ISSUES.md, output period table |
| Address, not count | reads channel 5's current address and its page | the 8237's address register must move with the output, as the count does, and the page register must read back | host-cdrom-spec.md section 5 |
| 42h | sets the input rate too | on the 4.xx one rate register serves 40h and 41h-43h, so 42h sets the output rate as well; the virtual SB16 takes 42h as 41h | vsb-spec.md section 13 |
| D0h then D3h at set-up | pause, speaker off | harmless with no transfer running | |

**Open:** Blood's trace stopped at 150 accesses, just after D1h: whether
its 44 kHz output then started on the virtual card is not in the trace.

## Music and timer [trace]

Duke Nukem 3D: the timer at **120.1 Hz** (mode 3, 9933), OPL3 with both
banks, 33 status reads per write. Rise of the Triad: 35 Hz, then 240 and
320 Hz as the game runs, OPL2 only. Detail in
[music-and-timers.md](music-and-timers.md).

## On the cards before the SB16 [trace]

On an SB Pro Duke Nukem 3D adapts to mono high speed (90h, 43.5 kHz); Rise of the Triad keeps the 16-bit DMA channel its SB16 setting names and stays silent; Hocus Pocus and Realms of Chaos use 1Ch. See [pre-sb16.md](pre-sb16.md).

## Quick reference

| | Apogee Sound System (SB16) |
|---|---|
| Detect | reset, E1h; 41h/42h, D0h, D3h |
| IRQ found by | the configuration (BLASTER or the .CFG) |
| DMA | 16-bit, auto-init, a ring of four blocks |
| Rate | 41h and 42h in Hz |
| Format | 16-bit stereo, 256-frame blocks (older: 64 or 128 samples) |
| Acknowledge | 82h, then 2xFh |
| Position | **the 8237's current address and page register** |
| Music | OPL3 through its own code, MPU-401, AWE32 |
