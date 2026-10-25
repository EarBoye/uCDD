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
  (rig86/CLAUDE.md). Consequence: the sound check cannot judge uCDD with
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

### CAND-1 Tier 0, T0-CUE-I02: a CUE sheet with INDEX 02 or higher is refused (found 25 Oct 2026, open)

Pinned: count-position 7994cd1 (C2 hash UCDD.EXE 03d92066, UCDDHOST.BIN 447ace33; C1 hash UCDD.EXE f8d8ec5e; rig86/fixtures/pinned/MANIFEST.txt). Bin: CANDIDATE_UCDD_CDROM, FAIL 10/10 (Tier 0; the template's 3/3 is the sweep's).
Cell: none (Tier 0: cue.asm's prepare_image included unchanged, no game), scope not applicable until A4's image audit counts the library's sheets with INDEX 02.
Affected: not known (A4). Controls: C0, C1 not applicable (Tier 0 runs the module, not the driver).
Observed: T0.TXT `FAIL I02 +carry got 00000001 want 00000000` (prepare_image returns carry: the sheet is refused) in all ten runs (bdae96f1-161 to -170, folders t0c-161 to t0c-170); plan bdae96f1. Expected: the sheet mounts and index 2 is ignored for positioning (README Images, the specification uCDD implements, as Michael read it, 25 Oct 2026, Project A question 6).
Trace: by reading, src/cue.asm:360-361 at the pinned SHA (`cmp ax, 1` / `ja cue_bad`): any INDEX number above 1 refuses the whole sheet. Minimal reproduction: `T0CUE.COM I02` (matrix T0-CUE-I02; bench dos/src/t0/t0cue.asm).
Hypothesis (labelled, not tested): the fix exists and is the author's: Beta 0.9.4-a1 (his a8b57d4, 19 Oct 2026; RELEASE-NOTES "CUE files with a UTF-8 byte-order mark or with INDEX 02 and higher now mount"), on merge-a6 src/cue.asm:385-390 ("Check and ignore an index after INDEX 01"), built, not run; by the merging rule his version is the one kept. Evidence: emulator (plan bdae96f1), dynarec off. Hardware: UNCONFIRMED.

### CAND-2 Tier 0, T0-CUE-BOM: a CUE sheet that starts with a UTF-8 byte order mark is refused (found 25 Oct 2026, open)

Pinned: count-position 7994cd1 (C2 hash UCDD.EXE 03d92066, UCDDHOST.BIN 447ace33; C1 hash UCDD.EXE f8d8ec5e; rig86/fixtures/pinned/MANIFEST.txt). Bin: CANDIDATE_UCDD_CDROM, FAIL 10/10 (Tier 0; the template's 3/3 is the sweep's).
Cell: none (Tier 0: cue.asm's prepare_image included unchanged, no game), scope not applicable until A4's image audit counts the library's sheets with a byte order mark.
Affected: not known (A4). Controls: C0, C1 not applicable (Tier 0 runs the module, not the driver).
Observed: T0.TXT `FAIL BOM +carry got 00000001 want 00000000` (refused) in all ten runs (bdae96f1-181 to -190, folders t0c-181 to t0c-190); plan bdae96f1; the same sheet without the mark (T0-CUE-M1R) mounts in every run. Expected: the sheet mounts (README Images, as Michael read it, 25 Oct 2026, Project A question 6).
Trace: by reading, src/cue.asm:162-197 at the pinned SHA: the first token of each line is matched against the keywords; with EF BB BF before FILE it matches none and the parser takes `jmp cue_bad` (line 197). Minimal reproduction: `T0CUE.COM BOM` (matrix T0-CUE-BOM).
Hypothesis (labelled, not tested): the fix exists and is the author's: Beta 0.9.4-a1 (his a8b57d4, 19 Oct 2026), on merge-a6 src/cue.asm:79-85 (the far form, the driver's mount helper, helper.asm) and 103-109 (the near form, UCDDPLAY), skipping the three bytes before the first line; built, not run; by the merging rule his version is kept. Evidence: emulator (plan bdae96f1), dynarec off. Hardware: UNCONFIRMED.

### CAND-3 Tier 0, T0-ADPCM-3: the virtual Sound Blaster's 2.6-bit ADPCM decodes differently from DOSBox-X (found 25 Oct 2026, open)

Pinned: count-position 7994cd1 (C2 hash UCDD.EXE 03d92066, UCDDHOST.BIN 447ace33; C1 hash UCDD.EXE f8d8ec5e; rig86/fixtures/pinned/MANIFEST.txt). Bin: CANDIDATE_UCDD_SFX, FAIL 10/10 (Tier 0; the template's 3/3 is the sweep's).
Cell: none (Tier 0: audio/sb_adpcm.asm included unchanged, no game), scope not applicable; which games use 2.6-bit ADPCM is A4's engine census to say.
Affected: not known (A4). Controls: C0, C1 not applicable (Tier 0 runs the module, not the driver).
Observed: T0.TXT `FAIL 3 code 3 (byte 1) got 144 want 148; 1475 of 1920 differ` in all ten runs (bdae96f1-281 to -290, folders t0c-281 to t0c-290); plan bdae96f1. The 4-bit and 2-bit cases match DOSBox-X in every code (1280 and 2560; T0-ADPCM-4 and -2 pass). Checked outside the emulator: a Python transcription of both decoders over the same block gives the same counts and the same first difference (bench dos/src/t0/adpcm_model.py). Expected: DOSBox-X's decoder (EMUSRC: src/hardware/sblaster.cpp at f6b476e9, decode_ADPCM_3_sample and the DSP_DMA_3 split), A1's reference, graded emulator (Michael, 25 Oct 2026, question 6).
Trace: by reading, two differences. (1) The third code of a byte: DOSBox-X takes `(b & 3) << 1`, the sign from bit 1 and a magnitude of 0 or 2; sb_adpcm.asm (.two_six with the count at 1) takes the sign from bit 1 and a magnitude of 0 or 1 (`and al, 1`). (2) The largest step: DOSBox-X's fifth row moves 5, 15, 25, 35 (a step of 10); sb_adpcm.asm doubles the step up to 16 (8, 24, 40, 56). The first difference is (1): byte 1 (6Dh) from the reference 128 gives 131 and 138 in both, then 148 in DOSBox-X (magnitude 2 at step 4) and 144 in uCDD (magnitude 1). Minimal reproduction: `T0ADPCM.COM 3` (matrix T0-ADPCM-3; bench dos/src/t0/t0adpcm.asm).
Hypothesis (labelled, not tested): sb_adpcm.asm follows the CT1741 4.05 firmware's 2.6-bit decoder as read from S95Sedan's disassembly (its header); DOSBox-X's tables are an emulator's reconstruction. The fork's own order (vsb-spec.md 0: Creative's documents, then the firmware, then the emulators) ranks the firmware above DOSBox-X; A1 takes DOSBox-X because it forbids the firmware as the reference. Which the card does is the CT2290's to say: AKIT plays one 2.6-bit block (Michael, 25 Oct 2026). Also by reading: the author's decoder, which replaced sb_adpcm.asm on merge-a6 (UPA6, the trap.asm ADPCM line; built, not run), takes three bits a code and the fifth row 5, 15, 25, 35 (merge-a6 src/audio/mix.asm adpcm_decode; trap.asm adpcm_params, adpcm_map3): DOSBox-X's decoding. T0ADPCM cannot run there (it includes sb_adpcm.asm, which merge-a6 no longer has); the card decides between the two decoders. Evidence: emulator (plan bdae96f1), dynarec off; the decoder comparison, reading. Hardware: UNCONFIRMED.

