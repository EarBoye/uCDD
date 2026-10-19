# Findings from the engine traces (19 Oct 2026)

What the 74 traced games showed that matters for uCDD: faults in the
driver, things the specification does not settle, and what to measure on
the CT2290. Every item is [trace] (86Box, the engine-trace build of the
`vcpi-children` line, 128-frame period, a virtual SB16 at 220h, DMA 1 and
5) unless it says otherwise. Nothing here is fixed yet; each needs its
own branch and test.

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

### F6. Duke Nukem 3D's SB Pro path never starts on the virtual SB Pro

On the virtual SB Pro, Duke Nukem 3D (configured SBType 6, so it checks
the DSP itself) sets time constant E9h (43.5 kHz), 48h 512 and 90h, mono,
and gets no interrupt: its DMA address never moves, it sends D3h twice
and gives up. The same at IRQ 5, so not F4. DOSBox-X's SB Pro 1 and 2
play the same sequence at one interrupt every 12 ms. Stargunner's 90h at
the same time constant (stereo) plays on the virtual SB Pro at IRQ 5, so
the rate is not the cause. Open; Duke reads the 8237's address and page
register rather than the count, which the earlier stalls did not.

### F1 confirmed

System Shock on DOSBox-X's SB16 plays its digital sound (46 ms blocks),
where uCDD's runs with both cards on IRQ 7 lost the probe interrupt.

## Behaviour to copy (rule 1: as the real hardware would)

| # | Engine | What it does | What the card must do |
|---|---|---|---|
| B1 | HMI SOS | clears 0Ch (the 8-bit controller's flip-flop) before channel 5's address and count | keep channel 5's flip-flop on the 16-bit controller only (D5 in host-cdrom-spec.md) |
| B2 | Sierra AUDBLAST | reads the count one byte per poll, no flip-flop clear | toggle the flip-flop on every read |
| B3 | Apogee Sound System | reads channel 5's **current address** and the **page register** 8Bh | the address register moves with the output; page registers read back |
| B4 | DigPak SB16 | writes mixer 81h = 02h | ignore it, as a jumpered card does, unless the CT2290 shows otherwise (M2) |
| B5 | HMI SOS, DigPak SB Pro 1993 | write mixer 83h = 0Bh | nothing: the CT2290 has no register there (reads FFh); the virtual SB16 reads the same (M1) |
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
| M1 | What does mixer register 83h do (HMI writes 0Bh)? | **Half answered [hw, SBKIT 17 Oct]:** the CT2290 reads FFh from 83h up, so it has no such register (vsb-spec.md 9.4); left: play a block with 0Bh written, to see it changes nothing |
| M2 | Is mixer 81h writable on the CT2290? | read 81h, write 02h, read back, restore |
| M3 | Does an auto-init transfer keep running when its interrupt is never acknowledged? | as DMACNT: start DSP C6h (8-bit auto-init), never read 2xEh, read the count over 2 s |
| M4 | Does channel 5's current address register move with the transfer, and does 8Bh read back? | read C4h and 8Bh during a B6h transfer |
| M5 | Does a 0Ch write disturb channel 5's flip-flop? | write port 0Ch between the two byte reads of port 0C6h |

## Not engine faults, seen on the way

- Inca II ("Not enough extended memory", a negative free size) and Star
  Trail (negative free XMS) read the test machine's large memory wrongly;
  Inca II is the Phar Lap case in host-cdrom-spec.md section 10. Death
  Rally stopped with "Stack Overflow" while loading; not looked at.
- Ultima VII refuses to run with an expanded memory manager: it needs a
  boot entry without JemmEx.
- System Shock and Warcraft are F1, not their own fault.
