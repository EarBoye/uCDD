# Build from source

Install Python 3 and NASM. Run this command from the source directory:

```console
python scripts/build.py --resident-audio
```

The output files are `build/UCDD.EXE`, `build/UCDDSET.EXE`, and `build/UCDDPLAY.EXE`. The driver contains the internal audio host. The build does not download dependencies.

The UCDDPLAY graphics and tables are in `src/play/assets.bin` and `src/play/assets.inc`. The scripts in `src/play/art` make them. To make them again, install Blender and Pillow. Render `faceplate.py` and `logo.py` with Blender, then run `assets.py` with the two images.

For a CD driver without resident audio, omit `--resident-audio`.

The release source archive contains the project source and this build script. Install DOS, a memory manager, and a CD redirector separately. No third-party programs are included.
