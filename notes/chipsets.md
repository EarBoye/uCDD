# Chipset notes: ISA DMA timing, ISA-side knobs, RTC/PIC/DMA quirks

Scope: every ISA bridge, south bridge and PC/AT chipset in `library/Chipsets/` (386, 486,
Pentium, P6), plus `Reference parts and specs/eisabook.txt` and the 82C206 data sheet where a
chipset delegates its DMA unit to an 82C206. Citations are `file:line` in the pdftotext copies.
"Doc:" marks what a document says; "Infer:" marks my reading. Hex values are as printed.

File keys used below (all under `library/Chipsets/` unless noted):

| Key | File |
|---|---|
| PIIX | Pentium/82371FB_82371SB_PIIX_PIIX3_datasheet_final.txt |
| PIIXp | Pentium/290550-001_82371FB_82371SB_PCI_ISA_IDE_Xcelerator_199605.txt |
| PBOOK | Pentium/241732-003_Pentium_and_Pentium_Pro_Processors_and_Related_Products_1996.txt |
| PIIX4 | Pentium/290562_82371AB_PCI-TO-ISA_IDE_XCELERATOR_PIIX4_199704.txt |
| SIO93 | 486/1993_Intel_82378_PCI-ISA_System_IO.txt |
| SIOZB | Pentium/290571-001_82378ZB_82379ZB_System_IO_and_System_IO_APIC_199603.txt |
| ESC | Pentium/82374EB.txt |
| MISA | P6/290563-001_82380AB_199702.txt |
| VP | Pentium/VT82C580VP_Apollo_VP_199602.txt (VT82C586 section) |
| 586A, 586B | Pentium/VT82C586A_..._199610.txt, Pentium/VT82C586B_..._199705.txt |
| 596B | Pentium/VT82C596B_South_Bridge_199906.txt |
| 686A, 686B | P6/VT82C686A_Super_South_Bridge_V1.1_199904.txt, P6/VT82C686B.txt |
| 8231 | P6/VT8231_PC99_South_Bridge_199910.txt |
| 496G | 486/VT82C496G_VT82C406MV_199504.txt |
| 1523 | Pentium/M1523B_PCI_to_ISA_Bridge_199701.txt |
| 1543 | Pentium/M1543C_Desktop_Southbridge.txt |
| 1487 | 486/M1487_M1489_486_PCI_Chip_Set_199707.txt |
| 5595 | Pentium/SiS-5595_PCI_System_IO_199811.txt |
| 5597 | Pentium/SiS-5597-5598_199704.txt |
| 5582 | Pentium/SiS-5582_199704.txt |
| 630 | P6/SiS-630_199910.txt |
| 496 | 486/SiS_85C496-497_199507.txt |
| 471 | 486/85C471_V6.0_199408.txt |
| 460 | 486/SiS_85C460.txt |
| 4031 | 486/CS4031_Chipset_F84031_F84035_199305.txt |
| PEAK | 386/82C351_355_356_PEAK_DM_prelim_199102.txt |
| 206 | Reference parts and specs/82C206_Integrated_Peripheral_Controller_199608.txt |
| VIPER | Pentium/Viper_Express+_BIOS_Programming_Guide_199701.txt |
| EISA | Reference parts and specs/eisabook.txt |

## 1. Per-channel fast DMA timing

