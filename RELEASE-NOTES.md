# Fork changes (`fixes` branch, unreleased)

These changes are on top of Beta 0.9.3b. ISSUES.md records how each was
tested; the ones marked hardware ran on a Pentium MMX 233 with an ESS
ES1868, the rest in emulators (QEMU, DOSBox-X, 86Box with MS-DOS 7.1 and
JemmEx).

## Requirements

- Microsoft EMM386 is no longer supported. JEMMEX 5.86 or 5.87 was already required for CD-Audio; its port-trap interface reaches the DMA controller, which EMM386's does not.

## Disc images and the CD driver

- Mount discs with non-standard root directory headers (Hexen, Duke Nukem 3D Atomic). Hardware.
- Clamp a volume space larger than the image instead of refusing it, for data tracks ripped from mixed-mode discs.
- Keep CD audio refills running with a 256-frame output period. Hardware.
- Switch discs from the hotkeys without re-entering DOS with the game's PSP and without the DOS state swap. A game with a file open on the same handle number no longer loses its file position.
- Park INT 23h during CD reads, so that Ctrl+C or Ctrl+Break with BREAK=ON does not end the resident driver.
- Unmount by CUE sheet name; `-unmount NAME.CUE` matches a mount made from that sheet.
- Install without `DOS=UMB` or on FreeDOS; a DOS that cannot link UMBs no longer fails the install.
- MSCDEX details: interleave size and skip are ignored, Read Long takes Red Book addresses, Stop and Seek on a unit without audio return done, Eject works while the driver's own audio is bound, audio channel control accepts every mapping, the volume size is the disc up to the lead-out, the track control byte carries ADR 1, the raw sector size is 2352, a bad request length is error 5, a transfer address above 1 MiB returns general failure, and the media-changed answer stays "changed" after the mounting helper's own query until the redirector reads the disc.
- Fix memory corruption after exit when a game passes a protected-mode pointer to MSCDEX: a flat segment is reflected to real mode as segment A000h, not 0. Hardware.
- Find the PCI disk controllers at `UCDD -install` through the PCI BIOS and pass their IRQs to DOS directly, with IRQ 14 and 15 and an IRQ set by hand in UCDDSET. A DOS/4GW game no longer freezes at its banner on a machine whose disk controller uses another IRQ. `UCDDPCI=OFF` skips the scan.

## Sound card emulation and output

- Native ESS AudioDrive output through the chip's extended mode at 44.1 kHz, with a half-rate model that costs less CPU time. Register BAh is written only on an ES1868 or ES1878. Hardware, ES1868.
- Single-cycle playback: a new sound no longer writes past the output buffer at large output periods, very short blocks are accepted (Sierra's driver test in King's Quest V), the same on a slow CPU, and a click between two close blocks is gone.
- DSP command parsing: a refused command or argument clears the argument counter; a rate is checked before it is stored, so a rate of 0 no longer divides; exit auto-initialize while paused is applied at the resume; 41h/42h set the rate of the legacy commands too; A0h and A8h are accepted; 20h answers 80h, F8h answers 0, F3h raises the 16-bit interrupt; the status ports read 7Fh/FFh in the undefined bits; the SB16 stop resets the DSP.
- Virtual mixer: FM register 26h starts at FFh like its 5-bit twins, so a driver that saves and restores the mixer no longer leaves the FM volume at the lowest step.
- 8237 emulation: the command, master clear, all-mask and status registers of both controllers are trapped. Master clear and all-mask keep the owned channel virtual and the output ring unmasked, and stop and resume the stream as the controller would; write-only registers read FFh.
- Virtual PIC: the rotate forms of the end-of-interrupt commands, set priority, special mask mode and poll are accepted; after an ICW1 the ICW2 to ICW4 bytes are counted off instead of being written to the mask. An EOI from a real-mode handler whose interrupt the DPMI host had already ended is no longer taken for the game's own.
- Virtual PIC: an EOI is credited to the virtual Sound Blaster interrupt only once that interrupt has reached the game's handler. Doom's effects no longer turn into a wash with the physical and the virtual card on IRQ 7. A signalled interrupt left unacknowledged for two periods is raised again.
- The mixer is faster on a 386: unity-gain variants, inlined interpolation, doubleword moves. Bit-identical output, checked with the `--verify-mix` build.
- WSS: the board register's IRQ codes follow the documented table; the codec start no longer fails when the calibration bit is never seen set; the ESS mixer registers the start writes are put back at the stop.
- The interpolation of the last CD frame of a half no longer reads one frame past the data loaded at output rates above 44.1 kHz.
- More interrupt-flag patterns recognised (the flags image in a register), and a larger, hashed table of learned sites. Hardware, benefit partly confirmed.

