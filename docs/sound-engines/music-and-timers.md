# Music and timers: the FM chip and the PIT

The other half of every engine: the music on the OPL (FM) chip and the
timer that drives it. A second trace build passed the PIT (40h, 43h) and
the FM ports (388h-38Bh, 2x0h-2x3h, 2x8h-2x9h) straight to the hardware
and counted them: every timer write in the log, every FM register write
counted by register group and bank, every FM status read counted. 38
games, 35 s plus four keys each, in 86Box (the set-up in the
[README](README.md#how-these-notes-were-made)). Everything on this page
is [trace] unless it says otherwise.

uCDD itself does not trap these ports: a game's FM writes and timer
writes reach the card and the PIT directly, at full speed. The DPMI host
traps 40h and 43h only for its retrace hint (host-cdrom-spec.md); then a
latch and its reads each cost a trap.

## The timer each engine sets

The PIT's channel 0, programmed through 43h (mode byte) and 40h (reload,
low then high byte). Rate = 1193182 / reload; 0 or 65536 is 18.2 Hz, the
BIOS rate. Mode 2 is the rate generator, mode 3 the square wave; both
interrupt once per period.

| Engine | Game | Mode, reload | Rate | Other |
|---|---|---|---|---|
| DMX | Doom, Hexen | 3, 8522 | **140.0 Hz** | |
| Apogee SS | Duke Nukem 3D | 3, 9933 | **120.1 Hz** | |
| Apogee SS | Rise of the Triad | 3, 34058 / 4966 / 3725 | 35.0, then 240.3, then 320.3 Hz | changes with the game state |
| HMI SOS | Descent | 2, 9943 | **120.0 Hz** | 256 latches (counter reads) |
| HMI SOS | Tomb Raider | 3, 9943 | 120.0 Hz | |
| HMI SOS | Screamer | 3, 11931 | 100.0 Hz | |
| Miles MSS 3 | Albion, Dungeon Keeper | 2, 5966 | **200.0 Hz** | 31246 and 3514 latches: Albion reads the counter about 500 times a second |
| Miles MSS 3 | Warcraft | 3, 5966 | 200.0 Hz | |
| Miles MSS 3 | System Shock | 3, 4261 | 280.0 Hz | |
| Miles (LBA) | Little Big Adventure | 3, 9943 | 120.0 Hz | |
| DigPak/MidPak | X-COM UFO Defense | 3, 8522 | 140.0 Hz, then 18.2 Hz | 512 latches |
| Sierra SCI | King's Quest V, VI, Police Quest 3, Larry 2 | 3, 19886 | **60.0 Hz** | the same in SCI0, SCI1 and SCI1.1 |
| Westwood | Kyrandia, Dune II | 3, 19887, then 16572 | 60.0, then 72.0 Hz | |
| Origin | Wing Commander | 3, 19886 | 60.0 Hz, back to 18.2 Hz and to 60 Hz again several times | 2652 latches |
| Creative drivers | Monkey Island, Xargon, Jill of the Jungle, Pizza Tycoon | 3, **7000** | **170.5 Hz** first in all four | then their own: Xargon and Jill 96.0 Hz (12428), Pizza Tycoon 192.0 and 64.0 Hz; Monkey Island back and forth to 18.2 Hz |
| Epic Pinball | | 3, 21845 | 54.6 Hz | twice, with 18.2 Hz between |
| MicroProse | Darklands | 2, 17024 | 70.1 Hz | |
| Loudness SS | Tyrian | 3, 17152 | 69.6 Hz | |
| DSMI | C-Dogs | 3, 11931, then 2130 | 100.0, then **560.2 Hz** | the mixing rate |
| own (Blake Stone) | | 3, 8514, then 1702 | 140.1, then **701.0 Hz** | |

The 170.5 Hz first rate in every game that carries Creative's drivers
suggests it is the drivers' own (SBFMDRV or CT-VOICE) [trace,
correlation only]. Rates of 500 Hz and more come from engines that mix
digital sound in the timer handler (DSMI, Blake Stone).

## How each engine writes the FM chip

