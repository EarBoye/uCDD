# The virtual ESS AudioDrive: behaviour specification

Version 0.4, 16 Oct 2026. Clean-sheet design, written from the ESS data
sheets before any code. The ES1868 is the spine; version 0.2 adds the
family pass over the ES1869, ES1878, ES1887 and ES1888 sheets (commands,
extension registers, mixer, stereo order, reset values), and section 17
lists where the current uCDD virtual ESS departs from this document.
Version 0.3 adds section 18: the ES688/ES1688 (no sheet) from the Linux
drivers and the emulators' source, how real software identifies each model,
and the clock and rate notes those sources give. Version 0.4 (16 Oct, from
the first regression of the clean card) adds E2h (7.1), the state at
install (10.3) and corrects the Table 21 summary (10.2).

## 0. Rules, sources and conventions

This document follows the project's mantra (docs/spec-first.md, section 12,
on the spec-first branch). Three rules
shape it:

- **Rule 1.** The data sheets decide. Where they are silent or disagree,
  emulation decides first, then the real ES1868F, and the disagreement is
  written down here (section 14).
- **Rule 6.** The ESS is not a Sound Blaster. Its compatibility mode is
  described by the ESS sheets, not by Creative's guides; nothing here is
  inherited from the Sound Blaster model and "corrected".
- **Rule 8.** Every statement carries its grade: **[sheet]**, **[emu]**
  (an emulator's behaviour or source), **[driver]** (a driver written
  against the real chips: Linux es18xx.c and es1688_lib.c, v5.0), **[hw]**
  (the ES1868F in Michael's PC), or **[inference]** (reasoning from the sheet, to be confirmed).

Sources, in reference-library under `Sound Cards/ESS AudioDrive/`. Aliases
follow notes/sound-cards.md:

| Alias | File | Chip |
|---|---|---|
| E68 | ESS_ES1868_Data_Sheet_1996.txt | ES1868 |
| E69 | DS1869.txt (DS1869_other_revision.txt agrees on what is cited) | ES1869 |
| E78 | DS1878A.txt | ES1878 |
| E87a, E87b | ES1887_Data_Sheet_part_1_of_2.txt, part_2_of_2.txt | ES1887 |
| E88 | ES1888_Design_Guide_1995-10_rev_C.txt | ES1888 |

There is no sheet in the library for the ES688 or ES1688. Anything said
about them is **[emu]** only.

Hardware measurements: section 13, from the ES1868F conformance runs of
15 Oct 2026 (CONF, JEMM.TXT and UCDD.TXT; the report is in the project notes).
Line numbers below are into the text files (E68:2710 is line 2710 of the
ES1868 sheet).

Notation: `2xNh` is a port at the card's base (220h, 240h...). Registers
A0h to BFh are the extension registers (written as commands). Mixer
registers are written as `mixer NNh`.

## 1. What the virtual card is

- A virtual ESS AudioDrive that a DOS program cannot tell from the chip it
  presents, for everything the program can observe: ports, replies, status
  flags, register read-back, interrupts, DMA counts and their timing.
- **The model it presents.** By default, the ESS chip in the machine (the
  physical card): its E7h bytes and mixer 40h sequence (section 2). Where
  models differ, the virtual card follows the presented model's sheet
  (section 12). [design decision]
- **In scope now.** Audio 1 playback in compatibility and extended modes,
  the command interface, the extension registers, the mixer, interrupts,
  identification.
- **Defined but not implemented in the first build.** Recording (ADC),
  Audio 2 (second DMA channel, full duplex), programmed I/O to the FIFO
  (2xFh), serial (DSP) mode, power management, PnP configuration. For each,
  section 15 says what the virtual card answers meanwhile, so a program sees
  a consistent card, never garbage.
- **Not the virtual card's.** The FM synthesizer (2x0h-2x3h, 2x8h-2x9h,
  388h-38Bh) and MPU-401: the physical chip's own, passed through.

## 2. Identification

| Method | ES1868 | ES1869 | ES1878 | ES1887 | ES1888 |
|---|---|---|---|---|---|
| E7h reply | 68h, 8xh; x >= 8 for ES1868, x < 8 for ES688 (E68:2710-2713) [sheet] | 68h 8xh; "use mixer 40h to identify" (E69:5079-5081) [sheet] | 68h 8xh [sheet] | legacy ES688/ES1688 bytes (E87b:1255-1258) [sheet] | 68h 8xh (E88:1164-1171) [sheet] |
| Mixer 40h, successive reads | 18h, 68h, A[11:8], A[7:0] of the configuration device (E68:2306-2313) [sheet] | 18h, 69h, ... (E69:2992-3001) [sheet] | 18h, 78h, ...; an index write restarts (E78:2370-2382) [sheet] | not an ID: FM/joystick/MPU config (E87b:316-345) [sheet] | not an ID: MPU/joystick config (E88:2630-2641) [sheet] |
| E1h (version) | 03h, 01h: "Sound Blaster Pro compatibility" (E68 Table 10) [sheet] | same (E69 Table 26) | same (E78 Table 19) | same (E87b Table 6) | same (E88 2.8) |
| E7h in the command table | yes | yes | **no** (Table 19 ends at E1h) | yes | yes |

- ES1868F in Michael's PC: E7h answers 68h 8Bh. Mixer 40h restarts its
  sequence when the index is rewritten [hw].
- The virtual card answers E7h and mixer 40h with the physical chip's own
  values, read at install [design decision].
- E7h on a non-ESS card does "an unknown function" and the sheet tells
  programs to reset afterwards (E68:2710). Not the virtual card's concern.

## 3. Ports

From Table 13 (E68:2989-3030) and the port descriptions (E68:3030-3107).

