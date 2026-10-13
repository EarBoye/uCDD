# State of this fork

What was tested, how, and what is still open. RELEASE-NOTES.md lists the
changes themselves.

## How things were tested

**Real hardware:** Pentium MMX 233, ECS P5HX-A (430HX), 64 MB, ESS ES1868
at A220 I5 D1, S3 Trio64V+, Voodoo 1, Promise Ultra133 TX2, MS-DOS 7.1,
JemmEx, SHSUCDX. These tests were made on 0.9.3a, and the combined build
was run again after the rebase on 0.9.3b. Nothing after the `setup-audit`
change in the table below has run on the real PC yet.

**Emulators:**

- FreeDOS with JemmEx 5.86 and SHSUCDX 3.09 in QEMU (SB16 and CS4231A, protected-mode games, memory snapshots, an AHCI controller for the disk IRQ scan) and in DOSBox-X (SB16, SB Pro, ES688, recorded audio). Test programs play known signals and run the detection code of real game drivers; the recorded output is checked for gaps and steps.
- 86Box 6.0 (ASUS P/I-P55T2P4, Pentium MMX 233, 64 MB), MS-DOS 7.1, JEMMEX 5.86, MSCDEX 2.25, an ES1688 standing in for the ES1868 and set by UNISOUND, also Sound Blaster Pro v2, Sound Blaster 2.0 and Sound Blaster 16. A raw DPMI test client exercises the host services (0204h/0205h, 0200h, reflection, 0300h, nested exec); a recording build of the driver counts deliveries, acknowledges and EOIs. Doom, Heretic, Duke Nukem 3D, Wolfenstein 3D and Witchaven run with the output recorded and the spectrogram checked. Protected-mode games cannot be tested in DOSBox-X: the host uses the debug registers, which that emulator does not act on.

## Changes

Each change was made on a branch of its own and folded into `fixes`. The
branches are gone; their names stay as the names of the changes.

