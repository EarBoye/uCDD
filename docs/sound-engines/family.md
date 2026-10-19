# The whole Sound Blaster family: each engine on each card

How 24 games, covering every engine family, behave on each of Creative's
cards before and including the SB16: the SB 1.0, SB 2.0, SB Pro 1, SB Pro
2 and SB16. Run in DOSBox-X, the emulator eXo built the libraries for,
with a port log stamped with emulated time ([methods.md](methods.md)):
no uCDD involved, so this is how the engines meet a card, and the
reference uCDD's virtual cards are measured against. All [trace] in
DOSBox-X (an emulator); Creative's own cards were not used. Grades as in
the [README](README.md#evidence-grades).

Each cell: the transfer commands the game used, and the median spacing
of its interrupt acknowledges (the block period it runs at); "plays"
where the DMA count or address moved without regular acknowledges;
"silent" where a transfer was asked for and nothing moved; "no transfer"
where the game never started one. The games kept their library
configuration (eXo's, mostly set for an SB16), 45 s each, BLASTER
matching the card (T1, T3, T2, T4, T6).

| Game (engine) | SB 1.0 | SB 2.0 | SB Pro 1 | SB Pro 2 | SB16 |
|---|---|---|---|---|---|
| Albion (Miles MSS 3.03) | 14h, 92 ms | 14h+1Ch, 92 ms | 14h+1Ch, 92 ms | 14h+1Ch, 92 ms | B0h+C6h, 93 ms |
| C-Dogs (DSMI) | 90h: **silent** | 90h, plays | 90h stereo, plays | 90h stereo, plays | 90h stereo, plays |
| Capitalism (DigPak SB Pro) | 14h, 992 ms | 14h, 1014 ms | 14h, 992 ms | 14h, 992 ms | 14h, 1032 ms |
| Castles II (AIL 2 SB Pro) | no transfer | no transfer | 14h probes only | 14h probes only | 14h probes only |
| Dark Forces (iMUSE) | no transfer | no transfer | C6h: **silent** | C6h: **silent** | C6h, 47 ms |
| Descent (HMI, SB16 module) | C4h: **silent** | C4h: **silent** | C4h: **silent** | C4h: **silent** | C4h, plays |
| Doom (DMX) | 14h, 369 ms | 14h+1Ch, 12 ms | 14h+90h stereo, 12 ms | 14h+90h stereo, 12 ms | C6h, 12 ms |
| Duke Nukem 3D (Apogee 1.1) | 14h, 12 ms | 1Ch, 12 ms | 90h, 12 ms | 90h, 12 ms | B6h, 12 ms |
| Hocus Pocus (Apogee 1.0) | 14h, 13 ms | 1Ch, 13 ms | 1Ch, 13 ms | 1Ch, 13 ms | B6h, 6.0 ms |
| King's Quest V (Sierra) | 14h, 1474 ms | 14h, 1474 ms | 14h, 1474 ms | 14h, 1474 ms | 14h, 1474 ms |
| Kyrandia (Westwood) | no transfer | no transfer | 14h, 3308 ms | 14h, 3308 ms | 14h, 3308 ms |
| LBA (AIL/32 SB16) | no transfer | no transfer | B6h: **silent** | B6h: **silent** | B6h, 47 ms |
| Monkey Island (LucasArts) | 14h, 9.4 ms | 14h, 9.4 ms | 14h, 9.4 ms | 14h, 9.4 ms | 14h, 9.4 ms |
| Rayman (HMI, SB Pro module) | 90h: **silent** | 90h, 418 ms | 90h stereo, 418 ms | 90h stereo, 418 ms | 90h stereo, 418 ms |
| Stargunner (own) | 14h, 3014 ms | 1Ch, 3014 ms | 90h stereo, 1507 ms | 90h stereo, 1507 ms | B6h, 1474 ms |
| Super Stardust (MIDAS) | 14h, 3014 ms | 90h, 2948 ms | 90h, 2948 ms | 90h, 2948 ms | B4h, 2971 ms |
| System Shock (Miles 1994 SB16) | no transfer | no transfer | no transfer | no transfer | B0h+C6h, 46 ms |
| The Jungle Book (own) | 14h, plays | 1Ch, plays | 1Ch, plays | 1Ch, plays | 1Ch, plays |
| Theme Hospital (Miles 3.50E SB16) | no transfer | no transfer | no transfer | no transfer | B0h+B6h, 23 ms |
| Time Commando (Miles 3.04 SB16) | no transfer | no transfer | no transfer | no transfer | B0h+B6h, 23 ms |
| Tyrian (Loudness) | no transfer | no transfer | no transfer | no transfer | no transfer |
| Ultima Underworld (AIL 2) | no transfer | no transfer | 14h, 340 ms | 14h, 340 ms | 14h, 340 ms |
| X-COM (DigPak SB16) | C2h: **silent** | C6h: **silent** | C6h: **silent** | C6h: **silent** | C6h, 46 ms |
| Xargon (Creative) | 14h, 242 ms | 14h, 243 ms | 14h, 242 ms | 14h, 242 ms | 14h, 242 ms |

Two passes of the whole matrix agreed cell for cell, but for three runs
that failed to start in the second (filled from the first) and one run
spoiled in the first by a shared virtual display (Xargon on the SB Pro 2).

## What the matrix shows

- **Engines that look at the card adapt to every model and keep their
  block period.** Duke Nukem 3D runs 12 ms blocks on all five cards:
  single-cycle 14h on the SB 1.0, auto-init 1Ch on the 2.0, high-speed
  90h on both Pros, 16-bit B6h on the SB16. Albion keeps 92 ms, Hocus
  Pocus 13 ms (6 ms on the SB16), MIDAS about 3 s, Stargunner 1.5-3 s.
  DMX keeps 12 ms from the SB 2.0 up; on the SB 1.0, which has no
  auto-init, it falls back to long single-cycle blocks (369 ms).
- **What each card brings out:**

  | Card | What the adaptive engines use |
  |---|---|
  | SB 1.0 | chained single-cycle 14h only |
  | SB 2.0 | auto-init 1Ch with 48h, or high speed 90h (MIDAS, Rayman, C-Dogs) |
  | SB Pro 1 and 2 | high speed 90h, **stereo** through mixer 0Eh (DMX, Stargunner, Rayman, C-Dogs), or mono 1Ch (Albion, Hocus Pocus) |
  | SB16 | 16-bit B6h/B4h or 8-bit C6h with 41h rates |

  The SB Pro 1 and 2 behaved alike in every game: none of these engines
  told them apart on the digital side (the FM side differs: OPL3 on the
  Pro 2).
- **Engines that take the card from their configuration only work on the
  card they were set up for**: HMI's SB16 module (Descent), Miles 3's
  SB16 drivers (System Shock, Theme Hospital, Time Commando), DigPak's
  SB16 driver (X-COM), AIL/32's SB16 driver (LBA) and iMUSE (Dark
  Forces) are silent on everything older. Set up for each card (below),
  HMI's modules play on every one.
- **Some code needs the SB Pro's mixer**: AIL 2's SB Pro driver (Castles
  II), Westwood (Kyrandia), Ultima Underworld find no card on the SB 1.0
  and 2.0.
- **High speed needs DSP 2.01**: Rayman's HMI SB Pro module and C-Dogs
  ask for 90h and get nothing on the SB 1.0.
- Creative-era and Sierra code (Xargon, Monkey Island, King's Quest V)
  and DigPak's SB Pro driver (Capitalism) behave the same on all five.

## Compatibility modes: which input an engine believes

### An SB16 whose BLASTER says it is something else

The same SB16, with BLASTER claiming an SB Pro 2 (T4), an SB 2.0 (T3), an
SB 1.x (T1), or no BLASTER at all:

| Game | SB16, T6 | told T4 | told T3 | told T1 | no BLASTER |
|---|---|---|---|---|---|
| Doom (DMX) | C6h, 12 ms | C6h, 12 ms | C6h, 12 ms | C6h, 12 ms | C6h, 12 ms |
| Albion (Miles MSS 3.03) | B0h+C6h, 93 ms | B0h+C6h, 93 ms | B0h+C6h, 93 ms | B0h+C6h, 93 ms | B0h+C6h, 93 ms |
| King's Quest V (Sierra) | 14h, 1474 ms | 14h, 1474 ms | 14h, 1474 ms | 14h, 1474 ms | 14h, 1474 ms |
| Xargon (Creative) | 14h, 242 ms | 14h, 242 ms | 14h, 243 ms | 14h, 242 ms | 14h, 242 ms |
| Monkey Island (LucasArts) | 14h, 9.4 ms | 14h, 9.4 ms | 14h, 9.4 ms | 14h, 9.4 ms | 14h, 9.4 ms |
| Stargunner (own) | B6h, 1474 ms | B6h, 1474 ms | B6h, 1474 ms | B6h, 1474 ms | B6h, 1474 ms |
| The Jungle Book (own) | 1Ch, plays | 1Ch, plays | 1Ch, plays | 1Ch, plays | 1Ch, plays |
| C-Dogs (DSMI) | 90h stereo, plays | 90h stereo, plays | 90h stereo, plays | 90h stereo, plays | failed to start |
| Duke Nukem 3D (Apogee 1.1) | B6h, 12 ms | B6h, 12 ms | B6h, 12 ms | B6h, 12 ms | failed to start |
| Hocus Pocus (Apogee 1.0) | B6h, 6.0 ms | C6h, 13 ms | C6h, 13 ms | C6h, 13 ms | no transfer |
| Super Stardust (MIDAS) | B4h, 2971 ms | B4h, 169 ms | B4h, 169 ms | B4h, 169 ms | no transfer |

- Most engines ignore BLASTER's type and ask the card: DMX, Albion's
  Miles, Sierra, Xargon, Monkey Island, Stargunner, The Jungle Book and
  C-Dogs did the same whatever T said, and with no BLASTER at all.
- The Apogee Sound System 1.0 (Hocus Pocus) believes T: told anything
  but 6 it plays 8-bit (C6h, 13 ms) instead of 16-bit (B6h, 6 ms), still
  with the SB16's commands, and with no BLASTER it plays nothing. MIDAS
  keeps 16-bit but changes its block from about 3 s to 169 ms, and with
  no BLASTER plays nothing. Duke Nukem 3D takes its card type from its
  own configuration file, not from BLASTER.
- A real SB16 behaves the same way to all of this: the type in BLASTER is
  only what a game reads; the card answers E1h with 4.xx whatever it says.

### The game's own configuration set for each card

HMI's device ID (E000h on the SB 1.0 and 2.0, E001h on the Pros), the Apogee Sound System's BlasterType or SBType (1, 3, 2, 4), each on the matching card:

| Game | SB 1.0 | SB 2.0 | SB Pro 1 | SB Pro 2 |
|---|---|---|---|---|
| Descent (HMI) | 14h, 20 ms | 1Ch, 20 ms | 90h stereo, plays | 90h stereo, plays |
| Tomb Raider (HMI) | 14h, 188 ms | 1Ch, 188 ms | 90h stereo, 94 ms | 90h stereo, 94 ms |
| Duke Nukem 3D (Apogee 1.1) | 14h, 12 ms | 1Ch, 12 ms | 90h, 12 ms | 90h, 12 ms |
| Rise of the Triad (Apogee) | 14h, 23 ms | 1Ch, 23 ms | 1Ch, 24 ms | 1Ch, 24 ms |

- HMI's modules adapt within their own family: the SB module (E000h)
  uses single-cycle 14h on the SB 1.0 and auto-init 1Ch on the SB 2.0;
  the SB Pro module (E001h) high-speed stereo on both Pros. The device ID
  in the configuration, not detection, decides which module runs.
- Duke Nukem 3D with BlasterType set behaves as with BlasterType 6 on the
  older cards: it checks the DSP itself. Rise of the Triad with SBType
  set for each card plays on every one (1Ch on the Pros, no stereo);
  left at 6 on an SB Pro it programs the 16-bit DMA channel and stays
  silent ([pre-sb16.md](pre-sb16.md)).

## uCDD against the reference

The same games on uCDD's virtual cards (86Box) against DOSBox-X's card of
the same model ([pre-sb16.md](pre-sb16.md), [findings.md](findings.md)):

| Game | DOSBox-X | uCDD | Finding |
|---|---|---|---|
| System Shock, SB16 | plays, 46 ms blocks | no digital sound with both cards on IRQ 7 | F1 |
| Doom, Hexen, Raptor (DMX), SB Pro | stereo 90h, 12 ms | stalls at the 12-byte priming with both cards on IRQ 7; plays at IRQ 5 | F4 |
| Rayman, SB Pro and SB 2.0 | 90h, 418 ms | stalls with both on IRQ 7; plays at IRQ 5 | F4 |
| Stargunner, SB Pro | stereo 90h, 1.5 s | stalls at IRQ 7; plays at IRQ 5 | F4 |
| C-Dogs, every card from the SB 2.0 up | plays | never starts, at any IRQ | F5 |
| Duke Nukem 3D, SB Pro | 90h mono, 12 ms | never starts, at IRQ 7 and at IRQ 5 | F6 |

Everywhere else the two agreed: the same commands, the same paths, the
same silences (HMI's SB16 module, Miles 3's SB16 drivers, DigPak's SB16
driver, LBA and iMUSE on the older cards; the mixer test failing on the
SB 2.0).
