# uCDD reference library: text copies

This branch holds plain-text copies of the reference documents used to
develop uCDD: data sheets, specifications and Ralf Brown's Interrupt List.
It shares no history with the code branches and is never merged into them.

The original PDFs are in the `References.zip` asset of the
[references release](https://github.com/EarBoye/uCDD/releases/tag/references).
The folders here mirror the folders in that zip, and each `.txt` file has the
name of its PDF. Text was extracted with `pdftotext -layout`, so tables keep
their columns but figures are lost. Check a register table against the PDF
before relying on a detail.

To read a document without checking out the branch:

    git fetch origin references
    git show "origin/references:Sound Cards/ESS AudioDrive/DS1878A.txt"

## What the library covers

uCDD emulates a CD-ROM drive from disc images and mixes CD audio into a
virtual ISA sound card, running beside Jemm with its own DPMI host. The
documents kept are the ones that bear on that:

- **Sound Cards**: the Sound Blaster family, the ESS AudioDrive chips, the
  Windows Sound System codecs, the AWE32 synthesizer, and the FM chips.
- **Reference parts and specs**: the 8237 DMA and 8259 interrupt
  controllers, the 82C206 (DMA, interrupt controller, timer and RTC in one
  part), Intel's peripheral data books, EISA, and the i386 reference.
- **Chipsets**: the south bridges and PC/AT chipsets that hold the ISA bus,
  its DMA timing (Type F and others) and the RTC, from the 386 to the
  Pentium III.
- **Memory managers and DOS extenders**: DPMI 0.9 and 1.0, VCPI, XMS, EMS
  (LIM 4.0) and Jemm.
- **CD-ROM**: ISO 9660 (ECMA-119), MSCDEX and SHSUCDX.
- **Ralf Brown's Interrupt List**: release 61, its interrupt, port, CMOS,
  memory and MSR lists. The viewers and tools from the zips are left out.

## Left out of the text set

Three PDFs have no text layer and were discarded: the UMC UM82C380 series,
the Headland HT12, and the OPTi 82C895 power management controller.

These are host bridges, memory and cache controllers with no ISA, DMA,
interrupt controller or RTC content. Their PDFs remain in the release zip
but have no text copy here:

- Chipsets/386/290143-004_82385_386_cache_198911.pdf
- Chipsets/386/82C391_82C392_OPTi-386WB_PC_AT_Chipset_199012.pdf
- Chipsets/486/82C497_OPTi-DXBB_199201.pdf
- Chipsets/486/82C822_VESA_to_PCI_Apr94.pdf
- Chipsets/486/VT82C505_VL-PCI_Bridge_199405.pdf
- Chipsets/Athlon/AMD-750.PDF
- Chipsets/Athlon/VT8363A_KT133_Athlon_North_Bridge_200010.pdf
- Chipsets/P6/290523-001_450KX_GX.pdf
- Chipsets/P6/290549-001_440FX_PCIset_82441FX_82442FX_Prelim_199605.pdf
- Chipsets/P6/290564-002_82443LX_199801.pdf
- Chipsets/P6/290566-001_82093AA_199605.pdf
- Chipsets/P6/290616-001_82443EX_199804.pdf
- Chipsets/P6/290633-001_82443BX_199804.pdf
- Chipsets/P6/290638-001_82443GX_199806.pdf
- Chipsets/P6/290650-001_82443ZX_199811.pdf
- Chipsets/P6/M1621_Aladdin_Pro_II_North_Bridge.pdf
- Chipsets/P6/SiS-600_Pentium_II_PCI_AGP_199901.pdf
- Chipsets/P6/VT82C691_Apollo_Pro_199807.pdf
- Chipsets/P6/VT82C693A_Apollo_Pro133_199907.pdf
- Chipsets/P6/VT82C693_Apollo_Pro-Plus_199812.pdf
- Chipsets/P6/VT8601A_Apollo_PLE133_North_Bridge_200110.pdf
- Chipsets/Pentium/290518-002_82430FX_82437FX_82438FX_PCIset_DATASHEET_199612.pdf
- Chipsets/Pentium/290559-001_INTEL_430TX_PCISET_82439TX_SYSTEM_CONTROLLER_MTXC_199702.pdf
- Chipsets/Pentium/82434LX.PDF
- Chipsets/Pentium/M1521_Aladdin_III_199611.pdf
- Chipsets/Pentium/M1531B_Aladdin_IV_199705.pdf
- Chipsets/Pentium/M1541_M1542_Aladdin_V_Socket_7_North_Bridge.pdf
- Chipsets/Pentium/VT82C580VPX_Apollo_VPX_199701.pdf
- Chipsets/Pentium/VT82C595_Apollo_VP2_199701.pdf
- Chipsets/Pentium/VT82C598MPV_Apollo_MPV3_199807.pdf

The Intel 430HX system controller (`29055102`) is kept although it is a host
bridge, because it is the development PC's chipset.

Duplicates were removed by content: the Sound Blaster Series Hardware
Programming Guide was present three times (once under a Creative SB0350
manual page), the Developer Kit reference five times, and the 1996 Intel
Peripheral Components book twice. Two same-titled pairs differ and are both
kept: the PIIX and PIIX3 data sheet (the preliminary Intel issue and a later
one with more on Type F DMA), and two revisions of the ES1869 data sheet.