| Part | PCI ID (doc) | Faster-than-compatible per channel? | Register and bits | Power-up default | Source |
|---|---|---|---|---|---|
| 82371FB PIIX | 8086:122E (PIIX:1534) | Yes, Type F (3 SYSCLK) + 4-byte buffer, max 2 channels | cfg 76h MBDMA0, 77h MBDMA1: b7 FAST, b6:4 rsvd, b3 DMC (0 = route MDRQ/MDAK pair to CHNL, 1 = use ISA DREQ/DACK), b2:0 CHNL (100 = disabled) | 0Ch per final and preliminary sheets; 04h per 1996 databook | PIIX:1995-2032, PIIXp:1905-1920, PBOOK:31308-31338 |
| 82371SB PIIX3 | 8086:7000 (PIIX:1535) | Yes, Type F, max 2 channels | 76h/77h: b7 FAST, b6:3 rsvd, b2:0 CHNL | 0Ch | PIIX:1995-2032, 4789-4792 |
| 82371AB PIIX4 | 8086:7110 fn 0 (PIIX4:3158-3161) | Yes, Type F for "an ISA peripheral" | 76h/77h: b7 FAST, b6:4 rsvd, b3 "Reserved. Read as 1", b2:0 CHNL | 04h (conflicts with b3 read-as-1) | PIIX4:3650-3672, 9733-9768 |
| 82378 / 82378ZB SIO | 8086:0484 (SIO93:2237-2240, SIOZB:1610-1613) | Yes, Type A (6), B (5), F (3 SYSCLK); to main memory only | I/O 40Bh (ch 0-3), 4D6h (ch 5-7), write only: b7 rsvd/Stop, b6 EOP in, b5:4 timing 00 compat 01 A 10 B 11 F, b3:2 size (00 8-bit, 01 16-bit words), b1:0 channel | b5:4 = 00, b3:2 = 00 (DMA1) / 01 (DMA2), EOP out | SIO93:3633-3716, 6497-6530, SIOZB:4546-4551 (DCEM page is blank in SIOZB text, 2880-2915) |
| 82379AB SIO.A | 8086:0484 | No: "always generates ISA-Compatible" cycles | - | - | SIOZB:4530, 4559 |
| 82374EB/SB ESC (EISA) | none (EISA side; config via 22h/23h after ESCID=0Fh) | Yes, Type A, B, C (burst, EISA only); no Type F | I/O 40Bh/4D6h write only, b5:4 00 compat 01 A 10 B 11 C | 000000xxb | ESC:2572-2665, 1587-1624; EISA:3671-3830 |
| 82380AB MISA (mobile) | 8086:123C (MISA:531-535) | No: "compatible ISA DMA timings for all 7 DMA channels" | - | - | MISA:28-30 |
| 82371MX MPIIX | (DID not legible) | No: "Compatible DMA Transfers" | - | - | PBOOK:26284-26288 |
| VIA VT82C586 / 586A / 586B | 1106:0586 (VP:884, 586A:1630, 586B:1973) | Yes, "DMA type F Timing" per channel; plus global double DMA clock | cfg 45h: b7 ISA master/DMA line buffer, b6..b4 ch 7..5, b3..b0 ch 3..0; cfg 41h b3 Double DMA Clock (0 = DMA clock is ISA/2) | 45h = 00h, 41h b3 = 0 | VP:979-990, 941; 586A:1720-1728, 1661-1663; 586B:2065-2073, 1997-1999 |
| VIA VT82C596B | 1106:0596 (596B:2070) | Same as 586B | 45h as above; 41h b3 | 00h | 596B:2188-2196, 2144-2146 |
| VIA VT82C686A / 686B | 1106:0686 (686A:3123, 686B:3149) | Same; 686B text says 45h[n] makes channel n 8 MHz, 16 MHz if 41h b3 also set | 45h, 41h b3 | 00h | 686A:3199-3211, 3147-3149; 686B:3177-3187, 3227-3240 |
| VIA VT8231 | 1106:8231 (8231:3193) | Same | 45h, 41h b3; plus 5Ch b0 DMA Line Buffer Disable | 00h | 8231:3268-3280, 3218-3220, 3449-3482 |
| VIA VT82C496G (486) | not PCI (index A8h/A9h) | No per channel. Global: "DMA controller runs either at the same or half the speed of the ISA clock (bit 6 of RX10h)" | A8h/A9h index 10h b6 (polarity not given; register app note not in folder) | not given | 496G:846-850, 1273-1277 |
| ALi M1523B | 10B9:1523 (1523:1137-1138) | Yes, Type F (3 SYSCLK single, 2 repeated) | I/O 40Bh/4D6h: b5:4 11 = Type F, 00/01/10 = compat; b3:2 and b7:6 reserved 00; b1:0 channel | 00 | 1523:3714-3748 |
| ALi M1543C | 10B9:1533 (1543:2762-2767) | Yes, same DCEM as M1523B | I/O 40Bh/4D6h as above | 00 | 1543:8938-8962 |
| ALi M1487 (486) | not PCI (22h/23h after unlock 03h then C5h) | No per channel. Global DMA clock | index 29h b3 (0 = DMA clock is ATCLK/2, 1 = ATCLK) | 00h | 1487:2376-2392, 3524-3575 |
| SiS 5597/5598, 5582 | 1039:0008, rev 01h (5597:8085-8118, 5582:6870-6901) | Yes, "Type-F DMA Control" per channel, only when 70h b7 = 1 | cfg 71h: b7..b5 ch 7..5, b4 rsvd, b3..b0 ch 3..0; 70h b7 = DMA/ISA master prefetch/postwrite; 47h b0 global DMA clock | 71h = 00h, 70h = 12h (b7 = 0), 47h = 00h | 5597:8717-8732, 8689-8693, 8266-8290; 5582:7494-7507, 7465, 7046-7070 |
| SiS 5595 | 1039:0008, rev B0h (5595:5212-5217, 5260-5261) | No Type F in text (71h is "Reserved"). Global DMA clock and DMA wait states | 47h: b0 DMA clock (0 = ISA/2 "recommended"), b5:4 16-bit and b3:2 8-bit DMA wait states (00 = 1 DMACLK) | 00h | 5595:5439-5466, 5986 |
| SiS 630 (LPC bridge) | 1039:0008 (630:7914-7924) | No ISA DMA timing (LPC, DDMA only) | - | - | 630:8196-8228 |
| SiS 85C496/497 (486 PCI) | 1039:0496 (496:5513-5518) | No per channel. Built-in 206 timing | 22h/23h index 01h: b0 DMA clock, b5:4 / b3:2 DMA wait states, b1 early DMAMEMR# | C0h | 496:7567-7568, 7690-7716 |
| SiS 85C471, 85C460 | not PCI | No per channel; "selection of the DMA clock rate" via 22h/23h index 01h | as 82C206 index 01h | not given | 471:863-870; 460:788-797 |
| C&T CS4031 (84035) | not PCI | No per channel. Index 01h (82C206 layout) and 0Ah DMA clock divider from SCLK | 22h/23h idx 01h b0, b5:2; idx 0Ah b3:0 | 00h | 4031:1171-1178, 1870-1925, 2026-2065 |
| C&T PEAK 82C356, NEAT CS8221, CS8230, OPTi 82C491/493/495XLC/546-547/283/291 | not PCI | No per channel. DMA unit is an 82C206 (discrete or megacell); global DMA clock via 22h/23h index 01h | 206 idx 01h: b0 0 = SYSCLK/2, 1 = SYSCLK; b3:2 8-bit, b5:4 16-bit DMA wait states (00 = 1) | 00h (b7:6 = 11) | 206:1313-1370; PEAK:7449-7500 |
| OPTi 82C686 ISP (EISA) | not PCI | EISA Type A/B/C per EISA spec (40Bh/4D6h) | per EISA spec | - | 486/82C681_...:3304, 5175-5180 |
| OPTi 82C578 (Viper Xpress+) | 1045:C568 as PCIDV1 (VIPER:204, 260) | Not documented in this BIOS guide | - | - | VIPER (no DMA timing text) |
| Intel 82344 (386) | not PCI | Mentions "DMA wait state, clock, and -MEMR timing programmability"; register not in this excerpt | - | - | 386/240843-001_82344_199010.txt:79-82 |

