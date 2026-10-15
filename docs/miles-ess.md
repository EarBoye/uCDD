# The Miles ESS digital driver on the virtual ESS

Status: branch `ess-registers`, 15 Oct 2026. Emulator results (86Box);
the real PC has not run it yet.

This note records how the Miles Sound System's ESS digital driver
(AUDIODRV.DIG, Miles 3.5, "ESS AudioDrive" in DIG.INI) was made to work on
the virtual ESS, so that the next fault in this area does not start from
nothing. It took several sessions. The games: Theme Hospital, Dungeon
Keeper, Heroes of Might and Magic 2 and 13 more in the libraries.

## What the driver does, in order

Read from the driver's code and from port traces of Theme Hospital. Offsets
are into the DIG file as loaded (the driver's code runs at offset 100h, so
a code address is the file offset plus 100h).

1. **Reset and identification.** Reset (2x6h 3/0 then 1/0, AAh), C6h, E7h.
   The chip answers 68h and 8xh; the driver checks both.
2. **IRQ and DMA from B1h and B2h** when DIG.INI says -1: bits 3:2 of the
   read-back (B1h: 00 IRQ 9, 01 IRQ 5, 10 IRQ 7, 11 IRQ 10; B2h: 01 DMA 0,
   10 DMA 1, 11 DMA 3). See ISSUES.md, B1h/B2h.
3. **The F2h interrupt test** (file offset 433h on). It hooks the IRQ
   with a counting handler, clears its counter, then:
   - sends F2h and F2h, and spins up to 65536 turns of
     `cmp word [count],1 / loopne` (no port access) for the count to read
     **exactly** 1;
   - sends F2h, spins for exactly 2;
   - sends F2h, spins for exactly 3;
   - unhooks. Any spin that runs out means no card.

   On the ES1868F each F2h raises its own interrupt 11.7 to 14.2 us after
   the command, one after the other, while the program runs on (F2TEST:
   two F2h back to back give two interrupts; F2h, interrupt not
   acknowledged, F2h gives one). So the count passes through 1, 2 and 3.
4. **The E2h DMA identification**, twice (E2h AAh, one byte by DMA on the
   8-bit channel, expected E6h then F5h). E2TEST matches the hardware.
5. **The playback set-up** (file offset 566h on): reset, C6h, B8h=04h,
   A8h read and written with bits 1:0 = 01 (stereo) or 10 (mono), A1h,
   A2h, A4h/A5h (block length), B6h, B7h twice (71h then BCh for 16-bit
   signed stereo), B1h and B2h as `(read AND 0Fh) OR 50h`, then **1000
   writes of D3h as a delay** (offset 6F6h; with interrupts on), D1h, the
   8237 programmed (Theme Hospital: mode 19h, demand, auto-initialize,
   read, 4096 bytes on channel 1), B8h read and written with bits 0 and 2
   set.
6. **The playback interrupt handler** (file offset 85Bh, hooked through
   INT 21h AH=25h at set-up) reads 2xEh first, then does its block work
   and ends with a specific EOI (67h for IRQ 7).

A trace of the first 1000 trapped accesses fills up with step 5's D3h
delay; filter out the 2xCh status polls and D3h to see what follows.

## Fault 1: the F2h interrupts came at once

