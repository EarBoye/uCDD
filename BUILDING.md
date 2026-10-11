# Build from source

Install Python 3 and NASM. Run this command from the source directory:

```console
python scripts/build.py --resident-audio
```

The output files are `build/UCDD.EXE`, `build/UCDDSET.EXE`, and `build/UCDDPLAY.EXE`. The driver contains the internal audio host. The build does not download dependencies.

The UCDDPLAY graphics and tables are in `src/play/assets.bin` and `src/play/assets.inc`. The scripts in `src/play/art` make them. To make them again, install Blender and Pillow. Render `faceplate.py` and `logo.py` with Blender. `faceplate.py` writes the faceplate and a mask of its corner shells. Then run `assets.py` with the three images.

For a CD driver without resident audio, omit `--resident-audio`.

## Build options

These options apply with `--resident-audio`.

- `--audio-period-frames N`: set the output period to 32, 64, 128, or 256 frames. The default is 32. A larger period makes fewer interrupts and costs less CPU time, with more delay: 256 frames is 5.8 ms at 44.1 kHz. The driver refuses a game's auto-initialize block that lasts less than two periods, so a larger period also leaves more games without sound: 256 frames needs blocks of 11.6 ms, 128 frames needs 5.8 ms.
- `--no-refill-hint`: test option. Refill the CD queue whenever a refill is due, without waiting for the display retrace.

These fixes are in every resident-audio build. Each has a `--no-` option to build without it, for testing:

- `--no-flat-sink`: by default, when a 32-bit program calls a real-mode service with a flat data segment in DS or ES, the driver passes segment `A000h` to real mode, not segment 0. A service that writes through an untranslated pointer then cannot damage low memory.
- `--no-inject-register`: by default, the driver recognises `PUSHF, POP reg, CLI` and `PUSHFD, POP EAX, AND EAX,200h, CLI`, where the saved flags are in a register and not on the stack.
- `--no-split-word-io`: by default, a word access to a trapped sound-card port runs as two byte accesses.

The older options `--flat-sink`, `--inject-register`, `--split-word-io`, and `--disk-irq-direct` are still accepted and change nothing.

### Disk controller IRQs

There is no build option for these. A PCI disk controller holds its level-triggered request until its real-mode handler runs. When a protected-mode game waits in a real-mode call for that disk, the request must go to the handler directly, or the game freezes (DOS/4GW games, at their banner). The driver does this for:

- IRQ 14 and 15,
- the IRQ of every PCI mass storage controller (class 01h) with an interrupt pin, which UCDDSET finds through the PCI BIOS at each `UCDD -install`,
- the IRQ set by hand in the Disk row of UCDDSET, kept in the last byte of UCDD.CFG (0 for none; that byte was always 0 before).

The IRQ of the physical card is never passed. UCDDSET warns when a disk controller uses the IRQ of the physical card, the virtual Sound Blaster, or the virtual WSS codec. A machine without a PCI BIOS uses IRQ 14, IRQ 15, and the IRQ set by hand.

The builds tested on real hardware used this line:

```console
python scripts/build.py --resident-audio --audio-period-frames 256 --no-refill-hint
```

The release source archive contains the project source and this build script. Install DOS, a memory manager, and a CD redirector separately. No third-party programs are included.
