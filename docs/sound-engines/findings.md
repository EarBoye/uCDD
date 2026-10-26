# Findings from the engine traces (19 Oct 2026)

What the 74 traced games showed that matters for uCDD: faults in the
driver, things the specification does not settle, and what to measure on
the CT2290. Every item is [trace] (86Box, the engine-trace build of the
`vcpi-children` line, 128-frame period, a virtual SB16 at 220h, DMA 1 and
5) unless it says otherwise. Fixed so far: F14 (branch `stray-eoi`); the
rest are open, each for its own branch and a family check.

## Faults in uCDD

### F1. Shared IRQ 7: the 1994 Miles probe interrupt is lost

Warcraft and System Shock carry the same SB16.DIG (2756 bytes, identical
files, no version string: the 1994 Miles Sound System) [file]. Both send
its one-sample probe (B0h, length 0) and wait for the interrupt. With the
physical card and the virtual card **both on IRQ 7**, the game's handler
never ran in 5 of 6 runs: four probes, then the driver gives up and the
game has no digital sound. With the physical card on IRQ 5 and the
virtual on IRQ 7, 3 of 3 runs passed; with both on IRQ 5,
1 of 1. Time Commando (3.04, a 2836-byte SB16.DIG), Theme Hospital and
Dungeon Keeper (3.50E, 2923 bytes) pass the same probe on 7/7. System Shock on 86Box's own SB16 without
uCDD recorded three to five times the audio level of the
uCDD run after its intro started.

A trace that also logged the PIC's command port showed, in the failing
run, nine EOIs from the game's timer handler during the wait and no
in-service read; in the one 7/7 run that passed, the handler read the
in-service register (0Bh, then 80h) and acknowledged. The same shape as
the Miles ESS fault 2 (the virtual IRQ taken for a spurious IRQ 7 when
it shares the line with the physical card, docs/miles-ess.md), on the
SB16 path and the DPMI host. Not on Michael's planned set-up (CT2290 on
IRQ 5); it is on any machine with the card on IRQ 7.

### F2. The polled DMA count steps backwards

A real 8237's count only falls during a transfer (until an auto-init
reload). In six games the virtual count read higher than the read before
it, without a wrap [trace]:

| Game | Engine | Steps back | Size |
|---|---|---|---|
| King's Quest V | Sierra AUDBLAST | 166 of 260 | 16-17 bytes (single-cycle) |
| Super Stardust | MIDAS | 28 of 203 | 68-69 words, once 529 |
| Dark Forces | iMUSE | 19 of 235 | 104 bytes |
| Hexen | DMX | 14 of 135 | 98 bytes |
| Cyberdogs | DSMI | 13 of 234 | 146-220 words (reads far apart: less sure) |
| Raptor | DMX | 1 of 106 | 356 bytes |

For an auto-init transfer the count is the smaller of the output clock
and the mix position; for a single-cycle one (King's Quest V) it is the
mix position alone (trap.asm, `.dma_read`).

Follow-up the same afternoon [trace, 86Box]: Dark Forces stepped back
again on the same trace build (20 steps in a repeat run), and its steps
sit where the count crosses 400h, the end of the first 1024-byte block
of its 2048-byte buffer: the block end, not the DMA lap. A build that
only added a check of the output clock (log any clock below the last
one) showed **no** step in the clock and none in the count, in three
runs of Dark Forces, three of Hexen and one under full host CPU load. So
the output clock is not shown to go back, the fault is timing-sensitive
(a race: a few added instructions hide it), and the per-block position
path (the mix position and its block start) is the next place to look.
Super Stardust's two repeat runs had no real step (the one each was the game
reprogramming its buffer from 0378h to 0500h words) where the first run
had 28 small ones. Open.
Engines that mix up to the position they read (HMI, iMUSE, MIDAS, DSMI)
can then mix over frames already played; the "two reads agree" loop of
Battle Race 95 (host-cdrom-spec.md section 10) is the same field. The
counts were paired from the traces with each game's programmed buffer
size, so a wrap is not counted as a step back.