| Change | State |
| --- | --- |
| `disc-header-tolerance` | Tested on hardware |
| `flat-pointer-reflection` | Tested on hardware |
| `cd-refill-large-periods` | Tested on hardware |
| `ess-native-output` | Tested on hardware, ES1868 only. The half-rate alignment fix on top is tested in an emulator only |
| `cli-patterns` | Tested on hardware, benefit only partly confirmed |
| `disk-irq-direct` | In every tested build, not tested alone. Replaced by `disk-irq-detect` |
| `disk-irq-detect` | Emulators only. The scan ran first in UCDDSET and then moved into `UCDD -install`, where the driver learns the machine's controllers itself and UCDDSET keeps the Disk row and the IRQ set by hand. QEMU with an AHCI controller on IRQ 11: the install prints "Disk controller IRQs go to DOS directly: 11 14 15" and the driver and host masks read 11 14 15; `UCDDPCI=OFF` gives 14 15. DOSBox-X with and without a PCI bus prints nothing, and a manual IRQ 9 gives 9 14 15. The UCDDSET Disk row shows "PCI on IRQ 11" and warns about the virtual WSS on IRQ 11. The freeze it prevents needs a PCI controller that uses its IRQ in DOS, so that part needs real hardware |
| `split-word-io` | In every tested build, not tested alone |
| `single-cycle-start` | Four fixes for single-cycle playback. Emulators only |
| `cue-far-buffer` | Emulators only: 111 CUE sheets against the old parser, and a mixed-mode image mounted, read and played under FreeDOS. Part of `fixes` because the driver segment is full without it |
| `wss-stop-vector` | The WSS and ESS stop put the old IRQ handler back on the wrong vector: `sb_irq` was read after `lds` had moved DS, so vector (garbage + 8) was hooked and the IRQ vector left pointing into the program. Under MS-DOS 7.1 with the card on IRQ 7 that vector was 08h, and the machine stopped taking interrupts after the UCDDSET Test. Seen on the real PC, traced and fixed in 86Box, which freezes the same way; the fixed build passes there at IRQ 5 and 7. Not yet run on the real PC |
| `setup-audit` | A review of UCDDSET after `wss-stop-vector`. Fixed, in the shared sound code: the SB Pro start counted loop turns for its priming timeout (now each turn reads a port); `pro_stop` reset the DSP with the IRQ live (masked first now); the real-mode handler took any IRQ 7 as the card's on the SB Pro and SB 2.0 models (the in-service bit is checked now); the WSS codec start unmasked the IRQ before clearing a codec interrupt left from before. In UCDDSET: INT 23h and 24h handlers (Ctrl+Break with BREAK=ON ended the program with vectors hooked); a bounded copy of a kept BLASTER field (a field of 9 or more characters late in the value overran the 96-byte buffer); mode 7 and B000h on MDA and Hercules, blink off on CGA, and the previous text mode and 43/50 lines put back on exit; the tick waits read as elapsed the reset at midnight; `speaker_test` freed segment 0 when its allocation had failed; a CPU check before 386 instructions; the detection's 8237 programming with interrupts off. Checked in 86Box: the Test twice at IRQ 5 and 7, once as SB Pro and SB 2.0; Hercules and CGA; an empty environment; a 100-character BLASTER field at install. QEMU: Doom under the host at IRQ 7 and 5 unchanged. Not tested: the priming timeout on a GHz CPU, Ctrl+Break itself. The in-service check it added clobbered the stack segment at IRQ 7; fixed later, see "Fixed after the reviews" |
| Review of UCDD.EXE | Five independent readings of the driver, the port trap and card emulation, the mixer and CD streaming, the host IRQ path and the DPMI services. The fixes are listed under "Fixed after the reviews". Emulators only |
| Specification pass | The code read against the documents in `docs/references` and the hot paths costed with the i386 clock counts. Emulators only |
| EMM386 dropped | JEMMEX was already required. The host refuses to start when the VCPI server has filled the page table entries it uses ("The internal DPMI host did not start"); JEMMEX 5.86 reports the same first free entry (444h) with and without option `SB`, so the refusal was not seen in the rig and stands as a guard |
| INT 1Ch/23h/24h reflection | 86Box, raw DPMI client: a 16-bit client's INT 1Ch handler gets 18 ticks a second (0 before), 15 to 18 with CD audio playing; the vector under the stub reads as the original and the IVT is back after exit; a 32-bit client's INT 24h handler runs for an open on an empty A: with the client's selectors and no DOS prompt, and its fail, retry and abort answers are honoured; a child without a handler freezes the parent's counter and a child with one counts on its own; Ctrl+C reaches a protected-mode INT 23h handler, and its carry ends the program |
| DOS-side termination | 86Box: an INT 24h abort and an INT 23h termination, at depth 0 and from a child under a parent, leave the IVT (08h-0Fh, 70h-77h, 1Ch, 22h-24h), DOS free memory and VCPI free pages as before the client, and the next client starts. Before, the host stayed busy until reboot |
| IRQ 7 wash | See "Fixed after the reviews". 86Box: 0 washed Doom runs of 15 at 7/7 on the fixed build against 3 of 10 before; Duke Nukem 3D, Heretic, Wolfenstein 3D, Witchaven and the DPMI client unchanged |
| Data-flow pass | After the IRQ 7 stack fault, a mechanical pass over every entry point and join label (register, segment, stack and flag state on each incoming path) across the driver's interrupt and trap side, its DOS side, the host's mode switches and stubs, and the host's protected-mode services. Five defects, listed under "Fixed after the reviews"; everything else traced came back sound. 86Box on the fixed head: Doom 7/7 three runs and one with a real-mode serial mouse driver, no wash; timedemo unchanged; Heretic and Wolf3D as before; verify-mix 0 bad; 16-bit and 32-bit INT 1Ch clients at 18 ticks a second; a new client after an INT 24h abort; a client polling INT 16h for 30 s with keys arriving leaves the keyboard working and nothing in service at the controller. That last harness did not reproduce the swallowed EOI on the build before the fix either, so the register-only reflection fix stands on reading, not on a reproduced failure |

## The output period decides which games have sound

The mixer reads game data up to two output periods ahead, so the driver
refuses an auto-initialize block that lasts less than two periods. The game
gets no sound and no interrupt; the DSP command stream is parsed on.

