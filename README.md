## About this fork

This is a fork of vorvek's μCDD. All credit for the driver is his. The
changes in this fork were written with Claude, tested on real hardware where
noted, and otherwise in emulators (QEMU, DOSBox-X and 86Box with MS-DOS 7.1,
JemmEx and a DPMI test client). [ISSUES.md](ISSUES.md) records the state of
each change and what is still open; [RELEASE-NOTES.md](RELEASE-NOTES.md)
lists the changes; [BUILDING.md](BUILDING.md) gives the build options.

The `fixes` branch holds everything. The changes were made on branches of
their own and folded in; those branches are gone, and the commit messages
carry the test notes.

Tested on real hardware (Pentium MMX 233, 430HX, ESS ES1868, Voodoo 1,
Promise Ultra133) across a large DOS game library:

- Discs with non-standard root directory headers mount (Hexen, Duke Nukem 3D Atomic).
- No memory corruption after exit when a game passes a protected-mode pointer to MSCDEX.
- More interrupt-flag patterns recognised, and a larger table of learned sites.
- CD audio refills keep running with a 256-frame output period.
- Native ESS AudioDrive output, with an optional half-rate mode.

Tested in emulators:

- A PCI disk controller on any IRQ no longer freezes DOS/4GW games. `UCDD -install` finds the controllers through the PCI BIOS and passes their IRQs to DOS directly; UCDDSET shows them in a Disk row and takes an IRQ by hand for one the BIOS does not report.
- Single-cycle playback: a new sound no longer loses its first milliseconds at large output periods, and very short blocks are accepted (King's Quest V's driver test).
- A review of the whole driver and a second pass against the hardware and interface specifications in `docs/references`, with the fixes listed in ISSUES.md: DOS re-entry from the disc hotkeys, Ctrl+Break during CD reads, DSP command parsing, the 8237 and 8259 emulation, MSCDEX details, the DPMI host's handling of program exits, callbacks, faults and the INT 1Ch/23h/24h handlers of protected-mode programs.
- Doom's effects turning into a wash with the physical and the virtual card on IRQ 7: fixed.
- UCDDSET: a review of the setup program, and a **Program** button that sets a jumperless Sound Blaster 16.

Microsoft EMM386 is no longer supported; JEMMEX was already required.

The build line used for testing is:

```console
python scripts/build.py --resident-audio --audio-period-frames 256 --no-refill-hint
```

The period is a trade: 256 frames costs the least CPU time but leaves some
games without sound. See "The output period decides which games have sound"
in ISSUES.md before choosing.

The original README follows, updated where the fork changed things.


# μCDD

**Eternal betaware**

μCDD is a virtual CD-ROM driver for DOS. It mounts disc images from a local hard disk and plays their CD-Audio through the sound card, mixed with the game's own sound.

## Requirements

