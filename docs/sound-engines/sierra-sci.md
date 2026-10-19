# Sierra SCI drivers

Sierra's Creative Interpreter loads one driver file per device, named in
`RESOURCE.CFG`; the interpreter versions (SCI0 1988-1990, SCI1 1990-1992,
SCI1.1 and SCI32 from 1992) each have their own driver set. About 55
games here: every King's Quest, Space Quest, Police Quest, Leisure Suit
Larry, Quest for Glory, Gabriel Knight, and Sierra's arcade titles. See
[inventory](inventory.md).

Grades as in the [README](README.md#evidence-grades).

## Files and configuration

`RESOURCE.CFG` names a driver for each job [file, King's Quest V]:

```
videoDrv  = VGA320.DRV
soundDrv  = ADL.DRV 220       (music: FM through the AdLib driver)
audioDrv  = AUDBLAST.DRV 220  (digital: the Sound Blaster driver)
```

| Driver | Job | Interpreters |
|---|---|---|
| `ADL.DRV` | music on OPL2 (AdLib, and the SB's FM) | all |
| `SNDBLAST.DRV` | music on the SB's FM, sound effects | SCI0/SCI1 |
| `AUDBLAST.DRV` | digital audio (speech, effects) on a Sound Blaster | SCI1 and later |
| `AUDPRO.DRV`, `AUDPS1.DRV` | digital on Pro Audio Spectrum, PS/1 | SCI1 |
| `MT32.DRV`, `GENMIDI.DRV` | MIDI: MT-32, General MIDI (MPU-401) | all / SCI1 and later |
| `STD.DRV`, `TANDY*.DRV`, `CMS.DRV`, `IMF.DRV` | speaker, Tandy, Game Blaster, IBM Music Feature | SCI0 |

The digital driver takes the port from RESOURCE.CFG and finds the IRQ
itself.

## What AUDBLAST.DRV does (King's Quest V, SCI1) [trace]

1. Reset, AAh. **E0h AAh** (55h back), **E1h**.
2. **The IRQ test**: opens IRQ 3, then 5, then 7 at the PIC (mask B0h,
   90h, 10h) with a handler on each, programs a **one-byte single-cycle
   transfer** (8237 mode 49h, count 0), time constant 64h (6410 Hz),
   **14h with length 0**; the handler that runs reads 2xEh. The other
   lines are masked again.
3. D1h, time constant A6h (11111 Hz) three times, **48h 4000h** (a block
   size, which single-cycle transfers do not use), then the 8237 and
   **14h with length 3FFFh**: 16 KB single-cycle blocks.
4. While a block plays, the driver **reads the 8237 count one byte at a
   time without clearing the flip-flop**: the reads alternate between the
   low and the high byte.

The test wait is a fixed loop: "Sierra's AUDBLAST.DRV waits 2048 loop
passes for its test interrupt. That is too short for any card on a fast
CPU" (ISSUES.md). The libraries carry a patched AUDBLAST.DRV for this
(never committed).

**Open [trace, 86Box]:** at the end of King's Quest V's run the count's
low byte stayed between 30h and 6Eh (high byte 0Ah) for 60 reads, rising
by 10h or 11h three reads in a row and falling 2Fh on the fourth. A real
8237's count only falls during a transfer. Either the transfer had
stalled and the virtual count wobbles around the stall by about two
output periods, or the virtual count runs backwards between periods. To
look at in the virtual 8237 (host-cdrom-spec.md section 5).

## SCI1.1 and SCI32 (King's Quest VI CD, Gabriel Knight) [trace]

E0h AAh, E1h, D1h, then **41h** (11025 Hz, then 22050 Hz): the newer
AUDBLAST uses the SB16's rate command when E1h says 4.xx. Mixer 26h=FFh
(FM volume). The runs ended before any transfer.

## SCI0 (Larry 2, Police Quest 3 era)

Larry 2's RESOURCE.CFG names ADL.DRV (FM music only), yet its run shows
the same one-byte probe (E0h, E1h, time constant 64h, 14h length 0, the
mask stepping A0h, 20h) [trace]; which program sent it is not known.
Police Quest 3 (SCI1): E0h, E1h, the probe, mask A8h, A0h, 80h, 00h:
IRQ 3, 5 and 7 opened one by one, then all [trace].

## What uCDD needs for Sierra

| Item | What the driver does | What it needs |
|---|---|---|
| One-byte probe | 14h with length 0 | a one-byte single-cycle transfer that ends and interrupts within the driver's 2048-pass wait (patched in the library) |
| Single-byte count reads | no flip-flop clear | the flip-flop toggles on every read, as the 8237's does |
| 48h before 14h | sets a block size it does not use | 48h stored, not acted on |
| 16 KB single-cycle blocks | 1.5 s each at 11111 Hz | chained by the handler; the count must fall steadily |

## Quick reference

| | AUDBLAST (SCI1) | AUDBLAST (SCI1.1, SCI32) |
|---|---|---|
| Detect | reset, E0h AAh, E1h | the same |
| IRQ found by | one-byte DMA probe with IRQ 3, 5, 7 open | the same |
| DMA | 8-bit single-cycle, 16 KB blocks | 8-bit |
| Rate | time constant | 41h on a 4.xx |
| Acknowledge | 2xEh | 2xEh |
| Position | interrupt per block, count read one byte at a time | |
| Music | a separate driver (ADL, SNDBLAST, MT32, GENMIDI) | the same |