### 1a. PIIX family register 76h: what the documents say

Doc, common to all three: b7 FAST enables Type F and the 4-byte DMA buffer for the channel in
b2:0; b2:0 = 100b means disabled (PIIX:2008-2031, PIIX4:3659-3667). Type F only with increment
mode, single or demand (not block), no verify (PIIX:4834-4840, PIIX4:9654, 9730, 9755-9757).
The channel's memory must be forwarded to PCI; BIOS should not enable Type F if ISA memory is
present above TOM (PIIX:4825-4828, PIIX4:9601-9604). Type F also removes the 8-SYSCLK DREQ
delay used in compatible mode (PIIX4:9760-9768; SIO93:6543-6546 for the SIO). Compatible
repetition is 8 SYSCLK, Type F 3 SYSCLK (360 ns) (PIIX4:9739-9742).

- PIIX4 vs PIIX3: same offsets (76h/77h), same FAST and CHNL fields, same channel encoding.
  Differences: default 04h instead of 0Ch, and b3 "Reserved. Read as 1" (PIIX4:3653, 3664).
  PIIX4 also says Type F is "provided for motherboard DMA slave and ISA DMA slaves"
  (PIIX4:9735-9737). PIIX4 adds PDMACFG 90h-91h: a channel set to PC/PCI or Distributed DMA
  ignores the ISA DREQ (PIIX4:3773-3830); default 0000h = normal ISA DMA.