Follow-up 20 Oct, Hexen [trace, reading]: its steps are 98 bytes, two
output periods (128 bytes of its 8-bit stereo at 11025 Hz, with
128-frame periods) less the 30 bytes between its reads. In the trace's
last stretch the count climbs 30 bytes a read and falls back 98 every
fourth read, with no block interrupt in between: it cycles inside a
two-period window. That is what output_clock (trap.asm) gives when the
period interrupt has not run for more than a period: it takes the
playing half from the physical DMA position and the period from its own
counter, and once the DMA is more than a period past the counter it reads
two periods short. So Hexen's F2 in that trace is the output clock
aliasing while uCDD's period interrupt is held off, not a race in the
count. What held it off is not known: that run had both cards on IRQ 7,
and DMX sends its timer EOI only after its timer jobs (dmx.md step 13),
which holds every lower line, IRQ 5 and 7 among them, until then. DMX's
answer to a step back across a block boundary: it mixes a block it has
already mixed, and every sound playing skips 11.6 ms.


22 Oct 2026, a measurement to make (branch period-late, from irq-counters):
how late the card's period interrupts come on the PC. The refill deadline
is one output period after each interrupt: 0.73 ms at 32 frames (the rule
for all testing since 22 Oct), 2.9 ms at 128. DMX runs its mixing job on
its 140 Hz timer before that timer's EOI, which holds IRQ 5 off meanwhile
(dmx.md). An interrupt more than a period late is also where the output
clock aliases (the 20 Oct reading of Hexen's 98-byte steps). Three
counters in UCDD -STATUS: periods refilled more than half a period late;
periods refilled a whole period late (the card played the old half); and
the BIOS timer's ticks, so that periods lost to a longer delay show
against the time. Proved first on a planted delay (a program holding
interrupts off for set times, lesson L10), then on the PC at 32 frames
with Hexen and Doom.

23 Oct 2026, the PC [hardware: PLKIT, period-late a1ec3ec at 32 frames,
the CT2290 on IRQ 5]: idle, no period refilled late in 20 s (periods
equal to the timer's ticks within 0.1%); held off by CLIGAP 0.5 ms, 9
late and none a whole period; 1 ms, 21 and 38; 4 ms, 80 a whole period
and about 1.6 periods a hold lost against the ticks (the card stopping
its DMA while unacknowledged, as M3 measured on 19 Oct, rather than the
clock aliasing as in 86Box [inference]). Hexen's timedemo (20 s): 4 late,
6 a whole period; Hexen played (about 2 minutes): 3 and 10; DMX's 10788
virtual interrupts all taken and ended. Michael heard nothing wrong. The
price: the timedemo took 415 realtics against D7's 369 at 128 frames
(12.5% slower; the builds differ in more than the period, so the share
that is the period is not yet measured).

24 Oct 2026, fixed for the clock on branch `count-position` (7994cd1,
ISSUES.md F2, the ring): the output ring is 512 frames, so a period
interrupt late by up to 15 periods at 32 frames is read right. [86Box:
idle, the period count matches the BIOS ticks (75.8 and 75.4 a tick,
nominal 75.69; the two-period ring 69.3 and 72.7), each 2 or 4 ms hold
counts once as a whole-period late; SBT16's rates through uCDD within
about 1.5% of the bare card, where they were about 5% short.] So the
aliasing was common in 86Box, and the "86Box plays slow" note of 22 Oct
was mostly this. The count also cannot step back within a transfer since
F8's fix (30c82ca). Dark Forces' sound check is unchanged (speed 1.04,
about 70 steps back): its fault is not this. Hardware: not yet; the kit
repeats PLKIT's 4 ms holds (the alias predicts no periods lost, M3 the
same loss).
### F3. A single-cycle count that hovers (King's Quest V)

At the end of King's Quest V's run the count of a 16 KB single-cycle
block stayed within 0A30h-0A6Eh for 120 reads (F2's sawtooth): either
the transfer had stalled and the count wobbles around the stall point,
or the transfer runs on and the count runs backwards. The block should
have ended about 1.5 s after it started.

### F4. High speed on the older virtual cards never starts with the cards sharing IRQ 7

Found on the pre-SB16 pass ([pre-sb16.md](pre-sb16.md)), confirmed
against DOSBox-X ([family.md](family.md)). With the virtual card an SB Pro
or an SB 2.0 and both cards on IRQ 7, high-speed output (90h) and DMX's
stereo priming transfer never start: the DMA count stays at its start
value. Seen in Doom, Hexen and Raptor (DMX: a 12-byte single-cycle 14h
with stereo on, then 90h), Rayman (HMI's SB Pro module: 90h, on the
virtual SB Pro and SB 2.0), Stargunner (90h). With both cards on IRQ 5
Doom, Rayman (both cards) and Stargunner play (the count moves through
82-123 values). Mono auto-init (1Ch) and chained single-cycle 14h play
at IRQ 7 (King's Quest V, Capitalism, Hocus Pocus; DMX and Stargunner
take 1Ch on the SB 2.0 and play). DOSBox-X plays every one of these on
its own SB Pro and SB 2.0. A transfer starts only at the driver's next
mixing period (game_start_pending); what stops these at IRQ 7 is not
known. Probably the same root as F1. Not on the planned set-up (both
cards on IRQ 5).

### F5. A transfer started before the 8237 is set never starts

C-Dogs (DSMI) programs the DMA channel's page and address, sends 48h and
**90h**, and only then writes the 8237's mode and count and unmasks the
channel. A real DSP holds its DMA request until the controller serves
it, so on hardware the transfer runs once the channel is unmasked. Under
uCDD the count never moved: on the virtual SB16, SB Pro and SB 2.0, and
at IRQ 5 as at 7 (464 reads, one value). DigPak, which unmasks after its
DSP command but sets mode and count before it, plays. Not settled: which
of mode, count or mask the virtual card latches at the command.
DOSBox-X plays C-Dogs on every card from the SB 2.0 up (the count
moves through 112-1700 values), so the fault is uCDD's.

**Confirmed on the CT2290 [hw, 19 Oct]:** C-Dogs' exact order (page and
address, E9h, D1h, 48h 61440, 90h, then mode, count and unmask) starts at
once on the bare card, and also when the unmask comes 20 ms after the
90h: the count moves within 1 ms. Through uCDD (D7) the count never
moves, on the virtual SB16 [hw] and SB Pro [trace]. The same holds for a
1-byte 14h ([ct2290.md](ct2290.md), the late unmask).

### F6. Duke Nukem 3D's SB Pro path never starts on the virtual SB Pro

**Probably the same mistake as F16 (20 Oct).** These runs used Duke's
config as eXo left it: `BlasterType = 6` (SB16) and `BlasterInterrupt = 7`,
so at IRQ 5 the game hooked the wrong line. Set up as its setup program
does for an SB Pro (BlasterType 4, 8 bits) on IRQ 7, Duke plays under uCDD's
virtual SB Pro as on 86Box's own SB Pro 2 [86Box, D7, the sound check, 20
Oct]. The IRQ 7 runs below came before that set-up and may be F4. Kept
open until a trace on the right set-up shows 90h running.

