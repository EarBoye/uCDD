# The virtual Sound Blasters: behaviour specification

Version 0.2, 16 Oct 2026 (0.1 the same day, from Creative's documents
alone). Creative's Hardware Programming Guide is the spine; where it is
silent, the DSP's own firmware decides, then the emulators, then the Sound
Blaster 16 CT2290 in Michael's PC, and every disagreement is written down
(section 13).

## 0. Rules, sources and conventions

The project's mantra (docs/vess-spec.md section 0) shapes this document:

- **Rule 1.** Creative's documents decide. Where they are silent or
  contradict each other, emulation decides first, then the real card.
  Michael's direction of 16 Oct ("firmware and reference doc-perfect
  Sound Blasters") puts the DSP firmware between the two: it is the real
  card's own program, so it outranks the emulators, which imitate it, but
  not the documents. Where the firmware contradicts the guide (a bug, a
  rule the guide states), the guide wins and the firmware's behaviour is
  recorded in section 13. To be confirmed by Michael.
- **Rule 6.** The ESS family is a separate card with its own specification
  (vess/SPEC.md). Nothing here applies to the virtual ESS, and nothing in
  the ESS document applies here. Since 16 Oct each build presents one
  family: the default build the Sound Blasters, `--virtual-ess` the ESS.
- **Rule 8.** Every statement carries its grade:
  - **[doc]** Creative's Hardware Programming Guide (or the Developer Kit
    reference, the same technical text);
  - **[fw]** the DSP firmware: S95Sedan's disassembly of the CT1741's 4.05
    (the SB16) and the CT1341's 3.02 (the SB Pro 2), CT1741_DSP on GitHub,
    reassembling to the dumped ROMs (github.com/S95Sedan/CT1741_DSP). Read
    instruction by instruction; the labels are the disassembler's guesses.
    The SB 2.0's 2.01 is not dumped;
  - **[emu-x]** DOSBox-X's source (v2026.10.01, src/hardware/sblaster.cpp
    and mpu401.cpp), whose comments often record what its authors measured
    on real cards (marked **[emu-x, hw note]**);
  - **[emu-86]** 86Box's source (master, src/sound/snd_sb.c,
    snd_sb_dsp.c, snd_mpu401.c);
  - **[hw]** the CT2290 in Michael's PC (none yet: section 14 lists what
    to measure);
  - **[86Box]** 86Box runs of this project's test programs;
  - **[inference]** reasoning, to be confirmed.

Sources, in the reference library (`Sound Cards/Superset references/`):

| Alias | File |
|---|---|
| SBG | Sound_Blaster_Series_Hardware_Programming_Guide.txt |
| SBK | Developer_Kit_SB_Series_Hardware_Programming_Reference.txt (the same technical text a few lines earlier, without the VOC appendix) |
| FW405 | CT1741_DSP, assembly/v405-8k_e51aff23.asm |
| FW302 | CT1741_DSP, assembly/v302_4k_4701c5fc.asm |

Line numbers are into the text file (SBG:3537 is line 3537); firmware
references name the routine (FW405 cmd_dma8).

Notation: `2xNh` is a port at the card's base. Mixer registers are written
`mixer NNh`. DSP versions follow SBG's notation (SBG:386-399): 1.xx, 2.00,
2.01+ (major 2 but not 2.00), 3.xx, 4.xx.

## 1. What the virtual cards are

uCDD presents one of three Creative cards, chosen in UCDDSET:

| Model | Card | DSP version (E1h) | Mixer | Notes |
|---|---|---|---|---|
| 3 | Sound Blaster 1.5/2.0 | 2.01 | none | SBG:404-405: "SB2.0 2.01+" |
| 1 | Sound Blaster Pro | 3.02 | CT1345 | 3.02 is the SB Pro 2 [emu-x] |
| 0 | Sound Blaster 16 | 4.05 | CT1745 | the CT1741 firmware's version [emu-x, emu-86] |

A program must not be able to tell the virtual card from the card it
presents: ports, replies, status bits, mixer read-back, the DMA channel's
counts and the interrupt line, and their timing. FM (2x0h-2x3h, 2x8h-2x9h,
388h-38Bh) and the MPU-401 (330h) are the physical card's and are not
trapped; the virtual card's line still carries the MPU-401's interrupt on
the SB16 (section 8.3).

## 2. Ports (SBG Appendix A)

| Port | SB 2.0 (SBG:4166-4178) | SB Pro (SBG:4262-4282) | SB16 (SBG:4354-4374) |
|---|---|---|---|
| 2x0h-2x3h | C/MS, write only, optional | FM | FM |
| 2x4h, 2x5h | **nothing** | mixer index (write only), data | mixer index (write only), data |
| 2x6h | DSP reset, write only | the same | the same |
| 2x8h, 2x9h | FM | FM | FM |
| 2xAh | read data | the same | the same |
| 2xCh | write command/data; read: write-buffer status, bit 7 | the same | the same |
| 2xEh | read-buffer status, bit 7; the 8-bit acknowledge | the same | the same |
| 2xFh | (alias of 2xEh) | (alias of 2xEh) | the 16-bit acknowledge (SBG:987-989) |