### CAND-4 Tier 1, T1-EJECT and T1-C1-EJECT: after Eject Disk the device status never says the door is open (found 25 Oct 2026, open)

Pinned: count-position 7994cd1 (C2 hash UCDD.EXE 03d92066, UCDDHOST.BIN 447ace33; C1 hash UCDD.EXE f8d8ec5e; rig86/fixtures/pinned/MANIFEST.txt). Bin: CANDIDATE_UCDD_CDROM, FAIL 10/10 under C2 and 10/10 under C1 (Tier 1; the template's 3/3 is the sweep's).
Cell: none (Tier 1: T1.EXE through INT 2Fh on a synthetic disc, no game), scope not applicable; which games watch the door bit is not known.
Affected: not known. Controls: C0 no reference: OAKCDROM with MSCDEX 2.25 on 86Box's own ATAPI drive answers device status 0796h throughout, its lock and door bits never moving (development run t1dev-c0, not recorded; HANDOFF 25 Oct), so 86Box's drive cannot show what a period driver reports for a real tray. C1: the same failure (T1-C1-EJECT).
Observed: T1.TXT `FAIL EJECT device status after Lock 0710, after Unlock 0712, after Eject 0C02; then a read 8102)` in all ten C2 runs (ccb39d17-141 to -150, folders t1a-141 to t1a-150) and `FAIL EJECT device status after Lock 0400, after Unlock 0402, after Eject 0C02; then a read 8102)` in all ten C1 runs (ccb39d17-351 to -360, folders t1a-351 to t1a-360); plan ccb39d17. Lock and unlock answer as asked (bit 1); after the eject bit 11 (RBIL: no disk in drive) is set and bit 0 (door open) is not; the read after it fails with 8102h (not ready), as it should. C1's word lacks 0310h because the CD-only build has no audio (driver.asm:321-323). Expected: bit 0 set from the eject until a disc is put in: MSCDEX:820-823 ("The door will report as being open until the user has inserted a disk into the drive unit and closed the door. The status bit for door open can be monitored to determine when a disk has been reinserted."), MSCDEX:557-558 (bit 0, door open); RBIL: INTERRUP.G:677-690 (table 01450, bit 0 door open, bit 11 no disk in drive).
Trace: by reading, at the pinned SHA: src/driver.asm:305-323 (IOCTL input 6) builds the word from 0400h (M-5), the lock flag (bit 1), an empty unit (bit 11), raw reading (bit 2) and audio (0310h); bit 0 is set nowhere and the unit keeps no door state. src/driver.asm:420-438 (IOCTL output 0) calls eject_unit (1370-1396), which closes the image and clears the unit. Also by reading, not tested by this row: an Eject while the door is locked is refused (420-421, request_error), where MSCDEX:820 has the driver unlock the drive and eject. merge-a6's device status has the same shape (src/driver.asm:332-350, no bit 0): no fix exists on another branch. Minimal reproduction: `T1.EXE EJECT` on T1A (matrix T1-EJECT; T1-C1-EJECT under C1).
Hypothesis (labelled, not tested): a door-open flag set by an eject and cleared at the next mount, reported as bit 0, would answer the document. What a period driver reports for a real tray is the hardware's to say; 86Box's drive cannot. Evidence: emulator (plan ccb39d17), dynarec off. Hardware: UNCONFIRMED.