## DPMI host

- A program's protected-mode handlers for INT 1Ch, 23h and 24h are called for the real-mode timer tick, Ctrl+Break and critical errors, as DPMI 0.9 section 2.4.2 asks. An INT 24h handler's answer and an INT 23h handler's carry go back to DOS.
- A program that DOS ends from real mode (a critical error answered with Abort, an INT 23h handler asking for the end) is released: the host hooks the program's terminate address, frees its state and vectors, and the next DPMI program starts. Before, the host stayed busy until reboot.
- INT 20h and INT 21h AH=00h or 31h from a program end it as AH=4Ch does, instead of ending the DOS process under the host.
- A real-mode callback of a suspended parent program (a mouse handler armed before a child started) no longer ends the child.
- The hardware PIC masks a child program leaves behind are put back when it exits.
- 0800h maps a physical range below 1 MiB to itself instead of refusing it.
- INT 2Fh AX=1686h answers AX=0 in protected mode; a 0302h procedure is entered with interrupts off; software INT 0 to 7 reach a protected-mode handler with virtual interrupts off; exceptions 1, 3, 4 and 5 without a handler are reflected as real-mode interrupts; the return from a real-mode callback honours the ES:(E)DI the program returns with.
- Spurious IRQ 7 and 15 are dropped by the real-mode bridge stubs (IRQ 7 unless the virtual Sound Blaster is on it); the PIC read register is put back after the in-service probes; the spurious cascade EOI is specific.
- Less time on a 386: the pending test comes before the controller reads, the general protection fault decoder fetches four code bytes with one page walk, the real-mode transfer copies doublewords, and the plain EOIs with nothing virtual to end are answered in the host.

## UCDDSET

- A **Program** button writes the physical IRQ and DMA channels into a jumperless Sound Blaster 16 (DSP 4.xx) through mixer registers 80h and 81h and reads them back.
- A **Disk** row shows the PCI disk controllers found at install, takes an IRQ by hand for one the BIOS does not report, and warns when a controller shares an IRQ with a sound card setting.
- The WSS and ESS stop put the old IRQ handler back on the right vector. Under MS-DOS 7.1 with the card on IRQ 7 the wrong vector was the timer's, and the machine stopped taking interrupts after Test.
- A review of the setup program: the SB Pro start waits for its priming interrupt by port reads instead of loop turns; the SB Pro stop masks the IRQ before the DSP reset; the real-mode handler checks the in-service bit for IRQ 7; INT 23h and 24h handlers, so Ctrl+Break no longer ends the program with vectors hooked; a kept BLASTER field is bounded; MDA, Hercules and CGA adapters get the right video segment and mode, and the previous text mode and line count come back on exit; a CPU check before 386 instructions; the detection's 8237 programming runs with interrupts off.
- The Disk row text stops before the IRQ field.

## Build

- `--audio-period-frames`, `--no-refill-hint`, `--verify-mix` and `--profile-host` as described in BUILDING.md. The flat sink, register flags image and word I/O split are in every resident-audio build.

# Beta 0.9.3b

## Changes in 0.9.3b

- Add a Tunnel visualization to UCDDPLAY. Wireframe rings move toward the edge of the bottom window, with speed set by the audio level.
- Allow a DPMI program to start another 16-bit or 32-bit DPMI program and resume when it exits. This lets the Batman Forever installer run its video test and lets Battle Arena Toshinden SETUP start SSETUP.
- Preserve the driver information passed through interrupt E9h by 32-bit programs. This fixes the "DLL load aborted" error when 3dfx games load GLIDE2X.OVL.

# Beta 0.9.3a

## Changes in 0.9.3a