| Port | Access | Function |
|---|---|---|
| 2x0h-2x3h | R/W | FM synthesizer [pass-through] |
| 2x4h | R/W | Mixer address. Unlike the SB Pro (write-only), readable (E68:2736). ES1888: the read gives the address bits 5:1 in bits 5:1 and "MXD" in bit 0 (E88:1565-1570) [sheet] |
| 2x5h | R/W | Mixer data |
| 2x6h | W | bit 0: software reset; bit 1: FIFO reset ("don't care" in compatibility mode) |
| 2x6h | R | bits 7:5 activity flags, bit 4 serial activity, bit 3 0 if powered down, bit 2 MIDI mode, bit 1 FIFO reset, bit 0 software reset (E68:3045-3080) [sheet] |
| 2x7h | R/W | Power management: bit 5 FM reset, bit 7 suspend request, bit 2 power-down request, bits 1:0 GPO (E68:3052-3090) [sheet] |
| 2x8h-2x9h | R/W | FM [pass-through] |
| 2xAh | R | Read data (replies) |
| 2xCh | W | Command/data write buffer |
| 2xCh | R | bit 7 busy; in extended mode also the FIFO and interrupt status (section 5.3) |
| 2xEh | R | bit 7 data available; any read clears an active interrupt request (E68:2576-2579, 3027) |
| 2xFh | R/W | FIFO data for programmed I/O in extended mode |
| 388h-38Bh | R/W | FM [pass-through] |

- **Power management by model.** ES1878: through PnP register 2Dh; of
  2x7h only bit 5 (FM reset) and bit 7 (suspend) remain (E78:3679)
  [sheet].
- **2x6h read, activity flags.** Bits 7:5 are set high by each read of 2x6h
  and set low by activity: bit 7 by FM or MPU port access, bit 6 by reads of
  2xCh or 2xEh, bit 5 by DMA, 2x2h-2x3h, writes of 2x6h and 2xCh, reads of
  2xAh (E68:3051-3075) [sheet]. Power-management software reads them to see
  whether the card is in use. The virtual card should report them from its
  own trapped accesses [design decision; low priority].

## 4. Reset

### 4.1 Software reset sequence (E68:2315-2328) [sheet]

1. Write 1 to 2x6h (or 3: bit 1 also clears the FIFO, recommended before
   extended mode, E68:2826-2830).
2. Delay briefly (for example by reading 2x6h).
3. Write 0 to 2x6h.
4. Poll 2xEh bit 7 for at least 1 ms; read 2xAh until it is AAh.

### 4.2 What any reset does (E68:2329-2345) [sheet]

1. Extended mode off (C6h needed again).
2. Timer divider and filter set for 8 kHz.
3. Any DMA stopped.
4. Any active interrupt request cleared.
5. Voice input to the mixer disabled (as D3h).
6. Compatibility and extended DMA counters set to 2048 bytes.
7. Analog direction DAC, DAC at mid-level.
8. 8-bit AGC input volume at maximum.
9. 16-bit input volume mid-range (8, E68:2504).

A **hardware** reset also resets the mixer registers; a software reset does
not (E68:2345, 2742) [sheet].

### 4.3 Extension registers after a software reset

| Reg | Sheet | ES1868F [hw] | 86Box ES1688 [emu] |
|---|---|---|---|
| A1h | "unknown" (Table 16) | DCh (22097 Hz) | kept as written |
| A2h | "setup for 8 kHz" | E7h (a 3.5 kHz roll-off) | kept |
| A4h | 00h (E68:3423) | 00h | kept |
| A5h | F8h (E68:3433) | F8h | kept |
| A8h | | 02h (mono) | kept |
| A9h | bit 2 set by hardware reset (E68:3475) | 0Ch | |
| B1h | ES1878/1888: bits 7:5 cleared | 1Ah (10h + IRQ 7 code) | |
| B2h | ES1878/1887/1888: bits 7:5 cleared | 1Ah (10h + DMA 1 code) | |
| B4h | ES1878/1888: FFh | FFh | FFh |
| B5h | | 00h | kept |
| B6h | | 80h | kept |
| B7h | | 44h | kept |
| B8h | | 00h | kept |
| B9h | | 00h | kept |
| BAh | bit 6 cleared by hardware reset | 00h; 40h when the driver set the clock trim before (bit 6 survives a software reset) | |
| BCh | bits 7:6 10b by hardware reset (E68:3537) | 76h (bits 7:6 01b) | |

The virtual card uses the ES1868F values [hw]. Every write-then-reset test
on the chip came back to these values, so a software reset sets them all.
The BCh difference from the sheet is recorded in section 14.

## 5. The command interface

### 5.1 Writing (E68:2552-2580) [sheet]

- Poll 2xCh bit 7 until clear, then write the byte to 2xCh.
- Busy is set while the write buffer is full or the chip is otherwise busy
  (after a reset, and during compatibility-mode DMA requests).
- ES1868F: busy for 5 to 7 µs after a command (F2TEST "ready", 6 to 8 PIT
  counts) [hw].

### 5.2 Reading (E68:2570-2580) [sheet]

- Poll 2xEh bit 7 (or 2xCh bit 6, the same flag) for a byte, then read
  2xAh. Reading 2xAh clears the flag.
- **Any read of 2xEh also clears an active interrupt request.**

### 5.3 Port 2xCh as status (Table 13, E68:3010-3027) [sheet]

| Bit | Meaning |
|---|---|
| 7 | Write buffer not available, or busy |
| 6 | Same as 2xEh bit 7 (read data available) |
| 5 | Extended mode FIFO full (256 bytes) |
| 4 | Extended mode FIFO empty |
| 3 | FIFO half-empty (DAC direction: 0 to 127 bytes; ADC: 128 to 256) |
| 2 | Processor interrupt request (F2h, compatibility-mode DMA complete) |
| 1 | FIFO half-empty change interrupt request (programmed I/O) |
| 0 | DMA counter overflow interrupt request (extended mode) |

ES1868F [hw]:
- 18h at rest, after a reset, before and after C6h (empty and half-empty).
- 01h at an extended block interrupt (09h once the FIFO has drained below
  half).
- 1Ch at an F2h interrupt.
- A read of 2xEh returns bits 6:0 of 2xCh with bit 7 the data-available
  flag, and clears bits 0 and 2.

### 5.4 Commands in compatibility mode during DMA (E68:2480-2512) [sheet]

- While compatibility DMA runs, busy is set except in windows when the
  64-byte FIFO is full. A command must be written within 13 µs of busy
  clearing, or it is taken as DMA data.
- D0h sent as a transfer completes has no effect, and the completion
  interrupt is still pending; reading 2xEh clears it.
- The virtual card cannot confuse a command with data, so its busy flag in
  compatibility mode need only be set while a reply string or the post-
  command delay is pending [design decision, to be confirmed against a
  program that relies on the window].

## 6. The two modes (Table 8, E68:2280-2299) [sheet]

