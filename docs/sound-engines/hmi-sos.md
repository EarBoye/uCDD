# HMI Sound Operating System (SOS)

Human Machine Interfaces' SOS, 1992-1997: digital audio and MIDI for
protected-mode games, the second largest family here (about 80 games:
Descent 1 and 2, Tomb Raider, MDK, Screamer, Rayman, Abuse, Shellshock,
Carmageddon, Command & Conquer). See [inventory](inventory.md).

Grades as in the [README](README.md#evidence-grades).

## Files and configuration

| File | What it is |
|---|---|
| `HMIDRV.386` | A library of digital drivers, one small module per device and format, each with a device ID [file, Tomb Raider: 51 modules] |
| `HMIMDRV.386` | The MIDI drivers in the same format [file, Descent] |
| `HMIDET.386` | Detection code, used by the setup program [file] |
| `HMISET.CFG` | `[DIGITAL]` and `[MIDI]` sections: name, IRQ, DMA, port, device ID [file, Tomb Raider] |
| the game's own file | Descent: `DigiDeviceID`, `DigiPort`, `DigiIrq`, `DigiDma`, `MidiDeviceID`, `MidiPort` in DESCENT.CFG [file] |

The game loads only the one module whose ID the configuration names; the
module carries no detection of its own (the setup program's job), so a
wrong IRQ in the file is used as written.

### Device IDs (from HMIDRV.386 and HMIMDRV.386) [file]

Digital, for the cards that matter here:

| ID | Module | Output |
|---|---|---|
| E000h | sbdrv | Sound Blaster 8-bit mono (SB 1.x/2.0) |
| E001h | sbstdrv | SB Pro 8-bit stereo |
| E00Fh | sbpro8m | SB Pro 8-bit mono |
| E015h | sb168m | SB16 8-bit mono |
| E016h | sb168s | SB16 8-bit stereo |
| E017h | sb1616m | SB16 16-bit mono |
| E018h | sb1616s | SB16 16-bit stereo |
| E019h-E01Ch | ess8m, ess8s, ess16m, ess16s | ESS AudioDrive 8/16-bit, mono/stereo |
| E023h-E02Ah | gus*, gmax* | Gravis UltraSound and UltraSound MAX |
| E003h-E006h | mvpas*, pas* | Pro Audio Spectrum |
| E107h | intspkr | PC speaker |

MIDI: A001h MPU-401, A002h OPL2, A009h OPL3, A008h AWE32, A00Ah GUS,
A004h MT-32, A006h PC speaker. Modules ending in `w` are the Watcom
builds of the same driver; `r` the recording ones.

The format is chosen by ID, not detected: Descent's `0xe016` is SB16 8-bit
stereo, and its trace shows exactly that (C4h, mode 20h) [file + trace].

## What the SB16 driver does [trace]

Seen in Descent, Tomb Raider, MDK, Screamer, Shellshock, Abuse and
Command & Conquer. In order:

1. **Masks and unmasks IRQ 0** at the PIC a few times (B9h/B8h pairs)
   while it sets itself up: the timer is held off while HMI swaps its own
   timer handler in.
2. Reset (01h, 00h, AAh). **No E1h**: the version is never read; the
   configuration's device ID is trusted.
3. **Mixer register 83h = 0Bh.** Creative's guide lists no register 83h
   (SBG and SBK, checked), and the CT2290 has none: it reads FFh from 83h
   up [hw, vsb-spec.md 9.4], so the write goes nowhere on it. Capitalism (DigPak/AIL 2) writes the same, so it may come
   from a shared piece of detection code rather than from HMI alone.
4. 41h: the rate in Hz (11025 or 22050 here).
5. The 8237: mode 59h (auto-init, single, read), page, address, count;
   the buffer is 4096 or 8192 bytes (or words).
6. Unmask the configured IRQ at the PIC, unmask the DMA channel.
7. **C4h or B4h: auto-init with the FIFO off** (C6h/B6h would turn it on).
   The length is the whole DMA buffer: one interrupt per buffer.
8. From then on the engine **polls the DMA count**: clear the flip-flop,
   read the low and the high byte, over and over from its timer handler
   (Descent: about 200 count reads in the last 640 accesses, against a
   handful of acknowledges). It mixes ahead of the position it reads. The
   card's interrupt is acknowledged (2xEh) once per buffer, at the wrap;
   the mixing follows the count. In the traces HMI's count never read
   higher than the read before it ([findings.md](findings.md) F2 was not
   seen in any HMI game).

Format by game (all at 220h):

| Game | ID | Command | Mode | Rate | DMA buffer |
|---|---|---|---|---|---|
| Descent | E016h | C4h | 8-bit stereo | 11025 Hz | DMA 1, 4096 bytes |
| Tomb Raider | E016h | C4h | 8-bit stereo | 22050 Hz | DMA 1, 4096 bytes |
| MDK | | C4h | 8-bit stereo | 11025 Hz | DMA 1, 4096 bytes |
| Screamer | | C4h | 8-bit stereo | 11025 Hz | DMA 1, 8192 bytes |
| Shellshock, Abuse | | C4h | 8-bit mono | 22050 / 11025 Hz | DMA 1, 4096 bytes |
| Command & Conquer | | B4h | 16-bit mono | 22050 Hz | DMA 5, 4096 words |
| Rayman (SB Pro module) | E001h | 48h + 90h | 8-bit stereo through mixer 0Eh=02h, so mono on an SB16 (no 0Eh there) | TC CDh | DMA 1, 8192 bytes |

### The wrong flip-flop

On the 16-bit channel (Command & Conquer, B4h on DMA 5) HMI clears the
**8-bit controller's** flip-flop (port 0Ch) before writing channel 5's
address and before every read of its count (0C6h), where the 16-bit
controller's is D8h [trace; the 8237 pair has one flip-flop per
controller, hardware.md]. It works on real machines only because every
access is a pair of bytes, so the 16-bit controller's flip-flop comes back
to where it started. A card or chipset model that shares one flip-flop
between the controllers, or one that leaves it odd, would hand HMI swapped
bytes.

## What uCDD has learned from HMI

| Item | What HMI does | What it needs | Where |
|---|---|---|---|
| Position by count | reads the DMA count hundreds of times a second | a count that moves with the output clock, not in whole mix periods | ISSUES.md `virtual-timing`, `ess-position` |
| Descent 2 clicks | rewrites the buffer right up to the count it reads; a virtual count at the mix position (ahead of what is heard) let it overwrite frames not yet played | the count follows the output clock and never passes the mix | ISSUES.md `ess-position`, `virtual-timing` |
| No version check | goes straight to 83h and 41h | the configured card must accept 41h (an SB16 or ESS command) | |
| 0Ch before D8h | wrong controller's flip-flop | channel 5's flip-flop must survive 0Ch writes | host-cdrom-spec.md D5 |
| No acknowledge needed | plays on with its interrupt lost | the output must keep running when the game never acknowledges | see below |

**Not settled [trace, 86Box, 19 Oct]:** in Descent's run with the card on
IRQ 7 (the game configured for IRQ 5, so the virtual interrupt was raised
on a line the game kept masked) the polled count ran through one buffer
and three quarters of the next, then stood at 03F5h for the rest of the
run. The stop came at the trace build's own log dump, which prints about
5 KB to LPT1 with interrupts off, and the physical card shared IRQ 7 with
the virtual one. With card and game both on IRQ 5 the count kept moving
through the same dumps (197 reads, every one different, an acknowledge
at each wrap). So this is the trace build and the shared line, not HMI.
Whether a real SB16 keeps an auto-init transfer running while its
interrupt goes unacknowledged is not in Creative's guide; the CT2290 can
answer it.

## Music and timer [trace]

The timer at **120 Hz** (Descent mode 2, Tomb Raider mode 3; Screamer
100 Hz). HMI's OPL3 driver (fmmidi3, ID A009h) writes both banks alike,
31.5 status reads per write, 834 writes a second in Descent's menu, most
of them to the sustain/release registers. Detail in
[music-and-timers.md](music-and-timers.md).

## Quick reference

| | HMI SOS (SB16 modules) |
|---|---|
| Detect | none at run time (the setup program detects, the ID is stored) |
| IRQ found by | the configuration file |
| DMA | auto-init, one block the size of the buffer, FIFO off |
| Rate | 41h in Hz (SB16, ESS); time constant on the SB/SB Pro modules |
| Acknowledge | 2xEh (or 2xFh), once per buffer |
| Position | **the 8237 count, polled** |
| Timer | its own handler on IRQ 0 at 120 Hz (Screamer 100 Hz), swapped in with IRQ 0 masked |