On the virtual SB Pro, Duke Nukem 3D (configured SBType 6, so it checks
the DSP itself) sets time constant E9h (43.5 kHz), 48h 512 and 90h, mono,
and gets no interrupt: its DMA address never moves, it sends D3h twice
and gives up. The same at IRQ 5, so not F4. DOSBox-X's SB Pro 1 and 2
play the same sequence at one interrupt every 12 ms. Stargunner's 90h at
the same time constant (stereo) plays on the virtual SB Pro at IRQ 5, so
the rate is not the cause. Open; Duke reads the 8237's address and page
register rather than the count, which the earlier stalls did not.

Duke's DSP and 8237 sequence on its own (8237 mode 59h and 4096 bytes,
E9h, D1h, 48h 512, 90h, a handler that reads the PIC's in-service
register) plays on the virtual SB Pro at IRQ 5, one interrupt every 11.6
ms [trace, 19 Oct]: the stall comes from something else the game does.

### F7-F13. Found by measuring the CT2290 (19 Oct)

Each is the virtual SB16 under D7 against the bare CT2290 on the same PC,
both [hw]; the numbers are in [ct2290.md](ct2290.md).

- **F7.** Time constants: the card plays A5h at 10846 Hz, D3h at 22047,
  E9h at 43383; the virtual card at 11023, 22046 and 44092 (A5h and E9h
  1.6% fast).