| | Compatibility (SB Pro) | Extended |
|---|---|---|
| FIFO | 64 bytes, firmware (32 levels for 16-bit, 64 for 8-bit, E68:2418) | 256 bytes, hardware |
| Mono 8-bit DAC | to 44 kHz | to 44 kHz |
| Mono 16-bit DAC | to 22 kHz | to 44 kHz |
| Stereo 8-bit DAC | to 22 kHz | to 44 kHz |
| Stereo 16-bit DAC | to 11 kHz | to 44 kHz |
| Signed data | no (unsigned only) | yes |
| Programmed I/O | no | yes |
| FIFO status flags | no | yes |
| Timer base | 1 MHz or 1.5 MHz | 795.5 kHz or 397.7 kHz |
| Jitter | ±2 µs | none |

- Compatibility mode is the default after any reset.
- C6h enables the extension commands (Axh, Bxh, C0h); C7h disables them.
  C6h is needed after every reset (E68:2561-2583).
- "Avoid mixing" the modes; D1h and D3h are safe in extended mode, other
  compatibility commands "likely to cause problems" (E68:2544-2552). The
  extension commands may also be used just to set DMA and IRQ before
  compatibility-mode playback.

## 7. Compatibility mode

### 7.1 Commands (Table 10, E68:2594-2716) [sheet]

| Cmd | Bytes | Function |
|---|---|---|
| 10h | 1 W | Direct 8-bit DAC, unsigned |
| 11h | 2 W | Direct 16-bit DAC, unsigned, low byte first |
| 14h | 2 W | Normal DMA, 8-bit DAC; count - 1. Stereo if mixer 0Eh bit 1. Max 44 kHz mono, 22 kHz stereo |
| 15h | 2 W | Normal DMA, 16-bit DAC; count - 1. Max 22 kHz mono, 11 kHz stereo |
| 1Ch | | Auto-init DMA, 8-bit DAC; block from 48h |
| 1Dh | | Auto-init DMA, 16-bit DAC; block from 48h |
| 20h | 1 R | Direct 8-bit ADC |
| 21h | 2 R | Direct 16-bit ADC |
| 24h, 25h | 2 W | Normal DMA ADC, 8 and 16-bit |
| 2Ch, 2Dh | | Auto-init DMA ADC, 8 and 16-bit |
| 30h/31h | | MIDI input; 31h with an interrupt per byte. Exit by any write to 2xCh |
| 34h/35h | | MIDI UART; exit only by reset |
| 38h | 1 W | MIDI output, one byte |
| 40h | 1 W | Time constant: rate = 1 MHz / (256 - X), X <= 233. Stereo: twice the per-channel rate |
| 41h | 1 W | Time constant: rate = 1.5 MHz / (256 - X), X <= 222 |
| 42h | 1 W | Filter clock: 7.16 MHz / (256 - X), roll-off 1:82 (40h/41h set it automatically) |
| 48h | 2 W | Block size - 1 for auto-init and high speed |
| 64h-6Fh | 2 W | ESPCM transfers (with and without reference byte) |
| 74h-7Bh | 2 W | ADPCM transfers (4, 2.6, 2-bit; with and without reference byte) |
| 80h | 2 W | Silence period, samples - 1 |
| 90h | | Auto-init 8-bit DMA DAC, count from 48h |
| 91h | | 8-bit DMA DAC, count from 48h |
| 98h, 99h | | High-speed 8-bit ADC, auto-init and normal |
| C1h | | Resume after suspend |
| C6h, C7h | | Extension commands on, off |
| CEh, CFh | 1 R, 1 W | GPO power management register |
| D0h | | Pause DMA (the FIFO keeps emptying) |
| D1h, D3h | | Voice to mixer on, off |
| D4h | | Continue DMA after D0h |
| D5h | 1 R | Always 1 (ES488 compatibility) |
| D6h, D7h, DEh, DFh | 1 R / 1 W | ES488 commands not supported: "use mixer registers instead" |
| D8h | 1 R | Voice status: 0 off, FFh on |
| DCh, DDh | 1 R / 1 W | Input gain 0-15 (16-bit and high-speed ADC) |
| E1h | 2 R | 03h, 01h |
| E7h | 2 R | 68h, 8xh |
| F2h | | Interrupt for test purposes |
| FDh | | Force power-down; reset needed to wake |

**By model** (E69 Table 26, E78 Table 19, E87b Table 6, E88 section 2.8)
[sheet]:

| Commands | 1868 | 1869 | 1878 | 1887 | 1888 |
|---|---|---|---|---|---|
| 10h-99h, Axh/Bxh, C0h, C1h, C6h, C7h, D0h, D1h, D3h, D4h, D8h, E1h | yes | yes | yes | yes | yes |
| CEh, CFh (GPO) | yes | yes | no | yes | yes |
| D5h, D6h, D7h, DEh, DFh (ES488) | yes | no | no | no | yes |
| DCh, DDh (input gain) | yes | yes | no | yes | yes |
| E7h, F2h, FDh | yes | yes | no | yes | yes |

"No" means absent from that sheet's table; what the chip does with it is
unknown. A virtual card presenting that model treats it as an unknown
command (section 16).

**A contradiction inside the ES1869 sheet.** Its programming text says to
use 48h only with the high-speed commands 90h/91h, and to use D0h to stop
after the current auto-init block and D4h for the next normal-mode block
(E69:3192-3233, 3261-3312). Its own command table says 1Ch/1Dh take their block size
from 48h and D0h pauses (Table 26), as every other sheet says. The command
table is followed.

Not in the ES1868's table, so not commands of this card: E0h, E3h, E4h,
E8h, F3h, F8h, DAh, D9h, the SB16 Bxh/Cxh starts. Whether the chip has
these Creative commands is to be measured; until then the virtual card does
nothing for them (section 16).

**E2h, the exception.** Creative's DMA identification is in no ESS table,
but the ES1868F answers it exactly as a Sound Blaster does (E2TEST: 40 30
F3 98 for the arguments 00h, 55h, AAh, FFh) [hw], and Miles' ESS driver
sends it, in extended mode, to confirm the DMA channel [driver: trace of
Theme Hospital, 16 Oct]. One argument byte. A running byte, AAh after a
reset, has the argument XORed with the next of the masks 96h, A5h, 69h, 5Ah
added to it; the result goes to memory by one DMA write cycle when the
8-bit channel is set up for a write transfer, otherwise it is the reply.
Assumed for every model until measured on the others [inference].

### 7.2 Data and timing [sheet]