### CAND-5 Tier 1, T1-AONLY and T1-MDM: a CUE sheet with only audio tracks is refused at the mount, alone or in an MDM list (found 25 Oct 2026, open)

Pinned: count-position 7994cd1 (C2 hash UCDD.EXE 03d92066, UCDDHOST.BIN 447ace33; C1 hash UCDD.EXE f8d8ec5e; rig86/fixtures/pinned/MANIFEST.txt). Bin: CANDIDATE_UCDD_CDROM, FAIL 10/10 in both cases (Tier 1; the template's 3/3 is the sweep's).
Cell: none (Tier 1, no game), scope not applicable; how many of the library's sheets have no data track is A4's image audit to count (the author names Edna and Defender of the Crown, below).
Affected: not known (A4). Controls: C0 not run on T1C. C1: not in the data-path subset.
Observed: T1-AONLY: M.TXT `The image cannot be opened or is not valid.` and T1.TXT `FAIL AONLY no disc: status 8102` in all ten runs (ccb39d17-471 to -480, folders of the same names), so no beep and no capture to judge. T1-MDM: M.TXT `The disc list cannot be mounted. Check its images and XMS memory.` (one message of two lines, helper.asm:783-784) and `FAIL MDM no disc: status 8102` in all ten (ccb39d17-161 to -170, folders t1a-161 to t1a-170); plan ccb39d17. Tier 0's T0-CUE-AONLY passes (cue.asm's prepare_image accepts the same kind of sheet; plan bdae96f1), so the refusal is the driver's mount. A list of T1D and T1A mounts and switches with Ctrl+Alt+2 on the same build (development run t1dev-mdmkeys, not recorded: `PASS MDM (disc 1 T1D; Ctrl+Alt+2: media changed FF, volume T1A)`); T1E.MDM differs from that list by T1C alone. Expected: the disc mounts as a drive holding an audio CD would: Audio Disk Info gives tracks 1 to 3 (MSCDEX:651-660) and PLAY AUDIO plays track 1 (MSCDEX:1030); T1C's case as Project A sets it (gate A2, T1C "audio only, three tracks").
Trace: by reading, at the pinned SHA: src/driver.asm:1155-1158 (mount_image): track 1's control byte, bit 5 masked, must be 40h (a data track), else .reject; after it, 1222-1249 read sector 16 for an ISO 9660 primary volume descriptor ('CD001') and reject without one. An audio first track fails the first test. Minimal reproduction: `UCDD -mount T1C.CUE` (matrix T1-AONLY); `UCDD -mount T1E.MDM` (T1-MDM).
Hypothesis (labelled, not tested): the fix exists and is the author's: Beta 0.9.4-a3 (his beea8ab, 20 Oct 2026, the code; fedc465, 21 Oct, the release note "Mount CUE sheets that have only audio tracks. This fixes Edna and Defender of the Crown."), on merge-a6 src/driver.asm:1270-1285 (mount_image takes an audio first track on a 2352-byte image, candidate_audio: "An audio CD has no data track. Data reads fail as on a drive."); built, not run; by the merging rule his version is kept. Whether an MDM list holding an audio-only disc then mounts is not read. Evidence: emulator (plan ccb39d17), dynarec off; the MDM attribution, a development run. Hardware: UNCONFIRMED.

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

## The feature branches offered to the author (rows reconstructed 24 Oct 2026)

These four issues were ported from the fork's line onto the author's
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
