# The cards before the SB16: Sound Blaster 1.x/2.0 and Pro

What the engines do when the card they find is not an SB16, and what
uCDD's virtual SB Pro and SB 2.0 meet. The cards' own behaviour, command
by command, is in [vsb-spec.md](../vsb-spec.md) (sections 5, 7.3, 7.4,
9.3, 11); this page is about the games. Grades as in the
[README](README.md#evidence-grades).

## The cards in one table

| Card | DSP | BLASTER T | Output (SBG:1418-1442) | Mixer | FM | Where it differs for a game |
|---|---|---|---|---|---|---|
| SB 1.0/1.5 | 1.xx | T1 | 8-bit mono, single-cycle 14h only, 4000-23000 Hz | none | OPL2 | no auto-init (1Ch and 48h come with 2.00), no high speed; D1h/D3h pause the DMA (vsb-spec.md 11) |
| SB 2.0 | 2.01 | T3 | adds auto-init (1Ch, 48h, DAh) and high speed (90h/91h): normal to 23000 Hz, high speed 23000-44100 Hz, mono | none | OPL2 | no mixer: 2x4h/2x5h hold nothing |
| SB Pro (1) | 3.0x | T2 | as the 2.01, plus stereo: mixer 0Eh bit 1 with high speed, **11025 or 22050 Hz** a channel | CT1345 | two OPL2 (left 2x0h, right 2x2h, SBG:4234-4239) | stereo needs the 0Eh switch and a priming byte (vsb-spec.md 7.4) |
| SB Pro 2 | 3.02 | T4 | as the SB Pro | CT1345 | one OPL3 | |
| SB16 | 4.xx | T6 | 41h rates 5000-44100 Hz, Bxh/Cxh 8/16-bit, mono or stereo by the mode byte | CT1745 (no 0Eh) | OPL3 | 41h-47h before the SB16 act as 40h with one argument (vsb-spec.md 4) |

The output columns are [doc]; the BLASTER T values are [recall]. A
program that asks a card for more than its range gets what that card
does, which the documents do not say (vsb-spec.md 6).

uCDD presents the SB 2.0 (model 3, DSP 2.01) and the SB Pro (model 1, DSP
3.02); there is no virtual 1.xx. The FM ports are the physical card's:
on Michael's CT2290 a game set for an SB Pro 1's two OPL2 chips meets an
OPL3 (SBG:450-454 for the difference) [doc].

## How each engine reacts [trace]

48 games, each run on a virtual SB Pro (T4) and a virtual SB 2.0 (T3) in
86Box, with their library configuration unchanged (eXo set most of them
up for an SB16). "Plays" means the DMA count moved or block interrupts
came; the runs were at IRQ 7 unless stated (see F4 below).

| Engine (games) | On the SB Pro | On the SB 2.0 |
|---|---|---|
| **DMX** (Doom, Hexen, Raptor) | detects the SB Pro by reading the mixer, F2h with four lines open, then an undocumented **FAh** (reply 00h); stereo: 0Eh=13h, time constant D3h (11.1 kHz a channel), a **12-byte single-cycle 14h** to prime the stereo, waits for its count to run out, then 4 KB auto-init (8237 mode 19h, demand) with **48h 256 and 90h**: 11.5 ms blocks. Plays at IRQ 5; **stalls at IRQ 7** (F4) | mono: 14h then 1Ch auto-init; plays |
| **Miles MSS 3** SB16 driver (Theme Hospital, Dungeon Keeper, Time Commando, Warcraft) | E1h, sees 3.02, gives up: no digital sound, cleanly | the same |
| Miles MSS 3 (Albion's run) | adapts: a 4-byte 14h probe, then time constant A6h with 48h 1024 and **1Ch**, 0Eh=11h (mono) | no transfer |
| **Miles AIL 2** SB Pro driver (Castles II, SimCity, Serf City) | as on the SB16: the 0Ah mixer test, single-cycle 14h | the mixer test fails: no card, no sound |
| AIL/32 SB16 driver (LBA) | sends B6h anyway: nothing plays | no card |
| **HMI SOS**, SB16 module (Descent, Tomb Raider, MDK, Abuse) | sends 41h and C4h anyway: 41h is taken as a time constant, C4h starts nothing; silent. Only the setup's device ID decides | the same |
| HMI SOS, SB Pro module E001h (Rayman) | stereo 0Eh=13h, time constant CDh, 48h 8192, 90h. Plays at IRQ 5; **stalls at IRQ 7** (F4) | 90h, mono (no mixer); stalled at IRQ 7 (not run at 5) |
| **Apogee SS** (Duke Nukem 3D, configured SBType 6) | adapts: time constant E9h (43.5 kHz, inside the high-speed mono range), 48h 512, **90h**, mono (no 0Eh write); under uCDD it never starts (F6) | no transfer seen |
| Apogee SS (Rise of the Triad, SBType 6) | 90h, but **DMA 5** programmed and DMA 1 left masked: silent, as a real SB Pro would be | the same |
| Apogee SS (Hocus Pocus, Realms of Chaos) | **1Ch** with 48h 128 (about 12 ms blocks), 0Eh=11h | 1Ch; plays |
| **DigPak** SB16 driver (X-COM, Pizza Tycoon) | sends 41h and C6h anyway: silent | the same |
| DigPak SB Pro driver (Capitalism) | single-cycle 14h chained; reads mixer 82h, which the SB Pro does not document; plays | plays |
| **Sierra** AUDBLAST (King's Quest V, Police Quest 3) | identical on every card: time constant, 14h blocks | identical |
| **Creative-era** code (Xargon, Jill, Monkey Island, Epic Pinball, Dark Seed) | identical: these were written for the 1.x/2.0 | identical |
| **iMUSE** (Dark Forces, TIE Fighter) | reads mixer 80h/81h, then no traffic at all | the same |
| **Westwood** (Kyrandia, Dune II) | as on the SB16 (their SB Pro code) | the mixer test fails: no digital sound |
| **DSMI** (C-Dogs) | 90h before the 8237 is set: never starts, on every card (F5) | the same |
| **MIDAS** (Super Stardust) | adapts to 90h high speed with a time constant; plays | plays |
| Loudness (Tyrian), MicroProse (Darklands) | identical 14h chains | identical |
| Own code (Risky Woods, Ultima Underworld, Cyberia, The Jungle Book) | identical to the SB16 runs | Ultima Underworld: no card; the others play |
| Own code (Stargunner) | stereo 90h; plays at IRQ 5, **stalls at IRQ 7** (F4) | 1Ch mono; plays |

## What it means

- **A game's configuration, not its engine, decides most failures.**
  eXo set most games up for an SB16 (DOSBox's default). On a virtual SB
  Pro or SB 2.0, every engine that takes its card from a file (HMI's
  device ID, Miles' DIG.INI driver, DigPak's SOUNDRV.COM, AIL's
  configuration) uses the SB16 driver it was given: it sends SB16
  commands or gives up. The real cards would do the same. To use a
  pre-SB16 virtual card, each such game's own setup has to be run again.
- **The engines that look at the card themselves adapt**: DMX, Apogee,
  MIDAS, Sierra, the Creative-era code, own code. Their SB Pro paths are
  stereo high speed (DMX, Rayman's module, Stargunner) or mono 1Ch/90h
  (Apogee, MIDAS, Albion).
- **The SB 2.0 loses the games that need a mixer**: AIL 2's SB Pro driver,
  Westwood's code and Ultima Underworld test mixer 0Ah and find no card.
- **Every high-speed path here stalls at IRQ 7 under uCDD** (F4), and
  the DMX games are among them: on a virtual SB Pro at IRQ 7 Doom, Hexen
  and Raptor ran without digital sound (Heretic and Strife share the
  engine and were not run). Duke Nukem 3D's stalls at any IRQ (F6). The
  same games on DOSBox-X's cards: [family.md](family.md).

## uCDD faults found on this pass

See [findings.md](findings.md):

- **F4**: high-speed output (90h) and DMX's stereo priming never start
  on the virtual SB Pro or SB 2.0 when the physical and the virtual card
  share IRQ 7 (DMX's three games, Rayman on both cards, Stargunner); with
  both on IRQ 5 they run. Mono 1Ch and 14h chains play at IRQ 7. A later
  check showed it is high speed, not stereo, that stalls (Rayman's mono
  90h on the SB 2.0). Probably the same root as F1.
- **F6**: Duke Nukem 3D's mono 90h at 43.5 kHz never starts on the
  virtual SB Pro, at IRQ 5 as at 7; DOSBox-X plays it.
- **F5**: a DSP command that starts a transfer before the game has set
  the 8237's mode and count and unmasked it (C-Dogs: 48h, 90h, then the
  DMA) never starts, on every card and at IRQ 5 too. A real DSP waits for
  the DMA, so the order works on hardware.
