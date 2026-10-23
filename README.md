# μCDD: the EarBoye fork

This is a fork of [vorvek's μCDD](https://github.com/vorvek/uCDD), a DOS
CD-ROM driver for disc images that mixes CD audio with the game's own sound
through a virtual Sound Blaster. All credit for the driver is his. For what
μCDD is, how to install it and how to use it, see his README and releases.

The fork's `main` branch carries his releases only, unchanged (now Beta
0.9.4-a6). Everything else here is the fork's own work, written with Claude
and tested in emulators (86Box, DOSBox-X, QEMU) and, where noted, on one
real PC (Pentium MMX 233, Intel 430HX, a Creative SB16 CT2290 and before it
an ESS ES1868, a Promise Ultra133 TX2).

## Feature branches, ready to take

Each of these is one feature on top of the author's Beta 0.9.4-a6, so a
comparison against `main` shows that feature alone. Each has a file in
`docs/` that says what the change does, why, and what was tested, and its
commit messages say the same. They are built at 128 and 32 frames and
without resident audio; they have not yet been run on 0.9.4-a6 itself (the
evidence is from the fork's own line, as each doc says).

| Branch | What it does | Read first |
| --- | --- | --- |
| `feature/disk-irq` | A PCI disk controller on any IRQ no longer freezes DOS/4GW games: `UCDD -install` finds the controllers through the PCI BIOS and their IRQs go straight to the real-mode handler; UCDDSET shows them and takes one by hand. | `docs/disk-irq.md` |
| `feature/step-aside` | While no mounted disc has CD audio and the physical card can be the virtual one, the driver steps aside: no output stream, no port traps, no DPMI host, so a game runs as it does without μCDD. | `docs/step-aside.md` |
| `feature/fast-dma` | The chipset's own fast DMA timing on the output channel (Intel PIIX family, 82378 and EISA, ALi, OPTi, VIA and AMD-756, SiS), which gives back most of the memory bus the output stream takes. Builds on the two branches above, which it contains. | `docs/fast-dma.md`, `docs/platform-dma.md` |
| `feature/ess` | Native ESS AudioDrive output (ES1868 and its family), with the ES1868's clock trimmed to an exact 44.1 kHz. In preparation. | |

The three settings these branches add share one `UCDD.CFG` layout (version
5: the author's version 4 record, then the disk IRQ, the step-aside switch
and the fast DMA switch at offsets 42, 43 and 44), so any of them can be
taken alone or together.

## Other work in this fork

Not yet offered as feature branches, because they are still being tested or
depend on each other:

- **The virtual Sound Blaster read against the documents.** Each model
  (SB16, SB Pro, SB 1.5/2.0) follows Creative's programming guides and the
  DSP firmware's own command tables; the SB16 answers as a DSP 4.13, as the
  CT2290 measures. The DMA count and the block interrupt come from one
  position, the card's fetch point.
- **The author's 0.9.4-a6 merged into the fork's line** (`merge-a6`): where
  both sides fixed the same thing, his version is kept. `ISSUES.md` on that
  branch lists every place (UPA6). Built, not yet run.
- **The fork's current line** (`count-position`): the virtual card's count
  and interrupt work, a 512-frame output ring so a late period interrupt no
  longer throws the clock back, and interrupt counters (`UCDD -status`).
- **The DPMI host and the CD-ROM driver read against their
  specifications**: nested clients, 16-bit clients, exceptions, DPMI 0.9
  and 1.0 details, MSCDEX details (raw sector reads, media change).
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
| `feature/*` | The feature branches above, each on 0.9.4-a6. |
| `merge-a6` | The fork's line with 0.9.4-a6 merged in. |
| `count-position` | The fork's line before the merge. |
| `fixes` | This README; the fork's combined line up to 20 Oct 2026, kept for its history. |
| `sound-engine-library`, `reference-library`, `spec-first` | Notes, references and design. |

Branches that were folded into others live on as `archive/<name>` tags.