- 8-bit unsigned, centred on 80h; 16-bit unsigned, low byte first, centred
  on 8000h (E68:2439-2443).
- **8-bit stereo starts with the right channel**, in all five sheets
  (E68:2456, E69:3102, E78:2458, E87a:1835, E88:813). The ES1888 adds:
  after any write to mixer 0Eh, the next 8-bit sample is the right
  channel's (E88:1552-1553). Creative's SB Pro starts with the left; rule 6
  applies. Owners of ESS cards report SB Pro games with swapped stereo
  [reports, via Michael]: a known quirk of the real cards, which the virtual
  card reproduces, not a sheet error.
- 16-bit stereo: groups of four bytes, left low, left high, right low, right
  high (E68:2462-2468).
- Stereo is DMA only; set mixer 0Eh bit 1 and the timer to twice the
  per-channel rate (E68:2444-2455).
- The timer (40h/41h) also sets the switched-capacitor filter; 42h overrides
  it. The SB Pro filter bits in mixer 0Ch/0Eh do nothing (Table 14 note, E68:3121)
  [sheet].
- Direct mode: the filter stays at the reset 8 kHz unless 40h is sent
  (E68:2404-2410).
- The end of a block raises an interrupt; in auto-init mode, one per buffer
  half (E68:2426-2438). Where in the playback the compatibility-mode
  interrupt falls (block entering the 64-byte FIFO, or played) is not
  stated: to be measured (section 16).

## 8. Extended mode

### 8.1 Extension registers (Table 16, E68:3381-3560; ES1869 detail
E69:4613-4890) [sheet]

| Reg | Function |
|---|---|
| A1h | Sample rate: 397.7 kHz / (128 - x) with bit 7 clear; 795.5 kHz / (256 - x) with bit 7 set. Bit 7 set for rates above 22 kHz |
| A2h | Filter clock: 7.16 MHz / (256 - x); roll-off at 80-90% of Fs/2, ratio 1:82 |
| A4h, A5h | DMA counter reload, two's complement, low and high byte |
| A8h | bits 1:0 01 stereo, 10 mono (converter mode); bit 3 record monitor; bit 4 write 1 (E69). Read-modify-write: preserve the other bits |
| A9h | bit 2 microphone preamp +26 dB (set by hardware reset); preserve the others |
| B1h | bit 7 processor IRQ (compatibility; leave 0); bit 6 interrupt on counter overflow; bit 5 interrupt on FIFO half-empty change; bit 4 don't care; bits 3:0 read-only IRQ decode (section 8.3) |
| B2h | bit 7 processor DRQ (compatibility); bit 6 DRQ for extended DMA (0: programmed I/O); bit 5 DRQ for compatibility DMA; bit 4 don't care; bits 3:0 read-only DMA decode |
| B4h | Record level |
| B5h, B6h | Direct DAC holding (B6h 80h before unsigned, 00h before signed, Table 11) |
| B7h | bit 7 FIFO to codec (record); bit 6 opposite of bit 3; bit 5 signed; bit 4 write 1; bit 3 stereo; bit 2 16-bit; bit 0 load (E69) |
| B8h | bit 3 ADC; bit 2 auto-init; bit 1 DMA read (ADC direction); bit 0 enable transfer |
| B9h | 0 single transfer; 1 demand, 2 bytes per request; 2 demand, 4 bytes |
| BAh | bit 6 sample-rate adjust (clock trim, cleared by hardware reset); bit 5 no wake-up delay; bits 4:0 reserved |
| BCh | bits 7:6 FM DAC level; bits 5:0 must be 110110b |

### 8.2 The playback sequence (Table 11, E68:2800-2870) [sheet]

1. Reset with 3 (clears the FIFO), C6h.
2. B8h (0 normal, 4 auto-init), A8h bits 1:0, B9h.
3. A1h, A2h, A4h/A5h.
4. B6h, then B7h twice, by format: unsigned mono 8-bit B6h 80h, B7h 51h,
   B7h D0h; signed mono 8-bit B6h 00h, B7h 71h, B7h F0h; 16-bit sets B7h bit
   2 (D4h, F4h); stereo uses 98h, B8h, 9Ch, BCh.
5. B1h and B2h: bits 4 and 6 high, bits 7 and 5 clear.
6. D1h after about 100 ms; then B8h bit 0 high, preserving the rest.
7. Auto-init: no commands at interrupt time except reading 2xEh. Normal
   mode: reprogram the DMA, clear and set B8h bit 0 for the next block.
8. Stop at once: clear B8h bit 0. Stop after the current auto-init block:
   clear B8h bit 2, wait for the interrupt, then clear bit 0.

### 8.1a Extension registers by model [sheet]

| Reg | 1868 | 1869 (Table 25) | 1878 (Table 18) | 1887 (E87b Table 5) | 1888 |
|---|---|---|---|---|---|
| B1h bit 7 | processor IRQ (leave 0) | "game compatible IRQ" | processor IRQ | game compatible IRQ | |
| B1h bits 6:4 | enables: overflow, FIFO-HE, x | enables | enables | **masks**: DMA complete, FIFO-HE, all Audio 1 | |
| B1h bits 3:0 | read-only decode | read-only decode | IS1/IS0 select | bits 3:2 = 7Fh[3:1] | bits 3:2 IS1/IS0 |
| B2h bit 4 | don't care | x | inactive-DRQ pull-down | inactive-DRQ pull-down | DRQ bits (E88:1786-1825, notes) |
| B2h bits 3:0 | read-only decode | read-only decode | DS1/DS0, read-only | DRQ/DACKB select | DS1/DS0 |
| BAh | bit 6 clock trim, bit 5 wake delay | bit 5 wake delay, bits 4:0 left ADC offset | bit 6 trim, bit 5 wake delay, bits 4:0 offset | | |
| BBh | | right ADC offset | right ADC offset | | |
| BCh | FM DAC level | | FM DAC level | | |

### 8.3 B1h and B2h decodes (E68:3436-3480) [sheet]

| Bits 3:0 | IRQ (B1h) | DMA (B2h) |
|---|---|---|
| 0000 | 2/9 and all others | all others |
| 0101 | 5 | 0 |
| 1010 | 7 | 1 |
| 1111 | 10 | 3 |

- ES1868F: bits 3:0 read-only; B1h bit 7 does not take a write; B2h bit 7
  does [hw].
