# Games with their own sound code

About 475 of the 838 games carry no known engine: their sound is the
game's own code, written from Creative's and AdLib's example programs,
or the game has no Sound Blaster support at all. They are classed by
what their files name and what their code touches (see the
[inventory](inventory.md) for the method):

| Class | Games | What it means |
|---|---|---|
| own: SB + AdLib | 141 | digital sound on the SB's DSP and music on the OPL, written by the game |
| own: SB | 97 | digital only, or FM through the same code without naming AdLib |
| own: AdLib | 59 | FM music and effects on the OPL at 388h; the SB is used only as an AdLib |
| own: speaker | 105 | the PC speaker only (PIT channel 2 and port 61h) |
| own: nothing visible | 54 | no device found: packed executables, or no sound |
| own: runs from its disc | 19 | no program files on disk and nothing known on the disc |

Grades as in the [README](README.md#evidence-grades): the classes are
[file]; the sequences below are [trace].

## How own code talks to the card

The traced own-code games use the same pieces as Creative's own drivers
([creative.md](creative.md)), in the order Creative's guide teaches them:

1. Reset at 2x6h, AAh at 2xAh.
2. Often E1h (version), sometimes E0h (identify).
3. The IRQ: from BLASTER, or found with F2h, a short 14h, or an 80h
   silence with several lines open (Tyrian's Loudness code opens every
   line but IRQ 3).
4. 8-bit single-cycle **14h** blocks chained from the handler (the 1.x
   way, still the most common), or auto-init (1Ch, 90h, C6h, B6h) on
   later games.
5. 2xEh to acknowledge, 20h to the PIC.

| Game | What the trace shows |
|---|---|
| Battle Race 95 | 41h 22050 Hz, B6h 16-bit stereo, one 61440-sample block over a 4416-word buffer; position by the count, "two reads agree" |
| Liero | 41h 22025 Hz, B6h 16-bit mono, 512-sample blocks |
| Tyrian (Loudness SS) | 80h silence for the IRQ, 14h blocks of 384 bytes at 10989 Hz |
| Kyrandia 1, 2, Dune II (Westwood) | the AIL 2 SB Pro driver's exact sequence, built into the game: D3h, the 0Ah mixer test, a 4-byte probe from address 0, 14h blocks up to 55 KB at 21739 Hz with D0h between |
| Hocus Pocus | the Apogee Sound System's sequence (packed executable) |

## A random sample of 75 own-code games (19 Oct, second pass)

Drawn at random from the "own" classes (34 SB + AdLib, 24 SB, 6 AdLib,
2 speaker) and 9 from the small engines, then traced with the build that
logs the card and counts the timer, FM and MPU-401 together [trace]. 25
touched the card, 21 used only the FM chip, 29 made too little traffic
in 35 s for a log (silent menus, or a start that failed in the test).

How the 25 drive the card:

| Style | Games | Detect | IRQ test | Rate | Position |
|---|---|---|---|---|---|
| **Single-cycle 14h blocks** (the 1.x way), chained from the handler | Jack in the Dark, Dark Queen of Krynn, Risky Woods, Cadaver: The Payoff, Baron Baldric, Bomberman, Celtic Tales, Dark Sun, Might and Magic 5 and World of Xeen, Subtrade, The Incredible Machine, Ultima Underworld, Darkness | E1h, E0h, E4h/E8h and E2h all four in Baron Baldric, Bomberman and Celtic Tales (Creative's sample code); the SB Pro mixer test 0Ah in Risky Woods, Dark Sun, Ultima Underworld; E0h alone in Jack in the Dark, E1h and E0h in The Incredible Machine; nothing seen in the rest | a one-byte 14h (9 games), F2h (3) | time constant | interrupts; Darkness also polls the count |
| **8-bit auto-init 1Ch** (2.0 and later) | Creature Shock, Cyberia, The Jungle Book | E1h or none | none seen | time constant | Cyberia reads the 8237 **address**, The Jungle Book the count |
| **16-bit SB16 auto-init B6h** | Stargunner, Ignition, Flying Tigers II | E1h (Stargunner), none seen in the others | none seen | 41h; **Stargunner uses a time constant with B6h** | the 8237 count, polled |
| Detection only in the run | Elvira (F2h with every master line open), GT Racing 97, Chasm, It Came from the Desert, Blake Stone: Planet Strike, Nova 9 | | | | |

Risky Woods repeats its one-byte probe 14 times, opening IRQ 5 and 7
in turn, before it settles. The games that acknowledged in the run read
2xEh; the SB16 ones (Stargunner, Ignition) 2xFh. Nothing in the sample
used a DMA mode or a position method the engine pages do not already
cover.

Findings that touch own-code games: Stargunner's 90h high-speed output
never starts with both cards on IRQ 7 on the virtual SB Pro and SB 2.0,
and plays at IRQ 5 ([findings.md](findings.md) F4, open); Battle Race 95
stops in a "two reads agree" loop on the polled count, the same field as
F2 (host-cdrom-spec.md section 10; the count and the clock fixed on
`count-position` 24 Oct [86Box], Battle Race not yet rerun).

Their FM habits (38 games wrote the chip):

| Status reads per register write | Games | What it is |
|---|---|---|
| none | 11: Star Control 3 (1193 writes/s), Worlds of Ultima: The Savage Empire (1213/s), Metal Gear (868/s), Might and Magic 5 and World of Xeen, The Bard's Tale 3, Bomberman, Subtrade, Jack in the Dark, Exterminator, Dizzy: Prince of the Yolkfolk | any delay is in the code between writes: fine on the CPUs they were written for, too fast for an OPL2 on a fast one |
| 5 to 14 | MechWarrior (4.8), The Cycles (6), Dark Sun (14), The Lost Vikings (14) | short loops |
| 24 to 34 | Risky Woods and Ultima Underworld (24), Celtic Tales, Genghis Khan II and Gemfire (27: the Koei games), The Jungle Book (34) | |
| **41** | 10: Blake Stone: Planet Strike, Elvira, Gateway 2, M.C. Kids, It Came from the Desert, Darkness, Shuttle, Dragon Lord, Monty Python's Flying Circus, Cadaver: The Payoff | **AdLib's documented delay**, about 6 reads after the index and 35 after the data [recall: the AdLib guide's 3.3 us and 23 us] |
| 43 to 70 | Overlord (43), The Dark Queen of Krynn, BAT and Buck Rogers: Matrix Cubed (48), A-Train (50), Baron Baldric (70) | longer still |

Timers set by the 38: from 25 Hz (Cyberia) to 701 Hz (Blake Stone); 291.3
Hz (reload 4096) in all three Koei games; 50 Hz and 72.8 Hz are common.
Gateway 2 alternates PIT latch commands 00h and 01h in a tight loop,
842000 trapped accesses in the run: a timing loop, not sound
([findings.md](findings.md) B11).

The FM side and the timer of the engines are on [music-and-timers.md](music-and-timers.md):
Kyrandia and Dune II set the timer to 60 and then 72 Hz and write the
OPL2 with 27 status reads per write; Blake Stone 140 Hz and then 701 Hz
(its digital mixing), 41 reads per write; Wing Commander (Origin) 60 Hz
and about 1200 register writes a second with no status reads [trace].

## Games that ran without touching the card

In 35 s of running, with Enter and Space pressed, these made no Sound
Blaster access [trace]: Blake Stone, Commander Keen 4, Flashback, Gods,
Body Blow, Catacomb, Scorched Earth, Ultima VI, Golden Axe, Covert
Action, Wing Commander. Their menus are silent or their music is FM or
MIDI only; their digital sound comes later in play, if at all.
