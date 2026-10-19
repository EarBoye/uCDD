# From a symptom to its cause

Start here when a game's sound misbehaves under uCDD. Find what you hear
or see, then read the engine page and the item named. The causes are
those seen in this library's traces and in the fork's notes; each line
gives where the evidence is. Find the game's engine first in the
[inventory](inventory.md).

## No digital sound at all

| Seen with | Likely cause | Where |
|---|---|---|
| A 1994 Miles game (Warcraft, System Shock), card and virtual card on the same IRQ 7 | the probe interrupt never reaches the game's handler; the driver gives up after four tries | [findings.md](findings.md) F1 |
| Any game with very short blocks (Hocus Pocus, probably Blood at 44 kHz, DMX on a virtual SB Pro) | a block shorter than two output periods is refused; the game gets no interrupt | ISSUES.md, output period table; [apogee.md](apogee.md), [dmx.md](dmx.md) |
| An HMI game whose config names a different IRQ or card than the BLASTER line | HMI never detects: it uses the config's device ID and IRQ as written | [hmi-sos.md](hmi-sos.md), files and configuration |
| King's Quest V and other Sierra SCI1 games | AUDBLAST's fixed 2048-pass wait for its test interrupt is too short on a fast CPU (the library carries a patched driver) | [sierra-sci.md](sierra-sci.md) |
| A game that finds the IRQ with F2h (Miles counts the interrupts one by one) | an F2h whose interrupt comes inside the write, or two at once, fails the count (seen and fixed on the virtual ESS, 15 Oct) | [miles.md](miles.md), the F2h test |
| A game set up for an SB16 (most of the library: eXo's default) on a virtual SB Pro or SB 2.0 | its engine was given an SB16 driver by its configuration (HMI device ID, Miles DIG.INI, DigPak SOUNDRV.COM): it sends SB16 commands or gives up, as on a real older card. Run the game's own setup for the card | [pre-sb16.md](pre-sb16.md) |
| SB Pro stereo games on a virtual SB Pro (Doom, Hexen, Rayman, Stargunner) with both cards on IRQ 7 | the stereo transfer never starts | [findings.md](findings.md) F4 |
| C-Dogs, on any card | it sends 90h before setting up the DMA channel; uCDD never starts that transfer | [findings.md](findings.md) F5 |
| A game whose AIL 2, Westwood or own SB Pro code tests the mixer, on a virtual SB 2.0 | the SB 2.0 has no mixer, so the game finds no card | [pre-sb16.md](pre-sb16.md) |
| A DigPak game where the loader says "Load Failed" | not shown to be the card: Simon the Sorcerer's loader failed so in 86Box; cause not looked at | [digpak.md](digpak.md) |

## Clicks, crackle, repeats

| Seen with | Likely cause | Where |
|---|---|---|
| HMI games (Descent 2) | the engine mixes up to the DMA count it reads; a count ahead of what is heard lets it overwrite unplayed frames | [hmi-sos.md](hmi-sos.md), ISSUES.md `ess-position`, `virtual-timing` |
| iMUSE, DMX, MIDAS, DSMI games | a polled count that steps back (seen in 86Box, timing-sensitive) | [findings.md](findings.md) F2 |
| Games that read the count twice until they agree (Battle Race 95) | the virtual count moves between the two reads, so they never agree: a hang, not a click | [others.md](others.md), host-cdrom-spec.md section 10 |

## Sound stops after a while

| Seen with | Likely cause | Where |
|---|---|---|
| A game that leaves its interrupt unacknowledged for seconds (Mortal Kombat Trilogy's Miles driver) | something else waiting for that EOI (uCDD's CD refill did, fixed as M-12) | [miles.md](miles.md); host-cdrom-spec.md M-12 |
| A game whose IRQ setting does not match the card | the virtual interrupt is raised on a line the game keeps masked; Descent's count stalled that way, but only with the trace build and a shared IRQ 7 | [hmi-sos.md](hmi-sos.md), "Not settled" |
| A game using the MPU-401 on an SB16 | the MPU's interrupt shares the card's line (fixed in `sb16-mpu`) | ISSUES.md `sb16-mpu` |

## Mono where stereo was expected

| Seen with | Likely cause | Where |
|---|---|---|
| A game set for "Sound Blaster Pro" played on an SB16 or the virtual SB16 (Rayman's HMI SB Pro module) | SB Pro stereo is switched on with mixer 0Eh bit 1; the SB16 has no register 0Eh (the CT2290 reads 00h), so the game plays its interleaved stream as mono, at the right pitch. The real card does the same: set the game to SB16 if it offers it | [findings.md](findings.md) B12, vsb-spec.md 9.4 |

## Music wrong (FM)

| Seen with | Likely cause | Where |
|---|---|---|
| Missing or wrong notes in Wing Commander, Tyrian, Jill of the Jungle, Pizza Tycoon, Monkey Island | they write the FM chip with no delay; a real OPL2 cannot keep up with a fast CPU (uCDD is not involved: it does not trap the FM ports) | [music-and-timers.md](music-and-timers.md) |
| Half the notes missing in an OPL3 game (HMI, Apogee, Miles 3, King's Quest VI) | the game is set for OPL3 on a card with an OPL2 | [music-and-timers.md](music-and-timers.md) |
| Music at the wrong speed | the engine's timer rate (35 Hz to 701 Hz) is not kept: lost or late timer interrupts | [music-and-timers.md](music-and-timers.md), the timer table |

## A hang or a crash at the sound set-up

| Seen with | Likely cause | Where |
|---|---|---|
| A DOS/4GW game that stops early with a divide error (Shellshock) | the host's stepping of interrupts-off regions (D-8) makes the game's PIT clock read 3 ms back | host-cdrom-spec.md D-8, ISSUES.md |
| Battle Race 95 at its loading screen | its "two reads agree" count loop under the host | host-cdrom-spec.md section 10 |

## Possible, not seen

| Seen with | Possible cause | Where |
|---|---|---|
| Games that write the master PIC mask 00h (DigPak SB16, Cool Spot, Sound Images) | every line opened behind the driver's back; a line without a handler reaches the BIOS default | [findings.md](findings.md) B9 |
| A game run after a DigPak SB16 game | DigPak writes mixer 81h; on a software-configured SB16 that changes the card's DMA setting (the virtual card ignores it) | [digpak.md](digpak.md), [findings.md](findings.md) M2 |

## Before patching anything

1. Find the engine ([inventory](inventory.md)) and read its page's
   "What uCDD needs" table: most faults are one of those lines.
2. Check the game's own sound config against the card (IRQ, DMA, device
   ID): several engines never detect.
3. Trace it: the method is in the [README](README.md#how-these-notes-were-made).
4. Rule 1: if the game breaks the specification, the real card's answer
   is the answer; no special case.
