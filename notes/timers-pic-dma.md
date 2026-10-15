# Timers, PIC and DMA: reference notes for uCDD

Status: review notes, read-only. Written against `fixes` 77979b2 and the
event timer design in notes/event-timer.md. Every claim carries a citation.
"Doc:" marks what a document says; "Inference:" marks my reasoning from it.

## 0. Citation keys

Library root L = scratchpad/library/. Line numbers are of the pdftotext files.

| Key | File |
| --- | --- |
| 206 | L/Reference parts and specs/82C206_Integrated_Peripheral_Controller_199608.txt (OPTi) |
| UM | L/Reference parts and specs/UM82C206.txt (UMC) |
| 8259 | L/Reference parts and specs/8259A.txt |
| 8237 | L/Reference parts and specs/8237A.txt |
| IPC | L/Reference parts and specs/1994_Intel_Peripheral_Components.txt (82C54 sheet) |
| PIIX4 | L/Chipsets/Pentium/290562_82371AB_PCI-TO-ISA_IDE_XCELERATOR_PIIX4_199704.txt |
| PIIX | L/Chipsets/Pentium/290550-001_82371FB_82371SB_PCI_ISA_IDE_Xcelerator_199605.txt |
| CMOS, PA, IA, IC, ID, IQ, MEM | L/Ralf Brown's Interrupt List/ CMOS.LST, PORTS.A, INTERRUP.A, .C, .D, .Q, MEMORY.LST |
| ET | notes/event-timer.md |
| irq, trap, ports, res, pic | src/audio/irq.asm, src/audio/trap.asm, src/audio/ports.inc, src/host/resident.asm, src/host/pic.asm |

None of the library files is the Motorola MC146818 sheet itself; the RTC
facts below come from the two 82C206 sheets and the PIIX4, which describe
MC146818-compatible cores (PA:7692-7693 notes the RTC may be an emulation).

## 1. RTC (MC146818 behaviour)

### 1.1 Index port, NMI bit, latching

- Doc: port 70h bits 6:0 are the index, bit 7 is NMI mask, 1 = NMI disabled,
  0 = enabled (PA:7696-7700; CMOS:58-62; PIIX4:5116; PIIX:3509).
- Doc: "any write to PORT 0070h should be followed by an action to PORT
  0071h or the RTC wil be left in an unknown state" (PA:7701-7702). IBM
  follows the 70h write with a "throw-away" access (CMOS:61-62).
- Doc: 70h is write-only. PIIX and PIIX4: reads of 70h flow to the ISA/X-bus
  and return no index (PIIX:3501-3506; PIIX4:5108-5113, 5131-5136). PIIX4 can
  read the index back only through MISCSUP RTCIREN, bits 6:0 only, bit 7
  "indeterminate" (PIIX4:6556-6575).
- Doc: on the 82C206 the index is latched on the falling edge of AS, which
  a PC/AT design generates from a write to 70h (206:2946-2958; UM:2343-2347,
  408-410). NMI is not an RTC function on PIIX4: bit 7 is "used by PIIX4 NMI
  logic" (PIIX4:5139).
- Doc, chips that decode differently: PIIX4 aliases 70h at 72h, 74h, 76h and
  71h at 73h, 75h, 77h, except that 72h/73h become a separate extended-bank
  index/data pair when upper RAM is enabled (PIIX4:2674-2686, 2791-2794,
  4095-4097, 5181-5201). PIIX/PIIX3 drive the external RTC chip select for
  the whole 70h-77h range (PIIX:1750-1751). 64-byte chips mirror 40h-7Fh onto
  00h-3Fh (CMOS:64-65).
- Inference: the previous NMI state cannot be read on any of these chips, so
  every 70h write sets the NMI mask to whatever bit 7 says.

### 1.2 Register A (0Ah)

- Doc: bit 7 UIP read-only (206:2951-2953, 3096-3100; CMOS:212-213). Bits
  6:4 divider: 010 = 32.768 kHz normal, 11x = divider reset
  (206:3101-3109; UM:2572-2597; CMOS:214-215). PIIX4 lists 101, 100, 011 as
  "bypass stages (test mode only)" and 000 as invalid (PIIX4:11303-11311).
