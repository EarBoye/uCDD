# The host, the CD-ROM driver and the virtual PIC and DMA: reference check

Version 0.1, 17 Oct 2026. The parts of uCDD outside the sound cards, read
against their specifications: the DPMI host, its use of VCPI, XMS, EMS and
JemmEx, the CD-ROM device driver under MSCDEX, and the virtual 8259A and
8237A the driver keeps for games. It starts from the review in the
reference library (branch `reference-library`, `notes/hosts-and-cdrom.md`
and `notes/timers-pic-dma.md`), written against an older `fixes`; every
item was checked again against this branch's code before anything changed.

## 0. Rules and sources

- The specifications decide; where they are silent or disagree, the
  emulators, then the real PC (the uCDD mantra, rules 1 and 5). Each
  finding carries its grade: [doc] a specification, [86Box] a run of this
  project's test programs in 86Box, [hw] Michael's PC.
- Sources, all in the reference library: DPMI 0.9 (D09) and 1.0 (D10)
  specifications, VCPI 1.0 (VCPI), XMS 3.5 (XMS), LIM EMS 4.0 (EMS), the
  Jemm readme (JR) and QPIEMU (QPI) in `Memory managers and DOS extenders/`;
  MSCDEX 2.1 (MSC), SHSUCDX (SHSU) and ECMA-119 (ECMA) in `CD-ROM/`; Ralf
  Brown's Interrupt List (RBIL); the 8259A and 8237A data sheets in
  `Reference parts and specs/`. Line numbers are the text files'.
- Tests: `DPMIG.COM`, a raw 16-bit DPMI client with one line per check
  (E, C, I, P, Z below), and `CDPLAY.COM d Q`, which now also prints the
  audio IOCTLs a game polls (12, 1, 4).

## 1. The DPMI host

What a 0.9 host owes its client, in short: the 1687h entry and the
initial selectors (D09:587-692); simulated CLI/STI and the virtual
interrupt flag (D09:304-327, 2575-2620); hardware interrupts to the
protected-mode handler first, on a locked stack (D09:335-366); every one of
the 256 vectors reflecting to real mode by default, but INT 31h and 21h/4Ch
(D09:496-505); the real-mode call and callback services (D09:1521-1804);
exception handlers through 0202h/0203h, with the unhandled exceptions 0-5
and 7 reflected as interrupts and the others ending the client
(D09:1350-1465, 1428-1433); the virtual controllers' bases through 0400h,
reprogrammable (D09:353-356, 2082-2104).

| # | Finding | Source | Status |
|---|---|---|---|
| D-1 | 0202h gave 0000:00000000 for an exception the client had not hooked, so a handler that chains to the previous one (the usual pattern) jumped to selector 0 and the client ended. | D09:1350-1366, 1428-1433 | **Fixed.** 0202h returns a default stub, one per exception, in the host's stub segment. A handler that chains to it gets the host's own handling: the fault's context comes back from the exception frame and runs once more without the client's handler (`dpmi_exception_default`). [86Box: DPMIG E gives 006B:A71C... where it gave 0000:0000; C, an INTO handler chaining to the default, reaches the real-mode INT 04h: "pm 1, real 1"; the old build ends the client there.] |
| D-2 | A client's INT n to a vector where an IRQ lands (under JemmEx 08h-0Fh and 70h-77h) raised #GP, because those gates are DPL 0 so that only the controller enters them, and the client ended. | D09:496-505; D10:1409-1416 | **Fixed.** A #GP from ring 3 with the IDT bit in its error code, whose instruction is `CD n` for that vector, runs as the INT it is (`mon_exception .idt_fault`). [86Box: DPMIG I, INT 0Bh, reaches the real-mode vector; the old build ends.] |
| D-3 | A real-mode callback entered again while one runs ends the client (one save area). | D09:1777-1784; D10:1882-1890 | Open. Needs a save area and stacks per level inside the one real-mode segment the resident host fits in. |
| D-4 | With no handler, exceptions 0 and 7 ended the client; only 1, 3, 4 and 5 were reflected. | D09:1428-1431 | **Fixed.** 0-5 and 7 go to the protected-mode interrupt handler, or with none to the real-mode vector, as the spec says. [86Box: DPMIG Z, a divide by zero, reaches the real-mode INT 0; the old build ends.] |
| D-5 | An ICW1 written to the host's virtual PIC was refused: #GP, and the client ended. | D09:353-356 | **Partly fixed.** ICW1 is taken and the ICW2-ICW4 that follow are counted off, not read as masks; the bases stay as 0400h reports them (open: a client that moves them under DPMI). [86Box: DPMIG P, the mask reads the same before and after.] |
| D-6 | 000Dh (allocate a specific LDT descriptor) is not supported, and the host keeps LDT entries 6 and 7 for itself, which 0.9 reserves for clients. | D09:1142-1160 | Open. |
| - | Harmless, kept as they are: callback entry leaves the structure's CS:IP stale; a fresh locked-stack page per nesting level; separate descriptors for DS and SS when equal; CL=3 on every CPU; the audio and disk IRQs go to real mode first (a design choice); callbacks on their own stack. | review 1.3 | No change. |