- 386 or later, DOS 5 or later, and a CD redirector: [SHSUCDX](http://adoxa.altervista.org/shsucdx/) or MSCDEX.
- For CD-Audio: [JEMMEX](https://github.com/Baron-von-Riedesel/Jemm) 5.86 or 5.87, which provides the XMS, VCPI and port-trap services the audio driver needs, including the port-trap callback interface changed in 5.87pre1. HIMEM alone does not provide these, and Microsoft EMM386 is not supported: its port-trap interface cannot reach the DMA controller, so a game could take over the physical audio transfer.
- A Sound Blaster (1.5/2.0, Pro, or 16), a Windows Sound System codec, or an ESS AudioDrive. **Initialize the card before `UCDD -install`.** μCDD does not configure it. Set the jumpers, or run the card's Plug and Play or setup utility (CTCM, UNISOUND, and so on) first. A jumperless Sound Blaster 16 without Plug and Play can be set from UCDDSET with **Program**.

**Protected-mode game support is incomplete.**

**Note:** CD-Audio performance on anything below a Pentium processor may be lacklustre. Uncompressed audio requires around 800KB/s of constant read speed.

## Setup

Copy `UCDD.EXE` and `UCDDSET.EXE` into one directory and run `UCDDSET`.

<table>
  <tr>
    <td align="center" width="33%">
      <strong>Card settings</strong><br>
      <a href="docs/ucddset.png"><img src="docs/ucddset.png" alt="UCDDSET physical and virtual sound card settings" width="100%"></a><br>
      <sub>Set the physical and virtual cards.</sub>
    </td>
    <td align="center" width="33%">
      <strong>Hotkeys</strong><br>
      <a href="docs/ucddset-hotkeys.png"><img src="docs/ucddset-hotkeys.png" alt="UCDDSET hotkey assignments and modifier keys" width="100%"></a><br>
      <sub>Choose resident hotkeys.</sub>
    </td>
    <td align="center" width="33%">
      <strong>Mixer</strong><br>
      <a href="docs/ucddset-mixer.png"><img src="docs/ucddset-mixer.png" alt="UCDDSET CD audio, game audio, and master volume controls" width="100%"></a><br>
      <sub>Set audio levels and volume steps.</sub>
    </td>
  </tr>
</table>

- **Physical** is the card in the machine. μCDD plays the mix on it. For a Plug and Play WSS codec, enter the WSS base address, four ports below the codec index port. For an ESS AudioDrive, select **ESS AudioDrive** and enter its Sound Blaster base address, IRQ, and DMA Low channel. μCDD then plays 44.1 kHz 16-bit stereo through the chip's extended mode; the DMA High channel is not used. **ESS AudioDrive (fast)** plays at 22.05 kHz and takes less CPU time. **Detect** does not identify an ESS chip. Select the ESS model by hand. Only the ES1868 was tested on hardware. The driver trims the ES1868's clock to an exact 44.1 kHz (register BAh, which it touches only on an ES1868 or ES1878); other ESS chips run at the rate their data sheets give, 44194 Hz, and the mixer is told so. That costs: on those chips every CD frame is interpolated, which takes about three times the CPU of the exact-rate path (4.8 against 1.8 percent of a Pentium 233 with CD audio playing, two thirds of a 386DX-40 against one quarter), so an ES1868 or ES1878 is the ESS chip to prefer for CD audio on a slow machine. The ES688 and ES1688 are not known to report the interrupt source bit the driver relies on.
- A physical **WSS codec** or ESS card must be on IRQ 5 or 7; the driver handles the master interrupt controller only.
- **Disk** shows the PCI disk controllers that `UCDD -install` found and lets you add the IRQ of one the BIOS does not report. UCDDSET warns when a controller shares an IRQ with a sound card setting. See BUILDING.md for what the driver does with these IRQs.
- **Virtual** is what games see: a Sound Blaster (SB16, SB Pro, or SB 1.5/2.0, which report DSP 4.05, 3.02, or 2.01) and a WSS codec. The WSS codec uses the DMA Low channel of the virtual Sound Blaster, and a game can move its IRQ through the WSS board register. Where possible, match the virtual model to the physical card. For example, a virtual SB Pro on an SB Pro-compatible card keeps the game sound in 8-bit stereo and avoids a 16-bit conversion.
- **Detect** reads the physical card from the hardware. `BLASTER` only fills in values that the tests cannot find. **Test** plays a tone on each speaker. **Program** writes the IRQ and DMA channels shown into a jumperless Sound Blaster 16 (DSP 4.xx, such as the CT2290 and CT2291) through mixer registers 80h and 81h, so the card listens where the settings say; it checks for a DSP 4.xx at the port first and reads the registers back. A Plug and Play SB16 is set by its PnP utility instead. All three need DOS without the μCDD audio driver.

`UCDDSET` saves to `UCDD.CFG`. `UCDD -install` runs `UCDDSET`, which copies the settings into the driver and sets `BLASTER` for the virtual Sound Blaster. Other `BLASTER` fields, such as `P330`, are kept. If `UCDD.CFG` is missing or from an older version, the `UCDDSET` menu opens first. Changes take effect at the next boot.

CONFIG.SYS:
```dos
DOS=HIGH,UMB
DEVICE=C:\JEMMEX\JEMMEX.EXE
```

JEMMEX options to avoid: `NOVCPI` (the audio driver's host is a VCPI client and cannot start without it), `SB` (it maps the first 4 MB into the page table the host shares with JEMMEX), and `NOEMS` if protected-mode games need more than the 8 MB pool it leaves. `UCDD -install -ems` needs an EMS page frame.

AUTOEXEC.BAT:
```dos
LH C:\UCDD\UCDD.EXE -install
C:\DOS\SHSUCDX.COM /D:UCDD0001 /L:F
```

`MSCDEX` can also assign the drive letter.

Set `UCDDPCI=OFF` in the environment to skip the PCI disk controller scan at install; IRQ 14 and 15 and the IRQ set by hand are still passed to DOS directly.

Do not load the audio driver for games that use ADPCM sound. ADPCM is not supported or passed through, and its playback commands conflict with the PCM output that μCDD mixes into. Boot without `UCDD -install` for those games. Unmounting an image does not unload the driver.

## How it works

`UCDD.EXE` installs as a DOS CD-ROM device. The redirector assigns its drive letter. The installer is discarded after load.

μCDD traps the game's sound-card I/O and DMA access, converts its PCM sound, and mixes it with CD samples from the image. The physical card plays the combined stream. An internal DPMI host keeps the traps in place for protected-mode games.

## Usage

### Installation

Install once per boot, before the redirector. `UCDD -install -units 2` creates two empty drives (1 to 4) with the data-only driver; the resident audio driver supports one drive and refuses more. Restart DOS to change the unit count. `LH` loads the resident driver into upper memory when UMBs are available. The driver, its buffers and the internal host take about 55 KB of upper memory in five blocks; each block falls back to conventional memory on its own.

```dos
UCDD -mount C:\IMAGES\GAME.CUE
UCDD -mount C:\IMAGES\DATA.ISO -drive G
UCDD -unmount
UCDD -unmount -drive G
```

Without `-drive`, mount uses the first empty μCDD letter and unmount uses the first mounted one. Close files on a drive before you change its image. A locked drive cannot be changed. `UCDD -unmount NAME.CUE` matches a mount made from that CUE sheet.

`UCDD /?` and `UCDDSET /?` print command help.

### Multiple discs

Make a text file with a `.MDM` extension and one image path per line:

```text
DISC1.ISO
DISC2.CUE
DISC3.BIN
```

```dos
UCDD -mount C:\IMAGES\GAME.MDM
UCDD -unmount C:\IMAGES\GAME.MDM
```

The first disc is mounted. At the game's disc-change prompt, use the [hotkeys](#hotkeys). A held key selects its disc once. A key with no disc assigned does nothing.

Only one MDM file can be mounted at a time, on one virtual unit. The usual `-drive` selection applies. Mounting a single image over that unit releases the list. It can also be unmounted normally.

Paths may be absolute or relative to the MDM file. A CUE sheet's BIN path is relative to the CUE sheet. Nested MDM files are not supported. Blank lines and spaces at the start or end of a line are ignored. Only the first ten non-empty lines count.

All listed images are opened before the mount replaces the current disc. If a listed image is missing or invalid, the current image stays mounted. Give DOS enough file handles. If the drive is in use, μCDD waits, then applies the last requested disc. MDM files require XMS.

### Hotkeys

| Action | Default |
| --- | --- |
| Select disc 1 to 10 | Ctrl+Alt+1 to Ctrl+Alt+0 (or F1 to F10) |
| Next / previous disc | Ctrl+Alt+PgDn / Ctrl+Alt+PgUp |
| Eject | Ctrl+Alt+E |
| CD-Audio volume up / down | Ctrl+Alt+Keypad + / Ctrl+Alt+Keypad - |

The modifier keys can be any mix of Ctrl, Alt, Shift, and Win. The keys still reach the game. Key names are US layout; on other layouts, use the key in the same position.

Eject makes the drive report no disc and keeps the image open. A disc key, or next or previous disc, inserts a disc again. The hotkeys control the MDM drive, or the first μCDD drive when no MDM file is mounted.

Some BIOSes change the CPU speed with Ctrl+Alt+Keypad + and -. KEYB uses Ctrl+Alt+F1 and Ctrl+Alt+F2.

### Protected-mode games and VCPI

When the audio driver is installed, μCDD hides VCPI from programs. It answers the VCPI detection call (INT 67h, AX=DE00h) with "not available". All other EMS and VCPI calls go to JEMMEX without change.

Many DOS extenders can use DPMI or VCPI. Some, such as PMODE/W and CauseWay, select VCPI first when it is available. In VCPI mode, the extender runs the game in its own protected mode and sends the sound directly to the card. μCDD cannot trap this access, so the game's sound and the CD-Audio stop or conflict. Without VCPI, these extenders use the μCDD DPMI host, which keeps the traps in place.

The internal host runs 32-bit and 16-bit DPMI programs. A DPMI program can start another DPMI program, with up to eight child levels. The host saves the parent program and restores it when the child exits. A child program still sees VCPI. For 16-bit programs, such as programs made with Borland Pascal 7, the host also translates the DOS calls that use protected-mode addresses. A program's protected-mode handlers for INT 1Ch, 23h and 24h are called for the real-mode timer tick, Ctrl+Break and critical errors, and a program that DOS ends from real mode (a critical error answered with Abort, or Ctrl+Break) is released by the host.

If a program supports only VCPI, install with `UCDD -install -vcpi`. VCPI then stays visible, but the sound of these programs bypasses μCDD.

### Images

Use DOS 8.3 names on a local hard disk. Image files must be smaller than 2 GiB. Images on CD, floppy, or network drives are not supported.

| Format | Notes |
| --- | --- |
| `.ISO` | 2048-byte data sectors |
| `.CUE` / `.BIN` | One BINARY file, sequential tracks, INDEX 01 on each track. INDEX 00 and PREGAP are accepted. The data track can be MODE1/2048, MODE1/2352, or MODE2/2352 with Form 1 sectors |
| `.BIN` alone | MODE1/2352 data, no audio track table. Use a CUE sheet for CD-Audio |
| `.MDM` | Disc list, as above |

PREGAP adds silence without reading sectors from the BIN file. Put PREGAP before the track's INDEX entries. Track positions include these gaps.

`FLAGS PRE` applies CD de-emphasis during playback. `DCP`, `4CH`, and `SCMS` are also accepted. `4CH` audio is treated as stereo; copy-control flags do not restrict playback.

Other MODE2 sector formats, compressed audio, and multi-file CUE sheets are not supported.

### CD player

`UCDDPLAY` plays CD-Audio from μCDD images and physical CD drives in VGA mode. It needs the μCDD audio driver.

![UCDDPLAY](docs/ucddplay.png)

- **OPEN** shows CD drives and the images on local hard disks. Select a CD drive to use its disc, or select a CUE sheet, an ISO or BIN image, or an MDM file to mount it. If a physical drive is selected, images mount on the first μCDD drive. **EJECT** unmounts an image or opens the physical drive tray.
- **SHUF** plays the tracks in a random order. **REPEAT** repeats one track or all tracks.
- The equalizer has a preamp, 10 bands from 31 Hz to 16 kHz, and presets. It changes only the CD-Audio, and only while `UCDDPLAY` runs. If the CPU is too slow for it, it stays off.
- Push V or click the bottom window to select Warp Speed, Spectra, Firebars, Lavaflow, Bubbles, Plasma, Tunnel, or Random. Tunnel shows moving wireframe rings. Their speed changes with the audio level.
- Push F1 to see all keys. With a mouse driver, the mouse also works.

`UCDDPLAY D:` selects CD drive D:. Push D to select the next CD drive. When you exit `UCDDPLAY`, the CD-Audio stops.

For a physical disc, load its DOS CD-ROM driver and assign it a drive letter with SHSUCDX (or MSCDEX). The drive and its driver must support digital audio extraction. UDVD2, OAKCDROM.SYS, and VIDE-CDD.SYS were checked with SHSUCDX in 86Box. In UCDDSET, set the **virtual** Sound Blaster model to SB16. This does not require a physical SB16 card. Keep the BLASTER value set by `UCDD -install`.

Physical-disc audio passes through the equalizer and the μCDD audio output. It does not use the drive's internal audio cable. The player also applies de-emphasis to tracks marked with pre-emphasis. Opening the file browser pauses physical-disc playback; push Space to resume after closing it.

Physical-disc playback uses the wave output level set in UCDDSET. The player's volume control adjusts this level further.

## GAMES WITH REDBOOK AUDIO THAT WORK

These are games known to work, not a list of every game that may work.

- Absolute Pinball
- Alien Trilogy
- Alone in the Dark
- Alone in the Dark 2
- Alone in the Dark 3
- Amazing Learning Games with Rayman
- An Elder Scrolls Legend: Battlespire
- Archimedean Dynasty
- Batman Forever: The Arcade Game
- Battle Arena Toshinden
- Battle Chess Enhanced CD-ROM
- Battle Race
- BC Racers
- Betrayal at Krondor
- Big Red Racing
- Blam! Machinehead
- Blood
- Bust-A-Move 2 Arcade Edition
- Carmageddon
- Chasm: The Rift
- Corridor 7: Alien Invasion
- Cyber Police (CYBERPO1.EXE)
- Cyberball
- Descent II
- Descent II: Vertigo Series
- Destruction Derby
- Destruction Derby 2
- Fascination
- Future Wars
- Gobliiins
- Gobliins 2: The Prince Buffoon
- Goblins Quest 3
- Little Big Adventure
- Little Big Adventure 2
- Loom
- Lost in Time
- Pro Pinball: The Web
- Pro Pinball: Timeshock!
- Quake
- Rayman
- Rayman 60 Levels
- Rayman By His Fans
- Rayman Designer
- Realms of Arkania III: Shadows over Riva
- Realms of Arkania: Blade of Destiny (German CD edition)
- Realms of Arkania: Star Trail (German CD edition)
- Return to Zork
- Screamer
- Screamer 2
- Screamer Rally
- ShadowCaster
- The Manhole
- The Secret of Monkey Island
- Tomb Raider

## Build

Assembler sources are in `src/`. NASM and Python 3 are required. See [BUILDING.md](BUILDING.md).

## Special thanks

Thanks to davidmorom on VOGONS for testing games and reporting compatibility problems.

## License

Copyright (C) 2026 vorvek. μCDD is licensed under [GNU GPL version 3 only](LICENSE). No warranty; see the license for its terms.
