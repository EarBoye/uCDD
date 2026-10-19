# Games with their own sound code

About 470 of the 838 games carry no known engine: their sound is the
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

The FM side and the timer are on [music-and-timers.md](music-and-timers.md):
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
