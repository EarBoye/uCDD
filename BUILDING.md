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

- `--flat-sink`: when a 32-bit program calls a real-mode service with a flat data segment in DS or ES, pass segment `A000h` to real mode, not segment 0. A service that writes through an untranslated pointer then cannot damage low memory.

The release source archive contains the project source and this build script. Install DOS, a memory manager, and a CD redirector separately. No third-party programs are included.