- ES1878 and ES1888 use bits 3:2 as writable selects; ES1887 bits 3:2
  "match" its 7Fh routing (section 12) [sheet].

### 8.4 FIFO, counter and interrupts [sheet, hw]

- The 256-byte FIFO sits between the ISA bus and the DAC/ADC.
- The DMA counter counts each byte moved by DMA. It reloads from A4h/A5h at
  the start and at every overflow. Each overflow requests an interrupt if
  B1h bit 6 is set (E68:3440-3460).
- Auto-init: DMA runs on indefinitely. Normal mode: DMA stops at the
  overflow until a new transfer is commanded (B8h bit 0 cleared and set).
- So the block interrupt comes when the block's last byte enters the FIFO,
  up to 256 bytes before it plays [hw: 1024 bytes at A1h 6Eh interrupt
  after 34.78 ms mono, 17.41 ms stereo, (1024 - 256) bytes at the frame
  rate].
- The DAC takes one frame per sample clock; the frame size follows B7h bit
  3 (stereo) and bit 2 (16-bit). A disagreeing A8h does not change the
  timing [hw].
- The FIFO fills at about 267 bytes/ms with B9h = 0: half at 0.5 ms, full
  at 0.96 ms [hw]. Demand transfers (B9h 1, 2): to be measured.
- Stereo data alternates left then right (E68:2818). This is the
  opposite of compatibility-mode 8-bit stereo.
- D0h pauses the DMA and the FIFO plays out; D4h continues (Table 10).
- B2h bit 6 clear: no DRQ, so no DMA (B2h description).
- Programmed I/O through 2xFh: an interrupt on the half-empty flag's rising
  edge with B1h bit 5. DAC: when the FIFO "changes from >=128 to < 128";
  prime with more than 128 bytes (E68:2926-2952).
- The clock trim (BAh bit 6) slows the chip about 0.25% to make 44.1 kHz
  exact. Untrimmed, the chip runs at the A1h formula [hw].

## 9. Interrupts (E68:1453-1560) [sheet]

- **Audio 1** carries compatibility DMA completion, extended DMA counter
  overflow, programmed I/O half-empty changes, the processor interrupt
  (F2h) and SB MIDI receive.
  - Cleared by a hardware or software reset, or by a read of 2xEh.
  - Polled through 2xCh.
- **Audio 2.** Second DMA channel, latch in mixer 7Ah bit 7, mask in 7Ah
  bit 6.
- **Hardware volume.** Mixer 64h bit 1 mask, bit 4 request, cleared by
  any write to mixer 66h.
- **MPU-401.** Masked by mixer 64h bit 6.
- **Configuration device.** Interrupt status (base+6) and mask (base+7)
  belong to the PnP side, out of scope.