- Add physical audio CD playback to UCDDPLAY.EXE through digital audio extraction. Select a compatible CD drive in Open and use the equalizer, track controls, volume, and eject without an internal audio cable.
- Add a Plasma visualization to UCDDPLAY and rename Stars to Warp Speed.
- Show bordered buttons in UCDDSET and make the virtual-card setup instruction clearer.
- Accept PRE, DCP, 4CH, and SCMS flags in CUE sheets. This lets Destruction Derby mount its CUE sheet without removing the flags.
- Apply CD de-emphasis to audio tracks marked PRE.
- Reduce loading delays caused by protected-mode timer calibration loops, including those in Rayman By His Fans and Rayman Designer.
- Support debug-register access and exception reflection in protected-mode games. This fixes the startup failure in Rayman.
- Support CUE images with a MODE1/2048 data track followed by raw audio tracks. This fixes mounting the CD edition of Betrayal at Krondor.
- Support protected-mode CPU checks used by Little Big Adventure 2 and word writes to the Sound Blaster mixer used by Little Big Adventure.
- Allow larger parameter lists for DPMI real-mode calls. This fixes VESA initialization in Little Big Adventure.
- Fix real-mode interrupt chaining from protected-mode programs. This fixes the startup freeze in Soccer Kid.
- Correct Sound Blaster mixer detection, volume steps, and CD volume control used by Corridor 7.
- Add Betrayal at Krondor, Corridor 7: Alien Invasion, Destruction Derby, Destruction Derby 2, Little Big Adventure, Little Big Adventure 2, Rayman, Rayman 60 Levels, Rayman By His Fans, Rayman Designer, Return to Zork, and ShadowCaster to the list of working Redbook-audio games.
- Add a special thanks section for davidmorom's game testing and compatibility reports.

# Beta 0.9.3

This update adds support for 16-bit DPMI programs, changes how protected-mode games use DPMI and VCPI, and moves all sound card settings into UCDDSET. It adds UCDDPLAY, a CD player for uCDD drives. It also fixes CD-Audio and game sound in many protected-mode games.

## Changes in 0.9.3

- Keep all settings in a new version of UCDD.CFG. `UCDD -install` runs UCDDSET, which must be in the directory of UCDD.EXE. UCDDSET loads the settings, copies them into the driver, and sets BLASTER for the virtual Sound Blaster. It keeps the other BLASTER fields. UCDD no longer reads BLASTER. UCDDSET opens its menu when UCDD.CFG is missing, from an older version, or not valid.
- Initialize the physical card before `UCDD -install`. uCDD no longer sets the IRQ and DMA channels of Sound Blaster 16 and WSS cards.
- Redesign UCDDSET with settings for the physical card, the virtual Sound Blaster, and the virtual WSS codec, and with Hotkeys and Mixer pages.
- Detect the physical card. UCDDSET finds Sound Blaster 16 cards through the mixer, older Sound Blaster cards through an interrupt and DMA test, and WSS codecs. BLASTER supplies only the values that the tests cannot find.
- Select the virtual Sound Blaster model: Sound Blaster 16, Sound Blaster Pro, or Sound Blaster 1.5/2.0. The model sets the DSP version and the BLASTER type. Set the port and the start IRQ of the virtual WSS codec.
- Select the hotkey modifiers, including the Windows key, the disc keys (1 to 0 or F1 to F10), and keys for the next disc, the previous disc, eject, and the CD-Audio volume. Eject and insert discs with a hotkey, for MDM lists and single images.
- Set the start level of CD-Audio, the wave output level, the master volume of the physical card, and the step of the volume hotkeys.
- Fix a crash after UCDDSET returned when UCDD.CFG was missing at installation.
- Shorten the command help of UCDD and UCDDSET.
- Add UCDDPLAY, a VGA CD player for uCDD drives. It has a 10-band equalizer for CD-Audio, a spectrum analyzer, VU meters, shuffle and repeat modes, mouse support, and a requester that mounts and ejects images and MDM lists.
- Support 16-bit DPMI programs, including DOS call translation for Borland Pascal 7 programs, and allow more protected-mode selectors. This fixes the startup failure in Chasm: The Rift.
- Hide the JEMMEX VCPI interface from protected-mode games while uCDD provides DPMI, so that game sound goes through uCDD. Add the `-vcpi` install option for programs that need VCPI. This fixes missing sound and music in Cyberball and Amazing Learning Games with Rayman, and the freeze at the name prompt in An Elder Scrolls Legend: Battlespire.
- Reduce the cost of interrupt-flag emulation for protected-mode games. This removes the slowdown during file access in DOS/4GW games such as Bust-A-Move 2.
- Stop single-stepping protected-mode interrupt and exception handlers.
- Support nested raw mode switches and preserve FS and GS across them. Let disk interrupts reach the BIOS during background CD reads. Accept CD IOCTL input requests with a zero transfer count. This fixes the startup freeze in Absolute Pinball.
- Report the busy status during CD-Audio playback on every request. This fixes repeated music restarts in Batman Forever: The Arcade Game.
- Report the DMA current address and page registers, and accept DSP command 42h. This fixes the startup exception and slow sound setup in Blood.
- Deliver Sound Blaster interrupts during real-mode calls from protected-mode games, and keep interrupt vectors that sound drivers change during a host call. This fixes the freeze at the loading screen in Bust-A-Move 2.
- Accept short auto-initialize blocks, and blocks longer than the DMA buffer. This fixes missing table sounds in Cyberball and missing effects in Cyber Police.
- Support Sound Blaster 16 mixer resets and voice volume registers. This fixes quiet effects in Battle Race.
- Accept Sound Blaster output rates up to 48000 Hz. Support 16-bit mono and unsigned 16-bit game sound.
- Apply the voice level and the wave output level to direct DAC output.
- Support MODE2/2352 Form 1 data tracks in CUE sheets.
- Keep free conventional memory contiguous when DOS loads UCDD into conventional memory and uCDD moves the audio service into upper memory.
- Add Absolute Pinball, Amazing Learning Games with Rayman, An Elder Scrolls Legend: Battlespire, Batman Forever: The Arcade Game, Battle Race, Blood, Bust-A-Move 2 Arcade Edition, Chasm: The Rift, Cyber Police (CYBERPO1.EXE), and Cyberball to the list of working Redbook-audio games.

