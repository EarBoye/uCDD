# State of this fork

## How things were tested

**Real hardware:** Pentium MMX 233, ECS P5HX-A (430HX), 64 MB, ESS ES1868
at A220 I5 D1, S3 Trio64V+, Voodoo 1, Promise Ultra133 TX2, MS-DOS 7.1,
JemmEx, SHSUCDX. All of these tests were made on 0.9.3a, and the combined
build was run again after the rebase on 0.9.3b.

**Emulators:** FreeDOS with JemmEx 5.86 and SHSUCDX 3.09 in QEMU (SB16 and
CS4231A, protected-mode games, memory snapshots) and in DOSBox-X (SB16,
SB Pro, ES688, recorded audio). Test programs play known signals and run
the detection code of real game drivers; the recorded output is checked
for gaps and steps.

## Branches

| Branch | State |
| --- | --- |
| `disc-header-tolerance` | Tested on hardware |
| `flat-pointer-reflection` | Tested on hardware |
| `cd-refill-large-periods` | Tested on hardware |
| `ess-native-output` | Tested on hardware, ES1868 only. The half-rate alignment fix on top is tested in an emulator only |
| `cli-patterns` | Tested on hardware, benefit only partly confirmed |
| `disk-irq-direct` | In every tested build, not tested alone |
| `split-word-io` | In every tested build, not tested alone |
| `single-cycle-start` | Four fixes for single-cycle playback. Emulators only |
| `cue-far-buffer` | Emulators only: 111 CUE sheets against the old parser, and a mixed-mode image mounted, read and played under FreeDOS. Now part of `fixes`, because the driver segment is full without it |

## The output period decides which games have sound

The mixer reads game data up to two output periods ahead, so the driver
refuses an auto-initialize block that lasts less than two periods. The
refusal is silent: the game gets no sound and no interrupt.

| `--audio-period-frames` | Shortest block accepted | Examples that fall below it |
| --- | --- | --- |
| 32 (default) | 1.5 ms | none known |
| 64 | 2.9 ms | none known |
| 128 | 5.8 ms | 256-frame blocks above 44.1 kHz |
| 256 | 11.6 ms | DMX on a virtual SB Pro (Doom, Heretic, Hexen: 128 stereo frames at 11.1 kHz is 11.5 ms). Any 256-frame block at 22.2 kHz or faster. From its source, the Apogee Sound System uses 256-frame blocks, so its 44 kHz setting should fall below this too (not tested) |

A larger period costs less CPU time on every card, and on the ES1868 it
is what makes Sound Blaster Pro output work at all. The combined build was
tested at 256. Measured in an emulator: Doom with a virtual SB Pro is
silent at 256 and has sound at 128.

## Slow CPUs

Measured in QEMU with an instruction-counted clock, SB16, unmodified
0.9.3b. Every instruction takes the same time there, so a real 386, where
a multiply is slow, does worse than these figures. "CPU taken" is the
share of a counting loop's passes lost over five seconds.

| Speed | Period | CPU taken, nothing playing | CPU taken, CD audio playing |
| --- | --- | --- | --- |
| 128 ns per instruction (7.8 MIPS, a fast 386) | 32 | 18.5 % | 32.8 % |
| | 64 | 6.0 % | 26.5 % |
| | 128 | 6.1 % | 22.7 % |
| | 256 | 3.7 % | 21.0 % |
| 256 ns per instruction (3.9 MIPS, a 386SX) | 256 | 6.0 % | 81.2 % |

At 256 ns per instruction a Sound Blaster detection sequence (reset,
version, one-byte block) does not finish with the driver loaded. This is
the same on unmodified 0.9.3b and is not investigated. With a 32-frame
period the measurement itself did not finish at that speed.

At 128 ns per instruction and a 32-frame period, the port trap lasts
longer than one output period. The last fix in `single-cycle-start` is
for that case.

## Not solved

- Hexen: the machine sometimes freezes after the game exits. The launcher
  log shows the game returned and the image was unmounted first. A test
  client that makes Hexen's CD calls, followed by a second protected-mode
  program, does not reproduce it in QEMU.
- Mortal Kombat Trilogy hangs at the Battle screen, at a CD track change.
- The Need for Speed SE hangs while it loads a race. It also hangs with
  the data-only driver, so this is probably not the audio host.
- Descent II: crackle in the intro audio with every build tested on
  hardware. The filter fix in `single-cycle-start` removes a click of this
  kind in an emulator; whether it is the same fault is not known.
- A 512-frame output period is not usable.
- A flat pointer passed to a reflected real-mode service no longer
  corrupts memory, but the service still cannot return data to the client.
- `UCDD -install` stops with "UCDDSET.EXE cannot be started" when DOS has
  no upper memory to link (FreeDOS refuses INT 21h AX=5803h). Seen in
  DOSBox-X until JemmEx was given `I=D000-EFFF`.
- Sierra's AUDBLAST.DRV waits 2048 loop passes for its test interrupt.
  That is too short for any card on a fast CPU, so King's Quest V still
  needs the wait patched, with or without this driver.
- Protected-mode games cannot be tested in DOSBox-X: the host uses the
  debug registers, which that emulator does not act on.
