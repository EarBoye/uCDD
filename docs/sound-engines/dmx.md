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

How DMX uses them [code, Hexen]:

- **The BLASTER line** gives the defaults: A (210h-280h on a 10h step,
  else 220h), I (7 when missing) and D (1 when missing). H and T are never
  read: DMX plays 8-bit only and never touches a 16-bit channel.
- **The port**: the config's, or BLASTER's when the config says -1; if no
  DSP answers there, six standard ports are tried.
- **The IRQ**: with `snd_sbirq 0` BLASTER's line is taken untested. Any
  other value runs the IRQ test below, and the line that answers wins
  over the configured one. So the eXo default of 7 does no harm when the
  card is on 5 (unlike Duke's config, F16): DMX finds the line itself.
- **The DMA channel**: the config's (BLASTER's when -1). It is tested
  only when F2h raises no interrupt at all.

## What the Sound Blaster driver does

Traced in Doom, Doom II, Hexen, Raptor, and Strife after its own preamble,
all on a virtual SB16 at 220h, IRQ 7, DMA 1 [trace], and read in Hexen's
program [code]. The sequence is the same in all of them.

### Detection [code, trace]

1. **Reset**: 2x6h 1, about 30 ms by its own timer, 0, about 20 ms, then
   AAh. Every DSP write waits for the busy bit and every read for data,
   200 status reads each with no time base, and gives up silently after
   that.
2. **E1h**: the version. Above 4.xx it is taken as 1.00.

### The IRQ test [code, trace]

3. Handlers go on **IRQ 2, 3, 4, 5, 7 and 10** (protected-mode vectors
   through DOS/4GW), each line unmasked as it is hooked. In the traces at
   IRQ 7 the master mask steps B8h, B0h, A0h, 80h, 00h: IRQ 2 was open
   already, and IRQ 10 is on the second controller, which the trace did
   not log.
4. **The in-service register is cleared**: DMX reads it (OCW3 0Bh, then
   20h) and sends non-specific EOIs until it reads zero. It does this
   before the test and again after it.
5. **F2h**, then up to 200 ms by its own timer for a handler to run; the
   handler only notes its line. An acknowledge (2xEh), **F2h again**, and
   the same line must answer within 200 ms, or the answer is dropped.
6. Only if F2h raised nothing: speaker on, 400 ms, a 4-byte single-cycle 14h at
   time constant D3h on the configured channel (programmed first). And
   if that raised nothing either: an 11-byte 14h is sent **before any
   channel is programmed**, then DMA 0, 1 and 3 are programmed in turn,
   200 ms each, and the channel that ends the transfer is the card's.
   That is F5's pattern (a transfer that must wait for its channel); a
   card that answers F2h never reaches it.
7. Every hook is removed and each line's mask put back as it was.

### Playback start, by DSP version [code; the SB16 path also trace]

8. The buffer: 4096 bytes of DOS memory that does not cross a 64 KB
   page, filled with 80h (silence). Blocks of 128 frames at 11025 Hz,
   256 at any other rate. In 8-bit stereo that is sixteen blocks of 256
   bytes (11.6 ms each); in mono, thirty-two of 128 bytes.
9. **4.xx (SB16)**: an acknowledge, the 8237 in **demand mode**,
   auto-init, read (mode 19h on DMA 1) over the whole buffer, **41h**
   11025 Hz, **C6h mode 20h** (8-bit stereo, auto-init, FIFO on) with the
   block length. No speaker command.
10. **3.xx (SB Pro)**: first **FAh**, its test for a Jazz16 card: exactly
    one non-zero byte back means a Jazz16; anything else is followed by a
    DSP reset. Then speaker on and 200 ms, mixer 0Eh bit 1 (stereo) set,
    04h and 26h (voice and FM volume) set to EEh, the time constant from
    500000/rate (the SB Pro's stereo clock doubling), and a **12-byte
    single-cycle 14h** as a priming transfer. At its interrupt: 0Eh bit 5
    cleared (the output filter in), the 8237 in auto-init over the whole
    buffer, **48h** with the block, **90h** (high speed, auto-init).
11. **2.xx (SB 2.0)**: the same priming (no mixer), the time constant
    from 1000000/rate, then 48h and **1Ch** (auto-init, mono).
12. **1.xx**: the priming, then **14h** for the whole buffer, sent again
    at every interrupt, while the 8237 runs in auto-init.

### The interrupt [code, trace]

13. DMX's own dispatcher calls the handler on its own stack and sends the
    EOI **after** it, never before; nothing is chained. On IRQ 7 it reads
    the in-service register first and skips the handler when bit 7 is
    clear (a spurious IRQ 7), but sends a non-specific EOI even then.
    Under uCDD, a virtual IRQ 7 must therefore show in the in-service
    register while it is in service.
14. The handler: on a 4.xx, **mixer 82h**, then 2xEh if bit 0 is set (or
    2xFh if bit 1 is), and no acknowledge at all when neither is set; on
    older DSPs 2xEh. Then, on the cards before the SB16, the next step
    (the priming transfer's interrupt starts the stream; on a 1.xx the
    next 14h). Last, it **marks the mixing job due**. It mixes nothing
    itself.

### How DMX keeps the buffer full [code, trace]

15. Mixing is a job on DMX's 140 Hz timer (the same timer that plays the
    music, music-and-timers.md). On every tick, while the job is due, it
    reads the 8237 count **once** (flip-flop, low, high), works out the
    block being played from it, and mixes **exactly one block: the one
    after it**. If that is the block it mixed last time, it does nothing
    and tries again at the next tick, 7.1 ms later. After mixing, it
    waits for the next block interrupt (or, as a fallback, one second).
    On a 1.xx, which has no auto-init, the job runs at every tick instead.