- **The SB 2.0 has no mixer** at its base: every card has one "except
  SB2.0 and earlier version of Sound Blaster cards" (SBG:573-574), "the
  SB2.0 does not contain a mixer chip on board" (SBG:713), and its map
  lists no 2x4h/2x5h (SBG:4164-4180). The CT1335 mixer belongs to the
  separate CD interface card at 250h or 260h (SBG:4190-4211). [doc] What
  the bus returns there is not stated; an empty ISA port reads FFh
  [inference].
- **Aliasing on the cards before the SB16.** "All Creative hardware prior
  to Sound Blaster 16 appear to alias most of the I/O ports. This has been
  confirmed on a Sound Blaster 2.0 and a Sound Blaster Pro (v3.1)": every
  port but 2x4h/2x5h decodes with bit 0 clear, so 2xBh reads as 2xAh, 2xDh
  as 2xCh, 2xFh as 2xEh and 2x7h as 2x6h [emu-x, hw note]; 86Box does the
  same for DSP versions below 4.04 [emu-86]. The guide is silent.
- **Values of the undefined bits.** The guide defines bit 7 of 2xCh and
  2xEh only (SBG:878-879, 924-926, 940-943). On the SB 2.0 and SB Pro both
  emulators return 2Ah (bit 7 clear) and AAh (set), "observed return values
  on SB 2.0" [emu-x, hw note; emu-86]; on the SB16 7Fh and FFh [emu-x,
  emu-86].
- **2xFh on the SB16** acknowledges the 16-bit interrupt and returns FFh
  [emu-86]; the guide gives only the acknowledge.
- **2x6h** is write only (SBG:870-871); a read returns FFh [emu-x,
  emu-86].

## 3. Reset (SBG:881-921)

- Write 1 to 2x6h, wait 3 us, write 0; poll 2xEh bit 7 and read AAh from
  2xAh. "Typically, the DSP takes about 100 microseconds to initialize
  itself." [doc]
- The reset happens on the 1: the DSP stops what it was doing and stays
  in reset until the 0 [emu-x: DSP_Reset on the 1, AAh 20 us after the 0;
  emu-86: reset on the 1, AAh queued at once on the 0].
- In high-speed mode the reset "terminates high-speed DMA mode and
  restores all the DSP parameters to their states prior to entering the
  high-speed DMA mode" (SBG:1352-1354, 3744-3746). In SB-MIDI UART mode it
  "terminates MIDI UART mode and restores all DSP parameters to the states
  prior to entering MIDI UART mode" (SBG:2827-2829, 3468-3470). [doc]