- Verdict for 7110h: the uCDD write `(old & 78h) | 80h | channel` is correct for PIIX4. It keeps
  b6:3 as read (b3 reads 1 per the text), sets FAST and the channel. Restoring the saved byte is
  also fine. Infer: the 04h default printed beside "read as 1" is a sheet inconsistency; masking
  with 78h is the right defence either way.
- PIIX (122Eh) is the one that differs. b3 is DMC, not reserved. With DMC = 0 the MDRQ/MDAK#
  pair is routed to CHNL and the ISA DREQ/DACK# pins of that channel are masked; with DMC = 1
  the ISA pair is used and FAST applies to the ISA peripheral (PIIX:2010-2025). The final and
  May-1996 sheets give default 0Ch (DMC = 1), the 1996 Pentium databook gives 04h (DMC = 0)
  (PIIX:1998, PIIXp:1908, PBOOK:31311).
- PIIX only: "does not support Type F DMA write timings ... Type F DMA read timings ... are
  supported" (PIIX:4843-4844). Playback (8237 mode 48h/58h, memory to I/O) is a read transfer,
  so it qualifies. Recording on the same channel (mode 44h/54h) must not run with FAST set.
- Doc: up to two channels can be Type F at once, one per MBDMA register (PIIX:4791-4792).

## 2. Other ISA-side knobs (PIO and DMA cost)

BIOS-set means the document says BIOS programs it or it is board/clock dependent. "Runtime"
is my judgment of whether a TSR can change and restore it around playback.