16. So **DMX writes at most one block (11.6 ms) ahead of the count it
    reads**, and reads it up to one tick (7.1 ms) after the interrupt.
    On the card the count is where its DMA has fetched to: at the
    interrupt it sits exactly on the block boundary, and nothing beyond
    the count has been taken (the FIFO's 16 samples are behind it, taken
    but not yet heard) [hw, ct2290.md]. So each block is written at
    least 4.5 ms (one block less one tick) before the card takes it. A
    card or emulation that takes data beyond the count it reports spends
    that margin; past it, the start of a block, or a whole block, plays
    what the buffer held one lap (186 ms) earlier (finding F18).
    22 Oct: not seen in 86Box even with D9 at 256 frames (findings.md
    F18); the check itself is not yet proved on a planted fault.
17. The "count twice" in the traces is step 15's retry: one read after
    the interrupt still in the old block, a second at the next tick.

### Stop [code]

18. DSP reset, the interrupt unhooked (its mask bit set again only if it
    was masked before), the timer job removed. On a 3.xx or later, mixer
    0Eh has stereo cleared and bit 5 set (the filter out). On the SB16,
    whose CT1745 has no 0Eh, that is the "0Eh=20h" seen in Doom's trace
    (harmless).

### An oddity [code, Hexen]

Hexen asks DMX's detection for the DSP version without giving it a place
to put it, so the two version bytes are written at linear address 0: the
real-mode INT 0 vector, under DOS/4GW's flat memory. It works because
DOS/4GW maps the first page; a host that left it unmapped would fault
here.

### Strife's preamble

Before DMX starts, Strife runs a different detection [trace]: time
constant 04h with **80h** (a DMA-less silence of length 0, used to see the
interrupt), time constant B3h and a 10-byte **14h** single-cycle transfer
(the DMA check), E1h, D0h, then 1469 samples of 8-bit mono at 22050 Hz
(C6h mode 00h), D0h twice. Then DMX's own steps follow. Who owns the
preamble (the game's voice code or a launcher) is not known.

## What uCDD needs for DMX

| Item | What DMX does | What it needs | Where |
|---|---|---|---|
| Short blocks | 11.5-11.6 ms blocks | the output period at most half that: 128 frames works, 256 is silent on a virtual SB Pro | ISSUES.md, output period table |
| Six lines open for F2h | hooks IRQ 2, 3, 4, 5, 7, 10, clears the in-service register with EOIs, fires F2h twice | exactly one interrupt per F2h, on the card's line only; nothing of the driver's left in service | miles.md, F2h |
| Demand mode | 8237 mode 19h | demand accepted as single (the emulation moves data a period at a time) | host-cdrom-spec.md D4 |
| One block ahead of the count | mixes the block after the one the count is in, at a 140 Hz tick after the interrupt (step 15) | the count on the block boundary at the interrupt, and no data taken more than about 4.5 ms beyond the count; the virtual count trails what uCDD has taken by one to two output periods (F8) | [findings.md](findings.md) F18, open |
| Spurious IRQ 7 check | reads the in-service register on IRQ 7 before its handler | the virtual line shown in service while it is | step 13 |
| IRQ 7 timing | Doom's timedemo, used as uCDD's speed check | | 1807/1787 realtics on the PC (ES22), about 1640 in 86Box |
| Count steps back | Hexen 14 of 135 count reads went up (98 bytes), Raptor 1 of 106; a step back across a block boundary makes DMX mix a block it has already mixed: every sound playing skips 11.6 ms | a count that never rises | [findings.md](findings.md) F2, open |

## Music and timer [trace]

The timer at **140.0 Hz** (mode 3, reload 8522), the same in Doom and
Hexen. Music on the **OPL2 only** (no second bank, even on an OPL3), 30
status reads per write, the whole instrument rewritten for every note.
Detail in [music-and-timers.md](music-and-timers.md). The same timer runs
the digital mixing (step 15) and the waits of the detection; one tick in
every so many is passed on to the BIOS's own timer handler, which then
sends the EOI [code].

## On the cards before the SB16 [trace]

On an SB Pro DMX switches to stereo high speed after a 12-byte priming transfer, on an SB 2.0 to mono 1Ch; under uCDD its SB Pro stereo stalls when both cards share IRQ 7 (findings F4). See [pre-sb16.md](pre-sb16.md). Steps 10 to 12 above give the detail [code].

## Quick reference

| | DMX (SB16 path) |
|---|---|
| Detect | reset, E1h |
| IRQ found by | F2h twice with IRQ 2, 3, 4, 5, 7, 10 open together; a 14h transfer only if F2h fails |
| DMA | DMA 1, demand mode, auto-init, 4096 bytes; 8-bit only (BLASTER's H unused) |
| Rate | 41h 11025 Hz (SB16), time constant (older cards) |
| Format | 8-bit stereo, 128-frame blocks |
| Acknowledge | 82h, then 2xEh |
| EOI | after the handler; on IRQ 7 also for a spurious one |
| Position | one count read at a 140 Hz tick after each block interrupt; mixes the block after the one being played |
| Music | OPL through its own code, or MPU-401, or GUS |
