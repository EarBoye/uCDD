# Notes on the reference library

Written from the text copies in this branch, read against the uCDD source
on `fixes` at f5a4104 and the event timer design on `event-timer`. Every
claim in the topic files cites the document and line it came from, and
separates what a document says from what is inferred.

| File | Covers |
| --- | --- |
| [chipsets.md](chipsets.md) | Every ISA and south bridge in the library: Type F and other fast DMA controls with PCI IDs, registers and defaults; ISA timing knobs; RTC and IRQ 8 quirks; candidates for the fast DMA option |
| [timers-pic-dma.md](timers-pic-dma.md) | The RTC, 8259A, 8237A and 8254 against the virtual PIC, the virtual DMA controller, the host's PIT handling and the event timer design |
| [sound-cards.md](sound-cards.md) | DSP commands across the Sound Blaster models, interrupt semantics, the SB Pro and SB16 mixers, the ESS AudioDrive family compared chip by chip, the CS4231A and CS4232, the FM chips |
| [hosts-and-cdrom.md](hosts-and-cdrom.md) | DPMI 0.9 and 1.0 host obligations, VCPI, XMS and EMS, Jemm's QPI, MSCDEX 2.1 and ISO 9660 against the host and the device driver |
| [processors.md](processors.md) | The 486 and Pentium books: VME and PVI |

## Findings checked against the code

Each of these was confirmed by reading the code at the cited place, not
only taken from a reader's note.

| Finding | Where | Effect |
| --- | --- | --- |
| A virtual ESS mixer write is stored raw at its own index before it is routed to its twin. On the internal SB16 layout 32h is the PCM left gain and 36h the CD left gain, so an ESS master write corrupts the left PCM gain and an ESS FM write the left CD gain | `src/audio/trap.asm` 411, 426 to 433 | Left and right levels differ under the virtual ESS whenever a game sets master or FM volume |
| ESS commands 41h and 42h take one byte each on the ESS (41h: time constant at 1.5 MHz; 42h: filter clock). The parser gives them the SB16's two-byte meaning on every model | `src/audio/trap.asm` 744 to 747; ES1868 sheet 2634 to 2640 | The byte after them is eaten under the virtual ESS |
| On the original PIIX (8086:122Eh), bit 3 of the Type F register (DMC) chooses the ISA DREQ and DACK pins over the motherboard pair; the write keeps the old bit 3 | `src/audio/standby.asm` fast_dma_set; PIIX/PIIX3 sheet 2000 to 2030 | If the BIOS left bit 3 at 0, ticking Type F on a PIIX board cuts the card off. The PIIX3 (the development PC) and PIIX4 are not affected; the PIIX4 write is right |
| The virtual PIC takes only 20h as a non-specific EOI. 21h to 27h, which the 8259A treats the same, fall through to the fault path | `src/audio/irq.asm` 280 to 291 | A driver that writes 20h plus its IRQ (a common mistake that works on a real PIC) leaves the virtual interrupt in service |
| The OCW3 poll command returns the request register instead of the poll byte, and other OCW3 forms are refused | `src/audio/irq.asm` 261 to 296 | Rare in games |
| A status read of the virtual 8237 never clears the terminal-count bit, and an auto-init wrap never sets it | `src/audio/trap.asm` 1735 to 1752 | A game polling the status for completion sees it stuck |
| F2h sets the DSP interrupt bits to 1 instead of adding bit 0, losing a pending 16-bit request | `src/audio/trap.asm` 875 | Minor |
| DPMI 0202h returns 0:0 when the client has installed no exception handler; the table starts zeroed. The spec requires a valid selector | `src/host/vectors.asm` 44 to 53, `src/host/dpmi.asm` 620 | A client that chains to the previous handler is terminated when an exception occurs |
| With JEMMEX VME, a real-mode game's CLI clears VIF and leaves IF set; the trap-exit delivery tests only IF | `src/audio/host_jemm.asm` 199 | Only if a user adds VME to the JEMMEX line (NOVME is Jemm's default) |

## Reported by the readers, not yet checked against the code

Plausible from the documents; each needs a look before it is acted on.

- A software INT 08h to 0Fh or 70h to 77h from a protected-mode client is
  fatal (DPL 0 gates); the DPMI spec reflects all 256 vectors.
- Re-entering a real-mode callback terminates the client; the spec allows
  re-entry.
- With a plain ISO mounted, IOCTL input 1, 4 and 12 and output 3 answer
  Unknown Command; MSCDEX 2.1 expects the Q-channel call to answer with
  nothing playing.
- A DPMI client's PIC reinitialisation terminates it; VCPI DE0Bh is never
  called, so a PIC remap by a VCPI program leaves the host's gates stale.
- Reading 22Eh or 22Fh does not cancel a request still waiting at the
  virtual PIC; the ES1868 sheet says the read cancels it.
- 38h (MIDI out) is refused and its data byte parsed as a command; ADPCM
  commands are missing.
- The virtual ESS's 2xCh status always reads 7Fh, showing FIFO full and
  empty and data available together.

## For the event timer design

From [timers-pic-dma.md](timers-pic-dma.md) and [chipsets.md](chipsets.md);
to be folded into `docs/event-timer.md` before phase 1:

- Port 70h is write-only on most chips, so the NMI bit cannot be kept "as
  the BIOS left it" by reading it back; the driver must track the last
  value written or choose one.
- If the timer sends its own EOIs before reflecting a tick, the game's EOI
  that follows reaches the virtual PIC as an EOI for the virtual sound card
  interrupt or a lower physical one. Leaving the EOIs of reflected ticks to
  the game avoids that.
- A game that masks IRQ 2 at the master stops the timer; the virtual mask
  must keep the cascade bit clear at the chip.
- IRQ 8 is edge-triggered on every Intel bridge, so register C must be read
  every tick. On SiS bridges an extended CMOS bank bit left set by the BIOS
  stops 70h and 71h from reaching register C.
- No document in the library says when a rate change takes effect; the
  design's assumption needs a measurement.

## For the fast DMA option

From [chipsets.md](chipsets.md), ranked by confidence: the Intel 82378 SIO
(Type F through port 40Bh, write-only, restore the reset value), the ALi
M1523B and M1543C (40Bh or 4D6h), the VIA south bridges (config 45h, one bit
a channel, which the 686B sheet says doubles the DMA clock rather than
giving Type F), and the SiS 5597, 5598 and 5582 (config 71h, with a revision
check against the 5595 that shares the ID). The PIIX supports Type F only
for DMA reads from memory, which is playback; capture on that channel must
not run with it set.