- **F8.** At a block's interrupt the card's 8237 count sits exactly on the
  block boundary; the virtual count is about 7Dh short of it. The card's
  FIFO (16 samples) brings the first interrupt 0.7 ms forward; the virtual
  card shows no such difference. In stereo (B6h mode 30h) the virtual
  count is FCh words short [trace].
  23 Oct 2026, fixed for auto-init on branch `count-position` (30c82ca,
  ISSUES.md F8): the count and the block interrupt come from one position,
  the frame heard plus one period, never past what uCDD has taken (vsb-spec
  7.8). [86Box, 32 frames: every auto-init SBT16 case now reads the count
  on the boundary or up to one period past it at the interrupt, where it
  read one to two periods short; single-cycle was already on it; the sound
  check as before.] Hardware: not yet.
- **F9.** A block never acknowledged: the card raises one interrupt and
  stops the DMA within about two blocks until the acknowledge; the virtual
  card raises 7 interrupts in 300 ms and never stops.
- **F10.** An interrupt the card raises while the program has interrupts
  off reaches the handler 2.1 us after STI; the virtual one 0.47-0.81 ms
  after. With interrupts on the virtual F2h takes 26 us (card 36 us).
- **F11.** Short transfers end within about a sample on the card (a 1-byte
  14h at A5h: 65 us; DMX's 12-byte priming: 0.5 ms; a channel unmasked late:
  32 us after the unmask); the virtual card ends them at its next output
  period (0.7 ms, 0.8 ms, 2.3 ms).
- **F12.** Mixer 80h and 81h are writable on the card (it is a
  software-configured SB16) and 83h keeps bits 0-3 (0Bh reads FBh); the
  virtual card reads fixed values for all three. The specification now
  follows the card for 80h and 81h (vsb-spec.md 9.4, on the notes branch,
  changed 27 Oct 2026, Michael, Project A question 15: an 81h write takes
  effect, and with no 16-bit channel bit 16-bit data moves on the 8-bit
  channel, SBG:1136-1138; PnP boards differ, SBG:1140-1148); the pinned
  build does not yet (ISSUES.md CAND-14, notes branch).
- **F13.** The card's DSP takes 61 us to reset, shows busy for 26 us after
  each command byte and in 46% of idle reads, and answers E1h in 31 us;
  the virtual DSP answers in 6-12 us and never shows busy.

### F14. Mortal Kombat Trilogy's game sounds play about 2.3x long

Under uCDD the logo sounds of Mortal Kombat Trilogy (Miles 3.5, the SB16
driver shared with Dungeon Keeper: B6h mode 30h, 22050 Hz, 1024-word
blocks in a 2048-word auto-init buffer, DOS/4GW) last about 2.3 times as
long as without uCDD, at the right pitch. Placed piece by piece against a
run on 86Box's own CD drive, each 40 ms of the uCDD sound covers about
17 ms of the true sound and keeps stepping back: the card plays a buffer
half again before the game's handler has refilled it, so the refill comes
a block (23.2 ms) or more late. Michael's recording on the PC: x2.22
[hw, 19 Oct]; 86Box with D7: x2.38 [trace]. Every uCDD build that ran the
game has it (18 and 19 Oct captures); the runs without uCDD do not. The
CD music in the same recordings is exact. Not the stereo block length:
B6h mode 30h with length 1024 interrupts every 23.2 ms under D7, as on
the card [trace].

**Cause [trace, 19 Oct]:** DOS/4GW passes IRQ 5 down to the Miles
driver's real-mode handler with an INT to the hardware vector, and the
DPMI host marked the next EOI as a stray one for every hardware vector it
reflected so, as if it had queued the IRQ and sent its EOI itself. For
the virtual interrupt it had not: the game's EOI was swallowed, the
virtual interrupt stayed in service, and block after block ended with the
previous interrupt unacknowledged (58% of them; none of the game's EOIs
ended it) until some other EOI did. **Fixed** on branch `stray-eoi`: the
mark only when the host held the IRQ in service. 86Box: no block ends
over an unacknowledged one, the sounds x1.00 against the run without
uCDD. Hexen (DOS/4GW too) chops some sounds on the PC: to check with the
fix.

**Not MKT alone [trace, 19 Oct]:** the same trace without and with the fix
on 28 games for about 90 s each, every Miles SB16 driver version in the
library among them. "Overruns" are block ends while the previous block's
interrupt was unacknowledged; "swallowed" are the game's EOIs taken for
stray ones.

