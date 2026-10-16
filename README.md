# uCDD reference library: text copies

This branch holds plain-text copies of the reference documents used to
develop uCDD: data sheets, specifications and Ralf Brown's Interrupt List.
It shares no history with the code branches and is never merged into them.

The original PDFs are in the `References.zip` asset of the
[references release](https://github.com/EarBoye/uCDD/releases/tag/references),
except four that are not in that zip and are kept here beside their text:
the CS4231A and CS4232 data sheets, the later PIIX and PIIX3 data sheet, and
the second ES1869 revision. Jemm's QPI description is plain text already.
The folders here mirror the folders in that zip, and each `.txt` file has the
name of its PDF. Text was extracted with `pdftotext -layout`, so tables keep
their columns but figures are lost. Check a register table against the PDF
before relying on a detail.

To read a document without checking out the branch:

    git fetch origin reference-library
    git show "origin/reference-library:Sound Cards/ESS AudioDrive/DS1878A.txt"

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

## Added 17 October 2026

Found for the platform fast DMA work (uCDD docs/platform-dma.md). The
`references` release the paragraph above names is no longer on the fork
(only its tag is), so these PDFs are kept here beside their text. The Viper-M
book is a scan with no text layer: its text is Tesseract OCR at 300 dpi,
one form feed a page, so check a register table against the PDF.

| File | Source |
|---|---|
| Chipsets/Athlon/AMD-756_Peripheral_Bus_Controller_22548B_199908 | [The Retro Web](https://theretroweb.com/chip/documentation/014-00142-0-amd-756-64e7d9ee7067e716162188.pdf) |
| Chipsets/Athlon/AMD-756_Revision_Guide_22591C_200005 | [The Retro Web](https://theretroweb.com/chip/documentation/22591-64e7d8590ed64465091296.pdf) |
| Chipsets/Athlon/AMD-750_Chipset_Overview_23016A_199908 | [Datasheet Archive](https://datasheet.datasheetarchive.com/originals/distributors/Datasheets-1/DSA-5236.pdf) |
| Chipsets/Athlon/AMD-766_Peripheral_Bus_Controller_23167B_200103 | [Datasheet Archive](https://datasheet.datasheetarchive.com/originals/distributors/Datasheets-1/DSA-3430.pdf) |
| Chipsets/Athlon/AMD-768_Peripheral_Bus_Controller_24467B_200110 | [o3one.org](http://www.o3one.org/hwdocs/amd_chipset/amd_768_24467.pdf) |
| Chipsets/Pentium/82C700_Firestar_Single-Chip_Notebook_Solution_199702 | [bitsavers](https://www.bitsavers.org/components/opti/dataSheets/82C700_Firestar_Single-Chip_Notebook_Solution_199702.pdf); OPTi's own FireStar ACPI edition is [pd015_10.pdf](http://www.opti-inc.com/ftp_file/pd015_10.pdf) |
| Chipsets/Pentium/82C556M_82C557M_82C558M_Viper-M_Preliminary_Data_Book_199504 | [The Retro Web](https://theretroweb.com/chipset/documentation/optiviperm-6455103be0209487111887-64557edc702b7863333286.pdf) (no data book found for the desktop Viper 82C556/557/558) |
| Chipsets/Pentium/M1533_PCI_to_ISA_Bus_Bridge_v1.56_199811 | [The Retro Web](https://theretroweb.com/chip/documentation/1533ds156-644fcae05e871456058266.pdf) |
| Chipsets/P6/M1535_South_Bridge_Product_Brief | [The Retro Web](https://theretroweb.com/chip/documentation/m1535dm-web-6454b1719884a427856813.pdf) (a 4-page brief; no full M1535 data sheet found) |
| Chipsets/P6/M1535D+_South_Bridge_Product_Brief | [The Retro Web](https://theretroweb.com/chip/documentation/1535pbdp1-663b952451301009019133.pdf) |
| Chipsets/486/UM8881_UM8886_HB4_Reverse_Engineered_20260216 | [The Retro Web](https://theretroweb.com/chip/documentation/umc-chipset-2026-02-16-69b1cf47a753d286286159.pdf), from the [VOGONS thread](https://www.vogons.org/viewtopic.php?t=68829) (UMC never published one) |

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