## 2. VCPI, XMS, EMS and JemmEx

| # | Finding | Source | Status |
|---|---|---|---|
| V-1 | The PIC bases are read with DE0Ah once, at install. | VCPI:565-605 | **No change**: a VCPI client that remaps the controllers must put them back before it ends (VCPI:604-605), so the bases at install hold for every later client. |
| V-2 | DE0Ch from V86 may be called with IF set after a real-mode call. | VCPI:615 | No change: JemmEx enters its INT 67h handler with interrupts off (review 2). |
| X-1 | XMS: the CD queue, the cache, the MDM backup and the resident host from the 0-4 GB pool; no A20 calls; UMBs through DOS. | XMS:70-141; JR:357-362 | No change. |
| X-2 | EMS queue (a build option): 47h/48h around each copy, one context per handle. | EMS:528-541, 1337-1415 | No change: a nested copy fails cleanly with 8Dh. |
| Q-1 | Word and dword I/O on the Sound Blaster's ports: only a word OUT to base+4 is taken; others are dropped. | RBIL.P:5965-5974 | Open (rare). |
| Q-2 | Jemm's internals are read through an undocumented IOCTL (versions 5605h and 5705h only). | JR:351-353 | No change; a new Jemm may need a look. |
| Q-3 | VME: with Jemm's VME option a game's CLI leaves IF set in the V86 frame, which the trap exit tests (`host_jemm.asm`, host_io_irq). | JR:194-196 | Open. NOVME is Jemm's default; the README should say it is required. |

## 3. The CD-ROM device driver

uCDD is the device driver; MSCDEX or SHSUCDX provide INT 2Fh 15xxh. The
commands, IOCTLs and their formats are MSCDEX 2.1's (MSC:199-1161).

| # | Finding | Source | Status |
|---|---|---|---|
| M-1 | On an image with no CD audio (a plain ISO), IOCTL input 1 (head), 4 (channels) and 12 (Q-channel) and output 3 (channel control) answered Unknown Command. | MSC:715-717 ("valid even when the drive is idle") | **Fixed.** They answer as an idle drive at sector 0: Q-channel 41h, track 1, index 1, 00:00:00 in the track, 00:02:00 on the disc; head 0 (HSG) or 00:02:00 (Red Book); outputs 0-3 from inputs 0-3, the first two at FFh; channel control taken. [86Box: CDPLAY G Q on DATA.ISO gives 0100h and those bytes; the old build 8103h.] |
| M-2 | Commands 7 and 11 answer Unknown Command. | MSC:383-386 | No change (harmless). |
| M-3 | READ LONG raw is refused while IOCTL 7 offers 2352. | MSC:900-975 | No change (status bit 2 says raw is not supported). |
| M-4 | Volume size is the lead-out LBA, 150 below the MSF formula. | MSC:598-608; RBIL.G:622-627 | No change (common practice). |
| M-5 | Status bit 9 (Red Book) only with audio; bit 10 never set. | MSC:549-586 | No change. |
| M-6 | No error 0Fh on media change; IOCTL 9 reports it. | MSC:388-391 | No change. |
| M-7 | Reads during play succeed with busy set. | MSC:322-325 | No change (friendlier than busy+error). |
| M-8 | PLAY with a zero count or into a data track fails 810Ch. | spec silent | No change. |
| M-9 | High Sierra discs are refused. | MSC:1512-1560 | No change (1990s games use ISO 9660). |