| Games | Without the fix | With it |
|---|---|---|
| Mortal Kombat Trilogy, Theme Hospital, Dungeon Keeper, Redguard, Little Big Adventure 2, Motor Mash, Time Commando, X-Men: Children of the Atom | 56-58% overruns | 0% (Motor Mash 1%) |
| Grand Theft Auto 77%, Bust-A-Move 2 30%, System Shock 15%, Jagged Alliance 15% | overruns | 0% |
| Heroes of Might and Magic II, Oddworld, Test Drive Off-Road, Star Command Revolution, Warcraft, Albion, Caesar II, The Settlers II, X-COM (DigPak) | EOIs swallowed as often as blocks end, no overruns (another EOI ended the interrupt in time) | swallowed 0-19 |
| Doom, Hexen, Descent | clean (handlers in protected mode) | clean |

So the fault is the host's, not Miles': any game whose sound interrupt
reaches a real-mode handler through an INT to the hardware vector, which
DOS/4GW does for Miles' real-mode drivers and for DigPak's. Two games
kept overruns with the fix: F15, and F16, which turned out to be the
game's own config.

### F15. Fade to Black overruns with or without the F14 fix

84% of its block ends overran without the fix, 79% with it, with no EOI
swallowed [trace, 19 Oct]. Its Miles SB16 driver is the one version not
traced before (0c12adc1). Not looked at yet.

### F16. Duke Nukem 3D on the virtual SB16: the interrupt is never taken

172 of 173 block ends overran, and no EOI ever ended a virtual interrupt,
with or without the F14 fix [trace, 19 Oct]: the virtual interrupt
appears never to reach the game.

**Not a uCDD fault (20 Oct).** The copy of Duke traced still had eXo's
`BlasterInterrupt = 7` in DUKE3D.CFG while both cards were on IRQ 5: the
Apogee Sound System takes the IRQ from its config file (apogee.md), so it
hooked IRQ 7 and never saw the card's interrupts. On 86Box's own SB16
without uCDD, set up the same way, Duke stops its sound with "Playback
failed, possibly due to an invalid or conflicting IRQ" [86Box, 20 Oct]:
the real card answers the same. With the config at 5, as Duke's setup
writes it on Michael's PC (irq7_game_configs.txt lists the line), Duke
plays under uCDD as without it on the SB16, the SB Pro and the SB 2.0
[86Box, D7, the sound check, 20 Oct]. The lesson is the "checking a game"
rule: a fault is uCDD's only if the game behaves otherwise without uCDD
on the same set-up.

### F17. Jill of the Jungle: sounds play too long on the virtual cards

