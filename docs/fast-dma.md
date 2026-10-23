# FASTDMA: the chipset's own fast DMA timing on the output channel

A change from the EarBoye/uCDD fork, on top of Beta 0.9.4-a6, offered for
the author to take if he wants it. This file says what it does, why, and
what was tested. The chipset table and its sources are in
`docs/platform-dma.md`.

This branch builds on two others, which it contains: `feature/disk-irq`
(its PCI scan finds the chipset) and `feature/step-aside` (its engage and
release are where the output starts and stops). The commits after the
merge of the two are the fast DMA change alone.

## Why

The output stream is ISA DMA all the time the driver runs, and in the
default ISA DMA timing each byte holds the bus for about a microsecond. On
a Pentium MMX 233 (430HX, PIIX3) with an ES1868 that cost 9 percent of
memory copy speed at the half rate and 18 percent at the full rate, with no
driver loaded and the card streaming silence. Most PCI chipsets have a
faster timing for an ISA DMA slave, set per channel.

## The change

UCDDSET's "Enable platform fast DMA" asks for the chipset's documented fast
timing on the output channel while the output runs; the old value goes
back when it stops. The install's PCI scan looks the ISA bridge up in a
table (`src/platform.asm`), or finds an EISA machine by its ROM signature:

- Intel PIIX, PIIX3, PIIX4: Type F by the MBDMA register (the original
  PIIX also gets its DMC bit, so the card keeps its DMA lines).
- Intel 82378 SIO and EISA machines: Type A by the extended mode register
  (40Bh, 4D6h).
- ALi M1523, M1533, M1543, M1535; OPTi Viper-M and FireStar: Type F by the
  same register.
- VIA VT82C586, 596, 686, VT8231 and the AMD-756: the doubled DMA clock,
  config register 45h.
- SiS 5597, 5598, 5582: Type F by config register 71h, only while the BIOS
  has 70h bit 7 on.

386 and 486 ISA chipsets have one global DMA clock, which the driver leaves
alone; the AMD-766 and 768 have no ISA DMA. UCDDSET names the chipset under
the Disk row and greys the box where nothing is known or the BIOS has the
timing off.

- `src/platform.asm` (new): the table. `src/disk_scan.asm`: the PCI walk
  looks each bridge up, and EISA by its signature. `src/driver.asm`: the
  install keeps what the scan found.
- `src/audio/standby.asm`: `fast_dma_set` and `fast_dma_clear`, one routine
  pair per method, called at the install, at the removal, and where the
  driver steps aside and engages again.
- UCDDSET: the tick box (row 17), the chipset line (row 18) and a help line
  that says why the box is greyed.
- `UCDD.CFG` version 5: the switch at offset 44 (42 and 43 are the disk
  IRQ and step-aside bytes, the same layout as on those branches). Off by
  default.

## What was tested

On the fork's own line:
- The real PC (ECS P5HX-A, PIIX3, ES1868), Type F set by a standalone tool
  first: the tone unchanged by ear at 22.05 and 44.1 kHz; the memory copy
  loss with the stream running from 9.0 to 0.7 percent at the half rate
  and from 18.0 to 1.5 at the full rate; Doom's timedemo from 1788 to 1613
  realtics and Quake from 19.8 to 22.0 fps with CD music. Then the driver
  option on the same PC: Doom's timedemo the same at 32, 64, 128 and 256
  frames, at the half and the full rate.
- The real PC with a Creative CT2290 (SB16) in place of the ES1868: the
  card accepts Type F.
- 86Box, one board per method (P/I-P54TP4XE, P/I-P55T2P4, AN430TX, Batman,
  M560, CUV4X-LS, SP97-XV, a 386 and a 486): each chipset named right, the
  registers written as the sheets say, the tone the same on every board.
  86Box keeps no DMA timing, so this shows detection and no harm, not the
  speed.
- Only the PIIX3 is proven on hardware. Every other chipset rests on its
  data sheet. One disagreement is written down (platform-dma.md section
  8): 86Box reads bits 3:2 of 40Bh and 4D6h as Intel's transfer size on
  ALi and OPTi, where their sheets call the bits reserved or not
  implemented; the driver follows the sheets.

On this branch (the change ported onto 0.9.4-a6): built at 128 and 32
frames and without resident audio. Not run yet.
