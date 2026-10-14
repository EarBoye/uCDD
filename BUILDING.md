# Build from source

Install Python 3 and NASM. Run this command from the source directory:

```console
python scripts/build.py --resident-audio
```

The output files are `build/UCDD.EXE`, `build/UCDDSET.EXE`, and
`build/UCDDPLAY.EXE`; `build/UCDDHOST.BIN` is the internal DPMI host, which
`UCDD.EXE` carries inside it. The `build` directory is not kept in git. The
build does not download dependencies.

For a CD driver without resident audio, omit `--resident-audio`.

The UCDDPLAY graphics and tables are in `src/play/assets.bin` and
`src/play/assets.inc`. The scripts in `src/play/art` make them. To make them
again, install Blender and Pillow. Render `faceplate.py` and `logo.py` with
Blender. `faceplate.py` writes the faceplate and a mask of its corner shells.
Then run `assets.py` with the three images.

## Size limits and what takes the room

The resident driver is one 64 KB segment and the host image must fit a
16-bit size, so the script stops when `UCDD.EXE` reaches 65536 bytes or
`UCDDHOST.BIN` reaches 65535. Every feature added to the resident code costs
room there. The installer-only code (the disk scan, the CUE parser, the
command helper, about 19 KB) counts against the same segment although it
never stays resident; moving it to a second segment is the way to make room
when something does not fit.

Figures from the tested build (256 frames, no refill hint), rounded; they
move a little with every change.

**In memory after `UCDD -install`:** the driver image is 42 KB, of which
34 KB is permanent and the last 9.5 KB holds the activation code first and
the DOS swap area and the unit table afterwards. Beside it: the CD work
buffer (6 KB), the output ring (2 KB at 256 frames, 256 bytes at 32), the
tail cache (2 KB) and the host's real-mode gateway and stack (7 KB plus
page alignment). The 64 KB host image itself lives in extended memory
through VCPI.

**The permanent 34 KB by piece:**

| KB | Piece | Notes |
| --- | --- | --- |
| 5.1 | Port trap dispatcher, DSP, DMA and mixer emulation (`audio/trap.asm`) | Core |
| 5.1 | Device driver and MSCDEX requests (`driver.asm`) | Core |
| 4.1 | CD streaming, queue, XMS (`audio/mounted.asm`) | Core |
| 3.2 | General mixer (`audio/mix.asm`) | Core |
| 2.6 | Mixer fast paths (`audio/mix_run.asm`) | About a quarter of the mixer's cost on a 386, about 1 percent of a Pentium |
| 3.3 | JemmEx trap backend and its init (`audio/host_jemm*.asm`) | Core; the init is one-shot but outside the overlay |
| 2.3 | Physical SB16 and ESS output, the interrupt handler (`audio/sb16.asm`) | Core |
| 2.1 | WSS physical output (also the ESS routines), the virtual WSS codec (`audio/wss_*`) | The virtual codec, 1.2 KB, serves few games |
| 1.6 | Multi-disc lists and hotkeys (`mdm.asm`) | A feature, not core |
| 0.9 | Seek cache for image metadata (`audio/disk_cache.asm`) | Fewer FAT walks per refill |
| 0.8 | Virtual PIC (`audio/irq.asm`) | Core |
| 0.7 | SB Pro physical output (`audio/pro_output.asm`) | Only with an SB Pro physical card |
| 0.6 | Single-cycle block patch (`audio/sb_patch.asm`) | Core: short effects |
| 0.5 | CD resampling (`audio/cd_resample.asm`) | Core for the ESS fast mode and the SB 2.0 |
| 0.25 | De-emphasis for PRE tracks (`audio/deemphasis.asm`) | Rare |
| 2.3 | Mixer volume math, timer tick, config, direct DAC, high DMA, state | Small and needed |

Stripping everything that is not core (virtual WSS, SB Pro output, MDM,
de-emphasis) would save 3 to 4 KB and make the binary card-specific; there
is no build option for it. The limits above are the reason to care about
size, not memory: the five blocks fit the upper memory of a machine that
loads JEMMEX.

**The host image (64 KB, extended memory):** the monitor with its
instruction decoder, port traps and exceptions 22.5 KB; the interrupt-flag
site learning and stepping 7.6 KB; real-mode callbacks 5 KB; the DPMI
entry, exit and services 4.3 KB; the real-mode bridge 3.9 KB; vectors,
16-bit DOS translation, nesting, memory, cleanup, descriptors, the PIC,
the switch code and the debug-register support between 0.7 and 2.8 KB
each.