The virtual DSP raised each F2h's interrupt inside the trap of the command
itself. The game's handler ran at the trap's exit, before the second F2h
was even written, and the second F2h raised the next one at its own exit.
By the time the spin started the count was already 2, it never read 1, and
the driver found no card. The game then ran with no digital sound (Theme
Hospital's intro played silently).

A trap cannot interrupt the program a few microseconds later on its own:
nothing runs until the next trapped access or output interrupt. So the
model (irq.asm, `virtual_f2h`, `f2h_service`):

- An F2h raises its interrupt at once, as before, unless another F2h was
  raised within the last 8 trapped port accesses (`F2H_CALLS`) and 128
  output frames (`F2H_FRAMES`). That one is **held**.
- Held F2h interrupts are raised one at a time, one at each later trapped
  access (port_callback's entry) or output interrupt (the period handler).
- A DSP reset clears the held ones.

Why count accesses and not time: in the chip's 13 us a program makes only a
few port accesses, whatever the CPU. Measured in time, the gap between
Miles' two F2h is about 3 us on the chip but 3 to 7 output frames on the
Pentium under the driver (each trapped access costs about 31 us there), and
far longer on a 386. A frame window failed in the first attempt for that
reason.

With the hold, Miles' test runs: F2h 1 raises (count 1), F2h 2 is held, the
spin sees 1; at the next status poll F2h 2's interrupt is raised (count 2),
F2h 3 is held, the spin sees 2; and so on.

Side effect, measured: F2TEST's single-F2h latency under the driver reads
20 to 21 PIT counts in 86Box (10 before), because the F2h path now reads
the output clock. The ES1868F reads 14 to 17. Pair and no-acknowledge
results are unchanged (2 and 1).

## Fault 2: the interrupt went to the driver's own handler

With the F2h test passing, the game froze on the intro's first frame: the
driver now started playback and waited for its block interrupts, and none
reached its handler. The virtual ESS raised them on time (every 23.2 ms,
2048-byte blocks of 16-bit stereo at 22094 Hz, checked by a mark in the
trace), and the virtual PIC showed each delivered and ended with an EOI,
yet the handler's first instruction, a 2xEh read, never showed in the
trace.

The cause. When the card's physical IRQ and the game's virtual IRQ are the
same line (the real PC: both 7), the interrupt vector holds the driver's
`audio_irq`, and the game's handler, set through INT 21h AH=25h, is kept in
`sb_game_vector` (sb_patch.asm, `sb_dos_vector`). Two delivery paths knew
that: the trap exit (`host_io_irq`) and the period handler's real-mode jump
(`sb_real_irq`). The third did not: the driver's DPMI host, delivering the
virtual interrupt to a protected-mode client that has no protected-mode
handler for it, runs the guest vector in real mode (dpmi.asm, `.real_irq`,
`mon_real_int`). That entered `audio_irq` with no physical interrupt behind
it. On IRQ 7 it found the in-service bit clear and returned as from a
spurious interrupt; on another line it would have gone to the vector that
was there before the driver. The game's handler never ran. The game's other
EOIs (its fast timer) were then credited to the virtual interrupt, so the
virtual PIC looked clean while the DSP line stayed high: no new edge, no
more interrupts.

The fix (sb16.asm, `audio_irq_reflected`): the delivered mark now has two
values. The host sets 1 when it delivers (through `resident_delivered`);
the driver's own two paths, which jump straight to the game's handler, set
2. At `audio_irq`'s spurious exit and its unowned exit, a mark of 1 with
the guest IRQ equal to the card's means the entry is the host's delivery:
the mark becomes 2 (still set for the EOI credit) and control goes to
`sb_game_vector`. A spurious IRQ 7 while the game's handler runs (mark 2)
is not mistaken for one.

Any game on the driver's DPMI host with a real-mode sound handler and the
same IRQ as the card could take this path, for each interrupt that arrives
while the game is in protected mode. Why Theme Hospital's Sound Blaster 16
driver did not show it is not established; the regression run of that
driver is in ISSUES.md.

## How it was found, for next time

- **A port trace build.** A local build defines TEST_SB_TRACE: trap.asm
  logs trapped accesses (port, kind, value, output period) at `.done`, and
  `tr_mark` adds marks from anywhere in the driver (for example in
  `virtual_dsp_raise_line`, with the virtual PIC's state). After the game
  exits, a memory search for the log's signature dumps it. Filter what
  floods the log: EOIs on port 20h (log them only while the virtual line is
  requested or in service), 2xCh status polls, keyboard port 60h.
- **Getting the game to exit** so the log can be read: Escape presses at
  45, 50, 55 and 60 s in Theme Hospital.
- **Separating the model from the delivery.** ESSAUTO (a test program
  outside this repository) repeats step 5 in real mode and counts the
  interrupts: 23 in 550 ms, the right number, on the virtual ESS and on the
  emulated chip. That put the fault in the delivery, not the model.
- **Reading the driver.** The F2h test and the handler were found by
  searching the disassembly for `mov al,0F2h` and `add dx,0Eh`.

## Results (86Box, 15 Oct 2026)

- Theme Hospital, AUDIODRV.DIG, DIG.INI IRQ and DMA -1, the virtual ESS at
  32 frames: the intro plays with sound and the game runs on. Before: the
  intro silent (fault 1), then frozen on its first frame (fault 1 fixed,
  fault 2 not).
- Theme Hospital, the same at 128 frames: sound in 129 of 160 seconds.
- Regression against the previous build (7daee02):
  - SBT16 on seven card pairings: identical output.
  - SADUMP: the same apart from the driver's own addresses (the code grew).
  - verify-mix: 0 bad samples and 0 bad state in nine cases.
  - E2TEST: 40h 30h F3h 98h, as the hardware, on the virtual ESS and SB16.
  - F2TEST and ESSSTAT: as before, except the single-F2h latency above.
  - Doom timedemo: 1652 realtics (1654 before).
  - Descent 2 on the virtual ESS: 1.1 and 0.9 clicks a second at 128 and
    32 frames (0.9 and 1.1 before; the detector's floor is about 1).
  - Theme Hospital on SB16.DIG: the intro's sound second by second as in
    the earlier run.
  - Warcraft II (SBPRO.DIG with ESFM music, virtual ESS): sound in 57 of 89
    seconds, mean level 125 (58 and 126 before).
