# Specification first: a design proposal

Status: proposal. Written on `fixes` at 77979b2, with `spec-fixes`,
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
| Timing | F2h interrupt delivered at once; the DSP takes microseconds | B and C |
| Mixer | Every index is plain RAM; SB 2.0 has a mixer it should not | B |
| ESS | 2xCh status always 7Fh: FIFO full and empty and data available together | C |
| ESS | No compatibility-mode model: always the extended register set | C |
| Output | Game stream held, not interpolated; at half rate pairs averaged across a drifting phase (the Descent 2 wobble) | D |
| Output | Output rate fixed at 44100 (or 22050), so every game rate is resampled | D |

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
MHz/(256-X), roll-off a 82nd of it). Under passthrough the physical A2h is
the game's A2h too. A Descent 2 stream at A1h=DCh plays at 22097 Hz, and its DMA
consumption and interrupts follow 22097 Hz. That is already true of the
consumption (the rig found it). What is not true is the output, which
resamples it; layer D fixes that.

**BAh clock trim** is the physical driver's business. The virtual BAh
reads and stores as the sheet says. Its bit 6 changes the virtual card's
clock only if a game sets it, which no surveyed driver does.

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

**The principle.** The game's stream is the subject and the CD is the
guest. Where the physical card can play the virtual card's programmed rate
exactly, the physical output runs at that rate and the game's samples pass
through untouched (format conversion only, which is lossless). The CD
stream is then the one resampled, to the game's rate, as it already is
whenever the rates differ. Where the physical card cannot hit the rate, the
game stream is resampled with a proper interpolating, band-limited
resampler, never held.

**By pairing:**

| Virtual | Physical | Game stream | CD stream |
| --- | --- | --- | --- |
| ESS | ESS | Passthrough: the physical A1h is the game's A1h, so 22097 Hz is 22097 Hz | Resampled 44100 to the game's rate |
| SB16 | SB16 | Passthrough: the physical 41h is the game's rate, and whatever the SB16 makes of it is what the real card makes of it | Resampled |
| SB Pro, SB 2.0 | SB16 | Near passthrough: 1 MHz/(256-tc) to the nearest Hz, at most 0.002 percent off | Resampled |
| Any | WSS | Resampled to the nearest codec crystal rate, interpolated | Resampled |
| SB16 | ESS | Resampled (the ESS divider cannot make arbitrary rates), interpolated | Resampled |
| Nothing playing | Any | None | Native 44100 where the card allows |

**What it costs.**

- *A rate change restarts the physical output.* The driver must time the
  restart at a block boundary and carry the CD stream across it, so the
  disc audio does not click. Games change rate rarely: at a sound
  effect's start, between music and speech. A real card's analog CD path
  is unaffected by the game's rate, so ours must be too.
- *The fast mode in its current form goes.* Its purpose, less ISA DMA
  time on a slow machine, is served better by passthrough. A 22097 Hz
  stream played at 22097 Hz moves half the bytes of 44100 Hz output, with
  no averaging. On a slow machine with CD audio alone, 22050 Hz output
  stays a choice.
- *The mixer runs at a variable output rate.* The period, the ring and the
  CD step are already in terms of `output_rate`. What becomes per-stream
  is the rate itself.

**Read-ahead within the hardware's margin.** Two periods of read-ahead
must not exceed what the card being emulated buffers:

| Card | Buffer | Read-ahead needed |
| --- | --- | --- |
| SB16 | A few samples | Small |
| ESS, Compatibility Mode | 64 bytes | Small |
| ESS, Extended Mode | 256 bytes | At most 256 bytes |

At 64 frames of 44.1 kHz 16-bit stereo, two periods are 512 bytes. So for
the ESS in Extended Mode the period should be 32 frames, and the 32-frame
click problem the rig found must be solved, not avoided. On the Pentium
the period costs nothing measurable down to 32 frames.

**What the current branches become.**

- `fast-resample` (pair-held game samples) is an interim fix for the
  current fixed-rate design. With passthrough on ESS to ESS it is no
  longer needed. I recommend not merging it unless passthrough is far
  off.
- `event-timer` section 0, the short period plus the physical one-shot,
  is the timing mechanism for layers B and C, unchanged.

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
   - F2TEST: latency and merging.
   - A DSP command sweep per model, compared with a bare card on the PC.
   - An ESS status sweep: 2xCh through a block.
   - A mixer read-back sweep per model.
   - An output transparency test: a known game stream captured digitally
     in 86Box and compared sample for sample, and on the PC by spectrum.
3. Every deviation that stays gets a row in ISSUES under "Deviations from
   specification", with the reason.
4. Order: layer A's open rows, layer B's table, layer C's two modes, layer
   D's passthrough, then layer E. A layer is done when its matrix has no
   open row without a recorded reason.

## 9. Branch disposition under this proposal

| Branch | State | Proposal |
| --- | --- | --- |
| `spec-fixes` | Spec corrections, regression clean | Merge into `fixes` now |
| `ess-position`, `miles-irq`, `virtual-timing` | Spec corrections (count timing, B1h/B2h, IRQ delivery) | Merge into `fixes` now, after `spec-fixes` |
| `fast-dma`, `setup-layout` | Layer E (Type F), plus the UCDDSET layout | Hold until A to C, as asked; or merge now as off by default, since Type F changes nothing observable and the UCDDSET layout is not a speedup. Michael's call |
| `fast-resample` | Interim layer D fix, retest pending | Do not merge if passthrough is next |
| `event-timer` | Timing design | Keep; section 0 feeds layers B and C |

## 10. Questions for Michael

1. Layer D's passthrough changes the physical output rate whenever a game
   stream starts at a new rate. Accept the restart, carried at a block
   boundary with the CD stream continuous, as the cost of exactness?
2. The ESS's reference model: the ES1868 with the family's differences
   only as needed, or one model per chip from the start?
3. `fast-dma` and `setup-layout`: hold until layers A to C are done, or
   merge now as off-by-default (section 9)?
4. Fast mode: retire it in favour of passthrough, or keep it as a
   CD-audio-only choice for slow machines?

## 11. Decisions (Michael, after the proposal)

1. CD audio follows the period hardware: on an ESS or Sound Blaster card of
   the time, disc audio never passed through the DAC. The drive's analog
   output went by cable to the card's CD input and was mixed in the analog
   mixer, under the mixer's CD volume (38h on the ESS, 28h on the SB Pro,
   36h/37h on the SB16). The game set only that volume and the MSCDEX play
   commands; the DAC's rate never touched the disc audio. So the virtual
   card's rate is the game's, and the CD stream is the guest that adapts to
   it, continuously across any rate change: this confirms layer D's
   passthrough and its requirement that a restart never clicks the disc.
2. ESS behaviour is guided by what ESS games expect: the eleven ESS driver
   binaries in the 147 ESS-aware games of the survey (HMI's five variants
   in 62 games, ADRV688.DIG in 52, ESFM.MDI in 21, AUDIODRV.DIG's two in
   16) set the order in which layer C's registers and behaviours are
   proven, each against the data sheet.
3. `fast-dma` and `setup-layout` are merged into `fixes` (fcf67f2, with
   `spec-fixes` and the rig's three branches).
4. Fast mode as a physical output mode is retired in favour of
   passthrough: it keeps the ESS out of spec (every game rate resampled to
   22050 Hz and pair-averaged). Its one remaining reason, half the ISA DMA
   time on a slow machine, is met by passthrough when the game plays at 22
   kHz, and by an option to play disc audio alone at 22050 Hz, which
   touches only the guest stream. `fast-resample` is not merged.