- A plain reset "returns it to its default state" (SBG:900-901) [doc]; the
  guide does not list the state. The firmware does: the 1 restarts the
  8051, which takes the cold start unless high-speed or UART mode left a
  signature (34h, 12h) in its RAM, when it takes the warm start [fw]:
  - cold (FW302 cold_boot, FW405 cold_boot): time constant 9Ch (10000 Hz;
    the 4.05's rate register 38h, 9973 Hz), 8-bit block length 07FFh, the
    E2h sequence from AAh/96h, the status byte 0 (speaker flag off, the
    4.05's timer off), mono input; on the 3.02 the port pins return high,
    so the speaker's output is off. Not touched: the test register (E4h,
    internal RAM 2Ah) [fw].
  - warm: everything above stays; the 3.02 turns the speaker and stereo
    input back on if they were [fw]. This is the guide's "restores all the
    DSP parameters".
  - The signature is set by 90h-9Fh and 34h-37h; the 4.05 clears it at the
    end of any 8-bit single-cycle block, the 3.02 at the end of 91h's
    block [fw].
  uCDD: as the firmware; an install starts as after a cold start.
- Both emulators clear the command parser, the reply queue, any DMA
  transfer, the pending interrupts, MIDI modes and the E2h sequence, set
  22050 Hz (time constant 45), and keep the speaker [emu-x, emu-86]: the
  firmware's 10000 Hz and speaker off disagree (13). The mixer is not reset
  by a DSP reset (its own register 00h resets it, SBG:2329) [doc,
  inference].

## 4. The command interface

- A command byte, then its argument bytes, all written to 2xCh while bit
  7 of 2xCh reads 0 (SBG:938-953).
- Replies are read from 2xAh while 2xEh bit 7 reads 1 (SBG:922-936).
- **An unknown command** takes no arguments and does nothing: both
  emulators give every byte not in their tables a length of 0 and ignore
  it [emu-x, emu-86]. The guide is silent.
- **A command not in the presented DSP version** does nothing and takes
  its documented arguments [emu-x: DSP_SB16_ONLY, DSP_SB2_ABOVE and
  DSP_SB201_ABOVE skip the effect after the arguments are read].
- **41h to 47h on the cards before the SB16** are aliases of 40h and take
  one argument (a demo depends on 41h acting as 40h on an SB Pro) [emu-x,
  hw note: vogons thread cited]. On the SB16, 41h and 42h are the rate
  commands [doc].
- **The busy bit.** The guide only says to wait for bit 7 clear. On the
  SB16 the write status toggles busy in a regular cycle even when idle,
  and a byte written during the busy phase is held until it ends [emu-x,
  hw note]. In high-speed mode the DSP "will not accept any other
  commands" (SBG:1346-1347, 3742) [doc]; the cards before the SB16 read busy
  and drop writes then [emu-x].
- **A reply** stays readable until read; a read with nothing waiting
  returns the last byte again [emu-x, hw note: "JANGLE DEMO"].

## 5. Commands by DSP version

From SBG chapter 6 (SBG:3134-3222 and each command's "Available" row).
"Args" counts the bytes after the command. "All" means 1.xx to 4.xx.

| Cmd | Args | Reply | Versions [doc] | Effect [doc unless marked] |
|---|---|---|---|---|
| 10h | 1 | | all | direct 8-bit DAC output (SBG:3250-3266) |
| 14h | 2 | | all | 8-bit single-cycle output, length = samples-1 (SBG:3271-3284) |
| 16h, 17h | 2 | | all | 2-bit ADPCM single-cycle; 17h with the reference byte; length = bytes-1 (SBG:3289-3323) |
| 1Ch | 0 | | 2.00+ | 8-bit auto-init output, block from 48h (SBG:3328-3349) |
| 1Fh | 0 | | 2.00+ | 2-bit ADPCM auto-init with the reference byte (SBG:3354-3371) |
| 20h | 0 | 1 | all | direct 8-bit ADC input (SBG:3376-3390) |
| 24h | 2 | | all | 8-bit single-cycle input (SBG:3395-3405) |
| 2Ch | 0 | | 2.00+ | 8-bit auto-init input (SBG:3410-3421) |
| 30h | 0 | | all | MIDI input, polling (SBG:3426-3438) |
| 31h | 0 | | all | MIDI input, interrupt; 31h again ends it (SBG:3443-3456) |
| 34h-37h | 0 | | 2.00+ | SB-MIDI UART modes: polling, interrupt, and both with time stamps; only a reset ends them (SBG:3461-3532) |
| 38h | 1 | | all | MIDI output of one byte (SBG:3537-3548) |
| 40h | 1 | | all | time constant (SBG:3553-3568) |
| 41h, 42h | 2 (high, low) | | 4.xx | output, input rate, "5000 to 45 000 Hz" (SBG:3573-3599) |
| 48h | 2 | | 2.00+ | block size, bytes-1, for auto-init and high speed (SBG:3604-3616) |
| 74h-77h | 2 | | all | 4-bit (74h, 75h) and 3-bit (76h, 77h) ADPCM single-cycle; the odd ones with the reference byte (SBG:3621-3680) |
| 7Dh, 7Fh | 0 | | 2.00+ | 4-bit, 3-bit ADPCM auto-init with the reference byte (SBG:3685-3714) |
| 80h | 2 | | all | silence for (length+1) sample periods, then the interrupt (SBG:3719-3730) |
| 90h | 0 | | 2.01+, 3.xx | 8-bit high-speed auto-init output (SBG:3735-3752) |
| 91h | 0 | | 2.01+, 3.xx | 8-bit high-speed single-cycle output (SBG:3757-3769) |
| 98h, 99h | 0 | | 2.01+, 3.xx | the same for input (SBG:3774-3801) |
| A0h, A8h | 0 | | 3.xx | input mono, stereo (SBG:3806-3832) |
| B0h-BFh | 3 | | 4.xx | 16-bit DMA: bit 3 input, bit 2 auto-init, bit 1 FIFO; mode bit 5 stereo, bit 4 signed; length = samples-1 (SBG:3837-3872) |
| C0h-CFh | 3 | | 4.xx | the same for 8-bit DMA (SBG:3877-3894) |
| D0h | 0 | | all | pause 8-bit DMA (SBG:3899-3909) |
| D1h | 0 | | all | speaker on; up to 112 ms; on 1.xx pauses DMA; on 4.xx only the flag (SBG:3914-3932) |
| D3h | 0 | | all | speaker off; up to 220 ms; the same notes (SBG:3937-3953) |
| D4h | 0 | | all | continue 8-bit DMA (SBG:3958-3968) |
| D5h, D6h | 0 | | 4.xx | pause, continue 16-bit DMA (SBG:3973-3999) |
| D8h | 0 | 1 | 2.00+ | speaker status: FFh on, 00h off (SBG:4004-4015) |
| D9h | 0 | | 4.xx | exit 16-bit auto-init at the block end (SBG:4020-4030) |
| DAh | 0 | | 2.00+ | exit 8-bit auto-init at the block end (SBG:4035-4046) |
| E1h | 0 | 2 | all | major, minor (SBG:4051-4061) |

Not in the guide (no Creative document has them; the firmware [fw] for
the SB16 and SB Pro, DOSBox-X for the rest):

| Cmd | Args | Reply | Behaviour |
|---|---|---|---|
| E0h | 1 | 1 | the argument inverted [fw, emu-x] |
| E2h | 1 | | DMA identification: a byte written by 8-bit DMA, or read at 2xAh when no transfer takes it (vess SPEC 7.1) [fw, emu-x, emu-86] |
| E3h | 0 | string | SB16: "COPYRIGHT (C) CREATIVE TECHNOLOGY LTD, 1992." and its zero [fw]; the 3.02 runs it as E2h (5.2) [fw] |
| E4h, E8h | 1, 0 | E8h: 1 | test register write, read; a reset keeps it [fw] |
| F2h | 0 | | the 8-bit interrupt [fw]; DOSBox-X after 10 us |
| F3h | 0 | | SB16: the 16-bit interrupt [fw] |
| F8h | 0 | 1 | 00h: the 4.05 clears its output latch, the 3.02 tests its RAM [fw] |

### 5.2 How the firmware decodes the command byte [fw]

Both firmwares dispatch on the high nibble. The 3.02 then decodes the low
bits of every group; the 4.05 decodes groups 1, 2, 3, 7, 8 and 9 the same
way and looks groups 0, 4, D, E and F up in 16-entry tables whose unused
entries do nothing. So an undocumented command runs as a documented one
(uCDD: sb_decode, then the table sb_commands):

| Group | Bits (both firmwares) | Runs as |
|---|---|---|
| 1 | bits 3, 2 clear; bit 2; bit 3; with bit 2 or 3, bit 1 ADPCM 2-bit and bit 0 its reference | 10h; 14h, 16h, 17h; 1Ch, 1Eh, 1Fh |
| 2 | bits 3, 2 clear; bit 2; bit 3 | 20h; 24h; 2Ch |
| 3 | bits 3, 2 clear; bit 2; bit 3 | 30h (MIDI input, 32h/33h with time stamps); 34h-37h; 38h |
| 7 | bit 2 alone; otherwise (70h-73h too) auto-init; bit 1 2.6-bit, bit 0 reference | 74h-77h; 7Ch-7Fh |
| 8 | any | 80h |
| 9 | bit 3 input, bit 0 single-cycle | 90h, 91h, 98h, 99h |

| 3.02 group | Bits | Runs as |
|---|---|---|
| 0 | bit 3; bit 2; neither | 08h-0Fh halt the DSP until a reset; 04h-07h reply the status register; 00h-03h nothing |
| 4 | bit 3 | 48h, else 40h |
| 5 | bit 3; bit 0 | 58h-5Fh load samples into RAM (four bytes and the samples; not modelled); 51h... play them; 50h... stop |
| 6, B, C | | nothing while idle; while a transfer runs, the A group's pin changes and the transfer stalls (not modelled, 13) |
| A | bit 3, then bit 2 | A8h-AFh stereo input (ACh-AFh also set a port pin of unknown use), A0h-A7h mono |
| D | bit 2; bit 3 (bit 1); bit 0 (bit 1); none | D4h; D8h or DAh; D1h or D3h; D0h |
| E | the highest of bits 3-0 | E8h, E4h, E2h (E3h too), E1h, E0h |
| F | the highest of bits 3-0 | F8h (RAM test, reply 00h, the RAM left as 55h: not modelled), F4h (the ROM's checksum, two bytes: not modelled), F2h (F3h too), F1h (port 2), F0h (a sine wave: not modelled) |

| 4.05 table | Commands |
|---|---|
| 0 | 01h CSP upload: 00h, then the length and the program; 02h 1 argument; 03h, 08h reply a CSP port (FFh without the chip); 04h 1, 05h 2; 06h, 07h; 09h two bytes, 0Ah two bytes (lock count, a CSP port); 0Bh, 0Ch take the length and wait for the chip forever; 0Eh 2 (X-bus write); 0Fh 1 and a reply (X-bus read); 00h, 0Dh nothing |
| 4 | 40h (EAh and above at 45412 Hz), 41h/42h, 44h-47h set and clear two port pins (not DAh's flag: 45h does not undo DAh), 48h, 4Ch 2, 4Dh 1 and a reply, 4Eh 2 (a one-shot timer), 4Fh (the timer: started with 2 bytes, or stopped), 43h and 49h-4Bh nothing |
| D | as the guide, plus DCh-DFh (port pins), D2h, D7h, DBh nothing |
| E | E0h-E4h, E8h; the rest nothing |
| F | F0h a test tone (not modelled), F2h, F3h, F4h replies 7Dh 1Bh, F8h 00h, F9h/FAh internal RAM read and write, FBh status byte, FCh auxiliary byte, FDh the command before it; F1h, F5h-F7h, FEh, FFh nothing |

The tables are 4.05's, which 4.04 shares; 4.11 to 4.16 add 43h (a DMA
transfer count), and 4.16 gives D2h and D7h a flag of their own [fw]. The
virtual SB16 is a 4.05.

uCDD's answers for chip state it does not keep: CSP reads FFh, 09h 00h
00h, 4Dh 00h, F9h 00h outside the block length (0Eh, 0Fh), the test
register (2Ah) and the commands (20h, 30h), F1h's port 2 as idle (32h, bit
0 with the speaker off, bit 3 with stereo input).

The SB 2.0's 2.01 is not dumped: its commands stay as the guide and
DOSBox-X have them, except 41h-47h as 40h (DOSBox-X) and 04h replying 88h
(DOSBox-X).

## 6. Rates and formats

- **Time constant** = 65536 - 256000000/(channels x rate), high byte
  (SBG:1249-1257). The rate is 1000000/(256-TC) bytes a second; with the
  SB Pro's stereo switch on, two bytes make a frame [doc, inference].
- **41h** sets the rate in hertz, no doubling for stereo (SBG:3577-3579),
  valid "5000 to 45 000 Hz inclusive" [doc]; outside it, the SB16 limits
  to its range [emu-x: DSP_RateLimitedFinalSB16Freq_New].
- **The ranges by version** (SBG:1418-1442, output): 4.xx 5000-44100 Hz
  for every format; 3.xx 4000-23000 Hz normal mono, 23000-44100 Hz
  high-speed mono, 11025 and 22050 Hz high-speed stereo; 2.01+ 4000-23000
  normal, 23000-44100 high speed; 1.xx and 2.00 4000-23000 Hz; ADPCM 4-bit
  to 12000 Hz, 3-bit to 13000 Hz, 2-bit to 11000 Hz. [doc] A program that
  asks for more gets what the card does: the documents do not say [open].
- **Data**: 8-bit unsigned, 16-bit signed (SBG:1188-1199); the SB16's
  mode byte selects signed or unsigned for both (SBG:3854-3863, 3884-3885).
  Stereo is left first (SBG:1216-1237). On the SB Pro "the first digitized
  sound data byte will be directed to the left channel" with the stereo
  switch on (SBG:2392-2398). [doc]

## 7. DMA transfers

### 7.1 Single-cycle

The DSP transfers the programmed count and interrupts (SBG:1280-1297).
The 8237 channel is the game's; the transfer cannot cross a 64 KB page
(SBG:1285-1294). 8-bit PCM, 16-bit PCM and ADPCM. [doc]

### 7.2 Auto-init

The block size comes from 48h (versions before 4.xx) or from the Bxh/Cxh
length (4.xx). An interrupt at the end of every block (SBG:1300-1314).
Two ways to stop (SBG:1318-1326, 3335-3341, 1678-1690, 2172-2186):

1. A single-cycle command: "The DSP will, at the end of the current block
   transfer, exit auto-init mode and process the new DMA mode I/O
   command." The new block starts after the current one ends.
2. DAh (8-bit) or D9h (16-bit): auto-init ends at the end of the current
   block, and the transfer stops.

[doc] The firmware: the 4.05 keeps the new length and starts it at the
block's end when its auto-init flag is set (a DAh clears the flag: a
single-cycle command after DAh restarts at once); a Cxh single-cycle
command's mode byte is then ignored. The 3.02 does the same behind any
transfer that runs, a single-cycle one too, so that single-cycle blocks
chain without a gap [fw]. Neither emulator queues: both start the new block
at once [emu-x, emu-86; 86Box: SBQUEUE L on the bare cards gives three
interrupts, 184/184/92 ms, where the guide gives four, 184/184/184/92].
uCDD: the guide's queue on every model (sb_queue_check), the 3.02's behind
a single-cycle block on the SB Pro; the queued command runs as written.
SBQUEUE: L, C, B four interrupts; S two on the SB Pro, one on the others.

### 7.3 High speed (2.01+, 3.xx)

90h, 91h, 98h, 99h with the block size from 48h. In high-speed mode "the
DSP will not accept any other commands"; 91h/99h leave it at the end of
the block, 90h/98h only by a reset, which restores the parameters from
before (SBG:1340-1356, 3735-3801). Mono and stereo 8-bit PCM; no ADPCM.
[doc] The SB16 accepts 90h-99h as well: both emulators play them on the
SB16, and games set to "Sound Blaster Pro" use them on SB16 cards [emu-x,
emu-86]; the guide's table leaves 4.xx out (13).

### 7.4 SB Pro stereo (SBG:1832-2034)

Stereo output on the SB Pro is the mixer's stereo switch (0Eh bit 1) with
the high-speed commands. The guide's procedure: set the switch, send one
silent byte by single-cycle DMA (14h, length 0) and take its interrupt,
then program the transfer, turn the output filter off (0Eh bit 5), set
the block size and start with 90h or 91h. [doc] The silent byte makes the
first data byte go to the left channel [inference from SBG:2394-2396].

### 7.5 ADPCM (SBG:1360-1377, 3289-3714)

- The first block carries a reference byte, the first byte of the block,
  "an actual data byte value"; later blocks use the commands without one.
  Decompression is output only. [doc]
- The decoding is in no Creative document. Both emulators decode with
  Creative's step tables (DOSBox-X's scaleMap/adjustMap); the vess
  specification (7.3) reduced them to one rule, with the ESS's 2.6-bit
  form being Creative's 3-bit form [emu-x, emu-86].