- Doc: bits 3:0 rate; 0011 = 122.070 us, 0110 = 976.5625 us, 0000 = none;
  on a 32 kHz base 0001 and 0010 give 3.906 and 7.8125 ms, not 30.5/61 us
  (206:3126-3152; UM:2599-2650; PIIX4:11313-11327). Usual value 26h
  (CMOS:208, 219-227).
- Doc: the rate selects "one of 13 taps of the 15 stage divider chain"
  (PIIX4:11313; also 11197-11200).

### 1.3 Register B (0Bh)

- Doc: bit 7 SET inhibits the update cycle and aborts one in progress
  (206:3155-3157; PIIX4:11350-11353). Bit 6 PIE enables the periodic
  interrupt "without affecting the programmed rate" (206:3158-3161). Bit 5
  AIE, bit 4 UIE; UIE "is also cleared when the SET bit goes high"
  (206:3162-3169; UM:2669-2670). Bit 2 DM, bit 1 24/12, bit 0 DSE
  (CMOS:232-243).
- Doc, chip difference: on both 82C206 parts SQWE (bit 3) and DM (bit 2) are
  "always fixed to 0", BCD only (206:3170-3172; UM:2672-2676); PIIX4 has a
  working DM bit and a dummy SQWE (PIIX4:11368-11372).

### 1.4 Register C (0Ch)

- Doc: IRQF = PF.PIE + AF.AIE + UF.UIE; "the condition which causes this bit
  to be set also generates an interrupt"; "This bit and all other active
  bits in this register are cleared by reading the register"; writes have
  no effect (206:3203-3208; UM:2701-2711; PIIX4:11410-11414; CMOS:254-259).
- Doc: PF is set at the selected divider transition "independent of the
  condition of the PIE control bit" (206:3209-3212; UM:2713-2716; PIIX4
  register A: "Otherwise, this tap sets the PF flag", PIIX4:11313-11315).
  AF and UF are likewise independent of their enables (206:3213-3217).
- Doc: IRQF also asserts the interrupt output (PIIX4:11413-11414); IRQ8 is
  always edge sensitive at the PIC (PIIX4:4799-4802), and an edge-mode input
  "can remain high without generating another interrupt" (8259:757-760).
- Inference, C not read: IRQF stays 1, the IRQ8 line stays asserted, no new
  rising edge reaches the slave PIC, so no further IRQ 8 of any kind (PF,
  AF or UF) until something reads C. ET:113-115 is right.
- Inference, stale PF: since PF is set at every tap edge regardless of PIE,
  and IRQF is a combination of flag and enable, setting PIE while PF is
  still set raises IRQF and the interrupt at once, not at the next tap.

### 1.5 Register D (0Dh)

- Doc: bit 7 VRT, rest zero on the 82C206 (206:3224-3229); on PIIX4 bits 5:0
  are a writable date alarm (PIIX4:11436-11446).

### 1.6 Rate change while running

- Doc: no library document says when a new rate takes effect. All three
  describe PF as set by a transition of the selected tap of a free-running
  chain (206:3209-3211; UM:2713-2715; PIIX4:11313-11315); PIIX4 even words it
  as "PF is 1 when the tap ... is 1" (PIIX4:11416-11417).
- Inference: the chain is not reset by an RS write (only DV=11x resets it,
  206:3109), so the first interrupt at the new rate comes at the next
  transition of the new tap, between 0 and one new period after the write,
  phase-locked to the chain, never "one full period after the write".
  Whether a switch to a tap that is already high sets PF at once (a glitch
  tick) depends on edge versus level sampling, which the documents leave
  open: the design must tolerate an early first tick.
- Inference: all taps are binary submultiples of one chain, so the interval
  from the last fast tick to the first coarse tick is anywhere in 0 to
  976 us, not 976 us.

### 1.7 UIP and the 244 us window

- Doc: UIP rises at least 244 us before the update; the update lasts up to
  1984 us (PIIX4:11298-11301, 11461-11466) or "an additional 2ms"
  (206:3096-3099). Registers 00h-09h are unavailable during the update;
  0Ah-0Dh are always accessible (206:3013-3024, 3083-3088).
- Doc: the read A then read time method works only if the whole sequence,
  "including any interrupt service routines which might occur", ends within
  244 us (206:3031-3040; UM:2549-2558). Writing SET=1 clears UIP
  (206:3100; UM:2570).

