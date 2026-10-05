# Open problems in this fork

Test machine: Pentium MMX 233, ECS P5HX-A (430HX), 64 MB, ESS ES1868 at
A220 I5 D1, S3 Trio64V+, Voodoo 1, Promise Ultra133 TX2, MS-DOS 7.1,
JemmEx, SHSUCDX.

## Branches

| Branch | State |
| --- | --- |
| `disc-header-tolerance` | Tested on hardware |
| `flat-pointer-reflection` | Tested on hardware |
| `cd-refill-large-periods` | Tested on hardware |
| `ess-native-output` | Tested on hardware, ES1868 only |
| `cli-patterns` | Tested on hardware, benefit only partly confirmed |
| `disk-irq-direct` | In every tested build, not tested alone |
| `split-word-io` | In every tested build, not tested alone |
| `cue-far-buffer` | Emulator only. Not in `fixes` |

All hardware tests were made on 0.9.3a. The branches are rebased on
0.9.3b and assemble, but the 0.9.3b builds are not yet run on hardware.

## Not solved

- Mortal Kombat Trilogy hangs at the Battle screen, at a CD track change.
- The Need for Speed SE hangs while it loads a race. It also hangs with
  the data-only driver, so this is probably not the audio host.
- Descent II: crackle in the intro audio with every build.
- Doom: no sound effects with a virtual Sound Blaster Pro on the ESS output.
- A 512-frame output period loses Doom sound effects. 256 is the limit.
- A flat pointer passed to a reflected real-mode service no longer
  corrupts memory, but the service still cannot return data to the client.