- The DMA count and the block length count compressed bytes (SBG:3294-3296).
  [doc]

### 7.6 Pause, continue, silence

- D0h/D5h stop the DSP's DMA requests, D4h/D6h resume them; for both
  single-cycle and auto-init (SBG:3899-3999). [doc]
- 80h plays (length+1) sample periods of silence and then interrupts
  (SBG:3719-3730). [doc]

### 7.7 Input

24h, 2Ch, 98h, 99h, C8h-CFh with bit 3, B8h-BFh with bit 3: the DSP writes
samples into memory by DMA at the rate, with the same interrupts as
output (SBG:1446-1464, 3395-3421). uCDD has no recording source: the
virtual card records silence (80h for 8-bit unsigned, 0 for signed)
[design, as the direct ADC 20h answers 80h today].

## 8. Interrupts

### 8.1 Before the SB16 (SBG:954-963)

One source on the line for DMA output, DMA input and interrupt-mode MIDI
input. "Within the ISR, each DSP interrupt is acknowledged by reading the
DSP Read-Buffer Status port once." [doc]

### 8.2 The SB16 (SBG:965-1018)

- "Four interrupts use the same Interrupt Request (IRQ) line": 8-bit DMA,
  16-bit DMA, SB-MIDI and MPU-401. Mixer 82h names them: bit 0 8-bit DMA
  or SB-MIDI, bit 1 16-bit DMA, bit 2 MPU-401; "A bit is set to 1 if the
  corresponding interrupt is triggered." [doc]
