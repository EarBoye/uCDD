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

## Changes

Each change was made on a branch of its own and folded into `fixes`. The
branch names stay as the names of the changes.

| Change | State |
| --- | --- |
| `disc-header-tolerance` | Tested on hardware |
| `flat-pointer-reflection` | Tested on hardware |
| `cd-refill-large-periods` | Tested on hardware |
| `ess-native-output` | Tested on hardware, ES1868 only. The half-rate alignment fix on top is tested in an emulator only |
| `cli-patterns` | Tested on hardware, benefit only partly confirmed |
| `disk-irq-direct` | In every tested build, not tested alone. Replaced by `disk-irq-detect` |
| `disk-irq-detect` | Emulators only, in the first form: PCI scan (QEMU with an AHCI controller on IRQ 11, DOSBox-X with and without a PCI bus), the mask in the driver and the host, the UCDDSET Disk row and warnings, old and new UCDDSET and UCDD mixed, Doom timedemo. The scan has since moved from UCDDSET into `UCDD -install` (the driver learns the machine's controllers itself; UCDDSET keeps the Disk row and the IRQ set by hand) and was run again in the rig: QEMU with the AHCI controller prints "Disk controller IRQs go to DOS directly: 11 14 15" and the driver and host masks read 11 14 15; `UCDDPCI=OFF` gives 14 15; DOSBox-X with and without a PCI bus prints nothing, and a manual IRQ 9 gives 9 14 15; the UCDDSET Disk row shows "PCI on IRQ 11" and warns about the virtual WSS on IRQ 11. The freeze it prevents needs a PCI controller that uses its IRQ in DOS, so that part needs real hardware and is not tested yet |
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
`fixes`. Checked in the emulator rig (FreeDOS, JemmEx, SHSUCDX in QEMU and
DOSBox-X), each against the build before the review (0f81195): the hotkey
disc change and the eject and insert of one image with twelve handles open
on one file (the file position no longer jumps to 0); E1h after a refused
short block at 256 frames (replies 04.05, no reply before); D0h, DAh, D4h
on an auto-initialize stream (the block ends after the resume, looped
before); `UCDD -install` without `DOS=UMB` (installs, failed before); Doom
timedemo under the host unchanged. Not covered: Ctrl+Break with BREAK=ON
(FreeDOS does not run the break check in those calls, so this needs
MS-DOS), and the DPMI host changes beyond the Doom regression (a parent
callback during a child program, a client ending with INT 20h); the
Batman Forever and Toshinden programs were not at hand. Nothing has run on
the real PC yet.

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
- DPMI host: a real-mode callback of a suspended parent (a mouse event
  handler armed before the parent started a child program) ended the child.
  The stub now returns to its caller with the registers unchanged when the
  slot is not the running client's. The decision between an interrupt frame
  and a far call is made from the IVT and the shape of the flags word, so
  it is a heuristic; the parent's slots are kept off limits to the child.
- DPMI host: INT 20h and INT 21h AH=00h or AH=31h from a client ended the
  DOS process under the host and leaked its memory. They end the client as
  AH=4Ch does.
- DPMI host: 0800h maps a physical range below 1 MiB to itself instead of
  refusing it; 0801h accepts such an address.
- DPMI host: the hardware PIC masks a child left behind are put back to the
  parent's when the child exits.
- The virtual PIC, in the host and in the driver, accepts the rotate forms
  of the end-of-interrupt commands, set priority, special mask mode and
  poll, which faulted the client before. ICW1 still does.
- DPMI host: the slave PIC read register is put back after the spurious
  IRQ 15 check, and the real-mode bridge stubs drop a spurious IRQ 15, and
  a spurious IRQ 7 unless the virtual Sound Blaster is on IRQ 7.

Not changed, by design or because a safe change needs more than a review:

- The virtual WSS codec raises its interrupts through the DPMI host only.
  A real-mode game on the virtual WSS codec waits for an interrupt that
  never comes. Delivering it in real mode needs the slave PIC in the
  real-mode virtual PIC, which emulates one master input today.
- The 8237 emulation accepts the single and auto-initialize modes that
  Sound Blaster drivers program (49h, 59h, 45h, 55h). Demand and block
  modes set the fault byte.
- DPMI host: a real-mode callback cannot be entered while another is
  active in the same client (status 14); software INT 08h to 0Fh and 70h
  to 77h from protected mode raise a general protection fault; LDT
  selectors must have RPL 3; the host image is mapped user-writable at
  linear E0000000h.
- With the virtual Sound Blaster on IRQ 7, a spurious IRQ 7 that arrives
  while a client is in a real-mode call still reaches its handler. The
  driver's trap hides the physical bit from the stubs.

## Checked against the specifications

A second review read the code against the reference documents in
`docs/references` (the Sound Blaster programming reference, the ES1868,
ES1887 and ES1888 data sheets, the 8237A and 8259A data sheets, DPMI 0.9
and 1.0, VCPI, XMS, EMS 4.0, the MSCDEX 2.1 driver specification, ECMA-119
and Ralf Brown's list), and costed the hot paths with the i386 clock counts.
Fixed in `fixes`, checked by assembly only unless the test notes say more:

- Virtual PIC: an EOI from a real-mode handler that the DPMI host had
  already ended at the controller was taken for the game's own, and cleared
  the virtual in-service state while the game's handler ran. The host now
  marks that EOI as spent (CDF5 block). An EOI with nothing virtual in
  service goes through without a read of the in-service register, which
  spares three port traps on every interrupt of every device. After an
  ICW1 the ICW2 to ICW4 bytes are counted off instead of being written to
  the mask.
- 8237: the command, master clear, all-mask and status registers of both
  controllers are trapped (rig: a write to the slave all-mask register
  during playback first stopped the stream, because the per-channel write
  went to port 0Fh; fixed, and the master and slave all-mask now stop and
  resume the stream as the controller would). Master clear and all-mask keep the owned
  channel virtual and the output ring's channel unmasked; the status read
  hides the ring's channel and shows the owned channel's terminal count;
  the write-only registers read as FFh.
- Sound Blaster: the virtual mixer's FM register 26h starts at FFh, as its
  5-bit twins 34h/35h do (a driver that saved and restored the mixer left
  the physical FM volume at the lowest step); 41h/42h set the rate of the
  legacy commands too, and a refused time constant leaves it alone; A0h
  and A8h are accepted, 20h answers 80h, F8h answers 0, F3h raises the
  16-bit interrupt; the status ports read 7Fh/FFh in the undefined bits;
  the SB16 stop resets the DSP.
- ESS: register BAh is written only on an ES1868 or ES1878 (mixer 40h
  identification); the analog control write changes bits 1 and 0 only;
  the mixer registers the start writes (14h, 22h, 26h) are put back at
  the stop.
- WSS: the board register's IRQ codes follow the documented table (none,
  7, 9, 10, 11, 5); the codec start no longer fails when the calibration
  bit is never seen set.
- MSCDEX: a volume space larger than the image is clamped, not refused
  (data tracks ripped from mixed-mode discs); interleave size and skip are
  ignored; Read Long takes Red Book addresses; Stop and Seek on a unit
  without audio return done; Eject works with the driver's own audio
  bound; audio channel control accepts every mapping, with inputs 2 and 3
  as silence; the volume size is the disc up to the lead-out; the track
  control byte carries ADR 1; the raw sector size is 2352; a bad request
  length is error 5; a volume descriptor's version is checked only for the
  primary one; the media-changed answer stays "changed" after the mounting
  helper's own query until the redirector reads the disc.
- The CD filter owner is taken from DOS (AH=62h), not from an SDA offset.
- The mixer speedups are bit-identical: the --verify-mix build gives 0 bad
  samples and 0 bad state on SB Pro and SB 2.0, with and without a game
  stream, at default and changed volumes (once the harness left the fast
  path's scratch dword out of its state sum).
- DPMI host: INT 2Fh AX=1686h answers AX=0 in protected mode; a 0302h
  procedure is entered with interrupts off; software INT 0 to 7 reach a
  protected-mode handler with virtual interrupts off; exceptions 1, 3, 4
  and 5 without a handler are reflected as real-mode interrupts instead of
  ending the client; a reflected interrupt with a data segment that no
  real-mode segment reaches gets the sink segment instead of failing; the
  return from a real-mode callback honours the ES:(E)DI the client returns
  with; the master in-service probes put the read register back; the
  spurious cascade EOI is specific.
- DPMI host, 386 time: the pending test comes before the controller reads
  in dpmi_pic_next; the interrupt-flag site table is hashed; the general
  protection fault decoder fetches four code bytes with one page walk; the
  real-mode transfer copies doublewords.
- 386 time: the SDA swap moves dwords; the physical IRQ handler writes the
  saved mask back instead of reading it again.

Left as they are, with the reason:

- The virtual mixer is a CT1745 on every model, and a DSP reset leaves the
  speaker on. Both are leniencies that games have relied on.
- A single-cycle command during an auto-initialize stream starts at once
  from the buffer start; the DSP would finish the block first. No game is
  known to use that stop method.
- The virtual PIC keeps fixed priorities: the rotate and set-priority
  commands are accepted without effect, and the poll command reads the
  request register.
- The resident image still carries 2.3 KB of one-shot activation code; the
  units could be placed before it.
- Real-mode INT 1Ch, 23h and 24h reach a protected-mode handler the client
  installed (DPMI 0.9, section 2.4.2; the same in 1.0). Three stubs in the
  IVT enter the bridge with bit 9 of the entry word set; the handler runs
  on the locked stack with the client's interrupt flag unchanged, and an
  INT 24h handler's AL goes back to DOS. Without a handler, during a CD
  refill, or at the bridge or stack depth limit, the stub chains to the
  vector it replaced. A suspended parent's handler does not run while a
  child runs. Assembly only; the test plan is in the commit.
- A 0300h call to an IRQ vector that the host holds in service lets the
  real handler's EOI reach the driver; the stray-EOI mark covers the
  queued and chained paths only.
- With no UMBs, the host's gateway and stack sit just above the installer
  image, which leaves a hole of about 19 KB after the driver stays
  resident. The driver's image would have to shrink before the host starts.
- Microsoft EMM386 is no longer supported. Its port-trap interface cannot
  reach the DMA controller, so the 8237 emulation could not protect the
  output ring, and its backend added a second code path to every trap. The
  host refuses to start when the VCPI server has filled the page table
  entries it uses, with "The internal DPMI host did not start". JEMMEX 5.86
  reports the same first free entry (444h) with and without option `SB`,
  so the refusal was not seen in the rig; it stands as a guard.