| `--audio-period-frames` | Shortest block accepted | Examples that fall below it |
| --- | --- | --- |
| 32 (default) | 1.5 ms | none known |
| 64 | 2.9 ms | none known |
| 128 | 5.8 ms | 256-frame blocks above 44.1 kHz |
| 256 | 11.6 ms | DMX on a virtual SB Pro (Doom, Heretic, Hexen: 128 stereo frames at 11.1 kHz is 11.5 ms). Any 256-frame block at 22.2 kHz or faster. From its source, the Apogee Sound System uses 256-frame blocks, so its 44 kHz setting should fall below this too (not tested) |

A larger period costs less CPU time on every card, and on the ES1868 it is
what makes Sound Blaster Pro output work at all. The combined build was
tested at 256. Measured in an emulator: Doom with a virtual SB Pro is silent
at 256 and has sound at 128.

## Slow CPUs

Measured in QEMU with an instruction-counted clock, SB16, unmodified
0.9.3b. Every instruction takes the same time there, so a real 386, where a
multiply is slow, does worse than these figures. "CPU taken" is the share of
a counting loop's passes lost over five seconds.

| Speed | Period | CPU taken, nothing playing | CPU taken, CD audio playing |
| --- | --- | --- | --- |
| 128 ns per instruction (7.8 MIPS, a fast 386) | 32 | 18.5 % | 32.8 % |
| | 64 | 6.0 % | 26.5 % |
| | 128 | 6.1 % | 22.7 % |
| | 256 | 3.7 % | 21.0 % |
| 256 ns per instruction (3.9 MIPS, a 386SX) | 256 | 6.0 % | 81.2 % |

At 256 ns per instruction a Sound Blaster detection sequence (reset,
version, one-byte block) does not finish with the driver loaded. This is the
same on unmodified 0.9.3b and is not investigated. With a 32-frame period
the measurement itself did not finish at that speed.

At 128 ns per instruction and a 32-frame period, the port trap lasts longer
than one output period. The last fix in `single-cycle-start` is for that
case.

The mixer speedups of the specification pass (unity gains, inlined
interpolation, doubleword moves) are not measured in these figures. They
are bit-identical: the `--verify-mix` build gives 0 bad samples and 0 bad
state on SB Pro and SB 2.0, with and without a game stream, at default and
changed volumes.

## Not solved

- Hexen: the machine sometimes freezes after the game exits. The launcher
  log shows the game returned and the image was unmounted first. A test
  client that makes Hexen's CD calls, followed by a second protected-mode
  program, does not reproduce it in QEMU.
- Mortal Kombat Trilogy hangs at the Battle screen, at a CD track change.
- The Need for Speed SE hangs while it loads a race. It also hangs with the
  data-only driver, so this is probably not the audio host.
- Descent II: crackle in the intro audio with every build tested on
  hardware. The filter fix in `single-cycle-start` removes a click of this
  kind in an emulator; whether it is the same fault is not known.
- Witchaven's Smacker intro (SMACKPLY.EXE) freezes on its first frame with
  the audio driver installed, silent, at 7/7 and at 5/5, on every build
  tested in 86Box; it plays without μCDD. The game itself, started without
  the intro, runs. Not investigated.
- A protected-mode handler for INT 1Ch misses the ticks that arrive while
  the CD refill runs inside DOS, about 8 percent with CD audio playing: the
  stub chains to the BIOS vector then, since the client cannot run. A game
  that times itself on INT 1Ch runs that much slower while CD audio plays.
- Doom's timedemo runs about one percent slower since the IRQ 7 fix in
  86Box (1650 against 1635 realtics), also at 5/5 and 7/5. The EOI round
  trips into the driver did not rise, so the cause is not known. Left as is.
- A 512-frame output period is not usable.
- A flat pointer passed to a reflected real-mode service no longer corrupts
  memory, but the service still cannot return data to the client.
- Sierra's AUDBLAST.DRV waits 2048 loop passes for its test interrupt. That
  is too short for any card on a fast CPU, so King's Quest V still needs
  the wait patched, with or without this driver.

