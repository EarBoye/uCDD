# μCDD: fixes/updates/ESS fork

**This fork and all the work in it were developed entirely with agentic AI
(Claude), directed and tested by one person.**

This is a fork of [vorvek's μCDD](https://github.com/vorvek/uCDD), a DOS
CD-ROM driver for disc images that mixes CD audio with the game's own sound
through a virtual Sound Blaster. All credit for the driver is his. For what
μCDD is, how to install it and how to use it, see his README and releases.

The fork's `main` branch carries his releases only, unchanged (now Beta
0.9.5-a1, 26 October 2026). Everything else here is the fork's own work,
written with Claude and tested in 86Box (with DOSBox-X as a second opinion)
and, where noted, on one real PC (Pentium MMX 233, Intel 430HX, a Creative
SB16 CT2290 and before it an ESS ES1868, a Promise Ultra133 TX2).

## Taken upstream

The author's Beta 0.9.5-a1 took twelve of the fork's changes, each credited
in his [release notes](https://github.com/vorvek/uCDD/blob/main/RELEASE-NOTES.md):
native ESS AudioDrive output (in his own form), `UCDD -status` and its
interrupt counters, the XA bit in the device status, Ctrl+C ignored during
CD reads, the single-cycle block interrupt after one output period, the DMA
count at the start of an auto-initialize lap, MPU-401 interrupts on the
SB16, the interrupt vector restored before the PIC mask at stop, the wait
after DSP command D1h and the JEMMEX `VME` note, the DPMI host's gateway
stack fault, the INT 16h return with interrupts on, and the flat-segment,
INT 2Fh 1686h and nested-exception handling in the DPMI host.

## Feature branches, still open

Each of these is one feature on top of the author's Beta 0.9.4-a6, so a
comparison against that release shows the feature alone. Each has a
document that says what the change does, why, and what was tested, and its
commit messages say the same. They are built at 128 and 32 frames and
without resident audio; they have not been run on 0.9.4-a6 itself (the
evidence is from the fork's own line, as each document says) and have not
been rebased onto 0.9.5-a1.

| Branch | What it does | Read first |
| --- | --- | --- |
| [`feature/disk-irq`](https://github.com/EarBoye/uCDD/tree/feature/disk-irq) | A PCI disk controller on any IRQ no longer freezes DOS/4GW games: `UCDD -install` finds the controllers through the PCI BIOS and their IRQs go straight to the real-mode handler; UCDDSET shows them and takes one by hand. | [`docs/disk-irq.md`](https://github.com/EarBoye/uCDD/blob/feature/disk-irq/docs/disk-irq.md) |
| [`feature/step-aside`](https://github.com/EarBoye/uCDD/tree/feature/step-aside) | While no mounted disc has CD audio and the physical card can be the virtual one, the driver steps aside: no output stream, no port traps, no DPMI host, so a game runs as it does without μCDD. | [`docs/step-aside.md`](https://github.com/EarBoye/uCDD/blob/feature/step-aside/docs/step-aside.md) |
| [`feature/fast-dma`](https://github.com/EarBoye/uCDD/tree/feature/fast-dma) | The chipset's own fast DMA timing on the output channel (Intel PIIX family, 82378 and EISA, ALi, OPTi, VIA and AMD-756, SiS), which gives back most of the memory bus the output stream takes. Builds on the two branches above, which it contains. | [`docs/fast-dma.md`](https://github.com/EarBoye/uCDD/blob/feature/fast-dma/docs/fast-dma.md), [`docs/platform-dma.md`](https://github.com/EarBoye/uCDD/blob/feature/fast-dma/docs/platform-dma.md) |
| [`feature/ess`](https://github.com/EarBoye/uCDD/tree/feature/ess) | Native ESS AudioDrive output: 44.1 kHz 16-bit stereo through the chip's extended mode, with the ES1868's and ES1878's clock trimmed to an exact 44.1 kHz. The author's 0.9.5-a1 has its own native ESS output and measures the rate instead of trimming it; this branch stays as the trimmed form. Its `wss_stop` vector fix is upstream. | [`docs/ess.md`](https://github.com/EarBoye/uCDD/blob/feature/ess/docs/ess.md) |

The three settings the first three branches add share one `UCDD.CFG`
layout (version 5: the author's version 4 record, then the disk IRQ, the
step-aside switch and the fast DMA switch at offsets 42, 43 and 44), so any
of them can be taken alone or together.

## Current work: a test campaign

Since late October the fork runs a test harness against the author's
0.9.4-a6 as pinned, with no driver changes until it finishes: unit tests
of the parsers and converters, driver conformance against the MSCDEX
specification on synthetic images, virtual Sound Blaster conformance
against Creative's programming guides and a real CT2290, and a
zero-interaction sweep over a game library. Every result is a row in
[`ISSUES.md` on `notes`](https://github.com/EarBoye/uCDD/blob/notes/ISSUES.md),
with the run that produced it and the document that decides its expected
result; the commit checks under `.github` enforce that. Candidate driver
faults are written up there for the author to take or leave; nothing is
sent to him.

## Other work in this fork

Not offered as feature branches, because they are still being tested or
depend on each other:

- **The virtual Sound Blaster read against the documents.** Each model
  (SB16, SB Pro, SB 1.5/2.0) follows Creative's programming guides,
  checked against a real CT2290; the virtual SB16 answers as that card
  does (DSP 4.13). The DMA count and the block interrupt come from one
  position, the card's fetch point.
- **The author's 0.9.4-a6 merged into the fork's line** (`merge-a6`): where
  both sides fixed the same thing, his version is kept.
  [`ISSUES.md` on that branch](https://github.com/EarBoye/uCDD/blob/merge-a6/ISSUES.md)
  lists every place (UPA6). Built, not run.
- **The fork's current line** (`count-position`): the virtual card's count
  and interrupt work and a 512-frame output ring so a late period interrupt
  no longer throws the clock back. Its interrupt counters are upstream now.
- **The DPMI host and the CD-ROM driver read against their
  specifications**: nested clients, 16-bit clients, exceptions, DPMI 0.9
  and 1.0 details, MSCDEX details (raw sector reads, media change). Part of
  this is upstream in 0.9.5-a1.
- **A virtual ESS AudioDrive** built from the ESS data sheets, for games
  set to an ESS on an ESS card.
- **A sound engine library** (`sound-engine-library`): which games use which
  sound engines and driver versions, so a fault seen in one game is tested
  across every game that shares its engine.
- **Reference material** (`reference-library`): text copies of the data
  sheets and specifications the work follows.

## Branches

| Branch | Holds |
| --- | --- |
| `main` | The author's releases, unchanged. |
| `feature/*` | The feature branches above, each on 0.9.4-a6; built, not run. |
| `merge-a6` | The fork's line with 0.9.4-a6 merged in; built, not run. |
| `count-position` | The fork's line before the merge; the build the test campaign pins. |
| `fixes` | This README; the fork's combined line up to 20 Oct 2026, kept for its history. |
| `notes` | The test campaign's rows (`ISSUES.md`) and its notes. |
| `claude/brave-franklin-6h9xzo` | The method package the commit checks run (to be renamed `method` after the campaign). |
| `sound-engine-library`, `reference-library`, `spec-first` | Notes, references and design. |
| `irq-counters`, `irq-batch`, `event-timer`, `period-late`, `play-harness`, `stray-eoi`, `vcpi-children` | Earlier working branches, kept until the campaign decides which become candidate rows; then archived. |

Branches that were folded into others live on as `archive/<name>` tags.