## Build options

These options apply with `--resident-audio`.

- `--audio-period-frames N`: set the output period to 32, 64, 128, or 256 frames. The default is 32. A larger period makes fewer interrupts and costs less CPU time, with more delay: 256 frames is 5.8 ms at 44.1 kHz. The driver refuses a game's auto-initialize block that lasts less than two periods, so a larger period also leaves more games without sound: 256 frames needs blocks of 11.6 ms, 128 frames needs 5.8 ms. See "The output period decides which games have sound" in ISSUES.md.
- `--no-refill-hint`: refill the CD queue whenever a refill is due, without waiting for the display retrace. Without it the retrace and timer ports are trapped, and a protected-mode game that polls the retrace pays for every poll: keep this option on any machine below a Pentium.

Test builds:

- `--verify-mix`: check every mixer half against the general loop and count mismatches; for checking the mixer fast paths, not for use.
- `--profile-host`: event counters and cycle counts in the host, written to `build/profile`. The counters sit in a block tagged `uCDprof` in the host image (extended memory): twelve event dwords from offset 16 (step, decode, gp, cli, dpmi, dos, bridge, allocate, page, flush, irqentry, refill), then the step samples, then the tag `CYC1` at offset 96 and eleven cycle slots of 12 bytes (8 of cycles, 4 of passes) from offset 100: other exceptions, CLI, STI, IN, OUT, the real-mode bridge (outermost pass), a hardware IRQ entry, then the bridge again by what it carries: the timer vector, the physical audio IRQ vector, another interrupt, a far call.
- `--profile-driver`: cycle counts in the resident driver, written to `build/profile`. The block is tagged `uCDDprof` in the resident image: a version byte, a zero, the block size, then seven slots of 12 bytes from offset 12: the physical interrupt handler, mix_half from it, the disc half load and filter, the CD refill from the timer and the deferred refill, the INT 21h read of the image, the XMS writes into the queue, the port callback.

Both cycle counters use RDTSC, so those builds need a Pentium or later; the normal build is unchanged by them.

These fixes are in every resident-audio build. Each has a `--no-` option to
build without it, for comparison with 0.9.3:

- `--no-flat-sink`: by default, when a 32-bit program calls a real-mode service with a flat data segment in DS or ES, the driver passes segment `A000h` to real mode, not segment 0. A service that writes through an untranslated pointer then cannot damage low memory.
- `--no-inject-register`: by default, the driver recognises `PUSHF, POP reg, CLI` and `PUSHFD, POP EAX, AND EAX,200h, CLI`, where the saved flags are in a register and not on the stack.
- `--no-split-word-io`: by default, a word access to a trapped sound-card port runs as two byte accesses.

## Disk controller IRQs

There is no build option for these. A PCI disk controller holds its
level-triggered request until its real-mode handler runs. When a
protected-mode game waits in a real-mode call for that disk, the request
must go to the handler directly, or the game freezes (DOS/4GW games, at
their banner). The driver passes these IRQs to DOS directly:

- IRQ 14 and 15;
- the IRQ of every PCI mass storage controller (class 01h) with an interrupt pin, which `UCDD -install` finds through the PCI BIOS (INT 1Ah B101h, B108h, B109h) before the audio starts. An interrupt line of 0 or FFh, and an IDE controller with both channels in compatibility mode, are skipped. `UCDDPCI=OFF` in the environment skips the scan;
- the IRQ set by hand in the Disk row of UCDDSET, kept in the last byte of UCDD.CFG (0 for none; that byte was always 0 before).

The IRQ of the physical card is never passed. UCDDSET warns when a disk
controller uses the IRQ of the physical card, the virtual Sound Blaster, or
the virtual WSS codec. A machine without a PCI BIOS uses IRQ 14, IRQ 15,
and the IRQ set by hand.

## The tested build

The builds tested on real hardware and in the emulators used this line:

```console
python scripts/build.py --resident-audio --audio-period-frames 256 --no-refill-hint
```

The release source archive contains the project source and this build
script. Install DOS, a memory manager, and a CD redirector separately. No
third-party programs are included.
