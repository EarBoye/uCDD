# State of this fork

What was tested, how, and what is still open. RELEASE-NOTES.md lists the
changes themselves.

Mantra rule 10 (20 Oct 2026): fix by family, not by game. A fault seen in
one game is tested across every game sharing its sound engine and driver
version (branch `sound-engine-library`, docs/sound-engines: inventory and
census) before it is called that game's own; the shared cause is fixed
once and the fix checked across the family before it ships. Mortal Kombat
Trilogy's slow sounds were 22 games' fault, cleared by one host fix
(stray-eoi, below).

Branch names below that are no longer on the fork (they were folded into
`fixes` or into `vcpi-children`, the current line) live on as tags:
`archive/<name>` points at the commit the branch had (19 Oct 2026).

## How things were tested

**Real hardware:** Pentium MMX 233, ECS P5HX-A (430HX), 64 MB, ESS ES1868
at A220 D1, on IRQ 5 for the early tests and IRQ 7 since, S3 Trio64V+,
Voodoo 1, Promise Ultra133 TX2, MS-DOS 7.1, JemmEx, SHSUCDX. The early
tests were made on 0.9.3a, and the combined build was run again after the
rebase on 0.9.3b. The builds from the IRQ 7 fix on ran there with a set of
scripts (HWLOG) that time memory, disk, Doom and Quake with and without
the driver, and dump the profile builds' counters; those are the figures
under "Performance".

**Emulators:**

- FreeDOS with JemmEx 5.86 and SHSUCDX 3.09 in QEMU (SB16 and CS4231A, protected-mode games, memory snapshots, an AHCI controller for the disk IRQ scan) and in DOSBox-X (SB16, SB Pro, ES688, recorded audio). Test programs play known signals and run the detection code of real game drivers; the recorded output is checked for gaps and steps.
- 86Box 6.0 (ASUS P/I-P55T2P4, Pentium MMX 233, 64 MB; also an Am386DX-40 with 8 MB and a 486DX2-66 with 16 MB for the slow-CPU figures), MS-DOS 7.1, JEMMEX 5.86, MSCDEX 2.25, an ES1688 standing in for the ES1868 and set by UNISOUND, also Sound Blaster Pro v2, Sound Blaster 2.0 and Sound Blaster 16. A raw DPMI test client exercises the host services (0204h/0205h, 0200h, reflection, 0300h, nested exec); a recording build of the driver counts deliveries, acknowledges and EOIs. Doom, Heretic, Duke Nukem 3D, Wolfenstein 3D and Witchaven run with the output recorded and the spectrogram checked. Protected-mode games cannot be tested in DOSBox-X: the host uses the debug registers, which that emulator does not act on.

## Changes

Each change was made on a branch of its own and folded into `fixes`. The
branches are gone; their names stay as the names of the changes.

| Change | State |
| --- | --- |
| `disc-header-tolerance` | Tested on hardware |
| `flat-pointer-reflection` | Tested on hardware |
| `cd-refill-large-periods` | Tested on hardware |
| `ess-native-output` | Tested on hardware, ES1868 only. The half-rate alignment fix on top is tested in an emulator only. The 44.1 kHz clock trim was not applied on hardware until the ESS identification fix below |
| `cli-patterns` | Tested on hardware, benefit only partly confirmed |
| `disk-irq-direct` | In every tested build, not tested alone. Replaced by `disk-irq-detect` |
| `disk-irq-detect` | Emulators only. The scan ran first in UCDDSET and then moved into `UCDD -install`, where the driver learns the machine's controllers itself and UCDDSET keeps the Disk row and the IRQ set by hand. QEMU with an AHCI controller on IRQ 11: the install prints "Disk controller IRQs go to DOS directly: 11 14 15" and the driver and host masks read 11 14 15; `UCDDPCI=OFF` gives 14 15. DOSBox-X with and without a PCI bus prints nothing, and a manual IRQ 9 gives 9 14 15. The UCDDSET Disk row shows "PCI on IRQ 11" and warns about the virtual WSS on IRQ 11. The freeze it prevents needs a PCI controller that uses its IRQ in DOS, so that part needs real hardware |
| `split-word-io` | In every tested build, not tested alone |
| `single-cycle-start` | Four fixes for single-cycle playback. Emulators only |
| `cue-far-buffer` | Emulators only: 111 CUE sheets against the old parser, and a mixed-mode image mounted, read and played under FreeDOS. Part of `fixes` because the driver segment is full without it |
| `wss-stop-vector` | The WSS and ESS stop put the old IRQ handler back on the wrong vector: `sb_irq` was read after `lds` had moved DS, so vector (garbage + 8) was hooked and the IRQ vector left pointing into the program. Under MS-DOS 7.1 with the card on IRQ 7 that vector was 08h, and the machine stopped taking interrupts after the UCDDSET Test. Seen on the real PC, traced and fixed in 86Box, which freezes the same way; the fixed build passes there at IRQ 5 and 7. Not yet run on the real PC |
| `setup-audit` | A review of UCDDSET after `wss-stop-vector`. Fixed, in the shared sound code: the SB Pro start counted loop turns for its priming timeout (now each turn reads a port); `pro_stop` reset the DSP with the IRQ live (masked first now); the real-mode handler took any IRQ 7 as the card's on the SB Pro and SB 2.0 models (the in-service bit is checked now); the WSS codec start unmasked the IRQ before clearing a codec interrupt left from before. In UCDDSET: INT 23h and 24h handlers (Ctrl+Break with BREAK=ON ended the program with vectors hooked); a bounded copy of a kept BLASTER field (a field of 9 or more characters late in the value overran the 96-byte buffer); mode 7 and B000h on MDA and Hercules, blink off on CGA, and the previous text mode and 43/50 lines put back on exit; the tick waits read as elapsed the reset at midnight; `speaker_test` freed segment 0 when its allocation had failed; a CPU check before 386 instructions; the detection's 8237 programming with interrupts off. Checked in 86Box: the Test twice at IRQ 5 and 7, once as SB Pro and SB 2.0; Hercules and CGA; an empty environment; a 100-character BLASTER field at install. QEMU: Doom under the host at IRQ 7 and 5 unchanged. Not tested: the priming timeout on a GHz CPU, Ctrl+Break itself. The in-service check it added clobbered the stack segment at IRQ 7; fixed later, see "Fixed after the reviews" |
| Review of UCDD.EXE | Five independent readings of the driver, the port trap and card emulation, the mixer and CD streaming, the host IRQ path and the DPMI services. The fixes are listed under "Fixed after the reviews". Emulators only |
| Specification pass | The code read against the documents in the reference library (the `references` release and the `reference-library` branch) and the hot paths costed with the i386 clock counts. Emulators only |
| EMM386 dropped | JEMMEX was already required. The host refuses to start when the VCPI server has filled the page table entries it uses ("The internal DPMI host did not start"); JEMMEX 5.86 reports the same first free entry (444h) with and without option `SB`, so the refusal was not seen in any emulator and stands as a guard |
| INT 1Ch/23h/24h reflection | 86Box, raw DPMI client: a 16-bit client's INT 1Ch handler gets 18 ticks a second (0 before), 15 to 18 with CD audio playing; the vector under the stub reads as the original and the IVT is back after exit; a 32-bit client's INT 24h handler runs for an open on an empty A: with the client's selectors and no DOS prompt, and its fail, retry and abort answers are honoured; a child without a handler freezes the parent's counter and a child with one counts on its own; Ctrl+C reaches a protected-mode INT 23h handler, and its carry ends the program |
| DOS-side termination | 86Box: an INT 24h abort and an INT 23h termination, at depth 0 and from a child under a parent, leave the IVT (08h-0Fh, 70h-77h, 1Ch, 22h-24h), DOS free memory and VCPI free pages as before the client, and the next client starts. Before, the host stayed busy until reboot |
| IRQ 7 wash | See "Fixed after the reviews". 86Box: 0 washed Doom runs of 15 at 7/7 on the fixed build against 3 of 10 before; Duke Nukem 3D, Heretic, Wolfenstein 3D, Witchaven and the DPMI client unchanged |
| Data-flow pass | After the IRQ 7 stack fault, a mechanical pass over every entry point and join label (register, segment, stack and flag state on each incoming path) across the driver's interrupt and trap side, its DOS side, the host's mode switches and stubs, and the host's protected-mode services. Five defects, listed under "Fixed after the reviews"; everything else traced came back sound. 86Box on the fixed head: Doom 7/7 three runs and one with a real-mode serial mouse driver, no wash; timedemo unchanged; Heretic and Wolf3D as before; verify-mix 0 bad; 16-bit and 32-bit INT 1Ch clients at 18 ticks a second; a new client after an INT 24h abort; a client polling INT 16h for 30 s with keys arriving leaves the keyboard working and nothing in service at the controller. That last harness did not reproduce the swallowed EOI on the build before the fix either, so the register-only reflection fix stands on reading, not on a reproduced failure. The join labels and entry points the pass visited carry a comment naming the register, segment, stack and flag state on each incoming path, so the next change there starts from the list instead of rederiving it |
| Performance pass | Measured first, then changed: port traps answered in protected mode, the common mixer chains as single loops, a 16 KB refill budget. Each checked bit-identical with the `--verify-mix` build; the figures are under "Performance". 86Box on the Pentium, 386 and 486 templates, then the real PC |
| ESS identification | The ES1868 was never recognised, so its clock trim never ran: the mixer index was rewritten before each identification read, which restarts the chip's answer, and the first byte was then lost to a port read. Found from the real PC's cycle counts; confirmed on the chip with a probe program and the fixed build |
| `step-aside` | The driver stops its output, untraps the ports and puts the host to sleep while no mounted image is bound for CD audio and the physical card can stand in for the virtual one; it engages again at the next mount of a disc with audio. Decided only from the control entry (mount, MDM mount, eject) and at the end of the install. 86Box: 120 transitions (audio CUE, data ISO, MDM with the audio disc second) leave the IVT, PIC masks, trapped-port table, DMA and mixer state byte-identical to the fresh install when aside and to the engaged build when a disc is bound; aside, Doom's timedemo equals the boot without the driver on the Pentium (1558 both) and on the 386 (within 0.2 percent, against 20 percent slower engaged); every pairing rule checked both ways; a version 2 UCDD.CFG installs. Two defects found and fixed in the round: a list with the audio disc second stayed aside, and the stop's vector restore was taken by the driver's own INT 21h hook. Not run: hotkeys mid-game on a list, UCDDPLAY's physical-disc mode, the dialog's save of a version 2 file. Not yet on the real PC |
| `virtual-ess` | A virtual ESS AudioDrive (virtual model 4): the ESS commands and extension registers in front of the SB Pro parser, 16-bit data over the 8-bit channel, demand-mode DMA accepted, the IRQ on the 8-bit status for every format, the ESS mixer twins (14h, 32h, 36h, 38h) as the SB Pro pairs, and the physical chip's own E7h and mixer 40h answers; UCDDSET offers it only with a physical ESS and the pairing lets the driver step aside with one. 86Box: regression on nine card pairings byte-identical; verify-mix 0 bad on the ESS cases; Warcraft II's ESFM driver enters ESFM native mode (register 105h bit 7, then the native register map) with the virtual ESS and finds no card with a virtual SB Pro. With the ESS mixer twins routed, the ESFM level follows the driver's mixer 36h writes (the remaining 8 dB above the bare chip is the driver's own FM level, the same offset OPL music has). The Miles ESS digital drivers do not start on 86Box's ES1688 even without the driver; on DOSBox-X the Miles 3.5 one (AUDIODRV.DIG) runs on a bare ESS688 and ESS1688, so its run on the virtual ESS waits for the real PC. Real PC (ES1868F): Descent 2 plays on the virtual ESS at the half and the full rate, its crackle gone with the polled DMA count at the played position (42 clicks a second on the old recording, 0 to 1 now). At the half rate a 22097 Hz stream (Descent 2's A1h=DCh) wobbled; see fast-resample. The Miles ESS digital driver still fails its F2h interrupt test (the limit below) |
| `odd-long-block` | A block longer than the DMA buffer skips the whole-frame check (Descent 2's HMI ESS driver). 86Box regression: SBT16 and SADUMP on six pairings, verify-mix, Doom, Duke, Heretic, Wolf3D, Witchaven unchanged |
| `ess-position` | The virtual ESS reports a polled DMA count one output period behind the mix (Descent 2 crackle). 86Box: SBT16 and SADUMP on seven pairings unchanged, verify-mix 0 bad on the virtual ESS with and without CD audio |
| `virtual-timing` | An auto-initialised transfer's polled DMA count follows the output clock, as a real card's counter does, instead of the mix's whole periods; never past the mix. 86Box: SBT16 on seven pairings unchanged, verify-mix 0 bad on eight runs, Doom, Duke, Heretic, Wolf3D, Witchaven, Theme Hospital (SB16.DIG), Warcraft II as before, Descent 2 clean on ESS and SB16. Tomb Raider (whose CD audio support brought in the mix-based count, 9f3b5bd) with its CD mounted (data track and 60 s of track 2) sounds the same second by second, about 30 detector events a second on both builds; whether those are its sound or an older fault needs a bare-card run |
| `mem-holes` | A sweep of conventional, upper and XMS memory in four layouts (normal, the CD-ROM driver low, uCDD loaded low, a virtual SB16) found two holes the driver left: 3 KB in conventional memory below COMMAND.COM, where the CD half buffer was allocated before moving up between two buffers that stayed, and 19 KB in upper memory, where the install code sat below the host's blocks and the buffers and was freed at the end. Fixed: the CPU-only buffers move up lowest first, stopping at the first that does not fit; the host's blocks and the moved buffers take upper memory last fit, so the install code's space joins the free memory; the host allocates its gateway before its stack, so the stack can take the slack the page-aligned gateway frees. 86Box: no hole between the driver's blocks in any layout; the largest free conventional block grows by 2.3 KB (normal, loaded low), 6 KB (SB16) and 28 KB with the CD-ROM driver low (MSCDEX now fits in upper memory); upper memory used by the driver drops 3-4 KB (the gateway's alignment slack). XMS: allocations unchanged, no new fragmentation. Regression unchanged (the F2H script's pair and no-acknowledge counts vary at 128 frames on every build, the trap limit) |
| `sb16-mpu` | The physical SB16's MPU-401 interrupts on the card's own line, mixer 82h bit 2, and every acknowledge byte raises one (Creative's guide: "An interrupt is generated when the interface is set to UART mode"). The driver's handler sent every interrupt without bit 1 to the vector it found at install, on most machines the BIOS default, which masks an IRQ it does not know: the output stopped until something unmasked it. Seen on the real PC as Settlers II's menu freezing about once a second with General MIDI (Miles MPU401.MDI) and Descent's setup crashing in its General MIDI test. Fixed: the handler reads 82h once; bit 1 plays the output, bit 2 raises the virtual SB16's line (82h bit 2 there follows the card's, as on the real card; the SB Pro and SB 2.0 have no MPU-401 on their line) and the interrupt ends in the driver, bit 0 alone (a stray 8-bit request) is acknowledged. While the MPU-401 may hold the line high, an output interrupt that comes meanwhile raises no edge, so the timer tick and the port trap look for one pending at the card and missing at the controller and run the output for it. A block end now adds its bit to 82h while another source holds the virtual line. The verify build's loop counters became bytes (MIXVERI4) to keep it inside its segment. 86Box (SB16 at 220h, IRQ 5, MPU-401 330h, a tone through the virtual SB16 while a polled loop resets the MPU-401 and enters UART mode once a tick): the old build delivered no block interrupt and the output stuck; the fixed build plays all 54 blocks, the program's handler gets 91 MPU-401 interrupts (92 on the bare card) and no stall. Regression: SBT16 identical on seven pairings, verify-mix 0 bad in nine cases, E2TEST as before, Doom 1642 realtics (1639), Descent 2 0.9 and 1.1 clicks a second at 128 and 32 frames, Theme Hospital on both drivers and Warcraft II with the same sound, the ESS scripts as before within the trap's one-period jitter. Not yet on the real PC |
| `sb-gauntlet` | The virtual SB16, SB Pro and SB 2.0 read against Creative's two documents (the Hardware Programming Guide and the Developer Kit's Hardware Programming Reference), the DSP firmware itself (S95Sedan's disassembly of the CT1741 4.05 and the CT1341 3.02, CT1741_DSP on GitHub) and DOSBox-X and 86Box. First part (a96bfca): the ports by model (the cards before the SB16 ignore bit 0 of the DSP's ports; the status bits read 2Ah before the SB16 and 7Fh on it), reset as a 1 then a 0, the last reply read again, each model's commands with their argument counts (another model's command takes none and does nothing), 41h-47h as 40h before the SB16, the high-speed lockout of the SB Pro and SB 2.0, the CT1345 and CT1745 mixers with their read-back rules. Second part: the input commands (24h, 2Ch, 98h, 99h, the SB Pro's A0h and A8h, the SB16's Bxh and Cxh with bit 3) record silence in the game's format, as the bare cards in 86Box record from their silent inputs; ADPCM (16h, 17h, 1Fh 2-bit; 74h-77h, 7Dh, 7Fh 4-bit and 2.6-bit) is decoded by the firmware's own engine (audio/sb_adpcm.asm), fetching the reference byte and each block's first byte when the firmware does; an acknowledge that leaves no source drops a request the virtual controller has not yet given to the CPU; 45h and 47h continue an auto-init that DAh or D9h was to end (DOSBox-X). The virtual ESS (model 4) became a build option (`--virtual-ess`) so that the Sound Blasters have its room in the segment; without it a configuration for model 4 presents the SB Pro. 86Box: SBPROBE matches the bare cards except where 86Box and DOSBox-X disagree; SBT16's cases as before; the legacy and input cases give the bare SB Pro's and SB 2.0's interrupt counts and silence bytes; SBADPCM's interrupt and DMA counts match the bare cards, and its decoded waveform the firmware model (correlation 0.96-0.999); verify-mix 0 bad in six cases; MPUTONE 54 blocks and 91 MPU-401 interrupts; Doom 1655 realtics over the ESS and 1649 over the SB16; Theme Hospital, Descent 2 and Warcraft II with sound as before; Theme Hospital over the physical SB16 at 32 and 128 frames with sound throughout; Warcraft II on the virtual SB Pro (SBPRO.DIG, SBPRO2.MDI) with sound. The ESS build: the ESS scripts as before within the trap's jitter, Descent 2, Theme Hospital and Warcraft II as before. Not yet on the real PC |
| `sb-gauntlet` (firmware pass) | The SB16's and SB Pro's DSPs as their firmware runs them, under the guide (vsb-spec.md 0: Creative's documents, then the firmware, then the emulators). A command byte is decoded as the firmware decodes it (sb_decode): an undocumented member of a group runs as a documented command, and the undocumented commands take the firmware's argument counts and replies. A single-cycle command during auto-init starts at the end of the current block, as the guide says and both firmwares do (the emulators restart at once); the virtual SB Pro also chains one behind a running single-cycle block, as the 3.02 does. A reset is the firmware's cold start (10000 Hz, 48h length 07FFh, speaker off, on the SB16 only its flag, the E2h sequence from its start), or after high-speed or UART mode its warm start, which keeps them. 45h and 47h no longer undo DAh and D9h; 30h-33h drop the next byte; the SB Pro's 08h-0Fh and the SB16's 0Bh and 0Ch halt the DSP until a reset; the SB16 clamps 41h below 4864 Hz to 4986 and from 45312 Hz to 45412, and time constants from EAh to 45412 Hz; time constants down to 00h are taken. A reply waits behind one not yet read. Not followed (vsb-spec.md 13): the 3.02 drops most commands while a transfer runs, against the guide; the 4.05 loses a carry in its rate sum for 1652 rates and has a wrong entry (C8h) in its time-constant table. The ESS build presents only the virtual ESS and leaves the Sound Blasters' DSP code out (62.5 KB); a word written to 2x4h now reaches its mixer. 86Box: SBPROBE matches the firmware in every command case on the SB16 and SB Pro; SBQUEUE gives four interrupts (184/185/183/89 ms) where the bare cards give three, and two on the SB Pro behind a single-cycle block; SBT16's cases as before on every pairing, the ESS build's too; the legacy, input and ADPCM cases as on the bare cards; verify-mix 0 bad in six cases; MPUTONE 54 blocks, 91 MPU-401 interrupts; E2TEST as before; Doom 1654 realtics over the ESS and 1650 over the SB16; Theme Hospital over the SB16 at 128 and 32 frames and over the ESS, Descent 2 and Warcraft II (the virtual ESS and the virtual SB Pro) with sound as before; the ESS scripts within the trap's jitter. Not yet on the real PC: kit SBKIT for the CT2290 |
| `sb-gauntlet` (CT2290 pass) | The first measurements on Michael's CT2290 (SBKIT, the bare card; vsb-spec.md 13 and 14). The card carries a DSP 4.13, and the virtual SB16 now presents one: E1h 04h 0Dh, F4h A4h 6Fh, 43h sets the rate as 41h does, DCh takes one argument (the 4.13's tables, which add those two to the 4.05's; the other handlers, the ADPCM decoders and the RAM F9h reads are the 4.05's). The rate is the DSP's rate register, as the firmware keeps it: 41h-43h round 23 x rate / 4096 (with the 4.13's carry, so 22900 Hz plays right), 40h looks the time constant up in the 4.13's table, which rounds down and has 64h at C8h; both play the register's step, 4096/23 Hz, so 41h 22050 and time constant D3h both play 22083 Hz, as the card plays them alike (the formula gave D3h 22222 Hz, 1 percent fast). E2h with the 8-bit channel masked: the SB16 holds the byte for the DMA and takes no command until the channel is unmasked or a reset, with nothing at 22Ah, as the card and the 4.13's code do (the SB Pro, SB 2.0 and ESS answer at 22Ah as before). The CT1745 reads back as the card does: only each register's own bits, 00h for the registers it lacks below 80h, 80h's bits 7:4 as 1, 82h's as 8 (86Box's rule from DSP 4.11, and the card). Confirmed by the card as they were: the queue of a single-cycle command during auto-init (four interrupts), the mixer's reset levels, the MPU-401's interrupts (92 for 92). Open: 23h (direct input) reads FFh on the card, 80h here. 86Box: SBPROBE against the CT2290's report differs only at 23h and at 2x5h idle (whichever register was selected last); the 4.13's expectations in every command case; E2TEST's masked case gives no reply; the standard regression as before (SBT16's cases, verify-mix 0 bad in six, SBQUEUE's counts, MPUTONE, Doom 1654 and 1651 realtics, Theme Hospital, Descent 2 and Warcraft II with sound). Not yet on the real PC through uCDD: kit SBKIT2 |
| `mem-upper` | The virtual ESS's DAC ring (2.3 KB, only the CPU touches it) moves to upper memory after the host frees its loading buffer, as the CD half buffer already does; with no room it stays low as before. 86Box with the CD-ROM driver loaded low (upper memory free): the ring goes up and the largest free conventional block grows by 11.4 KB (the ring, and a 9 KB hole it used to strand below MSCDEX and the mouse driver); Theme Hospital (AUDIODRV.DIG) and Caesar II (ADRV688.DIG) play with it there. With upper memory full (the CD-ROM driver loaded high) nothing changes. Regression unchanged |
| `ess-espcm` | ESPCM 64h-67h on the virtual ESS play as silence at the chip's packing (19 samples in 10 or 8 bytes) with the block's interrupt, so a game no longer waits for ever. No document gives ESPCM's decoding; 86Box's tables are, by its own comment, part guesswork, and would take 2.5 KB the segment does not have, so only the packing is taken from it (docs/vess-spec.md 7.4). 6Ah/6Bh (every ESS sheet's third kind; 86Box plays 6Ch/6Dh instead) wait for the chip's timing (the ESPCM script). 86Box: 64h and 66h complete with one interrupt, 64 bytes' worth earlier than 86Box's chip, its known end-of-play interrupt; regression unchanged. The verify build is 47 bytes under the segment limit |
| `ess-adpcm` | The virtual ESS plays ADPCM (74h/75h 4-bit, 76h/77h 2.6-bit, 7Ah/7Bh 2-bit, the odd codes with the reference byte): the decoder sits in the model's DAC stage, one sample a sample clock, a byte from the FIFO when its codes are used up. Creative's ADPCM, which the ESS sheet names; its decoding is in no document we have, so the emulators decide: DOSBox-X's and 86Box's tables, reduced to one rule and checked entry by entry (docs/vess-spec.md 7.3). The verify build's loop counters are packed 24 a source (signature MIXVERI3) to keep it within the segment. 86Box: an ESSRUN script (ADPCM) plays one block of each kind; the 4-bit and 2.6-bit blocks match the chip's own decoding sample for sample (86Box's chip has no 7Ah/7Bh), at the right length and pitch, one interrupt each, at 32 and 128 frames. Regression unchanged (SBT16 on seven pairings, verify-mix 0 bad in nine cases, E2TEST, Doom 1639, Descent 2 1.1 clicks a second at both, Theme Hospital on both drivers, Warcraft II). The README's ADPCM advice now applies to the virtual Sound Blasters only. Not yet on the real PC |
| `host-gauntlet` | The DPMI host, its use of VCPI, XMS, EMS and JemmEx, the CD-ROM driver and the virtual 8259A and 8237A read against DPMI 0.9 and 1.0, VCPI, MSCDEX 2.1 and the data sheets (docs/host-cdrom-spec.md). Fixed: 0202h hands out a default handler instead of 0000:0; exceptions 0-5 and 7 with no handler are reflected as interrupts; a client's INT n to an IRQ's vector runs as a software interrupt; both virtual PICs decode OCW2 and OCW3 by their bits, and the host takes ICW1; an image with no audio answers the audio IOCTLs as an idle drive; demand and block DMA modes are taken as single. A deviation from DPMI that a game requires (D-7, kept by Michael under rule 1's game exception): a reflected INT 16h comes back with the client's virtual IF on, as DOS/4GW's own INT 16h does; Mortal Kombat Trilogy needs it. 0400h reports the processor the host runs on (it said 80386 on every CPU; X-Men Children of the Atom stopped with its fatal error 7 and then page-faulted in its own cleanup), and INT 2Fh AX=168Ah is answered in protected mode instead of being reflected. 000Dh is supported, with LDT entries 0-15 kept for it (the client's initial selectors moved to entries 16-20). The "MS-DOS" vendor extension is answered to 16-bit clients (D-11): Borland's RTM requires it. A client that stays resident from real mode is kept (D-12), and an exception inside a client's exception handler is delivered (D-13). READ LONG raw on 2352-byte images (M-3). An IOCTL request with the length byte 0 is accepted (M-10, Lollypop). The physical SB Pro and SB 2.0 starts wait for D1h. The ESS build starts its virtual mixer at the sheet's reset levels over a non-ESS card (it was silent). 86Box: DPMIG's five checks, CDPLAY Q on a data-only image, Mortal Kombat Trilogy to the fight with CD music, the standard regression. QEMU, for DOS/4GW's own behaviour. Not yet on the real PC |
| `ess-gauntlet` | The clean virtual ESS read section by section against docs/vess-spec.md and the ESS sheets (section 20 there). Fixed: B8h bit 2 cleared while auto-initialised DMA runs stops it after the current block; A4h/A5h reload at every counter overflow; A1h (and the clock trim) written mid-stream changes the rate at once, with the DAC clock and the mixer's position rebased; B1h/B2h bits 3:2 writable selects on the models whose sheets say so; 2x6h reads the activity, power and MIDI bits (bit 7 the physical chip's own); 2x7h trapped (untrapped, a program's power-down request reached the physical chip), stored, bit 5 to the physical FM reset, FFh on the Creative models; 2xFh reads 00h; FDh shows as powered down in 2x6h; the E2h byte resets with the card. 86Box: the ESS test scripts against the reference model as before, plus a new QUIRKS script (the mid-stream changes match the model within the trap's latency); regression unchanged (SBT16 on seven pairings, verify-mix 0 bad in nine cases, E2TEST as the SB16 now also with the channel masked, Doom 1639, Descent 2 0.9 and 1.0 clicks a second at 128 and 32 frames, Theme Hospital on both drivers, Warcraft II). Recorded, not fixed: ESPCM/ADPCM play nothing and raise no interrupt, SB MIDI is not sent out, no reconstruction filter, 2xEh bit 6 with a reply waiting (open) |
| `ess-clean` | The virtual ESS rewritten from the ESS data sheets (docs/vess-spec.md) in its own module, src/audio/ess/card.asm: virtual model 4 no longer passes through the Sound Blaster parser. Its own command table with commands by model (ES1868, 1869, 1878, 1887, 1888; the model is the physical chip's, from mixer 40h); the extension registers with the measured ES1868F reset values and the B1h/B2h decode rules; compatibility mode with the 64-byte firmware FIFO, 8-bit stereo right channel first (the real cards' known swapped stereo), 16-bit and the ESS time constants; the mixer with a register map per model, SB Pro/extended twins, SB Pro master emulation through the 60h/62h counters (Tables 19, 20) and the Table 21 level law; 2x4h and 2x6h readable; E2h answered as the ES1868F does. At install the card takes the physical chip's voice, FM, mic and record levels, and its master counters only from an identified ES1868 or later (otherwise through Table 20 from 32h); CD starts at 0 dB. Old ESS code removed from trap.asm. 86Box: the ESS test scripts (ESSRUN, written from the same specification and run by a Python model for the expected reports) match the model on registers, commands, mixer, the register, mixer and command sweeps and the stereo test; timing differs by the known trap limit (an interrupt up to one output period late for a program that does not touch a port). Regression: SBT16 identical on seven pairings, SADUMP the same but for the driver's addresses, verify-mix 0 bad in nine cases, E2TEST as the hardware on the virtual ESS and SB16, Doom 1640 realtics (1639), Descent 2 on the virtual ESS 1.1 and 1.0 clicks a second at 128 and 32 frames, Theme Hospital with AUDIODRV.DIG and SB16.DIG, Warcraft II with sound. Levels follow Table 21: voice at 15 is +1.5 dB (Descent 2 and the Warcraft II intro 1.5 dB louder than before), Warcraft II's CD music about 12 dB louder (CD at 0 dB). Found on the way: copying the master counters from 86Box's ES1688, which has none, put the virtual master 40 dB down. Not yet on the real PC |
| `reference-check-2` | The virtual ESS against the ES1868 data sheet after `ess-registers` (report in the development notes). Fixed: no SB Pro 3.2 kHz output filter on the virtual ESS (the ES1868 ignores the SB Pro filter bits and filters at the rate); D0h and D4h pause and continue the model's DMA with the FIFO playing out; the SB Pro mixer registers and their extended twins are one register, read with bits 0 and 4 set through the SB Pro address, 0Ch bit 0 reads 1; D5h answers 1; B2h bit 6 gates the DMA. Found in testing: after an ESS start the next command byte was taken as a second B8h value (D0h stopped the stream, Miles' C0h B8h read lost its reply). 86Box: ESSMIX matches the data sheet line by line, ESSAUTO P pauses and continues, ESSAUTO G gets no interrupts, a 5.5 kHz tone in SB Pro mode 10.5 dB louder (the filter gone). Regression: SBT16 identical on seven pairings, SADUMP the same but for the driver's addresses, verify-mix 0 bad in nine cases, E2TEST as the hardware, Doom 1652 realtics, Descent 2 on the virtual ESS 1.0 and 1.1 clicks a second at 128 and 32 frames, Theme Hospital on SB16.DIG and AUDIODRV.DIG and Warcraft II with sound as before. Open: the fill rate for B9h demand transfers (ESSSTAT's B9h blocks, for the real PC) |
| `miles-ess` | The Miles ESS digital driver: F2h interrupts one after the other (a held F2h raised at the next trapped access or output interrupt), and the DPMI host's delivery through the guest vector passed on to the game's handler when the card and the game share the IRQ. 86Box: Theme Hospital with AUDIODRV.DIG plays with sound on the virtual ESS (silent, then frozen, before). Regression: SBT16 identical on seven pairings, SADUMP the same but for the driver's addresses, verify-mix 0 bad in nine cases, E2TEST as the hardware, Doom 1652 realtics (1654), Descent 2 on the virtual ESS 1.1 and 0.9 clicks a second at 128 and 32 frames (0.9 and 1.1), Theme Hospital on SB16.DIG and Warcraft II as before. docs/miles-ess.md |
| `ess-irq-bits` | B1h/B2h report the virtual IRQ and DMA in bits 3:2. 86Box: SBT16 on five pairings unchanged, Descent 2 and Doom on the virtual ESS as before |
| `fast-dma` | Type F ISA DMA on the output channel through the PIIX's MBDMA0 register, behind a UCDDSET switch, set at every output start and restored at every stop; the bridge (8086h:7000h, 122Eh or 7110h) found at install. Real PC (ECS P5HX-A, PIIX3, ES1868, by the standalone tool before the driver option): tone unchanged by ear at 22.05 and 44.1 kHz; memory copy loss with the stream running 9.0 to 0.7 percent at the half rate, 18.0 to 1.5 at the full rate; Doom timedemo 1788 to 1613 realtics, full Quake 19.8 to 22.0 fps with CD music; the PIIX3 keeps bit 3 of the register, so the write preserves bits 6:3. Cards known to accept the timing: ES1868. The driver option on the real PC (combined-test 772941d, Type F on, virtual ESS into the ES1868): Doom timedemo 1519 to 1522 realtics at 32, 64, 128 and 256 frames, at the half and the full rate. On the original PIIX (122Eh) bit 3 is DMC, which selects the ISA slot's DREQ and DACK# over the motherboard pair; the write sets it there (86Box writes 89h, but does not model DMC, so the failure it prevents is not reproducible in emulation) |
| `platform-dma` | UCDDSET's "Use Type F DMA" becomes "Enable platform fast DMA" (docs/platform-dma.md). The install's PCI scan looks the ISA bridge up in a platform table (src/platform.asm), or finds an EISA machine by its ROM signature, and the driver sets that chipset's documented fast timing on the output channel while the output runs, putting the old value back when it stops: Intel PIIX, PIIX3, PIIX4 Type F by MBDMA (as `fast-dma`); Intel 82378 SIO and EISA Type A by the extended mode register 40Bh/4D6h; ALi M1523, M1533, M1543, M1535 (the M1535 by inference, no register map), OPTi Viper-M and FireStar Type F by the same register; VIA VT82C586, 596, 686, VT8231 and the AMD-756 by config 45h; SiS 5597/5598/5582 by config 71h, only while the BIOS has 70h bit 7 on. 386 and 486 ISA chipsets have a global DMA clock only, and the AMD-766/768 no ISA DMA: none. UCDDSET names the platform and greys the box where nothing is known. The old scan called the PCI BIOS even with UCDDPCI=OFF; this one does not. 86Box, one board per method (P/I-P54TP4XE, P/I-P55T2P4, AN430TX, Batman, M560, CUV4X-LS, SP97-XV, a 386 and a 486): each named right; 76h 04/89/04 (PIIX), 04/81/04 (PIIX3, PIIX4); VIA 45h 80/82/80; SiS refused with 70h bit 7 clear; the tone the same on every board; on the M560 an SB16 on DMA 5 the same with the switch on and off. 86Box keeps no DMA timing and its ISA path does not read 40Bh/4D6h, so the DCEM boards show detection and no harm, not the write. Disagreement written down (platform-dma.md 8): 86Box since September 2026 reads bits 3:2 of 40Bh/4D6h as Intel's transfer size on ALi and OPTi, where their sheets call the bits reserved or not implemented; the driver follows the sheets. Not yet on the real PC |
| `irq-counters` | The virtual Sound Blaster interrupt counted where each step happens, in the release build, and `UCDD -status [-reset]` to print the counts: raised, taken, ended by the game's EOI, block ends while unacknowledged, raised again, EOIs taken as stray (in the driver and the host), spurious IRQ 7, the output periods. 86Box: SBT16's 12 and 88 interrupts counted exactly (raised, taken and ended each), `-reset` back to 0, wrong options give the usage. The sound check (per-family recordings against runs without the driver on the SB16, SB Pro and SB 2.0) on this build: see the entry below. Not yet on the PC |
| UCDDSET layout | The main screen redone to a mockup agreed with the fork's owner: the box one row taller, Options and Detected columns, tick boxes that grey themselves with a help line saying why, the chipset named. Tested in 86Box and accepted by the fork's owner |
| Program button | Added to UCDDSET for the jumperless Sound Blaster 16 boards, then dropped: UNISOUND sets those boards through the same registers and the README already requires the card set before install |

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
0.9.3b; the mixer and refill changes of the performance pass came later
and their 386 and 486 figures are under "Performance". Every instruction takes the same time there, so a real 386, where a
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

- Shellshock: DOS/4GW's divide error in its PIT clock (it reads 3 ms
  back). Measured 19 Oct: 1.2 million single steps in about 70 s, and
  every timer interrupt that reached the game 1 to 5 ms late arrived while
  its virtual interrupt flag was off. The cost of stepping interrupts-off
  regions (D-8) is the cause; open.
