# Specification first: a design proposal

Status: adopted (Michael), updated 15 Oct with the ES1868F measurements.
Was: proposal. Written on `fixes` at 77979b2, with `spec-fixes`,
`setup-layout`, the rig's three branches (`combined-test` 772941d),
`fast-resample` and `event-timer` in view. Sources: the reference library
(branch `reference-library`, notes in `notes/`) and S95Sedan's disassembly
of the CT1741 SB16 DSP firmware.

## 1. The rule

uCDD's purpose is an accurate virtual ISA sound card. CD audio is mixed in
within the margins that accuracy leaves. Every decision follows from that:

1. The platform is to specification, 386 to Pentium III and Athlon: the
   interrupt and DMA controllers the driver emulates, the ones it drives,
   the CPU features it relies on, the memory manager and DPMI interfaces.
2. The virtual Sound Blasters (2.0, Pro, 16) behave as the Creative
   documents and the CT1741 firmware say, at the ports, on the DMA channel,
   on the IRQ line and in time.
3. The virtual ESS behaves as the ESS data sheets say, as its own card, not
   as a Sound Blaster with extras. A game that programs 22097 Hz gets 22097
   Hz.
4. Only then speedups such as Type F DMA, which never change anything a game
   can observe.
5. At all times the documents decide. Where they are silent, the real chip
   decides (measured on Michael's PC), then the firmware, then an emulator.
   An emulator never overrules a document or the hardware.

"Observable" means what a program can see: values read from ports, what
the DMA controller reports and moves, when and how often the IRQ comes,
and what comes out of the speaker relative to what the game wrote. The last
one is the new part: the output is observable, so a resampler that colours
the game's audio is a deviation, not an implementation detail.

## 2. What is already known to deviate

From the library review (`notes/README.md` on `reference-library`) and the
rig's work. Fixed on `spec-fixes` (634ca66): the virtual ESS mixer twins
writing the internal gains, ESS 41h/42h argument counts, non-specific EOI
forms 21h to 27h, F2h dropping a 16-bit request. Fixed on the rig's
branches: the polled DMA count follows the played position, B1h/B2h carry
the IRQ and DMA, the delivered mark on the trap exit. Still open:

| Area | Deviation | Layer |
| --- | --- | --- |
| 8237 | Status read does not clear terminal count; playback never sets it | A |
| 8259 | Poll command answers the request register; other OCW3 forms refused | A |
| DPMI | 0202h returns 0:0 with no handler installed | A |
| DPMI | Software INT 08h to 0Fh, 70h to 77h from protected mode is fatal | A (to check) |
| DPMI | Re-entered real-mode callback terminates the client | A (to check) |
| CPU | JEMMEX VME: trap-exit delivery tests IF, not VIF | A |
| MSCDEX | IOCTL Q-channel and audio status unanswered with a data-only disc | A (to check) |
| DSP | 38h MIDI out refused, its data parsed as a command | B |
| DSP | ADPCM commands absent (16h, 17h, 1Fh, 74h to 7Fh) | B |
| DSP | A single-cycle command during auto-init restarts at once; the guide says at the block end | B |
| DSP | Reading 2xEh does not cancel a request still waiting at the PIC | B |
| Timing | Block-end IRQ from the mix position, not the played position | B |
| Timing | F2h interrupt delivered at once; the ES1868F takes 11.7 to 14.2 us and does not merge two | B and C |
| Mixer | Every index is plain RAM; SB 2.0 has a mixer it should not | B |
| ESS | 2xCh status always 7Fh: FIFO full and empty and data available together | C |
| ESS | No compatibility-mode model: always the extended register set | C |
| Output | Game stream held (zero-order), not band-limited; at half rate pairs averaged across a drifting phase (the Descent 2 wobble) | D |
| Output | No emulation of the card's reconstruction filter (ESS A2h, SB Pro 0Eh) | D |

## 3. Layer A: the platform

**Scope.** What the driver emulates (the master 8259 for the guest IRQ,
both 8237s for the guest channels, the RTC if the event timer is ever
built), what it drives (the physical card, the PIC, the DMA controller, the
PCI BIOS), and what it runs under (Jemm's QPI and IRQ slot, VCPI, XMS, its
own DPMI host).

**Machine range and what changes across it.**

| Generation | What matters to the driver |
| --- | --- |
| 386, AT chipsets (NEAT, OPTi, 82C206 class) | No CPUID, no RDTSC, no PCI. The 82C206 integrates the PICs, DMA, timer and RTC. ISA DMA limited to the first 16 MB and to 64 KB (8-bit) or 128 KB (16-bit) pages. Slow traps: the 386 cost figures in ISSUES |
| 486 | Write-back L1 on later parts: DMA coherence depends on the chipset snooping the bus; the DMA buffer sits in conventional memory below 640 KB, which every chipset in the library snoops or leaves uncached. VLB and early PCI bridges. CPUID on later steppings, with VME on the DX4 and SL parts |
| Pentium (430FX/HX/VX/TX, ALi, SiS, VIA) | PCI BIOS, PIIX-family ISA bridges with Type F, ELCR at 4D0h/4D1h. VME and PVI. TSC |
| P6 and Athlon (440 family, PIIX4, VIA 596/686, ALi M1543, SiS 5595) | The same ISA bridge model; PIIX4 and VIA put the RTC with extended banks in the bridge; some boards route legacy audio DMA through distributed DMA, which ISA cards do not use |

**Method.** A requirement table: one row per documented behaviour the
driver relies on or emulates, with the document and line, the code that
implements it, and the test that shows it. The library notes give the
first draft of the 8259, 8237 and DPMI rows. Each "to check" row in
section 2 is read against the code before it becomes a fix.

**Rules.** The driver uses no instruction the 386 lacks outside the
profiling builds. It touches a chipset register only when the chipset is
identified and its document shows the register. It assumes nothing about
the BIOS's settings that the document gives as a default only.

## 4. Layer B: the virtual Sound Blasters

**Models.** Creative's own: SB 2.0 (DSP 2.01), SB Pro (DSP 3.02), SB16
(DSP 4.05, matching the CT1741 firmware disassembled). The Hardware
Programming Guide and the Developer Kit reference are the documents; the
firmware disassembly settles what they leave open.

**Per model, a conformance table** with every DSP command the model's DSP
version accepts: argument count, reply, effect, interrupt, and what the
other models do with it. From the firmware:

- An invalid command is ignored, with no argument consumed.
- The busy bit at 2xCh and the data-available bit at 2xEh are the
  firmware's state.
- The interrupt is a level held until the acknowledge read.
- PCM DMA is paced by the hardware.
- ADPCM and 80h silence are paced by the firmware.
- E2h, E3h and E4h/E8h are as the firmware computes them.

**Mixer per model.** The SB 2.0 has none, unless the CD-interface variant
(CT1335) is chosen. The SB Pro has the CT1345 with its register set and
read-back. The SB16 has the CT1745, with 80h to 82h and the reserved
registers. Unimplemented indices read as the chip reads them, not as RAM.

**Timing that is part of the spec.**

- The DMA count moves at the programmed rate and is read as the played
  position. Done on the rig's branches.
- The block-end interrupt comes when the count wraps or expires.
- F2h and F3h raise their interrupt after the DSP's latency, not at once.
- Reset takes about 100 us before AAh is readable.
- D1h and D3h take their documented times.

The mechanism is `event-timer` section 0: a short output period, deadlines
checked at every period interrupt and trap exit, and the physical card's
own one-shot for sub-period events.

**Output fidelity.** The game's samples reach the speaker at the rate it
programmed, without colouring by the virtual card. See layer D.

## 5. Layer C: the virtual ESS

**Its own card.** The reference model is the ES1868, which is the
development PC's chip and the best-documented of the family. The
identification is mirrored from the physical chip (E7h, mixer 40h), as
done. The other family members get their documented differences only when
the physical chip is one of them.

**Two modes, as the ES1868 data sheet's Table 8 (and the ES1888 design
guide's Table 2.1.1) define them.** After any reset the chip is in
Compatibility Mode, a Sound Blaster Pro at DSP 3.01:

- A 64-byte firmware FIFO.
- Rates from the 1 MHz (40h) or 1.5 MHz (41h, ESS only) timer.
- Stereo 16-bit DAC only to 11 kHz, mono 16-bit to 22 kHz.
- ±2 us DAC jitter.

Extended Mode is entered through C6h:

- The 256-byte hardware FIFO.
- Rates from 795.5 kHz or 397.7 kHz, through A1h.
- FIFO status flags at 2xCh, signed and unsigned control, the A0h to BFh
  registers.
- No jitter.

The virtual ESS models both. In Compatibility Mode it is the SB Pro model
with the ESS's own commands and limits (41h, 42h, the Table 8 maxima). In
Extended Mode it is the register set with the sheet's reset values.

**Exact rates.** The virtual card runs at what the game programs. In
Extended Mode that is 397.7 kHz/(128-X) with A1h bit 7 clear and 795.5
kHz/(256-X) with it set (ES1868 data sheet, "Extended Mode Sample Rate
Generator"). In Compatibility Mode it is 1 MHz/(256-X) for 40h and 1.5
MHz/(256-X) for 41h. The game's A2h sets the filter roll-off, which the
sheet puts at 80 to 90 percent of half the sample rate (filter clock 7.16
MHz/(256-X), roll-off a 82nd of it). The game's A2h sets the emulated
reconstruction filter (layer D). A Descent 2 stream at A1h=DCh plays at 22097 Hz, and its DMA
consumption and interrupts follow 22097 Hz. That is already true of the
consumption (the rig found it). What is not true is the output, which
resamples it; layer D fixes that.

**BAh clock trim** is the physical driver's business. The virtual BAh
reads and stores as the sheet says. Its bit 6 changes the virtual card's
clock only if a game sets it, which no surveyed driver does.

**Measured on the ES1868F** (F2TEST and ESSSTAT on the development PC,
JEMM boot after UNISOUND, 15 Oct; the chip reads FFh everywhere without
UNISOUND, so there is no power-on reference). Where 86Box differs, the chip
decides:

- F2h raises its interrupt 11.7 to 14.2 us after the command. Two F2h
  back to back give two interrupts, every time: the chip does not merge
  them (86Box does). With the first unacknowledged, a second F2h raises
  nothing (done on `dsp-irq-level`). The Miles test (ADRV688, AUDIODRV)
  needs its counter to pass through 1 between the two interrupts, so the
  requirement is the latency, serialised, not merging.
- 2xCh reads 18h idle (bit 4 FIFO empty, bit 3 half-empty), not 00h
  (86Box) or 7Fh (the virtual ESS). During a block the full, empty and
  half-empty bits follow the FIFO. At a block interrupt it reads 01h, or 09h
  below half; at an F2h interrupt 1Ch. The 2xEh read clears bits 0 and 2,
  and its own value is those low bits (01h, 09h, 1Ch), not 7Fh.
- B1h and B2h read 1Ah after UNISOUND. Bits 3:0 are read-only and hold the
  data sheet's code, the same two bits in 3:2 and 1:0: IRQ 2/9 0000, 5
  0101, 7 1010, 10 1111; DMA 0 0101, 1 1010, 3 1111. Written 5Ah, DAh, 50h:
  B1h reads 5Ah each time (bit 7 cannot be set), B2h 5Ah, DAh, 5Ah. The
  virtual ESS's reset value (50h plus 1000 for IRQ 7) and its writable low
  bits are both wrong.
- The extended-mode block interrupt comes when the block's last byte
  enters the 256-byte FIFO: 1024 bytes at 22094 Hz interrupt after 34.78
  ms mono (model (1024-256)/22094 = 34.76) and 17.41 ms stereo (17.38).
  86Box raises it at the end of play.
- The FIFO's consumption follows B7h bit 3; a disagreeing A8h makes no
  difference to the timing. A8h bits 1:0 set the converters' mode
  (ES1869 sheet) and are stored and read back.

**From the data sheets** (ES1868, with the ES1869 for the registers the
ES1868 sheet does not describe):

- A reset sets the timer divider and filter for 8 kHz and the DMA counters
  to 2048 bytes; the virtual ESS leaves A1h and A2h at 00h.
- The ES1868 ignores the SB Pro filter bits in 0Ch and 0Eh; in
  Compatibility Mode the filter follows 40h, 41h or 42h.
- 14h, 32h, 36h, 38h and 3Eh are the 8-bit extended access of 04h, 22h,
  26h, 28h and 2Eh, and 1Ch of 0Ch. Reads of the SB Pro registers return
  bits 0 and 4 set; 0Ch bit 0 reads 1 and is cleared on write. 3Ah and 3Ch
  are not in the ES1868 sheet.
- BAh is the sample-rate adjust on the ES1868 and the left ADC offset on
  the ES1869: the virtual BAh follows the mirrored chip.

**What the ESS drivers use** (DOSBox-X port logs for HMI and Miles, a
static listing for ADRV688 and ESFM; register by register, the order in
which layer C is proven):

| Driver (games) | Detection | Set-up and play | Mixer and other ports |
| --- | --- | --- | --- |
| HMI SOS (62) | Reset, C6h | B8h 04h, 00h, 05h; A8h 01h; B6h 80h; B7h 51h then 98h; B2h DAh; A1h DCh (22097 Hz); A4h/A5h -4096; D1h. Reads back A8h and B2h | None |
| ADRV688.DIG, AIL 3.0 (52) | Reset, C6h, E7h, F2h three times (the interrupt counter test), E2h AAh twice | B8h 04h; A8h bits 1:0 (01b stereo, 10b mono); B6h and B7h from a four-format table (80/51/D0, 00/71/F4, 80/51/98, 00/71/BC); B1h and B2h read-modify-write keeping bits 3:0, OR 50h; A1h from 795.5 kHz above 23000 Hz, 397.7 kHz below; A2h from a table or the rate; D3h, D1h; B8h OR 05h to start | None |
| ESFM.MDI, AIL 3.0 (21) | Reads 388h and the DSP ports, resets through 2x6h | ESFM native mode: 2x7h pulse 20h then 00h (FM reset), index 105h = 80h through 38Ah/38Bh, then 16-bit register indices | Mixer 36h read, saved, written 88h, set from the MIDI master volume, restored at exit |
| AUDIODRV.DIG, AIL 4 (16) | C6h, E7h, F2h four times, E2h AAh twice | C6h; B8h 04h; A8h 01h; A1h 6Eh (22094 Hz); A2h F7h; A4h/A5h -2048; B6h 00h; B7h 71h then BCh; B1h and B2h 5Ah after reading them; B8h 05h; D1h; D3h | Mixer 14h and 36h 88h after reading them; 2x7h 20h then 00h; 2xCh polled about two thousand times |

So the virtual ESS needs, in this order:

1. B1h and B2h: the chip's code in read-only bits 3:0, B1h bit 7 clear;
   A1h and A2h reset to 8 kHz.
2. 2xCh and 2xEh as measured: FIFO state, the three interrupt source bits,
   the 2xEh value.
3. The extended-mode block interrupt when the last byte enters the FIFO.
4. The F2h interrupt after its latency (about 13 us), serialised.
5. A1h's two clock ranges and A2h, which also feeds layer D's filter.
6. Consumption from B7h bit 3; A8h stored and read back.
7. Mixer 14h and 36h with read-back, and the SB Pro read-back bits.

FM (ESFM native mode, 2x7h) passes through to the physical chip and is
its business.

**What the sheet says that the virtual ESS must add:**

- 2xCh status: busy, FIFO full, FIFO empty, half-empty, and the three
  interrupt source bits (2, 1, 0) from the real state, not a constant.
- Extended-mode interrupt timing: the block interrupt when the block's
  last byte enters the FIFO, which is up to 256 bytes before it plays. The
  DMA count is then FIFO-ahead of the speaker exactly as on the chip.
- FIFO half-empty interrupts for programmed I/O, if B1h bit 5 asks for
  them.
- The ESS mixer layout (14h, 1Ah, 1Ch, 32h, 36h, 38h, 3Ah, 3Ch, 3Eh, 40h,
  and the 70h to 7Fh extension registers) with read-back as the chip does
  it. Audio 2, the second DMA channel, is declared unmodelled until a game
  needs it.

## 6. Layer D: the output, where CD audio lives

**The model of the period hardware.** A game's samples reached the speaker
through the card's DAC at the rate the game programmed, then the card's own
reconstruction filter, then the analog mixer. Disc audio reached the same
mixer by the drive's analog cable at full bandwidth, whatever the DAC was
doing. uCDD mixes digitally, which already departs from that; the design
keeps the departure invisible to the game and as small as possible to the
ear.

**The design: emulate the card's DAC, at a fixed output rate.**

- The physical card plays at 44100 Hz (the trimmed ESS, the SB16, the
  WSS codec), the disc's own rate. Disc audio is never resampled on a
  card that can play 44100 Hz, as on the cable. That is the case on the
  development PC.
- The game's stream is upsampled from its programmed rate to 44100 Hz by
  a band-limited interpolator (a polyphase FIR) whose cutoff is the
  emulated card's reconstruction filter. The game itself names both
  parameters:
  - On the ESS in Extended Mode the rate comes from A1h and the roll-off
    from A2h. The data sheet puts it at 80 to 90 percent of half the
    sample rate, from a filter clock of 7.16 MHz/(256-X) with the
    roll-off at a 82nd of it.
  - On the SB Pro the filter follows the time constant and mixer 0Eh's
    filter switch. The ESS in Compatibility Mode ignores 0Eh: its filter
    follows 40h, 41h or 42h.
  - On the SB16 it follows the rate. No document in the library says
    so: to be measured, or marked firmware-derived.
  Upsampling loses nothing, so the game's audio comes out as the real
  card would have played it, which is the emulation the spec asks for.
- Timing is unchanged and already exact. The game's samples are consumed,
  counted and interrupted at its programmed rate: 22097 Hz is 22097 Hz to
  the game.
- A rate change is the game's own business and changes only the
  interpolator's step and filter. The physical output never restarts, and
  disc audio never moves.

**Why not passthrough** (the first draft of this section played the
physical card at the game's rate):

- *It would put disc audio through the game's rate.* A game firing 11 kHz
  sound effects would drag the music down to 11 kHz bandwidth, and even
  at 22 kHz the ESS's own filter would cut the disc above about 9 kHz.
  On the hardware the cable never met the DAC.
- *Every rate change would restart the physical output.* An ESS start
  takes 0.66 ms, with the first interrupt 1.25 ms after the call
  (ISSUES.md). Older games play each effect as its own single-cycle block
  with its own time constant.

**What it replaces.**

- The held game samples, a zero-order hold, which colour the output with
  images and with a beat whenever the rate is not a divisor of the
  output.
- The half-rate pair average, the source of the Descent 2 wobble.
- `fast-resample` is not merged.

**Cost.** An 8 to 16-tap polyphase filter on the game's stream, only while
a game stream plays: an estimated 2 to 4 percent of a Pentium 233, to be
measured. Disc audio alone costs nothing new.

**The slow-machine mode** (a 386 is best effort, as the author always
said):
- The game's stream keeps its rate and timing, with linear interpolation
  in place of the filter.
- The disc may play at 22050 Hz output.
- It costs the guest stream and the filter quality, never the virtual
  card's behaviour.

**Read-ahead within the hardware's margin.** Two periods of read-ahead
must not exceed what the emulated card buffers:

| Card | Buffer | Read-ahead allowed |
| --- | --- | --- |
| SB16 | A few samples | Small |
| ESS, Compatibility Mode | 64 bytes | Small |
| ESS, Extended Mode | 256 bytes | At most 256 bytes |

On the Pentium a 32 or 64-frame period costs nothing measurable. The
32-frame click the rig found must be solved, not avoided. The
interpolator adds its own delay, half its length (4 to 8 output frames),
which counts toward the same margin.

**What carries over.** `event-timer` section 0 (the short period and the
physical card's own one-shots) remains the timing mechanism for layers B
and C.

## 7. Layer E: speedups, last

Type F (`fast-dma`, `setup-layout`), other chipsets' fast DMA modes (the
82378 SIO, ALi, VIA and SiS rows in `notes/chipsets.md`), and VME. Rules:
detect-only, off by default, and never a change a game can observe. Each
one gets a measured cost and a regression showing the virtual card's
observable behaviour identical with it on and off.

## 8. Process

1. A conformance matrix per layer, in `docs/conformance/`: requirement,
   document and line, code, test, status. A row without a document line is
   marked as hardware-measured or firmware-derived, with the evidence.
2. Conformance tests, on the rig and the PC. Existing: SBT16, SADUMP,
   E2TEST, E41TEST, TONE4, verify-mix. To add:
   - F2TEST: latency and merging (written; ES1868F measured).
   - A DSP command sweep per model, compared with a bare card on the PC.
   - An ESS status sweep: 2xCh through a block (ESSSTAT, written;
     ES1868F measured).
   - A mixer read-back sweep per model.
   - An output transparency test: a known game stream captured digitally
     in 86Box and compared sample for sample, and on the PC by spectrum.
3. Every deviation that stays gets a row in ISSUES under "Deviations from
   specification", with the reason.
4. Order: layer A's open rows, layer B's table, layer C's two modes, layer
   D's DAC emulation, then layer E. A layer is done when its matrix has no
   open row without a recorded reason.

## 9. Branch disposition under this proposal

| Branch | State | Proposal |
| --- | --- | --- |
| `spec-fixes` | Spec corrections, regression clean | Merge into `fixes` now |
| `ess-position`, `miles-irq`, `virtual-timing` | Spec corrections (count timing, B1h/B2h, IRQ delivery) | Merge into `fixes` now, after `spec-fixes` |
| `fast-dma`, `setup-layout` | Layer E (Type F), plus the UCDDSET layout | Hold until A to C, as asked; or merge now as off by default, since Type F changes nothing observable and the UCDDSET layout is not a speedup. Michael's call |
| `fast-resample` | Interim layer D fix, passed in 86Box | Not merged: layer D's DAC emulation replaces it |
| `event-timer` | Timing design | Keep; section 0 feeds layers B and C |

## 10. Questions for Michael

1. Answered: DAC emulation at a fixed output rate, not passthrough
   (sections 6 and 11).
2. The ESS's reference model: the ES1868 with the family's differences
   only as needed, or one model per chip from the start?
3. Answered: merged (section 11).
4. Answered: retired, with a slow-machine mode that costs only the guest
   stream (section 11).

## 11. Decisions (Michael, after the proposal)

1. CD audio follows the period hardware: on an ESS or Sound Blaster card of
   the time, disc audio never passed through the DAC. The drive's analog
   output went by cable to the card's CD input and was mixed in the analog
   mixer, under the mixer's CD volume (38h on the ESS, 28h on the SB Pro,
   36h/37h on the SB16). The game set only that volume and the MSCDEX play
   commands; the DAC's rate never touched the disc audio. So the virtual
   card's rate is the game's, and the CD stream is the guest that adapts to
   it, continuously across any rate change: this is why layer D emulates the DAC at a fixed output rate: the disc
   never meets the game's rate.
2. ESS behaviour is guided by what ESS games expect: the eleven ESS driver
   binaries in the 147 ESS-aware games of the survey (HMI's five variants
   in 62 games, ADRV688.DIG in 52, ESFM.MDI in 21, AUDIODRV.DIG's two in
   16) set the order in which layer C's registers and behaviours are
   proven, each against the data sheet.
3. `fast-dma` and `setup-layout` are merged into `fixes` (fcf67f2, with
   `spec-fixes` and the rig's three branches).
4. Fast mode as a physical output mode is retired: it keeps the ESS out of
   spec (every game rate resampled to 22050 Hz and pair-averaged). Layer D
   emulates the card's DAC instead (section 6), and passthrough is dropped
   for the two reasons given there. `fast-resample` is not merged.
5. A slow-machine mode stays, on one condition: it may cost the CD stream
   (disc audio at 22050 Hz, the guest) and the filter's quality (linear
   interpolation), but never the virtual card's behaviour.
6. The game comes first, always. A game expects to talk to a card in a
   specific way and to get specific results; it does not know the CD is
   being mixed. Mixing the disc digitally is itself a departure from the
   period hardware (the analog cable to the mixer), so its cost, in CPU,
   bus time and anything audible, is kept as small as possible and never
   paid by the game.
7. Chipset speedups (layer E) are extended beyond the PIIX family to the
   other bridges in `notes/chipsets.md` on `reference-library`. If space
   in the resident driver becomes a concern, Intel first: the PIIX family
   (done), then the 82378 SIO. Then ALi (M1523B, M1543C), VIA (586, 596,
   686, 8231: a doubled DMA clock rather than Type F), and SiS (5597,
   5598, 5582, with the 5595 revision check). Each one detect-only, off by
   default, cited to its data sheet, and proven to change nothing a game
   can observe. A chipset nobody here owns is built to its data sheet and
   shipped; reports from its owners correct it.
8. Every deviation in section 2 is fixed, whether or not it changes the
   sound. Evidence from the ESS drivers and the game set decides the
   order, never whether.

## 12. The mantra (16 Oct 2026)

Agreed with Michael after a review; it replaces the three principles of
15 Oct. When the rules conflict, rule 5 sets the order.

1. **The specification and reference documents are mother and father.**
   They are holy; compliance is our goal.
   - We check them at the start of each step, when a bug is found, and
     after regression testing.
   - Where the documents are silent or contradict each other, emulation
     decides first, then the real hardware we have.
   - That hardware is one sample, not the whole family. Every disagreement
     between documents, emulators and hardware is written down.
2. **We are platform and hardware agnostic.**
   - The driver works from a 386 to an Athlon or Pentium III; the 386 is
     best effort.
   - We use the references to make sure, emulators to confirm, and real
     hardware to prove it where we have it.
3. **We aim for accurate CD audio output and mix in game audio.** We only
   accept downsampling CD audio if the selected physical card is incapable,
   or the CPU cannot keep up within the 16 ms ceiling (rule 5), and we
   record which.
4. **Performance is the crown we earn.** If the specification allows it,
   we reach for it.
5. **When rules conflict, the order is: specification, then working on
   every platform, then accurate audio, then performance.**
   - Added latency never exceeds 16 ms.
   - Within that ceiling, a system that cannot keep up may get a longer
     period, downsampled audio or another allowance, and we record why.
6. **The ESS family and the Sound Blaster family are separate entities.**
   - We do not build one as the other and correct it from there.
   - In compatibility mode the ESS follows the ESS data sheets' description
     of its Sound Blaster compatibility, not Creative's documents.
   - The ESS work follows the ESS sheets as a family. The virtual card
     follows the model it presents, and the physical path handles every
     model we have a sheet for.
   - Consequence for layer C: the virtual ESS's command set is to be built
     from the ESS sheets' command tables, not from the SB Pro parser with
     the ESS commands in front of it, as it is now.
7. **We write meticulous notes, for us and for others who may find them.**
   - When we find a bug, we write it down. When we find the answer, we
     write it beside it.
   - The fork's limits stay: no game files, nothing to the original author
     without Michael's say-so, no test-bench nicknames.
8. **Every result carries its evidence grade:** data sheet, emulator, or
   hardware.
9. **We write beautiful, efficient, well-commented code for humans to
   read.**
