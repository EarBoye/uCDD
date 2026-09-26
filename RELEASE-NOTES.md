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
