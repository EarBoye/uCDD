# Build from source

Install Python 3 and NASM. Run this command from the source directory:

```console
python scripts/build.py --resident-audio
```

The output files are `build/UCDD.EXE`, `build/UCDDSET.EXE`, and `build/UCDDPLAY.EXE`. The driver contains the internal audio host. The build does not download dependencies.

The UCDDPLAY graphics and tables are in `src/play/assets.bin` and `src/play/assets.inc`. The scripts in `src/play/art` make them. To make them again, install Blender and Pillow. Render `faceplate.py` and `logo.py` with Blender. `faceplate.py` writes the faceplate and a mask of its corner shells. Then run `assets.py` with the three images.

For a CD driver without resident audio, omit `--resident-audio`.

## Build options

These options apply with `--resident-audio`. All are off by default.

- `--disk-irq-direct`: always pass IRQ 14 and 15 to the real-mode handler. For PCI IDE controllers, which hold a level-triggered request until that handler runs.

The release source archive contains the project source and this build script. Install DOS, a memory manager, and a CD redirector separately. No third-party programs are included.
