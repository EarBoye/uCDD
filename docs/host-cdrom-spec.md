# The host, the CD-ROM driver and the virtual PIC and DMA: reference check

Version 0.2, 17 Oct 2026 (0.1 the same day). The parts of uCDD outside the sound cards, read
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
- One exception (rule 1 as amended on 17 Oct 2026): a game that
  specifically requires behaviour the specification forbids, when the
  failure is traced, the expected behaviour is measured where the game was
  built to run, and the change is the narrowest that makes it work. Such a
  deviation is marked **Deviation** below.
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
| D-6 | 000Dh (allocate a specific LDT descriptor) was not supported, and the host used LDT entries 1-7 (the client's initial CS, DS, SS, PSP and environment selectors and its two locked stacks) and handed out entries from 1, while DPMI keeps entries 0-15 (selectors 04h-7Ch) for 000Dh. | D09:1142-1160; D10:Int 31H 000DH ("must not be used by the DPMI host") | **Fixed.** 000Dh allocates the entry BX names (8011h when it is in use, 8022h for a GDT selector or one beyond the LDT); the host's own entries and the client's initial selectors moved to entries 16-22 (CS 87h, DS 8Fh, SS 97h, PSP 9Fh, environment A7h, the locked stacks AFh and B7h), and 0000h starts at entry 16. An LDT selector is taken by its table bit whatever its RPL, and entry 0 is valid once 000Dh gives it. [86Box: DPMIG S, 000Dh on 0Fh, again (8011h), on 04h, on 10h (8022h), then 0001h on both; Pentium, 486 and 386.] |
| D-7 | A software interrupt reflected to real mode came back with the client's virtual IF as it was before the call. Mortal Kombat Trilogy waits for ever under the host (section 7): it needs INT 16h to turn interrupts on. | D09:304-322, 411; D10:1428-1439, 1531-1532 | **Deviation, kept (Michael, 17 Oct 2026; rule 1's game exception).** A reflected INT 16h comes back with the client's virtual IF on, as an STI would, which is what INT 16h does when DOS/4GW is its own host. Every other vector keeps the flag as DPMI says. A first version took the IF from whatever any real-mode handler returned with; no game needs that, so it was narrowed to INT 16h. [86Box: the game reaches the fight, with CD music on the full disc; QEMU, the game without the host: DOS/4GW's INT 16h returns IF on in 12 of 12 calls made with IF off.] |
| D-8 | A stepped interrupts-off region has no bound: the host steps until the region ends, so a long first region from a CLI site (a game that draws a frame with interrupts off) costs about 10,000 steps a second in 86Box. | none (cost) | Open. A step budget with a learned "long region" site state was tried (it fixed nothing on its own here, and it can miss a POPF that ends a region after the budget); not kept. |
| D-9 | 0400h reported CL=03h (an 80386) on every processor. X-Men Children of the Atom asks 0400h for the processor, stops with its fatal error 7 when it reads anything below 04h, and its error path then calls a sound-library routine that was never set up: DOS/4GW's page fault at 1A7:0000002F (section 8). | D10:Int 31H 0400H ("CL = processor type: 02H 80286, 03H 80386, 04H 80486, 05H-FFH reserved for future Intel processors") | **Fixed.** CL is the processor found at the call: 03h when EFLAGS.AC cannot be changed, 04h when EFLAGS.ID cannot, otherwise the CPUID family (05h Pentium, 06h P6 and Athlon), with the extended family added to family 0Fh. [86Box: DPMIG G gives CL 05 on the Pentium MMX, 03 before; X-Men reaches its attract mode under the driver, as without it.] |
| D-10 | INT 2Fh AX=168Ah (the vendor-specific API entry point) from protected mode was reflected to real mode, where any handler could change AL and hand the client a bogus entry point. | D10:Int 2FH Function 168AH ("available only in protected mode"; unsuccessful: "AL = unchanged (8AH)") | **Fixed.** The host answers it. AL stays 8Ah for every name but the one extension in D-11; 0A00h fails with 8001h for those names. [86Box: DPMIG V gives AL 8A and 0A00h CF 1 AX 8001, before and after; the change removes the real-mode chance.] |
| D-11 | Borland's RTM (16-bit) asks INT 2Fh AX=168Ah for "MS-DOS" and, refused, accepts only Windows (INT 2Fh AX=1600h); otherwise it stops: "Error: no DOS extensions in the DPMI server" (Chasm: The Rift, section 9). It discards the entry point: to RTM the name means that the host translates DOS calls carrying protected-mode addresses, as Windows does. | D10:Int 2FH Function 168AH and Int 31H 0A00H (vendor extensions, "All extended API parameters are specified by the vendor"); RBIL tables 02719 and 02720 ("MS-DOS": AX=0100h, get LDT alias selector) | **Fixed, an extension, not a deviation.** The host answers "MS-DOS" to 16-bit clients, the only ones whose DOS calls it translates (dos16.asm); 32-bit clients and other names still get 8Ah, and 0A00h gives the same answer as 168Ah. The entry point (`dpmi_msdos_entry`, ring 3, DPMI calls only) takes AX=0100h: an LDT alias, a 16-bit data descriptor at DPL 3 over the whole table, allocated by 0000h so the client owns it; any other function returns carry set. [86Box: DPMIG M, AL 00 and 006B:AA2A from both functions, the alias reads the program's CS descriptor as 000Bh gives it, 0200h refused, the alias freed; RTM passes its check. Chasm itself still fails in 86Box, section 9.] |
| D-12 | A client that stays resident from real mode (INT 21h AH=31h) was released: the real-mode end hook (PSP:0Ah) took it for an end. Borland's RTM goes resident this way after its protected-mode start, and the program's stub then calls it through INT 2Fh; with the client released, Chasm: The Rift left silently. | D10:"Writing Resident Service Providers" (a client serving real-mode programs uses DOS's Int 21H Function 31H through 0300H); D10:Int 21H Function 4CH (the host acts on the end) | **Fixed.** The hook keeps a client whose PSP's memory block is still its own (the arena header below the PSP names it), which only a resident exit leaves, and goes on to the address DOS would have jumped to. [86Box: Chasm's RTM goes resident, its stub calls it, and RTM loads the game's segments; the regression matches the one before it.] |
| D-13 | An exception raised while a client exception handler ran ended the client: the host kept one exception state and took a second exception as unhandled. Chasm: The Rift's runtime takes a general protection fault inside its segment-not-present handling. | D10:"the host automatically switches to this stack during servicing of ... all exceptions ... Subsequent nested interrupts or calls will not cause a stack switch"; D09 silent | **Fixed.** A nested exception goes to the client's handlers like the first, on a new level of the locked stack; the outer handler's place (cursor, SP) is kept by level and comes back when the inner one returns or chains to the default. The stack's levels bound the nesting (four, as for interrupts). [86Box: Chasm then reaches its full start-up screen (memory, controls, VESA, the SB16, MSCDEX) and its runtime reports its own fault, "Runtime error 216", and exits cleanly, where the client was ended before; the regression matches the one before it.] |
| - | Harmless, kept as they are: callback entry leaves the structure's CS:IP stale; a fresh locked-stack page per nesting level; separate descriptors for DS and SS when equal; the audio and disk IRQs go to real mode first (a design choice); callbacks on their own stack. | review 1.3 | No change. |

## 2. VCPI, XMS, EMS and JemmEx

| # | Finding | Source | Status |
|---|---|---|---|
| V-1 | The PIC bases are read with DE0Ah once, at install. | VCPI:565-605 | **No change**: a VCPI client that remaps the controllers must put them back before it ends (VCPI:604-605), so the bases at install hold for every later client. |
| V-2 | DE0Ch from V86 may be called with IF set after a real-mode call. | VCPI:615 | No change: JemmEx enters its INT 67h handler with interrupts off (review 2). |
| X-1 | XMS: the CD queue, the cache, the MDM backup and the resident host from the 0-4 GB pool; no A20 calls; UMBs through DOS. | XMS:70-141; JR:357-362 | No change. |
| X-2 | EMS queue (a build option): 47h/48h around each copy, one context per handle. | EMS:528-541, 1337-1415 | No change: a nested copy fails cleanly with 8Dh. |
| Q-1 | Word and dword I/O on the Sound Blaster's ports: only a word OUT to base+4 is taken; others are dropped. | RBIL.P:5965-5974 | Open (rare). |
| Q-2 | Jemm's internals are read through an undocumented IOCTL (versions 5605h and 5705h only). | JR:351-353 | No change; a new Jemm may need a look. |
| Q-3 | VME: with Jemm's VME option a game's CLI leaves IF set in the V86 frame, which the trap exit tests (`host_jemm.asm`, host_io_irq). | JR:194-196 | **Documented.** The README lists `VME` among the JEMMEX options to avoid; `NOVME` is Jemm's default. |

## 3. The CD-ROM device driver

uCDD is the device driver; MSCDEX or SHSUCDX provide INT 2Fh 15xxh. The
commands, IOCTLs and their formats are MSCDEX 2.1's (MSC:199-1161).

| # | Finding | Source | Status |
|---|---|---|---|
| M-1 | On an image with no CD audio (a plain ISO), IOCTL input 1 (head), 4 (channels) and 12 (Q-channel) and output 3 (channel control) answered Unknown Command. | MSC:715-717 ("valid even when the drive is idle") | **Fixed.** They answer as an idle drive at sector 0: Q-channel 41h, track 1, index 1, 00:00:00 in the track, 00:02:00 on the disc; head 0 (HSG) or 00:02:00 (Red Book); outputs 0-3 from inputs 0-3, the first two at FFh; channel control taken. [86Box: CDPLAY G Q on DATA.ISO gives 0100h and those bytes; the old build 8103h.] |
| M-2 | Commands 7 and 11 answer Unknown Command. | MSC:383-386 | No change (harmless). |
| M-3 | READ LONG raw is refused while IOCTL 7 offers 2352. | MSC:900-975 | **Added (18 Oct).** Raw reading, the spec's optional data read mode 1: on an image of whole sectors (2352-byte stride) READ LONG returns each sector's 2352 bytes as the image holds them, and status bit 2 says so; an ISO image still refuses it (8103h) and leaves bit 2 clear. It does not by itself change what MSCDEX shows (M-5). [86Box: CDRAW, raw sectors 16-17 and 16-45 (30, past one 27-sector DOS read) byte for byte as the image, headers 00:02:16 to 00:02:45; CDIOCTL status 316h on Chasm's image, 2h on DATA.ISO with raw refused.] |
| M-4 | Volume size is the lead-out LBA, 150 below the MSF formula. | MSC:598-608; RBIL.G:622-627 | No change (common practice). |
| M-5 | Status bit 9 (Red Book) only with audio; bit 10 never set. MSCDEX 2.25 (MS-DOS 7.1's) shows no XA file of a CD-i Bridge disc (system identifier "CD-RTOS CD-BRIDGE", directory records with XA system use) unless bit 10 is set: DIR of Chasm's disc is empty under uCDD, full under 86Box's own drive and OAKCDROM. | MSC:549-586 (bits 10-31 reserved); RBIL.G table 01450 (bit 10 "audio is playing") | **Open, a decision for Michael.** Measured (86Box, CDIOCTL): OAKCDROM reports 796h on that disc with nothing played (audio status all 0); uCDD 316h. Of the differences only bit 10 matters (one build each: bit 7 no change, bit 10 the full listing; raw, M-3, no change; the "XA" signature cleared in a copy of the directory shows the files). Setting it would say "audio is playing" by RBIL's table; the 2.1 spec reserves it. SHSUCDX, on the real PC, does not look at XA, so the PC may not see this. |
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
| D1 | The owned channel's TC bit is not cleared by a status read. | 8237:477-480 | Open. The bit is byte 3 of the channel's record, which also means "this single-cycle transfer has ended" (the count then reads FFFFh, as the chip's does, and E2h refuses the channel); the fix is a separate status latch per channel, cleared by a status read, with byte 3 left as it is. |
| D2 | An auto-init wrap does not set TC. | 8237:477-479 | Open. The emulation works the position out from the output clock when it is read, with no event at a wrap; the latch of D1 would need the count of completed cycles since the last status read. Games take the card's interrupt rather than the controller's TC, so this waits. |
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

Mortal Kombat Trilogy from the library, the driver as on Michael's PC (not
forced on), keys to the first fight: before D-7 it stops at the character
select or the Battle screen with the timer IRQ waiting; with it, the menu,
the character select, Choose Your Destiny and the fight, as in the run
without the driver. With the full disc (audio tracks) the fight music plays
through the driver. [86Box]

## 7. Mortal Kombat Trilogy and the virtual IF (D-7)

The game runs under DOS/4GW. Its scripts run in an interpreter that
disables interrupts before it returns into the C code that called it
(`CLI` then `JMP [EBX]`; EIP D47F7 in the game's code), so the C code goes
on with interrupts off: input, drawing, the copy to the screen and a frame
limiter that polls the timer count its own IRQ 0 handler advances. On the
bare machine the next keyboard poll turns interrupts on again: DOS/4GW, as
its own host under VCPI, handles INT 16h itself, and its handler starts with
STI and returns with RETF. Under uCDD's host DOS/4GW is a DPMI client, does
not install that handler, and the host reflects INT 16h to real mode. The
BIOS and MS-DOS 7's hook end it with STI and RETF 2, but the host kept the
client's virtual IF off, so the frame limiter waited for a tick that never
came. The same happens to any game the host runs that was built on this
behaviour.

The specification is against the change. DPMI 0.9 (2.3) and 1.0 ("Virtual
Interrupts") say a client that cleared its flag gets no hardware interrupts
until it executes STI or calls 0901h, and both say that software interrupts
other than 00h-07h "do not modify the interrupt flag state". DOS/4GW
without a DPMI host, the environment the game was built for, disagrees
(measured below). Windows' DOS sessions may as well, since Windows keeps the
interrupt flag per virtual machine; that is neither measured nor taken from
a document here.

How the evidence was taken:
- QEMU 11.1, the game without uCDD under JemmEx (DOS/4GW at ring 0), gdb on
  QEMU's stub. A breakpoint at the CLI (linear 5F07F7 there; the game is
  flat under VCPI and based at 5C4000h under the host): IF on again 81
  instructions later, at the interpreter's next STI, on the same stack every
  time (the main program, not an interrupt handler). The INT 16h with IF
  forced off: IF on after it in 12 of 12 calls; stepped through, DOS/4GW's
  handler at 0070:04FA is STI, its real-mode call, then STI and RETF.
- 86Box, the host's diagnostic build: the region from that CLI never sees an
  STI or an IRET or POPF that sets IF; it runs through the drawing and into
  the frame limiter. Stepping natively (the decoder's emulation turned off)
  gives the same path, so the emulation is not the cause.
- QEMU has no game port, and the game's joystick read clears only CX before
  a `LOOPNE` that counts ECX: without a port it waits up to 2^32 reads. The
  QEMU runs patched that loop's count in memory to 65536.

What the host does now: after a reflected INT 16h, a client whose virtual
IF was off has it on, as after an STI (the region's CLI site learns it as
an STI end). That is DOS/4GW's own INT 16h, which ends with STI whatever
the caller's flag. Nothing else changed: the real-mode handler still gets
a flags image with IF set, and every other reflected vector leaves the
client's flag as it was, as DPMI 0.9 and 1.0 ask. The first version of
this change (824d2da) took the flag from any real-mode handler that
returned with interrupts on (keyboard, but also disk, system and multiplex
services that end with STI and RETF 2); no game was shown to need that,
so under rule 1's bar it was narrowed to the one vector the game uses.

## 8. X-Men Children of the Atom and 0400h (D-9)

Under the driver the game stopped with "DOS/4GW Professional error (2001):
exception 0Eh (page fault) at 1A7:0000002F", every run, with either
virtual card and with no sound driver at all (16 Oct). On 17 Oct a sampler
in the host and a dump of the client's stack at the fault traced it:

- The game called a null function pointer: a table of interrupt helpers
  that its sound library's DPMI layer fills at initialisation was still
  zero, so the call ran through the interrupt vector table from address 0
  until a garbage instruction at 2Fh read an unmapped page.
- The call came from the library's unlock routine, called by the game's
  cleanup, called by its fatal-error routine with error 7, before the
  library was set up.
- Error 7 is the game's processor check: it calls DPMI 0400h and accepts
  CL 04h and up. The host returned 03h on every processor.

The page fault is the game's own latent bug on an error path; the fault
that led there was the host's. With CL the real processor type the game
runs as it does without the driver. The earlier notes found the crash
sensitive to the driver's size and to timing; that was not followed up and
does not fit this cause, which is the same every run.

## 9. Chasm: The Rift and Borland RTM (D-11)

Chasm's PS10.EXE is a Borland 16-bit protected-mode program; its stub loads
RTM.EXE ("DPMI LOADER built 03/05/93"), which uses the DPMI host when one is
present and its own DPMI16BI.OVL otherwise. Under the driver it stopped
with "Error: no DOS extensions in the DPMI server, Loader error (0025)".
RTM's code (file offset 1FBBh) asks INT 2Fh AX=168Ah for "MS-DOS", throws
the entry point away, and when AL comes back 8Ah accepts only a Windows
answer to INT 2Fh AX=1600h. D-11 answers it. What was found on the way:

- Beta 0.9.3b passed the check by accident. It refused to reflect an INT
  2Fh whose DS lay above 1 MiB and returned AX=0001h with carry; RTM read
  AL=01h as "extension present". When the fork made that reflection
  follow DPMI 0.9 (DS sent as a harmless segment), the check failed as it
  should, which is why the release notes of 0.9.3 call the game fixed.
- With D-11, RTM goes on, takes its first segment-not-present fault (its
  demand loading, handled through 0203h as DPMI allows), switches to real
  mode through 0306h, hooks INT 2Fh and stays resident (AH=31h), as it is
  built to: PS10's stub started it with EXEC and calls it next. The host
  released it there (D-12). With D-12 the stub calls RTM, RTM opens
  PS10.EXE, reads the program past the stub and demand-loads its segments.
- It then failed later, at a point that moved with the driver's layout:
  in one build a page fault, in another a general protection fault
  inside the program's segment-not-present handling, which the host did
  not deliver (D-13, fixed). With D-13 the game shows its whole start-up
  screen (memory 62814K, keyboard, VESA 1.2, "SB16 #220h, IRQ05, DMA5,
  DSPv4.13", MSCDEX 2.25), then its runtime reports "Runtime error 216 at
  00CF:95DE" (a general protection fault in the game's code: les bx,
  [bp-4], then a write through ES:BX) and exits cleanly.
- With M-5's bit 10 as well (an experiment: MSCDEX then lists the disc),
  the game takes another path and the DOS memory chain breaks again
  ("Memory allocation error"), as in 0.9.3b. Not traced further: both
  failures depend on what the game reads from the disc and the driver.
- In 86Box, every build tested fails Chasm after RTM, 0.9.3b too (its
  later "Memory allocation error, Cannot load COMMAND, system halted").
  Which point it reaches moves with the driver's layout: of the parts of
  one fork commit (d7c134e), reverting either of two unrelated halves
  restores 0.9.3b's point. That is the mark of a memory overwrite, not of
  one wrong service.
- In the same runs MSCDEX lists nothing on the game's disc (Mode 2 Form 1,
  read back correctly through MSCDEX's absolute read, INT 2Fh AX=1508h,
  by CDSEC), nor on two other games' discs, while another Mode 2 disc
  (Destruction Derby 2) lists. The real PC uses SHSUCDX, so the game may
  behave differently there.

Open: the game's fault after its start-up screen, and the broken memory
chain once the disc lists. The real PC (SHSUCDX, which lists the disc) is
the quickest next answer: RGKIT asks for it.

