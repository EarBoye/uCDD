# Sound engine reference library

How the sound engines of the DOS games in Michael's two libraries
(Action and Thinking, 838 games) talk to the hardware: what they detect,
how they find the IRQ and DMA, which DSP commands and transfer modes
they use, how they acknowledge, how they track the play position, and
what that asks of a card, real or virtual. Written so that a fault in a
game can be matched to its engine's habits before anything is patched.

Built 19 Oct 2026 from a scan of every game's files and port traces of
74 games in 86Box.

## The pages

| Page | What it covers |
|---|---|
| [hardware.md](hardware.md) | The DSP, mixer, 8237, 8259, OPL, MPU-401 and PIT, as the engines use them |
| [miles.md](miles.md) | Miles AIL 2 (.ADV), AIL/32 (A32*.ADV/.DLL) and the Miles Sound System 3 (.DIG/.MDI) |
| [hmi-sos.md](hmi-sos.md) | HMI's Sound Operating System, its driver library and device IDs |
| [dmx.md](dmx.md) | DMX (Doom, Heretic, Hexen, Strife, Raptor) |
| [apogee.md](apogee.md) | The Apogee Sound System (Duke 3D, ROTT, Shadow Warrior, Blood) |
| [digpak.md](digpak.md) | DigPak and MidPak |
| [sierra-sci.md](sierra-sci.md) | Sierra's SCI drivers (AUDBLAST, SNDBLAST, ADL) |
| [creative.md](creative.md) | Creative's CT-VOICE, CTVDSK, SBFMDRV, and the detection code games copied from them |
| [lucasarts.md](lucasarts.md) | iMUSE and LucasArts' digital drivers |
| [others.md](others.md) | DSMI, MIDAS, Allegro, Loudness, MicroProse, Sound Images, Melodix, Vision, DiamondWare, Origin, AdLib's driver, CMS/Tandy/Covox |
| [own-code.md](own-code.md) | The games with their own sound code, by class |
| [pre-sb16.md](pre-sb16.md) | The SB 1.x/2.0 and SB Pro: what each engine does when it meets one, from runs on uCDD's virtual SB Pro and SB 2.0 |
| [music-and-timers.md](music-and-timers.md) | The timer rate each engine sets, how it writes the FM chip (OPL2/OPL3, delays) and the MPU-401 |
| [symptoms.md](symptoms.md) | **Start here for a fault**: from what you hear or see to the engine habit or finding behind it |
| [findings.md](findings.md) | What the traces showed about uCDD: faults, behaviour to copy, questions for the CT2290 |
| [inventory.md](inventory.md) | Every game: its engine, the devices it names, whether it was traced |

## The families at a glance

| Family | Games | Traced | Finds the IRQ by | Transfer | Rate | Acknowledge | Position from |
|---|---|---|---|---|---|---|---|
| Miles MSS 3 and AIL/32 (SB16) | 134 in all | 23 | mixer 80h, a one-sample B0h probe | B6h/C6h auto-init, 2 blocks | 41h | 82h, 2xFh/2xEh | interrupts |
| Miles AIL 2 (SB Pro) | (above) | | a 4-byte 14h probe | 14h single-cycle | time constant | 2xEh | interrupts |
| HMI SOS | 83 | 8 | the config file | C4h/B4h auto-init, **FIFO off**, one block | 41h | 2xEh | **8237 count, polled** |
| Sierra SCI | 55 | 6 | a 1-byte 14h probe, IRQ 3/5/7 opened in turn | 14h, 16 KB blocks | time constant (41h on SCI1.1+) | 2xEh | interrupts; count read a byte at a time |
| DigPak / MidPak | 34 | 11 | the config file | C6h auto-init (SB16), 14h chained (SB Pro) | 41h / time constant | 82h, 2xFh **and** 2xEh | interrupts |
| Creative drivers | 31 | 9 | F2h, a short 14h, or 80h | 14h per VOC block | time constant | 2xEh | interrupts |
| Apogee SS | 13 (+1) | 7 | the config file | B6h auto-init, 4-block ring | 41h + 42h | 82h, 2xFh | **8237 address and page register** |
| DMX | 12 | 3 | F2h with IRQ 3, 4, 5, 7 open | C6h auto-init, demand mode, 16 blocks | 41h | 82h, 2xEh | interrupts + 2 count reads |
| iMUSE (LucasArts) | 5 | 3 | mixer 80h (older: F2h) | C6h auto-init | time constant | 2xEh | **8237 count, read twice** |
| DSMI, MIDAS | 10 | 3 | | one huge block over a small buffer | 42h or 41h, or high speed | rarely needed | **8237 count, polled** |
| Own code | about 475 | 6 | BLASTER, F2h, 14h or 80h | mostly 14h single-cycle | time constant | 2xEh | interrupts |

Games are counted once per family they carry (a game with Miles and HMI
counts in both); "Traced" counts games with a usable port trace. The
table is the SB16's; what each engine does on an SB Pro or SB 2.0 is in
[pre-sb16.md](pre-sb16.md).

**Four ways to know where the card is**, and each asks something
different of an emulated card: the interrupt alone (Miles, Sierra,
Creative, most own code); the 8237 count polled from a timer (HMI, DSMI,
MIDAS, iMUSE); the count read inside the interrupt handler (DMX); and
the 8237's address and page registers (Apogee). A card is only as good
as its worst answer to all four.

## Evidence grades

Every statement carries one:

| Grade | Meaning |
|---|---|
| [trace] | Seen in a port trace in 86Box (an emulator result) |
| [file] | Read from the game's own files: config files, driver headers, strings, tables |
| [doc] | A cited document (SBG is Creative's *Sound Blaster Series Hardware Programming Guide*) |
| [hw] | Measured on Michael's PC |
| [recall] | Background knowledge not checked here; to be confirmed before anything is built on it |

## How these notes were made

1. **The scan.** Every game folder's executables, overlays and driver
   files were searched for each engine's signature strings (copyright
   lines, library names, function names) and driver file names, and for
   the devices its code names (setup menu text) or touches (`mov dx`
   with a card's port, the speaker's PIT channel 2). Games with no
   program files on disk were scanned on their disc images.
2. **The traces.** A test build of uCDD logged every access the game
   made to the virtual card's ports, the 8237s and the PIC masks (first
   448 accesses in order, then the latest 192; repeats folded), and
   printed the log to LPT1, which 86Box writes to a file. Each game ran
   from its library launcher with its own configuration, 35 s, then
   Enter, Enter, Space, Enter.
3. **The set-up.** 86Box, a Pentium on the 430HX, MS-DOS 7.1, JemmEx,
   a Sound Blaster 16 at 220h, IRQ 7, DMA 1 and 5, MPU-401 at 330h; uCDD
   from the `vcpi-children` line with a 128-frame output period and a
   virtual SB16 (DSP 4.13) at the same resources, forced on; a serial
   mouse. IRQ 7 because the libraries' configurations assume it
   (DOSBox's default); some runs on IRQ 5 to check (findings.md, F1).
4. **The limits.** uCDD does not trap the OPL (388h) or the PIT, so the
   first traces have no FM music and no timer rates; a second build passed
   those ports through and counted them for 38 games
   ([music-and-timers.md](music-and-timers.md)); a third added the
   MPU-401 for 16 games set for MIDI. 35 s often ends in a
   menu: a game that plays its digital sound only in play shows only its
   detection. A trace can miss the steady state between the first 448
   and the last 192 accesses. A long log print holds interrupts off and
   can disturb timing (hmi-sos.md, Descent).

Where the traces and the documents disagree, the disagreement is
written beside the item, with both grades.