- **Edges.** A source still active when unmasked raises a new request,
  because the pin went low then high (E68:1557; ES1887: "edge-
  generation logic", E87a:983-985).
- **F2h** [hw]:
  - The interrupt comes 11.7 to 14.2 µs after the command.
  - Two F2h back to back give two interrupts, one after the other.
  - F2h, its interrupt not acknowledged, then F2h: one interrupt (the line
    stays high).

## 10. Mixer

### 10.1 Access rules (E68:2720-2790) [sheet]

- Mixer writes are read and acted on by the chip's processor: "do not take
  effect instantly or necessarily in the same order as written".
- A software reset does not touch the mixer; a write to mixer 00h resets it.
- **SB Pro addresses** (address bit 4 clear): 3 bits per channel. Bits 0
  and 4 are cleared by a write and read as 1.
- **Extended access** (address bit 4 set): all 8 bits. These are the same
  registers: 04h/14h, 22h/32h, 26h/36h, 28h/38h, 2Eh/3Eh. Example: write
  00h to 04h, read 11h (E68:2763-2778).
- 0Ah (mic, mono, 2 bits) maps onto 1Ah: writes 00h, 55h, AAh, FFh by bits
  2:1. Reads give bit 3 of 1Ah and bit 0 = 1.
- 0Ch: record source in bits 2:1; bit 0 cleared by a write, set on read.
  Extended 1Ch adds "Mixer" as a source (D2 D1 D0 = 111).
- The SB Pro filter bits F0-F2 in 0Ch/0Eh are ignored.

### 10.2 Registers (Tables 14 and 15) [sheet]

- **SB Pro set.** 00h (reset), 04h voice, 0Ah mic, 0Ch record source,
  0Eh stereo switch, 22h master, 26h FM, 28h CD, 2Eh line.
- **Extended.**
  - 14h, 1Ah, 1Ch, 32h, 36h, 38h, 3Eh.
  - 40h identification.
  - 42h-4Eh serial mode.
  - 60h/62h hardware master volume counters (bit 6 mute, bits 5:0 level).
  - 64h: bit 0 when clear, a write to the SB Pro master (22h) is
    translated into 60h/62h; when set, the SB Pro master is in effect
    read-only.
  - 66h clears the hardware volume interrupt.
  - 70h-7Ah Audio 2 (ES1868: 74h-7Ah; the second channel shares the first's
    rate).
- **Reset values** (ES1888 Tables 3.1 and 3.2, E88:1578-1640; the ES1869,
  ES1878 and ES1887 register descriptions agree where they state them)
  [sheet]:

  | Register | Reset |
  |---|---|
  | 04h / 14h voice | 88h |
  | 0Ah / 1Ah mic | 00h |
  | 0Ch / 1Ch record source | 00h |
  | 0Eh / 1Eh stereo | 00h |
  | 22h / 32h master | 88h |
  | 26h / 36h FM | 88h |
  | 28h / 38h CD | 00h |
  | 2Eh / 3Eh line | 00h |

  With master-volume emulation on, a mixer reset sets both hardware master
  counters to 54 (36h) (E69:3822, E87b:48, E88:1284).
- **SB Pro master volume emulation** (E69 Tables 19 and 20, E69:3784-3830;
  E78 Table 16; E87b Table 1) [sheet]:
  - A write to 22h (or 32h) sets the 6-bit counters 60h/62h by a table:
    value 0 mutes, 1-15 give 24, 24, 30, 34, 38, 42, 46, 50, 54, 55, 56,
    58, 59, 61, 62, 63 (Table 20).
  - Reads of 22h/32h translate the counters back to 4 bits (Table 19),
    whether or not the emulation is enabled.
  - Mixer 64h bit 0 set disables the write translation.
- **Volume scale** (E69 Table 21, E69:3851-3880) [sheet]: 4-bit level 0
  mutes; steps 1 to 8 are 3 dB each, 8 to 15 are 1.5 dB each. One law,
  offset by input (dB at 8 and at 15):

  | Input | 8 | 15 |
  |---|---|---|
  | Audio 1 (14h, the voice this card plays; gated by D1h/D3h) | -9.0 | +1.5 |
  | Audio 2 | -10.5 | 0 |
  | Mic, music DAC (FM, 36h), I2S | 0 | +10.5 |
  | AuxA (CD, 38h), AuxB, line, mono in | -7.5 | +3.0 |

  (Corrected 16 Oct: v0.3 summarised this as "Audio 1 15 = 0 dB; CD 8 =
  0 dB", which is the Audio 2 and music columns. The code followed the
  table.)
- **Mixer 0Eh bit 1** is not cleared by a software reset, only by a mixer
  reset (E69:3933-3934, E88:1561-1562).
- **Register sets differ by model.** The ES1869 adds 3Ah AuxB, 3Ch PC
  speaker, 50h-5Eh spatializer, 61h/63h counters, 65h, the record mixer
  68h-6Fh, Audio 2 at 70h-7Ch, 7Dh, 7Fh (E69 Table 24). The ES1887 adds 7Fh
  interrupt routing. The ES1868 has none of these. The virtual card carries
  a register map per model; a register the model lacks reads as the model's
  sheet or the chip says (open question 8).

### 10.3 The virtual card at install [design decision]

The virtual mixer is the game's mixer. The physical one belongs to the
driver and the user: during output uCDD sets the physical voice to maximum
and the physical master to UCDDSET's level, so the virtual levels act on top
of the user's volume, as on every other virtual card.

- 14h voice, 1Ah mic, 1Ch record source and 36h FM are copied from the
  physical chip, so the card starts where UNISOUND left the real one.
- The master counters 60h/62h are copied only from an identified ES1868 or
  later (mixer 40h answered). An older or unidentified chip may have no
  counters: the ES688/1688 does not (absent registers read 0Ah, as 86Box's
  card does), and copying them put the virtual master at 40 dB below full
  (16 Oct, 86Box). There the counters come from the physical 32h through
  Table 20, as a write to 32h would set them.
- 38h CD starts at DDh, 0 dB after the CD input's offset, and is not
  copied: uCDD mixes CD audio into its own stream, so the physical CD input
  is unused, and UNISOUND /VC00 mutes it (the setting the eXo kit uses).
  A mixer reset (00h) still sets 00h, as the sheets give, and mutes CD;
  that is the chip's behaviour and is kept.
- Then a software reset (section 4.2).

## 11. FM and MPU-401

- Not the virtual card's: the physical chip's own ESFM/OPL3 at 2x0h-2x3h,
  2x8h-2x9h, 388h-38Bh, and its MPU-401.
- Mixer 26h/36h (FM level) is the virtual card's, applied to the physical
  FM through the physical mixer [design decision; already the case in
  uCDD].

## 12. Model differences (summary; detail in sections 2, 7.1, 8.1a, 10.2)

| | ES1868 | ES1869 | ES1878 | ES1887 | ES1888 |
|---|---|---|---|---|---|
| Identification | E7h 68 8x, mixer 40h 18 68 | mixer 40h 18 69 | mixer 40h 18 78 | E7h legacy bytes; writable 64h bit 3, 70h, 64h bit 5 | E7h 68 8x |
| BAh | bit 6 clock trim, bit 5 wake delay | ADC offset only, no trim | bit 6 trim + bits 4:0 ADC offset | not documented | not documented |
| B1h bits 3:0 | read-only decode | read-only decode | IS1/IS0 select | bits 3:2 mirror 7Fh | bits 3:2 IS1/IS0 select |
| B1h, B2h at reset | not stated | not stated | bits 7:5 cleared | B2h bits 7:5 cleared | bits 7:5 cleared |
| FIFO | 64 compatibility, 256 extended | same | same | same | same |
| Interrupt routing | PnP | config base +6/+7 | | 7Fh "new method"; B1h bits 6:4 become masks | B1h bit 4 tri-state enable |

## 13. ES1868F measurements (Michael's PC, 15 Oct 2026) [hw]

- The reset values of section 4.3, and the B1h/B2h behaviour of section 8.3.
- 2xCh and 2xEh values of section 5.3.
- F2h: 11.7 to 14.2 µs to the interrupt; busy 5 to 7 µs; two F2h give two
  interrupts; no acknowledge gives one.
- Extended blocks:
  - 1024 bytes at A1h 6Eh interrupt after (1024 - 256) bytes at the frame
    rate.
  - Stereo follows B7h, not A8h.
  - The FIFO is full at 0.96 ms.
  - The untrimmed chip is on the A1h formula; the trim slows it about
    0.25%.
- E7h 68h 8Bh; mixer 40h restarts on an index write.
- Without UNISOUND the chip reads FFh everywhere (not configured).

## 14. Where sources disagree

| Item | Sheet | ES1868F [hw] | 86Box ES1688 [emu] | DOSBox-X [emu] | Virtual card follows |
|---|---|---|---|---|---|
| B1h/B2h bits 3:0 | read-only | read-only | writable | read-only | sheet and hw |
| B1h bit 7 | reserved | not writable | writable | | hw (sheet silent) |
| Extension registers on software reset | some stated | all reset (section 4.3) | kept | | hw (sheet partly silent; emulators wrong) |
| A1h after reset | "unknown" | DCh | kept | | hw |
| BCh after reset | bits 7:6 10b (hardware reset) | 01b (software reset) | | | hw (different reset) |
| 2xCh at rest | bit 4 empty implied | 18h | 00h | | sheet and hw |
| Extended block interrupt | last byte into the FIFO (counter description) | same, measured | at end of play | | sheet and hw |
| Frame size | B7h bit 3 (data), A8h (converter) | timing follows B7h | | A8h | sheet and hw |
| Two F2h | not stated | two interrupts | merged | merged | hw |
| B8h bit 0 after a normal block | DMA halts (bit not said to clear) | to measure | | cleared | open question 11 |
| F2h latency | not stated | 11.7 to 14.2 µs | | | hw (as far as a trap can) |
| Clock trim | BAh bit 6 | 0.25% slower | not modelled | | sheet and hw |

| Creative commands E0h, E4h/E8h, F8h | not listed | to measure (CMDS script) | answered as an SB (ESSRUN, 16 Oct) | | open: 86Box builds its ESS on its SB DSP code |
| Compatibility block interrupt | "at the end of the transfer" | to measure (COMPAT script) | at the end of play (55002 counts for 1024 bytes at 22.2 kHz) | | open question 1 |
| Extended block interrupt (ESSRUN) | last byte into the FIFO | last byte into the FIFO | end of play (55316) | | sheet and hw |
| 2xCh, 2xEh | status, flags | 18h at rest | 00h at rest, 2xEh 7Fh | | sheet and hw |
| Mixer reset values | 88h/00h (ES1888 tables) | to measure (MIXER script) | FFh, CD FFh, master counters 0Ah | | sheet |
| Absent mixer registers | | to measure (MIXER script) | read 0Ah, 3Ah stores | | open question 8 |

Rule 1 puts emulation before hardware where the sheet is silent. In every
row where the sheet is silent, the emulators disagree with each other or
with the chip, so the chip decides and the row says so.

## 15. Not implemented in the first build, and what the card answers

| Feature | First build answers |
|---|---|
| Recording (B8h bit 3/bit 1, 20h-2Dh, 98h/99h) | Refused: the command is taken and nothing starts; no interrupt |
| Audio 2 (mixer 70h-7Ah) | Registers stored and read back; no DMA, no interrupt |
| Programmed I/O (2xFh) | Writes discarded, reads 00h; no half-empty interrupt |
| Serial mode (mixer 42h-4Eh) | Stored and read back; no effect |
| Power management (2x7h, CEh/CFh, C1h, FDh) | 2x7h bit 5 passed to the physical FM reset; the others stored; FDh ignored |
| ESPCM, ADPCM (64h-7Bh) | To be decided: implement (the decoders are documented elsewhere) or refuse |
| 16-bit compatibility (11h, 15h, 1Dh) | Implemented: they are ES1868 commands |

## 15a. Test scripts

The behaviour above is also written as a reference model in Python, with
unit tests drawn from the data sheets and the ES1868F's measured values, and
as test scripts that a small DOS runner (ESSRUN) executes on a real chip or
under uCDD. The model produces each script's expected report, so the chip,
the driver and the model are compared with the same tests: REGS, CMDS,
MIXER, F2H, EXT, COMPAT, the register, mixer and command sweeps, RATES,
TIMES and the STEREO listening test. They are kept with the development
notes for now.

Under uCDD, a program that waits without touching a port gets its
interrupts up to one output period late (2.9 ms at 128 frames): a
trap-based card's limit.

## 16. Open questions

1. When does the **compatibility-mode** block interrupt come: when the
   block enters the 64-byte firmware FIFO, or when it plays? To measure
   with ESSSTAT (a compatibility block, as for extended mode).
2. Does the ES1868 answer the Creative commands it doesn't list (E0h, E3h,
   E4h, E8h, F3h, F8h, DAh)? To measure.