# Beta 0.9.2c

## Changes in 0.9.2c

- Support advisory CD prefetch requests used by Gobliiins and Gobliins 2.
- Support Sound Blaster direct DAC speech and effects. Support single-cycle 8-bit mono DMA samples above 1 MiB with the JEMM audio backend.
- Prevent a lockup when background CD reads interrupt hardware interrupt handlers.
- Accept contiguous CD reads with a nonzero interleave size and allow reads beyond the ISO volume size within the data track. This fixes resource reads in Fascination.
- Preserve CD information buffer counts and report active CD playback correctly. This fixes repeated music restarts in Future Wars.
- Improve Sound Blaster detection and short-sample interrupt response for The Secret of Monkey Island.
- Correct the DOS startup stack layout for larger executables.
- Keep free conventional memory contiguous when loading the audio service into upper memory.
- Add Fascination, Future Wars, Gobliiins, Gobliins 2: The Prince Buffoon, Goblins Quest 3, and Lost in Time to the list of working Redbook-audio games.
- Add Descent II: Vertigo Series, The Manhole, The Secret of Monkey Island, Realms of Arkania III: Shadows over Riva, and the German CD editions of Realms of Arkania: Blade of Destiny and Star Trail to the list of working Redbook-audio games.
- Add Alien Trilogy, Battle Arena Toshinden, BC Racers, Big Red Racing, and Blam! Machinehead to the list of working Redbook-audio games.

# Beta 0.9.2b

## Changes in 0.9.2b

- Support PREGAP in CUE sheets, with silent gaps and corrected track positions. This lets Loom use its original disc layout and play complete voice prompts.
- Preserve the physical audio interrupt handler when real-mode games write interrupt vectors directly under JEMMEX. This fixes stalled playback and sustained tones in the Alone in the Dark games.
- Add Loom and Alone in the Dark 1, 2, and 3 to the list of working Redbook-audio games.

# Beta 0.9.2a

## Changes in 0.9.2a

- Improve WSS compatibility with Plug and Play codecs, including Crystal CS4236B cards.
- Support IRQ 5 for WSS output and let UCDDSET select IRQ 5 or 7.
- Document the WSS settings for Plug and Play cards.

# Beta 0.9.2

## Changes in 0.9.2

- Batch raw BIN sector reads and compact their payloads in place. This reduces DOS reads and seeks for multi-sector requests.
- Defer blocked timer, keyboard, and mouse interrupts for protected-mode games. This fixes missed key releases and mouse-triggered slowdown in Descent II.
- Add a build-time audio output period option for testing. The standard build retains its 32-frame period.
- Add Descent II to the list of working Redbook-audio games.

# Beta 0.9.1e

This update improves sound playback in Pro Pinball: The Web, reduces audio and protected-mode processing overhead, and lowers conventional-memory use.

## Changes in 0.9.1e

