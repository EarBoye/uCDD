# Creative's own drivers: CT-VOICE, CTVDSK, SBFMDRV

The drivers Creative shipped with the Sound Blaster developer kit
(1989-1992), linked or loaded by early games: CT-VOICE.DRV (digital,
from memory), CTVDSK.DRV (digital, from disk), SBFMDRV.COM (FM music,
resident). About 28 games here: Xargon, Jill of the Jungle, Epic Pinball,
Cool Spot, Prehistorik 2, Dark Seed, The Secret of Monkey Island, Caesar,
Pizza Tycoon, Whale's Voyage. Several games with their own code use the
same detection steps, copied from Creative's examples. See
[inventory](inventory.md).

Grades as in the [README](README.md#evidence-grades).

## Files

`CT-VOICE.DRV` starts with a near jump, then `CT-VOICE`, a zero, "Creative
Sound Blaster Card" and Creative's 1989-1990 copyright [file, Prehistorik
2]. The game loads it at offset 0 of a segment and calls it with a far
call, the function number in BX [recall: 0 version, 1 set port, 2 set
IRQ, 3 initialise, 4 speaker, 6 output a VOC block, 8 stop, 9 terminate];
the driver reads `BLASTER` in later versions and otherwise takes the port
and IRQ the game passes. SBFMDRV.COM stays resident and takes the first
free interrupt from 80h up [recall].

## Detection seen in the traces [trace]

The games differ in order but use the same pieces, all from the 1.x/2.0
era of the guide:

| Step | Ports | Games |
|---|---|---|
| Speaker off, reset, AAh | D3h; 2x6h 1/0; 2xAh | all |
| **Identify**: E0h with a byte, the inverse comes back | E0h 55h then AAh read (Xargon); E0h AAh then 55h (Prehistorik 2, Epic Pinball); **E0h C6h, expecting 39h** (Jill of the Jungle, Monkey Island, X-Wing) | |
| **Test register**: E4h writes a byte, E8h reads it back | E4h 1Bh / E8h (Xargon, Pizza Tycoon); E4h AAh / E8h (Monkey Island) | |
| **DMA identification**: E2h with a byte, the DSP writes one byte by DMA (8237 mode 45h: write to memory) | E2h 06h, then E2h 6Bh (Prehistorik 2, Epic Pinball, Monkey Island); E2h BAh (Cool Spot); E2h 98h, F6h (Alien Breed) | |
| **Read flush**: 256 reads of 2xAh after a reset | Xargon | |
| **SB Pro mixer test**: reset the mixer (00h), write 55h to 22h, read it back | Xargon, Dark Seed; then 22h, 26h, 04h set to FFh | |
| **IRQ test** | F2h (Jill of the Jungle, Monkey Island); a short 14h transfer (Xargon: 8 bytes at time constant A0h); **80h**, a DMA-less silence (Dark Seed, length 0101h at time constant 7Fh) | |

Playback is 8-bit single-cycle **14h**, one block per VOC block, chained
from the interrupt handler, with the time constant from the VOC header
(Xargon: A0h, 10416 Hz, then 60h, 6250 Hz for its music samples) and
**D0h** (pause) between blocks [trace].

## Seen in the traces, not the drivers'

- Cool Spot writes the master PIC mask A8h then 00h over and over from
  its start, before any card access [trace]: the game opens every line
  repeatedly.
- Several Creative-driver games poll the keyboard port (60h) inside the
  detection (Xargon) [trace]; harmless.

## What uCDD needs for the Creative drivers

| Item | What they do | What it needs | Where |
|---|---|---|---|
| E0h, E4h/E8h | identify, test register | the 2.0+ commands answered on every model | vsb-spec.md section 5 |
| E2h | one byte written by DMA into memory (mode 45h) | the DMA write path, the byte the 4.13 computes; no reply when the 8-bit channel is masked (CT2290) | vsb-spec.md 13, D11 |
| 80h silence | interrupt after a silence, no DMA | a timed interrupt from 80h | irq.asm sb_silence_tick |
| VOC chains | single-cycle blocks with pauses | 14h chaining from the handler without a gap | vsb-spec.md 7.1 |

## Music and timer [trace]

Every game here that carries Creative's drivers sets the timer to
**170.5 Hz** first (reload 7000): Monkey Island, Xargon, Jill of the
Jungle, Pizza Tycoon. Then their own: Xargon and Jill 96 Hz, Pizza
Tycoon 192 and 64 Hz. FM on the OPL2 only, often with rhythm mode (BDh);
Jill, Pizza Tycoon and Monkey Island write it **with no status reads at
all**, Xargon with 77 per write. Detail in
[music-and-timers.md](music-and-timers.md).

## Quick reference

| | CT-VOICE era |
|---|---|
| Detect | reset; E0h; E4h/E8h; E2h; mixer 22h read-back |
| IRQ found by | F2h, a short 14h, or 80h |
| DMA | 8-bit single-cycle |
| Rate | time constant from the VOC block |
| Acknowledge | 2xEh |
| Position | interrupt per block |
| Music | SBFMDRV (FM) |