| Knob | Part: register, encoding, default | Source | Who sets / runtime safety (Infer unless quoted) |
|---|---|---|---|
| ISA clock divider | PIIX: strap, read in MSTAT 6Ah b0 (RO); PIIX3: same bit R/W, 1 = /3 (25 MHz PCI), 0 = /4 | PIIX:598-606, 1942-1949 | BIOS/strap. Do not touch: depends on PCI clock. |
| | PIIX4: fixed PCICLK/4 | PIIX4:1694-1699 | none |
| | SIO: cfg 4Dh b2:0, 000 = /4, 001 = /3; reset ISA via b3 when changing; default 40h | SIOZB:2232-2280 | BIOS. Do not touch. |
| | SIO: with /3, DMA line buffer (40h b0) must be 0 | SIOZB:4483-4489 | BIOS |
| | VIA: 42h b3 enable, b2:0 select (/3 /2 /4 /6 /5 /10 /12 OSC/2); default PCICLK/4; documented switch sequence | 586B:2020-2041, 686B:3205-3231 | BIOS. Do not touch. |
| | ALi M1523B/M1543C: 42h b2:0 (000 = 7.16 MHz, 001-101 = PCICLK/2../6); M1487: 29h b2:0 | 1523:1258-1300, 1543:3020-3060, 1487:3524-3545 | BIOS |
| | SiS 5595/5597/5582: 45h b7:6 (00 = 7.159 MHz, 01 = /4, 10 = /3); 85C497: 70h b7:6 | 5595:5385-5390, 5597:8223-8227, 496:7575-7582 | BIOS |
| | OPTi 82C578: PCIDV1 47h b5:4 ATCLK select | VIPER:893, 936-941 | BIOS |
| 8/16-bit I/O recovery | PIIX/PIIX3 cfg 4Ch IORT, default 4Dh: b6 8-bit enable, b5:3 extra SYSCLK (001 = 1 .. 000 = 8), b2 16-bit enable, b1:0 (01 = 1 .. 00 = 4); base 3.5 SYSCLK; b7 DMAAC (90h-9Fh alias) | PIIX:1660-1708 | BIOS. Default adds 1 SYSCLK each. Lowering is possible at runtime but saves only ~120 ns per back-to-back I/O and risks slow cards. |
| | PIIX4 4Ch, default 4Dh, same 8-bit table; 16-bit table printed as 00 = 3, 01 = 1, 10 = 2, 11 = 4 (differs from PIIX) | PIIX4:3342-3410 | BIOS |
| | SIO 4Ch ICRT, default 56h, base 5 SYSCLK, +1..+8 | SIOZB:2183-2225 | BIOS |
| | MISA 40h, default 4Dh, b7 SYSCLK divider | MISA:695-740 | BIOS |
| | VIA 40h b3 enable (default off), b4 chipset I/O wait states 2/4, b5 ISA slave wait 4/5, b7 command delay; 686B 41h b6 recovery 13 vs 8 BCLK | 586B:1963-1993, 686B:3168-3175 | BIOS |
| | ALi 41h b5:2 period 0..3.75 us (2 ATCLK steps), b0 enable, b1 on-chip; default 00h; "not ... longer than 1 us" | 1523:1193-1250, 1543:2968-3015 | BIOS |
| | ALi M1543C 43h b1:0 / b3:2 extra waits on 16-bit I/O / memory | 1543:3084-3120 | BIOS |
| | SiS 46h b7:6 16-bit recovery (00 = 5 BUSCLK .. 11 = 2), b5:4 8-bit (00 = 8 .. 11 = 3); default 00h (slowest) | 5595:5412-5437, 5597:8244-8262 | BIOS. Default is the slowest setting. |
| DMA clock (SYSCLK or SYSCLK/2) | 82C206 idx 01h b0 (0 = /2); 85C497 idx 01h b0; CS4031 idx 01h b0 + 0Ah divider; M1487 29h b3; SiS 47h b0; VIA 41h b3; VT82C496G Rx10 b6 | 206:1360-1370, 496:7714-7716, 4031:1921-1925, 1487:3549-3551, 5595:5462-5466, 586B:1997-1999, 496G:850 | All global (every channel including floppy). Doc "recommended" /2 on SiS (5595:5464). Not safe to flip globally. |
| DMA wait states | 82C206/85C497/CS4031 idx 01h b3:2 (8-bit) and b5:4 (16-bit), 00 = 1 wait; SiS 47h same layout, 00 = 1 DMACLK | 206:1340-1358, 5595:5451-5461 | BIOS. Already at minimum by default. |
| DMA/ISA master line buffer | SIO 40h PCICON b0 DLBC (0 = single, 1 = 8-byte), b1 ILBC, b2 PPBE posted write; default 20h | SIOZB:1712-1760, 4645-4672 | BIOS. b0 must stay 0 with PCICLK/3. |
| | VIA 45h b7 line buffer (default 0); 46h b5 flush line buffer for int or DMA IOR; VT8231 5Ch b0 disable | 586B:2066, 2027-2032; 8231:3478-3482 | BIOS |
| | ALi 40h b0 DMA line buffer, b1 ISA master, b2 PCI-to-ISA posted write; default 00h, "Value 1 is recommended" | 1523:1145-1190, 1543:2909-2965 | BIOS |
| | SiS 5597/5582 70h b7 DMA/ISA master prefetch/postwrite (default 0); 5595 "two 32 bit Prefetch/Post Buffers" | 5597:8689-8693, 5595:235 | BIOS; 5597 needs it for 71h Type F. |
| | PIIX/PIIX4: 4-byte DMA buffer comes with FAST only | PIIX:4836-4838, PIIX4:9750-9757 | via MBDMA |
| Posted I/O writes to the sound card | ALi M1523B 40h b6 "I/O posted-write buffer"; M1543C 40h b6 "Sound Card I/O Posted-Write", needs 40h b2, ports in 50h-51h / 52h-53h (b15 enable, b11:0 address); defaults 0 | 1523:943, 1145-1152; 1543:2916-2922, 3588-3610 | BIOS normally. Infer: a TSR could set one port (DSP write 2xCh) and restore it; reads are retried until the buffer drains (1543:2444). Low value. |
| Top of memory for DMA | PIIX TOM 69h (default 02h, "must be set by the BIOS"; b1 forwards 512-640K) ; VIA 4E-4Fh b15:12 top, b9/b8 forward 80000-9FFFF / 0-7FFFF | PIIX:1801-1840, 586B:2092-2112 | BIOS. Relevant: Type F needs the ring in forwarded memory. |
| IOCHRDY during DMA | M1543C 74h b7 | 1543:4388-4395 | BIOS |