- Acknowledges: 2xEh for 8-bit or SB-MIDI, 2xFh for 16-bit, 3x0h for the
  MPU-401 (SBG:983-995). [doc]
- An ISR reads 82h first and chains to the previous handler when the
  interrupt is not its own (SBG:969-971, 997-1018). [doc]
- 82h bits 7:4 read the DSP's revision: 20h on a DSP 4.05, 10h on 4.04,
  80h from 4.11, 40h otherwise [emu-86]; DOSBox-X ORs 20h on every SB16
  [emu-x]. Reserved per the guide (SBG:981).

### 8.3 The MPU-401 on the SB16's line

- "An interrupt is generated when the interface is set to UART mode. It
  is not necessary to set up an interrupt service routine to handle the
  interrupt because reading from the Data port will clear the interrupt
  signal." (SBG:3059-3061) [doc] Every acknowledge byte (FEh after FFh in
  intelligent mode, after 3Fh) and every received MIDI byte raises it
  [emu-86: MPU401_QueueByte raises the IRQ when the queue goes from empty
  to one byte].
- In UART mode a reset (FFh) is not acknowledged [emu-86].
- [86Box] 86Box's SB16: MPUTONE P (a tone, and FFh/3Fh once a tick) gave 92
  interrupts with 82h bit 2 for 92 acknowledges; the tone played its 54
  blocks (16 Oct 2026).

