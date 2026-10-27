# STEPASIDE: the driver steps aside when it has nothing to add

When nothing mounted needs CD audio and the physical card can be the
virtual one, the driver steps out of the way, and games run on the real
card as fast as they do without μCDD. Developed on the EarBoye/uCDD fork
and ported here onto Beta 0.9.4-a6. On this base it is built and not yet
run.

## Why

The resident audio driver costs a game speed even when the game plays no CD
audio: the output stream runs, the ports are trapped and the DPMI host takes
the protected-mode programs. Measured on a Pentium MMX 233 (430HX) with an
ESS ES1868 streaming at the half rate: 9 to 10 percent of memory bandwidth
and 11 to 19 percent in Doom and Quake, with or without sound. Most of a
game library has no CD audio, and on most machines the physical card can be
the virtual one at the same settings.

## The change

While no mounted image is bound for CD audio and the physical card can
stand in for the virtual one at the same port, IRQ and DMA channels, the
driver steps aside: the physical output stops, the card's and the DMA
controllers' ports are untrapped (the keyboard port stays, for the hotkeys),
and the host neither offers DPMI (INT 2Fh AX=1687h chains) nor hides VCPI
(INT 67h AX=DE00h chains). A game then talks to the real card and runs as
it does without the driver. Mounting an image with audio tracks, or an MDM
list with one, brings the driver back. The state changes only at a mount, an
eject and the end of the install, never while a game runs.

- `src/audio/standby.asm` (new): `audio_reconsider` decides, `audio_release`
  steps aside, `audio_engage` comes back (the install's tail again: a silent
  ring, the ports, the card, the host). Neither while a game streams through
  the virtual card or a client runs under the host.
- `src/audio/pairing.asm` (new): when the physical card can be the virtual
  one. An SB16 is every virtual model (its own needs the same high DMA
  channel too); an SB Pro is an SB Pro or an SB 1.5/2.0; an SB 1.5/2.0 only
  itself; a WSS codec never. UCDDSET greys its box by the same rule.
- `src/driver.asm`: the control entry reconsiders after a mount, an MDM
  mount and an eject. `src/audio/resident_init.asm`: at the end of the
  install, with nothing mounted.
- `src/mdm.asm`: an MDM list counts as an audio disc when any member is
  bound for CD audio (`mdm_audio`), so a hotkey never changes the state.
- `src/audio/trap.asm`: `trap_release` and `trap_engage` give the ports back
  and trap them again.
- `src/audio/sb_patch.asm`: while aside, `sb_dos_vector` lets a game's INT
  21h set of the card's vector through to DOS.
- `src/host/dpmi.asm`: `dpmi_dormant`, offset 10 of the host's resident
  state (after the author's bytes 4 to 9), which the driver sets; INT 2Fh
  AX=1687h and INT 67h AX=DE00h chain while it is set.
- UCDDSET: "uCDD driver always on", a tick box (the tick item is new in
  `src/setup/screen.asm`). Ticked, the driver never steps aside. Greyed,
  with its value kept, while the cards cannot pair.
- `UCDD.CFG` version 5 (45 bytes): version 4's record, then the switch at
  offset 43; offsets 42 and 44 are reserved for the fork's disk IRQ and
  fast DMA branches, which use the same layout. Version 2 and 4 files read
  as before; the new bytes read 0 (the driver may step aside).

## What was tested

On the fork's own line (0.9.3b and the fork's changes), in 86Box:
- 120 transitions (an audio CUE, a data ISO, an MDM list with the audio
  disc second) leave the interrupt vectors, the PIC masks, the trapped-port
  table, the DMA and the mixer state byte-identical to a fresh install when
  aside, and to the engaged driver when a disc is bound.
- Aside, Doom's timedemo equals the boot without the driver: 1558 realtics
  both on the Pentium template; on the 386 template within 0.2 percent,
  against 20 percent slower engaged.
- Every pairing rule checked both ways; a version 2 UCDD.CFG installs.
- Two defects found and fixed on the way: a list with its audio disc second
  stayed aside, and the stop's vector restore was taken by the driver's own
  INT 21h hook (the `sb_dos_vector` check above).
- Not run: hotkeys mid-game on a list, UCDDPLAY's physical-disc mode. Not
  run as a test on the real PC.

On this branch (the change ported onto 0.9.4-a6): built at 128 and 32
frames and without resident audio. Not run yet.