- Battle Race 95 stops before "press any key": it polls the 16-bit DMA
  count with interrupts off until two reads agree, and under the host the
  reads are too slow for the moving virtual count (spec section 10).
  DMACNT.COM measures the real card's count to copy; open.
- Mortal Kombat Trilogy's sounds 2.3x long (F14 on `sound-engine-library`),
  found 19 Oct (hardware: Michael's recording x2.22; 86Box x2.38). Cause:
  DOS/4GW passes IRQ 5 down to the Miles driver's real-mode handler with an
  INT to the hardware vector. The host's reflection (dos.asm .hardware)
  marked the next EOI stray for every hardware vector, on the belief that
  it had queued the IRQ and sent its EOI. For the virtual Sound Blaster
  interrupt it had not: the handler's EOI was swallowed, the virtual
  interrupt stayed in service, and the card replayed its buffer halves
  until another EOI ended it two to five blocks later (traced: 58% of
  block ends overran, 0 of the game's protected-mode EOIs reached the
  driver). Fixed on `stray-eoi`: stray only when the host held that IRQ in
  service (dpmi_pic_reflect's carry). 86Box: overruns 0, every block
  acknowledged within one period, the sounds x1.00 against a run without
  uCDD (runs on 86Box's own CD drive). Not yet on the PC. Open beside it:
  CD music in MKT's logos shows a ~80 ms repeat then 20 ms catch-up steps
  around the restarts, in D7 too; to be looked at.
  A family fault, not MKT's (86Box, 28 games traced without and with the
  fix): Theme Hospital, Dungeon Keeper, Redguard, Little Big Adventure 2,
  Motor Mash, Time Commando, X-Men: Children of the Atom, GTA, Bust-A-Move
  2, System Shock and Jagged Alliance had 15-77% of their blocks overrun,
  and Heroes II, Oddworld, Test Drive Off-Road, Star Command Revolution,
  Warcraft, Albion, Caesar II, The Settlers II and X-COM (DigPak) had their
  EOIs swallowed without audible harm; with the fix all 0% (Motor Mash 1%).
  Two kept overruns: Fade to Black (F15, open) and Duke Nukem 3D (F16),
  which was not the driver: the copy traced had Duke's own config on IRQ
  7 with the cards on 5, and it fails the same way without the driver.
- Space (20 Oct, every irq-counters build with NASM 3.02): the DPMI host is
  65267 of the 65535 bytes build.py allows (268 free); the driver 63495 of
  65536 (about 2 KB free), the verify-mix build 65031 (505 free), the
  virtual ESS build 64563 (973 free). The next host fix or host
  diagnostic has to find room first (rings, trims) or move code out.
- Inca II's "not enough extended memory" is its Phar Lap 286 extender
  above 16 MB of free DPMI memory; not ours.
- Super Street Fighter II Turbo: dropped (Michael, 18 Oct). Its 32RTM
  loader writes CR0 and then needs DOS translation for 32-bit programs, a
  host feature of its own for one game; runs without the driver.
  Shellshock: DOS/4GW divide error in its own timer
  code when the timer interrupt arrives late (a latency question). Mass
  Destruction: fixed on `cdrom-bit10` (M-5, status bit 10 as OAKCDROM
  sets it).
  docs/host-cdrom-spec.md section 10.
- Star Command Revolution: its intro stopped at the first frame under the
  driver. The game (DOS/4GW) runs RAD's Smacker player through
  COMMAND.COM; the player is CauseWay, which takes VCPI first, and a
  program started by a DPMI program still saw VCPI, so it drove the card
  behind the traps. Fixed on `vcpi-children` (D-16): children see no VCPI
  either and become children of the host. 86Box: logo, intro and main
  menu as without the driver. Not yet on the PC.
- Chasm: The Rift runs on `locked-stack` (D-15): RTM, a 16-bit client, was
  given 32-bit stack segments for the locked stack; its LEAVE then loaded
  ESP from an EBP with a stale upper half (a stack fault on the real PC,
  a general protection fault in 86Box). With 16-bit stacks the game enters
  its level in 86Box. Not yet on the PC.
  MSCDEX 2.25 listed nothing on its CD-i Bridge disc under the driver
  until `cdrom-bit10` (M-5, device status bit 10); with the disc listed it ends
  in "Memory allocation error" as Beta 0.9.3b did (memory not given back,
  not a broken chain, as checked on 18 Oct without bit 10). Runs without
  the driver. docs/host-cdrom-spec.md section 9. The real PC uses SHSUCDX,
  which lists the disc.
- Mortal Kombat Trilogy's CD music paused for 0.3-0.5 s every 5.5 s
  during the logos (Michael's recording from the real PC, 19 Oct; 86Box
  the same). Fixed on `cd-restart` (M-12): the host's CD refill waited for
  the game's end of interrupt on the virtual Sound Blaster, which looked
  unsent for about 3 s after each sound. Corrected 20 Oct: the game sent
  it; the host swallowed it as a stray EOI (the stray-eoi entry above).
  The fix stands: a drive's audio does not wait for a game's EOI. The same
  branch makes PLAY AUDIO return after a short fill (M-11). 86Box only so
  far.
- Hexen: the machine sometimes freezes after the game exits. The launcher
  log shows the game returned and the image was unmounted first. A test
  client that makes Hexen's CD calls, followed by a second protected-mode
  program, does not reproduce it in QEMU. Not reproduced in 86Box either
  (`host-gauntlet` 824d2da, the SB16 physical and virtual, the shortened
  disc with three audio tracks): ten passes in one boot, five ending with
  the demo's timed exit and five quit through the game's menu with
  LaunchBox for DOS run and closed after each unmount.
- Mortal Kombat Trilogy hangs at the Battle screen, at a CD track change.
  Understood on `host-gauntlet` (docs/host-cdrom-spec.md, D-7 and section
  7): the game leaves interrupts off and relies on its keyboard poll to turn
  them on, which DOS/4GW's own INT 16h does and the host's reflection did
  not. Fixed there for INT 16h alone, a deviation from DPMI the game
  requires; the game reaches the fight with CD music in 86Box. Not yet run
  on the real PC.
- The Need for Speed SE hangs while it loads a race. It also hangs with the
  data-only driver, so this is probably not the audio host.
- Descent II: crackle in the intro audio with every build tested on
  hardware. The filter fix in `single-cycle-start` removes a click of this
  kind in an emulator; whether it is the same fault is not known. With the
  game set to ESS under the virtual ESS the crackle is understood and fixed
  (`ess-position`, under "Limits" above); with the Sound Blaster 16 setting
  86Box shows none, so the hardware report there is still open.
- The Miles ESS digital driver (AUDIODRV.DIG; Theme Hospital, Dungeon
  Keeper, Heroes 2 and 13 more in the libraries) under the virtual ESS.
  Three faults in turn, all in 86Box:
  - `miles-irq` (earlier): the F2h interrupt was not delivered while the
    game sat in a real-mode call; fixed in the trap exit.
  - `miles-ess`, F2h: the F2h interrupts came at once instead of one after
    the other; fixed with the hold above.
  - `miles-ess`, delivery: with the card's IRQ and the game's the same
    (7 and 7), the DPMI host delivered the virtual interrupt by running the
    guest vector in real mode. That vector is the driver's own handler,
    which found no physical interrupt and returned as from a spurious IRQ
    7, so the game's handler never ran and its playback waited for ever
    (the intro froze on its first frame). Fixed: `audio_irq` passes such an
    entry to the game's handler (`audio_irq_reflected`, the delivered mark
    1 from the host, 2 from the driver's own paths).
  Theme Hospital with AUDIODRV.DIG (IRQ and DMA -1) now plays its intro
  with sound on the virtual ESS. The full account, the driver's sequence
  and how it was traced: docs/miles-ess.md. Not yet on the real PC.
- HMI's 16-bit ESS modes (E01Bh, E01Ch) are silent on 86Box's bare ES1688
  too, so they are untested; their register sequence is the 8-bit one
  with another format byte (B7h F4h, BCh).
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
- The `--verify-mix` build never counts the CD-only mix on a physical
  SB16 (0 calls while the output runs): that store path bypasses the
  harness. The ESS and SB Pro physical paths are covered.
- The clock trim is applied on the ES1868 and ES1878 only (mixer 40h
  identification 18h then 68h or 78h, and BAh bit 6 following writes;
  both data sheets in the reference library document the sequence and the
  bit, the ES1878's with the ADC offset adjust in the low bits, which
  the trim write leaves at zero).
  The ES1869's manual gives BAh as the left ADC offset adjust register
  and documents no clock trim, so its 69h code is refused on purpose; the
  ES688, ES1688, ES1887 and ES1888 document no trim either. All of them
  run the interpolating path.
- Descent 2 with HMI's "ESS 488/688" digital driver hung black and silent
  under the virtual ESS (real PC, then 86Box): the driver programs an ESS
  transfer count of 61441 bytes, odd, over a 4 KB buffer of 8-bit stereo
  and polls the DMA position, and the start path refused the block for
  not being whole frames before it looked at whether the block was longer
  than the buffer, which only means polling. Fixed: a block longer than
  the buffer skips the frame check. 86Box: the intro plays 122 s of audio
  matching the bare chip; SETUP's 8-bit test plays. Not yet on the real
  PC with the fix.
- Descent 2 on "ESS 488/688" then crackled about 40 times a second (real
  PC, recorded at the speakers with both cards ESS, full rate, Type F off
  and on; 86Box 36.7/s at 128 frames, 38.2/s at 256, mostly three output
  periods apart; the bare ES1688 1.4/s, the detector's floor on that
  audio). HMI's driver rewrites its buffer right up to the DMA count it
  polls, and the count ran one output period ahead of what was safe.
  Fixed (`ess-position`): the virtual ESS's polled count of an
  auto-initialised transfer is reported one period behind the mix.
  Replaced on `virtual-timing` by a count that follows the output clock
  (the frame being heard) for every model, never past the mix: Descent 2
  on the virtual ESS 0.9/s at 128 frames and 1.2/s at 256, 8-bit mono
  0.7/s, the SB16 setting 1.3/s as before. 86Box:
  1.0/s at 128 frames and 1.1/s at 256; one period ahead instead gives
  117/s. Only the virtual ESS's count read changes; the SB models and the
  interrupt timing do not. Why exactly one period is the safe margin is
  not understood from the code (`game_mix_frame` should already equal
  the read position). The Sound Blaster 16 setting of the same game is
  clean on 86Box with and without the change. Not yet on the real PC.
- The virtual ESS's B1h and B2h. The ES1868 data sheet makes bits 3:0
  read-only, decoding the IRQ (2/9 0000, 5 0101, 7 1010, 10 1111) and the
  DMA channel (0 0101, 1 1010, 3 1111). The ES1868F reads 1Ah after
  UNISOUND at IRQ 7 and DMA 1, keeps bits 3:0 through writes of 5Ah, DAh
  and 50h, and does not take bit 7 in B1h (DAh reads back 5Ah) while B2h
  does (ESSSTAT, 15 Oct 2026). The first fix (`ess-irq-bits`) put a two-bit
  code in bits 3:2 only, over a 50h base, and let games write bits 3:0.
  Fixed (`ess-registers`): bits 3:0 carry the data sheet's code and ignore
  writes, B1h bit 7 is dropped, and the reset value is 10h plus the code,
  as the chip reads. AUDIODRV.DIG reads them when its DIG.INI leaves IRQ
  or DMA at -1; ADRV688.DIG keeps bits 3:0 in its read-modify-write.
- The Miles ESS digital driver (AUDIODRV.DIG) tests the card with F2h:
  two F2h a few microseconds apart, then a spin with no port access until
  its interrupt count reads exactly 1, then F2h and a spin for 2, then F2h
  and a spin for 3. On the ES1868F each F2h raises its own interrupt
  11.7 to 14.2 us after the command, one after the other (F2TEST, 15 Oct
  2026). The virtual card raised each inside its own trap, the count went
  from none to two, and the driver found no card. Fixed (`miles-ess`): an
  F2h within 8 trapped accesses of the last one raised is held and raised
  at the next trapped access or output interrupt. Details, and the second
  fault this uncovered, in docs/miles-ess.md. The next step of the same
  test, the E2h DMA identification, matches the hardware: E2TEST (four
  arguments after a reset, one byte each by single-mode write DMA on
  channel 1) reads 40h 30h F3h 98h with the 8237 TC bit, and 40h through
  22Ah with the channel masked, on 86Box's SB16 and ES1688 and on the
  virtual SB16, SB Pro and ESS alike.
- The virtual ESS AudioDrive plays only: B8h with its direction bit
  (recording) is refused, and the ESPCM and ADPCM start commands, and the
  16-bit compatibility-mode commands 11h, 15h and 1Dh, are the SB Pro
  parser's refusals. Port 2xCh is the FIFO status since `ess-registers`
  (docs/ess-fifo.md). Of the mixer's ESS registers, the SB Pro registers
  and their extended-access twins (14h, 32h, 36h, 38h, 3Eh) act; the
  serial-mode and input registers (42h to 4Eh) are stored only. Its FM side is
  whatever sits at 388h, which the driver never traps: the real ESFM on a
  physical ESS, and that is why UCDDSET offers the model with one only.
- While the driver has stepped aside (no disc bound for CD audio, cards
  matching, the "always on" box clear in UCDDSET) there is no
  virtual card: a game set to the virtual WSS codec finds nothing, a game
  that needs a DPMI host finds none unless it brings its own, and the state
  changes only at a mount or an eject from the command line or UCDDPLAY.
  An MDM list counts as an audio disc when any member has audio tracks. A
  mount while a game runs does not switch, and a stepped-aside driver that
  fails to engage at a mount (the card did not start) sets bit 7 of the
  fault byte and leaves CD audio silent until the next mount.

## The author's releases

### UPA6: the author's Beta 0.9.4-a6 merged into our line (24 Oct 2026)

- What: the author's releases 0.9.3c to 0.9.4-a6 (19 commits after
  0.9.3b, our base) merged into count-position on the branch merge-a6.
  The fork's main carries his releases only (fast-forwarded to a6 on 24
  Oct).
- Rule for this merge (Michael, 24 Oct 2026): his fixes take precedence
  over ours. Where both sides fixed the same behaviour, his version is
  kept and ours removed; where ours does something his does not (the DSP
  4.13 identity and the command tables by model, the count position D1,
  the 512-frame ring, the interrupt counters, the virtual ESS, F14), ours
  is kept and fitted to his code. Where his behaviour disagrees with the
  documents or the CT2290's measurements, his is kept and the disagreement
  is written below as a row for later (mantra rule 7).
- Citation: the documents are silent on which implementation to keep;
  Michael's rule decides. Each behaviour's own citation stays with its row.
- Family: none: the whole driver, every engine.
- Baseline: count-position 00b13de; the author's a6 8252786.
- Trial merge (24 Oct): 36 files conflict, about 130 places, about 4,500
  lines in the markers; trap.asm 40 places, 1,558 lines.
- Room: the DPMI host at 32 frames is 65,251 bytes on count-position and
  62,417 on a6 (0.9.3b: 59,361); both sides' additions together come to
  about 68,300, over the 65,535 limit. Taking his version where both fixed
  the same thing gives some back; if it still does not fit, start-up code
  moves out of the resident segment as he moved the driver's command
  parser in a1 (Michael, 24 Oct).
- Testing: held (Michael, 24 Oct). The merge is built, not run.
- Room (built): the host could not stay in one 64 KB image (66,480 bytes
  merged: gateway 7,968, install code 3,323, protected 55,184). The install
  code (.scratch) now comes before the protected part, so it still runs in
  real mode below 64 KB while the protected part, which runs from XMS with
  32-bit offsets, ends above it; the driver reads the image in two parts
  (audio/resident_host_init.asm) and XMS is sized for the install code's
  tail copied with it. This is the start-up code moved out of the way, as
  the author moved the driver's command parser in a1 (Michael, 24 Oct).
- Built (24 Oct) [build]: --resident-audio at 32 frames (--no-refill-hint)
  and at 128, the plain build, and --virtual-ess all assemble with no
  warnings but the section-crossing notes the tree always had. UCDDHOST.BIN
  66,480 bytes, UCDD.EXE 65,080 (131,568 with the host). Not run anywhere
  (testing held).
- Lost for now, each to be put back on the author's code:
  - mix_run's fast loops and mix_verify (the 386 work; --verify-mix gone);
  - the ESS half-rate output (model 5 plays at full rate meanwhile);
  - our ADPCM engine (sb_adpcm.asm): auto-init ADPCM (1Fh, 7Dh, 7Fh) is
    unsupported, as in his;
  - the virtual ESS build's mixer hooks (it assembles; its sound is not
    checked);
  - the stray-EOI marks where his host now hands the EOI to the real-mode
    handler (F14's design): F14's known-bad games (Mortal Kombat Trilogy,
    Theme Hospital) must pass the sound check before any kit.
- F2 at 32 frames [read]: his ring is RING_PERIODS periods (3 by default),
  96 frames at 32, and his mix_catch_up mixes RING_PERIODS-1 periods ahead.
  output_clock reads within the ring, so a period interrupt late by more
  than about two periods (1.5 ms at 32 frames) aliases the clock again, as
  before 7994cd1; a larger ring would also mix the game's stream further
  ahead (F18). His default of 128 frames gives 384 frames (8.7 ms). For
  testing at 32: --audio-ring-periods up to 4 (build.py), up to 8 in
  layout.inc. The fix, for later: a ring size apart from the write-ahead.
- The driver's block for the host (24 Oct, found after the merge commit
  52b2a41) [read]: both sides had grown it from CDF3, the author to his
  CDF4 (his JemmEx fields at +20 and +22) and the fork to CDF8 (the disk
  IRQ mask at +20, then the stray EOI byte, the delivered byte, the fast
  ports and the model). The merge took his sb_patch.asm, so the driver sent
  his CDF4 and the host read our CDF4 field from it: the disk mask from his
  JemmEx field, and none of our later fields. Now CDF9: his CDF4 as it is,
  then our fields 4 bytes on; the host reads CDF9, and his CDF4 and older
  as he does (host/resident.asm, host/v86.asm, audio/sb_patch.asm).