## Limits, by design

- The virtual WSS codec raises its interrupts through the DPMI host only. A
  real-mode game on the virtual WSS codec waits for an interrupt that never
  comes. Delivering it in real mode needs the slave PIC in the real-mode
  virtual PIC, which emulates one master input today.
- The 8237 emulation accepts the single and auto-initialize modes that
  Sound Blaster drivers program (49h, 59h, 45h, 55h). Demand and block modes
  set the fault byte.
- The virtual PIC keeps fixed priorities: the rotate and set-priority
  commands are accepted without effect, and the poll command reads the
  request register. ICW1 from a protected-mode program still faults it.
- The virtual mixer is a CT1745 on every model, and a DSP reset leaves the
  speaker on. Both are leniencies that games have relied on.
- A single-cycle command during an auto-initialize stream starts at once
  from the buffer start; the DSP would finish the block first. No game is
  known to use that stop method.
- DPMI host: a real-mode callback cannot be entered while another is active
  in the same client (status 14); software INT 08h to 0Fh and 70h to 77h
  from protected mode raise a general protection fault; LDT selectors must
  have RPL 3; the host image is mapped user-writable at linear E0000000h;
  a critical error raised inside the CD refill's own DOS call would end
  whichever PSP is current.
- With the virtual Sound Blaster on IRQ 7, a spurious IRQ 7 that arrives
  while a client is in a real-mode call still reaches its handler. The
  driver's trap hides the physical bit from the stubs.
- With no UMBs, the host's gateway and stack sit just above the installer
  image, which leaves a hole of about 19 KB after the driver stays resident.
  The driver's image would have to shrink before the host starts.
- The activation code shares its 9.5 KB with the DOS swap area and the unit
  table, which overwrite it after start; only the JemmEx backend's init,
  under 1 KB, stays resident as one-shot code. BUILDING.md has the sizes.
- The real-mode bridge only knows the IRQs it was told about: vectors a
  client points into UMB blocks are found at cleanup only when the UMB link
  is on.

## Performance

Measured in the 86Box rig (13 Oct 2026): a Pentium MMX 233 with the
ES1688 for the ES1868, an Am386DX-40 with 8 MB and a 486DX2-66 with 16 MB,
each with MS-DOS 7.1 and JEMMEX 5.86. Ratios between builds on one machine
are reliable; the 386 and 486 absolute figures are approximate, since the
emulator runs those CPUs slower per clock than the real chips. The
`--profile-host` and `--profile-driver` builds (BUILDING.md) gave the cycle
counts; the CPU shares come from a counting loop over five seconds.