## 3. RTC, IRQ 8, 8259, 8237 integration

RTC location and banks:
- PIIX/PIIX3, SIO, ESC, M1523B/M1543C: external RTC, chip selects only. PIIX XBCS 4Eh b0
  enables RTCCS#/RTCALE for 70h-77h (PIIX:1766-1767); ESC suppresses RTCRD#/RTCWR# for CMOS
  36h-3Fh when port 92h b3 (password) is set (ESC:1414-1434).
- PIIX4 internal RTC, 256 bytes: standard bank at 70h/71h, extended bank at 72h/73h, enabled
  by RTCCFG CBh (default 21h: b0 RTC enable, b2 upper RAM enable = 0, b5 positive decode),
  b3/b4 write-once locks for 38h-3Fh (PIIX4:4050-4106, 2660-2800, 11204-11240). IRQ8# pin is
  GPI6 unless GENCFG B0h b14 = 1; the internal RTC drives IRQ8 internally (PIIX4:3964-3965,
  11476-11479). Internal RTC registers "can only be accessed by PCI masters" (PIIX4:11240).
- VIA 586B..8231 internal RTC (Rx5A b2): 70/71 lower 128, 72/73 all 256, 74/75 when 48h b3 set;
  48h b4 selects IRQ8# input pin for an external RTC (586B:1896-1945, 2084-2093).
- SiS 5595/5597/5582: one port pair 70h/71h for three banks; 45h b3 EXTEND_EN = 1 switches
  70/71 to the extended bank, 45h b1 APCREG_EN to APC registers (5595:2815-2835,
  5597:1919-1934). SiS 630 moves these to 48h b7/b6 (630:8175-8193).
  Infer: with EXTEND_EN or APCREG_EN left set, index 0Ch reads extended RAM, so register C is
  never read, IRQF stays set and IRQ 8 stops. A fine-timer handler on SiS should not assume
  70h/71h reach register C unless 45h b3:b1 are clear.
- Port 70h readback: M1543C 52h-53h b13 enables reads of the RTC index ports 70h/72h
  (1543:3620-3622); SiS 630 60h mirrors port 70h read-only (630:8322-8330). Elsewhere 70h is
  write-only, so an IRQ 8 handler cannot restore the foreground's CMOS index (Infer).

