# State of this fork

What was tested, how, and what is still open. RELEASE-NOTES.md lists the
changes themselves.

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

- Chasm: The Rift does not run under the driver in 86Box. On
  `host-gauntlet` its RTM passes the DPMI check (D-11), stays resident as
  it is built to (D-12), and the game reaches its start-up screen with
  nested exceptions delivered (D-13); then its runtime reports "Runtime
  error 216" (a general protection fault in the game's code) and exits.
  MSCDEX 2.25 lists nothing on its CD-i Bridge disc under the driver
  (M-5, device status bit 10, a decision); with the disc listed the game
  breaks the DOS memory chain instead, as Beta 0.9.3b did. Runs without
  the driver. docs/host-cdrom-spec.md section 9. The real PC uses SHSUCDX,
  which lists the disc.
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

## Performance

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