**What the driver costs Doom on the Pentium**, 256 frames, against sound
on the bare card: 5.9 percent of realtics, of which the mixer interrupt's
work 1.7, the port traps' crossings into real mode 1.8, the host's fault
handling for the trapped ports 0.7, CLI and STI faults 0.5 (700 cycles of
handler against a 14 microsecond fault, so the CPU's cost, not ours), the
rest interrupt entries. A trapped port access from a protected-mode game
costs a fault plus a switch to real mode and back, about 26 microseconds
inside Doom; CLI and STI fault because port trapping needs IOPL below 3,
which is the price of the design.

**What CD audio costs**: 7.4 percent of the Pentium from the hard disk at
256 frames, of which 2.3 points are the BIOS reading the image by
programmed I/O (a bus-master IDE driver such as UIDE takes that off the
CPU; the Promise card's BIOS has no DOS driver of its own). On the ES1868's
exact-rate path the mixing is 1.8 percent; the ES1688 without the clock
trim runs the interpolating path at 4.8 percent, which is what any ESS
other than the ES1868 and ES1878 pays. On the 386 CD audio from the hard
disk took 33 percent on the exact-rate path and 66 on the interpolating
one; on the 486 17 and 30.

Changes made from these figures, each checked bit-identical by the
verify-mix build or byte-identical in the DSP test output:

- The host answers four of the seven trapped ports per virtual interrupt
  in protected mode (mixer index write, mixer data read, the two DSP
  status reads that acknowledge interrupts, the DMA flip-flop reset): the
  accesses crossing into the driver fell from 7.4 to 3.4 per interrupt,
  Doom 0.4 percent faster.
- The common mixer chains run as single loops: the 8-bit stereo and mono
  sources with and without the disc into a word or a halved store, and
  silence with the disc into a halved store. The CD-only exact-rate case
  fell from 13.3k to 8.8k cycles per interrupt on the Pentium, from 33 to
  26 percent of the 386 and 17 to 12.5 of the 486 from the hard disk; a
  mono stream alone from 19 to 16 percent of the 386, with the disc from
  38 to 26 (RAM disk). Doom's mixing fell 8 percent: its chain was
  shorter than estimated, and the gain is the jumps between the pieces.
- The timer refill reads 16 KB per pass instead of up to 128 KB, since
  the foreground program waits for the whole pass. On the 386 with an ISA
  disk the longest wait fell from 170 to 200 ms to 30 to 37 ms (17 ms on
  the exact-rate path), about eleven passes a second instead of three, no
  dropouts; the Pentium is unchanged.

Not worth changing: the CLI and STI path; a virtual ESS model (the
capture and mix are the same whatever the game believes it talks to); the
mixer for MMX (a few percent of the mixer's share, in a full segment).

## Fixed after the reviews

Found by the review of UCDD.EXE and the specification pass, fixed in
`fixes`, checked in the emulator rig against the build before the review
(0f81195) unless the note says otherwise. Ctrl+Break with BREAK=ON needs
MS-DOS (FreeDOS does not run the break check in those calls) and was checked
in 86Box.

Driver and CD:

- A disc hotkey (MDM list, or eject and insert of a single image) bound the
  new disc for CD audio from the timer tick and from the request entry, and
  read the image through DOS with the game's PSP and without the DOS state
  swap. A game's file on the same handle number lost its position. The bind
  runs inside `dos_enter` now, and the timer does not switch discs while the
  BIOS disk code runs. Rig: twelve handles open on one file, the position
  no longer jumps to 0.
- With `BREAK=ON`, Ctrl+C or Ctrl+Break during a CD read reached the default
  INT 23h handler with the resident's PSP current, which ended the resident.
  `dos_enter` points INT 23h at an `iret` and `dos_leave` puts it back, as
  for INT 24h.
- `UCDD -unmount NAME.CUE` never matched, because the mount stores the BIN
  file's name. The unmount resolves a CUE sheet the same way.
- `UCDD -install` failed with "UCDDSET.EXE cannot be started" on a DOS that
  cannot link UMBs. The UMBs are unlinked only when they are linked, and a
  refusal is not an error.
- A read request whose transfer address ends above 1 MiB returns general
  failure (0Ch), not sector not found.
- MSCDEX: a volume space larger than the image is clamped; interleave size
  and skip are ignored; Read Long takes Red Book addresses; Stop and Seek on
  a unit without audio return done; Eject works with the driver's own audio
  bound; audio channel control accepts every mapping, with inputs 2 and 3
  as silence; the volume size is the disc up to the lead-out; the track
  control byte carries ADR 1; the raw sector size is 2352; a bad request
  length is error 5; a volume descriptor's version is checked only for the
  primary one; the media-changed answer stays "changed" after the mounting
  helper's own query until the redirector reads the disc. The CD filter
  owner is taken from DOS (AH=62h), not from an SDA offset.
- An installation that failed with the trap code kept in memory did not
  free its environment block. The internal host loader did not accept the
  one-zero-byte empty environment.
- The SDA swap moves dwords.

Sound card emulation:

- With the physical card on IRQ 7, the in-service check that `setup-audit`
  added to the physical interrupt handler left the controller's answer in
  AX, and the stack switch that follows loads SS from AX. Every audio
  interrupt then ran on a stack in segment 800Ah or 800Bh, inside
  conventional memory at 512 KB, and wrote over whatever was there. Found by
  the rig session reading the handler after the IRQ 7 work; the games it ran
  at 7/7 happened to survive it. The handler loads CS again before the
  switch. The hardware tests all ran with the card on IRQ 5, so no real-PC
  run has had this fault.
- The single-cycle block patch, reached from the port trap when a game
  starts a block, ran the mixer's string stores with the game's direction
  flag: the JemmEx trap entry clears only IF and TF in the game's flags
  image. A game with the direction flag set at that DSP write would have had
  the patch written backwards through the output ring and past its start.
  Found by the data-flow pass after the IRQ 7 stack fault; `sb_patch` clears
  the flag under its own flag save now.
- A refused DSP command or argument left the argument counter set, so the
  bytes the game wrote next were taken as arguments. Rig: E1h after a
  refused short block replies 04.05, no reply before.
- A refused rate was already stored, and a rate of 0 later divided in the
  silence command and the single-cycle block start.
- DAh/D9h while paused with D0h/D5h was dropped; it is held and applied at
  the resume, as the DSP does. Rig: D0h, DAh, D4h on an auto-initialize
  stream ends the block after the resume, looped before.
- 41h/42h set the rate of the legacy commands too; A0h and A8h are accepted;
  20h answers 80h, F8h answers 0, F3h raises the 16-bit interrupt; the status
  ports read 7Fh/FFh in the undefined bits; the SB16 stop resets the DSP.
- The virtual mixer's FM register 26h starts at FFh, as its 5-bit twins
  34h/35h do.
- 8237: the command, master clear, all-mask and status registers of both
  controllers are trapped. Rig: a write to the slave all-mask register
  during playback first stopped the stream, because the per-channel write
  went to port 0Fh; fixed, and the master and slave all-mask stop and resume
  the stream as the controller would. The status read hides the ring's
  channel and shows the owned channel's terminal count; the write-only
  registers read as FFh.
- The interpolation of the last CD frame of a half read one frame past the
  data loaded when the output rate is above 44100 Hz (SB 2.0, ESS).
- The spurious IRQ 7 check in the physical interrupt handler put the PIC
  read register back to IRR whatever the game had selected. The handler
  writes the saved mask back instead of reading it again.
- ESS: register BAh is written only on an ES1868 or ES1878 (mixer 40h
  identification); the analog control write changes bits 1 and 0 only; the
  mixer registers the start writes (14h, 22h, 26h) are put back at the stop.
- WSS: the board register's IRQ codes follow the documented table (none, 7,
  9, 10, 11, 5); the codec start no longer fails when the calibration bit is
  never seen set.

Virtual PIC:

- An EOI from a real-mode handler whose interrupt the DPMI host had already
  ended at the controller was taken for the game's own and cleared the
  virtual in-service state. The host marks that EOI as spent (CDF5). An EOI
  with nothing virtual in service goes through without a read of the
  in-service register, which spares three port traps on every interrupt of
  every device.
- After an ICW1 the ICW2 to ICW4 bytes are counted off instead of being
  written to the mask. The rotate forms of the EOI commands, set priority,
  special mask mode and poll are accepted in the driver and in the host.
- Doom with the physical and the virtual card both on IRQ 7 turned its
  effects into a constant wash in most runs. The virtual PIC set its
  in-service bit when the interrupt was taken, before the game's handler
  ran, and credited any non-specific EOI arriving in between to the virtual
  card when the physical in-service register was empty. Under the DPMI host
  that register is always empty during a client's handler, since the host
  ends every IRQ it queues at the controller first. DMX's timer handler
  chains to the real-mode vector (or calls INT 08h through 0300h, whose
  BIOS EOI was not marked) and then sends its own EOI, which ended the
  virtual service while the virtual interrupt was still held. DMX's IRQ 7
  handler then read the in-service register, saw no bit 7, took the
  interrupt for a spurious one and never acknowledged it; no further
  interrupt was raised, DMX never retired its channels and sounds piled up.
  On IRQ 5 DMX has no such filter. Now a delivered mark, set by the
  real-mode jump or by the host's delivery (CDF6), gates the attribution; a
  0300h call to a hardware vector the host holds in service is treated as a
  chain; a signalled interrupt that is neither requested nor in service for
  two periods is raised again; and the host answers the plain EOIs with
  nothing virtual to end itself. Rig: the recording build shows one EOI per
  run landing on the held interrupt and the last delivery unacknowledged in
  the washed runs, and that EOI forwarded on the fixed build.

DPMI host:

- Found by the data-flow pass: the delivered mark of the IRQ 7 fix sat on
  a join label that the ordinary IRQ reflection also reaches, so a timer or
  keyboard interrupt reflected to real mode while the virtual interrupt was
  held marked it delivered, and the next EOI could end it before the client
  had it. The mark is on the virtual path alone now. Also found: the
  default-vector stub that brings a client's INT 21h or INT 31h to the host
  kept the client's direction flag, and the services copy with string
  instructions; the flag is cleared at the stub's entry. Also found: the
  stray-EOI mark of the specification pass stood on the label that both
  hardware vectors and register-only BIOS and DOS reflections (INT 10h, 11h,
  12h, 16h, 1Ah and a few INT 21h functions) reach, so a real-mode handler
  that ran during such a reflected call, a key arriving while a client
  polled INT 16h without its own keyboard handler for one, lost its EOI and
  left its IRQ in service at the controller. The mark is on the hardware
  path alone now. The client init after the mode switch clears the
  direction flag before its fills instead of trusting the VCPI server's.
- A real-mode callback of a suspended parent (a mouse event handler armed
  before the parent started a child program) ended the child. The stub
  returns to its caller with the registers unchanged when the slot is not
  the running client's. The decision between an interrupt frame and a far
  call is made from the IVT and the shape of the flags word, so it is a
  heuristic; the parent's slots are kept off limits to the child.
- INT 20h and INT 21h AH=00h or AH=31h from a client ended the DOS process
  under the host and leaked its memory. They end the client as AH=4Ch does.
- A client that DOS ends from real mode (an INT 24h handler answering abort,
  an INT 23h handler asking for the end, a 4Ch from real-mode code) left the
  host busy and the stubs in the IVT until reboot. The host saves the
  client's PSP terminate address and points it at a hook that switches to
  protected mode on the host's stack, runs the normal release, restores the
  parent gateway when nested, and jumps on to the saved address on DOS's
  stack. The normal exit restores the address.
- An INT 23h handler's carry did not reach DOS. The real-mode return is a
  RETF with the carry set when the handler asked for the end.
- 0800h maps a physical range below 1 MiB to itself instead of refusing it;
  0801h accepts such an address.
- The hardware PIC masks a child left behind are put back to the parent's
  when the child exits.
- The slave PIC read register is put back after the spurious IRQ 15 check;
  the real-mode bridge stubs drop a spurious IRQ 15, and a spurious IRQ 7
  unless the virtual Sound Blaster is on IRQ 7.
- INT 2Fh AX=1686h answers AX=0 in protected mode; a 0302h procedure is
  entered with interrupts off; software INT 0 to 7 reach a protected-mode
  handler with virtual interrupts off; exceptions 1, 3, 4 and 5 without a
  handler are reflected as real-mode interrupts instead of ending the
  client; a reflected interrupt with a data segment that no real-mode
  segment reaches gets the sink segment instead of failing; the return from
  a real-mode callback honours the ES:(E)DI the client returns with; the
  master in-service probes put the read register back; the spurious cascade
  EOI is specific.
- Real-mode INT 1Ch, 23h and 24h reach a protected-mode handler the client
  installed (DPMI 0.9, section 2.4.2; the same in 1.0). Three stubs in the
  IVT enter the bridge; the handler runs on the locked stack with the
  client's interrupt flag unchanged, and an INT 24h handler's AL goes back
  to DOS. Without a handler, during a CD refill, or at the bridge or stack
  depth limit, the stub chains to the vector it replaced. A suspended
  parent's handler does not run while a child runs.
- 386 time: the pending test comes before the controller reads in
  dpmi_pic_next; the interrupt-flag site table is hashed; the general
  protection fault decoder fetches four code bytes with one page walk; the
  real-mode transfer copies doublewords.

UCDDSET and documentation:

- The Disk row text stops before the IRQ field.
- README: `-units` applies to the data-only driver; the audio driver takes
  one drive.