Periodic interrupt (Doc, PIIX4 as the documented MC146818 clone): RS3:0 in register A pick
122.07 us (0011) to 500 ms; PIE in B; register C flags all clear on a read of C
(PIIX4:11286-11320, 11350-11360, 11401-11418). SQWE has no function, no SQW pin
(PIIX4:11370-11373). Infer: IRQ8 is edge, so an unread register C leaves IRQ8 high and no
further edges arrive; read C in every handler.

IRQ 8 polarity and mode:
- PIIX/PIIX3/PIIX4: IRQ8# active low, edge only, cannot be changed (PIIX:750-753, 5450-5451;
  PIIX4:1515-1519, 4800-4802). Must stay asserted until INTA or a default IRQ7 results
  (PIIX4:1517-1519).
- SIO: pin text says IRQ8# mode is ELCR-programmable (SIOZB:991-994), the ELCR table says INT8
  "Must be 0" (SIOZB:3940-3955). ESC: INT8 must be edge (ESC:4237-4245). M1487: IRQ8J must be
  edge, ELCR 4D1h b0 (1487:2276-2305). SiS: IRQ8 edge, not programmable (5595:3775-3778).
- Rerouting: no document offers moving the RTC interrupt off IRQ 8. SiS 5595 can merge serial
  IRQ8 (SIRQ8) into IRQ8 via 89h b7 (5595:3812). PIIX4 XBCS b8 turns IRQ0/IRQ8# pins to APIC
  use (PIIX4:3450-3458). SMI on IRQ8: PIIX SMIEN b3 (PIIX:2198), ESC (ESC:2248).
- VIA ELCR: ports 4D0h/4D1h are ignored unless 47h b5 = 1 (default 0); PCI IRQ polarity in 54h
  (586B:2057-2059, 2142-2149). Interrupt controller shadow registers make 20h/21h readable when
  47h b4 = 1 (586B:2060-2062, 1325-1330).

IRQ 7 spurious (card is on IRQ 7): a request that drops before INTA gives a default IRQ7 with
the ISR bit clear; read ISR (OCW3 0Bh) to tell it from a real one, and track nesting
(PIIX:5459-5468, PIIX4:10694-10700, SIOZB:4858-4864, SIO93:8352-8358).
ELCR: 4D0h b7 = IRQ7 level mode; ISA cards need edge (0). Switching a line from level to edge
creates a false interrupt; mask, write ELCR, then clear (ESC:4246-4255).

8237 extensions:
- High page registers 481h-48Bh: SIO (8 bits, 32-bit DMA), SIO.A (3 bits); writing the low page
  or current address zeroes the high page (SIOZB:1538-1550, 3119-3175). ALi needs 42h b6 = 1
  to use them (1523:1266, 3770, 1543:3050-3053). PIIX/PIIX3/PIIX4 are 24-bit only (PIIX:4794,
  PIIX4:9582).
- Extended mode 40Bh/4D6h: SIO, ESC, ALi (section 1). Write only on SIO and ESC.
- Readable base registers: SiS 5597 6Ch b1 (5597:8627).
- 90h-9Fh aliasing of DMA page registers: PIIX IORT b7, SIO PCICON b6 (PIIX:1678-1690,
  SIOZB:1725-1731).
- Default DMA wait state 1 and DMAMEMR# one clock late: 82C206 idx 01h b1 (206:1358-1360).

## 4. Recommendations for uCDD

Corrections to the current PIIX handling (fast-dma branch, src/audio/standby.asm
fast_dma_set):
1. PIIX4 7110h: keep. The write is right per PIIX4:3650-3667. No change needed.
2. PIIX 122Eh: b3 is DMC (PIIX:2010-2020). Preserving b3 from a byte that reads 04h (default in
   PBOOK:31311) or from a BIOS that routed a motherboard device would steer MDRQ0 onto the card
   channel and mask its ISA DREQ/DACK. Infer, recommended write on 122Eh only:
   `88h | channel` (FAST + DMC). Before that, if old b3 = 0 and old b2:0 != 100b, MBDMA0 is in
   use by a motherboard device: try 77h, else skip.
