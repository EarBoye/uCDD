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

- `--audio-period-frames N`: set the output period to 32, 64, 128, or 256 frames. The default is 32. A larger period makes fewer interrupts and costs less CPU time, with more delay: 256 frames is 5.8 ms at 44.1 kHz.
- `--flat-sink`: when a 32-bit program calls a real-mode service with a flat data segment in DS or ES, pass segment `A000h` to real mode, not segment 0. A service that writes through an untranslated pointer then cannot damage low memory.
- `--inject-register`: recognise `PUSHF, POP reg, CLI` and `PUSHFD, POP EAX, AND EAX,200h, CLI`, where the saved flags are in a register and not on the stack.
- `--disk-irq-direct`: always pass IRQ 14 and 15 to the real-mode handler. For PCI IDE controllers, which hold a level-triggered request until that handler runs.
- `--split-word-io`: run a word access to a trapped sound-card port as two byte accesses.
- `--no-refill-hint`: test option. Refill the CD queue whenever a refill is due, without waiting for the display retrace.

The builds tested on real hardware used all of them:

```console
python scripts/build.py --resident-audio --audio-period-frames 256 --no-refill-hint --disk-irq-direct --split-word-io --inject-register --flat-sink
```

The release source archive contains the project source and this build script. Install DOS, a memory manager, and a CD redirector separately. No third-party programs are included.
