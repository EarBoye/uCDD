# Findings from the engine traces (19 Oct 2026)

What the 74 traced games showed that matters for uCDD: faults in the
driver, things the specification does not settle, and what to measure on
the CT2290. Every item is [trace] (86Box, the engine-trace build of the
`vcpi-children` line, 128-frame period, a virtual SB16 at 220h, DMA 1 and
5) unless it says otherwise. Nothing here is fixed yet; each needs its
own branch and test.

## Faults in uCDD

### F1. Shared IRQ 7: the 1994 Miles probe interrupt is lost

Warcraft and System Shock (Miles Sound System 3.0x, SB16.DIG) send their
one-sample probe (B0h, length 0) and wait for its interrupt. With the
physical card and the virtual card **both on IRQ 7**, the game's handler
never ran in 5 of 6 runs: four probes, then the driver gives up and the
game has no digital sound. With the physical card on IRQ 5 and the
virtual on IRQ 7, 3 of 3 runs passed; with both on IRQ 5,
1 of 1. Theme Hospital, Dungeon Keeper and Time Commando (Miles 3.5)
pass the same probe on 7/7. System Shock on 86Box's own SB16 without
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
| Star Dust | MIDAS | 28 of 203 | 68-69 words, once 529 |
| Dark Forces | iMUSE | 19 of 235 | 104 bytes |
| Hexen | DMX | 14 of 135 | 98 bytes |
| Cyberdogs | DSMI | 13 of 234 | 146-220 words (reads far apart: less sure) |
| Raptor | DMX | 1 of 106 | 356 bytes |

The count is the smaller of the output clock and the mix position
(trap.asm, `.dma_read`), so the output clock itself moves back by about
one to two output periods at times. A suspect, not shown: the clock read
between the physical position's wrap and the period counter's advance.
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

## Behaviour to copy (rule 1: as the real hardware would)

| # | Engine | What it does | What the card must do |
|---|---|---|---|
| B1 | HMI SOS | clears 0Ch (the 8-bit controller's flip-flop) before channel 5's address and count | keep channel 5's flip-flop on the 16-bit controller only (D5 in host-cdrom-spec.md) |
| B2 | Sierra AUDBLAST | reads the count one byte per poll, no flip-flop clear | toggle the flip-flop on every read |
| B3 | Apogee Sound System | reads channel 5's **current address** and the **page register** 8Bh | the address register moves with the output; page registers read back |
| B4 | DigPak SB16 | writes mixer 81h = 02h | ignore it, as a jumpered card does, unless the CT2290 shows otherwise (M2) |
| B5 | HMI SOS, DigPak SB Pro 1993 | write mixer 83h = 0Bh | nothing documented; see M1 |
| B6 | DSMI (Cyberdogs) | sets the output rate with 42h only | 42h sets the shared rate register (the virtual SB16 does) |
| B7 | DSMI, MIDAS, Battle Race | one block of 60000+ samples over a small DMA buffer | the interrupt almost never comes; the count must be right |
| B8 | DMX, Sierra, Creative, Loudness, Tyrian | find the IRQ by F2h, a 1-byte 14h, or an 80h silence, with several lines open | one interrupt per test, on the card's line, after the command |
| B9 | DigPak SB16, Cool Spot, Sound Images | write the master PIC mask 00h (every line open) | nothing; the driver's own handlers must cope |
| B10 | Castles II | toggles IRQ 1's mask about 15 times a second | cheap mask writes |

## To measure on the CT2290

| # | Question | How |
|---|---|---|
| M1 | What does mixer register 83h do (HMI writes 0Bh)? | read 83h after a reset, write 0Bh, read back; play a block with 83h 00h and 0Bh |
| M2 | Is mixer 81h writable on the CT2290? | read 81h, write 02h, read back, restore |
| M3 | Does an auto-init transfer keep running when its interrupt is never acknowledged? | DMACNT-style: start C6h, never read 2xEh, read the count over 2 s |
| M4 | Does channel 5's current address register move with the transfer, and does 8Bh read back? | read C4h and 8Bh during a B6h transfer |
| M5 | Does a 0Ch write disturb channel 5's flip-flop? | write 0Ch between the two bytes of a C6h read |

## Not engine faults, seen on the way

- Inca II ("Not enough extended memory", a negative free size), Star
  Trail (negative free XMS), Death Rally ("Stack Overflow" at loading):
  three games that read the test machine's large memory wrongly; Inca II is the
  Phar Lap case in host-cdrom-spec.md section 10.
- Ultima VII refuses to run with an expanded memory manager: it needs a
  boot entry without JemmEx.
- System Shock and Warcraft are F1, not their own fault.
