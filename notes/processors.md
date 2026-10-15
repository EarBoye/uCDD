# Processor notes (Intel486 and Pentium data books)

Sources: `Chipsets/486/241731-002_Intel486_Microprocessors_and_Related_Products_1995.txt`
and `Chipsets/Pentium/241732-003_Pentium_and_Pentium_Pro_Processors_and_Related_Products_1996.txt`.
Both books are mostly peripheral and chipset data sheets; the chipset notes
cover those parts. This file covers only the processor features that bear
on uCDD.

## CR4 virtual interrupt extensions: VME and PVI

What the books say (486 book, lines 2936 to 2960 and 3488 to 3530):

- CR4 bit 0, VME, "enables support for a virtual interrupt flag in
  virtual-8086 mode" and removes "the overhead of faulting to a
  virtual-8086 monitor for emulation of certain operations".
- CR4 bit 1, PVI, enables the virtual interrupt flag "in protected mode",
  so that ring 0 code can run at ring 3.
- EFLAGS bit 19 is VIF, the virtual image of IF; bit 20 is VIP, virtual
  interrupt pending.
- Both are qualified by CPUID (feature bit 1, VME). The 486 models that
  report it are the later ones (DX4, the SL-enhanced parts); every Pentium
  has it.
- The semantics themselves are not in either book. Appendix A of the 486
  book (line 22211) says they are "Intel confidential" and only in the NDA
  supplement to the Pentium manual. The behaviour below is from Intel's
  later public manuals, not from this library.

Behaviour, from the later public manuals (inference for this project's
purposes, not a document in the library):

- VME, in virtual 8086 mode with IOPL below 3: CLI and STI change VIF, not
  IF, without a fault. PUSHF pushes VIF in the IF position and POPF loads
  IF into VIF. STI or POPF that sets VIF while VIP is set faults, so the
  monitor can deliver a held interrupt. INT n can go straight to the IVT
  when the TSS interrupt redirection bitmap says so.
- PVI, in protected mode at ring 3 with IOPL below 3: only CLI and STI are
  virtualised. PUSHF and POPF are not.

## Finding 1: uCDD delivers virtual IRQs under JEMMEX VME while the game has interrupts disabled

Jemm offers VME as an option, off by default (Jemm Readme, lines 194 to
196: "VME/NOVME ... NOVME is the default"). With VME on, a real-mode
game's CLI clears VIF and leaves IF set in the virtual 8086 frame.

`src/audio/host_jemm.asm` line 199, the first test in host_io_irq (the
trap-exit delivery of the virtual sound card interrupt), checks only IF:

    test byte [ebp+49], 2     ; EFLAGS bit 9 of the interrupted frame

Under VME that bit stays 1 after the game's CLI, so the virtual interrupt
can be pushed onto a game that has interrupts virtually disabled: an
interrupt inside the game's own critical section. The same frame also
needs VIF checked wherever else the driver reads a V86 frame's IF.

Severity: a bug only for a user who adds VME to the JEMMEX line; none of
the documented configurations do. Fix options, cheapest first:

1. Document NOVME as required in the README's install section.
2. In host_io_irq, read CR4 (the routine runs at ring 0 inside Jemm) and,
   when CR4.VME is set, test EFLAGS bit 19 (`[ebp+50]` bit 3) instead of
   bit 9. Jemm itself respects VIF for its own reflections, so the
   driver's reflections would then match.

VME would also be worth measuring rather than only tolerating: every
CLI, STI, PUSHF, POPF and INT n of a real-mode game currently faults into
Jemm's monitor. A real-mode game with sound (Wolf3D, Duke) may run
measurably faster with VME, so once finding 1 is fixed, a timedemo with
and without VME on the Pentium is cheap and informative. The Jemm Readme
(lines 514 to 518) notes one incompatibility: the JEMM extender used by
Strike Commander and Privateer does not work with VME.

## Finding 2: PVI is not worth taking for the DPMI host

The DPMI host runs clients at ring 3 with IOPL below 3 so that their port
accesses fault into the trap path, and so CLI and STI fault too. ISSUES.md
(lines 218 to 222) costs that at 0.5 percent of Doom. PVI would remove the
fault, but the host's CLI and STI handlers (`src/host/monitor.asm` lines
1361 to 1418) do more than flip a flag: they are where the host's
single-step machinery (dpmi_tf_loaded, dpmi_tf_inject, dpmi_cli_site_check,
dpmi_sti_begin) delivers pending IRQs and emulates POPF's IF changes,
which PVI does not virtualise. Taking PVI means rebuilding that machinery
on VIP for half a percent. ISSUES.md line 292 already rules the path out;
the documents give no reason to revisit it.

## Other processor features checked

- The time stamp counter (RDTSC) is what the profiling builds already use.
- Page size extensions (CR4 bit 4) and machine check (CR4.MCE) have no
  bearing on the driver.