3. Fill rate with B9h 1 and 2 (ESSSTAT's B9h blocks, sent with 8c2fe40).
4. Mixer reset values per model.
5. What A8h bits 1:0 do to the output when they disagree with B7h
   (channel mapping): to measure by ear or with a recording.
6. Busy timing in compatibility mode during DMA: does any program depend
   on the 13 µs window?
7. The ES688/ES1688: no sheet. Emulator source is the only reference until
   one is found.
8. What a register absent from a model's map reads as (for example mixer
   3Ah on the ES1868).
9. What the ES1878 does with E7h, F2h and FDh, which its command table
   omits.
10. The ES1888's 2x4h read: what "MXD" in bit 0 is.
11. After a normal-mode extended block, does B8h bit 0 still read 1 (the
    sheet: DMA halts until restarted) or 0 (DOSBox-X clears it: "right?")?
    The EXT script reads it.
12. 2xCh at an extended block interrupt: the model gives 21h (FIFO full
    as the last byte goes in), the ES1868F gave 01h in ESSSTAT [hw], and
    the virtual card gives 01h. The chip seems to hold its FIFO short of
    full while it refills; the TIMES fill timelines and EXT on the chip
    should show how. The model is left as the sheet reads until then.

## 17. Where the current uCDD virtual ESS departs from this document

From the v0.2 pass, against ess-registers 8c2fe40 [sheet unless noted]:

1. **Compatibility-mode 8-bit stereo order.** uCDD takes the first byte as
   left (mix.asm .stereo8_normal: the first byte goes to the left sum). The
   ESS takes it as right (all five sheets), which is the real cards' known
   swapped-stereo quirk. The virtual ESS should reproduce it; today it plays
   SB Pro-mode stereo the Creative way.
2. **Mixer reset values.** uCDD resets 04h, 22h, 26h and 28h to CCh. The
   ESS sheets give 88h for voice, master and FM, and 00h for CD and line.
3. **SB Pro master emulation.** Writes to 22h are not translated through
   the 6-bit hardware counters, and reads are not translated back (Tables 19
   and 20).
4. **16-bit compatibility commands** 11h, 15h, 1Dh are refused.
5. **Mixer 0Ah** does not map onto 1Ah; **1Eh** is not the twin of 0Eh;
   **0Eh writes** do not restart the stereo pairing.
6. **Port 2x4h** does not read back the address; **2x6h** reads do not give
   the reset and activity bits.
7. **Commands by model.** D5h-DFh, E7h, F2h, FDh, CEh/CFh are answered the
   same for every model.
8. **Busy flag** is not modelled beyond string replies (known, docs/ess-fifo.md).

## 18. The ES688/ES1688, identification in practice, clocks

Sources downloaded 16 Oct 2026, read only: Linux v5.0 sound/isa/es18xx.c,
es1688/es1688_lib.c; 86Box src/sound/snd_sb.c and snd_sb_dsp.c (master);
DOSBox-X src/hardware/sblaster.cpp (master).

### 18.1 How software tells the models apart [driver]

Linux snd_es18xx_identify:
1. Reset; E7h must answer 68h then 8xh (48h 8xh is the ES488). x below 8
   is the ES688.
2. Mixer 40h read twice: if the two differ, they are the version (1868,
   1869, 1878, 1879) and the next two the control port.
3. Otherwise mixer writability decides: 64h bit 2 not writable, the
   ES1688; 64h bit 2 writable and 70h not, the ES1788; 70h writable and
   64h bit 5 writable, the ES1887; otherwise the ES1888.