"Status reads" are reads of 388h (or 2x8h) between register writes: the
OPL2 needs time after each write (3.3 us after the index, 23 us after the
data, Yamaha's figures [recall]) and reading the status port is the
usual delay, about 1 us an ISA read. "OPL3" means writes to the second
register bank (38Ah/38Bh) and to register 105h (the OPL3 enable).

| Engine | Game | Writes/s | Status reads per write | Chip use | Pattern |
|---|---|---|---|---|---|
| DMX | Doom | 120 | 30 | OPL2 only | the whole instrument (20h, 40h, 60h, 80h, E0h, C0h) rewritten for every note |
| HMI SOS | Descent | 834 | 31.5 | **OPL3**, both banks written alike | heavy on 80h-9Fh (sustain/release: 11101 a bank) |
| Apogee SS | Duke Nukem 3D | 431 | 33 | **OPL3**, both banks | |
| Apogee SS | Rise of the Triad | 44 | 33 | OPL2 only | |
| Miles (MSS 3 OPL3.MDI) | System Shock, Warcraft | 211-439 | **14** | **OPL3**, both banks | 26 writes to 06h-1Fh and 9 to the timers at start (the detection) |
| Miles (AIL 2 via MidPak) | Capitalism | 100 | 14 | OPL3, both banks | the same start as MSS 3: the same FM code |
| Miles (LBA) | Little Big Adventure | 131 | 14.5 | OPL3, both banks | |
| DigPak/MidPak | X-COM UFO Defense | 138 | 40 | OPL2 only | |
| Sierra SCI1 | King's Quest V, Police Quest 3 | 65 | 38 | OPL2 only | |
| Sierra SCI1.1 | King's Quest VI CD | 408 | 38 | OPL3, **both banks identical** (the same counts in every group) | |
| Sierra SCI0 | Larry 2 | 121 | 43 | OPL2 only | |
| Westwood | Kyrandia, Dune II | 38-45 | 27 | OPL2 only | |
| Origin | Wing Commander | **1236** | **0** | OPL2 only | 33453 writes each to A0h-AFh and B0h-BCh: every channel's pitch rewritten every tick |
| Loudness SS | Tyrian | 299 | **0** | OPL2 only | levels (8266) and pitches (6312): software envelopes and effects |
| Creative-era | Xargon | 46 | **77** | OPL2 only | rhythm mode (BDh, 315 writes) |
| Creative-era | Jill of the Jungle | 48 | **0** | OPL2 only | rhythm mode (BDh, 589 writes) |
| Creative-era | Pizza Tycoon | 49 | **0** | OPL2 only | rhythm mode (362) |
| LucasArts | Monkey Island | 728 (one burst) | **0** | OPL2 only | |
| Epic Pinball | | 34 | 41 | OPL2 only | |
| MicroProse | Darklands | 90 | 25 | **OPL3**, the second bank mostly levels | |
| own (Blake Stone) | | 45 | 41 | OPL2 only | |

No FM in these runs: Albion, Dungeon Keeper, Tomb Raider, Screamer,
Hexen (CD music: `snd_musicdevice 10`), TIE Fighter (General MIDI in its
IMUSE.INI), Castles II, SimCity, 7th Guest (no music in 35 s), C-Dogs.

### What it means for a card

- **No-delay writers** (Wing Commander, Tyrian, Jill, Pizza Tycoon,
  Monkey Island) wrote the chip with no status read between writes. On a
  real OPL2 a fast CPU then outruns the chip's 23 us, and notes are lost
  or wrong; an OPL3 needs far shorter waits [recall]. The engines were
  written for a 286 or 386, where the instructions between writes were
  the delay. On the CT2290 this is the FM chip's business, not uCDD's,
  which never sees these writes.
- **Delay readers** take 14 to 77 ISA reads per register write: Descent's
  834 writes a second cost 26000 status reads a second, about 26 ms of
  bus time every second, in the game's timer handler.
- **OPL3 games** (HMI, Apogee, Miles 3, SCI1.1, MicroProse) switch the chip
  into OPL3 mode with 105h and write both banks; the SB Pro 2 and SB16 have
  an OPL3, the SB 1.x/2.0 one OPL2 and the SB Pro 1 two [recall]. A game
  set for OPL3 on an OPL2 card loses the notes it sends to the second bank.

## Detection of the FM chip

Every FM engine starts with the AdLib timer test [trace: the 02h-04h
writes at the start of each run]: reset both timers (04h=60h, 04h=80h),
read the status, start timer 1 with 02h=FFh and 04h=21h, wait, read the
status again (C0h expected), reset. Miles and LBA add 26 writes to
06h-1Fh (clearing the registers) and 4 to the second bank's timers, the
OPL3 test.