### 1.8 SET and the periodic interrupt

- Doc: SET stops update cycles (206:3155-3157; PIIX4:11350-11353). Nothing
  says it touches the divider chain or PF.
- Inference: the periodic interrupt keeps running while SET=1; only DV
  (register A bits 6:4) can stop it. UIE is cleared by SET (206:3169).

### 1.9 Check against event-timer.md 4.3 and 4.4

| ET claim (line) | Verdict | Evidence |
| --- | --- | --- |
| Read C every tick or no further interrupt (113-115, 242-244) | Right | 1.4 |
| Rate change takes effect "on the divider chain's next boundary at the new rate", first fast tick within 122 us (117-121) | Right as inference; add that the first tick may come at 0 us | 1.6 |
| Enabling PIE from off gives a first tick anywhere within one period (123-126) | Incomplete: with a stale PF the tick is immediate. Read C with PIE off just before setting PIE | 1.4 |
| Write 70h "with bit 7 clear so NMI stays as the BIOS left it" (131-133) | Wrong. Bit 7 clear enables NMI; the old state is unreadable. Shadow the last bit 7 written (the game's trapped 70h writes included) and write it back on every index write | 1.1 |
| Follow every 70h write with the 71h access (133-134) | Right (PA:7701-7702). But the handler "writes the game's index back before it returns" (227-229) is a bare 70h write and breaks this rule; in owned mode it is not even needed, since the game's 71h accesses are trapped and the virtual RTC selects the physical index itself | 1.1 |
| Register A: keep bits 6:4 at 010, write only 3:0 (134-135) vs. game's bits 6:4 "pass through" (230) | Contradiction. A game write of DV=11x stops the chain and the timer; 0xx test values change the base (PIIX4:11303-11311). Store the game's DV and keep 010 on the chip, or stand the timer down while DV is not 010 | 1.2 |
| Register A bit 7 is always the chip's UIP (230-233) | Right | 206:2951-2953 |
| Register B: SET and format bits pass through; PIE stays ours (235-241) | Right; note SET also clears the chip's UIE (206:3169), so the game's B read must take bit 4 from the chip after a SET write | 1.3 |
| PF in the game's copy at its virtual ticks regardless of PIE (245-248) | Right | 206:3209-3212 |
| Read of C clears the copy; IRQF when an enabled flag is set (251-252) | Right. Missing: setting the game's PIE while its PF copy is set should deliver at once | 1.4 |
| AF and UF kept for the game (244-246) | Incomplete: only PF ticks are reflected (258-261). With AIE or UIE set (INT 1Ah AH=06h alarm, ID:5925-5940) the chip interrupts on AF/UF and the game's INT 70h must be called for those too | 1.4 |
| "MC146818 keeps the periodic interrupt running while SET holds updates" (240-241) | Right by inference; not stated in any library sheet | 1.8 |
| D and CMOS pass through (253-254) | Right; PIIX4 D bits 5:0 are a date alarm | 1.5 |
| Accumulator in 122 us units "survives our own rate switches" (262-263) | Wrong as written. Adding 8 units per coarse tick and 1 per fast tick miscounts at both ends of a burst: the first fast tick and the first coarse tick after a switch are partial intervals (1.6). Per burst the error is 8 - a - b units, a = fast edges between the last coarse tick and the switch (0 to 7), b = fast edges from the last fast tick to the next coarse tick (1 to 8): up to 7 units, 854 us, a random walk. Fix: derive elapsed time from output_clock frames, or enter the fast rate only inside a coarse tick (a = 0) and leave it only on a fast tick that is a multiple of 8 since then (b = 8) | 1.6 |
| UIP window (not discussed) | Missing. A trapped A read plus several trapped time reads at 26 us each, plus a timer tick in between, can exceed 244 us, so a game can read a rollover between bytes. Low risk; mitigate by answering 00h-09h reads with a UIP check inside the trap | 1.7 |
| 70h reads and aliases 72h-77h (not discussed) | Missing. PIIX4 returns bus data for 70h reads, not the index; trapping only 70h/71h lets an alias access reach the chip | 1.1 |

## 2. 8259A

### 2.1 What the data sheet requires

- ICW1 (A0=0, D4=1) starts initialisation: edge sense reset, IMR cleared,
  IR7 lowest priority, slave address 7, special mask cleared, status read
  set to IRR, ICW4 functions zeroed if IC4=0 (8259:398-418; 206:2195-2211).
  ICW2 always follows; ICW3 only if SNGL=0; ICW4 only if IC4=1
  (8259:451-462; 206:2225-2244). LTIM=1 selects level mode (8259:451-453).
  On the AT pair: master ICW3 = 04h, slave ID = 02h, slave on master IR2,
  RTC on slave IR0 (206:2067, 2336, 2344).
- OCW2: R, SL, EOI = 001 non-specific EOI, 011 specific, 101 rotate on
  non-specific, 111 rotate on specific, 100/000 set/clear rotate in AEOI,
  110 set priority, 010 no-op; L2:0 used only by specific EOI and set
  priority (206:2398-2419; PA:284-299). A non-specific EOI resets the highest
  IS bit (8259:640-647). In cascade, EOI goes to both chips (8259:635-636,
  821-823).
- OCW3: ESMM/SMM (bits 6:5) set or reset special mask; P (bit 2) poll;
  RR/RIS read IRR or ISR on the next read; the chip remembers the selection;
  "Polling overrides status read when P=1, RR=1"; IMR read at A0=1 needs no
  OCW3 (8259:739-751; 206:2434-2472; PA:300-316). These fields combine in
  one write.
- Poll: the next read acts as INTA, sets the IS bit if a request is present
  and returns I (bit 7) plus W2:0, the highest pending level
  (8259:688-706); the poll is cleared after that read, and with no request
  bits 2:0 read 111 and bit 7 is 0 (206:2463-2464, 2503-2511).
- Special mask mode: a masked level is inhibited and all other unmasked
  levels, lower included, are enabled (8259:666-686); a non-specific EOI does
  not clear an IS bit masked in that mode (8259:598-600; 206:2144-2150).
- Priority: fully nested, IR0 highest; an IS bit inhibits its own and lower
  levels until EOI (8259:604-622; 206:2176-2192). Slave levels 8-15 take
  master IR2's place, above IRQ 3-7 (inference from the cascade wiring).
- Edge vs level: edge mode needs a low-to-high transition and ignores a held
  level (8259:757-760); level mode requires the request removed before EOI
  (8259:773-777). PIIX4 disables LTIM and uses ELCR; IRQ 0, 1, 2, 8, 13 are
  always edge (PIIX4:4528-4529, 4775-4802).
- Spurious IRQ 7: if the IR input drops before the first INTA, the chip
  issues a default IR7 without setting IS7; tell it apart by reading ISR
  (8259:276-283, 784-797; 206:2096-2100, 2290-2295). Inference: a slave
  does the same, giving INT 77h (IRQ 15) with master IS2 set, so the right
  answer is a master EOI only.
- Special fully nested mode: the handler sends a non-specific EOI to the
  slave, reads the slave ISR, and EOIs the master only if it is zero
  (8259:778-791).

### 2.2 Deviations of the virtual PIC (src/audio/irq.asm)

| # | Lines | Deviation from the data sheet | Rating |
| --- | --- | --- | --- |
| P1 | irq:247-259, 346-350 | ICW1 is not emulated: it raises a fault, is not forwarded, and ICW2-4 are counted off and dropped (the count itself matches 8259:451-462). Its side effects (IMR clear, read IRR, priority reset) are not applied to virtual_pic_mask or physical_pic_read | Harmless (reprogramming the master under Jemm breaks Jemm anyway) |
| P2 | irq:284-291 | A non-specific EOI is recognised only as exactly 20h (A0h after the rotate strip). 21h-27h and A1h-A7h are valid non-specific EOIs with don't-care L bits (206:2406-2415 "*L[2:0] are used by these commands" lists only specific EOI and set priority; PA:297) but fall to .fault and are dropped, so the virtual or physical IS bit stays set and that line and everything below it stays blocked | Bug (rare input, severe result) |
| P3 | irq:261-264 | Poll is recognised only as exactly 0Ch and answered as an IRR read. A real poll returns 80h+level or 07h, sets the IS bit, and is one-shot (8259:688-706; 206:2463-2464, 2503-2511). It also overwrites a prior ISR selection in physical_pic_read | Could matter (a polling handler reads 20h and sees "no interrupt") |
| P4 | irq:266-281, 291-296 | Other OCW3 values fault and are dropped: the no-op 08h/09h, 0Dh-0Fh (poll with RR), and the combined forms 4Ah/4Bh/6Ah/6Bh (special mask plus read selection) | Could matter (6Bh drops the ISR selection) |
| P5 | irq:272-281 | Special mask mode and set priority are swallowed; virtual_irq_take (183-192) always applies fixed nested priority | Harmless |
| P6 | irq:282-290, 343-345 | Rotate on non-specific EOI reaches the hardware as plain 20h, rotate on specific EOI as plain 6xh; 80h/00h (rotate in AEOI) fault | Harmless |
| P7 | irq:309-336 | Non-specific EOI ends the virtual interrupt when it is delivered and no strictly higher physical IS bit is set, else forwards: this matches "highest IS bit" (8259:640-647) with the virtual bit merged in | Correct |
| P8 | irq:175-204 | The virtual IS bit is not seen by the physical chip, so lower physical lines (IRQ 6, 7 under a guest IRQ 5) can interrupt the game's handler before its EOI if it runs STI; on hardware IS5 blocks them (8259:615-617) | Could matter (low) |
| P9 | irq:127-152 | An unacknowledged request is raised again after two periods; an edge-triggered input never re-requests a held level (8259:757-760) | Harmless (deliberate leniency) |
| P10 | trap:1765-1773, 873-878 | A 22Eh read clears virtual_dsp_irq but not virtual_pic_request. On hardware, a request acknowledged at the card before INTA (game with IF=0 polls 22Eh) makes the PIC issue a default IR7 (8259:784-788); here the game's IRQ 5 handler still runs later (host_jemm.asm:199-201 delivers when IF=1) | Could matter (detection code that runs with CLI) |
| P11 | irq:217-240 | No spurious IRQ 7 is ever generated; ISR reads show the virtual bit even while taken but not delivered | Harmless |
| P12 | irq:6, 247-259 | LTIM ignored: the input is always edge | Harmless (IRQ 5/7 are edge on ISA) |
| P13 | irq:351-363 | Master mask bit 2 (the cascade) passes to the chip | Harmless today; a bug for the timer (2.3) |

The protected-mode host's PIC (pic:205-300) copies the same rules
(ICW1 refused 222-224, poll 225-228, SMM swallowed 232-245, only 20h as a
non-specific EOI 246-255), so P2-P6 apply there too.

### 2.3 Consequences for the timer design

- Doc: an EOI must reach both chips (8259:635-636). ET:113-116 does that;
  right. Inference: until the master EOI, IS2 blocks the virtual IRQ 5/7
  (virtual_irq_take tests guest_irq_priority, which includes bit 2,
  irq:190-192), so the timer must EOI the master before it delivers
  deadlines, as ET:114-116 already says.
- Gap, reflected ticks: ET:259-261 and 278-283 EOI the chip before
  reflecting and plan to swallow the game's A0h EOI. Its 20h EOI is not
  swallowed: it reaches virtual_pic_write .eoi (irq:309-336), finds IS2
  already clear, and ends the virtual SB interrupt if one is delivered, or
  forwards 20h and ends a lower physical IS bit (an interrupted IRQ 6 or the
  card's own line). A handler using the SFNM procedure (8259:784-791) reads
  the slave ISR as zero for the same reason. Simplest fix: for a tick that
  is reflected, send no EOIs; leave IS0 on the slave and IS2 on the master
  to the game's handler, as on hardware, so the existing EOI logic and ISR
  reads are right unchanged (in shared mode this already happens: IS2 is
  set and irq:331-332 forwards). EOI only the ticks that are not reflected.
  Otherwise, mark a virtual IRQ 8 in service and consume one A0h and one
  20h EOI against it.
- Gap, master bit 2: the game's master mask passes bit 2 to the chip
  (irq:351-363). A game that masks IRQ 2 stops the timer. While the timer
  is held, keep the chip's bit 2 clear and gate reflection on the game's
  bit 2 as well as its A1h bit 0 (ET:259-260 checks only the slave bit).
- Spurious IRQ 15 (inference from 2.1): reading C with PIE on while IRQ 8 is
  pending and IF=0 withdraws the request and produces INT 77h with master
  IS2 set. Read C outside the handler only with PIE off.
- The DPMI host already traps A0h and A1h in protected mode
  (res:294-299; pic:205-300): the timer's A0h/A1h virtualisation must
  be one implementation shared with dpmi_pic_io, not a second one.

## 3. 8237A

### 3.1 What the data sheet says

- Mode register: bits 7:6 00 demand, 01 single, 10 block, 11 cascade; bit 5
  decrement; bit 4 autoinit; bits 3:2 00 verify, 01 write (to memory), 10
  read, 11 illegal; bits 1:0 channel (206:1818-1842; PA:120-136, which omits
  bit 4).
- Single: one transfer per DREQ, count and address step after each; TC
  when the count rolls from 0 to FFFFh (8237:251-258). Block: transfers until
  TC or EOP (8237:272-275, 243-246). Demand: until TC, EOP or DREQ drops;
  only EOP autoinitialises (8237:248-262). Cascade: priority only, no
  address (8237:264-292).
- Autoinit: current registers reloaded from the base registers at EOP; the
  mask bit is not set (8237:296-309; 206:1611-1626). Without autoinit the
  mask bit is set at EOP (8237:421-425; 206:1886-1888; PA:149-150).
- Count: N+1 transfers for a programmed N; FFFFh after TC if not
  autoinitialised (8237:355-372; 206:1752-1758). Base registers are written
  with the current ones and cannot be read (8237:374-384).
- Status: bits 0-3 TC, set at every TC or EOP, "cleared upon Reset and on
  each Status Read"; bits 4-7 request (8237:463-467, 477-482; 206:1957-1966;
  PA:69-79).
- Byte pointer flip-flop: one per controller, for all channels; cleared by
  0Ch, master clear or reset (8237:225-230, 477-483; 206:1497-1503).
- Master clear: clears command, status, request, temporary and the flip-flop,
  sets all masks (8237:485-490, 61-63); the 82C206 also clears its mode-read
  counter (206:1950-1953).
- Masks: single write at 0Ah (bit 2 set/clear, bits 1:0 channel); all four
  at 0Fh; clear all at 0Eh (8237:421-441, 492-494, 511-517).
- Request register (09h): software requests are non-maskable and need block
  mode (8237:399-411).
- Temporary register: read at 0Dh, last byte of a memory-to-memory transfer
  (8237:484-491, 512).
- Reads beyond the 8237A on chipsets: 82C206 reads the request register at
  09h, the command at 0Ah, the four modes in turn at 0Bh (bits 1:0 read 11),
  clears that counter at 0Eh, reads all masks at 0Fh (206:1437-1449,
  1764-1769, 1836).
- 16-bit controller: ports C0h-DFh, XA0 ignored (206:1307, 1497); address in
  words, A16:A1 from the controller, A23:A17 from the page register, page bit
  0 unused (206:1689-1716). Page ports: 87h, 83h, 81h, 82h for channels 0-3,
  8Bh, 89h, 8Ah for 5-7 (206:1680-1708).
- Programming a channel while unmasked can start a transfer after one byte
  (8237:578-603; 206:1505-1512).

### 3.2 Deviations of the DMA emulation (src/audio/trap.asm)

Owned state per controller: flip, mask, page, TC flag at +3, address, count,
snapshot, position, mode (layout.inc:22-29; trap:2200-2207).

| # | Lines | Deviation | Rating |
| --- | --- | --- | --- |
| D1 | trap:1748-1752 | The owned channel's TC bit (+3) is reported but not cleared by the status read (8237:477-480); it clears only on an address or count write (trap:686, 690) | Could matter. The flag doubles as "channel finished" for sb_identify (trap:1974), so a fix needs a separate status-read bit |
| D2 | irq:61-83, trap:1871-1893 | An autoinit wrap never sets TC in the status, though the chip sets it at every TC (8237:477-479) | Could matter (low: a game polling status for block end on autoinit) |
| D3 | trap:1744-1747 | Owned request bit always 0 | Harmless |
| D4 | trap:546-578 | Only single mode with read or write, with or without autoinit, is accepted (49h, 59h, 45h, 55h after the channel bits are forced to 01). Demand (except the virtual ESS, 562-566), block, cascade, verify and decrement fault and are not stored, so the previous mode stays | Could matter (demand or block mode on an SB) |
| D5 | trap:522-525, 692-695, 1923-1931 | The owned channel has its own flip-flop; the chip has one per controller (8237:225-230). Accesses to the owned channel toggle only the virtual one, accesses to other channels (untrapped) only the physical one | Harmless with even access counts; could matter with odd ones |
| D6 | trap:682-691 | Any address byte write resets position and TC, so it moves the current count back to the base; on the chip an address write does not touch the count (8237:527-562) | Harmless |
| D7 | trap:1707-1709 | Reads of 0Ah-0Fh (and D4h-DEh) return FFh: no temporary register (8237:512) and none of the 82C206 read-backs (206:1437-1449) | Harmless |
| D8 | ports:15-35 | 09h and D2h (request register) are not trapped: a software request for the guest channel goes to the physical channel | Could matter (low) |
| D9 | trap:610-629 | Master clear leaves the owned TC flag set (8237:485-490 clears status) | Harmless |
| D10 | trap:601-629, 2021-2044 | Protection covers only the controller carrying the output ring. With the ring on the 8-bit controller, a game's master clear at DAh, mask of channel 4 (D4h/DEh) or disable bit at D0h stops the cascade and so the ring | Could matter (rare; on bare hardware the same write would also stop channels 0-3) |
| D11 | trap:1964-2018 | E2h: TC sets +3 but not the mask; the decrement path (1989-1992) is unreachable because D4 refuses bit 5; with the channel not ready the byte goes to 22Ah instead of waiting for DMA | Harmless |
| D12 | trap:1876-1889 | At an exact lap boundary the count reads 0 (end of the old lap) instead of the reloaded base; documented, for HMI | Harmless |
| D13 | trap:1396-1397 | An 8-bit buffer crossing 64 KiB is refused; the chip wraps inside the page | Harmless |
| D14 | trap:1829-1931 | Low-byte read takes a snapshot, high byte reads it: coherent, unlike the chip | Harmless |
| ok | trap:1378-1401, 1847-1849, 1916-1920 | 16-bit: address and count in words, page bit 0 ignored, 128 KiB window: matches 206:1689-1716. N+1 convention kept everywhere (trap:1291, 1357, 1872; irq:68-69). FFFFh after TC (trap:1868-1869) matches 8237:371-372 | Correct |

## 4. 8254 PIT

- Doc: counter latch = control word with RW=00; D3-D0 are don't care, so
  00h-0Fh all latch counter 0; a second latch before the read is ignored;
  a two-byte counter needs two reads (IPC:66402-66466; PA:6906-6916).
- Doc: read-back (11 COUNT# STATUS# CNT2 CNT1 CNT0 0); with count and status
  latched, the first read returns status, the next one or two the count
  (IPC:66422-66525; PA:6880-6887, 6940-6951).
- Doc: mode 2 reloads at the end of the cycle; mode 3 counts down by two,
  twice per period, and a new count loads at the end of the half-cycle
  (IPC:66628-66717, 66721-66776; PA:6930-6934).
- Doc: no routine may interrupt between the two bytes of a read or write of
  the same counter (IPC:66346-66351, 66417-66420); RBIL adds that a 43h write must be followed at once by the counter access (PA:6892-6895) and that unlatched 16-bit reads can tear (PA:6887-6891).
- Code: 40h and 43h are trapped only in the protected-mode host and only
  with the refill hint built (res:215-229, 298). Every access goes to the
  chip at once and in order: byte writes (res:992), byte reads (res:1003),
  word accesses (res:952-956, 971-980). Neither driver nor host touches the
  PIT itself (no `out`/`in` on 40h-43h in src). So the PIT state machine is
  untouched and the IPC:66417-66420 rule holds. Correct.
- Code vs. doc, the hint only: 43h=00h exactly arms two reads (res:994-998).
  01h-0Fh latch counter 0 too but are missed; read-back latches (C2h, D2h)
  are missed; an LSB-only counter latches with one read, so the hint fires
  on the next unlatched read. All harmless: a missed or late hint, never a
  changed count.

## 5. BIOS INT 15h AH=83h/86h and INT 70h

- Doc: AH=83h AL=00h sets an event wait of CX:DX us, setting bit 7 of ES:BX
  at the end; AL=01h cancels; CF set if busy; "the resolution of the wait
  period is 977 microseconds on many systems because many BIOSes use the
  1/1024 second fast interrupt ... on INT 70"; the 1984 AT BIOS ignores AL
  (IC:5426-5443). AH=86h waits CX:DX us, CF set if an AH=83h wait is
  active; newer BIOSes may use other timers (IC:5578-5590).
- Doc: state in the BIOS data area: 40:98h pointer to the user flag, 40:9Ch
  remaining microseconds (dword), 40:A0h bit 7 elapsed, bit 0 AH=86h
  active (MEM:1099-1131).
- Doc: INT 70h runs on alarm or periodic interrupts, by default 1024 Hz;
  "many BIOSes turn off the periodic interrupt in the INT 70h handler unless
  in an event wait"; masked by A1h bit 0 (IQ:2983-2990). The INT 1Ah alarm
  (AH=06h) is delivered as INT 4Ah from the same IRQ (ID:5925-5945).
- Inference, how the BIOS uses the tick: its INT 70h reads C, and for PF
  subtracts a fixed 976 from 40:9Ch (it assumes rate 6, the usual 26h of
  CMOS:208, 219-227), then on expiry clears PIE through B and sets the
  flags; for AF it calls INT 4Ah; then EOI to A0h and 20h.
- Bearing on tick splitting (ET:256-264, 285-292):
  - The BIOS needs PF in its register C copy on every tick it receives,
    and it receives the tick through the game's IVT 70h: right as designed.
  - Its PIE-off write lands in the game's copy in owned mode (trapped) and
    on the chip in shared mode; the latter is caught by the tick-interval
    check (ET:196-202). Right.
  - It assumes 976 us per tick, so its virtual rate must be what register A
    says, at the chip-independent phase: the 1.9 accumulator error (up to
    854 us per fast burst) shortens or lengthens a SCUMM one-tick wait by up
    to one tick. A real 1-tick AH=86h wait already varies from 0 to 1953 us,
    so the effect is within hardware jitter, but it accumulates over long
    waits only if bursts are frequent.
  - The BIOS sends the A0h/20h EOI pair (ET:282-283): the 2.3 gap applies
    to every reflected BIOS tick.
  - AF with AIE (INT 1Ah alarm) must be reflected too (1.9 table).
  - A game hooking INT 70h that reads C and chains to the BIOS leaves the
    BIOS a cleared C, as on hardware; the copy semantics reproduce that.

## 6. Summary of likely bugs and gaps

Code (rated bug or could matter):
1. irq:284-291 (and pic:246-255): non-specific EOI with nonzero L bits
   (21h-27h, A1h-A7h) is dropped as a fault; the IS bit never clears. Bug.
2. irq:261-264: poll answered as an IRR read, not 80h+level, no IS set,
   prior ISR selection lost. Could matter.
3. irq:266-296: OCW3 no-op and combined SMM+RR forms dropped. Could matter.
4. trap:1748-1752: virtual DMA TC bit not cleared by a status read; no TC on
   autoinit wraps (D2). Could matter.
5. trap:546-578: demand/block/verify/decrement modes refused and not
   stored. Could matter.
6. trap:1765-1773: acknowledged-before-INTA request still delivered as the
   guest IRQ instead of vanishing into a spurious IRQ 7. Could matter.
7. trap:601-629: ring protection misses the cascade channel 4 when the ring
   is on the 8-bit controller. Could matter.

Design (event-timer.md 4.3/4.4):
8. ET:131-133: bit 7 clear enables NMI; it does not keep the BIOS state.
9. ET:259-261, 278-283: EOIs sent before a reflected tick make the game's
   20h EOI end the virtual SB interrupt or a lower physical IS bit.
10. irq:351-363 vs ET:272-276: master mask bit 2 passes to the chip; a game
    masking IRQ 2 stops the timer.
11. ET:262-263: a fixed 1 or 8 units per tick miscounts across rate switches.
12. ET:123-126: stale PF gives an immediate tick on PIE enable.
13. ET:230: DV bits passed through can stop or rescale the chain.
14. ET:258-261: AF/UF interrupts with AIE/UIE are not reflected.
15. Minor: index write-back without 71h (ET:227-229), 70h reads and aliases
    72h-77h, the 244 us window under trap cost.
