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
  virtual card reads fixed values for all three.
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
