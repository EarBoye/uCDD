# How to probe a sound engine

The methods this library was built with, what each one tells, and the
ones considered and not used. Each method answers a different question;
the strongest results come from two of them agreeing. Grades as in the
[README](README.md#evidence-grades).

## Used

| Method | Question it answers | Tool | Cost | Limits |
|---|---|---|---|---|
| **Signature scan** | which engine a game carries | strings and driver file names in every game folder (and the disc images of disc-only games) | minutes for 838 games | packed executables hide strings; a disc can carry other programs |
| **Driver census** | which games run the *same* driver binary | an MD5 of every driver file, grouped ([census.md](census.md)) | seconds | engines linked into the game have no file |
| **Port trace through uCDD** | what the engine sends the card and in what order, against uCDD's virtual card | a logging build of the driver: every trapped access, first 448 in order plus a ring, printed to LPT1 in 86Box | 75 s a game, 4 at a time | only what uCDD traps; a long log print holds interrupts off; the virtual card's own faults shape what follows |
| **Pass-through counters** | the timer rate, FM habits, MPU-401 traffic | the same build trapping the PIT, the FM ports and 330h/331h, passing them to the hardware and counting ([music-and-timers.md](music-and-timers.md)) | as above | heavy FM games run slowly; counts, not order |
| **Virtual card perturbation** | how the engine reacts to an older card | uCDD's virtual SB Pro and SB 2.0 with a matching BLASTER ([pre-sb16.md](pre-sb16.md)) | as above | only the models uCDD presents |
| **Reference emulator spy** | what the engine does on each real card model, with timing | DOSBox-X with a port log stamped with emulated time: SB 1.0, 2.0, Pro 1, Pro 2, 16 ([family.md](family.md)) | 45 s a run, 6 at a time | DOSBox-X's cards, not Creative's; no uCDD involved |
| **Differential testing** | whether a fault is uCDD's or the game's | the same game on uCDD's virtual card and on DOSBox-X's card of that model | one run each | two emulators, not hardware: a disagreement still needs the CT2290 |
| **Compatibility perturbation** | which input the engine believes: BLASTER, the DSP version, the mixer, or its own configuration | DOSBox-X's SB16 with BLASTER claiming an older card or missing; the game's own configuration switched to another card's driver ([family.md](family.md)) | as the spy | one change at a time |
| **Wavetable emulation** | how engines drive a General MIDI board on the SB16's header | 86Box's MPU-401 to FluidSynth with a GM soundfont under uCDD; DOSBox-X logging the MPU-401 bytes ([wavetable.md](wavetable.md)) | as the trace | a soft synth stands in for the X2GS |
| **Random sampling** | whether the named engines cover the rest | 75 own-code games drawn at random ([own-code.md](own-code.md)) | one batch | 35 s often ends in a silent menu |
| **Recording comparison** | whether what is heard is right: the CD music and the game's own sound, each against a recording made without uCDD | the CD track taken out of the recording (known to the sample), the game's sound placed in 40 ms pieces against the reference; speed, repeats and losses per sound, and spectrograms ([symptoms.md](symptoms.md), checking a recording) | minutes | needs a CD track playing; a phone recording keeps some music in it; random sounds match weakly |
| **Hardware probe** | what the real card does, with timing: rates, when interrupts come, the count at each, the DSP's response times, the mixer's writable bits, FM timers, the MPU-401 line rate ([ct2290.md](ct2290.md)) | HWPROBE: a silent DOS program, run on the bare card and again through uCDD with a disc mounted, TSC timed | 20 s a run | one card, one chipset; a game's own code still needs a game run |
| **Driver file reading** | the driver's own tables and strings | HMI's device ID table, AIL 2's function table, DIG.INI, RESOURCE.CFG | minutes | says what is there, not what runs |

## Considered, not used yet

| Method | What it would add | Why not now |
|---|---|---|
| **Disassembly of a driver** (ndisasm on a .DIG, an HMI module, SOUNDRV.COM) | the exact detection logic: which versions are accepted, how long a probe waits, what 83h is for | an hour or more per driver; worth it for one question at a time (F1: the 1994 SB16.DIG's probe wait; HMI's 83h write) |
| **Fault injection** (the virtual card answering wrongly on purpose: a late interrupt, another version, no mixer) | the engine's timeouts and fallbacks | test builds of uCDD, and the answers are not the real card's |
| **A spy on the real PC** (uCDD trapping and passing every access through to the CT2290) | the engines against Michael's actual card, the final reference | uCDD steps aside by putting its DPMI host to sleep, so protected-mode games could not be watched; a pass-through mode that keeps the host is a sizeable change |
| **Waveform comparison** (the recorded output of the bare card and of uCDD, aligned) | whether the sound is right, not only whether the transfer ran | intros differ run to run; worth it for chosen games |
| **Interrupt timing** (the request at the PIC against the game's acknowledge) | how long each engine's handler takes and how long an interrupt stays open | DOSBox-X's log has the acknowledges but not the requests; a small addition to the logger |
| **86Box with its own device logs** | the same spy on 86Box's cards | the AppImage is a release build without them; a source build would mean a download |

## Practical notes

- One change per run. Two runs of the same game sharing a virtual
  display sent keys and screenshots to the wrong game until the runner
  let Xvfb pick a free display (19 Oct): an earlier Xargon result was that.
- The game's own configuration decides more than the card does. Check it
  before reading meaning into a trace (Descent's DESCENT.CFG names IRQ 5;
  eXo set most games for an SB16).
- Count reads come in pairs after a flip-flop clear, except where the
  engine reads one byte per poll (Sierra's AUDBLAST): pair them before
  calling a count backwards.
