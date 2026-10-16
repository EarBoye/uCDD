# Platform fast DMA: specification

Version 0.2, 17 Oct 2026 (0.1 the same day, before the AMD, OPTi and ALi
M1533 documents were found). Written from the reference library (branch
`reference-library`: `Chipsets/`, `Reference parts and specs/eisabook.txt`,
Ralf Brown's Interrupt List) before the code. It replaces UCDDSET's "Use Type
F DMA (Intel PIIX)" with "Enable platform fast DMA": the driver finds the
chipset, looks it up in its platform table, and runs the physical card's
output channel with the fastest DMA timing that chipset documents for an ISA
DMA slave, from a 386 to a Pentium III or Athlon.

## 0. Rules

- The data sheets decide (the project's rule 1). A chipset is in the table
  only when its own sheet gives a per-channel timing for ISA DMA devices; a
  knob the sheet leaves to the BIOS, or that changes every channel at once,
  is not used.
- Grades: **[sheet]** the chipset's data sheet, **[EISA]** the EISA
  specification (*EISA System Architecture*), **[RBIL]** Ralf Brown's
  Interrupt List, **[hw]** measured on the real PC, **[86Box]** an 86Box
  run, **[inference]** reasoning to be confirmed.
- Citations are `file:line` in the library's text copies (keys in the
  library's `notes/chipsets.md`, which this document checks line by line).
  The 17 Oct additions (AMD-756, -766, -768, ALi M1533 and M1535, OPTi
  Viper-M and FireStar, UMC) are in the library from that date; the Viper-M
  book is a scan, cited by section and table.

## 1. Why

ISA DMA in compatible timing takes 8 SYSCLKs a transfer in its repeated
part (about 1 us at 8.33 MHz). The CPU waits for the bus meanwhile. On the
real PC (PIIX3, ES1868, 13 Oct 2026), Type F cut the memory copy loss with
the output running from 9.0 to 0.7 percent at the half rate and from 18.0 to
1.5 at the full rate; Doom's timedemo went from 1788 to 1613 realtics [hw].

## 2. What the driver does

At install it finds the platform (3). While its output runs, the output
channel (the high one on an SB16, the low one on the other cards) gets the
platform's timing; when the output stops, steps aside or the driver unloads,
the channel gets back what it had. Only that channel changes; nothing global
(DMA clock, ISA clock, recovery times) is touched. The output only reads
memory (8237 mode 48h/58h: single, increment, read), which every method here
allows (4). The switch is off by default: the card must take the faster
cycles, and only the ES1868 on a PIIX3 has been seen to [hw].

## 3. Finding the platform

1. With a PCI BIOS (INT 1Ah B101h; skipped with SET UCDDPCI=OFF), each row
   of the table (5) is looked for by vendor and device (INT 1Ah B102h),
   function 0, and checked against its revision range. The first match is
   the platform.
2. Otherwise, a machine with "EISA" at F000:FFD9 [RBIL MEMORY.LST:2706-2708]
   is an EISA platform (5, method DCEM-A). EISA Pentium boards (82375 PCEB
   with the 82374 ESC) have no PCI-to-ISA bridge to find and land here.
3. Otherwise there is no fast DMA: a 386 or 486 ISA or VL-bus chipset, whose
   DMA unit is an 82C206 or a copy of one. Those offer only a global DMA
   clock (SYSCLK or SYSCLK/2) and global wait states in their index 01h
   [sheet: 82C206_Integrated_Peripheral_Controller_199608.txt:1313-1370],
   which also drive the floppy's channel, and they have no ID to find them
   by (ports 22h/23h are also a Cyrix CPU's configuration space)
   [inference].

## 4. Methods

| Method | Where | Set for channel c | Restore | Sources |
|---|---|---|---|---|
| MBDMA | PCI config 76h (MBDMA0), else 77h (MBDMA1), of the ISA bridge | `(old & 78h) | 80h | c` (FAST, the channel; bits 6:3 as read). On the PIIX (122Eh) bit 3 is DMC and must be 1 for an ISA card, so `(old & 70h) | 88h | c` | the byte read before | PIIX:1990-2032 (Type F "for an ISA peripheral"), PIIX4:3650-3672, 9733-9768 |
| DCEM-F | I/O 40Bh (c = 0-3) or 4D6h (c = 5-7), write only | `30h | (c & 3)` (Type F; bits 3:2 and 7:6 reserved 00) | `00h | (c & 3)`, the reset value | 1523:3714-3748, 1543:8938-8962, 1533:5862-5881 and 7118 (write only); Viper-M section 4.16 and tables 5-76, 5-79; FIRE:10424-10458 |
| DCEM-A | I/O 40Bh or 4D6h, write only | `10h | c` for c = 0-3, `14h | (c & 3)` for c = 5-7 (Type A; bits 3:2 00 8-bit or 01 16-bit words, as at reset; EOP out, no stop register) | `00h | c`, `04h | (c & 3)`, the reset values | SIO93:3633-3716 ("most ISA DMA devices should be able to use type A"), ESC:2572-2690, EISA:3671-3830 |
| VIA45 | PCI config 45h | bit c (c = 0-3) or bit c-1 (c = 5-7) set; config 41h bit 3 (the global double DMA clock) untouched | the byte read before | VP:975-990, 586B:2065-2073, 596B:2188-2196, 686B:3177-3187, 3227-3240, 8231:3268-3280; 756:5082-5112 |
| SIS71 | PCI config 71h, only while config 70h bit 7 (the DMA prefetch and post-write buffer) is 1 | bit c set (bit 4 is reserved) | the byte read before | 5597:8685-8732, 5582:7465-7507 |

Rules every method keeps:

- A register the BIOS already uses for another channel is left alone. MBDMA:
  a register with FAST set for another channel, or on the PIIX with DMC = 0
  and a channel other than 100b (a motherboard device routed there,
  PIIX:2010-2020), is in use; the method takes the other register, and with
  both in use does nothing. If FAST is already set for the output channel,
  nothing is written and nothing restored.
- Type F on the PIIX family needs memory forwarded to PCI (PIIX:4825-4828,
  PIIX4:9601-9604); the output ring is in conventional memory, which the
  BIOS forwards whenever ordinary DMA to it works [inference]. The extended
  timings of the SIO and ESC fall back to compatible timing by themselves
  for ISA memory (SIO93:3650-3651, 3679-3680; ESC:2631-2632).
- Writes to the PIIX's Type F register are reads-only transfers on the
  original PIIX (PIIX:4843-4844): the output reads memory. Nothing in uCDD
  records through the physical channel.
- DCEM is write only on the SIO and ESC (and not stated readable on ALi): the
  value before cannot be saved, so the restore writes the reset value. A BIOS
  or EISA configuration that set another timing for that channel loses it
  until the next reset [inference: unlikely for a sound card's channel].

What each gives over compatible timing (repeated part of a transfer):

| Timing | SYSCLKs | Source |
|---|---|---|
| Compatible | 8 (9 single) | SIO93:3684-3685, ESC:2637-2638 |
| Type A | 6 (7 single on the ESC) | SIO93:3687-3690, 6510-6511; ESC:2642-2643 |
| Type F (Intel) | 3 | PIIX:4836, PIIX4:9741 |
| Type F (ALi) | 2 repeated, 3 single | 1523:3746-3748, 1543:8961-8962 |
| VIA "type F" | the channel's DMA clock doubled: 8 MHz instead of 4 | 686B:3227-3240 |
| AMD-756 Type F | zero wait states, the DMA clock at BCLK | 756:5108-5112 |
| OPTi Type F | 3 ISA clocks repeated (Viper-M); IOR# 2 and IOW# 1 ISA clock for ISA devices (FireStar) | Viper-M 4.16; FIRE:10424-10433 |
| SiS Type-F | not given | 5597:8717 |

## 5. The platform table

| Platform | ISA bridge, PCI ID | Revision | Method | Boards (examples) |
|---|---|---|---|---|
| Intel PIIX | 8086:122E | any | MBDMA (DMC) | 430FX |
| Intel PIIX3 | 8086:7000 | any | MBDMA | 430HX, 430VX, 440FX |
| Intel PIIX4, 4E, 4M | 8086:7110 | any | MBDMA | 430TX, 440LX, 440BX, 440ZX, 440EX, 440GX |
| Intel 82378 SIO | 8086:0484 | any | DCEM-A | 420TX, 420ZX (486), 430LX, 430NX, 450KX/GX with the SIO |
| ALi M1523 | 10B9:1523 | any | DCEM-F | Aladdin III |
| ALi M1533, M1543, M1535 | 10B9:1533 | any | DCEM-F | Aladdin IV, V, Pro II; M1535: Aladdin Pro 4/5, MAGiK 1 (Athlon) [inference: no register map for the M1535] |
| VIA VT82C586, 586A, 586B | 1106:0586 | any | VIA45 | Apollo VP, VPX, VP2, VP3, MVP3 |
| VIA VT82C596, 596A, 596B | 1106:0596 | any | VIA45 | Apollo MVP4, Pro, Pro Plus, Pro133 |
| VIA VT82C686, 686A, 686B | 1106:0686 | any | VIA45 | Apollo Pro133A, KX133, KT133, KT133A (Athlon) |
| VIA VT8231 | 1106:8231 | any | VIA45 | PLE133, ProSavage |
| SiS 5597, 5598, 5582 | 1039:0008 | 01h | SIS71 | SiS 5597/5598, 5581/5582 |
| AMD-756 | 1022:7408 | any | VIA45 | AMD-750 (Athlon) |
| OPTi 82C558M Viper-M (and the desktop Viper's 82C558 if it shares the ID [inference]) | 1045:C558 | any | DCEM-F | Viper-M, Viper |
| OPTi 82C700 FireStar | 1045:C701 | any | DCEM-F | FireStar notebooks |
| EISA | ("EISA" at F000:FFD9) | | DCEM-A | 486 and Pentium EISA boards (82350/82357 ISP, 82374 ESC, OPTi 82C686 ISP) |

Not in the table, and why:

| Part | Reason | Source |
|---|---|---|
| 82C206 and the 386/486 ISA and VL chipsets built round it (C&T NEAT, PEAK, CS4031; OPTi 283/291/491/493/495; SiS 460/471; ALi M1429/M1487; VIA VT82C496G; Intel 82344) | global DMA clock and wait states only | 206:1313-1370, 4031:1870-1925, 1487:3549-3551, 496G:846-850 |
| SiS 85C496/497 (486 PCI, 1039:0496) | global only, through 22h/23h | 496:7690-7716 |
| SiS 5595 (1039:0008 rev B0h), SiS 630 (LPC) | 71h reserved; LPC has no ISA DMA timing | 5595:5986, 630:8196-8228 |
| Intel 82379AB SIO.A | always compatible (shares 0484h with the SIO: the writes do nothing there) | SIOZB:4530 |
| Intel 82380AB MISA, 82371MX MPIIX | compatible only | MISA:28-30, PBOOK:26284-26288 |
| Intel ICH family (810, 815, 820) | no ISA bus; an 82380AB bridge, compatible only | MISA:28-30 |
| AMD-766, AMD-768 (AMD-760) | no ISA DMA: an 8-bit partial ISA bus for the flash BIOS, DMA over LPC | 766:169-171, 768:978, 1387 |
| UMC UM8886 | 40Bh and 4D6h exist but nobody has their bits (UMC never published the manual; the reverse-engineered sheet lists them as unknown) | UMC:115 |
| SiS 85C503/5513, 5571; AMD-645; SiS 730, 735 | no data sheet in the library | - |

## 6. UCDDSET

- The Options column's box reads **Enable platform fast DMA**.
- The Detected column names what the scan found and what the box would do:
  `Intel PIIX3: Type F`, `Intel 82378 SIO: Type A`, `EISA: Type A`,
  `ALi M1533/35/43: Type F`, `VIA VT82C686: fast DMA clock`,
  `AMD-756: fast DMA clock`, `OPTi Viper: Type F`, `OPTi FireStar: Type F`,
  `SiS 5597/5598: Type F`, `SiS 5597/5598: off in BIOS` (70h bit 7 clear),
  `ISA bridge vvvv:dddd: none known` (a PCI ISA bridge, class 0601h, not in
  the table), `No fast DMA known` (no PCI bridge and no EISA).
- The box is greyed when the platform has no method; the help line says
  why ("No fast DMA on this chipset, or its BIOS has it off."). A greyed box
  still shows the saved byte, so a configuration carried to another machine
  keeps the user's choice. Ticked, its help line reads "Faster sound card
  DMA, as the chipset allows. Untick if sound breaks."
- UCDD.CFG keeps the byte (config_fast_dma, version 4): a file that had Type
  F ticked keeps fast DMA ticked. The switch is off by default.

## 7. Tests

17 October 2026, build 128 frames, ESS on 220h/7/1 (DMA 1) unless said,
86Box 6.0 build 9001. PLATREG reads the bridge's 40h-7Fh before the
install, stepped aside, engaged (a CUE mounted), after a tone through the
virtual card, and stepped aside again after the unmount. Evidence: emulator.

| Machine | Bridge | UCDDSET says | Register: before, engaged, after | Tone |
|---|---|---|---|---|
| p54tp4xe | PIIX 8086:122E | Intel PIIX: Type F | 76h 04, 89, 04 | 87 Hz, as on PIIX3 |
| p55t2p4 | PIIX3 8086:7000 | Intel PIIX3: Type F | 76h 04, 81, 04 | 87 Hz |
| an430tx | PIIX4 8086:7110 | Intel PIIX4: Type F | 76h 04, 81, 04 (77h 04 untouched) | 87 Hz |
| batman | 82378 SIO 8086:0484 | Intel 82378 SIO: Type A | 40Bh is write only: not visible | 87 Hz |
| m560 | ALi M1543 10B9:1533 | ALi M1533/35/43: Type F | 40Bh is write only: not visible | 87 Hz |
| cuv4xls | VIA 686B 1106:0686 rev 40h | VIA VT82C686: fast DMA clock | 45h 80, 82, 80 (the BIOS's bit 7 kept) | 87 Hz |
| sp97xv | SiS 5582 1039:0008 rev 01h | SiS 5597/5598: off in BIOS (greyed) | 70h 1Ah (bit 7 clear): 71h untouched | 87 Hz |
| 486, 386 ISA | none | No fast DMA known (greyed) | - | - |

- The SB16 on 220h/7/1/5 (output on DMA 5) on the m560 and the p55t2p4:
  the tone through the virtual card and a 16-bit stereo tone on the bare
  card after the put-back are the same, second by second, with the switch
  on and off.
- 86Box does not model DMA cycle timing, so none of this shows the gain;
  and its ISA DMA path does not read the extended mode register (section 8),
  so the DCEM runs show detection and no harm, not the write.
- Still to do: the real PC (PIIX3), the 13 Oct numbers again through the
  platform path, and the CT2290 SB16 on Type F (its first test with fast
  DMA). Open, needs hardware we do not have: any method but MBDMA on a real
  board; each card's tolerance (the switch stays the user's).

## 8. Disagreements

1. **DCEM bits 3:2 on ALi and OPTi.** Intel's SIO and ESC use bits 3:2 of
   40Bh/4D6h for the transfer size (00 8-bit, 01 16-bit words; 01 at reset
   on 4D6h). The ALi M1533 sheet gives bits 3:2 as reserved, default 00, for
   both registers (1533:5862-5881); the Viper-M book says "Reserved: Must be
   written to 0" (tables 5-76, 5-79); the FireStar book says "Not
   implemented", only the bits shown supported (FIRE:10429-10458). 86Box
   since September 2026 applies Intel's size bits to its ALi M1543, OPTi
   Viper, SiS 85C411 and WD76C10 models: there the driver's `31h` to 4D6h
   would make channel 5 an 8-bit channel. The documents decide: the driver
   writes 00 in bits 3:2, as the three sheets say. ALi's default of 00 on
   4D6h, where a size field would need 01 for the 16-bit channels to work
   from reset, agrees [inference]. If an ALi or OPTi chip did take the bits
   as Intel's, a 16-bit output channel would break while engaged and after
   (the restore writes 00h as well) until a reset; the switch is off by
   default and its help line says to untick it. A real ALi or OPTi board
   with an SB16 on DMA 5 settles it.
2. **86Box 6.0 build 9001** (May 2026), the build these tests ran on, keeps
   the extended mode register but decodes it with `(val > 2)` for
   `(val >> 2)`, and its ISA transfers take their width from the channel
   number, not from that register: a DCEM write changes nothing a test can
   see. Fixed upstream in September 2026 (see 1).
