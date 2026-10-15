# The virtual ESS's FIFO and DAC model

Status: design for branch `ess-registers`, 15 Oct 2026. Layer C of
docs/spec-first.md (spec-first branch).

## What the chip does

From the ES1868 data sheet (reference-library, `Sound Cards/ESS AudioDrive/
ESS_ES1868_Data_Sheet_1996.txt`) and the ES1868F on the development PC
(F2TEST and ESSSTAT, 15 Oct 2026; context/report_es1868_conformance.md on
the development machine):

- **The FIFO.** In Extended Mode "a 256-byte FIFO is used as an intermediary
  between the ISA bus and the ADC and DAC" (Extended Mode Description).
- **The DMA counter.** It "will be incremented after each successful byte is
  transferred via DMA". It reloads from A4h/A5h at each overflow, and each
  overflow requests an interrupt when B1h bit 6 is set. In Normal Mode
  (single-cycle) DMA stops at the overflow until bit 0 of B8h is cleared and
  set again (A4h/A5h descriptions). So the block interrupt comes when the
  block's last byte enters the FIFO, not when it plays.
  - Measured: 1024 bytes at A1h=6Eh (22094 Hz) interrupt after 34.78 ms
    mono and 17.41 ms stereo. The model, (1024 - 256) bytes at the frame
    rate, gives 34.76 and 17.38.
- **The DMA count a game reads** is the bytes transferred, so it runs up to
  256 bytes ahead of the DAC. A game may rewrite anything behind it: those
  bytes are already in the FIFO.
- **Status, port 2xCh** (port table, 2xCh read):

  | Bit | Meaning |
  |---|---|
  | 7 | Busy |
  | 6 | Same as 2xEh bit 7 |
  | 5 | FIFO full (256 bytes) |
  | 4 | FIFO empty |
  | 3 | Half-empty (0 to 127 bytes, DAC direction) |
  | 2 | Processor interrupt (F2h, Compatibility Mode DMA complete) |
  | 1 | Half-empty-change interrupt (programmed I/O) |
  | 0 | DMA counter overflow interrupt |

  "A read from port 2xEh will reset any IRQ request."
  - Measured: 18h at rest. At a block interrupt 01h, or 09h below half.
    At an F2h interrupt 1Ch. A 2xEh read returns these low bits, with bit 7
    as data available, and clears bits 0 and 2.
- **Filling.** Measured: after B8h bit 0 is set, the FIFO reaches half at
  about 0.5 ms and full at about 0.96 ms (single transfer type, B9h=0):
  about 267 bytes per millisecond. After that the full flag drops for a
  byte or two and refills as the DAC takes samples.
- **Consumption.** The DAC takes one frame per sample clock (A1h).
  - The frame size follows B7h bit 3 (stereo) and bit 2 (16-bit). Measured:
    the block time follows B7h, and a disagreeing A8h changes nothing.
  - The DAC runs on between single-cycle blocks while the FIFO holds data.
    If the FIFO runs dry the stream underruns.

## The model

1. **Virtual DMA.** At each service the virtual DMA moves game bytes into a
   256-byte FIFO copy:
   - up to 256 bytes ahead of the DAC;
   - within the single-cycle block's end;
   - at no more than the measured fill rate.

   The bytes are copied at that moment, so a game that rewrites its buffer
   behind the reported count changes nothing already in the FIFO, as on
   the chip. Each time the moved count crosses a block boundary, the counter
   overflows. That sets 2xCh bit 0 and, with B1h bit 6, requests the
   interrupt. A single-cycle block's DMA ends there.
2. **Virtual DAC.** It takes one frame per sample-clock tick from the FIFO
   copy into a DAC ring indexed by time, or silence when the FIFO is empty.
   The DAC clock starts at the write that sets B8h bit 0 and runs
   continuously across single-cycle blocks until the FIFO has been empty,
   with no DMA, for longer than the output delay.
3. **Output.** The mixer reads the DAC ring a fixed delay D behind the DAC
   clock, D = two output periods. Everything it reads has been through the
   FIFO already, so it never needs a byte the virtual DMA has not moved.
   - The game's audio reaches the speaker D later than on the bare card:
     1.45 ms at 32 frames, 2.9 ms at 64, 5.8 ms at 128. Michael accepted
     this on 15 Oct 2026.
   - Nothing the game can observe moves: counts, interrupts and status
     follow the DAC clock.
   - Disc audio is not involved.
4. **Pause and DMA enable** (data sheet, Table 10 and the B2h description).
   - D0h pauses the DMA only: the DAC plays out the FIFO. D4h continues the
     DMA from the same counter and block. A paused stream does not time
     out.
   - With B2h bit 6 clear the chip drives no DRQ, so the virtual DMA moves
     nothing (the bytes stay put, no counter overflow, no interrupt).
5. **Service points.** Every trapped access to the card's ports and the DMA
   controller's ports, and every output period interrupt. A game that polls
   sees the exact state. An interrupt is requested at the first service
   after its moment: within one output period (0.73 ms at 32 frames).

## Limits and deviations, recorded

- **The clock step.** The DAC clock uses the mixer's 16.16 step, game rate
  times 65536 over 44100, truncated: under 20 ppm from the programmed rate.
  The chip's crystal is ±50 ppm.
- **Busy.** Bit 7 of 2xCh is not modelled beyond string replies. The chip
  shows busy for 5 to 7 µs after a command (F2TEST "ready").
- **Programmed I/O.** Block transfer through 2xFh and the half-empty-change
  interrupt (bit 1, B1h bit 5) are not modelled; no surveyed driver uses
  them.
- **Recording** is not modelled. Neither is Audio 2.
- **Buffer location.** A DMA buffer above 1 MB (the own host's high source
  path) keeps the previous path, without the model.
- **Fill rate by transfer type.** B9h 1 and 2 are demand transfers of 2 and
  4 bytes per request. The model fills at the rate measured with B9h=0
  (single transfers) for all three. ESSSTAT's B9h blocks measure the chip
  (not yet run on the PC).
- **Period length.** The model is assembled for output periods up to 256
  frames (OUTPUT_SHIFT 8), which keeps its DAC ring at 4 KB.

## Results (86Box, 15 Oct 2026)

- ESSSTAT on the model at 32 and 128 frames, against the ES1868F:

  | | Model | ES1868F |
  |---|---|---|
  | Reset table, B1h/B2h read-backs | Identical | |
  | 2xCh at rest | 18h | 18h |
  | 2xCh, F2h interrupt | 1Ch | 1Ch |
  | 2xCh, block interrupt | 01h, 00h after 2xEh | 01h, 00h after 2xEh |
  | Mono block interrupt (PIT counts) | 41598 to 41648 | 41498, 41458 |
  | Stereo block interrupt (PIT counts) | 20875 to 20917 | 20778, 20727 |
  | FIFO full | about 1.17 ms | 0.96 ms |

- verify-mix (256 frames): 0 bad samples and state in all 9 cases, the
  model's own extended-mode stream with CD audio included.
- SBT16 and SADUMP unchanged on the seven pairings. Doom unchanged.
- Descent 2 (HMI, Extended Mode, A1h=DCh) on the virtual ESS, clicks per
  second:

  | | 128 frames | 32 frames |
  |---|---|---|
  | Physical ESS full rate | 1.3 | 1.3 (the previous build: 7.3) |
  | Physical ESS half rate | 0.9 | 1.1 |
