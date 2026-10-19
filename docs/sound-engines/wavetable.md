# A wavetable board on the SB16: General MIDI through the MPU-401

Michael's CT2290 carries a Dreamblaster X2GS on its wavetable header: a
General MIDI and GS synthesiser fed from the card's MPU-401 at 330h. A
game set up for "General MIDI", "Roland Sound Canvas", "MPU-401",
"WaveBlaster" or "MT-32" sends MIDI bytes to 330h, and the board plays
them. This page is how the engines drive it. Grades as in the
[README](README.md#evidence-grades); the MIDI protocol facts are
[trace] unless marked.

## How it was emulated

- **Under uCDD (86Box):** the SB16's MPU-401 out to FluidSynth with a
  General MIDI and GS soundfont (eXo's SoundCanvas.sf2, a local copy,
  never committed), as a stand-in for the X2GS. The trace build counted
  the MPU-401 traffic; the recorded sound shows whether music played.
- **Without uCDD (DOSBox-X):** the games on DOSBox-X's SB16 with every
  byte to 330h logged, which shows the system exclusive messages each
  game sends at start-up ([methods.md](methods.md)).

The games were left as the libraries set them up: 17 already name a
MIDI device.

## Under uCDD: does the music play?

| Game | Engine, setting | Music in the recording (seconds over the noise, of about 60) |
|---|---|---|
| Sid and Al's Incredible Toons | Sierra GENMIDI.DRV | **58** |
| Amulets and Armor | HMI SOS, MPU-401 | **57** |
| Anvil of Dawn | HMI SOS, MPU-401 | music from 18 s (earlier run) |
| The Even More Incredible Machine | Sierra MT32.DRV | **27**, with General MIDI instruments (see below) |
| Theme Hospital | Miles MT32MPU.MDI | no note in 35 s: only its MT-32 set-up |

Without a synth on the MPU-401 the same runs recorded silence. With one,
uCDD passes the music through: the MPU-401's data ports are the physical
card's and uCDD does not trap them (vsb-spec.md 1). What uCDD does
handle is the MPU-401's interrupt, which on an SB16 shares the card's
line (ISSUES.md `sb16-mpu`).

## The protocol the engines use [trace]

| Engine | Set-up | Status reads per byte | System exclusive |
|---|---|---|---|
| HMI SOS (Toshinden, X-Car, Amulets and Armor, Anvil of Dawn) | FFh, 3Fh, the FEh acknowledge read back | 20 to 490 | **none**: General MIDI channel messages only; Toshinden and X-Car send 45 controller messages (a reset of every channel) |
| Miles MT32MPU.MDI (Theme Hospital) | FFh twice, 3Fh | **1** | **MT-32** (Roland model 16h): a reset of all parameters, then partial reserve and patch set-up |
| Sierra GENMIDI.DRV (Sid and Al) | FFh, 3Fh three times | 104-132 | **GS reset** (`F0 41 10 42 12 40 00 7F 00 41 F7`) |
| Sierra MT32.DRV (The Incredible Machine 2, The Even More Incredible Machine) | FFh, 3Fh three times | | **MT-32**: about 124 messages, custom timbres uploaded by name ("CS RHODES", "CS HARPSI", "CS AGOGO", "CS BRIGHTN") |

Every engine uses **UART mode** only (3Fh) and polls for its
acknowledges; none uses the MPU-401's intelligent mode or its interrupt.
No engine uses running status.

## What it means for the X2GS

- **General MIDI and GS games** (HMI's MPU-401 setting, Sierra's
  GENMIDI.DRV, Miles' MPU401.MDI, DMX's General MIDI, iMUSE's GMIDI.MDR)
  are what the board is for.
- **MT-32 games** send messages addressed to an MT-32 (model 16h). A
  General MIDI or GS synth ignores them [recall], so the music plays
  with the General MIDI instruments at the MT-32's program numbers: the
  wrong instruments, and the custom timbres missing. Set those games to
  General MIDI where their setup offers it. Whether the X2GS has an MT-32
  mode is not known here.
- uCDD's part is small: pass the data, and pass the MPU-401's
  interrupts on the shared line as the virtual SB16's (82h bit 2). No
  engine here waited for that interrupt; every acknowledge was polled.