So a virtual card presenting a model must also match that model's writable
mixer bits (64h bits 2 and 5, 70h), not just its ID bytes. The ES1868 model
answers at step 2. [design consequence]

### 18.2 The ES688 and ES1688 [driver, emu]

- E7h 68h 8xh, x < 8 the ES688, x >= 8 the ES1688.
- B1h and B2h bits 3:2 are writable selects (Linux writes F0h | irq << 2
  and F0h | dma << 2; IRQ codes 2/9 0, 5 1, 7 2, 10 3; DMA 0 1, 1 2, 3 3),
  as on the ES1878/1888. Not the ES1868's read-only decode.
- Mixer 40h is a writable configuration register (bit 0 joystick, the
  MPU-401 address and IRQ in bits 3 and up), not an ID. The ES688 has no
  MPU-401 configuration.
- No hardware volume (64h): the SB Pro master emulation through 60h/62h is
  the ES1788 and later (Linux step 3; 86Box applies it from the ES1788).
- Extended-mode playback is programmed exactly as the sheets give it
  (B6h/B7h sequences, A8h = 3 - channels, B9h 2, B8h 05h to start, a read of
  2xEh to acknowledge).
- Before the reset, Linux reads the "ENABLE" ports in a fixed sequence that
  some ES1688 cards need (the software address configuration, ES1868 Table
  13: ports 0E0h, 0E1h, 0F9h, 0FBh). Not the virtual card's concern: the
  physical card is configured before uCDD installs.

### 18.3 Clocks and rates [driver, sheet]

- Linux uses 795444 Hz and 397722 Hz for the A1h clocks: the 14.31818 MHz
  crystal over 18 and 36 (795454, 397727). The sheet rounds to 795.5 and
  397.7 kHz. The difference (under 0.01%) is far inside the crystal's
  tolerance; the model keeps the sheet's values.
- Linux sets A2h to 256 - 7160000*20/(8*82*rate): a roll-off at 80% of the
  half rate, as the sheet advises.
- The ES1869 (and ES1879) have a "new rate" mode, mixer 71h bit 5, with
  793.8 kHz and 768 kHz clocks. Not in the ES1868.
- Linux plays the ES1868 through Audio 2 and records through Audio 1;
  record and playback share one rate [driver].

### 18.4 Emulator notes

- 86Box models the ESS on its Sound Blaster DSP (sb_subtype), which is why
  it answers the Creative-only commands (section 14).
- 86Box's ESS keeps playing extended and compatibility DMA through a DSP
  reset (STEREO script, 16 Oct). The sheet: any reset stops DMA (SPEC 4.2).
- 86Box's master emulation tables match E69 Tables 19 and 20, except that a
  written 0 gives level 0 where the sheet gives "mute, 24".

## 19. The driver's physical ESS path against the family (16 Oct 2026)

uCDD's own output on a physical ESS (src/audio/wss_output.asm ess_setup,
ess_rate_adjust, ess_identify, wss_stop), checked against the five sheets
and the Linux drivers. Rule 6: the physical path handles every model with
a sheet. [sheet unless noted]

In line with every sheet:
- Reset with 3 (FIFO cleared), C6h, then the Table 11 sequence for 16-bit
  signed stereo: B8h 04h (auto-init DAC), B9h 02h (demand, 4 bytes),
  B6h 00h, B7h 71h, B7h BCh; B8h bit 0 to start; stop by B8h 0, then a
  reset back to compatibility mode.
- A1h EEh (795.5 kHz / 18 = 44194 Hz) or DCh (/ 36); A2h FBh / F6h, the
  roll-off the sheet and Linux compute (section 18.3).
- B1h and B2h: bits 4 and 6 set, 5 and 7 cleared, bits 3:0 kept as
  UNISOUND left them (read-only decodes on the 1868/1869, selects on the
  1878/1888, mirrors of 7Fh on the 1887). The ES1887 sheet calls B1h bit 6
  a "mask" in its Table 4, yet its own start sequence sets it, as every
  other sheet does; the driver follows the sequence.
- The clock trim (BAh bit 6) only on a chip that identifies as the ES1868
  or ES1878 through mixer 40h, the two sheets that document it; and only
  if the bit follows a write. Every other chip (ES1869, 1887, 1888, 688,
  1688) is left on the formula and the mixer is told the real rate.
- The master through 22h: translated into 60h/62h on the ES1868 and later
  (Table 20). Saving 22h and writing it back is exact for every 4-bit
  value (Table 19 then 20 is the identity); counters set directly (60h,
  62h or the volume buttons) can move one step on the first restore, then
  stay.
- The ES688/ES1688 (no sheet): Linux plays 16-bit through the same
  extended-mode sequence on both [driver], so the path holds there too.

Departures, all low:
1. A8h (stereo) is written after the clocks; Table 11's step 2 writes it
   with B8h and B9h, before them. No sheet says the order matters.
2. No delay before D1h. Step 7 recommends about 100 ms after the reset
   "before enabling voice input to mixer" (E68:2840), to let the analog
   side settle; skipping it risks a pop at the output start. Not reported
   on the PC.
3. Audio 1 (14h) is set to FFh: +1.5 dB (Table 21); 0 dB is EEh. Full-scale
   output then has 1.5 dB of analog gain on top. Whether that clips the
   chip's output stage is unmeasured.
4. E7h is sent to every chip, though the ES1878's table lacks it (open
   question 9). The wait for its reply times out, and Linux sends E7h to
   every chip too [driver].

Opportunity [sheet]: the ES1869's "new reg A1h" mode (mixer 71h bit 5,
E69:4499-4515). A1h then works as Audio 2's 70h does: bit 7 picks the
master clock (1 = 768 kHz for 48 kHz and its divisors, 0 = 793.8 kHz for
44.1 kHz and its divisors), bits 6:0 a two's complement divisor; 6Eh gives
793.8 kHz / 18 = 44100 Hz exactly (the sheet's own example). On an ES1869
CD audio could then play at its own rate with no resampling (rule 3),
where today the driver resamples to 44194 Hz because the ES1869 has no
trim. Only the ES1869 sheet documents it (not the 1868, 1878, 1887 or
1888 sheets); Linux names the ES1879 as having it too [driver]. Not used
yet; worth doing when an ES1869 can be tested (86Box's ESS models start
at the ES1688, so emulation cannot confirm it).