Found by the sound check (20 Oct): Jill's demo, with Creative's driver
(CT-VOICE, creative.md), against two runs on 86Box's own card of the same
model with no uCDD. A sound of about 1.5 s in the reference lasts about 6
s under uCDD, another short one is stretched too, and the rest of the demo
comes about 4 s later. The same on the virtual SB Pro (IRQ 7) and the
virtual SB16 (IRQ 5), on D7 and D9 alike [86Box]; the SB 2.0 has no
reference (Jill stops at its logo on 86Box's own SB 2.0). A first SB16 run
that "passed" had the driver stepped aside onto the bare card (no CD
audio); held on, it fails. Jill's driver runs in real mode, so this is
not F14's path. Not looked at yet. By rule 10 the first step is the
family: Creative's drivers on the virtual cards across the games that use
them (about 28, inventory.md), then the driver's transfer and interrupt
habits there (14h per VOC block, single-cycle).

### F18. DMX mixes one block ahead of a count that trails what uCDD has taken

Found reading Hexen's DMX (20 Oct; [dmx.md](dmx.md) steps 15 and 16)
[code], with the 19 Oct trace of Hexen [trace] and the CT2290's count
[hw, F8].

DMX mixes, at a 140 Hz timer tick after each block interrupt, exactly the
block after the one the 8237 count is in: at most 11.6 ms ahead. On the
CT2290 the count is where the DMA has fetched to and sits on the block
boundary at the interrupt, so DMX always writes a block at least 4.5 ms
before the card takes it. Under uCDD the block interrupt comes when the
mix (what uCDD has taken from the buffer) crosses the boundary, but the
count follows the output clock (the frame being heard; trap.asm, since
5e3f364 on 15 Oct), one to two output periods behind the mix: 2.9-5.8 ms
with 128-frame periods, the period of D7 and D9. On the PC that shows as
F8: the count about 7Dh short of the boundary at the interrupt. DMX's
lead over what uCDD takes shrinks by that much:

- When DMX's tick finds the count still in the old block, it waits a tick
  (the "count twice" of the traces) and mixes 7.1 ms later. If by then
  uCDD has taken the start of the next block, that start plays what the
  buffer held one lap (186 ms) earlier. At 128 frames the window is
  small: up to about 1.3 ms of a block in about one block in five, by
  the arithmetic [reading].
- When DMX falls a block behind (a late tick or interrupt), it mixes the
  block uCDD is already taking, and when the count has moved two blocks
  between its reads it skips a block: 11.6 ms of sound 186 ms old. The
  19 Oct trace of Hexen (snd_tr, a trace build, both cards on IRQ 7)
  shows both at the start of play: blocks mixed while uCDD was 0-120
  bytes into them, and 6 blocks skipped in 48 mixes; the reads then
  settle into the safe pattern [trace].
- 256-frame periods (5.8-11.6 ms behind) leave DMX no margin: the output
  period table's "256 is silent on a virtual SB Pro" (ISSUES.md) is
  probably this. 32-frame periods (0.7-1.5 ms) leave it its margin.

Measured: a detector for blocks that replay the sound of one lap before,
starting on DMX's block grid (the bench's rec/stale.py), finds 64% of
stale blocks injected into a recording (the misses fall in silence),
and in the sound check's D7 and D9 recordings of Hexen at 128 frames
nothing above the two references [86Box]. So on the clean build, at
86Box's timing, DMX keeps its margin. Not measured yet: the 256- and
32-frame builds (their runs stopped on a fault of the bench's host) and
the PC. Whether this is the chop Michael hears in Hexen is open; F2
below is the other candidate.

What it says about the count (rule 1): the CT2290's count tells how far
the card has taken data. A count that trails that breaks engines writing
just ahead of the count (DMX); one that runs ahead of it breaks engines
writing just behind (HMI). On the Sound Blaster models uCDD's mix position
is what it has taken: mix.asm sets it inside the period handler, with
interrupts off. The HMI clicks that 5e3f364 fixed were on the virtual
ESS, whose mixer reads a delayed ring (ess_fifo.asm), so there the mix
position ran ahead of what was taken [reading]. A fix needs the survey
of every engine that reads the count, by which side of it each writes
(rule 10), and keeps the ESS separate (rule 6).

22 Oct 2026, the known-bad case (lesson L4) [86Box, D9 c24d232 at 256
frames, SB16 on IRQ 5, Hexen's 50 s moment with its CD music]: the
stale-block check (stale.py) shows no DMX block played a lap late. Hits
per block phase are flat (best 56, next 53; the reference 37 and 37), no
match is 128 or 256 samples long, as in the reference, the control and
D9 at 32 and 128 frames. The 256-frame run has about 45% more short
(16-32 sample) matches than the reference, spread over every phase, not
on DMX's block grid; cause not known. The sound check failed it on the
CD music (6 windows off its lag, the control's 2), not on the game's
sounds (on time 0.92, the control's 1.00). So at 86Box's timing even 256
frames does not make DMX mix a block uCDD has taken, or the check cannot
see it: not decided until a planted fault (a count trailing by several
more periods) shows stale blocks to the check. The count rule is in
vsb-spec 7.8 (irq-counters 3cecfc5); no fix until a check fails on the
build it fixes.

F5's confirmation is above. The card also settles three things the
virtual card already does right: no lockout during 90h on the 4.13 (D0h,
D4h and E1h are taken), FAh has no reply and swallows what follows until
a reset, and a 0Ch write leaves channel 5's flip-flop alone.

### F1 confirmed

System Shock on DOSBox-X's SB16 plays its digital sound (46 ms blocks),
where uCDD's runs with both cards on IRQ 7 lost the probe interrupt.

## Behaviour to copy (rule 1: as the real hardware would)

| # | Engine | What it does | What the card must do |
|---|---|---|---|
| B1 | HMI SOS | clears 0Ch (the 8-bit controller's flip-flop) before channel 5's address and count | keep channel 5's flip-flop on the 16-bit controller only (D5 in host-cdrom-spec.md) |
| B2 | Sierra AUDBLAST | reads the count one byte per poll, no flip-flop clear | toggle the flip-flop on every read |
| B3 | Apogee Sound System | reads channel 5's **current address** and the **page register** 8Bh | the address register moves with the output; page registers read back |
| B4 | DigPak SB16 | writes mixer 81h = 02h | the CT2290 takes it: 81h is writable there and selects the DMA channels [hw, M2]; the virtual card ignores it (F12) |
| B5 | HMI SOS, DigPak SB Pro 1993 | write mixer 83h = 0Bh | the CT2290 keeps bits 0-3 (reads FBh after it) and an 8-bit transfer runs the same [hw, M1]; the virtual SB16 reads FFh (F12) |
| B12 | games set for SB Pro on an SB16 (Rayman's HMI SB Pro module, Castles II, Kyrandia) | select stereo through mixer 0Eh bit 1 | nothing: 0Eh does not exist on the SB16 (the CT2290 reads 00h whatever is written), so they play mono; the virtual SB16 does the same [hw: vsb-spec.md 9.4] |
| B6 | DSMI (Cyberdogs) | sets the output rate with 42h only | 42h sets the shared rate register (the virtual SB16 does) |
| B7 | DSMI, MIDAS, Battle Race | one block of 60000+ samples over a small DMA buffer | the interrupt almost never comes; the count must be right |
| B8 | DMX, Sierra, Creative, Loudness, Tyrian | find the IRQ by F2h, a 1-byte 14h, or an 80h silence, with several lines open | one interrupt per test, on the card's line, after the command |
| B9 | DigPak SB16, Cool Spot, Sound Images | write the master PIC mask 00h (every line open) | nothing; the driver's own handlers must cope |
| B10 | Castles II | writes IRQ 1's mask bit about 15 times a second | cheap mask writes |
| B11 | Miles MSS 3; Gateway 2 | latch the PIT's counter often: Albion some 500 times a second (at least 31246 latches in a run of about a minute); Gateway 2 in a tight loop, alternating latch commands 00h and 01h (842000 in a run) | with the host's retrace hint on (it traps 40h and 43h) every latch and its two reads are traps: about 1500 a second for Albion, far more for Gateway 2; the usual builds (`--no-refill-hint`) do not trap them ([music-and-timers.md](music-and-timers.md)) |

## To measure on the CT2290

| # | Question | How |
|---|---|---|
| M1 | What does mixer register 83h do (HMI writes 0Bh)? | **Answered [hw, 19 Oct]:** bits 0-3 are kept (0Bh reads back FBh; FFh before); a 1-byte C0h takes the same 50 us with 0Bh in it. What the bits do: not known |
| M2 | Is mixer 81h writable on the CT2290? | **Answered [hw, 19 Oct]:** yes, and 80h too (81h 22h -> 20h read 20h; 80h F2h -> F4h read F4h; both put back). The card is software-configured |
| M3 | Does an auto-init transfer keep running when its interrupt is never acknowledged? | **Answered [hw, 19 Oct]:** no: one interrupt, then the DMA stops within about two blocks; one acknowledge restarts it |
| M4 | Does channel 5's current address register move with the transfer, and does 8Bh read back? | **Answered [hw, 19 Oct]:** the address moves (address + count constant); 8Bh read back 00h as written (page 0: a weak test) |
| M5 | Does a 0Ch write disturb channel 5's flip-flop? | **Answered [hw, 19 Oct]:** no, 64 of 64 reads consistent |

## Not engine faults, seen on the way

- Inca II ("Not enough extended memory", a negative free size) and Star
  Trail (negative free XMS) read the test machine's large memory wrongly;
  Inca II is the Phar Lap case in host-cdrom-spec.md section 10. Death
  Rally stopped with "Stack Overflow" while loading; not looked at.
- Ultima VII refuses to run with an expanded memory manager: it needs a
  boot entry without JemmEx.
- System Shock and Warcraft are F1, not their own fault.