- sb_patch.asm (24 Oct, found while isolating the step-aside branch)
  [read]: the merge took the author's file whole, and with it went three of
  ours besides the patch design his remix replaces: the delivered mark in
  sb_real_irq (our virtual PIC ends the game's interrupt only once it is
  delivered: without it the virtual interrupt stayed in service after a
  delivery through audio_irq's jump), the CLD in sb_patch (the remix runs
  from the port trap with the game's direction flag), and the step-aside
  check in sb_dos_vector. All three are back.
- Before any kit: regression list a at 32 frames, the sound check (with
  F14's games, Hexen, Descent), the CD mounts (an audio-only sheet, INDEX 02,
  a byte-order mark), UCDD.CFG from each older version (our 4 at 38 bytes,
  his 4 at 42, version 2 at 36), and the step-aside (dpmi_dormant moved to
  byte 10).
- The merge table, each place both sides changed (his = the author's a6,
  ours = count-position):

| Place | His (a6) | Ours (count-position) | Kept |
|---|---|---|---|
| host_emm.asm | trap list for EMM386 adds 08h, D0h | file removed with EMM386 support (340de2c, 12 Oct) | ours: EMM386 support stays out (a design decision, not a fix; EMM386 cannot trap the 8237) |
| layout.inc, the ring | three periods, missed periods mixed (a6) | 512 frames, one period mixed ahead (7994cd1, F2) | his (same fault) |
| ports.inc | 08h, 0Ah-0Fh | 08h, 0Ah-0Ch, 0Dh-0Fh | his (the same ports) |
| sb_state.inc | record and remix state | single-cycle hold state | both |
| host_jemm.asm host_io_irq | the priority check while a client runs | delivery during a client's real-mode call | both (different paths) |
| mixer.asm, the game's FM level | fm_update with the FM fader (a6) | fm_update by card model (archive findings 19) | his (same behaviour) |
| mounted.asm, the play request's first fill | four times the request limit (a1) | CD_PLAY_FIRST (e24fcfd) | his (same behaviour) |
| mdm.asm | the mouse vector kept | the list's audio flag (step-aside) | both |
| config_file.asm | the FM fader's bound | the two option boxes' bounds | both |
| setup/screen.asm | box 22 rows | box 24 rows (Options, Detected) | ours (our rows; his layout has no conflict with it) |
| config.asm, UCDD.CFG | version 4: eleven keys, the FM level in the pad byte (42 bytes) | version 4: the disk IRQ in the pad byte, step-aside, fast DMA (38 bytes) | both, as version 5 (45 bytes): his record, then our three bytes; UCDDSET converts each older file by its size (setup/config_file.asm) |
| config.asm, the DSP version default | 4.05 | 4.13 (the CT2290), ESS 3.01 | ours (UCDDSET sets it by model in both) |
| guest_config.asm, the game volume | the PCM fader through sb_pcm_update | guest_scale at install | his, called after the virtual mixer reset |
| guest_config.asm, the EMM386 port list | translated | removed | ours (EMM386 stays out) |
| resident_init.asm, the ring's memory | two rings in one block, ring_place | one ring, a power of two, a block twice the size when it crosses a page | his, with our ESS half-size ring and the SB Pro's byte past the ring |
| resident_init.asm, the first fill | mix_fill | two silent halves and ring_fill | his; our counters' start tick kept |
| build.py | --audio-ring-periods, the default period 128 | our build options (32 frames by default) | both; his default period (128); testing still passes --audio-period-frames 32 |
| setup/blaster.asm, the BLASTER field bound | the field dropped with BP | the field dropped with field_start (audit 7) | his (same fix) |
| host/monitor.asm, the real-mode register copy | byte copy; TF and NT cleared | dword copy; TF cleared | ours' copy (the count is in dwords on our side), his flag mask |
| cue.asm, the start | QUOTE_ERROR | the CUE text in its own block (CUE_FAR) | both |
| cue.asm, a UTF-8 byte order mark | skipped (a1) | refused | his, on both text paths |
| pro_output.asm, the SB Pro priming wait | two BIOS ticks | 65535 port reads (audit 1) | his (same fix) |
| pro_output.asm, mono output | ES set to the ring | 1Ch auto-init on DSP 2.00 and later (archive findings 21) | both |
| setup.asm, Ctrl+Break | ignored (break_ignore) | a handler that keeps control | his; our INT 24h handler kept |
| setup.asm, messages | reworded | the mono tone and the 386 messages | both (his wording) |
| README.md, RELEASE-NOTES.md | his text | the fork's notes | both; the fork's notes say the merge is in |
| helper.asm, unmount by CUE name | his (a1) | ours | his (same fix) |
| helper.asm, the help text | short | long, with -status | his short text with our -status line; our status labels kept |
| helper.asm, arguments | a buffer in the second segment | the DOS save area | his |
| background.asm, the timer refill | a shared cd_refill_run, a read budget per tick, the wait for a whole DSP command, entry from the audio IRQ | 4 reads a pass; the MPU-401 line check | his; our line check kept on the tick |
| background.asm, the deferred refill | held while the virtual interrupt is in service | held only until the host delivers it (b3dca2f, F14) | ours (his has the old check; ours is a fix his lacks), with his DSP wait |
| sb16.asm, the period handler | mix_catch_up from the DMA position | one slot after the playing one; late counters | his; our late counters kept (now against the period before the clock's), the virtual ESS FIFO service and profile marks kept |
| sb16.asm, ring_offset and ring_place | his ring arithmetic | the ESS half-rate ring | his, with the half rate added |
| sb16.asm, the output EOI | specific EOI | non-specific; the polled path (sb16_line_check) | his EOI, our polled path |
| sb16.asm, an interrupt not the card's | chained as an interrupt, ended if still in service | to the game's handler when the host reflected it | both: ours first, then his |
| mix.asm, the whole mixer | the sample fetch (sb_dma_sample: formats, memory above 1 MB, page wrap), interpolation at low rates, his fast paths, the record segment | our fast paths (mix_run, mix_verify), the ESS half rate, ADPCM by the firmware in the mixer, the virtual ESS's 16-bit data | his whole. Lost for now, to restore on his mixer: mix_run's 386 fast paths (--verify-mix removed with them), the ESS half-rate output, the virtual ESS build's mixer hooks |
| standby.asm, re-engaging | (none) | two silent halves and ring_fill | his mix_fill |
| sb_patch.asm, a block restarted or moved at its end | sb_remix over the record segment (a4) | the next half patched (sb_patch_base) | his; our hold of a stream's first interrupt (sb_single_hold) kept before virtual_irq_tick |
| irq.asm, virtual_irq_tick | the silence command's interrupt (80h) | the virtual MPU-401 refresh, the virtual ESS's own time | both |
| irq.asm, the end of a single-cycle block | ADPCM byte units | .controller_stop (the 8237's position and count), 91h and the warm flag, ADPCM by the firmware | ours with his ADPCM units; our ADPCM close dropped (his ADPCM) |
| irq.asm, virtual_pic_write | ICW words to the controller, special mask, set priority, the host's specific EOI, the host's EOI ownership (0.9.3c) | ICWs counted off, poll and read select, EOI forms with level and rotation bits, the stray EOI (F14), the delivered mark, the counters | his decode and host calls; ours for the forms his lacks (poll, level and rotation bits), the stray EOI, the delivered mark and the counters |
| host/interrupts.asm, the interrupt flag | interrupts-off regions run at full speed, marked with NT (a1) | more PUSHF/CLI patterns, a hashed site table, an armed region run once | his whole (the same area; ours tuned the stepping his replaces) |
| host/pic.asm, the client's controller commands | special mask, rotation and set priority, priority-ordered EOIs | ICW1 counted off, poll and read select, EOI forms with level and rotation bits, the plain-EOI forward | his decode with ours' forms his lacks and our plain forward |
| host/pic.asm and the chain to a real vector | the real handler owns the EOI (dpmi_real_eoi) | the host's EOI already sent, the handler's marked stray (F14) | his; our 0300h path (dpmi_pic_real_int) brought to his ownership model |
| host/dos.asm, a reflected hardware vector | the real handler owns the EOI | the handler's EOI marked stray when the host held the IRQ (2e85975, F14) | his |
| host/dos.asm, INT 2Fh in protected mode | 168Ah through dpmi_vendor_query (both client sizes); INT 33h 0Ch | 1686h answered 0; 168Ah for 16-bit clients | his 168Ah, our 1686h and INT 20h; INT 31h 0A00h stays on ours (dpmi_vendor_entry) |
| host/dos.asm, 32-bit DOS calls | the path and short-buffer calls translated; 51h/62h, 09h | (none) | his |
| host/dpmi.asm, INT 67h DE00h | VCPI kept for the host's own query (nested clients) | VCPI shown while stepped aside (dpmi_dormant) | both |
| host/dpmi.asm, the state block the driver shares | bytes 4-9: the real EOI owed, its priority, the pending entry, the refill flag | byte 4: dpmi_dormant | his layout; dpmi_dormant moved to byte 10 (audio/standby.asm writes it there) |
| host/dpmi.asm, a nested client's exit and start | the stack blocks freed; the parent's descriptors, callbacks and vectors inherited | the nested PIC restored; exception-chained cleared; the parents' callback slots kept off limits | his inheritance and frees, our PIC restore and exception flag; our callback slot rule dropped (his children share the parent's callbacks) |
| host/dpmi.asm, the client's SS | 1Fh | DPMI_CLIENT_SS (97h: LDT 0-15 kept for 000Dh, D-11/D-12) | ours, after his bridge update |
| host/dpmi.asm, 0400h's processor type | dpmi_cpu, detected at start | dpmi_cpu_type | his |
| host/dpmi.asm, the armed region | his inline check | dpmi_irq_waiting, a region run once before stepping | his; dpmi_irq_waiting kept for our STI-shadow skip (d709be0) |
| host/locked.asm, the locked stacks | LDT 6 and 7, 32 KB (eight levels, a4), 16-bit for 16-bit clients | LDT 21 and 22 (0-15 kept for 000Dh), 16 KB, 16-bit for 16-bit clients (D-15) | our slots, his size |
| host/locked.asm, deliveries | hardware and software forms (the interrupted registers kept for hardware) | the delivered mark; INT 1Ch, 23h, 24h keeping the virtual IF; the bridge's carry | his forms; our reflected deliveries as his software form; our delivered mark and carry kept |
| host/resident.asm, the driver's CDF block | CDF4 read as CDF3 | CDF4 to CDF8 (disk IRQ mask, stray EOI, delivered mark, fast ports, virtual model) | ours (the driver sends CDF8) |
| host/resident.asm, the retrace refill window | ends at 384 frames; the client-level check gone | ends one period past 128; an almost empty queue does not wait | his |
| host/resident.asm, wide port access | split into bytes, as the ISA bus does (a3) | word accesses other than the mixer's refused | his |
| host/resident.asm, the cheapest virtual card ports | to the driver | answered in the host (CDF7, 27eae6d) | ours |
| driver.asm, request and IOCTL lengths | ignored, as drives do (a2, a3) | length 0 accepted for IOCTL and headers | his (same fix) |
| driver.asm, IOCTL input | the location code no longer sent to the audio driver (a1) | the CHANGED state kept until the redirector rereads the disc | both |
| driver.asm, eject | an MDM set keeps the set and ejects the current disc (a1) | eject allowed while the driver's own audio is bound | both |
| driver.asm, READ LONG | Red Book addresses (a1) | Red Book addresses with field checks; raw mode on whole-sector images (M-3); CHANGED seen | his addresses; our raw mode and CHANGED |
| driver.asm, the ISO header | a larger volume clamped; nonstandard root record names (a2) | the same two (1c9d123, the clamp) | his (same fixes) |
| host/bridge.asm, real-mode software interrupts to protected mode | INT 1Ch (0.9.4: the BIOS timer callback) | INT 1Ch, 23h and 24h (DPMI 0.9 2.4.2; INT 23h's carry back to DOS) | his for INT 1Ch; ours for INT 23h and 24h; the entry dispatch sends each to its path |
| host/bridge.asm, the IRQ stubs | a chained IRQ passed once; IRQ 0 and 1 handed to the real chain when owned | disk controller IRQs straight to real mode; a spurious IRQ 7 or 15 dropped | both |
| trap.asm, output_clock | the clock on a ring of any period count | count pairs in one JemmEx call (IRQCOST), the power-of-two ring | his arithmetic, our count pairs |
| trap.asm, the trap entry | its own stack when a game's is short (a6); the port and value kept for the refill's DSP wait | profile marks, the F2h service, the MPU-401 line check | both |
| trap.asm, a word read of the mixer ports | .wide_read (a2) | the virtual ESS's word port | both |
| trap.asm, DSP reset | the silence and pending-DMA states cleared | the firmware's cold and warm start (SBG) | both |
| trap.asm and sb_mixer.asm, mixer writes | inline, 81h selecting the 16-bit DMA channel, the FM pair to fm_update | the CT1745 by model (sb_mixer.asm), 80h-82h read only | ours by model, with his 81h write added (the CT2290's 81h is writable, F12) |
| trap.asm, the 8237 mode register | demand mode as single (0.9.4) | demand and block as single, cascade refused (8237A data sheet) | ours (the same result for demand mode) |
| trap.asm, master clear and all-mask | his, through dma_output_channel (a3) | ours, through dma_ring_controller | his; our command register (port 08h) and our unmask follow-ups (the identify release, the WSS input) kept |
| trap.asm, the DSP command decode | a chain of compares with his additions | the table by model from the firmware (4.13, 3.02, 2.01) | ours, with his additions in it: 00h ignored, 45h and 47h (his handlers), single-cycle ADPCM taken before the table to his start |
| trap.asm, ADPCM | single-cycle: converted to PCM in his mixer (a3); auto-init not played | single-cycle and auto-init by the firmware's engine (sb_adpcm.asm) | his; sb_adpcm.asm removed; 1Fh, 7Dh, 7Fh now unsupported, as in his |
| trap.asm, the legacy start | ADPCM played mono | input and output, stereo by the mixer switch and A8h (SBG) | ours with his ADPCM mono |
| trap.asm, the SB16 mode byte | reserved bits ignored (Team F1) | reserved bits refused | his |
| trap.asm and irq.asm, 80h silence | a deadline in output periods (a2) | an end frame from the output clock | his deadline, raised through our virtual_dsp_raise; our silence state removed (the SB Pro status bit reads his) |
| trap.asm, a start on a masked channel | waits for the unmask and replays (0.9.4, F5's case) | refused (F5 open) | his, in our handler form |
| trap.asm, block and buffer sizes | short blocks of one period, buffers to 64 KB (a3) | 512 bytes to 32 KB; a block longer than its buffer need not be whole frames (HMI's ESS driver) | his sizes, our rule for a block longer than its buffer |
| trap.asm, an 8-bit block past its 64 KB page | wraps to the page start, as the address counter does (a6) | refused | his |
| trap.asm, a DMA buffer above 1 MB | every format, single-cycle and auto-init (a2) | 8-bit mono single-cycle only | his |
| trap.asm, the transfer's source address | pending_source_segment and offset (page wrap, memory above 1 MB) | from the block's address; our ADPCM engine's first fetch | his |
| trap.asm, the 3.2 kHz filter between blocks | cleared at each start | kept when a block follows a filtered one (archive findings 4, the click) | ours |
| trap.asm, DMA status and other controller reads | TC cleared on read, the request bit for a waiting start; 0Bh, 0Dh, 0Fh read from the controller | the ring's channel hidden, the TC from the emulation | his, with our ring hiding |
| trap.asm, the mixer index port read | the index on every model (Hexen, a2) | FFh on the SB16, the index on the SB Pro | his (the SB 2.0 still FFh) |
| trap.asm, the DSP write status | one read in eight busy (a3) | busy in reset, high speed and while a string reply waits; the other bits by model | both: ours' conditions, then his one read in eight (F13 still open: the card's pattern differs) |
| trap.asm, the mixer data read | mixer_read | virtual_mixer_read by model | ours |
| trap.asm, the trap's exit | the waiting start replayed | the queued single-cycle command started (the guide's queue) | both |
| trap.asm, data | his ADPCM tables, the trap's own 512-byte stack | our DSP state | both |
- Evidence state (24 Oct 2026): built, not run; no emulator claim and no ledger entry; prove under plan 45bc14ec (list a) and plan cdee6f75 (the sound check, once it has recompiler-off references: DYNAREC) before this reaches fixes.

## The count and the block interrupt

### F8: the count short of the boundary at an auto-init block interrupt (23 Oct 2026)

- Symptom: the CT2290's 8237 count sits on the block's boundary at every
  block interrupt; through uCDD it was about 7Dh short (hardware: HWKIT,
  19 Oct, D7 and D9 at 128 frames; F8 on `sound-engine-library`). In 86Box
  at 32 frames (irq-batch, regression r32ib) every auto-init case of SBT16
  reads the count short of the boundary in each of its first eight block
  interrupts, by 8 to 122 units, about one to two output periods; every
  single-cycle case reads it on the boundary.
- Citation: vsb-spec 7.8 (one position, the card's fetch point: the count
  moves sample by sample, never passes what uCDD has taken, never moves back
  within a lap, and the block interrupt comes when that position crosses a
  block's end); 8237A.txt:253-256; SBG:1590; ct2290.md.
- Family: none: the virtual card's count and its auto-init block interrupt,
  under every engine. Surveyed: DMX (mixes one block ahead of the count,
  F18), HMI (writes up to the count), LucasArts' iMUSE (F2), Miles
  (auto-init half-buffer interrupts), others (MIDAS, DSMI).
- Baseline: irq-batch at 32 frames (r32ib) and the bare cards of the same
  regression.
- Reproducer: rsum's count at the block interrupt (ucdd-bench 00ce121):
  fails r32ib and r32d9 in every auto-init case; passes the bare cards in
  all 40 cases of both runs (L4).
- Cause [read]: for auto-init the block interrupt follows the mix
  (virtual_irq_tick through game_elapsed, which returns game_mix_frame, what
  uCDD has taken), while the count follows the output clock (trap.asm
  .dma_read: the smaller of the clock and the mix). Two positions one to two
  periods apart: at the interrupt the count is that far short.
- Hypothesis: one position for auto-init, the output clock plus one period,
  never past the mix and never back within the transfer. game_elapsed
  returns it, so the count, the block interrupt, the current block of DAh
  and D9h, and the pause snapshot all use it; virtual_irq_tick takes the
  clock its caller has just read. Single-cycle stays as it is: its count
  already sits on the boundary at the interrupt (the transfer is finished in
  the virtual card's state when the interrupt is raised), and its interrupt
  must come once the mix has taken the block's end, or a game that restarts
  from its handler misses sb_patch's window (one period, the write-ahead)
  and the chain gets a gap [read].
- Expected: the count at each auto-init interrupt on the boundary or up to
  about a period past; auto-init interrupts about one period later than
  now; the count nearer what is taken (DMX's margin, F18); DAh ends the
  block the position is in, and when the mix has already taken past that
  block's end, up to one period of the next block plays.
- Plan: 7ed5820d (151 runs: 29 probes, 122 recordings, about 220 min).
  Blocked: F2TEST (no verdict against a run without uCDD yet) and DMACNT's
  verdict (the CT2290's numbers).
- Result (30c82ca, built as the hypothesis says) [86Box]: regression list a
  at 32 frames, r32cp against r32ib: every auto-init case now reads the
  count on the boundary or up to one period past it at each of its first
  eight block interrupts (S0 2-12 units, a period being 16; S5 6-28 of 64;
  L7 7-8 of 8); single-cycle on the boundary as before; everything else as
  irq-batch, including the open interrupt-count shortfall in S5, L2, L3 and
  L5 (86Box at 32-frame rates). Sound check on the SB16 at 32 frames (cp32):
  as irq-batch, eight pass; Jill (F17, on time 0.44: D9 read 0.44, D7 0.42,
  irq-batch 0.01) and Dark Forces (speed 1.05, 84 steps back; irq-batch 78)
  fail as before, so D1 does not touch Dark Forces' fault. Driver 16 bytes
  smaller.
- Not run, and why: of plan 7ed5820d, the family survey's 60 game runs
  (their runner and judge are not rebuilt; REBUILD.md), the sound check on
  the virtual SB Pro and SB 2.0 (no references yet), Kyrandia (parked),
  SBQUEUE, E2TEST, SADUMP and ADPCM (not rebuilt). The commit cites what ran.
- Seen in passing, not D1's: after a DSP reset ends a high-speed transfer
  the bare card's count stops mid-block (L3 0073h, L4 0222h) and the
  virtual card's reads the full count (07FFh, 0FFFh), on irq-batch too; the
  mask case is DMAMASK below.
- Hardware: not yet (the PC runs irq-batch; a kit after the deeper ring or
  with it).
- Evidence state (24 Oct 2026): the emulator claim predates the ledger; re-prove under plan 45bc14ec (list a) and plan cdee6f75 (the sound check, once it has recompiler-off references: DYNAREC) before this reaches fixes.

### F2, the ring: a late period interrupt aliases the output clock (24 Oct 2026)

- Symptom: F2 (on `sound-engine-library`): the polled count stepped back
  in six games. Hexen's trace [trace, 20 Oct]: the count climbs and falls
  back two output periods every fourth read, with no block interrupt
  between, cycling inside a two-period window.
- Cause [read]: output_clock takes the period from [periods] and the
  position within it from the DMA count, and the ring holds two periods. A
  period interrupt more than one period late leaves the card two or more
  periods past [periods]; the half the DMA is in then names the wrong
  period, and the clock reads two periods back. The handler's resync then
  sets [periods] two periods short: the next mix frames lie two periods
  behind, so the game's stream is mixed again from there (heard as a
  repeat), and the count's position (F8, since 30c82ca) is held until the
  mix passes it again.
- Citation: vsb-spec 7.8 (the count never moves back within a lap); the
  physical ring's size is the driver's own choice, about which the
  documents say nothing; the 8237 auto-initialises over any length.
- Family: none: the output clock, under every engine.
- Baseline: count-position 30c82ca at 32 frames (r32cp, cp32).
- Reproducer: none in 86Box. CLIGAP's holds (2 and 4 ms, 400 each) against
  idle steps in one boot: 86Box's own rate moves 5% between two idle steps,
  more than the effect, and a 4 ms hold gives a whole-period late only about
  half the time (runs gapd1a, gapd1b). On the PC, PLKIT B4 (period-late, 32
  frames, the CT2290) lost about 66 periods against the ticks over forty 4 ms
  holds: either this alias or the card stopping unacknowledged (M3). The
  fix stands on reading in 86Box; the next kit repeats B4 on it: the alias
  predicts no periods lost, M3 the same loss as before.
- Hypothesis: a ring of 512 frames (16 periods at 32 frames, 8 at 64, 4 at
  128, 2 at 256 as today); output_clock takes the position modulo the whole
  ring, so a late interrupt is read right up to 15 periods (10.9 ms) at 32
  frames; the handler refills the slot after the one playing. Mixing stays
  one period ahead: no added latency. Two periods a build can keep the old
  form (the same arithmetic at two).
- Paths to check (L2): output_clock's 15 callers (the meaning unchanged:
  an absolute frame); the slot pick at .acknowledged (joined from the SB16,
  SB Pro, WSS and ESS paths); the SB Pro's, SB 2.0's, WSS's and ESS's DMA
  set-up (all already written as the whole ring and one period); the
  install and audio_engage, which mixed two silent periods into a
  two-period ring (the rest of a larger ring now gets them copied on).
- Result (7994cd1) [86Box]: a reproducer turned up after this row was
  written. UCDD -STATUS around CLIGAP holds: idle, the ring counts 75.8 and
  75.4 periods a BIOS tick against the nominal 75.69, where D1 counted 69.3
  and 72.7 (4-8% short and unsteady); 2 and 4 ms holds now each count once
  as a whole-period late (558 and 586 in 400 holds, D1 193 and 303). So in
  86Box the two-period ring lost periods to aliasing unseen, and that, not
  86Box, made uCDD's virtual card about 5% slow there since 22 Oct (the
  bench's note blamed the emulator: corrected, L1). Regression r32rg against
  r32cp: every SBT16 case now within the bare cards' interrupt count, rates
  within about 1.5% of the bare card; the count at the interrupt as D1.
  Sound check rg32: as D1 (Hexen's on-time drops to about 0.6 in some runs
  of both builds: an audiocmp weakness, below).
- Merged away (24 Oct, UPA6): the author's three-period ring replaces this
  one; at 32 frames the alias returns for interrupts over about two periods
  late (UPA6).
- Not fixed by the ring (24 Oct, found reading the author's Beta 0.9.4-a6,
  which mixes the missed periods two periods ahead) [read]: the sound
  during a hold. The handler still mixes one slot ahead, so during a hold
  of a whole period or more the card plays slots not refilled this lap:
  sound from one ring ago (11.6 ms at 32 frames), as the two-period ring
  did. The ring fixed the clock and the count, not this. Covering a hold
  needs sound mixed before it starts (write-ahead, which is latency), and
  mixing the game's stream further ahead takes its samples earlier than a
  card fetches them (F18). Open; it belongs with the period comparison.
- Not run: the physical SB Pro, SB 2.0, WSS and ESS paths (reading only:
  their DMA is set as the whole ring and one period). See PHYSPRO.
- Hardware: the kit repeats PLKIT's B4 (forty 4 ms holds): the alias
  predicts no periods lost against the ticks, M3 (the card stopping
  unacknowledged) the same loss as on period-late.
- Evidence state (24 Oct 2026): the emulator claim predates the ledger; re-prove under plan 45bc14ec (list a) and plan cdee6f75 (the sound check, once it has recompiler-off references: DYNAREC) before this reaches fixes.

### PHYSPRO: uCDD over a physical SB Pro gives no virtual interrupts in 86Box (found 24 Oct 2026, open)

- Symptom [86Box]: with 86Box's Sound Blaster Pro v2 as the physical card
  (IRQ 5, DMA 1) and the virtual SB Pro on IRQ 7, SBT16 through uCDD gets a
  few interrupts and stops (1Ch at 22050 Hz: D7 17 in 777 ms, D9 6, D1 5,
  the ring 1, all at 32 frames), then none in the next three cases; at 128
  and 256 frames none at all (D7 at 128 too, the build the PC ran for days
  on the SB16). Install reports no error.
- Not known: whether it is the bench's set-up (the physical and the
  virtual card both on DMA 1) or the driver's SB Pro output path. The PC
  has the SB16, so no hardware result says either way.
- Rule: every Creative card must work as the physical card (CONTEXT.md hard
  rules). Next: the same with the virtual card on another DMA channel and
  on the SB16 model, then the pro_output path read against the SB Pro's
  documents.

### Seen in passing (24 Oct 2026, not yet rows)

- After a DSP reset ends a high-speed transfer the bare card's count stops
  mid-block (SBT16 L3 0073h, L4 0222h) and the virtual card's reads the
  full count (07FFh, 0FFFh), on irq-batch, D1 and the ring.
- The sound check's on-time for Hexen is bimodal on this bench: 0.99-1.00
  or 0.60-0.61 on D1 and on the ring alike. audiocmp's strong matches
  (r > 0.85) lock onto a repetition of the same sound about 0.43 s away, just
  past its 0.4 s tolerance (bench runs rg32, rg32c, cp32b; the wave pieces
  themselves unchanged). An instrument fault, for the bench.

### DMAMASK: a masked channel does not stall the virtual transfer (found 23 Oct 2026, open)

- Symptom [86Box]: SBT16 C6 00 22050 M masks the 8-bit channel for 100 ms
  after the second block interrupt. On the bare card the transfer stalls
  and the third interrupt comes 137 to 142 ms after the second, on the
  boundary. Through uCDD it comes mid-block and at no fixed time: 111.7 ms
  after the first with the count at 029Ah (irq-batch, r32ib-001), 172.3 ms
  with 05F7h (D9, r32d9-001). The regression's M check asks only whether the
  transfer resumes, so it passed.
- Citation: the 8237 services no request on a masked channel (8237A data
  sheet, the mask register), so the DSP's transfer waits; vsb-spec says
  nothing of a mask during a transfer yet.
- Family: none (the virtual 8237).
- Cause: not found. A guess [read]: the stream's position is worked out
  from the output frame (mix.asm, game_elapsed), and nothing re-bases it at
  the unmask as .resume does after D4h.
- Next: its own change loop after F8; rsum's M case to judge the third
  interrupt's time and count.
- Now CAND-20 (28 Oct 2026, Project A): T2.EXE DMAMASK reproduces it on
  the pinned C2 (plan 3b9b90c9 `fail: 10`; C0 d34e05da `pass: 10`) and on
  a1 (f8c012c0 `fail: 10`): the count runs on while masked and the
  interrupt comes at the unmask. This row's text stays as it was (rule 7).

### DYNAREC: the sound check fails with 86Box's recompiler off (found 24 Oct 2026, open)

- Symptom [86Box]: count-position (7994cd1, build_32_t2), the SB16 sound
  check (plan cdee6f75, 10 games), 3 runs with the recompiler off
  (t3soff1-3) and 3 with it on (t3son1-3), the same binaries. On time:

  | game | off 1, 2, 3 | on 1, 2, 3 | control |
  |---|---|---|---|
  | MKTRIL | 0.31 0.31 0.32 FAIL x3 | 1.00 1.00 1.00 PASS x3 | 1.00 |
  | THEMHOSP | 1.00 1.00 1.00 PASS x3 | 1.00 1.00 1.00 PASS x3 | 1.00 |
  | DESCENT | 0.34 F, 0.62 P, 0.66 P | 0.67 P, 0.51 F, 0.76 P | 0.82 |
  | HEXENBEY | 0.54 0.78 0.73 FAIL x3 | 1.00 1.00 1.00 PASS x3 | 1.00 |
  | DUKE3D | 0.18 0.27 0.23 FAIL x3 (speed 1.18-1.24) | 0.98 0.97 0.97 PASS x3 | 0.99 |
  | XCOMUF | 0.64 F, 0.68 P, 0.67 P | 0.67 0.65 0.83 PASS x3 | 0.85 |
  | GK1 | 0.25 0.20 0.32 FAIL x3 (speed 1.28-1.36) | 0.90 0.90 0.94 PASS x3 | 0.82 |
  | JILLJUNG | 0.04 0.16 0.35 FAIL x3 | 0.14 0.03 0.43 FAIL x3 | 0.98 |
  | SWDFORC | 0.06 0.09 0.21 FAIL x3 (speed 1.08-1.11) | 0.61 0.63 0.65 FAIL x3 (speed 1.05) | 1.00 |
  | SSTRDUST | 0.07 0.05 0.06 FAIL x3 (speed 1.47-1.54) | 1.00 1.00 1.00 PASS x3 | 1.00 |

  Verdicts disagree on 6 games (MKTRIL, HEXENBEY, DUKE3D, GK1, SSTRDUST,
  XCOMUF in one run); SWDFORC fails in both sets with on time apart
  (0.06-0.21 off, 0.61-0.65 on); JILLJUNG fails in both with overlapping
  numbers; DESCENT is mixed in both.
- Measured [86Box]: 86Box's own speed readout in the screenshots at 20, 50
  and 80 s. Recompiler on: 100% in every shot read. Off: GK1 59-79%,
  SSTRDUST 62-73% after its first shot, SWDFORC 75-90%, MKTRIL 87-100%,
  JILLJUNG 83-101%, XCOMUF 90-101%, HEXENBEY 95-102%, THEMHOSP 91-104%,
  DESCENT 100%; DUKE3D not read (its window crops wrong). With the
  recompiler off the interpreter does not hold a Pentium MMX 233 at real
  time on this host in several games, and the recording is in host time.
  This does not account for every row: MKTRIL reads 87-100% and plays at
  0.31.
- Not measured: the control (the bare card, no uCDD) with the recompiler
  off. The stored references and controls (sndref/sb16) predate the rule
  and do not record the recompiler, so the off set compares uCDD with the
  recompiler off against a bare card that was most likely recorded with it
  on. Until a recompiler-off
  control is recorded, the difference is "the recompiler", nothing more
  (tightening r3, T3).
- Measured since (25 Oct 2026, Michael's answer to T3) [86Box]: the old
  references and controls were recorded with the recompiler on (all 20
  runs' 86box.cfg: `cpu_use_dynarec = 1`; kept as comparisons in
  sndref/sb16_dynarec_on). New ones recorded with it off, a reference and
  three controls per game (sndref/sb16; all 40 runs `cpu_use_dynarec =
  0`). The new reference against the old, on time: THEMHOSP 1.00,
  HEXENBEY 1.00, DESCENT 0.80, JILLJUNG 0.71 agree; MKTRIL 0.21 and DUKE3D
  0.59 (speed 0.84, 0.82), XCOMUF 0.44, SWDFORC 0.25 and SSTRDUST 0.11 (the
  moment 18.6 and 19.8 s apart) and GK1 0.00 do not. With the recompiler
  off the bare card plays 6 of the 10 moments differently, so the off set
  above was judged against references of the other mode.
- T3's recordings judged again against the new references (sndreg's rules
  on the mean of three controls; an analysis, not in the ledger): off 15
  PASS, 6 FAIL, 9 WEAK (above: 7 PASS, 23 FAIL); on, now against the other
  mode, 7 PASS, 14 FAIL, 9 WEAK (above: 23 PASS, 7 FAIL). The reference's
  mode decides most of the table. Still failing with the recompiler off:
  MKTRIL 2 of 3 (on time 0.37 and 0.41, speed 0.92 and 0.94; its controls
  0.80-0.94), XCOMUF 2 of 3 (0.57 and 0.59 against a line at 0.68; uCDD's
  runs sit about 4 s early in both modes, the controls at 0), DUKE3D 1
  (0.76 against 0.79), SWDFORC 1 (0.52 at its line; its own third control
  reads 0.44). Open: the next sound check through the runners against
  these references decides.
- WEAK with the recompiler off (the controls' mean on time below 0.6):
  GK1 0.00 (its 14:28 window is a quiet passage in the reference and all
  three controls alike, loudness about 30-340 against about 1000 from 33 s
  on, too quiet for audiocmp to match: the window wants moving for this
  mode), JILLJUNG 0.37 (0.76, 0.05, 0.30), SSTRDUST 0.46 (0.33, 0.60,
  0.44). Nothing is judged against them.
- L4 with the recompiler off: D7 (vcpich build_32) FAILS THEMHOSP (speed
  3.15, on time 0.01) and PASSES MKTRIL in 3 runs of 3 (on time 0.74,
  0.69, 0.73, speed 0.98-1.00), where on 22 Oct with the recompiler on it
  failed MKT at speed 2.38. count-position, with F14 fixed, fails MKTRIL 2
  of 3 in the same mode. MKTRIL does not separate the known-bad from the
  fixed build with the recompiler off; THEMHOSP does. Until that is
  explained, MKTRIL is not a trusted check in this mode (L4); the cause
  (F14 not showing in MKT's moment under the interpreter, or the check
  missing it) is not known.
- List a in the same runs (t3aoff1-3, t3aon1-3): 50 counters, none apart
  beyond the run-to-run spread; one verdict differs, 004 virtual SB 2.0 L2
  (130 interrupts in all six runs) DIFF in off 1 and 2, because the bare
  card read 139 there and 138 elsewhere (rsum's 6% edge; the T2 finding).
- Pictures: runs/sr_cdee6f75-NNN_sb16_GAME_off1..3 and _on1..3 (audiocmp/
  map_wave.png, map_band.png, mix.png; shot_*.png).
- Rule: evidence runs stay recompiler-off whatever this row finds
  (the bench's CLAUDE.md). Consequence: the sound check cannot judge uCDD with
  the recompiler off until the references and controls are re-recorded
  with it off, or the bench runs the guest at real time.
- The bare card's own jitter (Michael, 25 Oct 2026): 86Box's bare SB 2.0
  gives 137 to 139 interrupts in SBT16 L2 from run to run, recompiler on
  or off, so one bare-card run against rsum's 6% decides a verdict by its
  jitter (HSPEED). Controls are taken as the mean of three runs: the sound
  check's references since 25 Oct (sndreg: three controls, judged on their
  mean); list a's bare-card rows by the mean of three runs where three
  exist (HANDOFF, T3).

### HSPEED: the virtual SB 2.0's high-speed single-cycle 91h at E9h gives 6% fewer interrupts (candidate, found 24 Oct 2026, open)

- Symptom [86Box]: SBT16-legacy case L2 (`SBT16 91 00 44100`: 91h, 8-bit
  high-speed single-cycle, time constant E9h), count-position 7994cd1 at 32
  frames, plan 45bc14ec. Virtual SB 2.0 (row 004): 130 interrupts in all
  six T3 runs (off 130 130 130, on 131 131 130). 86Box's bare SB 2.0 (row
  006): off 139 139 138, on 138 138 138; mean of the three off runs 138.7.
  130 is 6.3% short of the mean: FAIL by rsum's 6%, which stays (Michael,
  25 Oct 2026). The virtual SB Pro in the same case: 130 131 131 / 131 130
  130 against the bare Pro's 138 138 138 / 137 138 138 (5.3%, inside the
  tolerance; T2's repeat had it at 130 against 139). The auto-init form at
  the same rate (L3, 90h): virtual 135-136 against 138-139 (about 2%).
- Reference: the CT2290 (sound-engine-library docs/sound-engines/ct2290.md,
  measured 19 Oct 2026 [hw]). Rate: E9h plays at 43383 Hz, 0.2% under
  1000000/(256-E9h) = 43478 Hz, which 86Box's bare card plays exactly; so
  the real card would give about 0.2% fewer interrupts than the bare card
  here, not 6%. Block end: 91h with 64 bytes at E9h reaches the handler in
  1.52 ms on the card and 3.55 ms on the virtual card (D7, 128 frames).
- Already in the notes (findings.md, sound-engine-library): F7 (the virtual
  card plays E9h as 44100, 1.6% fast) and F11 (short transfers end at the
  virtual card's next output period, not within a sample). Neither has a
  row here or a fix.
- Citation: SBG:1345-1351 (high-speed single-cycle: the DSP takes no
  commands during the transfer and leaves high-speed mode at its end) and
  SBG:1714 (the 8-bit mono high-speed single-cycle steps). The documents
  say nothing of how soon the block ends after its last byte: silent; the
  CT2290's measurements decide (mantra rule 1).
- Hypothesis (not tested): each single-cycle block ends at the next 32-frame
  output period (F11) and the restart waits for another, about 1.4 ms lost
  per block, which at L2's block length is the 6%; the auto-init form loses
  only the first.
- Evidence: emulator (plan 45bc14ec, rows 004 and 006; T3 runs t3aoff1-3,
  dynarec off). Hardware: UNCONFIRMED at 32 frames (the 19 Oct numbers are
  D7 at 128 frames). Next: the same case on the CT2290 through the pinned
  build; F11's own row.

### ESSRATE: an untrimmed ESS's output rate is 44194 Hz in the README and 44192 Hz in the code (found 25 Oct 2026, open)

- Found [reading], 25 Oct 2026, while writing Project A's Tier 0
  resampler cases (A1), at the pinned build count-position 7994cd1:
  README.md, ESS AudioDrive paragraph ("other ESS chips run at the rate
  their data sheets give, 44194 Hz"; RELEASE-NOTES, fork section: "every
  ESS ran at 44194 Hz") against src/audio/wss_output.asm, `ESS_RATE equ
  44192`, which sets output_rate, cd_step and cd_step_remainder for the ESS
  path.
- Which is the chip's: not settled here. The ESS data sheets in the library
  (ES1888 and the others under Sound Cards/ESS AudioDrive) give the rate
  formula; they are to be read when the ESS is unparked.
- Effect: the resampler's step is set against 44192; if the chip takes
  44194 samples a second, the disc audio plays 45 ppm fast (0.0045 %, the
  pitch high), far below any audible or 0.5 % pitch threshold. The README
  and the code should still say one number.
- Hypothesis (labelled, not tested): the same clock rounded two ways.
- Not tested: the ESS is parked (Michael, 25 Oct 2026, Project A question
  7: it stays parked); the resampler's pitch is NOT-UNIT-TESTABLE (A1), and
  A3's pitch case (t2x-13) covers the SB Pro and SB 2.0 only.
- Evidence: reading. Hardware: UNCONFIRMED. Under Project A's freeze: a
  row, never a fix.

### CAND-1 Tier 0, T0-CUE-I02: a CUE sheet with INDEX 02 or higher is refused (found 25 Oct 2026; the fork line lacks the upstream fix, B's backlog, 27 Oct; LACKS-FIX, 28 Oct)

Pinned: count-position 7994cd1 (C2 hash UCDD.EXE 03d92066, UCDDHOST.BIN 447ace33; C1 hash UCDD.EXE f8d8ec5e; the bench's fixtures/pinned/MANIFEST.txt). Bin: CANDIDATE_UCDD_CDROM, FAIL 10/10 (Tier 0; the template's 3/3 is the sweep's).
Cell: none (Tier 0: cue.asm's prepare_image included unchanged, no game), scope not applicable until A4's image audit counts the library's sheets with INDEX 02.
Affected: not known (A4). Controls: C0, C1 not applicable (Tier 0 runs the module, not the driver).
Observed: T0.TXT `FAIL I02 +carry got 00000001 want 00000000` (prepare_image returns carry: the sheet is refused) in all ten runs (bdae96f1-161 to -170, folders t0c-161 to t0c-170); plan bdae96f1. Expected: the sheet mounts and index 2 is ignored for positioning (README Images, the specification uCDD implements, as Michael read it, 25 Oct 2026, Project A question 6).
Trace: by reading, src/cue.asm:360-361 at the pinned SHA (`cmp ax, 1` / `ja cue_bad`): any INDEX number above 1 refuses the whole sheet. Minimal reproduction: `T0CUE.COM I02` (matrix T0-CUE-I02; bench dos/src/t0/t0cue.asm).
Hypothesis (labelled, not tested): the fix exists and is the author's: Beta 0.9.4-a1 (his a8b57d4, 19 Oct 2026; RELEASE-NOTES "CUE files with a UTF-8 byte-order mark or with INDEX 02 and higher now mount"), on merge-a6 src/cue.asm:385-390 ("Check and ignore an index after INDEX 01"), built, not run; by the merging rule his version is the one kept. Evidence: emulator (plan bdae96f1), dynarec off. Hardware: UNCONFIRMED.
0.9.5-a1 (Michael, 27 Oct 2026, rules-bot's fold: the reading-grade line replaced by a plan; rule 7, the old line: "0.9.5-a1: none (reading, a1 c5531c8 against a6 8252786: src/cue.asm unchanged; no release note names INDEX 02)."): the author's 0.9.5-a1 built as the bench's option a1 (fork main c5531c8, fixtures/a1/MANIFEST.txt), T0-CUE-I02-A1 (T0CUEA1.COM, the Tier 0 program assembled against a1's src/cue.asm), plan ec2be24b `pass: 10` (T0.TXT `PASS I02` in every run). Label (rule 7: the old, CANDIDATE_UCDD_CDROM against the pinned build): the fork line lacks the upstream fix: the author's 0.9.4-a1 note (RELEASE-NOTES.md:124 at c5531c8, quoted in the Hypothesis); moved to B's backlog. Evidence: emulator (plans bdae96f1, ec2be24b), dynarec off.

### CAND-2 Tier 0, T0-CUE-BOM: a CUE sheet that starts with a UTF-8 byte order mark is refused (found 25 Oct 2026; the fork line lacks the upstream fix, B's backlog, 27 Oct; LACKS-FIX, 28 Oct)

Pinned: count-position 7994cd1 (C2 hash UCDD.EXE 03d92066, UCDDHOST.BIN 447ace33; C1 hash UCDD.EXE f8d8ec5e; the bench's fixtures/pinned/MANIFEST.txt). Bin: CANDIDATE_UCDD_CDROM, FAIL 10/10 (Tier 0; the template's 3/3 is the sweep's).
Cell: none (Tier 0: cue.asm's prepare_image included unchanged, no game), scope not applicable until A4's image audit counts the library's sheets with a byte order mark.
Affected: not known (A4). Controls: C0, C1 not applicable (Tier 0 runs the module, not the driver).
Observed: T0.TXT `FAIL BOM +carry got 00000001 want 00000000` (refused) in all ten runs (bdae96f1-181 to -190, folders t0c-181 to t0c-190); plan bdae96f1; the same sheet without the mark (T0-CUE-M1R) mounts in every run. Expected: the sheet mounts (README Images, as Michael read it, 25 Oct 2026, Project A question 6).
Trace: by reading, src/cue.asm:162-197 at the pinned SHA: the first token of each line is matched against the keywords; with EF BB BF before FILE it matches none and the parser takes `jmp cue_bad` (line 197). Minimal reproduction: `T0CUE.COM BOM` (matrix T0-CUE-BOM).
Hypothesis (labelled, not tested): the fix exists and is the author's: Beta 0.9.4-a1 (his a8b57d4, 19 Oct 2026), on merge-a6 src/cue.asm:79-85 (the far form, the driver's mount helper, helper.asm) and 103-109 (the near form, UCDDPLAY), skipping the three bytes before the first line; built, not run; by the merging rule his version is kept. Evidence: emulator (plan bdae96f1), dynarec off. Hardware: UNCONFIRMED.
0.9.5-a1 (Michael, 27 Oct 2026, rules-bot's fold: the reading-grade line replaced by a plan; rule 7, the old line: "0.9.5-a1: none (reading, a1 c5531c8 against a6 8252786: src/cue.asm unchanged; no release note names a byte order mark)."): the author's 0.9.5-a1 built as the bench's option a1 (fork main c5531c8, fixtures/a1/MANIFEST.txt), T0-CUE-BOM-A1 (T0CUEA1.COM), plan 1d11fa3d `pass: 10` (T0.TXT `PASS BOM` in every run). Label (rule 7: the old, CANDIDATE_UCDD_CDROM against the pinned build): the fork line lacks the upstream fix: the author's 0.9.4-a1 note (RELEASE-NOTES.md:124 at c5531c8, "CUE files with a UTF-8 byte-order mark or with INDEX 02 and higher now mount"); moved to B's backlog. Evidence: emulator (plans bdae96f1, 1d11fa3d), dynarec off.

### CAND-3 Tier 0, T0-ADPCM-3: the virtual Sound Blaster's 2.6-bit ADPCM decodes differently from DOSBox-X (found 25 Oct 2026, open; a1 NOT-UNIT-TESTABLE, its line reading-grade, 28 Oct)

Pinned: count-position 7994cd1 (C2 hash UCDD.EXE 03d92066, UCDDHOST.BIN 447ace33; C1 hash UCDD.EXE f8d8ec5e; the bench's fixtures/pinned/MANIFEST.txt). Bin: CANDIDATE_UCDD_SFX, FAIL 10/10 (Tier 0; the template's 3/3 is the sweep's).
Cell: none (Tier 0: audio/sb_adpcm.asm included unchanged, no game), scope not applicable; which games use 2.6-bit ADPCM is A4's engine census to say.
Affected: not known (A4). Controls: C0, C1 not applicable (Tier 0 runs the module, not the driver).
Observed: T0.TXT `FAIL 3 code 3 (byte 1) got 144 want 148; 1475 of 1920 differ` in all ten runs (bdae96f1-281 to -290, folders t0c-281 to t0c-290); plan bdae96f1. The 4-bit and 2-bit cases match DOSBox-X in every code (1280 and 2560; T0-ADPCM-4 and -2 pass). Checked outside the emulator: a Python transcription of both decoders over the same block gives the same counts and the same first difference (bench dos/src/t0/adpcm_model.py). Expected: DOSBox-X's decoder (EMUSRC: src/hardware/sblaster.cpp at f6b476e9, decode_ADPCM_3_sample and the DSP_DMA_3 split), A1's reference, graded emulator (Michael, 25 Oct 2026, question 6).
Trace: by reading, two differences. (1) The third code of a byte: DOSBox-X takes `(b & 3) << 1`, the sign from bit 1 and a magnitude of 0 or 2; sb_adpcm.asm (.two_six with the count at 1) takes the sign from bit 1 and a magnitude of 0 or 1 (`and al, 1`). (2) The largest step: DOSBox-X's fifth row moves 5, 15, 25, 35 (a step of 10); sb_adpcm.asm doubles the step up to 16 (8, 24, 40, 56). The first difference is (1): byte 1 (6Dh) from the reference 128 gives 131 and 138 in both, then 148 in DOSBox-X (magnitude 2 at step 4) and 144 in uCDD (magnitude 1). Minimal reproduction: `T0ADPCM.COM 3` (matrix T0-ADPCM-3; bench dos/src/t0/t0adpcm.asm).
Hypothesis (labelled, not tested): sb_adpcm.asm follows the CT1741 4.05 firmware's 2.6-bit decoder as read from S95Sedan's disassembly (its header); DOSBox-X's tables are an emulator's reconstruction. The fork's own order (vsb-spec.md 0: Creative's documents, then the firmware, then the emulators) ranks the firmware above DOSBox-X; A1 takes DOSBox-X because it forbids the firmware as the reference. Which the card does is the CT2290's to say: AKIT plays one 2.6-bit block (Michael, 25 Oct 2026). Also by reading: the author's decoder, which replaced sb_adpcm.asm on merge-a6 (UPA6, the trap.asm ADPCM line; built, not run), takes three bits a code and the fifth row 5, 15, 25, 35 (merge-a6 src/audio/mix.asm adpcm_decode; trap.asm adpcm_params, adpcm_map3): DOSBox-X's decoding. T0ADPCM cannot run there (it includes sb_adpcm.asm, which merge-a6 no longer has); the card decides between the two decoders. Evidence: emulator (plan bdae96f1), dynarec off; the decoder comparison, reading. Hardware: UNCONFIRMED.
0.9.5-a1: none (reading, a1 c5531c8 against a6 8252786: no hunk touches ADPCM; his decoder, src/audio/mix.asm adpcm_decode at a1 988 with sb_adpcm_sample at 958, lies past a1's last mix.asm hunk, 670-679; the fork's sb_adpcm.asm is not in his tree). No a1 plan (27 Oct 2026): T0ADPCM assembles the fork's src/audio/sb_adpcm.asm, which a1 does not have (its decoder is inside its mixer, mix.asm adpcm_decode); a Tier 0 case on a1 needs a new harness, so this line stays reading-grade until Michael decides (STATE, Project A question 28).
a1, NOT-UNIT-TESTABLE (Michael, 28 Oct 2026, question 28: ADPCM4 plain and mixed on a1 first; if the oracle does not see the symptom, one attempt to %include a1's mixer unmodified; a needed patch makes it NOT-UNIT-TESTABLE for a1 and this line stays reading-grade with the reason; no special harness). (1) T2X-ADPCM4-A1, plan e93f4049 `fail: 10`, and T2X-ADPCM4-M-A1, plan 09fa8a69 `fail: 10`: T2.TXT PASS in all twenty (one interrupt, 25 ticks after 75h), no gap, quiet after the block; the 4-bit tone at 1999.9 Hz (by hand, pitchcal's peak, 09fa8a69-001, -005, -010 and e93f4049-001; tonecheck: SNR 89 to 91 dB plain) against the pin's 1977.1 Hz: a1 plays A5h at the formula's 10989 Hz, not through the DSP 4.13's table (VSB:292-304), B's list item of 27 Oct, not this row. The oracle does not see CAND-3's symptom: a 4-bit block cannot show the 2.6-bit decoder (predicted in the rows before the run, method 397d3e5). (2) The one attempt: a1's src/audio/mix.asm %included unmodified (nasm 2.16.03, a1's src on the include path, a frame calling adpcm_decode): 17 symbols undefined, from the driver's other modules and the build (game_offset, game_segment, game_active, game_step, mix_period, cd_position, PERIOD_FRAMES, OUTPUT_SHIFT and nine more), and the decoder's state and tables (adpcm_bits, adpcm_map, adpcm_params, adpcm_map3) are in src/audio/trap.asm (2306-2329), set by its 74h-7Fh path (2030-2032), not in the mixer. A unit test needs that state split from trap.asm (a patch) or stubs for the rest of the driver (a special harness): NOT-UNIT-TESTABLE for a1. This line stays reading-grade: by reading, a1's 2.6-bit table's fifth row is 5, 15, 25, 35 (trap.asm:2329), DOSBox-X's, not the pin's doubled step. Evidence: emulator (plans e93f4049, 09fa8a69: a1's 4-bit decoder and its rate); the 2.6-bit decoding, reading.

### CAND-4 Tier 1, T1-EJECT and T1-C1-EJECT: after Eject Disk the device status never says the door is open (found 25 Oct 2026, open; upstream candidate: fails on a1 too, 27 Oct; pin and a1 sections, 28 Oct)

Pinned: count-position 7994cd1 (C2 hash UCDD.EXE 03d92066, UCDDHOST.BIN 447ace33; C1 hash UCDD.EXE f8d8ec5e; the bench's fixtures/pinned/MANIFEST.txt). Bin: CANDIDATE_UCDD_CDROM, FAIL 10/10 under C2 and 10/10 under C1 (Tier 1; the template's 3/3 is the sweep's).
Cell: none (Tier 1: T1.EXE through INT 2Fh on a synthetic disc, no game), scope not applicable; which games watch the door bit is not known.
Affected: not known. Controls: C0 no reference: OAKCDROM with MSCDEX 2.25 on 86Box's own ATAPI drive answers device status 0796h throughout, its lock and door bits never moving (development run t1dev-c0, not recorded; HANDOFF 25 Oct), so 86Box's drive cannot show what a period driver reports for a real tray. C1: the same failure (T1-C1-EJECT).
Structure (Michael, 28 Oct 2026, question 28): one row, two observed sections, pin and a1, under one expectation and citation; the upstream report is written from the a1 section; a Hypothesis per build where the mechanism differs. The a1 section is the row's former 0.9.5-a1 line, its text unchanged.
Observed, pin: T1.TXT `FAIL EJECT device status after Lock 0710, after Unlock 0712, after Eject 0C02; then a read 8102)` in all ten C2 runs (ccb39d17-141 to -150, folders t1a-141 to t1a-150) and `FAIL EJECT device status after Lock 0400, after Unlock 0402, after Eject 0C02; then a read 8102)` in all ten C1 runs (ccb39d17-351 to -360, folders t1a-351 to t1a-360); plan ccb39d17. Lock and unlock answer as asked (bit 1); after the eject bit 11 (RBIL: no disk in drive) is set and bit 0 (door open) is not; the read after it fails with 8102h (not ready), as it should. C1's word lacks 0310h because the CD-only build has no audio (driver.asm:321-323). Expected: bit 0 set from the eject until a disc is put in: MSCDEX:820-823 ("The door will report as being open until the user has inserted a disk into the drive unit and closed the door. The status bit for door open can be monitored to determine when a disk has been reinserted."), MSCDEX:557-558 (bit 0, door open); RBIL: INTERRUP.G:677-690 (table 01450, bit 0 door open, bit 11 no disk in drive).
Trace: by reading, at the pinned SHA: src/driver.asm:305-323 (IOCTL input 6) builds the word from 0400h (M-5), the lock flag (bit 1), an empty unit (bit 11), raw reading (bit 2) and audio (0310h); bit 0 is set nowhere and the unit keeps no door state. src/driver.asm:420-438 (IOCTL output 0) calls eject_unit (1370-1396), which closes the image and clears the unit. Also by reading, not tested by this row: an Eject while the door is locked is refused (420-421, request_error), where MSCDEX:820 has the driver unlock the drive and eject. merge-a6's device status has the same shape (src/driver.asm:332-350, no bit 0): no fix exists on another branch. Minimal reproduction: `T1.EXE EJECT` on T1A (matrix T1-EJECT; T1-C1-EJECT under C1).
Hypothesis, pin (labelled, not tested): a door-open flag set by an eject and cleared at the next mount, reported as bit 0, would answer the document. What a period driver reports for a real tray is the hardware's to say; 86Box's drive cannot. Evidence: emulator (plan ccb39d17), dynarec off. Hardware: UNCONFIRMED.
Observed, a1 (Michael, 27 Oct 2026, rules-bot's fold: the reading-grade line replaced by a plan; rule 7, the old line: "0.9.5-a1: none (reading, a1 c5531c8 against a6 8252786: its one device-status change, src/driver.asm:324 `mov eax, 400h`, sets bit 10, XA, RELEASE-NOTES.md:7; bit 0, the door, stays unset)."): the author's 0.9.5-a1 built as the bench's option a1 (fork main c5531c8, fixtures/a1/MANIFEST.txt), T1-EJECT-A1, plan 61d9fe95 `fail: 10`, a different failure: T1.TXT `FAIL EJECT request 0C status 810C` in all ten (folders t1ejecta1x-001 to -010): an IOCTL output request answered with an error, general failure (0Ch), before any device status. By reading (a1 src/driver.asm:395-423): Lock and Unlock take `.lock` and answer done; Eject is refused with `request_error` while the unit is locked or while its CD audio entry is attached (`cmp dword [si+AUDIO_ENTRY], 0` / `jne request_error`, 411-412), and the bench's C2 is the resident-audio build, whose entry is attached. So on a1 the eject itself is refused, where the pinned build takes it and leaves bit 0 (door open) clear. Label (rule 7: the old, CANDIDATE_UCDD_CDROM against the pinned build): upstream candidate (MSCDEX:808-896: Eject Disk is a request the driver carries out). Evidence: emulator (plans ccb39d17, 61d9fe95), dynarec off; the refusal's cause by reading. T1.EXE's waits still spin (Michael, 27 Oct 2026: converted to HLT before its next run); these a1 runs used it as it stood, as the pin's plan did, so the comparison holds and the conversion is still due.
Hypothesis, a1 (labelled, not tested; by reading): the mechanism differs from the pin's. a1's IOCTL output (src/driver.asm:395-423 at c5531c8) refuses Eject with `request_error` while the unit is locked or its CD audio entry is attached (411-412), and the resident-audio build attaches it, so the eject never happens; MSCDEX:820 has the driver unlock and eject. Its device status (driver.asm:324) still sets no bit 0, so once the eject is taken the pin's failure would follow (not run: a1 never gets that far). The upstream report: both, the refusal first.
Run again on the Logo=0 bench (Michael, 26 Oct 2026; the notes' IOSYS08): T1-EJECT and T1-C1-EJECT, ccb39d17-141 to -150 and -351 to -360, 11:47Z, `fail` 10/10 each with the same lines (`device status after Lock 0400, after Unlock 0402, after Eject 0C02; then a read 8102`; C1: 0710, 0712, 0C02) (corrected 28 Oct 2026, rule 7: the old text above has C2 and C1 swapped; the ledger's notes, ccb39d17-141 (C2) `after Lock 0710, after Unlock 0712` and ccb39d17-351 (C1) `after Lock 0400, after Unlock 0402`, agree with Observed, pin): the logo hook's IRQ 0 holds were not its cause; the row stands.

### CAND-5 Tier 1, T1-AONLY and T1-MDM: a CUE sheet with only audio tracks is refused at the mount, alone or in an MDM list (found 25 Oct 2026; the fork line lacks the upstream fix, B's backlog, 27 Oct; LACKS-FIX, 28 Oct)

Pinned: count-position 7994cd1 (C2 hash UCDD.EXE 03d92066, UCDDHOST.BIN 447ace33; C1 hash UCDD.EXE f8d8ec5e; the bench's fixtures/pinned/MANIFEST.txt). Bin: CANDIDATE_UCDD_CDROM, FAIL 10/10 in both cases (Tier 1; the template's 3/3 is the sweep's).
Cell: none (Tier 1, no game), scope not applicable; how many of the library's sheets have no data track is A4's image audit to count (the author names Edna and Defender of the Crown, below).
Affected: not known (A4). Controls: C0 not run on T1C. C1: not in the data-path subset.
Observed: T1-AONLY: M.TXT `The image cannot be opened or is not valid.` and T1.TXT `FAIL AONLY no disc: status 8102` in all ten runs (ccb39d17-471 to -480, folders of the same names; plan 0cf7cb43's first captures are now runs/0cf7cb43-NNN.first), so no beep and no capture to judge. T1-MDM: M.TXT `The disc list cannot be mounted. Check its images and XMS memory.` (one message of two lines, helper.asm:783-784) and `FAIL MDM no disc: status 8102` in all ten (ccb39d17-161 to -170, folders t1a-161 to t1a-170); plan ccb39d17. Tier 0's T0-CUE-AONLY passes (cue.asm's prepare_image accepts the same kind of sheet; plan bdae96f1), so the refusal is the driver's mount. A list of T1D and T1A mounts and switches with Ctrl+Alt+2 on the same build (development run t1dev-mdmkeys, not recorded: `PASS MDM (disc 1 T1D; Ctrl+Alt+2: media changed FF, volume T1A)`); T1E.MDM differs from that list by T1C alone. Expected: the disc mounts as a drive holding an audio CD would: Audio Disk Info gives tracks 1 to 3 (MSCDEX:651-660) and PLAY AUDIO plays track 1 (MSCDEX:1030); T1C's case as Project A sets it (gate A2, T1C "audio only, three tracks").
Trace: by reading, at the pinned SHA: src/driver.asm:1155-1158 (mount_image): track 1's control byte, bit 5 masked, must be 40h (a data track), else .reject; after it, 1222-1249 read sector 16 for an ISO 9660 primary volume descriptor ('CD001') and reject without one. An audio first track fails the first test. Minimal reproduction: `UCDD -mount T1C.CUE` (matrix T1-AONLY); `UCDD -mount T1E.MDM` (T1-MDM).
Hypothesis (labelled, not tested): the fix exists and is the author's: Beta 0.9.4-a3 (his beea8ab, 20 Oct 2026, the code; fedc465, 21 Oct, the release note "Mount CUE sheets that have only audio tracks. This fixes Edna and Defender of the Crown."), on merge-a6 src/driver.asm:1270-1285 (mount_image takes an audio first track on a 2352-byte image, candidate_audio: "An audio CD has no data track. Data reads fail as on a drive."); built, not run; by the merging rule his version is kept. Whether an MDM list holding an audio-only disc then mounts is not read. Evidence: emulator (plan ccb39d17), dynarec off; the MDM attribution, a development run. Hardware: UNCONFIRMED.
0.9.5-a1 (Michael, 27 Oct 2026, rules-bot's fold: the reading-grade line replaced by a plan; rule 7, the old line: "0.9.5-a1: none (reading, a1 c5531c8 against a6 8252786: src/cue.asm unchanged; his fix is 0.9.4-a3, in the Hypothesis)."): the author's 0.9.5-a1 built as the bench's option a1 (fork main c5531c8, fixtures/a1/MANIFEST.txt), T1-AONLY-A1, plan 2e7057dc `pass: 10` (track 1 played, 1000.0 Hz in 4 of 4 windows, no gap of 20 ms), and T1-MDM-A1, plan 5b4ca263 `pass: 10` (disc 1 T1D; Ctrl+Alt+2: media changed, volume T1A): the MDM list holding an audio-only disc mounts on a1, which answers the Hypothesis's open point. Label (rule 7: the old, CANDIDATE_UCDD_CDROM against the pinned build): the fork line lacks the upstream fix: the author's 0.9.4-a3 note (RELEASE-NOTES.md:87 at c5531c8, quoted in the Hypothesis); moved to B's backlog. Evidence: emulator (plans ccb39d17, 2e7057dc, 5b4ca263), dynarec off. T1.EXE's waits still spin (Michael, 27 Oct 2026: converted to HLT before its next run); these a1 runs used it as it stood, as the pin's plan did, so the comparison holds and the conversion is still due.
Run again on the Logo=0 bench (Michael, 26 Oct 2026; the notes' IOSYS08): T1-AONLY (ccb39d17-471 to -480 and 0cf7cb43-081 to -090) and T1-MDM (ccb39d17-161 to -170), `fail` 10/10 each, `no disc: status 8102`: not the logo hook's; the row stands.

### CAND-6 Tier 1, T1-LOAD: CD audio drops out for up to a third of a second while data is read during play (found 25 Oct 2026; FORK-REGRESSION, B's backlog, 28 Oct (rule 7: was "the fork line lacks the upstream fix, B's backlog, 27 Oct"; no note of the author's names it, so a1 is read as never having had it; bisected over the fork's own commits when B unfreezes))

Pinned: count-position 7994cd1 (C2 hash UCDD.EXE 03d92066, UCDDHOST.BIN 447ace33; the bench's fixtures/pinned/MANIFEST.txt). Bin: CANDIDATE_UCDD_AUDIO. Rate: 5 of 10 in the ledger (plan 0cf7cb43 run again on tonecheck's gap check, 25 Oct 2026: T1-LOAD FAIL with every run recorded, Michael's answer to STATE question 9); 16 of 20 before (plan ccb39d17 and 0cf7cb43's first captures, counted with development scripts while the ledger said pass: the directive's tone measure, 90 % of 1 s windows, cannot see a gap shorter than a window); 21 of 30 in all. Timing-dependent, not deterministic.
Cell: none (Tier 1, no game), scope not applicable; every game that reads its disc while its CD music plays is exposed (A4's census can say which).
Affected: not known. Controls: C0 (T1-C0-LOAD, Michael's three runs before this row is binned; plan 0c71550f, dynarec off) refuses the load: OAKCDROM and MSCDEX 2.25 on 86Box's own ATAPI drive, disc T1B, answer the first Read Long during play with 830Ch (error, busy, done, 0Ch general failure), 3 of 3 (`FAIL LOAD request at sector 24 status 830C`), as MSCDEX:319-322 says a driver should; T1.EXE then stops the play, so C0 never plays while reading and cannot say whether 86Box itself would drop the audio under those reads. C0 does not fail the same way, so by the decision procedure the bin stays CANDIDATE_UCDD_AUDIO, not the emulator's. C1 not applicable (no audio).
Observed: in the ledger (0cf7cb43-071 to -080, judged 25 Oct 21:30Z), tonecheck's gap check fails 072 (30, 35 and 21 ms at +1.08, +1.40 and +1.53 s after PLAY), 074 (26 ms, +1.08 s), 075 (87 and 162 ms, +0.69 and +1.38 s), 076 (79 and 240 ms, +0.91 and +1.09 s) and 078 (211 ms, +1.27 s), every edge "ringing (the guest)", the closing beep -0.000 s and the tone 9/9 windows in all ten; 071, 073, 077, 079 and 080 have no gap. Before it, in T1-LOAD's captures (ccb39d17-461 to -470, and 0cf7cb43-071 to -080's first captures, now folders runs/0cf7cb43-071.first to -080.first), runs of exact digital zero inside the play: 1 to 3 per run, 21 to 332 ms each, 21 to 642 ms in a run (0cf7cb43-073: 309, 118 and 215 ms), in 16 of the 20 runs, all between 1.06 and 2.01 s after the opening beep (the play starts 0.49 s after it), none later in the 10 s play. They are the guest's, not the recorder's: the closing beep (tonecheck's capture check) lands within 10 ms of where the ticks put it in every 0cf7cb43 run with gaps; each gap's edges show the resampler's decaying ringing before it and its pre-ringing into the tone after it (0cf7cb43-073 at 13.809 s: `-43 34 -25 17 -10 4 -1 0 0 -1 1 -1`, then `... 0 0 4 -9 16 -24 33 -43`), where the recorder's breaks fall to zero on a straight ramp (ccb39d17-410, 0cf7cb43-001 and -018; the bench's CLAUDE.md, known emulator differences). T1.EXE's line passes in all 20 (CHECK.TXT read 4 times in 1-sector requests during play, CRC32 A3A46D5C each). The same build, disc and track without reads (T1-PLAY2, 21 captures) has no gap with the guest's edges; its two gaps are the recorder's (0cf7cb43-001, 459 ms, and -010, 19 ms, each on a straight ramp, the closing beep +0.020 s). Expected: the play continues: MSCDEX:1040-1042 (a play runs "until the requested sectors have been exhausted or until play is interrupted with a AUDIO STOP request"). The reads themselves, by the document, are refused: MSCDEX:319-322, "Device drivers should fail all requests to the physical device that require head movement when the device is playing and return the request with this bit and the error bit set and an error code", which C0 does. uCDD serves them instead (HOSTCD M-7, "Reads during play succeed with busy set ... friendlier than busy+error", citing MSC:322-325, the sentence about requests that would not interrupt play), and its play drops out while it does: by either reading the play must not stop. Corrected 25 Oct: this field first quoted 322-324 alone for the reads (lesson L30); the disagreement is written beside M-7 (host-cdrom-spec.md) and is Michael's (STATE question 10).
Trace: none taken (the freeze). By reading the notes only: a play starts with a short queue (HOSTCD M-11: the request reads 16 KB, up to 64 KB while it plays, about 0.37 s; the background refill does the rest), and the CD refill runs inside DOS (ISSUES.md, the INT 1Ch row near line 264). Minimal reproduction: `T1.EXE LOAD` on T1A (matrix T1-LOAD); tonecheck's gap check (bench 3c20bb8, thresholds.toml [gaps]) names each gap, its size and its edge in the ledger note. The 16 of 20 before it were counted with development scripts on sound.wav.
Run again clean (26 Oct 2026 08:07Z, the same plan 0cf7cb43, runs 071 to 080, superseding the 25 Oct entries, which are kept): the first runs had a stray DOSBox-X of this session's beside them (the top folder's context/docs/ledger_annotations.md); with nothing else on the box LOAD gives pass 2, fail 8, every failure a gap of the guest's shape (ringing, 22 to 463 ms, e.g. `+0.70 s 463 ms ringing (the guest)`), no HARNESS_ERROR. The stray process was not the cause; the case stays not deterministic (5/10 then, 2/10 now).
Hypothesis (labelled, not tested): following MSCDEX:319-322 as C0 does (fail a read during play, busy and error set) would take away the reads that starve the play; that is M-7's change, Michael's to decide. The mechanism: the foreground's 1-sector reads go through the driver into DOS one after another, and the refill, which needs DOS, gets in too seldom while the queue is still at its starting depth; it drains, and once the refill has filled the queue the reads no longer starve it (no gap after 2 s). 86Box's disk timing is not the PC's (L18): whether and how long the PC drops out is AKIT's to say, with a read during play by ear. Evidence: emulator, dynarec off: the ledger, plan 0cf7cb43 run again (5 of 10 FAIL by tonecheck's gap check); development scripts on plan ccb39d17 and 0cf7cb43's first captures (16 of 20). Hardware: UNCONFIRMED.
0.9.5-a1 (Michael, 27 Oct 2026, rules-bot's fold: the reading-grade line replaced by a plan; rule 7, the old line: "0.9.5-a1: none claimed (reading, a1 c5531c8 against a6 8252786: the nearest, RELEASE-NOTES.md:12, 'Fill the CD-Audio queue from the audio interrupt only when the timer stops or the queue is almost empty', src/audio/background.asm cd_timer_refill at a1 9-135, changes when the queue is refilled, not the reads during play; whether it moves this row is the harness's to say)."): the author's 0.9.5-a1 built as the bench's option a1 (fork main c5531c8, fixtures/a1/MANIFEST.txt), T1-LOAD-A1, plan 38dea235 `pass: 10` (CHECK.TXT read 4 times in 1-sector requests during play, CRC32 A3A46D5C each; the 1000 Hz in 9 of 9 windows, no gap of 20 ms or more). Label (rule 7: the old, CANDIDATE_UCDD_AUDIO against the pinned build): the fork line lacks the upstream fix. No note of the author's names reads during play; the changes between the pinned 0.9.3b and a1 that touch the CD queue or its reads are 0.9.4-a1 "Start CD-Audio tracks faster" (RELEASE-NOTES.md:119 at c5531c8), 0.9.4-a5's six-sector reads from raw images (RELEASE-NOTES.md:60 at c5531c8) and 0.9.5-a1's refill rule (RELEASE-NOTES.md:12 at c5531c8); which one moves this row is not read. Moved to B's backlog; the Hypothesis's M-7 question stays Michael's. Evidence: emulator (plans 0cf7cb43, 38dea235), dynarec off. T1.EXE's waits still spin (Michael, 27 Oct 2026: converted to HLT before its next run); these a1 runs used it as it stood, as the pin's plan did, so the comparison holds and the conversion is still due.
Run again on the Logo=0 bench (Michael, 26 Oct 2026; the notes' IOSYS08): 0cf7cb43-071 to -080, 26 Oct 12:08Z, pass 1, fail 9, every failure a gap of the guest's shape (ringing), 33 to 136 ms, at +0.64 to +1.39 s after PLAY (four runs the same 45 ms at +1.39 s), no HARNESS_ERROR. The IO.SYS logo hook was not its cause; the row stands, not deterministic (5/10, 2/10, 1/10 passing over three sets). The gaps are shorter than the Logo=1 set's (22 to 463 ms): noted, not judged.

### CAND-7 Tier 2, T2X-PICWORD: a 16-bit OUT to port 20h is dropped whole under the driver's trap, so the mask byte it carries for 21h never lands (found 26 Oct 2026; the fork line lacks the upstream fix, B's backlog, 27 Oct; LACKS-FIX, 28 Oct)

Pinned: count-position 7994cd1 (C2 hash UCDD.EXE 03d92066, UCDDHOST.BIN 447ace33; the bench's fixtures/pinned/MANIFEST.txt). Bin: CANDIDATE_UCDD_SFX (the virtual card's interrupt path), FAIL 10/10 under C2, one identical line (Tier 2; the template's 3/3 is the sweep's).
Cell: none (Tier 2: T2.EXE, real mode, no game), scope not applicable; which games write the 8259 with a 16-bit OUT is not known (A4's census can grep for it).
Affected: not known. Controls: C0 PASS 10/10 (T2C0-PICWORD, plan c04ab538: 86Box's own 8259 takes the word OUT as two bytes and the interrupt comes); C1 not applicable (no virtual card, no trap).
Observed: T2.TXT `FAIL PICWORD a word OUT to 20h: 21h reads B8h (B8h written); F2h while masked: 0 interrupt(s), IRR 20h; unmasked by a word OUT: 21h reads B8h (98h written), then 0 interrupt(s)` in all ten C2 runs (plan 350f51fb, runs 071 to 080, folders t2c2-071 to t2c2-080). The first word OUT (OCW3 0Ah, then B8h for 21h), before the card raised its line, took effect; the second (OCW3 0Bh, then 98h), with F2h's request waiting, did not: 21h still reads B8h and the card's interrupt never comes. The same steps as two byte OUTs pass under C2 (development run t2dev-c2w, a scratch build T2BYTE.EXE, not recorded). Expected: a 16-bit OUT writes its low byte to the port and its high byte to the port above: "any two consecutive 8-bit ports can be treated as a 16-bit port" (I386:8218-8219); at 20h that is an OCW3 (or OCW2) and an OCW1, the mask (8259:565-587). The C0 behaviour.
Stall or guest (Michael, 26 Oct 2026: a Tier 2 FAIL on exact digital zero is judged by hand before it is a candidate; thresholds.toml [stall], STALLCAL; measured 27 Oct 2026 on every capture of the plan): not applicable: no capture; the verdict is T2.EXE's own reading of the 8259.
Trace: by reading, at the pinned SHA: src/audio/trap.asm:321 sends every access wider than a byte (`test cl, 18h`) to `.wide` (428-440), which takes only a word OUT to the card's base+4 (the mixer index and data); every other wide access goes to `.unsupported` (444-451), which sets [fault] and drops it, both bytes. The PIC branch (383-386, `virtual_pic_write`) is reached only by byte writes. That the first word OUT landed suggests 20h and 21h are trapped only while the virtual line is in use; when the trap is set was not traced. The same drop on the Sound Blaster's own ports is HOSTCD Q-1 (open, "rare"); this row is that mechanism on the 8259's ports. Minimal reproduction: `T2.EXE PICWORD` under C2 (matrix T2X-PICWORD).
Hypothesis (labelled, not tested): `.wide` splitting a word OUT to 20h or 21h (and A0h, A1h) into two byte writes through `virtual_pic_write`, low byte first, as the CPU does (I386:8218-8221), would answer the document; Q-1's other ports the same way. Evidence: emulator (plans c04ab538 and 350f51fb), dynarec off. Hardware: UNCONFIRMED.
0.9.5-a1 (Michael, 27 Oct 2026, rules-bot's fold: the reading-grade line replaced by a plan; rule 7, the old line: "0.9.5-a1: none (reading, a1 c5531c8 against a6 8252786: no hunk in src/audio/trap.asm touches its wide accesses)."): the author's 0.9.5-a1 built as the bench's option a1 (fork main c5531c8, fixtures/a1/MANIFEST.txt), T2X-PICWORD-A1, plan 899ba757 `pass: 10` (21h reads B8h, then 98h, as written; the masked F2h's interrupt comes once unmasked). Label (rule 7: the old, CANDIDATE_UCDD_SFX against the pinned C2): the fork line lacks the upstream fix: the author's 0.9.4-a3 note (RELEASE-NOTES.md:81 at c5531c8): "Trap the DMA master clear and mask-all ports, and split word writes to the PIC and wide Sound Blaster port access into bytes." The old line read a1 against a6 only; the fix is a3's. Moved to B's backlog. Evidence: emulator (plans c04ab538, 350f51fb, 899ba757), dynarec off.
Also T2X-PICWORD-M (28 Oct 2026; plan 362fdb0b `fail: 10`, T2.TXT the same line as T2X-PICWORD's in every run, `unmasked by a word OUT: 21h reads B8h (98h written), then 0 interrupt(s)`): with T1A's track 2 playing around the case (T2.EXE's PIC MIX: TICK MIX, PIC, AFT, OFF) the same drop; the CD's 1 kHz on through it without a gap (tonecheck PASS in all ten). C0 PASS 10/10 (T2C0-PICWORD-M, plan b087dfd8). The plant for the shared MIX checks is T2L4-PICSEOI-M (da2961a4 `fail: 1`, the CD at 440 Hz).

### CAND-8 Tier 2, T2X-PICROT: OCW2 Set Priority is dropped and the rotating EOI loses its rotation, so the card's interrupt never comes before a waiting timer tick (found 26 Oct 2026, open; upstream candidate: fails on a1 too, 27 Oct; pin and a1 sections, 28 Oct)

Pinned: count-position 7994cd1 (C2 hash UCDD.EXE 03d92066, UCDDHOST.BIN 447ace33; the bench's fixtures/pinned/MANIFEST.txt). Bin: CANDIDATE_UCDD_SFX (the virtual card's interrupt path), FAIL 10/10 under C2, one identical line (Tier 2; the template's 3/3 is the sweep's).
Cell: none (Tier 2: T2.EXE, real mode, no game), scope not applicable; which games set the 8259's priorities is not known (A4's census can grep for OCW2 C0h-C7h and A0h, E0h-E7h).
Affected: not known. Controls: C0 PASS 10/10 (T2C0-PICROT, plan 708fb84f: 86Box's own 8259 gives the timer, then the card, then the timer); C1 not applicable (no virtual card).
Structure (Michael, 28 Oct 2026, question 28): one row, two observed sections, pin and a1, under one expectation and citation; the upstream report is written from the a1 section; a Hypothesis per build where the mechanism differs. The a1 section is the row's former 0.9.5-a1 line, its text unchanged.
Observed, pin: T2.TXT `FAIL PICROT both requests waiting: first the timer (the BIOS's order, IR0 highest: the timer); after OCW2 Set Priority with the card's line highest, the timer (the card); after its rotating EOI A0h, the timer (the timer: the card's line now lowest)` in all ten C2 runs (plan fd562273, folders t2c2r-001 to -010): with both requests waiting and interrupts then on, the timer is served first whatever the priority. Expected: "if IR5 is programmed as the bottom priority device, then IR6 will have the highest one" (8259:686-687; Set Priority, OCW2 R=1 SL=1, 689-691): with C4h written the card's IR5 is highest and comes first; after its EOI A0h (rotate on non-specific EOI, 673-677) it is the lowest (621-626). The C0 behaviour.
Stall or guest (Michael, 26 Oct 2026: a Tier 2 FAIL on exact digital zero is judged by hand before it is a candidate; thresholds.toml [stall], STALLCAL; measured 27 Oct 2026 on every capture of the plan): not applicable: no capture; the verdict is T2.EXE's own reading of the 8259.
Trace: by reading, at the pinned SHA: src/audio/irq.asm `virtual_pic_write` takes OCW2 by bits 6:5 (469-483): 01 (20h-3Fh, A0h-BFh) is made a plain non-specific EOI, `mov al, 20h` (479), so A0h's rotation is dropped; 11 is the specific EOI; anything else, Set Priority C0h-C7h among them (bits 10), goes to `.done` (483) and is neither emulated nor passed to the physical controller, though the comment above (471-475) says the physical controller keeps it. The virtual line's interrupt is the driver's own delivery, not the physical chip's, so the physical priorities would not order it anyway. HOSTCD P5, P6 ("kept by the physical controller, not emulated ... harmless") is contradicted by the code and by this row. Minimal reproduction: `T2.EXE PICROT` under C2 (matrix T2X-PICROT).
Hypothesis, pin (labelled, not tested): a virtual priority (the bottom level, set by C0h-C7h, moved by A0h and E0h-E7h) consulted where the driver chooses between delivering the virtual line and letting a waiting physical one through would answer the document; how the delivery is ordered against the physical timer was not traced. Evidence: emulator (plans 708fb84f and fd562273), dynarec off. Hardware: UNCONFIRMED.
Observed, a1 (Michael, 27 Oct 2026, rules-bot's fold: the reading-grade line replaced by a plan; rule 7, the old line: "0.9.5-a1: none (reading, a1 c5531c8 against a6 8252786: no hunk in src/audio/irq.asm touches OCW2's priority or rotation forms)."): the author's 0.9.5-a1 built as the bench's option a1 (fork main c5531c8, fixtures/a1/MANIFEST.txt), T2X-PICROT-A1, plan 8f20b2fa `fail: 10`, narrower: T2.TXT `FAIL PICROT both requests waiting: first the timer (the BIOS's order, IR0 highest: the timer); after OCW2 Set Priority with the card's line highest, the card (the card); after its rotating EOI A0h, the neither (a request missing) (the timer: the card's line now lowest)` in all ten. On a1 Set Priority is served as asked; after the rotating EOI, with both requests waiting, neither is served within the wait. Label (rule 7: the old, CANDIDATE_UCDD_SFX against the pinned C2): upstream candidate, for the rotating EOI (8259:673-691); the Set Priority half passes on a1, and no note of the author's names OCW2 (not read further). Evidence: emulator (plans fd562273, 8f20b2fa), dynarec off.
Hypothesis, a1 (labelled, not tested; by reading): the mechanism differs from the pin's. a1's `virtual_pic_write` (src/audio/irq.asm:407-447 at c5531c8) passes Set Priority, C0h-C7h, to the physical controller (430-433), which is why that step passes; the rotating EOI A0h matches none of its forms (20h, C0h-C7h, 60h-67h) and goes to `.unsupported` (442-447): a fault is set and the EOI is neither emulated nor passed on, so the card's line stays in service and neither request is served, where the pin turns A0h into a plain EOI (pin irq.asm:479). The upstream report: A0h (and E0h-E7h, rotate on specific EOI, by the same reading) taken as an end of interrupt with its rotation (8259:673-677).
Also T2X-PICROT-M (28 Oct 2026; plan a6cda8bd `fail: 10`, T2.TXT the same line as T2X-PICROT's in every run): with T1A's track 2 playing around the case the same failure; the CD's 1 kHz on through it without a gap (tonecheck PASS in all ten). C0 PASS 10/10 (T2C0-PICROT-M, plan 5b4682e3).

### CAND-9 Tier 2, T2X-SC8PAGE1: an 8-bit block that runs past the end of its 64 KB DMA page is refused, so it never plays and its interrupt never comes (found 26 Oct 2026; the fork line lacks the upstream fix, B's backlog, 27 Oct; LACKS-FIX, 28 Oct)

Pinned: count-position 7994cd1 (C2 hash UCDD.EXE 03d92066, UCDDHOST.BIN 447ace33; the bench's fixtures/pinned/MANIFEST.txt). Bin: CANDIDATE_UCDD_SFX, FAIL 10/10 under C2, one identical line (Tier 2; the template's 3/3 is the sweep's).
Cell: none (Tier 2: T2.EXE, real mode, no game), scope not applicable; the author found it in a game (below), so the census can look for games that place a DMA buffer near a page's end.
Affected: The Big Red Adventure by the author's note (its intro's missing sound and the stop at the Kremlin picture); others not known. Controls: C0 PASS 10/10 (T2C0-SC8PAGE1, plan 5fb0d861: 86Box's own card raises the interrupt for every crossing block, 4 at 11025 Hz, 8 at 22050); C1 not applicable (no virtual card).
Observed: T2.TXT `FAIL SC8PAGE1 P0 4096 bytes at 11025 Hz: 0 blocks, 0 interrupts, a block's interrupt never came, the address after it F800h ...; P1 4096 bytes at 22050 Hz: 0 blocks, 0 interrupts, a block's interrupt never came, the address after it F800h` in all ten C2 runs (plan 49b66842, folders t2c2p-001 to -010): a 14h block of 4096 bytes programmed at F800h in its page; the virtual channel's address never moves. Expected: "The transfer begins here. The DSP will generate an interrupt after transferring the programmed number of bytes" (SBG:1590-1591; single-cycle mode, 1280-1282; the 14h command, 3271-3278; VSB:319-324), the block taken as the card takes it; the 8237's address wraps within the page (8237:331-338, SBG:1285-1294: SC8PAGE2's, judged on the CT2290 in AKIT). The C0 behaviour for the interrupt.
Stall or guest (Michael, 26 Oct 2026: a Tier 2 FAIL on exact digital zero is judged by hand before it is a candidate; thresholds.toml [stall], STALLCAL; measured 27 Oct 2026 on every capture of the plan): not applicable: no capture; the verdict is the guest's own count (0 blocks, 0 interrupts).
Trace: by reading, at the pinned SHA: src/audio/trap.asm, at the DSP command that starts a block, adds the block's length to the channel's 16-bit address (1564-1580) and, for an 8-bit channel, refuses the command when the sum passes 65536: `cmp eax, 65536` / `ja .command_unsupported` (1582-1583, to 453), so the 14h is dropped: nothing plays and no interrupt is raised. Minimal reproduction: `T2.EXE SC8PAGE1` under C2 (matrix T2X-SC8PAGE1).
Hypothesis (labelled, not tested): the author's Beta 0.9.4-a6 (fork main 8252786, RELEASE-NOTES.md:6): "Play 8-bit sound blocks that run past the end of a 64 KiB DMA page. The DMA address wraps to the start of the same page, as on the hardware. This fixes the missing sound and the stop at the Kremlin picture in the intro of The Big Red Adventure." The pinned line predates it; merge-a6 carries his sample fetch with the page wrap (ISSUES.md UPA6, mix.asm sb_dma_sample: his), built, not run. Under the merging rule his fix is taken, not rewritten; T2X-SC8PAGE1 and SC8PAGE2 are its checks once merge-a6 is the build under test. Evidence: emulator (plans 5fb0d861 and 49b66842), dynarec off. Hardware: UNCONFIRMED.
0.9.5-a1 (Michael, 27 Oct 2026, rules-bot's fold: the reading-grade line replaced by a plan; rule 7, the old line: "0.9.5-a1: none (reading, a1 c5531c8 against a6 8252786: no hunk touches the page, src/audio/mix.asm sb_dma_sample at a1 785 untouched; his fix is 0.9.4-a6, in the Hypothesis)."): the author's 0.9.5-a1 built as the bench's option a1 (fork main c5531c8, fixtures/a1/MANIFEST.txt), T2X-SC8PAGE1-A1, plan 1f8ca693 `pass: 10` (P0 and P1: 4 and 8 blocks, an interrupt each, the address after them 0800h, wrapped within the page). Label (rule 7: the old, CANDIDATE_UCDD_SFX against the pinned C2): the fork line lacks the upstream fix: the author's 0.9.4-a6 note (RELEASE-NOTES.md:48 at c5531c8, quoted in the Hypothesis); moved to B's backlog. Evidence: emulator (plans 5fb0d861, 49b66842, 1f8ca693), dynarec off.

### CAND-10 Tier 2, T2X-AI8 (A2, A3) and T2X-S16AI (SS44, SU44, SS48, SU48): auto-init DMA buffers over 32 KB refused, 8-bit or 16-bit, whatever the rate, so a 64 KB double buffer never plays, nor 0.2 s of 16-bit stereo at 44100 or 48000 Hz (found 26 Oct 2026, open; the size, not the rate, 27 Oct; split on a1, 27 Oct; split into CAND-10A and CAND-10B, 28 Oct, below)

Pinned: count-position 7994cd1 (C2 hash UCDD.EXE 03d92066, UCDDHOST.BIN 447ace33; the bench's fixtures/pinned/MANIFEST.txt). Bin: CANDIDATE_UCDD_SFX, FAIL 10/10 under C2, one identical line for these steps (Tier 2; the template's 3/3 is the sweep's).
Cell: none (Tier 2: T2.EXE, real mode, no game), scope not applicable; the author found it in games (below).
Affected: The Incredible Machine 2 and Alien Terminator by the author's note; others not known. Controls: C0 PASS 10/10 (T2C0-AI8, plan ed15c007: 86Box's own card plays the 64 KB buffer, two 32 KB blocks, stops at DAh one block later, and starts again at 1Ch); C1 not applicable.
Observed: T2.TXT `A2: 0 interrupts before DAh, one more after it no, none after that no; A3: 0 interrupts before DAh, ...` and tonecheck `A2+0.1-1.1 s 2000 Hz: 0/1 windows (peak nan Hz, SNR -inf dB) FAIL; ... A3+0.1-1.1 s 2000 Hz: 0/1 windows ... FAIL` in all ten C2 runs (plan 0add08f0, folders t2c2a-001 to -010): the 64 KB buffer (DMA count FFFFh, mode 59h) with 48h 7FFFh and 1Ch gives no sound and no interrupt, and the 1Ch after it (A3) has nothing to start; A0 (2 KB) and A1 (8 KB) pass. Expected: "The application allocates a stationary DMA buffer which must not straddle a 64 KB physical page boundary. The DSP block transfer size is then set to half of the DMA buffer size" (SBG:1308-1311), the 8237 count up to FFFFh (65536 bytes); an interrupt each block (1303-1306). The C0 behaviour.
Also T2X-S16AI (26 Oct 2026; plan d085604b, folders s16c2-001 to -010, FAIL 10/10, one identical T2.TXT line): the same cap on the 16-bit channel. B6h stereo at 44100 and 48000 Hz over buffers of 0.2 s, 35280 and 38400 bytes (channel 5, mode 59h, word counts 44E7h and 4AFFh), gives no sound and no interrupt: T2.TXT `SS44: 0, no, no, 82h FFh then FFh; SU44: 0, no, no, 82h FFh then FFh; ... SS48: 0, no, no, 82h FFh then FFh; SU48: 0, no, no, 82h FFh then FFh` and tonecheck `SS44+0.1-1.1 s L 2002 Hz: 0/1 windows (peak nan Hz, SNR -inf dB) FAIL` and the same for SU44, SS48 and SU48 (SU44's interval then holds MS48's tone, started early). The eight steps whose buffers are 17640 to 19200 bytes pass: stereo at 22050 Hz, mono at every rate, 48000 Hz at 1892.2 Hz as due (the DSP 4.13's 45412 Hz, VSB:290-304). `.validate_dma` takes the 16-bit channel's word count as bytes (1454, 1476-1478) before the same 32768 test (1504-1505). Control: C0 PASS 10/10 (T2C0-S16AI, plan e5406064). Expected: a buffer "in contiguous memory without straddling a 64KB physical page boundary" (SBG:2112-2113) and a Bxh length of up to FFFFh samples (SBG:3864); an interrupt each block (SBG:2164-2165).
Split (Michael, 27 Oct 2026). 44.1 kHz (SS44, SU44: 16-bit stereo at 44100 Hz, buffers of 35280 bytes): inside the SB16's documented range, SBG:1424 (DSP 4.xx, Stereo/Normal, 16-bit signed, 5000 to 44100 Hz) and SBG:3577 (41h: 5000 to 45 000 Hz inclusive): a plain candidate, as above. 48 kHz (SS48, SU48: 16-bit stereo at 48000 Hz, 38400 bytes): above the guide's ceiling in both places, so no Creative document says the card plays it; the expectation rests on uCDD's own line, the pinned tree's RELEASE-NOTES.md:144 (7994cd1): "Accept Sound Blaster output rates up to 48000 Hz.", the driver's claim, not a reference (method.toml [references] has no key for it). That half is not called a fault until the CT2290 plays 48 kHz 16-bit stereo on AKIT (STATE's AKIT list): whether it plays a 0.2 s auto-init buffer at 48000 Hz, at what rate, an interrupt a block. The mechanism is the same 32 KB cap in both halves (MS48 and MU48, 19200 bytes, play: 1892.2 Hz on the DSP 4.13's rate register, VSB:290-304).
The size, not the rate (Michael, 27 Oct 2026; T2X-S16AIH, plan b77d8093 `pass: 10`, C0 6956436c `pass: 10`, planted 4f46ea7f `fail: 1`): S16AI's SS44, the same format at the same 44100 Hz, with a 0.1 s buffer (17640 bytes, blocks of 8820) plays on the pinned C2: `SS44: 30, yes, yes` and the tone at 2002.9 Hz in all ten. With the 0.2 s buffer (35280 bytes, blocks of 17640) it is refused. Both block sizes are under 32 KB; what differs is the buffer, as the trace reads (the DMA count + 1 against 32768), so the row names the buffer, not the block. The guide's limit is 64 KB a block (SBG:1285-1289: "may be of different sizes (but not more than 64 KB each)"; the auto-init buffer, its block half of it, must not straddle a 64 KB page, SBG:1309-1311); the author lifted the cap himself in 0.9.4-a3 (RELEASE-NOTES.md:37 on 8252786: "DMA buffers up to 64 KB"). The 48 kHz half folds in: the same cap (38400 bytes refused; MS48 and MU48, 19200 bytes, play), and 48000 Hz itself is taken (mono, at 45412 Hz on the DSP 4.13's register); the AKIT entry stays, for what the CT2290 does at 48 kHz (the guide is silent above 44100 Hz: SBG:1424, 3577).
Stall or guest (Michael, 26 Oct 2026: a Tier 2 FAIL on exact digital zero is judged by hand before it is a candidate; thresholds.toml [stall], STALLCAL; measured 27 Oct 2026 on every capture of the plan): guest. Plan 0add08f0: exact zeros on every channel, 20 runs of 823 to 5731 ms in 10 captures; plan d085604b: 70 runs of 772 to 2488 ms, and the right channel alone exact zero for 100 ms or more in all 10 (the recorder zeroes every channel). None on a straight fade or ending on the buffer edge (edge(): stall in none), none one buffer long (896 samples, the recorder's every stall so far), the closing beep in place, and T2.EXE's own count says 0 interrupts for each refused step.
Also T2X-AI8-M (27 Oct 2026; plan dcad8722, FAIL 10/10, the same checks in every run): with T1A's track 2 playing the same refusal: A2 and A3 `0 interrupts before DAh` and the 2 kHz absent in its band (the card's level under the silence level), the CD's 1 kHz on through the whole span without a drop. C0 PASS 10/10 (T2C0-AI8-M, plan d7c3511f). Stall or guest: not applicable (the absence is read by level, not by a silence's shape).
Also T2X-S16AI-M (27 Oct 2026; plan 0c2e4f08, FAIL 10/10, the same checks in every run): with T1A's track 2 playing (twice, the track being shorter than the twelve steps) the same refusal: SS44, SU44, SS48 and SU48 `0, no, no` in T2.TXT, the tone absent in its band on the left (about -87 dBFS) in SS44, SS48 and SU48; the CD's 1 kHz on through both plays without a drop. SU44's window reaches MS48's tone (the refused step lasts 15 ticks), so its right reads about -57 dBFS in the tone's band, as in T2X-S16AI's own runs. C0 PASS 10/10 (T2C0-S16AI-M, plan 48661467). Stall or guest: not applicable (the absence is read by level, not by a silence's shape).
Trace: by reading, at the pinned SHA: src/audio/trap.asm `.validate_dma` takes the auto-init buffer as the DMA count + 1 (1476-1478) and `.large_block` refuses it above 32 KB: `cmp ebx, 32768` / `ja .command_unsupported` (1501-1505), so the 1Ch (or the B6h) is dropped. Minimal reproduction: `T2.EXE AI8` under C2 (matrix T2X-AI8), step A2; `T2.EXE S16AI` (T2X-S16AI), step SS44.
Hypothesis (labelled, not tested): the author's Beta 0.9.4-a3 (fork main 8252786, RELEASE-NOTES.md:37): "Accept short Sound Blaster DMA blocks, blocks shorter than one output period, and DMA buffers up to 64 KB. This fixes the sound in The Incredible Machine 2 and Alien Terminator." The pinned line predates it; his a6 and our merge-a6 (27d51b6, trap.asm:1627-1631) have no 32 KB cap after the 512-byte minimum, built, not run. His fix is taken under the merging rule, not rewritten. Evidence: emulator (plans ed15c007 and 0add08f0; e5406064 and d085604b), dynarec off. Hardware: UNCONFIRMED.
0.9.5-a1 (Michael, 27 Oct 2026, rules-bot's fold: the reading-grade line replaced by a plan; rule 7, the old line: "0.9.5-a1: none (reading, a1 c5531c8 against a6 8252786: no hunk touches the buffer limit; his fix is 0.9.4-a3, in the Hypothesis)."): the author's 0.9.5-a1 built as the bench's option a1 (fork main c5531c8, fixtures/a1/MANIFEST.txt), split by the two cases. (1) T2X-AI8-A1, plan fd1de08d `fail: 10`: `A2: 0 interrupts before DAh, one more after it no, none after that no; A3: 0 interrupts ...` and no tone at A2 and A3 in all ten (A0 and A1 pass). By reading (a1 src/audio/trap.asm:1328-1336, `.buffer_size`, "The mixer uses 16-bit buffer offsets"): a buffer of more than 65535 frames is refused, and A2's 8-bit mono 64 KB buffer (count FFFFh) is 65536. On a1 this half narrows to a buffer of the full 64 KB: upstream candidate (SBG:1300-1326: a buffer within one 64 KB page). (2) T2X-S16AI-A1, plan 3694b485 `fail: 10`, but T2.TXT PASS in every run: all twelve formats, SS44, SU44, SS48 and SU48 included, 15 interrupts, one more after D9h, none after that. That half passes on a1: the fork line lacks the upstream fix, the author's 0.9.4-a3 note (RELEASE-NOTES.md:79 at c5531c8, quoted in the Hypothesis), B's backlog. Its tonecheck fails are at 48000 Hz only: the tone at 2000.0 Hz against the pin's 1892.2 Hz (a1 plays 41h's rate as asked, not through the DSP 4.13 register: the item on B's list of 27 Oct, not a Project A report), and the third harmonic at -18.9 to -19.9 dB against the 20 dB rule in 4 of the 40 windows at 48 kHz (MS48, SS48 twice, SU48): recorded, not filed, a rate above the guide's ceiling. Label (rule 7: the old, CANDIDATE_UCDD_SFX against the pinned C2): split, the 8-bit 64 KB half an upstream candidate, the 16-bit half B's backlog; Michael to confirm the split (STATE, Project A question 28). Confirmed (Michael, 28 Oct 2026, question 28): CAND-10A and CAND-10B below; this row keeps the evidence and the trace, the two rows carry the labels. Evidence: emulator (plans 0add08f0, d085604b, fd1de08d, 3694b485), dynarec off; the 64 KB limit by reading.

### CAND-10A Tier 2, T2X-S16AI (SS44, SU44, SS48, SU48): a 16-bit auto-init buffer over 32 KB refused (split from CAND-10, 28 Oct 2026; the fork line lacks the upstream fix, LACKS-FIX, B's backlog)

Split (Michael, 28 Oct 2026, question 28): CAND-10's 16-bit half. Its evidence, trace and Hypothesis stay in CAND-10 above. Pin: count-position 7994cd1, T2X-S16AI, plan d085604b `fail: 10` (SS44, SU44, SS48, SU48: `0, no, no`; buffers of 35280 and 38400 bytes against the 32 KB test, pin src/audio/trap.asm:1501-1505); the size, not the rate (T2X-S16AIH, b77d8093 `pass: 10`). a1: T2X-S16AI-A1, plan 3694b485, T2.TXT PASS in all ten (every format 15 interrupts, one more after D9h, none after); its tonecheck fails are 48 kHz's pitch as asked and four third-harmonic windows at 48 kHz (CAND-10). Expected: SBG:2112-2113 (a buffer within a 64 KB page), SBG:3864 (a length of up to FFFFh samples), SBG:2164-2165 (an interrupt a block). Note cited: the author's 0.9.4-a3, RELEASE-NOTES.md:79 at c5531c8 ("DMA buffers up to 64 KB"). Label: LACKS-FIX (the fork line lacks the upstream fix), B's backlog. Evidence: emulator (plans d085604b, 3694b485), dynarec off. Hardware: UNCONFIRMED (48 kHz on AKIT, CAND-10).

### CAND-10B Tier 2, T2X-AI8 (A2, A3): an 8-bit auto-init buffer of the full 64 KB (8237 count FFFFh) is refused, so it never plays and its interrupt never comes (split from CAND-10, 28 Oct 2026, open; upstream candidate)

Split (Michael, 28 Oct 2026, question 28): CAND-10's 8-bit half. Its pin evidence, stall judgement and trace stay in CAND-10 above. Structure as CAND-4's: pin and a1 sections, one expectation, the upstream report from the a1 section.
Expected (Michael's citation, 28 Oct 2026): the guide codes a length as a 16-bit count less one, so 65536 is the largest it can code: 48h "wBlockSize is a word giving the number of bytes to transfer less 1" (SBG:3604-3610; also SBG:1585-1587 and 1657, "one less than the actual transfer size"). The size refused here is the buffer's, not the block's (A2's blocks are 32 KB, 48h 7FFFh; its buffer is the 8237 count FFFFh), and the buffer's count is coded the same way: the 8237's word count is 16 bits (8237:33, "a full 64K address and word count capability") and a transfer ends when it rolls over from zero to FFFFh (8237:253-256), so FFFFh moves 65536 bytes; the buffer must not straddle a 64 KB page (SBG:1308-1311), which a 65536-byte buffer on a page boundary does not. An interrupt each block (SBG:1303-1306). The C0 behaviour (T2C0-AI8, ed15c007 `pass: 10`).
Observed, pin: T2X-AI8, plan 0add08f0 `fail: 10`: `A2: 0 interrupts before DAh ...; A3: 0 interrupts ...`, no tone at A2 and A3 (CAND-10); with the CD, T2X-AI8-M dcad8722 `fail: 10`.
Observed, a1: T2X-AI8-A1, plan fd1de08d `fail: 10`: the same lines, A0 and A1 pass (CAND-10's a1 section).
Hypothesis, pin (labelled, not tested): the 32 KB test (pin src/audio/trap.asm:1501-1505), CAND-10's trace.
Hypothesis, a1 (labelled, not tested; by reading): a1's `.buffer_size` (src/audio/trap.asm:1328-1336 at c5531c8, "The mixer uses 16-bit buffer offsets") lets 65536 bytes through (`cmp ebx, 65536` / `ja`) and then refuses more than 65535 frames (`cmp eax, 65535` / `ja .argument_rejected`); an 8-bit mono buffer of 64 KB is 65536 frames. A 16-bit offset holds 0 to 65535, the buffer's every frame; the length 65536 itself is what does not fit. The upstream report: the case, its T2.TXT line and this reading.
Label: upstream candidate, CANDIDATE_UCDD_SFX. Evidence: emulator (plans ed15c007, 0add08f0, dcad8722, fd1de08d), dynarec off; the a1 limit by reading. Hardware: UNCONFIRMED.

### CAND-11 Tier 2, T2X-AI8 (A4): the 8237 channel moved at a block end during auto-init is not followed: the old buffer goes on sounding (found 26 Oct 2026, open; upstream candidate: fails on a1 in 3 of 10, 27 Oct)

Pinned: count-position 7994cd1 (C2 hash UCDD.EXE 03d92066, UCDDHOST.BIN 447ace33; the bench's fixtures/pinned/MANIFEST.txt). Bin: CANDIDATE_UCDD_SFX, FAIL 10/10 under C2, one identical line for this step (Tier 2; the template's 3/3 is the sweep's).
Cell: none (Tier 2: T2.EXE, real mode, no game), scope not applicable; games that switch DMA buffers during auto-init are not known yet (the census can look for 8237 address writes while their channel runs).
Affected: not known. Controls: C0 PASS 10/10 (T2C0-AI8, plan ed15c007: after the move the capture is silence, `SW+0.3-1.0 s silence: RMS -240.0 dBFS`); C1 not applicable.
Observed: in all ten C2 runs (plan 0add08f0): the channel's address and count written again (mask, flip-flop, mode 59h, address, count, page, unmask) just after a block's interrupt, from the 8 KB tone to 8 KB of silence; the interrupts go on (8 after the move) but tonecheck `SW+0.3-1.0 s silence: RMS -24.6 dBFS FAIL`: the tone of the old buffer, at its level. Expected: a write to the channel's address port is "Base and Current Address" (8237:530-531): "The base registers are written simultaneously with their corresponding current register" (8237:380-382), so the transfer goes on from the new address, and the auto-init reload brings back the new base (374-379). The C0 behaviour.
Stall or guest (Michael, 26 Oct 2026: a Tier 2 FAIL on exact digital zero is judged by hand before it is a candidate; thresholds.toml [stall], STALLCAL; measured 27 Oct 2026 on every capture of the plan): not applicable: the failing check is sound where silence is due (the old buffer), not silence.
Also T2X-AI8-M (27 Oct 2026; plan dcad8722, FAIL 10/10): with T1A's track 2 playing, after SW the 2 kHz still sounds in its band (`SW+0.3-1.0 s 2000 Hz quiet among others: ... FAIL`, about -21.7 dBFS on the dev run), the old buffer going on. C0 PASS 10/10 (plan d7c3511f).
Trace: by reading, at the pinned SHA: src/audio/trap.asm `.address` and `.dma_word` (688-700) store the new address in the virtual channel and zero its position; the sound kept the old buffer, so where the sample fetch takes its address (at the DSP command, `.buffer_address`, 1564 on) and whether it reads the virtual channel again during a transfer was not traced. Minimal reproduction: `T2.EXE AI8` under C2 (matrix T2X-AI8), step A4.
Hypothesis (labelled, not tested): the fetch taking the channel's address from the virtual 8237 at each block (or at each write to it) instead of once at the command would follow the move; no note of the author's names it (0.9.4-a6 and 0.9.5-a1 read). Evidence: emulator (plans ed15c007 and 0add08f0), dynarec off. Hardware: UNCONFIRMED.
0.9.5-a1 (Michael, 27 Oct 2026, rules-bot's fold: the reading-grade line replaced by a plan; rule 7, the old line: "0.9.5-a1: none (reading, a1 c5531c8 against a6 8252786: no hunk in src/audio/trap.asm touches the 8237 address; RELEASE-NOTES.md:15, 'Start a single-cycle block that is longer than the DMA count, as a real card does', is another case)."): the author's 0.9.5-a1 built as the bench's option a1 (fork main c5531c8, fixtures/a1/MANIFEST.txt), T2X-AI8-A1, plan fd1de08d: A4 `16 interrupts before DAh, one more after it yes, none after that yes, interrupts after the move 8` in all ten; tonecheck `SW+0.3-1.0 s silence: RMS -19.3 dBFS FAIL` in 3 of the 10 (fd1de08d-006, -007, -009: the old buffer still sounding), silence in the other 7. Label (rule 7: the old, CANDIDATE_UCDD_SFX against the pinned C2): upstream candidate, 3 of 10 on a1 (the pin 10 of 10). Evidence: emulator (plans ed15c007, 0add08f0, fd1de08d), dynarec off.

### CAND-12 Tier 2, T2X-S16ODD1: a 16-bit stereo auto-init block of an odd count of samples, shorter than its buffer, is refused: no sound and no interrupt (found 26 Oct 2026, open; upstream candidate: fails on a1 too (the D9h exit), 27 Oct; pin and a1 sections, 28 Oct)

Pinned: count-position 7994cd1 (C2 hash UCDD.EXE 03d92066, UCDDHOST.BIN 447ace33; the bench's fixtures/pinned/MANIFEST.txt). Bin: CANDIDATE_UCDD_SFX, FAIL 10/10 under C2, one identical line for these steps (Tier 2; the template's 3/3 is the sweep's).
Cell: none (Tier 2: T2.EXE, real mode, no game), scope not applicable; the author names Surface Tension (below). The census can look for Bxh/Cxh commands with a stereo mode byte and an odd sample count.
Affected: Surface Tension by the author's note; others not known. Controls: C0 PASS 10/10 (T2C0-S16ODD1, plan 2224f8c2: 86Box's own card plays each step, 15 interrupts at 22050 Hz and 30 at 44100, the tone left and the right silent); C1 not applicable.
Structure (Michael, 28 Oct 2026, question 28): one row, two observed sections, pin and a1, under one expectation and citation; the upstream report is written from the a1 section; a Hypothesis per build where the mechanism differs. The a1 section is the row's former 0.9.5-a1 line, its text unchanged.
Observed, pin: in all ten C2 runs (plan 96dbfaff, folders 96dbfaff-001 to -010): B6h with mode 30h or 20h and a length of 1138h (4409 samples, an odd count) over a buffer of 4410 whole frames (17640 bytes; channel 5, mode 59h, word count 2273h) gives no sound and no interrupt: T2.TXT `SS22: 0, no, no, 82h FFh then FFh; SU22: 0, no, no, 82h FFh then FFh; SS44: 0, no, no, 82h FFh then FFh; SU44: 0, no, no, 82h FFh then FFh`, tonecheck `SS22+0.1-1.1 s L 2002 Hz: 0/1 windows (peak nan Hz, SNR -inf dB) FAIL` and the same for the other three. Even counts over the same kind of buffer play (T2X-S16AI's SS22 and SU22, plan d085604b). Expected: the guide is silent on an odd stereo count (wLength, "the number of 16-bit samples less 1", SBG:3864; an interrupt at the end of each block, SBG:2164-2165); both emulators play it on, an interrupt a block, the frames still paired (EMUSRC: DOSBox-X src/hardware/sblaster.cpp at 97ff66a, SB_INFO::GenerateDMASound keeps the odd last sample for the next transfer, `remain_size`; 86Box src/sound/snd_sb_dsp.c at 6311adc, sb_poll_o reads two words a frame and plays whole frames, one sample over), so emulation decides (rule 1): it plays. Grade emulator.
Also T2X-S16ODD-M (27 Oct 2026; plan ddd99d59, FAIL 10/10, the same line in every run): with T1A's track 2 playing the same refusal, T2.TXT `SS22: 0, no, no` to `SU44: 0, no, no`; each step ends 0.22 to 0.27 s after its tick, so tonecheck reads it too short to judge (NOT_JUDGED, which counts toward no candidate: the evidence here is T2.TXT's line); the CD's 1 kHz on without a drop. C0 PASS 10/10 (T2C0-S16ODD-M, plan dcfe1886).
Not CAND-10's cap (Michael's question, 27 Oct 2026; measured): T2X-S16AIH's SS44 has the same buffer as S16ODD1's SS44, 4410 frames, 17640 bytes, under 32 KB, and plays on the pinned C2 with blocks of 4410 samples (plan b77d8093 `pass: 10`, `SS44: 30, yes, yes`); with blocks of 4409 it is refused (96dbfaff, ddd99d59). Same routine, another test: `.large_block`'s whole-frames test on the block (trap.asm:1516-1520), not its 32 KB test on the buffer (CAND-10); the author's notes fix them in separate lines (0.9.4, RELEASE-NOTES.md:166, odd counts; 0.9.4-a3, :37, 64 KB buffers).
Stall or guest (Michael, 26 Oct 2026: a Tier 2 FAIL on exact digital zero is judged by hand before it is a candidate; thresholds.toml [stall], STALLCAL; measured 27 Oct 2026 on every capture of the plan): guest. Plan 96dbfaff: one run of exact zeros on every channel in each capture, 4019 to 4074 ms, the whole case; no fade, not on the buffer edge, not one buffer long; T2.EXE's own count: 0 interrupts each step.
Trace: by reading, at the pinned SHA: src/audio/trap.asm `.large_block`, after the buffer's own checks (1501-1511), refuses a block that is not whole frames unless it is longer than the buffer: `cmp edx, ebx` / `ja .block_aligned` / `test edx, eax` / `jz .block_aligned` / `jmp .command_unsupported` (1516-1520), so the B6h is dropped. The rule beside it is ours (`odd-long-block`, HMI's ESS driver: a block longer than its buffer need not be whole frames). Single-cycle blocks skip the test (`.validate_dma`, 1474-1475): T2.EXE S16ODD2, held on STATE question 14. Minimal reproduction: `T2.EXE S16ODD1` under C2 (matrix T2X-S16ODD1), any step.
Hypothesis, pin (labelled, not tested): the author's Beta 0.9.4 (fork main, RELEASE-NOTES.md:166): "Accept stereo DMA blocks with an odd number of 16-bit samples. This fixes missing sound effects in Surface Tension." The pinned line predates it; his a6 and a1 test only the buffer for whole frames in that path (a6 trap.asm `.buffer_size`, 1290-1303), not the block. Our merge-a6 (27d51b6, trap.asm:1648-1652) kept our block test beside his sizes (the merge table's "our rule for a block longer than its buffer", line 562 above), so by reading it still refuses these blocks: against the merging rule (his fix kept where both sides touched the behaviour), built, not run. His fix is taken under that rule, not rewritten; the HMI rule stays only where his does not cover it. Evidence: emulator (plans 2224f8c2 and 96dbfaff), dynarec off. Hardware: UNCONFIRMED.
Observed, a1 (Michael, 27 Oct 2026, rules-bot's fold: the reading-grade line replaced by a plan; rule 7, the old line: "0.9.5-a1: none new (reading, a1 c5531c8 against a6 8252786: no hunk touches the block test; his fix is 0.9.4, in the Hypothesis)."): the author's 0.9.5-a1 built as the bench's option a1 (fork main c5531c8, fixtures/a1/MANIFEST.txt), T2X-S16ODD1-A1, plan 81daa1fc `fail: 10`, a different failure: the odd block plays (tonecheck PASS, every format) and its interrupts come, but after D9h the one more interrupt never comes: T2.TXT `SS22: 15, no, no, 82h 02h then 00h` and the same for SU22 (15), SS44 and SU44 (30) in all ten (the wait for it timed out). Even blocks exit right on a1 (T2X-S16AI-A1, 3694b485). The pinned build's refusal is gone on a1 (the author's 0.9.4 note, RELEASE-NOTES.md:166 at c5531c8, quoted in the Hypothesis); the exit after D9h for an odd block fails. Label (rule 7: the old, CANDIDATE_UCDD_SFX against the pinned C2): upstream candidate, for the D9h exit (SBG:4020-4030). Evidence: emulator (plans 96dbfaff, 81daa1fc), dynarec off.
Hypothesis, a1 (labelled, not tested; by reading, in part): the mechanism differs from the pin's (the pin refuses the block; a1 plays it). a1's D9h path (src/audio/trap.asm:894-941 at c5531c8) sets the exit frame from the blocks consumed, rounded up to a whole block, then turned into frames by a shift (`shr eax, cl` by the frame shift, 912-913 and 930-931); a block of 4409 16-bit samples (1138h, the count in samples, SBG:3864) is 8818 bytes, 2204.5 stereo frames, so the shift drops the half frame and the exit frame falls half a frame short of a block's end; whether the one more interrupt is lost there was not traced. The upstream report: the case and its T2.TXT line; the cause left to the author.

### CAND-13 Tier 2, T2X-S16ODD2: 16-bit stereo single-cycle blocks of an odd count of samples start every other block on the right channel: the channels swap block by block (found 26 Oct 2026, open; upstream candidate: fails on a1 too, 27 Oct; pin and a1 sections, 28 Oct)

Pinned: count-position 7994cd1 (C2 hash UCDD.EXE 03d92066, UCDDHOST.BIN 447ace33; the bench's fixtures/pinned/MANIFEST.txt). Bin: CANDIDATE_UCDD_SFX, FAIL 10/10 under C2, the same failing checks in every run (Tier 2; the template's 3/3 is the sweep's).
Cell: none (Tier 2: T2.EXE, real mode, no game), scope not applicable; games that send single-cycle stereo blocks of an odd count are not known (the census can look for B0h-B3h with a stereo mode byte and an odd sample count).
Affected: not known. Controls: C0 not available: 86Box's own card gives no interrupt for this block (86ODDSC, an emulator row); the control is DOSBox-X at T6 and the judge the CT2290 in AKIT (Michael, 26 Oct 2026, question 14). C1 not applicable.
Structure (Michael, 28 Oct 2026, question 28): one row, two observed sections, pin and a1, under one expectation and citation; the upstream report is written from the a1 section; a Hypothesis per build where the mechanism differs. The a1 section is the row's former 0.9.5-a1 line, its text unchanged.
Observed, pin: in all ten C2 runs (plan a0c1f221, folders a0c1f221-001 to -010): B0h with mode 30h or 20h and a length of 1138h (4409 samples), each block from where the last one ended, the channel and B0h sent again at each interrupt; every block's interrupt comes (T2.TXT `SS22: 15 blocks, 15 interrupts, 82h 82h then 80h; ... SS44: 29 blocks, 29 interrupts, ...`, PASS), but the tone, written left only, comes out left and right in turn, block by block (a0c1f221-001, quarter-block windows: `LLL-RRR-LLL-RRR`): tonecheck `SS22+0.1-1.1 s R silence: RMS -27.7 dBFS FAIL` and the same on SU22, SS44 and SU44, 40 readings from -27.4 to -27.9 dBFS, the left channel at about the same level. Expected: the guide gives the 16-bit stereo order, a left word then a right word for each sample (SBG:1230-1237), and the count in 16-bit samples, one word each (SBG:3864; "2K of 16-bit samples" for half of an 8 KB buffer, SBG:2161-2164); it says nothing on where a block of an odd count leaves the next one: silent, and the hardware decides (the CT2290 in AKIT). DOSBox-X keeps the odd last sample and pairs it with the next block's first, so the right channel stays silent there (src/hardware/sblaster.cpp at 97ff66a, SB_INFO::GenerateDMASound, `remain_size`): the control at T6, grade emulator; not yet run.
Also T2X-S16ODD2-M (27 Oct 2026; plan 8b7732c9, FAIL 10/10, the same checks in every run): with T1A's track 2 playing, every block and interrupt in T2.TXT as T2X-S16ODD2's, and the right side holding the card's tone at -24.9 dBFS in its band in all four steps (`SS22+0.1-1.1 s R 2002 Hz quiet among others: -24.9 dBFS FAIL`), the CD's 1 kHz on without a drop. Its C0 twin held as T2C0-S16ODD2's (question 14).
Stall or guest (Michael, 26 Oct 2026: a Tier 2 FAIL on exact digital zero is judged by hand before it is a candidate; thresholds.toml [stall], STALLCAL; measured 27 Oct 2026 on every capture of the plan): not applicable: the failing check is sound where silence is due (the right channel), not silence.
Trace: by reading, in part, at the pinned SHA: each block's source is the channel's current address at the command (src/audio/trap.asm 1625, kept as game_offset and game_segment at 1677-1679), and single-cycle blocks skip the frame test that refuses CAND-12's auto-init blocks (`.validate_dma`, 1474-1475); the capture shows each block's first word taken as left, so after an odd block the next starts on a right word. Where the odd last word goes was not traced. Minimal reproduction: `T2.EXE S16ODD2` under C2 (matrix T2X-S16ODD2), any step.
Hypothesis, pin (labelled, not tested; mine): keeping the odd last word of a stereo block and pairing it with the next block's first, as DOSBox-X does, would keep the channels; whether the CT2290 does that, plays the half frame, or drops it is what AKIT decides. The author's 0.9.4 note on odd blocks (RELEASE-NOTES.md:166) concerns accepting them; his a1 mixer names no carry of an odd word (read for "odd", "leftover" and the like only). Evidence: emulator (plan a0c1f221), dynarec off. Hardware: UNCONFIRMED.
Observed, a1 (Michael, 27 Oct 2026, rules-bot's fold: the reading-grade line replaced by a plan; rule 7, the old line: "0.9.5-a1: none (reading, a1 c5531c8 against a6 8252786: no hunk touches the stereo fetch)."): the author's 0.9.5-a1 built as the bench's option a1 (fork main c5531c8, fixtures/a1/MANIFEST.txt), T2X-S16ODD2-A1, plan 937c49e7 `fail: 10`: signed, the same swap: SS22 and SS44 every block and interrupt, the right side holding the tone (`SS22+0.1-1.1 s R silence: RMS -21.8 dBFS FAIL`, SS44 -21.6 dBFS) in all ten; unsigned, refused on a1 where the pin plays it: `SU22: 0 blocks, 0 interrupts, a block's interrupt never came, 82h FFh then FFh` and the same for SU44, all ten. Label (rule 7: the old, CANDIDATE_UCDD_SFX against the pinned C2): upstream candidate; the unsigned refusal is a1's own (not read). Evidence: emulator (plans a0c1f221, 937c49e7), dynarec off.
Hypothesis, a1 (labelled, not tested; by reading, in part): signed, the same swap as the pin, mechanism not read on a1. Unsigned, the mechanism differs: the pin plays the unsigned case that a1 refuses (`SU22: 0 blocks`), so on that half a1 is behind the pin. a1's single-cycle checks (src/audio/trap.asm:1364-1390 at c5531c8) refuse a block when the channel's remaining count is zero (1381-1384) or the 16-bit buffer is over 64 KB (1370-1371); why the unsigned block meets one of them, or another, was not traced. The upstream report: the swap (signed) and the refusal (unsigned) as two lines.

### CAND-14 Tier 2, T2X-S16ON8: mixer 81h written with no 16-bit channel bit is ignored, and 16-bit samples cannot move on the 8-bit channel: no sound, no interrupt (found 26 Oct 2026; the fork line lacks the upstream fix, B's backlog, 27 Oct; LACKS-FIX, 28 Oct)

Pinned: count-position 7994cd1 (C2 hash UCDD.EXE 03d92066, UCDDHOST.BIN 447ace33; the bench's fixtures/pinned/MANIFEST.txt). Bin: CANDIDATE_UCDD_SFX, FAIL 10/10 under C2, one identical line (Tier 2; the template's 3/3 is the sweep's; run 001's first capture HARNESS_ERROR, taken again).
Cell: none (Tier 2: T2.EXE, real mode, no game), scope not applicable; DigPak's SB16 driver writes 81h = 02h (the sound engine library, digpak.md, "81h written"), and the author names The Horde (below).
Affected: The Horde by the author's note; DigPak's games by reading; others not known. Controls: C0 PASS 10/10 (T2C0-S16ON8, plan cd52e937: 86Box's own non-PnP SB16 takes the write, `81h 22h, written 02h, reads 02h`, and plays all four formats through channel 1); C1 not applicable.
Observed: in all ten C2 runs (plan dc6405c7, folders dc6405c7-001 to -010): 81h written 02h (channel 1's bit alone) reads back 22h, and B6h on channel 1 (mode 59h, byte counts) gives no sound and no interrupt: T2.TXT `81h 22h, written 02h, reads 22h; ... MS22: 0, no, no, 82h FFh then FFh; MU22: 0, no, no, 82h FFh then FFh; SS22: 0, no, no, 82h FFh then FFh; SU22: 0, no, no, 82h FFh then FFh`, tonecheck `MS22+0.1-1.1 s 2002 Hz: 0/1 windows (peak nan Hz, SNR -inf dB) FAIL` and the same on the other three. Expected: the CT2290's (vsb-spec.md 9.4, VSB:570-603, changed 26 Oct 2026 on Michael's word, question 15): its 81h takes the write (HWPROBE 19 Oct 2026, `X W81 22 20 20 22 22`; F12), and with no 16-bit channel bit set, only an 8-bit one, 16-bit data moves on that 8-bit channel (SBG:1136-1138). (Struck 27 Oct 2026 with vsb-spec 9.4's caveat, rule 7; the old text: "PnP boards differ, their 80h and 81h read only (SBG:1140-1148); the virtual card presents the CT2290." The CT2290 is a non-PnP SB16: SBG:1100-1106 decides.) What the CT2290 does with the transfer itself was not measured: the hardware kit judges it (STATE's AKIT list).
Also T2X-S16ON8-M (27 Oct 2026; plan 0759ed5c, FAIL 10/10, the same line in every run): with T1A's track 2 playing, 81h reads back 22h after 02h was written and every format is refused (`MS22: 0, no, no` to SU22); each step too short to judge in tonecheck (NOT_JUDGED, which counts toward no candidate: the evidence is T2.TXT's line); the CD's 1 kHz on without a drop. C0 PASS 10/10 (T2C0-S16ON8-M, plan 4856be64).
Status (rule 7 form). Old text (27 Oct 2026, the hold, withdrawn the same evening): "Held (Michael, 27 Oct 2026, from rules-bot): pending the CT2290's answer in AKIT (T2X-S16ON8: 16-bit samples on the 8-bit channel after 81h is written with the 8-bit channel's bit alone). The decision called the CT2290 a PnP card; the hardware record says otherwise: HWPROBE 19 Oct 2026 measured its 81h taking the write (`X W81 22 20 20 22 22`; F12), which SBG:1140-1148 says a PnP board's 81h does not ('read-only'); vsb-spec 9.4 and question 15 follow the measurement. Put to Michael as STATE question 24, with the judgeable row he asked for (UCDD.CFG and BLASTER without a high DMA channel), which cannot be configured as asked: the config reader takes the virtual high channel only from 5, 6, 7 in the pinned build and in the author's line (setup/config_file.asm, dma16_values), and his 0.9.3d path is switched by the guest's 81h write (merge-a6 sb_mixer.asm:31-39), not by the configuration." New text (Michael, 27 Oct 2026, from rules-bot, correcting his ruling): CAND-14 is not held; a plain candidate against SBG: the CT2290 is a second-generation, non-PnP SB16, on which 80h and 81h are written as any mixer register (SBG:1100-1106; the DMA select and 16-bit data on an 8-bit channel, SBG:1131-1138); the CT2290 in AKIT (T2X-S16ON8) confirms. The PnP caveat is struck from vsb-spec 9.4 and from question 15's record. The second row he asked for, the author's 0.9.3d shape (BLASTER without a high channel, the game's 81h write, 16-bit on channel 1), is T2X-S16ON8-NOH.
Also T2X-S16ON8-NOH (27 Oct 2026; plan 86e1bfc6, FAIL 10/10, the same line in every run): the author's 0.9.3d shape, BLASTER without H (A220 I5 D1 T6) and the game's 81h write with channel 1's bit alone: 81h reads back 22h and every format is refused (NOT_JUDGED in tonecheck; the evidence T2.TXT's line). C0 PASS 10/10 (T2C0-S16ON8-NOH, plan fe1c914d). UCDD.CFG keeps its virtual high channel 5, the only kind it holds.
Stall or guest (Michael, 26 Oct 2026: a Tier 2 FAIL on exact digital zero is judged by hand before it is a candidate; thresholds.toml [stall], STALLCAL; measured 27 Oct 2026 on every capture of the plan): guest. Plan dc6405c7: one run of exact zeros on every channel in each capture, 4128 to 4183 ms, the whole case; no fade, not on the buffer edge, not one buffer long; T2.EXE's own count: 0 interrupts each step.
Trace: by reading, at the pinned SHA: the virtual 81h is built from the setup's channels and a write does not change it (src/audio/sb_mixer.asm:27, 255-283); UCDDSET offers only channels 5 to 7 for the virtual 16-bit DMA (src/setup.asm:631-636); the trap takes every 16-bit transfer from the high controller's virtual channel (src/audio/trap.asm:1449-1455, its ports by guest_dma16 at 524-560), which T2.EXE left unprogrammed, so its count reads as one word and `.large_block` refuses the B6h (`cmp ebx, 512` / `jb .command_unsupported`, 1501-1503). Minimal reproduction: `T2.EXE S16ON8` under C2 (matrix T2X-S16ON8), any step.
Trace, step by step (Michael, 27 Oct 2026, from rules-bot: say how the result stands against the 0.9.3d note). What T2.EXE S16ON8 does (dos/src/t2/t2.asm): (1) 81h read (22h: channels 1 and 5), written 02h (channel 1's bit alone: `mov ah, 1` / `shl ah, cl` with cl = BLASTER's D), read back; the C0 card answers 02h, the pinned C2 22h; (2) channel 1 programmed by dma_auto: mask (0Ah), flip-flop (0Ch), mode 59h (0Bh: channel 1, single, auto-init, read from memory), the buffer's page, address and byte count less one, unmask; (3) B6h (16-bit output, auto-init, FIFO; s16_start), the mode byte (10h signed mono, 00h unsigned mono, 30h signed stereo, 20h unsigned stereo), the block length in 16-bit samples less one (half the 0.2 s buffer). "Refused" in T2.TXT is `MS22: 0, no, no, 82h FFh then FFh`: 0 interrupts before D9h, no interrupt after D9h, the third flag left unset because the step ended on its wait for a first interrupt, and 82h never read at an interrupt (FFh, the value before any). In the pinned build (count-position 7994cd1): the 81h write is not taken (src/audio/sb_mixer.asm:27-31: "80h-82h are read only"; the virtual 81h built from the setup's channels, 255-283), so the read-back is 22h; the B6h is a 16-bit transfer, taken from the high controller's virtual channel (trap.asm:1449-1455: `mov si, dma16`), which T2.EXE never programmed, so its count reads as one word and `.large_block` drops the command (`cmp ebx, 512` / `jb .command_unsupported`, 1501-1503): no sound and no interrupt. Related entry, the author's 0.9.3d note (fork main 8252786, RELEASE-NOTES.md:136): "Support Sound Blaster interrupt detection with high DSP time constants and 16-bit audio through an 8-bit DMA channel. This fixes sound card detection and sound effects in The Horde." Its shape in his code (a6; merge-a6 27d51b6): a guest write to 81h is stored and, with no 16-bit channel bit set, sets sb_dma16_low (sb_mixer.asm:31-39); a 16-bit transfer then takes the 8-bit channel (trap.asm:1550-1556). That is the shape the test drives: the same. It is not a regression in the pinned build: the pinned line is on top of 0.9.3b (its RELEASE-NOTES.md opens "These changes are on top of Beta 0.9.3b") and never had the 0.9.3d support; CAND-14 is the pinned line lacking the author's 0.9.3d fix, which merge-a6 carries, built, not run. No narrowing row: the test is the note's shape (T2X-S16ON8; the BLASTER-without-H variant T2X-S16ON8-NOH).
Hypothesis (labelled, not tested): the author's Beta 0.9.3d (fork main, RELEASE-NOTES.md:178): "Support Sound Blaster interrupt detection with high DSP time constants and 16-bit audio through an 8-bit DMA channel. This fixes sound card detection and sound effects in The Horde." His a1 stores an 81h write and sets `sb_dma16_low` when no high-channel bit is set (src/audio/trap.asm:445-470, `.dma_select`; a6 437-459). The pinned line predates it; our merge-a6 carries it (27d51b6: sb_mixer.asm:39, trap.asm:1556; the merge table's "with his 81h write", line 553 above), built, not run. His fix is taken under the merging rule, not rewritten. Evidence: emulator (plans cd52e937 and dc6405c7), dynarec off. Hardware: UNCONFIRMED; the CT2290 in AKIT judges.
0.9.5-a1 (Michael, 27 Oct 2026, rules-bot's fold: the reading-grade line replaced by a plan; rule 7, the old line: "0.9.5-a1: none new (reading, a1 c5531c8 against a6 8252786: no hunk touches `.dma_select`; his fix is 0.9.3d, in the Hypothesis)."): the author's 0.9.5-a1 built as the bench's option a1 (fork main c5531c8, fixtures/a1/MANIFEST.txt), T2X-S16ON8-A1, plan 1f4c4a00 `pass: 10` (81h written 02h reads 02h; every format plays on channel 1, the tone at 2000.0 Hz). Label (rule 7: the old, CANDIDATE_UCDD_SFX against the pinned C2): the fork line lacks the upstream fix: the author's 0.9.3d note (fork main 8252786, RELEASE-NOTES.md:136, quoted above); moved to B's backlog. Evidence: emulator (plans dc6405c7, 1f4c4a00), dynarec off.

### CAND-15 Tier 2, T2X-PROST: on the virtual SB Pro the data's first byte after the procedure's silent byte goes left, where the guide read literally and both emulators send it right: the channels swapped (found 26 Oct 2026, open; upstream candidate: fails on a1 too, 27 Oct)

Pinned: count-position 7994cd1 (C2 hash UCDD.EXE 03d92066, UCDDHOST.BIN 447ace33; the bench's fixtures/pinned/MANIFEST.txt). Bin: CANDIDATE_UCDD_SFX, FAIL 10/10 under C2, the same failing checks in every run (Tier 2; the template's 3/3 is the sweep's).
Cell: none (Tier 2: T2.EXE, real mode, no game), scope not applicable; every game that plays SB Pro stereo by the guide's procedure would have its channels the other way round from 86Box and DOSBox-X (not surveyed).
Affected: not known. Controls: C0 PASS 10/10 (T2C0-PROST, plan e555a482: 86Box's own SB Pro v2 sends the tone right, the left silent); C1 not applicable.
Observed: in all ten C2 runs (plan 04866e8f, folders 04866e8f-001 to -010): T2.TXT PASS (15 interrupts a step, the silent byte's interrupt, the reset answered AAh, none after), but the tone, written in each pair's first byte, comes out left: tonecheck `ST11+0.1-1.1 s R 2000 Hz: 0/1 windows (peak nan Hz, SNR -inf dB) FAIL; ST11+0.1-1.1 s L silence: RMS -24.6 dBFS FAIL` and the same at ST22, all ten runs. PROST2 under C2 (plan 716a3de7, EMU_DISPUTE, reported, not judged) has its three transfers left as well, where 86Box has them right (plan c81f7242). Expected: vsb-spec.md 7.4 as changed on 26 Oct 2026 (Michael, question 16): the guide read literally, the silent byte is the first digitized sound data byte and goes left, the data's first byte right (SBG:2394-2396, 1954-1960); both emulators (EMUSRC: 86Box src/sound/snd_sb_dsp.c at 6311adc, the toggle reset to the right at every DMA start; DOSBox-X src/hardware/sblaster.cpp at 97ff66a, the silent byte carried into the next transfer, remain_size). Grade emulator; hardware UNCONFIRMED (no SB Pro on the bench or the PC; an SB Pro 2 on Michael's missing-hardware list).
Also T2X-PROST-M (27 Oct 2026; plan 6615af3e, FAIL 10/10, the same checks in every run): with T1A's track 2 playing, the tone on the left in its band (-22.1 dBFS in ST11, -21.7 in ST22), the right's 2 kHz at -87 dBFS, the CD's 1 kHz on without a drop; T2.TXT PASS, as T2X-PROST's. C0 PASS 10/10 (T2C0-PROST-M, plan 9caca7c2).
Stall or guest (Michael, 26 Oct 2026: a Tier 2 FAIL on exact digital zero is judged by hand before it is a candidate; thresholds.toml [stall], STALLCAL; measured 27 Oct 2026 on every capture of the plan): guest. Plan 04866e8f: the right channel alone exact zero for 100 ms or more in all 10 captures while the left plays the tone (the recorder zeroes every channel); the runs of exact zeros on every channel (768 to 834 ms, one a capture) are none of the stall's shapes and fall outside the failing checks.
Trace: by reading, at the pinned SHA: the legacy commands take the mixer's stereo switch for output (src/audio/trap.asm 1316-1318) but play a transfer whose length word is 0, one byte, as mono (`test ax, ax` / `jz .legacy_mono`, 1327-1328), so the silent byte leaves nothing behind; each stereo transfer starts its frames at its own first byte, taken as left (frame shift 1, 1330). Minimal reproduction: `T2.EXE PROST` under C2 (matrix T2X-PROST), either step.
Hypothesis (labelled, not tested; mine): taking the one-byte transfer into the stereo stream when the switch is on, and keeping its byte's place for the next transfer as DOSBox-X does, would send the data's first byte right; whether a reset between transfers clears that, as DOSBox-X does and 86Box does not need to, is PROST2's open question. None of the author's release notes names the SB Pro's channel order (a1's RELEASE-NOTES.md read for "stereo", "left", "swap"); two older ones concern odd or short stereo transfers: RELEASE-NOTES.md:319 (Beta 0.9.1c), "Support combined SB Pro mixer writes and odd-length stereo transfers" (Battle Chess in SB Pro mode), and :359 (Beta 0.9.1), the "short stereo transfer used by Archimedean Dynasty during sound detection"; what they do with a one-byte transfer was not read. Evidence: emulator (plans e555a482 and 04866e8f), dynarec off. Hardware: UNCONFIRMED.
0.9.5-a1 (Michael, 27 Oct 2026, rules-bot's fold: the reading-grade line replaced by a plan; rule 7, the old line: "0.9.5-a1: none (reading, a1 c5531c8 against a6 8252786: no hunk touches the legacy commands' stereo)."): the author's 0.9.5-a1 built as the bench's option a1 (fork main c5531c8, fixtures/a1/MANIFEST.txt), T2X-PROST-A1, plan fc0a98b9 `fail: 10`, the same: T2.TXT PASS, the tone on the left (`ST11+0.1-1.1 s L silence: RMS -18.6 dBFS FAIL`, the same at ST22) and nothing on the right, all ten. Label (rule 7: the old, CANDIDATE_UCDD_SFX against the pinned C2): upstream candidate. Evidence: emulator (plans 04866e8f, fc0a98b9), dynarec off.
Firmware re-read (Michael, 28 Oct 2026: PROST's expected result against the CT1341's 3.02, grade [fw], cited by command and behaviour; rule 7: the row's text above unchanged, this added): silent. The 3.02 sends 14h's single byte, 1Ch's and 90h/91h's bytes from the DMA to its one DAC port the same way and keeps no channel state (FW302, vsb-spec 7.4); the left and right alternation is the CT1345 mixer's, undocumented. The expectation stands as vsb-spec 7.4 has it (emulation decides: the data's first byte right); the label stands; an SB Pro 2 decides when one is on hand.
Re-graded (Michael, 28 Oct 2026, from rules-bot; rule 7: the Expected line above, grade emulator, superseded and kept): data sheet, two manufacturers. The CT1345 sends the first byte after the switch left and its toggle persists (SBG:2393-2395, 2476-2478; the silent primer, SBG:1845-1854), so the application's first byte goes right; the ESS starts every transfer right (ES1868:2457-2459). Either way the data's first byte is the right channel, where the pinned build and a1 put it left: CAND-15 stands, stronger. The firmware re-read above (silent) stands beside it. Hardware: the PC's ES1868 in AKIT for the ESS's side; an SB Pro 2 is now low priority (vsb-spec 7.4).

### CAND-16 Tier 2, T2X-TIMERSTOP: with the timer stopped, CD audio drops out for 307 ms 1.73 s later, until IRQ 0 comes back: the CD queue is refilled only from the timer interrupt for a real-mode program (found 26 Oct 2026; the fork line lacks the upstream fix, B's backlog, 27 Oct; LACKS-FIX, 28 Oct)

Pinned: count-position 7994cd1 (C2 hash UCDD.EXE 03d92066, UCDDHOST.BIN 447ace33; the bench's fixtures/pinned/MANIFEST.txt). Bin: CANDIDATE_UCDD_AUDIO (the CD audio; CAND-6 the same), FAIL 10/10 under C2, the same failing check at the same place in every run (Tier 2; the template's 3/3 is the sweep's).
Cell: none (Tier 2: T2.EXE, real mode, no game), scope not applicable; every real-mode program that stops or slows PIT channel 0 for more than about 1.7 s while a CD track plays would lose the track's audio until its timer comes back (not surveyed; the author's notes name Future Dimension and Judge Dredd, RELEASE-NOTES.md:132).
Affected: not known. Controls: C0 PASS 10/10 (T2C0-TIMERSTOP, plan 8c669cc2: 86Box's own drive plays on through the stop, no gap, closing beep -0.000 s in 8, +0.010 and +0.020 s in one each); C1 not applicable.
Observed: in all ten C2 runs (plan 1279f08e, runs 1279f08e-001 to -010, recorded 26 Oct 11:33Z on the Logo=0 bench): T2.TXT PASS (channel 0 stopped for 36 ticks, 1977608 us on the TSC; 16015 interrupts of 16015 at 8000 Hz), the 1000 Hz tone in every phase's window (SNR 214 dB), but tonecheck `STOP+-0.5-2.5 s gaps of 20 ms or more: +1.73 s 307 ms ringing (the guest) FAIL` (and the same gap seen from RATE, `+-0.25 s` or `+-0.24 s`), all ten; the closing beep -0.000 s in nine, +0.010 s in one. The gap ends about 57 ms after channel 0 runs again. Expected: a drive plays its audio until its sectors are exhausted or a STOP, whatever the caller's interrupts do (MSC:1040-1042; HOSTCD M-12, 94-95, "a drive's audio does not depend on the game's interrupts"); the timer stopped by a control word and no count raises no interrupt (INTEL94:17304-17420). Grade emulator (the CD path under uCDD is uCDD's own, not 86Box's drive).
Observed, pin, protected mode (28 Oct 2026): T2X-W-TIMERSTOP (T2D4GW.EXE TIMERSTOP MIX under DOS/4GW, ring 3 under uCDD's host; the same phases, the CD's play and stop through INT 31h 0300h), plan bc67c0af `pass: 10` (runs bc67c0af-001 to -010): the 1000 Hz tone in every phase and no gap of 20 ms or more, the 36-tick STOP included, where the real-mode case loses 307 ms 1.73 s into it; 16015 interrupts of 16015 at 8 kHz; the closing beep +0.060 or +0.070 s, the guest's (no underrun; the BIOS count 63.5 to 64.2 ms behind the TSC, the trap cost of RATE's reflections and STOP's polling; tonecheck GUEST_LATE). C0 27da659d `pass: 10`; L4 2378bb31 `fail: 1` (T1AP). So the dropout is a real-mode program's, as the row's title says; why a protected-mode client's stop does not starve the queue is not traced.
Stall or guest (Michael, 26 Oct 2026: a Tier 2 FAIL on exact digital zero is judged by hand before it is a candidate; thresholds.toml [stall], STALLCAL; measured 27 Oct 2026 on every capture of the plan): guest. Plan 1279f08e: one run of exact zeros on every channel in each capture, 306 to 307 ms (15 buffers), the same within 1 ms in all ten, ringing into it (edge(): rings), no fade, not on the buffer edge; the closing beep -0.000 s; C0 plays through (8c669cc2).
Trace: by reading, at the pinned SHA: the refill runs inside the timer interrupt (src/audio/background.asm cd_timer, on INT 08h, 11-88; installed by resident_init.asm 146-159), 16 KB a pass, and only while the queue is under 448 KB of its 512 KB (44); the SB16 period handler marks a refill wanted (src/audio/sb16.asm 486-506, cd_refill_pending) but only the DPMI host acts on that, for its own client (background.asm 46-55, cd_deferred_refill 91 on); a real-mode program gets no refill without IRQ 0. Two seconds into the play the queue holds about 305 KB, 1.73 s of audio at 176400 bytes a second: the gap's place. Minimal reproduction: `T2.EXE TIMERSTOP 8000 MIX` under C2 (matrix T2X-TIMERSTOP).
Hypothesis (labelled, not tested; the author's): his 0.9.4-a3, RELEASE-NOTES.md:132, "Fill the CD-Audio queue from the Sound Blaster interrupt when a game stops the timer. This fixes the CD-Audio in Future Dimension and Judge Dredd"; merge-a6 keeps his timer refill with its entry from the audio IRQ (ISSUES.md UPA6, the merge table, background.asm row): built, not run, so whether merge-a6 passes TIMERSTOP is the harness's to say once the freeze allows. His 0.9.5-a1 changes it again (RELEASE-NOTES.md:12, "Fill the CD-Audio queue from the audio interrupt only when the timer stops or the queue is almost empty"). The older 0.9.3d note (RELEASE-NOTES.md:229, refills kept while games stop the BIOS timer, SuperKarts) is what the pinned build's deferred refill does for the host's own clients. Evidence: emulator (plans 8c669cc2 and 1279f08e), dynarec off; the planted T2L4-TIMERSTOP (T1AP, track 2 at 440 Hz) 5441bf40 `fail: 1`, `PLAY+0.5-1.5 s 1000 Hz: 0/1 windows (peak 440.0 Hz, SNR 217 dB) FAIL`. Hardware: not run.
0.9.5-a1 (Michael, 27 Oct 2026, rules-bot's fold: the reading-grade line replaced by a plan; rule 7, the old line: "0.9.5-a1: claimed by the note above (RELEASE-NOTES.md:12; not run)."): the author's 0.9.5-a1 built as the bench's option a1 (fork main c5531c8, fixtures/a1/MANIFEST.txt), T2X-TIMERSTOP-A1, plan e94f7425 `pass: 10` (channel 0 stopped 36 ticks; track 2's 1000 Hz through PLAY and STOP, no gap). Label (rule 7: the old, CANDIDATE_UCDD_AUDIO against the pinned C2): the fork line lacks the upstream fix: the author's 0.9.4-a3 note (RELEASE-NOTES.md:83 at c5531c8, quoted in the Hypothesis), changed again in 0.9.5-a1 (RELEASE-NOTES.md:12 at c5531c8); moved to B's backlog. Evidence: emulator (plans 8c669cc2, 1279f08e, e94f7425), dynarec off.

### CAND-17 Tier 2, T2X-DMAMCR: after an 8237 master clear and the channel set up again, the block interrupt comes at once, not after the rest of the interrupted block (found 27 Oct 2026, open; upstream candidate: fails on a1 too, 27 Oct)

Pinned: count-position 7994cd1 (C2 hash UCDD.EXE 03d92066, UCDDHOST.BIN 447ace33; the bench's fixtures/pinned/MANIFEST.txt). Bin: CANDIDATE_UCDD_SFX, FAIL 10/10 under C2, the same failing check in every run (Tier 2; the template's 3/3 is the sweep's).
Cell: none (Tier 2: T2.EXE, real mode, no game), scope not applicable; games that master-clear the 8237 during playback: the author names Assault Rigs, Oscar and The End of the World for the master clear (0.9.4-a3, merge-a6 RELEASE-NOTES.md:130), whether any of them depends on where the next interrupt comes is not known.
Affected: not known. Controls: C0 PASS 10/10 (T2C0-DMAMCR, plan 9b053b5b: 86Box's own card keeps the DSP's block, 2034 bytes left, due 92244 us, the interrupt 92194 to 92241 us after the set-up); C1 not applicable.
Observed: in all ten C2 runs (plan 22599c44, runs 22599c44-001 to -010; -007's first take, kept as .stall1, misread by tonecheck at midnight and taken again): half a block after a block interrupt the channel's count read 1998 to 2018 bytes left of the block, then the master clear (port 0Dh), 27 ticks with no interrupt (right), then the channel set up again: the first interrupt came 89 to 725 us after the unmask, against 90612 to 91519 us due. T2.TXT `FAIL DMAMCR ... 2011 bytes of the block left, due 91201 us after the set-up; the first interrupt came 176 us after it (within 2000); during the clear 0 interrupts (none) ...`. Expected: the first interrupt after the remainder of the interrupted block: the master clear is the DMA controller's ("the same effect as the hardware Reset ... the Mask register is set", 8237:485-491) and the block counter is the DSP's (SBG:1590-1591, 1652-1668, 3604-3612); Michael, 27 Oct 2026.
Stall or guest (Michael, 26 Oct 2026): not applicable: no silence judged; the failing check is the guest's own time of an interrupt.
Trace: by reading, in part, at the pinned SHA: the master clear marks the owned channel masked and keeps the output ring's channel unmasked (src/audio/trap.asm 612-631); the fork's note says the stream stops and resumes "as the controller would" (RELEASE-NOTES.md:47); where the block count stands at the resume is not traced. Every interrupt came within one output period (0.73 ms at 32 frames) of the unmask. DMAMC's MS phase under C2 (plan 98fb5e2c: 9 interrupts in 27 ticks in three runs, 8 on C0 in all ten) fits it. Minimal reproduction: T2X-DMAMCR.
Hypothesis (labelled, not tested; mine): the virtual DSP's bytes into its block are not kept across the clear, or the position is re-based to the new address so that a block end is crossed at the first output period; keeping the DSP's count of the block where the transfer stopped, and counting on from the set-up, would give the remainder.
0.9.5-a1 (Michael, 27 Oct 2026, rules-bot's fold: the reading-grade line replaced by a plan; rule 7, the old line: "0.9.5-a1: adds a starved state (sb_starved) cleared at each unmask of the owned channel (a1 c5531c8 against a6 8252786, src/audio/trap.asm); its release notes name no master clear change; whether it moves the first interrupt after a set-up is not read further (a1 read-only). Related: DMAMASK (a single mask, open). Evidence: emulator (plan 22599c44), dynarec off. Hardware: UNCONFIRMED (AKIT: the CT2290 confirms; 86Box can be as wrong here as uCDD, Michael 27 Oct 2026)."): the author's 0.9.5-a1 built as the bench's option a1 (fork main c5531c8, fixtures/a1/MANIFEST.txt), T2X-DMAMCR-A1, plan 6a3448dc `fail: 10`, the same: the first interrupt after the set-up 384 to 758 us after the unmask, against 92154 or 92879 us due, all ten; none during the clear. This answers the line to check below: a1 does not keep the DSP's block across a master clear. Label (rule 7: the old, CANDIDATE_UCDD_SFX against the pinned C2): upstream candidate. Evidence: emulator (plans 22599c44, 6a3448dc), dynarec off.

Line to check at the re-pin (Michael, 27 Oct 2026): the author's 0.9.5-a1, RELEASE-NOTES.md:15-17 (c5531c8): "Start a single-cycle block that is longer than the DMA count, as a real card does"; "Send the interrupt of a single-cycle block that starts a stream after one output period, not during the start command" (an interrupt one output period after a start is what C2 gave here, though this is auto-init after a set-up); "At the exact start of a new lap of an auto-initialize transfer, report the DMA count of the end of the previous lap". Whether a1 keeps the DSP's block across a master clear: DMAMCR on the re-pinned build says.

### CAND-18 Tier 2, T2X-DAC-M: direct DAC output (10h) paced from IRQ 0 at 8 kHz plays 2.4 to 3.0 % slow while uCDD plays a CD track (found 27 Oct 2026, open; bin pending the PC; upstream candidate: fails on a1 too, 27 Oct)

Pinned: count-position 7994cd1 (C2 hash UCDD.EXE 03d92066, UCDDHOST.BIN 447ace33; the bench's fixtures/pinned/MANIFEST.txt). Bin: pending, CANDIDATE_UCDD_SFX or EXPECTED_PERF by the PC (Michael, 26 Oct 2026, question 17: the 8 kHz DAC's trap cost; EXPECTED_PERF if the PC loses the time too); FAIL 10/10 under C2, the same failing check in every run.
Cell: none (Tier 2: T2.EXE, real mode, no game), scope not applicable; games that play digitised sound by direct DAC writes from a fast timer while a CD track plays (not surveyed).
Affected: not known. Controls: C0 PASS 10/10 (T2C0-DAC-M, plan 8f2bf0c3: the tone at 2002 Hz, ticks_lost -2.2 to -2.3 ms); without the CD, T2X-DAC on C2 (plan d376fe5b) plays 1983 Hz (0.95 % slow, inside tonecheck's 1.5 %), ticks_lost 16.7 to 17.4 ms over 77 ticks; C1 not applicable.
Observed: in all ten C2 runs (plan 98a5b358, runs 98a5b358-001 to -010): T2.TXT PASS (16015 bytes sent of 16015, none given up); the tone's peak 1942 to 1953 Hz against 2002.0 Hz due (`D8000+0.1-1.1 s 2001 Hz among others: 0/1 windows ... FAIL`, the band's peak not the neighbourhood's: tonecheck's band rule of bench 695ccc3); ticks_lost 58.2 to 59.4 ms over 117 BIOS ticks (the guest's count behind the TSC); the closing beep +0.060 or +0.070 s with a clean host record (no underrun: the guest's, question 21); the CD's 1 kHz on without a drop. Expected: the tone at a quarter of 8007.9 Hz, 2002.0 Hz (T2X-DAC's keys: SBG:3250-3261, the DAC fed at the program's rate).
Stall or guest (Michael, 26 Oct 2026): not applicable: no silence judged; the failing check is the tone's pitch, the guest's timing.
Trace: not read. Measured only: the guest's IRQ 0 at 8 kHz under uCDD with a CD track playing loses about three times the time it loses without the CD (ticks_lost 58 ms against 17 ms; the DAC's 2.0 s run 2.4 to 3.0 % long against 0.95 %).
Hypothesis (labelled, not tested; mine): every DSP port access traps (four a sample, 32000 a second, question 17), and with the CD stream running each trap or the IRQ 0 chain costs more in the host, so the guest's timer interrupts arrive late; the PC decides whether the time is uCDD's or the platform's (AKIT: T2X-DAC at 8 kHz, with the CD variant added 27 Oct 2026). Related: the band rule of 695ccc3 also moved T2X-SC8-M on C2 (a9b15826) from PASS to FAIL on S4's pitch (1965 Hz, 1.9 % low, with the CD; 1980 Hz without), the same family if the rule stands (STATE question 25).
Plain variant (Michael, 27 Oct 2026, question 26: the plain DAC's fail on C2 under the calibrated 0.5 % is this row's plain variant; rule 7, the old reading: T2X-DAC on C2, d376fe5b, PASS 10/10 at 1983 Hz inside the 1.5 %): T2X-DAC taken again, plan d376fe5b into d376fe5b-NNN.take2 (the first captures kept), `fail: 10`: the tone 1983.3 to 1984.7 Hz against 2002.0 Hz (0.9 % slow; `D8000+0.1-1.1 s 2001 Hz: 0/1 windows (peak 1984.0 Hz, SNR 58 dB) FAIL`), ticks_lost 16.4 to 17.3 ms over 77 ticks, the closing beep +0.020 s with a clean host record, T2.TXT PASS. Evidence: emulator (plan d376fe5b), dynarec off.
Plain variant under question 31 (Michael, 28 Oct 2026: a late closing beep judged when the host record is clean and the TSC log agrees): T2X-DAC taken a third time (plan d376fe5b, the takes kept as .take2 and .take3; 28 Oct 04:35Z), `fail: 10` at 1983.4 to 1984.4 Hz as on 27 Oct; the closing beep +0.020 s, the guest's in all ten (no underrun; ticks_lost 16.8 to 17.3 ms, all of it in the 2.0 s DAC phase: 16015 bytes over 2.017 s, 0.85 % slow, the pitch measured).
0.9.5-a1 (Michael, 27 Oct 2026, rules-bot's fold: each candidate's C2 case on a1, 10 runs; this row had no a1 line): the author's 0.9.5-a1 built as the bench's option a1 (fork main c5531c8, fixtures/a1/MANIFEST.txt). With the CD, T2X-DAC-M-A1, plan 8e4b82b8 `fail: 10`, further off than the pin: the tone 1910 to 1913 Hz (4.4 to 4.6 % slow; measured by hand on -001 and -005, tonecheck `D8000+0.1-1.1 s 2001 Hz among others: 0/1 windows (SNR 24 to 29 dB, -34.5 dBFS) FAIL`), ticks_lost 101.5 to 103.9 ms over 117 ticks, the closing beep +0.100 or +0.110 s with a clean host record, T2.TXT PASS (status reads that found the DSP busy 4575). Without the CD, T2X-DAC-A1, plan 563f449b `fail: 10`: the tone 1946.5 to 1947.6 Hz (2.7 % slow), ticks_lost 55.4 to 56.2 ms over 77 ticks, the closing beep +0.050 or +0.060 s, clean record. Label: upstream candidate, both variants; on a1 the guest's IRQ 0 loses about three times the pin's time. The bin stays pending the PC (question 17). Evidence: emulator (plans 98a5b358, d376fe5b, 8e4b82b8, 563f449b), dynarec off.

### CAND-19 Tier 2, T2X-SC8-M: 8-bit single-cycle blocks of 256 bytes at 22050 Hz play 1.9 % low, with sidebands near +-40 Hz, while uCDD plays a CD track (found 27 Oct 2026; FORK-REGRESSION, B's backlog, 28 Oct (rule 7: was "the fork line lacks the upstream fix, B's backlog, 27 Oct"; no note of the author's names it, so a1 is read as never having had it; bisected over the fork's own commits when B unfreezes))

Pinned: count-position 7994cd1 (C2 hash UCDD.EXE 03d92066, UCDDHOST.BIN 447ace33; the bench's fixtures/pinned/MANIFEST.txt). Bin: CANDIDATE_UCDD_SFX, FAIL 10/10 under C2, the same failing check in every run (Michael, 27 Oct 2026, question 25: its own row and candidate).
Cell: none (Tier 2: T2.EXE, real mode, no game), scope not applicable; games that play short single-cycle blocks (14h) at 22 kHz under a CD track (not surveyed).
Affected: not known. Controls: C0 S4 at 1997 to 1999 Hz with and without the CD (T2C0-SC8-M 374e7ae5 and T2C0-SC8 2c278c7c PASS 10/10; sidebands near +-40 Hz 24 to 26 dB down without the CD, 54 to 56 with it); C1 not applicable.
Observed: S4 (14h single-cycle, 256-byte blocks at 22050 Hz by 41h, each block sent at the last one's interrupt): plain C2 (T2X-SC8, plan 9646a9cc, PASS 10/10) peaks at 1978 to 1980 Hz (1.2 % low, inside tonecheck's 1.5 %), its strongest sideband near +-40 Hz 12 to 16 dB down; with T1A's track 2 playing (T2X-SC8-M, plan a9b15826, taken again 27 Oct 2026 under the band rule of bench 695ccc3: FAIL 10/10, `S4+0.1-1.1 s 2000 Hz among others: 0/1 windows ... FAIL`, every other step and the CD's 1 kHz passing) 1965 to 1966 Hz (1.9 % low), the strongest sideband 9 to 12 dB down. Expected: the tone at 2003.0 Hz on the virtual SB16 (SC8 sets the rate by 41h, SBG:3570-3577, not a time constant; the DSP 4.13's rate register, VSB:290-304: 22050 asked plays 22083.5 Hz) and 2000.0 Hz on 86Box's own card. The plan's first ten captures (PASS under the earlier band rule) were overwritten by the retake (plan_run's recordings go to the plan-id folders); their S4 figures are in bench 695ccc3's message (1965 Hz, sidebands near +-40 Hz).
Stall or guest (Michael, 26 Oct 2026): not applicable: no silence judged; the failing check is the tone's pitch.
Trace: not read.
Hypothesis (labelled, not tested; mine): each 256-byte block (11.6 ms at 22050 Hz) restarts at its interrupt, and the time from the block's end to the next block's first sample comes out of the stream, more of it while the CD stream also runs: the tone stretched (lower) and chopped at the block rate (the sidebands). Related, not the same row (Michael): CAND-18, the 8 kHz direct DAC slowed under the CD.
Plain variant (Michael, 27 Oct 2026, question 26: the plain SC8's fail on C2 under the calibrated 0.5 % is this row's plain variant; rule 7, the old reading above: "plain C2 (T2X-SC8, plan 9646a9cc, PASS 10/10) peaks at 1978 to 1980 Hz (1.2 % low, inside tonecheck's 1.5 %)"): T2X-SC8 taken again, plan 9646a9cc into 9646a9cc-NNN.take2 (the first captures kept), `fail: 10`: S4 at 1977.0 to 1977.5 Hz against 2003.0 Hz due (1.3 % low; `S4+0.1-1.1 s 2000 Hz: 0/1 windows (peak 1977.1 Hz, ...) FAIL`), every other step passing. Evidence: emulator (plan 9646a9cc), dynarec off.
0.9.5-a1 (Michael, 27 Oct 2026, rules-bot's fold: each candidate's C2 case on a1, 10 runs; this row had no a1 line): the author's 0.9.5-a1 built as the bench's option a1 (fork main c5531c8, fixtures/a1/MANIFEST.txt). With the CD, T2X-SC8-M-A1, plan 7ee92532 `pass: 10`; without it, T2X-SC8-A1, plan 5efe322c `pass: 10`: S4 at 2000.0 to 2000.1 Hz, every step's interrupts as asked. Label (rule 7: the old, CANDIDATE_UCDD_SFX against the pinned C2): the fork line lacks the upstream fix; no note of the author's names short single-cycle blocks' pitch (a1 plays 41h's rate as asked, the item on B's list, which alone would give 2000.0 Hz against the pin's 2003.0, not 1.3 to 1.9 % low); which change moves it is not read. Moved to B's backlog. Evidence: emulator (plans a9b15826, 9646a9cc, 7ee92532, 5efe322c), dynarec off.

### CAND-20 Tier 2, T2X-DMAMASK: while the 8237 channel is masked during auto-init the virtual transfer runs on: the count moves and, at the unmask, the block interrupt comes at once, not after the rest of the interrupted block (found 27 Oct 2026, open; the notes' DMAMASK of 23 Oct, its symptom; upstream candidate: fails on a1 too, 28 Oct; pin and a1 sections)

Pinned: count-position 7994cd1 (C2 hash UCDD.EXE 03d92066, UCDDHOST.BIN 447ace33; the bench's fixtures/pinned/MANIFEST.txt). Bin: CANDIDATE_UCDD_SFX, FAIL 10/10 under C2, the same failing checks in every run (Tier 2; the template's 3/3 is the sweep's).
Cell: none (Tier 2: T2.EXE, real mode, no game), scope not applicable; games that mask the sound channel during playback (to pause, or around a buffer refill) are not known; the census can look for writes to 0Ah (04h-07h), 0Fh and 0Eh during a transfer.
Affected: not known. Controls: C0 PASS 10/10 (T2C0-DMAMASK, plan d34e05da: 86Box's own card, the count 17F1h before and after the hold in all ten, 2034 bytes left, due 92244 us, the interrupt 92201 to 92202 us after the unmask); C1 not applicable.
Related: DMAMASK (23 Oct 2026, SBT16's M case: through uCDD the interrupt after an unmask came mid-block and at no fixed time); CAND-17 (the same remainder after a master clear and a set-up).
Structure (Michael, 28 Oct 2026, question 28): pin and a1 sections, one expectation and citation, the upstream report from the a1 section.
Expected: a mask bit "can be set to disable the incoming DREQ" (8237:421-427), so while the channel is masked nothing is transferred: the count stands (8237:225-230, read twice) and the DSP, waiting for its bytes, gives no block interrupt (SBG:1590-1591, the interrupt after the programmed number of bytes) and no sound; "Clear Mask Register ... enabling them to accept DMA requests" (8237:493-495), so the transfer goes on from where it stood and the block that was playing ends after its remainder: within 2.00 ms of the remainder at 22050 bytes a second (DMAMCR's window: the CT2290's FIFO of 16 samples, one output period at 32 frames, the count read). The C0 behaviour.
Observed, pin: T2X-DMAMASK, plan 3b9b90c9 `fail: 10` (runs 3b9b90c9-001 to -010): half a block into a block, Write All Mask Register Bits (port 0Fh); 27 ticks with no interrupt (right) and quiet (tonecheck PASS in all ten: MK silence -240.0 dBFS, the tone in MP and MU at its pitch, no gap); but the count read once masked and again before the unmask moved, 17D6h to 17E1h then 1B7Dh to 1B88h (in -001, 17DAh to 1B83h: 7255 bytes past whole laps of the 8 KB buffer; with three laps 31831 bytes, about the 32700 that 1.48 s carries at 22050 bytes a second: the transfer ran on at its rate through the hold); after Clear Mask Register (0Eh) the first interrupt came 167 to 708 us after it, against 133424 to 133922 us due for the remainder computed from the second count. T2.TXT, 3b9b90c9-001: `FAIL DMAMASK auto-init 8-bit at 22050 Hz, 4 KB blocks: playing, 7 interrupts in 27 ticks (7 or 8 blocks, within 2); masked (port 0Fh, all four), 0 interrupts (none), the count 17DAh then 1B83h (unchanged); unmasked (port 0Eh), 2940 bytes of the block left, due 133696 us; the first interrupt came 230 us after it (within 2000); then 8 interrupts in 27 ticks (within 2)`. Underruns: none in a case (22 captures with a host record).
Stall or guest (Michael, 26 Oct 2026): not applicable: no silence failed; the failing checks are the guest's own reading of the count and the time of an interrupt.
L4 (the checks fail on a known-bad input, on C0 where they pass): T2L4-DMAMASK, plan 871d558f `fail: 1` (the mask left out: 8 interrupts in the hold, the count 17F1h then 1BDDh, tonecheck MK -18.7 dBFS FAIL); T2L4-DMAMASK-T, plan 81ad7f7c `fail: 1` (the DSP's block started again at the unmask: the interrupt 185762 us after it against 92244 due; the hold and tonecheck pass).
Trace: by reading, in part, at the pinned SHA: the all-mask write sets the owned channel's virtual mask bit and keeps the output ring's channel unmasked (src/audio/trap.asm 632-675); while the virtual mask is set the mixer sums silence in place of the game's sample (src/audio/mix.asm 473-477: `cmp byte [si+DMA_MASK], 0` / `mov si, 0` / `jne .sum`) but goes on advancing the stream's frame, from which the count and the block ends are worked out (the 23 Oct guess: game_elapsed, nothing re-based at the unmask as .resume does after D4h); where the interrupt is held back during the mask was not traced. Every interrupt came within one output period (0.73 ms) of the unmask: the block end was crossed during the hold. Minimal reproduction: `T2.EXE DMAMASK` under C2 (matrix T2X-DMAMASK).
Observed, pin, protected mode (28 Oct 2026): T2X-W-DMA (T2D4GW.EXE DMA under DOS/4GW, ring 3 under uCDD's host; the same mask half a block in, port 0Fh, inside DMAREAD's and DMAMC's phases), plan e77493eb `fail: 10` (runs e77493eb-001 to -010), the same failure: MK 0 interrupts and quiet (tonecheck PASS in all ten), the count 17F6h to 17FAh then 1B6Ah to 1B78h across the hold; every other check passing in all ten (DR 7 interrupts, 1728 readings inside the buffer, none torn; MU 9; MC 0 and quiet; MS 9). So the virtual transfer runs on under a mask written from protected mode as from real mode: the mask's path does not depend on the client's mode. C0 control T2C0-W-DMA, plan c14ca056 `pass: 10`; L4 T2L4-W-DMA, plan d716334f-001 `fail` (the mask unwritten: the count 17FFh then 1BCDh, 8 interrupts, MK -18.7 dBFS; its first capture HARNESS_ERROR, the closing beep +0.100 s, kept as .stall1). T2W has no TSC, so the unmask window is DMAMASK's alone.
Observed, pin, PMODE/W (28 Oct 2026): T2X-WP-DMA (the same program bound with PMODE/W v1.33, T2PMW.EXE, uCDD's ring-3 DPMI client), plan 0b94fe39 `fail: 10` (runs 0b94fe39-051 to -060), the same failure: MK 0 interrupts and quiet, the count 17F7h to 17F9h then 1B6Ch to 1B7Ah; every other check passing. C0 control T2C0-WP-DMA (37775321) `pass: 10`; L4 T2L4-WP-DMA (ae71f6fe) `fail`. Two extenders, one result: the mask's path does not depend on the client.
Hypothesis, pin (labelled, not tested; mine): treat a masked owned channel as the DSP starved: hold the stream's frame (as D4h's pause does) while the mask is set and count on from the unmask, so the count stands and the block's remainder is kept. The fork's 0.9.5-a1 reading (CAND-17's line): a1 adds a starved state (sb_starved) cleared at each unmask of the owned channel.
Observed, a1: T2X-DMAMASK-A1, plan f8c012c0 `fail: 10` (runs f8c012c0-001 to -010), the same failure: 0 interrupts and quiet in the hold (tonecheck PASS in all ten, the tone at 1999.9 Hz: a1 plays 41h's rate as asked), the count moving across it, 17EFh (17FFh in -002) then 1BCFh or 1BDFh, and the first interrupt 203 to 751 us after the unmask against 137142 to 137868 us due. T2.TXT, f8c012c0-001: `FAIL DMAMASK ... masked (port 0Fh, all four), 0 interrupts (none), the count 17EFh then 1BDFh (unchanged); unmasked (port 0Eh), 3040 bytes of the block left, due 137868 us; the first interrupt came 410 us after it (within 2000); then 8 interrupts in 27 ticks (within 2)`. Underruns: none in a case.
Hypothesis, a1 (labelled, not tested; by reading): the same mechanism as the pin's: a1's mixer sums silence while the owned channel is masked and advances the frame (src/audio/mix.asm 432-437 at c5531c8, the pin's lines); its starved state (sb_starved) is set only for a single-cycle block longer than the DMA count (trap.asm:1391) and cleared at an unmask, so a mask during auto-init does not hold the stream. The upstream report: the case, its T2.TXT line, the two counts and this reading. Label: upstream candidate (8237:421-427, 493-495).
Evidence: emulator (plans d34e05da, 3b9b90c9, 871d558f, 81ad7f7c, f8c012c0; protected mode c14ca056, e77493eb, d716334f), dynarec off; the mechanism by reading, in part. Hardware: UNCONFIRMED (AKIT: the CT2290 confirms the remainder; 86Box can be as wrong here as uCDD, as for CAND-17).

### FLAKY-1 Tier 2, T2X-PICHOLD and T2X-PICHOLD12: 2 of 10 and 1 of 10 runs under C2 lose 20 ms of the 2 kHz tone in silence of the recorder stall's shape (filed 27 Oct 2026, closed the same day: recorder insertions)

Pinned: count-position 7994cd1 (C2 hash UCDD.EXE 03d92066, UCDDHOST.BIN 447ace33). Bin: FLAKY (Michael, 27 Oct 2026; project_a.md has no FLAKY bin: as on 25 Oct, "9/10 is FAIL with the count" carries it), until the host's record can be cited.
Rule (Michael, 27 Oct 2026): the capture's shape cannot tell a recorder stall from a refill uCDD missed inside one 86Box buffer period, so under C2 a "stall" is a FAIL unless the recorder's host-side record shows a stall at the same instant. Runs before 27 Oct have no such record; the record exists from bench 565a960 (runs/rec/alrec.c, alrec.txt beside each sound.wav).
Rate: T2X-PICHOLD (IRQ 4) plan 7211c04e reverts to 8 of 10: -006 and -009's first captures FAIL (their retakes' passes do not count); T2X-PICHOLD12 (IRQ 12) plan 7ae43d11: 9 of 10, -003's first take FAIL (the same rule, applied the same way; Michael named 7211c04e). Over PICHOLD's 20 C2 runs, 3 (15 %). C0 (27312daa, 1985f3dc): 0 of 20.
Observed: each a band drop of the 2 kHz tone read 20 or 21 ms, 896 exact zeros (18.67 ms) on every channel after a straight fade, ending on 86Box's 20 ms buffer edge; the closing beep +0.020 s in each. tonecheck now: `FAIL PICHOLD tonecheck: a band drop holding silence of the recorder stall's shape MIX+11.666 s 2000 Hz 20 ms, and no host record for the run: under C2 a FAIL (Michael, 27 Oct 2026)` (and +11.016 s, +0.916 s).
The six C2 recorder faults since the Logo=0 bench (runs/stalls.py; case, run, position, hold at that moment):
- T1-PLAY23, ccb39d17-410 (first capture, kept as .stall1): the capture broken, the closing beep +0.060 s; no silence, so no position in the capture (the break shows only at the closing beep, between PLAY and END); T1.EXE holds no interrupt. Still HARNESS_ERROR: a closing beep out of place is the recorder's clock, not a silence's shape (my reading of the rule; asked in STATE).
- T1-PLAY23, ccb39d17-403: 18.67 ms at PLAY+6.666 s (1.67 s after the track 2/3 boundary); no hold. Under the gap rule's 20 ms: PASS stands.
- T1-PLAY23, ccb39d17-405: 18.67 ms at PLAY+5.186 s (0.19 s after the track 2/3 boundary); no hold. PASS stands, as -403.
- T2X-PICHOLD, 7211c04e-006 (first capture): MIX+11.666 s, FREE+0.681 s: no hold active (the last ended about 725 ms before). FAIL.
- T2X-PICHOLD, 7211c04e-009 (first capture): MIX+11.016 s, FREE+0.031 s: no hold active (the last ended about 75 ms before). FAIL.
- T2X-PICHOLD12, 7ae43d11-003 (first take, .stall1): MIX+0.916 s, 73 ms before HOLD: no hold yet. FAIL.
None fell while a line was held.
Related (Michael, 26 Oct 2026): the author's 0.9.4-a2, RELEASE-NOTES.md:158, the 128-frame period against a mouse driver holding its interrupt for several milliseconds; 0.9.4-a6, RELEASE-NOTES.md:98, three output periods in the ring against a mouse driver keeping interrupts off longer than one period (the F2 ring row: the sound during a hold is not fixed by the ring).
Next: PICHOLD and PICHOLD12 under C2 again with alrec.txt (bench 565a960 on), so a stall can be read against the host's record. Evidence: emulator (plans 7211c04e, 7ae43d11), dynarec off. Hardware: UNCONFIRMED.

Closed (Michael, 27 Oct 2026): a missed refill cannot move the closing beep; only samples the recorder adds can. A silence whose buffer-rounded length equals the closing beep's lateness is the recorder's insertion (HARNESS_ERROR); with the beep on time it is the guest's (FAIL). All six faults above are insertions: -403, -405, 7211c04e-006, -009 and 7ae43d11-003 each 18.67 ms of silence, 20 ms in whole buffers, the closing beep +0.020 s; ccb39d17-410 +0.060 s with no silence (buffers played again). tonecheck now (bench c426591): `HARNESS_ERROR PICHOLD tonecheck: recorder insertion, not judged: silence at 24.52 s, 18.67 ms (20 ms in whole buffers), the closing beep +0.020 s late (no host record)`. So PICHOLD (7211c04e) and PICHOLD12 (7ae43d11) return to their clean re-run results, 10 of 10 each, the re-takes standing; the C2 rule this row was filed under is retired (STALLCAL, rule 7 form).

### 86CUE2048: 86Box misreads a CUE sheet whose data track has 2048-byte sectors (an emulator limitation; found 25 Oct 2026)

- Seen [86Box] while setting Project A's C0 control for gate A2 (OAKCDROM
  and MSCDEX 2.25 on 86Box's own ATAPI drive, development run t1dev-c0,
  not recorded; 86Box 6.0 build 9001, dynarec off). On T1A
  (fixtures/synth: TRACK 01 MODE1/2048, 538 sectors, then five AUDIO
  tracks, track 6 behind PREGAP 00:02:00) the lead-out comes out at
  02:10:18 (Audio Disk Info) and the volume size 9618, where the sheet
  gives 02:11:13 and 9688: the BIN's 22269824 bytes taken as 2352-byte
  sectors (9468) plus the 150-sector gap. The track starts (Audio Track
  Info) are right. On T1B, the same disc with the data track MODE1/2352,
  86Box reads 02:11:13 and 9688.
- Also, on both discs: a cooked READ LONG across the end of the data track
  into the first audio sector returns no error (status 0100h), where the
  pinned build answers 8108h with nothing written past the end. A real
  drive refuses a cooked read of an audio sector; 86Box's drive is no
  reference for it.
- Rule (Michael, 25 Oct 2026): T1A stays the C2 disc (uCDD reads the sheet
  as written); T1B is the C0 control disc; any C0 result on a CUE with a
  2048-byte data track is not a control until the second emulator agrees
  (tightening r3, T6).
- Not ours to fix (86Box's CUE loader); nothing in uCDD changes. Evidence:
  emulator (development runs t1dev-c0 and t1dev-c0b, 25 Oct). Hardware:
  not applicable.

### 86SMM: 86Box's 8259 has no special mask mode outside the IBM 5140 (an emulator limitation; found 26 Oct 2026)

- Seen [86Box] writing Project A's T2X-PICSMM (gate A3), development run
  t2dev-c0p (not recorded; 86Box 6.0 build 9001, dynarec off): on C0, with
  IRQ 0 in service, IRQ 0 masked and OCW3 68h written (special mask mode),
  F2h's interrupt on IRQ 5 does not come until IRQ 0 is ended. The 8259A:
  "In the special Mask Mode, when a mask bit is set in OCW1, it inhibits
  further interrupts at that level and enables interrupts from all other
  levels (lower as well as higher) that are not masked" (8259:669-673). The
  first phase (the fully nested mode, 8259:615-617) behaves.
- 86Box's source (src/pic.c, master, read 26 Oct 2026): OCW3 bits 6:5 set
  `special_mask_mode`, and a non-specific EOI skips a masked in-service
  level; but `find_best_interrupt()` lets a masked in-service level stop
  blocking lower ones only when the board is the IBM 5140 (`PIC_IBM5140`);
  on every other board an in-service level blocks every lower request.
- So on this bench C0 cannot validate T2.EXE PICSMM's second phase, and a
  C2 result cannot be told from the emulator's: under C2 the case gave the
  same 0 (the driver also drops OCW3 68h, irq.asm:456-466: its comment,
  450-454, keeps special mask mode for the physical controller, which
  serves the mixer). Nothing in uCDD changes. Evidence: emulator (the
  development run) and 86Box's source. Hardware: not run.
- The second emulator has it (read 26 Oct 2026): DOSBox-X 2025.02.01, the
  build T6 installed, src/hardware/pic.cpp: OCW3 bit 6 with bit 5 sets
  `special` (write_command), and `PIC_Controller::check_for_irq()` and
  `PIC_runIRQs()` scan to level 8 instead of stopping at the highest level
  in service when it is set (`special?8:active_irq`), so a lower request
  comes while a higher level is in service; its rule is wider than the
  document's (any unmasked level not in service, not only beside a masked
  one), the same for PICSMM2. Michael's decision (26 Oct 2026, question
  12): PICSMM split; PICSMM1 (the fully nested mode) runs on the bench;
  PICSMM2's control is DOSBox-X's path (EMUSRC, grade emulator), read, not
  run (T6 wires no runner); the CT2290 in AKIT judges, and the case is on
  the AKIT list (STATE).

### 86DMAPAGE: 86Box's own 8-bit DMA crosses the 64 KB page in this build; DOSBox-X wraps (an emulator disagreement; found 26 Oct 2026)

- Seen [86Box] writing Project A's T2.EXE SC8 (gate A3), development runs
  t2dev-sc8c0 and t2dev-page (not recorded; 86Box 6.0 build 9001, dynarec
  off), C0 (86Box's own SB16 and 8237, no uCDD): a 4096-byte 14h block
  programmed at F800h in a page (channel 1, mode 49h, the page register
  set once) plays its first 2048 bytes and then the bytes beyond the page
  (silence there: a gap of 186 ms a block at 11025 Hz, 93 at 22050, edges
  ringing; RMS -19 dBFS in the first half, -37 dBFS in the second, where
  the page's start held a 1378 Hz square), and its interrupt comes each
  block. The channel's current address reads back 0000h straight after
  F800h was written, and 1000h after the block.
- The 8237A: the current address register is 16 bits and the page lies
  outside it (8237:331-338); a transfer cannot straddle a page and wraps in
  it (SBG:1285-1294). 86Box's own source at master (src/dma.c,
  dma_channel_read_legacy and dma_advance_n, read 26 Oct 2026) masks an
  8-bit channel's address to 16 bits and keeps the page: it should wrap,
  so this build and that source disagree; not traced further.
- The second emulator wraps (read 26 Oct 2026): DOSBox-X 2025.02.01,
  src/hardware/dma.cpp, DmaChannel::Read masks the current address with
  `dma_wrapping` (0xffff by default) before and after each advance and
  never moves the page base; ports 0-7 read the current address back.
- A verdict 86Box and the second emulator disagree on is a finding, not a
  choice (the bench's CLAUDE.md): C0 cannot validate T2.EXE SC8PAGE's wrap. The
  page-crossing steps were taken out of SC8 into SC8PAGE, held on STATE
  question 13. Under C2 the same block's interrupt never came (0 blocks,
  the address left at F800h; development run t2dev-sc8c2, not recorded).
  Nothing in uCDD changes. Evidence: emulator (the development runs) and
  both emulators' sources. Hardware: not run.
- Michael's ruling (26 Oct 2026, question 13): this 86Box build (6.0, build
  9001) differs from its own master source, which wraps: a build-specific
  regression of 86Box's, recorded as such. (Mine, not the ruling: a later
  86Box build could be checked with T2C0-SC8PAGE2 before its C0 counts for
  the wrap.) SC8PAGE split:
  SC8PAGE1 (the crossing block's interrupt) on the bench, C0 10/10 (plan
  5fb0d861), C2 0/10 (plan 49b66842, CAND-9); SC8PAGE2 (the wrap) decides
  8237:331-338, grade data sheet, DOSBox-X's dma.cpp corroborating, judged
  on the CT2290 in AKIT (STATE's AKIT list).

### 86ODDSC: 86Box's own SB16 gives no interrupt for a 16-bit stereo single-cycle block of an odd count of samples; DOSBox-X carries the odd sample (an emulator disagreement; found 26 Oct 2026; uCDD's own behaviour is CAND-13)

- Seen [86Box] writing Project A's T2.EXE S16ODD (gate A3), development
  run t2dev-odd2c0 (not recorded; 86Box 6.0 build 9001, dynarec off), C0
  (86Box's own SB16 and 8237, no uCDD): B0h, mode 30h or 20h, length
  1138h (4409 samples), the 16-bit channel programmed for exactly the
  block's 4409 words: no interrupt within the block's length and 200 ms,
  at 22050 and 44100 Hz (`SS22: 0 blocks, 0 interrupts, a block's
  interrupt never came`).
- 86Box's own source at master (src/sound/snd_sb_dsp.c at 6311adc,
  sb_poll_o, read 26 Oct 2026) reads two words for each stereo frame and
  counts the length down by 2, interrupting below 0: the block's last
  frame wants a word past the channel's count, the channel (single mode)
  has masked itself at its terminal count, the read returns no data and
  the count never goes below 0. Auto-init plays on (whole frames, one
  sample over a block): T2C0-S16ODD1 PASS 10/10, plan 2224f8c2.
- The second emulator reads exactly the programmed count and keeps the odd
  last sample for the next transfer, paired with its first (DOSBox-X
  src/hardware/sblaster.cpp at 97ff66a, SB_INFO::GenerateDMASound,
  `remain_size`): an interrupt each block, the frames still paired.
- The guide is silent (SBG:3864). A verdict 86Box and the second emulator
  disagree on is a finding, not a choice: C0 cannot validate T2.EXE
  S16ODD2. Nothing in uCDD changes for this row. Evidence: emulator (the
  development runs) and both emulators' sources. Hardware: not run.
- Michael's ruling (26 Oct 2026, question 14): DOSBox-X the control at T6,
  the CT2290 in AKIT the judge, the case on the AKIT list; this row stays
  the emulator's. What uCDD does under C2 is its own and deterministic, a
  candidate row of its own: CAND-13 (every other block starts on the right
  channel, plan a0c1f221, 10/10).

### 86THRE: 86Box's 16550 raises the transmit-empty interrupt a second time when the shift register empties (an emulator difference; found 26 Oct 2026)

- Seen [86Box] in Project A's T2X-PICHOLD and T2C0-PICHOLD (gate A3; plans
  27312daa, 7211c04e and the development runs t2dev-ph0, t2dev-ph2, 86Box
  6.0 build 9001, dynarec off): one byte to COM1's THR (FIFO off,
  transmit-empty interrupt on) every 50 ms gives two interrupts on IRQ 4,
  one held by the case and one after its EOI; 201 not asked for in 200
  bytes (one at IER's write). Reported, not judged.
- The data sheet (the 82091AA's serial port, 16550 compatible,
  INTEL96:65815): THRE "is set to 1 when a character is transferred from
  the Transmitter Holding Register into the Transmitter Shift Register.
  THRE is set to 0 when the CPU loads the Transmitter Holding Register"
  (71246-71253); the interrupt is reset by "Reading the IIR Register (if
  Source of Interrupt) or Writing the Transmitter Holding Register"
  (70891-70895). One interrupt a character, when it moves on; nothing when
  the shift register empties. Whether enabling THREIE with THRE set raises
  one: silent (70787-70789). The library's SIO key names the 82378
  PCI-ISA bridge, which has no UART.
- 86Box's source (src/device/serial.c, master, read 27 Oct 2026): in
  non-FIFO mode serial_move_to_txsr() calls serial_xmit_d_empty_evt(),
  which sets THRE and the transmit interrupt (the data sheet's), and
  serial_process_txsr() calls it again once the byte is shifted out, with
  the THR still empty, so the interrupt comes again (not the data
  sheet's); its IER write (case 1) raises it when THREIE is set with THRE
  set (the one at IER's write).
- So: the second interrupt a byte is 86Box's. It costs the case one short
  extra interrupt on IRQ 4 after each hold and changes no verdict; the PC's
  line is IRQ 12 (its serial ports off: T2X-PICHOLD12). Nothing in uCDD.
  Evidence: data sheet and 86Box's source; emulator (the runs).

### IOSYS08: MS-DOS 7.1's IO.SYS holds IRQ 0 in service for up to 8 ms every other BIOS tick (a bench and PC finding, not uCDD's; found 26 Oct 2026; closed the same day: MSDOS.SYS [Options] Logo=0)

- Seen [86Box] chasing Project A's T2X-DAC (gate A3): with PIT channel 0
  reprogrammed (T2.EXE DAC, variant A: 8 kHz, an ISR that counts and
  passes the BIOS tick on, no sound), the guest's TSC shows 18 gaps over
  1 ms in 2 s, every 880th interrupt (two BIOS ticks), 3.5 to 8 ms long,
  and the capture's closing beep comes 70 to 90 ms late: the interrupts
  in a gap are lost, and the BIOS time counted from them falls behind.
  86Box 6.0 build 9001, machine p55t2p4 (ASUS P/I-P55T2P4, 430HX, Award
  4.51PG), Pentium MMX 233, development runs t2dev-csipA1 to -A4,
  t2dev-bare1 to -3, t2dev-stk0, t2dev-bios8, dynarec off (not recorded).
- The holder, by its own timing: T2.EXE's ISR calls the IRQ 0 handler it
  replaced (`pushf` / `call far`) and times it on the TSC: 37 calls, 18 or
  19 over 1 ms, the longest matching the longest gap (7.9 ms against 8.0
  ms, t2dev-csipA3). The interrupted CS:IP names nothing: always the test's
  own HLT (JEMMEX's HLT stub at C800:0016, 16014 of 16015 interrupts; on
  the bare boot T2.EXE's own loop).
- The boot bisection: bare (an empty CONFIG.SYS, no JEMMEX): the holds
  stay (three runs: longest 3.8, 6.0, 6.5 ms, +80, +70, +90 ms); with
  STACKS=0,0 too: the replaced handler is IO.SYS's own at 0070:02DE, still
  18 long calls (3.8 ms); chained straight to the BIOS's INT 08h entry
  (F000:FEA5, past IO.SYS): no gap over 1 ms (the longest interval 116 us),
  the closing beep -0.000 s. JEMMEX and DOS's STACKS stub only make the
  holds longer (up to 8 ms under JEMMEX, V86 costs).
- What it does, by reading its first bytes (0070:02DE, disassembled): it
  reads the BIOS tick count (0040:006C) and on even ticks re-enables
  interrupts (STI) and, while a flag of its own (0070:02D8) is set, polls
  the VGA input status port 3DAh for vertical retrace (bit 3), patching
  itself out if the wait never ends; all before the BIOS's INT 08h sends
  the EOI, so IRQ 0 stays in service at the 8259 and faster IRQ 0s are
  lost. The PC boots the same IO.SYS (Windows 98 SE, MS-DOS 7.1), so it
  may well do the same there: Project A's hardware kit carries variant A as
  the discriminator (STATE's AKIT list).
- What it touches: any program that reprograms channel 0 above 18.2 Hz and
  counts time by its own interrupts (direct-DAC players, T2X-DAC,
  T2X-TIMERSTOP) loses up to 8 ms of interrupts every 110 ms under this DOS.
  Not uCDD's; under C2 the same holds show in the capture (t2dev-d8c2: 18
  long periods at the same cadence). Evidence: emulator (the development
  runs above), reading (IO.SYS's bytes). Hardware: not run.
- Michael's ruling (26 Oct 2026): environment shared with the PC, not
  routed around, measured and separated. The labelled hypothesis, the boot
  logo's hook, tested first: MSDOS.SYS [Options] Logo=0 and no LOGO.SYS,
  variant A, three runs (t2dev-logo0_1 to -3): no gap over 1 ms (the
  longest interval 125 us), the replaced handler's longest call 2 us, the
  closing beep -0.000 s each. Closed by that setting: the bench adopts it
  (its boot/MSDOS.SYS, [Options] BootGUI=0 and Logo=0, written onto every
  run's disk; BootGUI=0 as on the PC, without it the boot waits 30 s), the
  hardware kit's README tells Michael to set it, and the kit's variant A
  runs under both settings. Runs before 26 Oct 2026 10:30Z booted with the
  logo hook in place. The table stands as the capture check's calibration
  entry for ticks_lost (runs/rec/thresholds.toml), and a program that fails
  identically in C0 by losing fast PIT ticks cites this row, not a bare
  GAME_FAULT (Michael).
- Corrected (rule 7 form, 26 Oct 2026): old text "The table stands as the
  capture check's calibration entry for ticks_lost
  (runs/rec/thresholds.toml)"; new text: the capture check keeps the BIOS
  tick; the TSC clock and ticks_lost are withdrawn (Michael), T2.EXE's TSC
  lines stay as a diagnostic, thresholds.toml has no ticks_lost entry.
- Closed (Michael, 26 Oct 2026): cause, the boot logo's timer hook; fix,
  MSDOS.SYS [Options] Logo=0 and no LOGO.SYS; grade emulator, hardware
  pending the hardware kit's variant A run under Logo=1 and Logo=0, so
  the PC grades the hold. The bench boots Logo=0 from 26 Oct 2026 (the
  bench's dc9f970, 10:38Z; its first plan a6ce4cf8, 10:43Z); every ledger
  entry before it is annotated "Logo=1 boot (IOSYS08 holds present)"
  (1852 entries in 50 plans; the annotations are kept with the ledger).
  Passes before it stay evidence. Run again on Logo=0, 10 runs each: T1-LOAD,
  T1-PLAY23 and every Tier 1 row that failed under CAND-4, 5 or 6; a fail
  that passes there is filed again as an interrupt-latency candidate citing
  this row, not dropped. The kit's README: set Logo=0 on the PC, this row
  the reason.

### 86FILL: with its recompiler off, 86Box falls behind real time when the guest spins at 233 MHz, and the recorder fills (an emulator and host limitation; found 26 Oct 2026)

- Seen [86Box] chasing Project A's T2X-DAC: T2.EXE DAC with its main
  loop spinning (`T2.EXE DAC 8000 BUSY`, C0, the bench's p55t2p4 at a
  Pentium MMX 233, dynarec off) fills the capture with repeated buffers:
  exact repeats of 960-sample blocks 4 back and more tone cycles than the
  guest's bytes make. With HLT or a port-read wait in the loop instead,
  no fill (IOSYS08's holds alone remain). Development runs, not recorded.
- The table (C0, 8000 Hz, the busy loop; repeats, cycles over the guest's
  4004, the closing beep by tonecheck):
  MMX 233, dynarec off (t2dev-dacc0b): 33, +397, outside the 1 s window;
  MMX 233, dynarec on (t2dev-fillDYN, a comparison): 0, +0, +0.090 s;
  MMX 200, dynarec off (t2dev-fill200_1 to _3): 21, 24, 9; +789, +937,
  +335; +0.49, +0.51, +0.24 s;
  MMX 166, dynarec off (t2dev-fill166_1 to _3): 0, 0, 0; +0; +0.09,
  +0.08, +0.08 s (IOSYS08's holds, not fill). Zero fill at the MMX 166.
- Not the guest's and not uCDD's: the host's interpreter cannot keep a
  233 MHz emulated CPU in real time through a tight loop. No configuration
  change made: the cells a slower CPU would affect are Michael's to weigh
  (STATE). Evidence: emulator (the runs above). Hardware: not applicable.
- Michael's ruling (26 Oct 2026): this 86Box cannot record sound in
  emulated time (its "Record" and ".wav" are the cassette drive's; the
  bench's capture is OpenAL Soft's real-time wave writer), so the row stays
  open. Tiers 0 to 2 stay at the MMX 233: no program spins, and every run's
  capture check proves it, now that its guest clock is the TSC (fill adds
  audio the guest never played and moves the closing beep: over 50 ms is
  HARNESS_ERROR; an exact-repeat scan cannot tell fill from a steady tone,
  the 86Box SB16's own captures repeating 960-sample blocks). The Tier 3
  CPU is decided at A5 from the calibration set's fill rate at 233; if
  games fill, A6 runs at the MMX 166 for the whole sweep, recorded once, no
  CPU axis.
- Under C2 an idle is no idle (Michael, 28 Oct 2026, question 29): a
  HLT under uCDD wakes on its period interrupt, 1378 times a second at 32
  frames, so a game that idles in HLT costs the host what a spinning one
  does on this bench. Seen in T2X-DMAREAD (plan 6fc1a31d's first takes):
  bursts of port reads with one HLT between them ran nearly flat out on C2
  (18176 readings, 18624 with no HLT at all) and broke 4 captures in 14,
  every underrun in the reading with 86Box's thread at 90 % or more; on
  C0, where the HLT waits for the next real interrupt, none in 10. The
  case now idles to the next BIOS tick (a HLT that returns at once is not
  a wait). A5's fill-rate measurement expects it: the calibration set's
  games under C2 fill as busy loops would, whether they spin or halt.

### TOL2: "within 2" in the interrupt counts of CLIGAP, PICHOLD and DMAMC (a bench tolerance; written 27 Oct 2026)

- What: T2.EXE judges the card's interrupts over a span against the blocks
  due in it (22050/4096 a second over the span's BIOS ticks), within 2:
  CLIGAP and PICHOLD from MIX to OFF, DMAMC each 27-tick phase.
- Origin: mine (bench ec21fab, CLIGAP; copied into PICHOLD e7815d4 and
  DMAMC 8e94c0a), not a document's. The span is measured in BIOS ticks
  (55 ms) and a block (186 ms) can fall either side of each end: one at
  the start, one at the end, 2 in all.
- What it judges: that blocks keep coming at their rate through the span,
  not when any one block's interrupt comes. That is DMAMCR's (Michael, 27
  Oct 2026: the first interrupt after a set-up comes after the remainder
  of the interrupted block, SBG's block counter being the DSP's,
  8237:485-491 scoping the clear to the DMA controller).

### PITCHCAL The captured pitch's tolerance, calibrated from C0 (27 Oct 2026)

Rule (Michael, 27 Oct 2026, question 26, from rules-bot): tolerance = max(0.5 %, 3 x the largest C0 pitch deviation over all plans to date). The 1.5 % that stood before was rules-bot's uncalibrated figure in the fold (context/docs/project_a.md:205); the charter's 0.5 % at project_a.md:146-147 is Tier 0's resampler check on a synthetic tone, another measurement.
Figures (the bench's runs/rec/pitchcal.py, bench b36f058): every current C0 capture on disk, 1990 tone and band checks in 36 C0 plans, each check's peak within 5 % of its expected frequency in its own window (Hann, a parabola through the peak bin). The largest deviation 0.161 % (T2C0-SC8-M, S4, 374e7ae5-006: 1996.77 Hz against 2000); then T2C0-AI8 A0 0.129 % (2002.58 Hz), T2C0-SC8-M S0 0.099 %, T2C0-SC8 S4 0.092 %; every S16SC-M step 0.045 to 0.047 %. Result: max(0.5 %, 3 x 0.161 % = 0.483 %) = 0.5 % (thresholds.toml tone.freq_tolerance 0.005).
Applied with it: the band check's neighbourhood its own 5 % (tone.neighbourhood; three tolerances hid the 1940 Hz skirt plant at 0.5 %); ADPCM4's C2 expected from the DSP 4.13's table (VSB:292-304: A5h, R = 61, 10863.3 Hz, the tone 1977.1 Hz; measured 1976.7; the CT2290 1974). test_rec.py 36 of 36.
Judged again (887 current captures in 100 plans), the moves the tolerance makes: T2X-DAC d376fe5b PASS to FAIL x10 (1982.8 to 1984.9 Hz against 2002.0: 0.9 % low) and T2X-SC8 9646a9cc x9 (S4 1977.6 to 1980.2 Hz, 1.1 % low), both taken again as Michael asked (the plain variants of CAND-18 and CAND-19); A2's Tier 1 CD cases on C2, plan 0cf7cb43 (T1-PLAY6 x10, PLAY23 x4, PLAY5 x1: the CD's 440 and 1000 Hz at 438.2 to 1002.8 Hz in single 1 s windows, so under 90 % of windows inside 0.5 %), put to Michael (STATE question 27). The other moves are not the tolerance's: ccb39d17's T1 captures from before T1.EXE's TICK END; nine single captures to HARNESS_ERROR by question 21's rule (no host record, an unexplained lateness); one a fault in the re-judging script (a C0 plant judged as C2).
Open: the C2 expected pitch of SC8, AI8 and the other 41h cases is 2000 Hz in tonecheck, where the DSP 4.13's register plays 2003.0 Hz (VSB:292-304): a 0.15 % bias inside the 0.5 %, not yet corrected.

### STALLCAL: the recorder's stall, calibrated (a bench instrument; Michael, 26 Oct 2026)

- What: 86Box's recorder (OpenAL's writer running dry) puts exact digital
  silence into sound.wav, reached on a straight fade and ending on 86Box's
  20 ms buffer edge; the guest's own silence reaches the recording through
  86Box's SB16 filter and rings. A stall is no verdict (HARNESS_ERROR,
  plan_run takes the run again); a silence that is not one is the guest's.
- Thresholds: the bench's runs/rec/thresholds.toml [stall]: level 0 (exact
  silence), buffer_s 0.020 (the buffer edge), edge_samples 16, ramp_spread
  2, min_step 1.0 (the straight fade), band_min_s 0.001 and band_margin_s
  0.005 (a stall inside a band drop); bench b1db940.
- Data: the five breaks of 0cf7cb43-001, -013, -018 and ccb39d17-410 (25
  Oct 2026; the fade 35 to 43 counts a sample, equal to 1 count),
  7b2cdd5e-001 (26 Oct: 780 and 38 ms ending on the grid, no fade),
  7211c04e-006 and -009 (26 Oct: 896 exact zeros, 18.67 ms, on the grid
  after a fade of 59 to 60 counts a sample; under the gap check's 20 ms,
  read 20 and 21 ms by the mixed cases' band-drop check, which called them
  FAIL until bench 6d2f5db; taken again, both pass). Every stall since the
  Logo=0 bench is 896 zeros after a 64-sample fade: one 20 ms buffer.
- Proof, permanent: the bench's runs/rec/test_rec.py plants 13 faults on a
  capture it makes (stalls at a tone peak of 20.0, 20.5 and 30 ms, the grid,
  the guest's shape at 19.5 and 25 ms, each source gone, three broken
  captures, and the limit) and checks each verdict: 13 of 13 at b1db940;
  against e7815d4's tonecheck (before the band-drop rule) 11 of 13.
- Limit: a stall that starts within a sample or two of a zero crossing has
  no fade to see; if it does not end on the grid it is read as a gap
  (test_rec.py keeps it as a FAIL). So a Tier 2 FAIL on exact digital zero
  is judged stall or guest by hand in its row before it is a candidate
  (Michael, 26 Oct 2026); CAND-7 to CAND-16 carry that line.
- Rate (Michael, 26 Oct 2026: counted per plan; more on C2 than on C0 makes
  the stalls the subject; open in STATE until the cause is found or the
  rate shown stable): the bench's runs/stalls.py. Since the Logo=0 bench
  (a6ce4cf8, 26 Oct 10:43Z): C0 50 captures, no broken one, no stall's
  shape in the 40 on disk; C2 93 captures, ccb39d17-410 broken (the
  closing beep +0.060 s) and 7211c04e-006 and -009 stalls, and the scan
  finds two more inside passing captures (ccb39d17-403 and -405, 18.67 ms,
  under the gap check): 4 of 83 on disk. More on C2: the subject (STATE).
  Evidence: emulator.
- The C2 rule (Michael, 27 Oct 2026): the shape cannot tell a recorder
  stall from a refill uCDD missed inside one 86Box buffer, so under C2 the
  shape is a FAIL unless the recorder's host-side record shows a stall at
  that instant; C0 keeps HARNESS_ERROR. The record: the bench's
  runs/rec/alrec.c (bench 565a960), loaded into 86Box with LD_AUDIT for
  every recording, alrec.txt beside sound.wav: each OpenAL buffer queued
  and each underrun on the host's clock; thresholds.toml stall.host_window_s
  0.10 (provisional until a stall is caught with its record) and
  host_startup_s 1.0. test_rec.py judges each stall plant four ways: 25 of
  25. PICHOLD's three C2 stalls are FAILs by it (FLAKY-1).

- Corrected 27 Oct 2026 (Michael), in the rule 7 form, both kept:
  - Old text (26 Oct, and the morning of 27 Oct): the recorder's stall is
    told by the silence's shape (exact zeros on a straight fade or ending
    on the 20 ms buffer edge), HARNESS_ERROR; then, as the stalls fell on
    C2 only (C0 0 of 90 against C2 6 of 135: the rate's asymmetry,
    inferred, not measured), the shape under C2 a FAIL unless the host's
    record showed the recorder stalled at that instant.
  - New text (27 Oct 2026): whose silence is measured by the closing beep.
    A missed refill cannot move the beep; only samples the recorder adds
    can. An exact silence where sound is due whose length in whole
    buffers equals the closing beep's lateness is the recorder's insertion
    (HARNESS_ERROR); with the beep on time it is the guest's (FAIL by the
    gap rule); C0 and C2 alike, old captures included; the host record
    (alrec.txt) confirms from 27 Oct on. The shape rule is retired. The
    measure: every one of the six faults had the beep late by its silence
    in whole buffers (+0.020 s for 18.67 ms; -410 +0.060 s, no silence).
    Bench c426591; thresholds.toml [stall] beep_tol_s 0.010 (the beep read
    in 10 ms frames), insert_min_s 0.010; test_rec.py: insertions of one
    and two buffers HARNESS_ERROR four ways, silence in place four shapes
    FAIL on C0 and C2, 25 of 25 (against the shape rule's tonecheck 11).
- The planted host stall (Michael, 27 Oct 2026; the bench's
  runs/rec/hoststall.py, C0, T2.EXE SC8 C0, 18.3 s after the device
  opened). SIGSTOP and SIGCONT: 25 ms nothing; 50 ms an underrun in the
  record, nothing in the capture; 100 ms 38.67 ms of silence, the beep
  +0.060 s; 200 ms 138.67 ms, +0.160 s. SIGSTOP freezes OpenAL's mixer too,
  which a real stall does not, so the plant was also made inside 86Box
  (alrec.c RIG_ALSTALL: the sound thread held while the mixer runs on): 25
  ms nothing; 50 ms an underrun only; 70 ms no silence, the beep +0.020 s;
  80 ms 18.67 ms, +0.040 s; 90 ms 38.67 ms, +0.040 s (tonecheck: recorder
  insertion, the host record shows an underrun there); 100 ms 38.67 ms,
  +0.060 s. So the +20 ms signature (the beep late by the silence in whole
  buffers) holds for every real fault and for the 90 ms plant, but a
  planted stall can also leave the beep one buffer later than its silence
  (80 and 100 ms): the rule as written would call such a silence the
  guest's (STATE question 20). The record logs the underrun 1 to 23 ms
  after the silence ends in every plant: stall.host_after_s 0.040 (bench
  07ef9be) replaces the 0.10 s window around the start, which a 140 ms
  silence would have missed.
- Old captures judged again under the rule (27 Oct 2026, every capture
  with a tonecheck verdict, 552): three passes turned out insertions
  (0cf7cb43-033 T1-PLAY5, ccb39d17-403 and -405 T1-PLAY23, each 18.67 ms
  with the beep +0.020 s), kept as .ins1 and taken again: pass, pass,
  pass; no FAIL changed. 70 more (ccb39d17-391 to -470 bar PLAY23) read as
  unfinished because they predate T1.EXE's closing beep; plan 0cf7cb43
  replaced them as the audio evidence on 25 Oct.
- The rule as a sum (Michael, 27 Oct 2026, question 20): the buffers the
  recorder put in are the silences' in whole buffers (those no longer than
  the lateness) plus the buffers 86Box played again (a copy of the buffer 4
  back: 86Box's src/sound/openal.c queues 4 buffers a source and, finding
  it stopped, plays them again); an insertion when the closing beep is late
  by exactly that sum; silence where sound is due then HARNESS_ERROR;
  copies alone inside the 50 ms limit: the verdict stands, noted with
  their count; past the limit a broken capture; lateness not explained:
  reported, not judged (bench d0bed03; test_rec.py 29 of 29).
- Measured against it (27 Oct 2026). Replays: 22599c44-002 (C2), 9b053b5b-004
  (C0) and 4de3c65b-006 (C2) each hold three copies of the buffers 4 back
  at the record's underrun, the beep only 1 buffer late; 4de3c65b-005 (C2)
  the same three with the beep on time: a replay mostly takes the guest's
  place rather than adding to it, so the sum does not hold and these read
  "not explained". DAC C2: all ten of d376fe5b and both new runs with a
  record (corr-dac2-1, -2) +0.020 s, no underrun, no copy, the writer
  steady: that lateness is not the recorder's; the guest's beep comes 20
  ms late in DAC under C2 (C0 -0.000 s in all ten). The replay scan counts
  the SC8 tone's own repetition on C0 as copies (14.2 to 15.0 s, the same
  in 2c278c7c-005, corr-c0-1 and -5): not yet fit to count. Every capture
  judged again: 27 move to "not explained" (STATE question 21; none taken
  again yet).
- The record outranks the capture (Michael, 27 Oct 2026, question 21;
  bench eda4e08). With alrec.txt: an underrun where the checks judge is a
  recorder event (HARNESS_ERROR), whether it put sound in or took the
  guest's place; elsewhere it is noted; none makes the capture the guest's
  and the closing beep's lateness a result. Without a record: the silence
  and the beep's sum as before, the replay scan not used, "not explained"
  kept; only runs that are current evidence for a FAIL or a candidate are
  taken again, superseded runs never judged again. The replay scan is
  dropped (it counted a tone's own repetition, and could not tell it from
  86Box's replays within one capture). DAC under C2 judged: its record
  clean, its lateness the guest's; ticks_lost from the TSC (the guest's
  BIOS count behind real time) 16.7 to 17.4 ms over 77 ticks under C2,
  -1.4 ms on C0: the bench's trap cost, shown, not judged; it feeds the
  AKIT 8 kHz entry (EXPECTED_PERF if the PC loses ticks too). The current
  evidence judged again: 20 moved; the five that were evidence for a FAIL
  or a candidate taken again (0add08f0-008, -009, dc6405c7-005,
  0cf7cb43-079, 22599c44-002): the same verdicts, each record with no
  underrun where the checks judge; the 15 that were PASS evidence left as
  recorded. test_rec.py 31 of 31.
- The stall is the box's (Michael, 27 Oct 2026): host underruns at the same
  rate on C0 and C2 (since bench 565a960: C0 3 of 10, C2 3 of 14; the batch
  corr-*: C0 2 of 8, C2 1 of 8, DAC C2 0 of 2). The single-step hypothesis
  is demoted to why C2 gets silence where C0 gets a repeat. Correlation
  (bench 22da675, alrec.txt's writer lines, watch.txt): the nearest DONE
  poll or screenshot 280 to 900 ms from each underrun (polls 2.6 ms on
  average); OpenAL's wave writer kept writing every 20.2 to 20.3 ms through
  each (longest gap in any run 21 to 28 ms); 86Box's main source last
  queued 40 to 86 ms before: 86Box's sound thread fell behind. Nothing
  aligned, so each run now logs the host's load and the agent's CPU seconds
  at its start and end, and no build, test or git work runs while a plan
  records (plan_run's recording.flag; the backups to wait on it through
  runs/quiet.sh, the crontab change Michael's to apply). Same family as
  86FILL; the A5 CPU decision covers both.
## The feature branches (rows reconstructed 24 Oct 2026)

These four changes were ported from the fork's line onto the author's
0.9.4-a6 on 23 Oct 2026, one `feature/*` branch each, and committed with
Issue trailers but no row. The rows below are reconstructed 24 Oct 2026
from each commit's own message and HANDOFF ("four feature branches for the
author"), for the fixes index (tightening r3, T1). Each change is built,
not run, on that base: built at 128 and 32 frames and without resident
audio, and no test of any kind has run on it there.

### DISKIRQ: disk controller IRQs go straight to DOS (reconstructed 24 Oct 2026; built, not run)
- Fault: a PCI disk controller holds its level-triggered request until its
  real-mode handler runs. A protected-mode program waiting in a real-mode
  call for the disk never took the IRQ the DPMI host queued for it, so
  DOS/4GW games froze at their banner on a PC whose only IDE controller is
  a PCI card (Michael's Promise Ultra133 TX2, on IRQ 9, 14 or 3 by BIOS
  settings).
- Change: `UCDD -install` scans the PCI BIOS for mass storage controllers
  and builds a mask (IRQ 14 and 15, the IRQs found, one set by hand in
  UCDDSET's Disk row); the host's real-mode IRQ stubs and its
  protected-mode IRQ path send those IRQs to the real-mode handler. CDF5
  carries the mask at +24; UCDD.CFG version 5 holds the hand-set IRQ at
  offset 42. `SET UCDDPCI=OFF` skips the scan. Details: docs/disk-irq.md
  on feature/disk-irq.
- Commit: fd2d564 on feature/disk-irq (also under feature/fast-dma).
- Evidence: data sheet (PCI BIOS 2.1, INT 1Ah B101h, B10Ah, B108h; class
  01h; PCI interrupts level-triggered and held until serviced); reading.
  Built, not run on 0.9.4-a6.
- Evidence state (24 Oct 2026): built, not run; no emulator claim and no ledger entry; prove under plan 45bc14ec (list a) and plan cdee6f75 (the sound check, once it has recompiler-off references: DYNAREC) before this reaches fixes.

### STEPASIDE: the driver steps aside while it has nothing to add (reconstructed 24 Oct 2026; built, not run)
- Behaviour: while no mounted image is bound for CD audio and the
  physical card can be the virtual one at the same port, IRQ and DMA, the
  driver stops its output, gives back the trapped ports but the
  keyboard's, and the host offers no DPMI and hides no VCPI: a game talks
  to the real card as without the driver. A mount of an audio disc (or an
  MDM list with one) brings it back; the state changes only at a mount, an
  eject and the end of the install.
- Change: UCDDSET's "uCDD driver always on" keeps the driver on (greyed
  while the cards cannot pair); UCDD.CFG version 5 offset 43; the host's
  dormant byte is offset 10 of its resident state. Details:
  docs/step-aside.md on feature/step-aside.
- Commit: d6c2008 on feature/step-aside (also under feature/fast-dma).
- Evidence: data sheet silent (the driver's own policy: a game on the real
  card, as without the driver); reading. Built, not run on 0.9.4-a6.
- Evidence state (24 Oct 2026): built, not run; no emulator claim and no ledger entry; prove under plan 45bc14ec (list a) and plan cdee6f75 (the sound check, once it has recompiler-off references: DYNAREC) before this reaches fixes.

### FASTDMA: the chipset's own fast DMA timing on the output channel (reconstructed 24 Oct 2026; built, not run)
- Cost addressed: in the default ISA DMA timing each byte holds the bus
  for about a microsecond; on a PIIX3 with an ES1868 the output stream cost
  9 percent of memory copy speed at the half rate and 18 at the full rate.
- Change: UCDDSET's "Enable platform fast DMA" sets the chipset's
  documented fast timing on the output channel while the output runs and
  puts the old value back when it stops. The install's PCI scan finds the
  ISA bridge in a table (Intel PIIX family, 82378 SIO and EISA, ALi, OPTi,
  VIA and AMD-756, SiS); 386 and 486 chipsets are left alone. UCDD.CFG
  version 5 offset 44. Details: docs/fast-dma.md and docs/platform-dma.md
  on feature/fast-dma.
- Commit: 2729c80 on feature/fast-dma.
- Evidence: data sheet (each chipset's, cited in docs/platform-dma.md:
  Intel 82371FB/SB/AB MBDMA, 82378 and EISA 40Bh/4D6h, ALi, OPTi, VIA 45h,
  SiS 70h/71h); reading. Built, not run on 0.9.4-a6. STATE question 2
  (ALi and OPTi bits 3:2) is Michael's to overrule.
- Evidence state (24 Oct 2026): built, not run; no emulator claim and no ledger entry; prove under plan 45bc14ec (list a) and plan cdee6f75 (the sound check, once it has recompiler-off references: DYNAREC) before this reaches fixes.

### ESSOUT: native ESS AudioDrive output (reconstructed 24 Oct 2026; built, not run)
- Limit addressed: an ESS AudioDrive could only be the physical card as a
  Sound Blaster Pro (8-bit stereo at 22 kHz).
- Change: UCDDSET's "ESS AudioDrive" model plays 44.1 kHz 16-bit stereo
  through the chip's extended mode, on the 8-bit DMA channel in demand
  mode, with the WSS codec's ring. The ES1868 and ES1878 (identified by
  mixer register 40h) get their clock trimmed to 44,100 Hz (BAh bit 6);
  any other ESS runs at its data sheet rate, 44194 Hz, and the mixer is
  told so. The stop resets the chip to Sound Blaster mode and puts its
  mixer registers back. Details: docs/ess.md on feature/ess.
- Commits: 17c78fc on feature/ess; 9e10a45 on feature/ess (wss_stop read
  sb_irq after LDS had changed DS, so it restored the old handler on the
  wrong vector and left the card's vector in the driver; on the fork's
  line this fix is 8c0b805, found when a UCDDSET Test froze the PC).
- Evidence: data sheet (ES1868 and ES1878 sheets: extended mode registers
  A1h-B9h, the rate divider, BAh bit 6, identification by mixer 40h; for
  9e10a45 silent, INT 21h AX=25xxh takes the vector in AL and the handler
  in DS:DX); reading. Built, not run on 0.9.4-a6 (17c78fc built at 128 and
  32 frames and without resident audio; 9e10a45 at 128 frames).
- Evidence state (24 Oct 2026): built, not run; no emulator claim and no ledger entry; no plan covers the ESS path yet (list a and the sound check are Sound Blaster only); a plan for it is needed before this reaches fixes.

## Performance

### IRQCOST: the fixed cost of each card interrupt (23 Oct 2026)

- Symptom: at 32 frames (the period for all testing since 22 Oct) the
  card interrupts 1378 times a second, four times as often as at 128.
  On the PC (hardware, PLKIT) Hexen's timedemo took 415 realtics on
  period-late at 32 frames against 369 on D7 at 128: 12.5% slower.
- Citation: data sheet: silent. The cost is the driver's own plumbing, not
  the card's behaviour; nothing a game sees may change.
- Family: none (every engine pays it).
- Where it goes (period-late a1ec3ec, read in the code): every port the
  handler touches is trapped, because the physical card shares 220h with
  the virtual one, so each access is a call into JemmEx's API (function
  1Ah, served by host_gate): 13 per period on the SB16 (mask 2, mixer
  82h 2, acknowledge 1, the DMA count read twice by output_clock 6, end
  of interrupt 1, unmask 1). A game's read of the virtual DMA count takes
  output_clock's 6 too. With a protected-mode client running, the host
  bridges to the real-mode handler by a VCPI round trip (two CR3 loads).
  While CD audio plays, the handler asks for a refill bridge whenever the
  queue is not full enough to skip, and the refill often cancels on
  arrival because the queue is above CD_QUEUE_BYTES-64 KB.
- Measured [86Box, profile build, Hexen timedemo]: the handler without
  mixing 4355 cycles a period at 32 frames, 4360 at 128; mixing 1412 and
  3463; the host's entry from protected mode, handler included, 9514 and
  10126. On the PC 18 Oct (TKIT): ~19000 cycles per interrupt.
- Changes on irq-batch, one at a time: (1) the port accesses batched into
  a few host_gate calls, the same ports in the same order (the DMA count
  read twice as one call; mask, mixer 82h and the 16-bit acknowledge as
  one when the MPU-401 is not signalling); (2) no refill request when the
  queue is above the refill's own cancel line. Later, if needed: the
  virtual interrupt's take inside the audio bridge, then the card's
  interrupt without leaving protected mode.
- Proof: the profile build's per-period cycles before and after in 86Box,
  and on the PC (PROFKIT, with UNITCOST for one access's cost); the
  standard regression and the sound check unchanged.
- Result, changes 1 and 2 (257b4a9, c6d5c4b) [hardware: the PC, PROFKIT
  against PK2, Hexen's timedemo with the profile builds]: the handler 11750
  cycles a period -> 8848 (its fixed part ~7400 -> ~4700); the host's
  protected-mode entry with the handler 20723 -> 17695; refill bridges
  4062 -> 614; the timedemo 429 -> 406 realtics. One call into JemmEx's
  API costs ~350 cycles over the port access itself (UNITCOST: 446
  against 95); a port uCDD traps, 1746. [86Box] the regression the same
  as period-late; the sound check as D9. Left: the host's own round trip
  (~9000 cycles when the card interrupts a protected-mode client), the
  second bridge for each virtual interrupt.


Measured in 86Box (13 Oct 2026): a Pentium MMX 233 with the
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

**On the real PC** (ECS P5HX-A, Pentium MMX 233, ES1868 at half rate,
Promise Ultra133, measured 13 Oct 2026 with the HWLOG scripts) the picture
is different from the emulator's, and 86Box does not model the cause. The
driver costs 11 to 13 percent on memory copies, fills and video fills and
11 to 19 percent in Doom and Quake with or without sound, but only 1.5
percent on a register loop. The output stream is the cost: the ESS card
streams by demand-mode ISA DMA all the time, and on this chipset each DMA
byte takes about a microsecond of the bus. With no driver loaded and the
card streaming silence, the same memory tests lose 8 to 10 percent at
22.05 kHz 16-bit stereo (88 KB/s) and 18 to 21 percent at 44.1 kHz (176
KB/s); a test build that installs the driver and then stops the output
costs 0 to 3 percent in the same tests, Doom without sound 2.7 percent
instead of 18.7. The audio interrupts themselves take 1.6 percent of the
CPU. The gains worth having on this machine are therefore in the stream,
not the code: stopping the output while nothing plays (no game DMA, no
disc audio) would give a soundless game the no-output figures, at the
price of a start delay for the next sound; the half-rate "fast" model
already halves the bus time against 44.1 kHz. Neither is done: games
are meant to play sound and disc audio, so the soundless case is not
worth a design change in the output path. A real ESS output start takes
0.66 ms with the first interrupt 1.25 ms after the call, should it ever
be revisited.

The ES1868 clock trim had never been applied on real hardware before the
ESS identification fix (13 Oct 2026): `ess_identify` rewrote the mixer
index before each of its four reads, which restarts the chip's answer
(the real chip gives 18h 18h 18h 18h that way and 18h 68h with the index
written once), and then kept the first byte in AH across a port read that
loads AX. Every ESS ran the interpolating path. With the fix the real
PC's CD-alone mixing fell from 43.5k to 12.2k cycles per interrupt and
the cost of disc audio over idle from 5.2 to 3.1 percent from the hard
disk and 4.0 to 1.9 from a RAM disk; the hard-disk cases keep about 1.2
points for the BIOS reads. A real ESS output start takes 0.66 ms, with
the first audio interrupt 1.25 ms after the call.

**Type F DMA** (13 Oct 2026, real PC): the PIIX family can run an ISA
DMA channel at 3 clocks per transfer instead of 8, through a 4-byte
buffer. With the ESS streaming and no driver loaded the memory copy loss
fell from 9.0 to 0.7 percent at the half rate and from 18.0 to 1.5 at
the full rate, the register loop unchanged; under μCDD Doom went from
1788 to 1613 realtics and full Quake with CD music from 19.8 to 22.0 fps,
which leaves the driver's whole cost in Doom at about 6 percent. The
ES1868 takes the faster cycle cleanly (its data sheet asks for a 100 ns
write strobe and releases its request within 30 ns). The option is a
UCDDSET switch, off by default; no other chipset family is known to the
driver, and a card that cannot keep up gives garbled audio, not damage,
since playback reads memory.

Not worth changing: the CLI and STI path; a virtual ESS model (the
capture and mix are the same whatever the game believes it talks to); the
mixer for MMX (a few percent of the mixer's share, in a full segment).
- Evidence state (24 Oct 2026): the emulator claim predates the ledger; re-prove under plan 45bc14ec (list a) and plan cdee6f75 (the sound check, once it has recompiler-off references: DYNAREC) before this reaches fixes.

## Fixed after the reviews

Found by the review of UCDD.EXE and the specification pass, fixed in
`fixes`, checked in 86Box against the build before the review
(0f81195) unless the note says otherwise. Ctrl+Break with BREAK=ON needs
MS-DOS (FreeDOS does not run the break check in those calls) and was checked
in 86Box.

Driver and CD:

- A disc hotkey (MDM list, or eject and insert of a single image) bound the
  new disc for CD audio from the timer tick and from the request entry, and
  read the image through DOS with the game's PSP and without the DOS state
  swap. A game's file on the same handle number lost its position. The bind
  runs inside `dos_enter` now, and the timer does not switch discs while the
  BIOS disk code runs. 86Box: twelve handles open on one file, the position
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
  a second reading of the handler after the IRQ 7 work; the games it ran
  at 7/7 happened to survive it. The handler loads CS again before the
  switch. The hardware tests before it ran with the card on IRQ 5, so no real-PC
  run has had this fault.
- The single-cycle block patch, reached from the port trap when a game
  starts a block, ran the mixer's string stores with the game's direction
  flag: the JemmEx trap entry clears only IF and TF in the game's flags
  image. A game with the direction flag set at that DSP write would have had
  the patch written backwards through the output ring and past its start.
  Found by the data-flow pass after the IRQ 7 stack fault; `sb_patch` clears
  the flag under its own flag save now.
- A refused DSP command or argument left the argument counter set, so the
  bytes the game wrote next were taken as arguments. 86Box: E1h after a
  refused short block replies 04.05, no reply before.
- A refused rate was already stored, and a rate of 0 later divided in the
  silence command and the single-cycle block start.
- DAh/D9h while paused with D0h/D5h was dropped; it is held and applied at
  the resume, as the DSP does. 86Box: D0h, DAh, D4h on an auto-initialize
  stream ends the block after the resume, looped before.
- 41h/42h set the rate of the legacy commands too; A0h and A8h are accepted;
  20h answers 80h, F8h answers 0, F3h raises the 16-bit interrupt; the status
  ports read 7Fh/FFh in the undefined bits; the SB16 stop resets the DSP.
- The virtual mixer's FM register 26h starts at FFh, as its 5-bit twins
  34h/35h do.
- 8237: the command, master clear, all-mask and status registers of both
  controllers are trapped. 86Box: a write to the slave all-mask register
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
  identification, with the index written once and the first byte kept
  clear of the port read, see "Performance"); the analog control write
  changes bits 1 and 0 only; the mixer registers the start writes (14h,
  22h, 26h) are put back at the stop.
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
  nothing virtual to end itself. 86Box: the recording build shows one EOI per
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

### REFEXCL: repositories evaluated and excluded as references (28 Oct 2026)

- NationDMA/NationDMA and Shocka-Zulu/Soundblaster-Emu-Fw ("DMA-Nations
  Free Firmware"): firmware for PCIe FPGA DMA cards, with no relation to
  the Sound Blaster DSP (Michael, 28 Oct 2026). Excluded; recorded here so
  they are not evaluated twice. The reference library's README says the
  same.
- Kept as firmware references, not in the library (the same ruling):
  S95Sedan/CT1741_DSP, schlae/sb-firmware and schlae/snark-barker's
  firmware/sb.hex, local read-only clones pinned by commit in the bench's
  downloads.lock, cited by command and behaviour only; the Snark Barker's
  Sb202Spec.md is in the library as key SB202SPEC (CC BY-SA 4.0).

### VESS-STEREO: the virtual ESS takes compatibility-mode 8-bit stereo's first byte as left, where the ESS starts every transfer right (28 Oct 2026, open; the virtual ESS is parked)

- Expected: "For 8-bit data, the ES1868 expects the first byte transferred
  to be for the right channel, and subsequent bytes to alternate left,
  right etc." (ES1868:2457-2459; the same in all five ESS sheets,
  vess-spec 7.2, E68:2456); the first byte of every stereo transfer right
  (Michael, 28 Oct 2026: ES1868 decides for an ESS).
- Observed, by reading only: uCDD takes the first byte as left
  (mix.asm .stereo8_normal), vess-spec 17 item 1. No Project A run: the
  virtual ESS is parked (rule 6 keeps the ESS and the SB families apart).
- Hardware: the PC's ES1868 confirms in AKIT (the PROST case on the ESS
  in compatibility mode). Evidence: data sheet; the virtual card's
  behaviour by reading. Hardware: UNCONFIRMED.

### LIBAUDIT: every silent and held row searched against the whole library (28 Oct 2026)

Michael, 28 Oct 2026, from rules-bot: for every matrix row whose `decides` says silent (planted faults aside) and every held row, the whole reference library's text (refs worktree, every .txt and .md, INDEX.md aside) searched for the row's subject terms, case-insensitive; the hits per row group below, and what the library answers. 76 rows in 20 subjects. Rows the library answers were rewritten with the citation, in rule 7 form. From r3.7, silent needs a searched: term list and hit count, checked by plan.py (not yet installed). The search: the bench's runs/libaudit.py, its terms listed here.

- **BOOTCHK** (3 rows: BOOT-C0 BOOT-C1 BOOT-C2). terms: boot check; hits 0 in 0 files. procedural (the bench's boot check); no document decides; silent stands.
- **CUE-INDEX02** (2 rows: T0-CUE-I02 T0-CUE-I02-A1). terms: INDEX 02; INDEX 2 ; subindex; index point; hits 57 in 15 files; most: M1543C_Desktop_Southbridge.txt (12), adip301.txt (10), M1533_PCI_to_ISA_Bus_Bridge_v1.56_199811.txt (8), 82C556M_82C557M_82C558M_Viper-M_Preliminary_Data_Book_199504.txt (7), 290562_82371AB_PCI-TO-ISA_IDE_XCELERATOR_PIIX4_199704.txt (5), SiS-5597-5598_199704.txt (3). the hits are chipset index registers and the AWE32's; no CUE sheet syntax in the library; silent stands (Michael's answer to question 6).
- **CUE-BOM** (2 rows: T0-CUE-BOM T0-CUE-BOM-A1). terms: byte order mark; EF BB BF; UTF-8; hits 0 in 0 files. no hits; silent stands.
- **CUE-PREGAP** (1 rows: T0-CUE-GAPA). terms: PREGAP; pre-gap; pause before; hits 1 in 1 files; most: hosts-and-cdrom.md (1). one hit, notes/hosts-and-cdrom.md:405 (the Q channel's index 0 in a disc's pregap), not CUE sheet syntax; silent stands.
- **RES-TOLERANCE** (5 rows: T0-RES-44100 T0-RES-43478 T0-RES-44444 T0-RES-44192 T0-RES-22050). terms: resampl; sample rate conversion; interpolat; hits 37 in 10 files; most: SiS-5597-5598_199704.txt (14), SiS-630_199910.txt (9), emu8kpgm.txt (4), DS1869_other_revision.txt (2), DS1869.txt (2), DS1878A.txt (2). the hits are chipset and ESS resampling registers, none a tolerance for uCDD's resampler; silent stands (A1's 0.5 %).
- **DEEMPHASIS** (5 rows: T0-DEEM-1K T0-DEEM-3K5 T0-DEEM-10K T0-DEEM-16K T1-PLAY5). terms: emphasis; 50/15; 50 us; 15 us; hits 19 in 14 files; most: MSCDEX21.txt (4), adip301.txt (2), M1487_M1489_486_PCI_Chip_Set_199707.txt (2), DS1869_other_revision.txt (1), DS1869.txt (1), DS1878A.txt (1). no 'emphasis' in MSCDEX21 or the ISO 9660 text; the hits are unrelated; the 50/15 us curve is the analytic one; silent stands.
- **T2X-13** (1 rows: T2X-13). terms: physical axis; hits 0 in 0 files. no hits (the physical axis); silent stands, held.
- **S16ODD2** (5 rows: T2X-S16ODD2 T2C0-S16ODD2 T2X-S16ODD2-M T2C0-S16ODD2-M T2X-S16ODD2-A1). terms: odd number; odd count; odd length; multiple of 4; multiple of four; hits 41 in 21 files; most: CS4031_Chipset_F84031_F84035_199305.txt (5), 82C556M_82C557M_82C558M_Viper-M_Preliminary_Data_Book_199504.txt (5), 1996_Intel_Peripheral_Components.txt (4), 241731-002_Intel486_Microprocessors_and_Related_Products_1995.txt (3), 241732-003_Pentium_and_Pentium_Pro_Processors_and_Related_Products_1996.txt (3), 1994_Intel_Peripheral_Components.txt (2). for the ESS the library answers: all six ESS sheets require 16-bit stereo DMA transfers in multiples of 4 (ES1868:2462-2466; ES1888 Design Guide:816; ES1887:1842; DS1878A:2464; DS1869:3115 and its other revision:3083), so an odd count is outside the ESS's sheet; for the SB16 (the rows' subject, B0h) the guide stays silent; silent stands for the SB16, the ESS finding recorded in STATE's AKIT entry.
- **PROST2** (2 rows: T2X-PROST2 T2C0-PROST2). terms: stereo switch; first byte transferred; alternate left; directed to the left; hits 14 in 9 files; most: ES1888_Design_Guide_1995-10_rev_C.txt (3), DS1878A.txt (2), Sound_Blaster_Series_Hardware_Programming_Guide.txt (2), Developer_Kit_SB_Series_Hardware_Programming_Reference.txt (2), DS1869_other_revision.txt (1), ESS_ES1868_Data_Sheet_1996.txt (1). answered the same day by Michael's ruling: SBG:2393-2395, 2476-2478, 1845-1854 and ES1868:2457-2459 (rows and CAND-15 rewritten, vsb-spec 7.4); what no document gives stays: the CT1345 toggle after a reset (EMU_DISPUTE kept for that).
- **IRQ-WINDOW** (6 rows: T2X-DMAMCR T2C0-DMAMCR T2X-DMAMASK T2C0-DMAMASK T2X-DMAMCR-A1 T2X-DMAMASK-A1). terms: FIFO; interrupt latency; request latency; hits 3539 in 46 files; most: 1996_Intel_Peripheral_Components.txt (950), 1994_Intel_Peripheral_Components.txt (545), 241731-002_Intel486_Microprocessors_and_Related_Products_1995.txt (481), M1543C_Desktop_Southbridge.txt (247), DS1869.txt (117), DS1869_other_revision.txt (115). SBG names the SB16's FIFO (3844-3852: the mode bit, re-initialised at each new digitized I/O command) but not its depth; the 16 samples are the CT2290's measurement (fork docs ct2290.md); the 2.00 ms window stays mine; silent stands.
- **GAPCHECK** (13 rows: T2X-TIMERSTOP T2C0-TIMERSTOP T2X-CLIGAP T2C0-CLIGAP T2X-PICHOLD T2X-PICHOLD12 T2C0-PICHOLD T2C0-PICHOLD12 T2X-P-TIMERSTOP T2C0-P-TIMERSTOP T2X-W-TIMERSTOP T2C0-W-TIMERSTOP T2X-TIMERSTOP-A1). terms: dropout; audible gap; glitch; hits 84 in 23 files; most: 241732-003_Pentium_and_Pentium_Pro_Processors_and_Related_Products_1996.txt (25), 82C556M_82C557M_82C558M_Viper-M_Preliminary_Data_Book_199504.txt (12), 241731-002_Intel486_Microprocessors_and_Related_Products_1995.txt (10), 1996_Intel_Peripheral_Components.txt (6), 82C700_Firestar_Single-Chip_Notebook_Solution_199702.txt (6), 1994_Intel_Peripheral_Components.txt (4). the bench's threshold ([gaps], Michael 26 Oct 2026); the hits are unrelated; silent stands.
- **LATENCY16MS** (2 rows: T2X-CLIGAP T2C0-CLIGAP). terms: 16 ms; latency; hits 879 in 40 files; most: 241732-003_Pentium_and_Pentium_Pro_Processors_and_Related_Products_1996.txt (121), 1996_Intel_Peripheral_Components.txt (101), 1994_Intel_Peripheral_Components.txt (98), 241731-002_Intel486_Microprocessors_and_Related_Products_1995.txt (45), 290562_82371AB_PCI-TO-ISA_IDE_XCELERATOR_PIIX4_199704.txt (40), SiS-5597-5598_199704.txt (38). the mantra's rule 5 ceiling; the hits are bus and cache latencies; silent stands.
- **KBC-D3** (2 rows: T2X-PICHOLD12 T2C0-PICHOLD12). terms: D3h; auxiliary device; mouse port; write auxiliary; hits 169 in 32 files; most: Developer_Kit_SB_Series_Programmers_Guide.txt (32), Developer_Kit_SB_Series_Library_Reference.txt (17), DS1869_other_revision.txt (11), DS1869.txt (11), ES1887_Data_Sheet_part_1_of_2.txt (10), SiS-630_199910.txt (8). answered: VIA's integrated keyboard controller documents D3h, 'Write Mouse Output Buffer & set status bit-5 (... so it appears to have come from the mouse)' (586B:1763-1765; 596B:1848-1850); T2X-PICHOLD12 and T2C0-PICHOLD12 rewritten with the citation (rule 7).
- **NAMED-COMPARISON** (2 rows: T2X-S16AI-M-HALT T2X-S16AI-M-SPIN). terms: HLT; hits 100 in 13 files; most: 1996_Intel_Peripheral_Components.txt (34), 1994_Intel_Peripheral_Components.txt (25), 241731-002_Intel486_Microprocessors_and_Related_Products_1995.txt (14), i386.txt (13), 241732-003_Pentium_and_Pentium_Pro_Processors_and_Related_Products_1996.txt (5), SiS-5595_PCI_System_IO_199811.txt (2). a named comparison, not evidence; procedural; silent stands.
- **BUILD-COMPARISON** (3 rows: SADUMP verify-mix verify-mix-legacy). terms: verify; hits 543 in 41 files; most: 1996_Intel_Peripheral_Components.txt (175), 1994_Intel_Peripheral_Components.txt (152), 241732-003_Pentium_and_Pentium_Pro_Processors_and_Related_Products_1996.txt (50), 241731-002_Intel486_Microprocessors_and_Related_Products_1995.txt (26), Intel_80C52_Data_Sheet.txt (13), 290562_82371AB_PCI-TO-ISA_IDE_XCELERATOR_PIIX4_199704.txt (13). comparisons between builds with no expected value; procedural; silent stands.
- **ENVELOPE** (1 rows: TONE4). terms: envelope; hits 209 in 9 files; most: adip301.txt (85), emu8kpgm.txt (50), SiS-630_199910.txt (36), Yamaha YM3812 Application Manual_text.txt (24), 241732-003_Pentium_and_Pentium_Pro_Processors_and_Related_Products_1996.txt (5), YMF262_199411.txt (3). a measurement with no expected value (the fast mode's pair averaging is the driver's design); silent stands.
- **GAME-RECORDING** (15 rows: MKTRIL THEMHOSP DESCENT HEXENBEY DUKE3D XCOMUF GK1 JILLJUNG SWDFORC SSTRDUST KYRA1 F4-highspeed DUNGKE01 F1-probe F15-fade). terms: game; hits 496 in 39 files; most: VT8231_PC99_South_Bridge_199910.txt (54), VT82C686A_Super_South_Bridge_V1.1_199904.txt (40), VT82C686B.txt (33), CS4232_datasheet.txt (32), DS1869_other_revision.txt (32), DS1869.txt (32). each game's recording without uCDD decides (CONTEXT.md: checking a game); procedural; silent stands.
- **SC8PAGE2** (2 rows: T2X-SC8PAGE2 T2C0-SC8PAGE2). terms: page register; wrap; roll over; rolls over; 64K boundary; 64 KB boundary; page boundary; hits 934 in 69 files; most: 241732-003_Pentium_and_Pentium_Pro_Processors_and_Related_Products_1996.txt (161), 1993_Intel_82378_PCI-ISA_System_IO.txt (105), 1996_Intel_Peripheral_Components.txt (88), 1994_Intel_Peripheral_Components.txt (73), 82374EB.txt (49), 290571-001_82378ZB_82379ZB_System_IO_and_System_IO_APIC_199603.txt (45). held for the emulator (86DMAPAGE), not for a document: 8237:331-338 already decides; the chipset hits restate the 8237's page registers; no change.
- **PICSMM2** (4 rows: T2X-PICSMM2 T2C0-PICSMM2 T2X-PICSMM2-M T2C0-PICSMM2-M). terms: special mask mode; SMM; hits 1569 in 38 files; most: 241731-002_Intel486_Microprocessors_and_Related_Products_1995.txt (422), 1996_Intel_Peripheral_Components.txt (208), 241732-003_Pentium_and_Pentium_Pro_Processors_and_Related_Products_1996.txt (196), M1487_M1489_486_PCI_Chip_Set_199707.txt (101), 1994_Intel_Peripheral_Components.txt (84), 82C700_Firestar_Single-Chip_Notebook_Solution_199702.txt (70). held for the emulator (86SMM), not for a document: 8259:669-681 already decides; no change.
- **TCROUND** (1 rows: T2X-TCROUND). terms: time constant; TC table; sample rate table; 1 MHz; 1MHz; hits 217 in 29 files; most: Sound_Blaster_Series_Hardware_Programming_Guide.txt (39), 1994_Intel_Peripheral_Components.txt (25), Developer_Kit_SB_Series_Hardware_Programming_Reference.txt (24), 241732-003_Pentium_and_Pentium_Pro_Processors_and_Related_Products_1996.txt (19), 1996_Intel_Peripheral_Components.txt (15), 241731-002_Intel486_Microprocessors_and_Related_Products_1995.txt (14). SBG's formula (1249-1257, 3553-3568) and the 4.13 firmware table; SB202SPEC's 1 MHz timer concerns the DSP 2.0x, not the SB16; held for the CT2290's measured table (question 30); no change.

Accepted (Michael, 28 Oct 2026): the standing reasons above, as written. Carried into the matrix by r3.7 (T9 item 3, method 010ef0c): each silent row's `searched` line from libsearch.py --searched with these terms (the planted rows: "planted fault"); libsearch also searches the fork's own specifications, and its new hits there were read and change no row (HOSTCD M-4 for PREGAP, the volume size; SPECFIRST, uCDD's own resampler design, for the resampler's tolerance; ES1888:1553, the ESS's side, for PROST2).