3. All three: if the old byte already has FAST = 1 for another channel, use the other MBDMA
   register rather than overwrite (Doc allows two, PIIX:4791-4792). Infer.
4. PIIX 122Eh: clear FAST before any DMA write (recording) on that channel (PIIX:4843-4844).
5. All three: the ring must be in memory forwarded to PCI; below 512K is safe, 512K-640K needs
   TOM 69h b1 = 1 (PIIX:1801-1840, 4825-4828). The current modes 48h/58h (single, increment,
   read) meet the Type F rules (PIIX:4836-4841).

Candidates, ranked by confidence (all Infer about safety; registers are Doc):
1. Intel 82378/82378ZB SIO, 8086:0484 (fn 0, class 0601). Fast mode is documented for ISA DMA
   devices; Type F is 3 SYSCLK but "mainly for fast I/O devices (i.e. IDE)" (SIO93:6537-6539),
   Type A is 6 SYSCLK and "most ISA DMA devices should be able to use" it (SIO93:3688-3695).
   Write, 8-bit channel c: `out 40Bh, 30h | c` (F) or `10h | c` (A); 16-bit: `out 4D6h,
   34h | (c-4)` (F) or `14h | (c-4)`. Restore `00h | c` / `04h | (c-4)` (the reset defaults,
   SIO93:3637-3656). DCEM is write only, so the BIOS value cannot be saved; assume defaults.
   Exclude 82379AB SIO.A (same DID; compatible only, SIOZB:4530): it shares 0484h, so check the
   revision ID or accept that its writes are ignored. Infer: offer Type A first on the SIO.
2. ALi M1523B 10B9:1523 and M1543C 10B9:1533 (fn 0). Write `out 40Bh, 30h | c` or
   `out 4D6h, 30h | (c-4)` (b3:2 reserved 00 on ALi, 1523:3735, 1543:8952). Restore
   `00h | (c & 3)`. Readability not stated; treat as write only.
3. VIA 1106:0586/0596/0686/8231 (fn 0). Read cfg 45h, set bit c (c <= 3) or bit c-1 (c >= 5),
   restore the saved byte. Do not touch 41h b3 (global). Caveat: 686B describes the bit as a
   per-channel 8 MHz DMA clock, not Intel Type F (686B:3177-3187), so the gain is about 2x, not
   2.7x; the ESS must tolerate a 2x faster 8237 cycle.
4. SiS 5597/5598/5582, 1039:0008 rev 01h. Only if cfg 70h b7 is already 1: 71h |= bit c
   (bit 4 reserved). Same DID as SiS 5595 (rev B0h, 71h reserved, 5595:5986) and SiS 630 LPC,
   so gate on revision ID 01h or on host bridge 1039:5597. Low confidence: the sheet gives no
   timing for SiS Type F.
5. ESC 82374EB/SB (EISA, behind PCEB): Type A/B via 40Bh/4D6h (`10h | c`, `20h | c`); never
   11b (EISA burst only, EISA:3789-3792). Low priority for this hardware class.
6. Not recommended at runtime: global DMA clock bits (82C206-family idx 01h b0, SiS 47h b0,
   M1487 29h b3, VIA 41h b3, VT82C496G Rx10 b6). They change floppy DMA too and the non-PCI
   ones have no ID to detect (22h/23h is also Cyrix CPU configuration space; Infer).

Not candidates: PIIX4 internals beyond 76h (fixed SYSCLK), 82380AB MISA, 82371MX MPIIX,
82379AB, SiS 5595, SiS 630, OPTi Viper 82C578 (no DMA timing in the guide).