## 4. The virtual 8259A (the driver's, for real-mode games, and the host's)

| # | Finding | Source | Status |
|---|---|---|---|
| P1 | ICW1 is not emulated. | 8259:451-462 | Real mode: counted off and dropped, as before. Host: taken and counted off (D-5). |
| P2 | A non-specific EOI with level bits (21h-27h) was dropped. | 8259A, OCW2 | **Fixed**: in the driver earlier (fixes), now in the host too: OCW2 is decoded by its bits 6:5, so every form is taken. |
| P3 | Poll (OCW3 bit 2) is answered as a request-register read. | 8259:688-706 | Open (a polling handler sees no interrupt number). |
| P4 | OCW3 08h/09h (nothing) and the forms with special mask mode and a read select (4Ah, 4Bh, 6Ah, 6Bh), and 0Dh-0Fh, were dropped; in the host they ended the client. | 8259A, OCW3 | **Fixed** in both: the read select, poll and special mask bits are taken apart. [86Box: DPMIG P, 08h and 4Bh then a read of the in-service register; the old build ends.] |
| P5, P6 | Special mask mode, set priority and the rotations are kept by the physical controller, not emulated. | 8259A | No change (harmless). |
| P8 | The virtual in-service bit is not seen by the physical chip, so lower lines can interrupt the game's handler after its STI. | 8259:615-617 | Open (low). |
| P10 | A request acknowledged at the card before the CPU takes it still runs the game's handler (a real PIC would give IRQ 7). | 8259:784-788 | Open. |
| P11-P13 | No spurious IRQ 7; LTIM ignored; mask bit 2 passes to the chip. | 8259A | No change. |

## 5. The virtual 8237A (the owned Sound Blaster channel)

| # | Finding | Source | Status |
|---|---|---|---|
| D1 | The owned channel's TC bit is not cleared by a status read. | 8237:477-480 | Open. |
| D2 | An auto-init wrap does not set TC. | 8237:477-479 | Open. |
| D4 | Demand, block, verify and decrement modes are refused and not stored. | 8237A, mode register | **Fixed** for demand and block: kept as the single mode of the same kind, since the emulation moves data a period at a time whatever the request mode (the virtual ESS did this already). Cascade, verify and decrement stay refused. [86Box: SBT16 D and SBQUEUE M, demand mode, as on the bare card; the old build kept its previous mode, which these short transfers do not show.] |
| D5 | The owned channel has its own flip-flop. | 8237:225-230 | Open (harmless with even access counts). |
| D8 | The request register (09h, D2h) is not trapped. | 8237 | Open (low). |
| D10 | The output ring's protection misses the cascade channel 4. | 8237 | Open (rare). |
| D11 | E2h with the channel not ready answered at 22Ah. | firmware | Fixed on `sb-gauntlet` (9f26044) for the SB16, from the 4.13's code and the CT2290. |
| D3, D6, D7, D9, D12-D14 | As the review rates them. | | No change (harmless). |

## 6. Tests

86Box, `host-gauntlet` against `platform-dma` d0532dc, the driver always
on so that the host is offered (DPMIG needs it):

| Test | platform-dma | host-gauntlet |
|---|---|---|
| DPMIG E | 0000:0000 for each exception | 006B:A71C, A724, A728, A736, A738 |
| DPMIG C | ends the client | pm 1, real 1 |
| DPMIG I | ends the client | real 1 |
| DPMIG P | ends the client | ISR 00, mask B8 B8 |
| DPMIG Z | ends the client | real-mode INT 0 |
| CDPLAY G Q, DATA.ISO | IOCTL 12, 1, 4: 8103h | 0100h, an idle drive at sector 0 |