- Support shorter game DMA buffers and reduce audio output latency. This fixes the repeated sound-effect stutter in Pro Pinball: The Web.
- Reduce mixer overhead for silent output, CD-Audio, and 16-bit stereo game sound. Reuse CD samples between output blocks to reduce extended-memory transfers.
- Schedule background CD reads to give games more time to refill their sound buffers. Avoid redundant seeks and add an optional extended-memory cache for disc-image file metadata.
- Preserve pending hardware interrupts while a protected-mode game disables virtual interrupts. Reduce overhead when games poll the timer, display status, or sound card.
- Process simple protected-mode instructions in bounded batches and reduce repeated code and buffer checks.
- Release the host's page-setup workspace after installation. This saves 7.5 KiB of conventional memory when the driver is loaded high.
- Add Pro Pinball: The Web and Pro Pinball: Timeshock! to the list of working Redbook-audio games.

# Beta 0.9.1c

This update fixes Battle Chess Enhanced CD-ROM sound and disc compatibility, and Tomb Raider's shared-IRQ startup failure.

## Changes in 0.9.1c

- Accept mixed-mode disc images whose ISO volume size extends into the audio tracks, while keeping data access within the data track. This fixes mounting the original Battle Chess CUE/BIN image without changing its track boundaries.
- Accept legacy CD control requests used by Battle Chess. This restores CD-Audio playback.
- Support the short Sound Blaster recording transfer used for DMA detection. This fixes Battle Chess's DMA-channel error in original Sound Blaster mode.
- Support combined SB Pro mixer writes and odd-length stereo transfers. This fixes missing or incorrect Battle Chess sound effects in SB Pro mode.
- Honor SB Pro PCM volume and output-filter settings for cleaner legacy sound effects. CD-Audio and SB16 PCM playback retain their existing output quality.
- Preserve the physical audio interrupt handler when protected-mode games write interrupt vectors directly. This fixes Tomb Raider's startup failure when the physical and virtual cards share IRQ5 under JEMMEX.
- Use JEMMEX as the default memory manager in the setup instructions. EMM386 support remains best effort.

# Beta 0.9.1b

This update improves CD access and loading speed in protected-mode DOS games.

## Changes in 0.9.1b

- Support stack arguments in DPMI real-mode interrupt and far-call services. This fixes CD-ROM initialization errors in Pro Pinball: The Web and Timeshock.
- Accept short, non-interleaved CD read requests. This fixes the CD prompts in Screamer, Screamer 2, and Screamer Rally.
- Reuse extended-memory pages and reduce page-table updates, memory clearing, and interrupt-stepping overhead to improve loading speed with resident audio.
- Correct the distinction between a protection fault and physical IRQ 5 under EMM386. This prevents the Screamer reset when CD audio starts with that interrupt configuration.
- Add an optional host-profiling build without adding counters to the normal release build.

# Beta 0.9.1a

This update corrects interrupt timing in the internal protected-mode host. It retains the audio changes from Beta 0.9.1.

## Changes in 0.9.1a

- Honor the one-instruction interrupt delay after `STI`. Preserve this state across callbacks and defer pending hardware and sound interrupts until delivery is permitted.
- Allocate a separate entry stack for the standalone development host, and free it when the host exits. This avoids the layout-sensitive stack failures seen while testing the larger host.
- Document Microsoft EMM386's shared-DMA limitation and the JEMMEX or separate-channel alternatives. This release does not attempt to recover physical DMA programming after a game overwrites it.


# Beta 0.9.1

This beta fixes CD access and mixed-audio problems in protected-mode DOS games. CD music and game PCM still use the same physical Sound Blaster output.

## Changes

- Correct interrupt delivery during protected-mode disk calls and real-mode callbacks. This fixes the reproduced Tomb Raider startup stall after the DOS/4GW banner.
- Run background CD reads after the protected interrupt handler returns. This fixes Tomb Raider effects that played a short beginning and then restarted while CD music was active.
- Keep hardware interrupt requests pending when all four interrupt stacks are in use. This prevents the reproduced interrupt-stack exhaustion abort without adding more stacks.
- Correct interrupt stepping, mixed-width return frames, and nested stack ownership. Process supported REP copy/fill instructions in bounded batches.
- Preserve the physical audio interrupt route when games change their virtual PIC mask. Keep real-mode port traps active during protected-mode calls and route sound interrupts to the handler that owns them.
- Correct the PCM consumption clock, pause behavior, non-power-of-two DMA rings, and single-cycle 16-bit transfers. A small tail cache preserves samples while a game refills its ring buffer.
- Support the reset-port read and short stereo transfer used by Archimedean Dynasty during sound detection.
- Recover CD playback after a queue underrun and increase the refill budget. Failed XMS operations still stop playback.
- Correct callback-slot reuse and host cleanup ordering.
- Support the changed port-trap callback interface tested with JEMMEX 5.87pre1, as well as 5.86.