### 8.4 The line (all models)

- The interrupt is a level that the card holds until the acknowledge
  (notes timers-pic-dma.md; the 8259 takes an edge). With the line already
  high, a new source adds its bit and raises no new edge [inference from
  SBG:981-982 and the 8259A's edge mode].
- F2h raises the 8-bit interrupt after the DSP's latency [emu-x: 10 us];
  F3h the 16-bit one at once [emu-x].

## 9. Mixers (SBG chapter 4)

### 9.1 Programming (SBG:2219-2277)

2x4h (write only) selects the register, 2x5h reads and writes it. Reserved
bits are undefined; software writes them as 0. [doc]

### 9.2 SB 2.0: none

No mixer at the card's base (section 2). [doc]

### 9.3 CT1345, the SB Pro (SBG:2351-2506)

| Reg | Bits | Meaning | Reset |
|---|---|---|---|
| 00h | | write: reset the mixer | |
| 04h | 7:5 left, 3:1 right | voice | 4 (-11 dB) |
| 0Ah | 2:1 | mic | 0 (-46 dB) |
| 0Ch | 2:1 source (0, 2 mic; 1 CD; 3 line), 3 filter 3.2/8.8 kHz, 5 input filter off | input | 0 |
| 0Eh | 1 stereo, 5 output filter off | output | 0 |
| 22h | 7:5, 3:1 | master | 4 (-11 dB) |
| 26h | 7:5, 3:1 | MIDI (FM) | 4 (-11 dB) |
| 28h | 7:5, 3:1 | CD | 0 (-46 dB) |
| 2Eh | 7:5, 3:1 | line | 0 (-46 dB) |

- Levels: 0 to 7 is -46 dB to 0 dB in about 4 dB steps (SBG:2498-2506).
  [doc]
- Read-back on a CT1600 (SB Pro 2) [emu-x, hw note]: registers 40h-FFh
  read FFh and take no write; 00h-3Fh decode only bits 5 and 3:0 (10h-1Fh
  mirror 00h-0Fh, 30h-3Fh mirror 20h-2Fh); 0Eh is also seen at 0Fh, 1Eh,
  1Fh, and a read of 00h, 01h, 10h or 11h returns 0Eh; 0Eh reads its bits
  1 and 5 with the reserved bits of each nibble set (11h, 13h, 31h, 33h).
  86Box returns FFh for every register it does not implement [emu-86].
- The SB16 registers 30h-47h do not exist on the CT1345 (above).

### 9.4 CT1745, the SB16 (SBG:2511-2752)

| Reg | Meaning | Reset [doc] |
|---|---|---|
| 00h | reset | |
| 04h, 22h, 26h | voice, master, MIDI, 4 bits a channel, mapped onto 32h/33h, 30h/31h, 34h/35h | 12 (-12 dB) |
| 28h, 2Eh | CD, line, the same | 0 (-60 dB) |
| 0Ah | mic, 3 bits | 0 (the guide says -48 dB; 0 to 7 is -42 to 0) |
| 30h-35h | master, voice, MIDI, bits 7:3, -62 to 0 dB in 2 dB steps | 24 (-14 dB): C0h |
| 36h-39h | CD, line | 0 |
| 3Ah | mic | 0 |
| 3Bh | PC speaker, bits 7:6 | 0 (-18 dB) |
| 3Ch | output switches: 4 line L, 3 line R, 2 CD L, 1 CD R, 0 mic | 1Fh |
| 3Dh | input left switches: 6 MIDI L, 5 MIDI R, 4 line L, 3 line R, 2 CD L, 1 CD R, 0 mic | 15h |
| 3Eh | input right switches, the same bits | 0Bh |
| 3Fh-42h | input, output gain, bits 7:6, 0 to 18 dB | 0 |
| 43h | bit 0: 0 mic AGC on, 1 fixed 20 dB | 0 |
| 44h-47h | treble, bass, bits 7:4, 8 = 0 dB | 8 (80h) |
| 80h | IRQ select: bit 0 IRQ 2, 1 IRQ 5, 2 IRQ 7, 3 IRQ 10 | the card's |
| 81h | DMA select: bits 0, 1, 3 channel 0, 1, 3; 5, 6, 7 channel 5, 6, 7 | the card's |
| 82h | interrupt status (8.2) | |

- 80h and 81h are "Read Only for PnP boards"; programs should not write
  them (SBG:1047-1052). The virtual card reads them as its own settings.
  [doc]
- Reset values in the emulators are louder than the guide's: 86Box sets
  30h-37h to F8h; DOSBox-X sets master, voice, FM and CD to 31 [emu-x,
  emu-86]. The guide decides; the CT2290 is to be read (14).
- Unimplemented registers: DOSBox-X keeps 3Bh-47h and returns 0Ah for
  others [emu-x]; to be read on the CT2290 (14).

## 10. MIDI (SBG chapter 5)

- **SB-MIDI**, every card: 38h sends one byte in normal mode; 34h-37h
  enter UART mode, where every write to 2xCh is MIDI data and 2xAh reads
  MIDI data; only a reset leaves it (SBG:2773-2876). Input by polling 2xEh
  bit 7 or by interrupt (31h, 35h, 37h), acknowledged at 2xEh; time-stamp
  modes prefix three bytes of milliseconds (SBG:2863-2876). [doc] In the
  input modes 30h-33h a byte written ends the mode and is lost (the 4.05's
  and 3.02's MIDI loop read it and leave; SBG:3450 "send the command 31h
  again") [fw]; uCDD has no MIDI input, and drops that byte. SB-MIDI
  goes out of the card's MIDI port, the same one the SB16's MPU-401 drives
  [inference from the SB16 block diagram, SBG:798-800: "MIDI PORT SB and
  MPU-401 COMPATIBLE"].
- **MPU-401 UART**, the SB16 only: 330h or 300h; status 3x1h bit 6
  output ready (0 = ready), bit 7 input ready (0 = data); commands FFh
  reset and 3Fh UART, each acknowledged with FEh (SBG:2881-3064). [doc]
  It is the physical card's (section 1).

## 11. Speaker (D1h, D3h, D8h)

- Before 4.xx the speaker connects the DAC to the amplifier; on 4.xx the
  commands only set the flag D8h reports (SBG:3914-3953). [doc]
- On 1.xx D1h and D3h pause the DMA transfer (SBG:3922-3923, 3943-3944).
  [doc] The virtual SB 2.0 is a 2.01 and does not.
- A cold reset turns the speaker off: on the 3.02 the 8051's port pins
  return high, and the pin that mutes the DAC is one; on the 4.05 the
  status byte returns to 0, its flag with it [fw]. A warm reset (after
  high-speed or UART mode) keeps it. The emulators keep it across every
  reset [emu-x, emu-86]; the guide's "default state" and the firmware
  decide (13). The SB 2.0 follows the 3.02 [inference: the same design,
  2.01 not dumped]. After power-on, and after uCDD's install, it is off.
- The 3.02's D1h also sets the DAC to 80h before unmuting [fw] (not
  modelled: a direct-DAC program writes its next sample anyway).

## 12. Timing

- Reset: AAh about 100 us after the 0 (SBG:892). [doc]
- D1h up to 112 ms, D3h up to 220 ms (SBG:3920, 3941). [doc]
- No other command time, no interrupt latency, in the guide. [doc]
- The DMA count moves at the programmed rate, as the 8237 is read
  (vess and spec-first notes); the block interrupt comes when the block's
  last byte has been transferred [doc: "after transferring", SBG:1590].

## 13. Where the sources disagree

| Point | SBG | DOSBox-X | 86Box | Decision |
|---|---|---|---|---|
| 90h-99h on 4.xx | not available (SBG:3751-3801) | accepted | accepted | accepted: both emulators, and the SB16 is sold as SB Pro compatible; to confirm on the CT2290 |
| Mixer reset levels | 4 (SB Pro), 12/24 (SB16), CD 0 | all at maximum | 30h-37h F8h | the guide |
| 2xEh on the SB16 | 8-bit acknowledge | 8-bit | clears 8-bit and 16-bit | the guide |
| AAh after reset | about 100 us | 20 us | at once | at once is within "about"; the guide gives no minimum |
| F8h | absent | 00h on every type, "pre-SB16 only" | | 00h |

Against the firmware [fw]:

| Point | Firmware | Emulators | Decision |
|---|---|---|---|
| Commands during a transfer (3.02) | groups 3 (but 38h), 4, 5, 8, E, F dropped while a transfer runs, their argument bytes then run as commands; 00h-03h and groups 6, A-C stall the transfer | taken | the guide: "the DSP is able to accept and execute commands" outside high-speed mode (SBG:1341-1344) |
| Single-cycle during auto-init | queued to the block end (both) | started at once | the guide (7.2) |
| Single-cycle during single-cycle | 3.02 queues, 4.05 restarts | restart | the firmware by model |
| Rate after a reset | 10000 Hz | 22050 Hz | the firmware |
| Speaker after a reset | off (3.02 output, 4.05 flag) | kept | the firmware: "its default state" |
| 45h, 47h | port pins only; DAh's exit stands | continue auto-init (DOSBox-X) | the firmware |
| 41h below 4864 Hz, from 45312 Hz | 4986 Hz, 45412 Hz | DOSBox-X clamps differently | the firmware |
| 41h rates with the lost carry (5699-5887, 8549-8703, 11398-11519, ..., 42741-42751 Hz: 1652 rates) | the rate register 16 low: 2849 Hz slower (FW405 X09a7) | as asked | the guide (the rate asked) |
| Time constant C8h on the SB16 | the table's C8h (35617 Hz) for 64h (17857 Hz) | as the formula | the guide |
| SB16 rate steps | rate register x 4096/23 Hz (22050 plays at 22083) | exact | exact: the register's real clock is not known (14) |
| 0Bh, 0Ch, 3.02 08h-0Fh | the DSP halts until a reset | various | the firmware |
| 30h-33h | the next byte written ends the mode and is dropped | taken as a command | the firmware (and SBG:3450, "send the command 31h again") |
| A reply not yet read | the next waits behind it | 86Box queues, DOSBox-X queues | queued |

## 14. To measure on the CT2290 (Michael's SB16)

First E1h: which 4.xx it carries (4.04, 4.05, 4.11, 4.12, 4.13, 4.16 are
dumped; the tables of 5.2 hold for each but 4.16 is to be checked).

1. The mixer after a reset (00h): 00h-FFh read back.
2. 82h's high bits, and 82h with an MPU-401 acknowledge pending.
3. 2xCh and 2xEh values idle, busy and with data; the busy cycle.
4. Unknown commands (06h, 50h, F0h): arguments taken? reply?
5. 90h/91h on the SB16; E3h; F8h; 04h/0Fh without an ASP.
6. The time from the reset's 0 to AAh; F2h's latency.
7. The MPU-401: an acknowledge's interrupt (82h bit 2) and when it ends.
8. SBQUEUE L, C, B, S, D: the queue, and S's one or two interrupts.
9. The rate: SBT16 R at 22050, 11025 and 44100 (22083, 11041 and 44166 if
   the register's step is 4096/23 Hz), 41h at 22900 (inside the lost-carry
   range: 20124 Hz if the firmware's sum is what the card plays, else 22973), time
   constant C8h (17857 or 35617 Hz).
10. After a reset: D8h (00h); E8h keeps E4h's value; 1Ch without a 48h
    plays 2048-byte blocks (07FFh); 1Ch without a 40h plays at 10000 Hz.
11. F4h (7Dh 1Bh), FBh, FCh, FDh; 0Fh with no CSP. Not 0Bh or 0Ch (they
    halt the DSP until a reset; harmless, but the probe needs a reset
    after).
12. DAh then 45h: does the auto-init end (the firmware says yes).
