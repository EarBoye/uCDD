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
| `disk-irq-direct` | In every tested build, not tested alone. Replaced by `disk-irq-detect` |
| `disk-irq-detect` | Emulators only: PCI scan (QEMU with an AHCI controller on IRQ 11, DOSBox-X with and without a PCI bus), the mask in the driver and the host, the UCDDSET Disk row and warnings, old and new UCDDSET and UCDD mixed, Doom timedemo. The freeze it prevents needs a PCI controller that uses its IRQ in DOS, so that part needs real hardware and is not tested yet |
| `split-word-io` | In every tested build, not tested alone |
| `single-cycle-start` | Four fixes for single-cycle playback. Emulators only |
| `cue-far-buffer` | Emulators only: 111 CUE sheets against the old parser, and a mixed-mode image mounted, read and played under FreeDOS. Now part of `fixes`, because the driver segment is full without it |
| `wss-stop-vector` | The WSS and ESS stop put the old IRQ handler back on the wrong vector. It read `sb_irq` after `lds` had moved DS to the handler's segment, so it hooked vector (garbage + 8) and left the IRQ vector pointing into the program. Under MS-DOS 7.1 with the card on IRQ 7, that vector was 08h: the timer went to the IRQ 7 handler, which sends no end-of-interrupt for it, and the machine stopped taking interrupts after the UCDDSET Test (no keyboard). The freeze was seen on the real PC. The cause was traced in 86Box (ES1868, P55T2P4, MS-DOS 7.1, JemmEx), which freezes the same way; the fixed build passes there at IRQ 5 and 7, with the Test run twice. Not yet run on the real PC. The resident driver reaches this code only when activation fails or on removal |
| `setup-audit` | A review of UCDDSET after `wss-stop-vector`, by reading and by three independent reviews of the same sources. Fixed, in the shared sound code: the SB Pro start waited for its priming interrupt by counting loop turns (CPU speed decided the timeout; now each turn reads a port); `pro_stop` reset the DSP with the IRQ still live (a DSP 1.xx block end in that window ran DSP writes from the handler; the IRQ is masked first now); the real-mode handler took any IRQ 7 as the card's on the SB Pro and SB 2.0 models and chained it to DOS on the others (now the in-service bit is checked, as the host and Detect already did); the WSS codec start unmasked the IRQ before clearing a codec interrupt left from before. In UCDDSET: no INT 23h or 24h handler, so with BREAK=ON a Ctrl+Break during a DOS call ended the program with the sound IRQ, INT 9 or the detection vectors still hooked (both installed now); `blaster_build` copied a kept BLASTER field with no bound (a field of 9 or more characters late in the value ran past the 96-byte buffer; a field that does not fit is dropped now); the screen was written to B800h in mode 3 whatever the adapter (blank on MDA and Hercules, blinking on CGA; now mode 7 and B000h there, blink off through the 6845 port, and the previous text mode and 43/50 lines put back on exit); the tick waits read as elapsed the reset at midnight; `speaker_test` freed segment 0 when its allocation had failed; no CPU check before 386 instructions; the detection's 8237 programming ran with interrupts on; two messages. Checked in 86Box (ES1868, MS-DOS 7.1): the Test twice at IRQ 5 and 7 (ESS fast), once as SB Pro and SB 2.0; Hercules (blank before, dialog now) and CGA; an empty environment (fine before and after: MS-DOS copies it as two zero bytes, so the review's claim was wrong); a 100-character BLASTER field at install. QEMU: Doom under the host at physical IRQ 7 and 5 unchanged. DOSBox-X and QEMU regression suite: see the commit. Not tested: the priming timeout on a GHz CPU (reasoning only), Ctrl+Break itself |

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
- Sierra's AUDBLAST.DRV waits 2048 loop passes for its test interrupt.
  That is too short for any card on a fast CPU, so King's Quest V still
  needs the wait patched, with or without this driver.
- Protected-mode games cannot be tested in DOSBox-X: the host uses the
  debug registers, which that emulator does not act on.

## Fixed after a review of UCDD.EXE

A review of the whole driver source (five independent readings of the
driver, the port trap and card emulation, the mixer and CD streaming, the
host IRQ path, and the DPMI services) found these. All are fixed in
`disk-irq-detect` and checked by assembly only so far; none has run on
hardware or in an emulator yet.

- A disc hotkey (MDM list, or eject and insert of a single image) bound the
  new disc for CD audio from the timer tick and from the request entry, and
  the seek-cache warm in that path read the image through DOS with the
  game's PSP and without saving the DOS state. With the game's file open on
  the same handle number its file pointer moved; from a request that came
  through DOS, DOS was re-entered without the SDA swap. The bind now runs
  inside `dos_enter`, and the timer does not switch discs while the BIOS
  disk code runs.
- With `BREAK=ON`, Ctrl+C or Ctrl+Break during a CD read reached the
  default INT 23h handler with the resident's PSP current, which ended the
  resident. `dos_enter` now points INT 23h at an `iret` and `dos_leave`
  puts it back, as it already did for INT 24h.
- A refused DSP command or argument (a rate outside 4000 to 48000 Hz, a
  block shorter than two output periods, an unsupported mode byte) left the
  argument counter set, so the bytes the game wrote next were taken as
  arguments. The counter is cleared now. The refusal of a short block that
  "The output period decides which games have sound" describes was never
  silent for the DSP command stream.
- A refused rate was already stored, and a rate of 0 later divided in the
  silence command and the single-cycle block start. The rate is checked
  first now.
- DAh/D9h (exit auto-initialize) was dropped while the stream was paused
  with D0h/D5h. It is held and applied at the resume, as the DSP does.
- `UCDD -unmount NAME.CUE` never matched, because the mount stores the name
  of the BIN file. The unmount resolves a CUE sheet the same way.
- `UCDD -install` failed with "UCDDSET.EXE cannot be started" on a DOS
  that cannot link UMBs (no `DOS=UMB`, or FreeDOS). The UMBs are unlinked
  only when they are linked, and a refusal is not an error.
- The interpolation of the last CD frame of a half read one frame past the
  data loaded when the output rate is above 44100 Hz (SB 2.0, ESS); two
  frames are loaded past the take now.
- The spurious IRQ 7 check in the physical interrupt handler put the PIC
  read register back to IRR whatever the game had selected (visible under
  EMM386 only).
- An installation that failed with the trap code kept in memory did not
  free its environment block.
- The internal host loader did not accept the one-zero-byte empty
  environment that `config_path_init` accepts.
- A read request whose transfer address ends above 1 MiB returns general
  failure (0Ch), not sector not found.
- UCDDSET: the Disk row text stops before the IRQ field.
- README: `-units` applies to the data-only driver; the audio driver takes
  one drive.

Not changed, by design or because a safe change needs more than a review:

- The virtual WSS codec raises its interrupts through the DPMI host only.
  A real-mode game on the virtual WSS codec waits for an interrupt that
  never comes. Delivering it in real mode needs the slave PIC in the
  real-mode virtual PIC, which emulates one master input today.
- The 8237 emulation accepts the single and auto-initialize modes that
  Sound Blaster drivers program (49h, 59h, 45h, 55h). Demand and block
  modes set the fault byte.

