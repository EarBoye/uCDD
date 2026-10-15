# Hosts and CD-ROM: DPMI, VCPI, XMS/EMS, Jemm QPI, MSCDEX, ISO 9660

Reference notes for uCDD (branch `fixes`). Read only; nothing in the repo was changed.

Conventions: "Doc:" = what a document says (file:line); "Code:" = what uCDD does
(path:line, relative to `/home/user/uCDD/src/`); "Inference:" = my reading. Ratings:
harmless / could matter / bug. Library files (scratchpad/library/): D09/D10 = DPMI 0.9/1.0
specs, VCPI = VCPI v1 (EDM2), XMS = XMS35.txt, EMS = LIM 4.0 wiki text, JR = Jemm Readme,
QPI = Jemm QPI (QPIEMU.txt), all in `Memory managers and DOS extenders/`; MSC =
`CD-ROM/MSCDEX21.txt`, ECMA = `CD-ROM/ECMA-119...`, SHSU = `CD-ROM/shsucdx.txt`;
RBIL.x = `Ralf Brown's Interrupt List/INTERRUP.x`.

## 1. DPMI 0.9 host obligations (with 1.0 notes)

### 1.1 What the spec requires

- Doc 1687h: AX=0, BX bit 0 = 32-bit OK, CL = CPU, DH.DL = version, SI = host data
  paragraphs, ES:DI = entry (D09:587-604). Entry: AX bit 0 = 32-bit, ES = host data; on
  success CS/DS/SS = 64K selectors on the real bases, ES = PSP selector (limit 100h),
  FS=GS=0, ESP high word 0, rest preserved (D09:615-640); 32-bit DS/SS have the Big bit
  (D09:653-659); PSP environment becomes a selector (D09:677-685); DS=SS gives one
  descriptor (D09:689-692); exit only by INT 21h AH=4Ch (D09:645-647).
- Doc IF: POPF/IRET do not change IF, CLI/STI are simulated (D09:304-327). 0900h/0901h/
  0902h: AL = previous/current VIF, CF clear, AH unchanged (D09:2575-2620).
- Doc HW interrupts: always to the PM handler first, the last PM handler reflects to real
  mode, also for IRQs that happen in real mode (D09:335-340, 364-366); locked stack,
  interrupts disabled, STI before IRET (D09:357-363), trace flag reset (D10:1477-1478);
  the virtual PICs can be reprogrammed, base via 0400h (D09:353-356).
- Doc reflection: real-mode INT 1Ch/23h/24h go to PM handlers (D09:398-405); only soft
  INT 00h-07h start with VIF off (D09:409-411); one 4K locked stack, no switch when
  nested (D09:466-475; D10:1214-1221); real-mode stack >= 200h (D09:476-481); all 256
  PM vectors reflect by default except INT 31h and 21h/4Ch (D09:496-505), D10 also
  excludes INT 2Fh (D10:1409-1411).
- Doc 0300h-0302h: structure 00h-30h (D09:1521-1545); everything but SS, SP, CS, IP is
  copied back (D09:1562-1564); SS:SP=0 means a host stack of ~30 words (D09:1567-1570);
  CX words copied (D09:1571-1591); 0300h ignores CS:IP, pushes the structure flags,
  IF/TF clear (D09:1613-1652); 0301h far call (D09:1658-1693); 0302h IRET frame, IF/TF
  clear (D09:1699-1737).
- Doc 0303h: interrupts disabled, DS:(E)SI -> real SS:SP, ES:(E)DI -> structure, locked
  stack, IRET with ES:(E)DI -> structure to load (D09:1743-1770); unchanged CS:IP means
  the callback runs again (D09:1785-1788); reentry is expected (D09:1777-1784;
  D10:1882-1890); at least 16 callbacks (D09:1803-1804).
- Doc exceptions: 0202h CX is "a valid protected mode selector" (D09:1350-1366);
  handler on a locked stack, interrupts off, RETF frame (D09:1405-1427, 1439-1465);
  unhandled or chained to the default: 0-5 and 7 reflect as interrupts, 6 and 8-1Fh
  terminate (D09:1428-1433; D10:1546-1549); 1.0 supersedes 0202h/0203h with
  0210h-0213h (D10:740-752).
- Doc 0400h: DH/DL = current virtual PIC bases (D09:2082-2104). Termination: not inside
  reflected interrupts or nested switches (D09:406-408, 519-524); a 0.9 host must at
  least free 0501h memory, then reissue 4Ch in real mode (D10:1140-1176). 000Dh: first
  16 LDT entries reserved for it, "may not be used by the host" (D09:1142-1160).

### 1.2 Where uCDD's host matches

- 1687h: AX=0, BX=1, CL=3, DX=90 (DH=0, DL=5Ah, the usual 0.9 encoding), SI=0,
  ES:DI=entry (host/dpmi.asm:96-111). Gone when dormant (host/dpmi.asm:99-100).
- Entry: flags masked with IF set (host/dpmi.asm:163-165); PSP environment replaced by
  selector 2Fh and restored at exit (host/dpmi.asm:183-188, 243-244); CS/DS/SS/PSP/env
  descriptors (host/dpmi.asm:644-666); B bit for a 32-bit client's DS and SS
  (host/dpmi.asm:654-657); PSP limit 0FFh (host/dpmi.asm:661); FS=GS=0 and ESP high
  word 0 (host/dpmi.asm:703-715).
- 0900h-0902h: AL=old VIF, AH kept because AX is rewritten from the call's EAX
  (host/dpmi.asm:828-854). Correct.
- 0300h: structure flags POPF'd then `INT n`, so the frame holds them and the handler
  runs with IF/TF clear; TF stripped from the image first (host/monitor.asm:958,
  1640-1643). 0302h pushes the flags and CLIs before the far call (host/monitor.asm:
  1656-1663). SS:SP=0 uses the host stack, CX>2048 words rejected, words copied
  (host/dpmi.asm:868-990). Real-mode DOS terminations through 0300h are refused
  (host/dpmi.asm:880-894).
- Hardware IRQs in PM are EOI'd at the PIC and queued (host/pic.asm:14-31), then
  delivered to the PM handler on a locked-stack frame with flags image IF=0 and VIF
  cleared (host/locked.asm:159-235). IRQs in real mode go through IVT stubs to the PM
  handler first when one is hooked (host/bridge.asm:121-141, 584-667). Real-mode INT
  1Ch/23h/24h get stubs too and keep the VIF (host/bridge.asm:142-167, 693-717;
  host/locked.asm:159-161, 196-201).
- 0400h DH/DL = the VCPI-reported PIC bases (host/dpmi.asm:855-866).
- INT 2Fh 1686h answered in PM (host/dos.asm:289-296).
- Termination: PM INT 21h AH=4Ch/31h/00h end the client through dpmi_finish
  (host/dpmi.asm:1067-1105); a real-mode end is caught through PSP:0Ah
  (host/dpmi.asm:189-197, 268-353).

### 1.3 Deviations (selected: the obligations most likely wrong in a small host)

D-1. 0202h returns 0000:00000000 when the client installed nothing. **bug.**
- Code: host/vectors.asm:44-53 returns the raw dpmi_exceptions slot, which
  dpmi_client_init zeroes (host/dpmi.asm:620-622). Contrast 0204h, which returns the
  default stub when the slot is empty (host/monitor.asm:775-793).
- Doc: CX must be a valid PM selector (D09:1365-1366), and chaining to the default
  must reflect or terminate per the rules above (D09:1428-1433).
- Effect (Inference): a client that saves the 0202h result and chains to it (the usual
  pattern) does a far jump to selector 0, takes #GP inside its handler; the host sees an
  exception while dpmi_exception_active is set and terminates (host/monitor.asm:
  1433-1434). For exceptions 1, 3, 4, 5 the client should have got real-mode reflection.

D-2. Software `INT n` from PM to a PIC vector is fatal. **could matter.**
- Code: IRQ gates are DPL 0 (`mov bl, 8eh`, host/monitor.asm:320-348) and replace the
  DPL 3 gates set for every vector (host/monitor.asm:251-268). Under JemmEx the bases
  are 08h and 70h (read in host/monitor.asm:219-247), so `INT 08h-0Fh` and `INT 70h-77h`
  from ring 3 raise #GP with an IDT error code. mon_exception sends any #GP with a
  nonzero error code to .fault (host/monitor.asm:1164-1165), 13 is not reflected
  (host/monitor.asm:1443-1445) and the client ends.
- Doc: every one of the 256 vectors reflects by default (D09:496-505; D10:1409-1416).
- Inference: games that fake a timer tick or chain the keyboard with `INT 8`/`INT 9`
  in PM would die. A ring-3 #GP whose error code has bit 1 set (IDT) could be decoded
  as a software INT and dispatched like dpmi_software_interrupt.

D-3. A reentered real-mode callback terminates the client. **could matter.**
- Code: dpmi_callback_enter takes the `.nested` path when dpmi_callback_active is set
  and switches to dpmi_callback_abort_entry (host/callback.asm:410-412, 441-453), which
  ends the client with status 14 (host/callback.asm:381-391). There is one static
  register save area and context (host/callback.asm:506-525).
- Doc: reentry is anticipated (D09:1777-1784; D10:1882-1890).
- Inference: a mouse or IRQ-driven callback that fires while another callback's
  handler runs with interrupts enabled (or calls DOS) kills the program.

D-4. Unhandled exceptions 0 and 7 terminate instead of reflecting. **could matter.**
- Code: with no 0203h and no 0205h handler only 1, 3, 4, 5 go to the real-mode vector
  (mask 3Ah, host/monitor.asm:1449-1455; the comment says so on purpose).
- Doc: 0, 1, 2, 3, 4, 5, 7 are reflected as interrupts (D09:1428-1431).
- Inference: a real-mode INT 0 hook (runtime "divide overflow" handlers) or a real-mode
  INT 7 FPU emulator is bypassed. Outcome for most programs is the same (they end).

D-5. Virtual PIC reinitialisation is fatal. **could matter.**
- Code: an OUT of ICW1 (bit 4 set) to 20h/A0h fails the trapped access
  (host/pic.asm:228-230), the I/O path falls to .fault (host/monitor.asm:1296-1320),
  i.e. #GP to the client or termination. 0400h will always report the VCPI bases.
- Doc: the virtualized PICs can be reprogrammed (D09:353-356).
- Inference: rare under DPMI (extenders remap only in raw/VCPI mode).

D-6. 000Dh is not supported and the host uses the reserved low LDT slots.
**could matter (low).**
- Code: functions 0-0Ch only (host/dpmi.asm:761-762); 0Dh falls through
  dpmi_descriptors to unsupported (host/descriptors.asm:90-130). The allocator starts at
  index 1 (host/descriptors.asm:57), and the host keeps LDT 6 and 7 for its locked and
  callback stacks (host/locked.asm:38-42).
- Doc: D09:1142-1160.

Harmless deviations noticed on the way:
- Callback entry leaves the structure's CS:IP stale; nothing writes offsets 2Ah/2Ch on
  entry (host/callback.asm:403-425; only read at 493-496). Doc D09:1785-1788.
- Each nesting level gets a fresh 4K locked-stack page instead of continuing on the
  current one (host/locked.asm:334-348), and more than 4 levels hold IRQs pending
  (host/locked.asm:6, 319-332). Doc D09:466-475.
- DS and SS get separate descriptors even when equal (host/dpmi.asm:649-653). Doc
  D09:689-692.
- CL=3 on every CPU in 1687h and 0400h (host/dpmi.asm:103, 858). Doc D09:594-597.
- The audio IRQ goes to real mode first and disk IRQs (mask 0C000h by default) never
  reach PM handlers (host/monitor.asm:624-660; host/bridge.asm:592-598, 815).
  Design choice; Doc D09:335-340.
- Callback handlers run on their own 4K stack, not the IRQ locked stack
  (host/callback.asm:211-240). Doc D09:466-475 speaks of one stack.

## 2. VCPI as used next to JemmEx

Doc, the calls (VCPI file):
- DE00h presence: AH=0, BH.BL=1.0; absent: AH nonzero, 84h recommended (VCPI:304-314).
- DE01h get PM interface: ES:DI -> page table 0 buffer, DS:SI -> 3 GDT slots; returns
  DI = first unused PTE, EBX = PM entry offset (VCPI:353-405).
- DE02h max physical address (VCPI:410-421). DE03h free 4K pages (VCPI:432-446).
  DE04h/DE05h allocate/free one 4K page (VCPI:456-484). DE06h physical address of a
  page in the first MB (VCPI:488-505). DE07h-DE09h CR0 and debug registers (VCPI:516-550).
- DE0Ah get PIC mappings: BX = master base, CX = slave base (VCPI:565-578).
- DE0Bh set PIC mappings, interrupts disabled; only to inform the server; a client may
  remap only if the PICs are still at the PC defaults and must restore them before it
  ends (VCPI:552-562, 583-605).
- DE0Ch V86 to PM: ESI -> CR3, GDTR, IDTR, LDTR, TR, CS:EIP; interrupts disabled
  (VCPI:611-660). PM to V86 by far call: interrupts disabled, SS:ESP in the first MB,
  DS = selector of the DE01h linear space, frame EIP..GS; clear TS first
  (VCPI:752-799). Undefined PM subfunction: AH nonzero, 8Fh (VCPI:680-686).
- Jemm: NOVCPI disables DE01h (JR:366-370); option SB identity maps 0-3FFFFFh in page
  table 0 (JR:331-345).

Code, what the host uses:
- DE00h, DE06h x2, DE01h, DE0Ah at install (host/monitor.asm:117-220); DE03h-DE05h for
  pages (host/memory.asm:39, 469, 485; host/resident.asm:552); DE0Ch in both directions
  (host/monitor.asm:439, 1592-1613, 1699; host/callback.asm:377, 438, 452;
  host/bridge.asm:575, 784; host/dpmi.asm:306, 1151; host/switch.asm:244). DE02h,
  DE07h-DE09h and DE0Bh are never called.
- The host refuses to run when Jemm's DE01h fills PTEs past 3E0h (option SB), because
  its pages sit at 3E0000h-3FFFFFh (host/monitor.asm:211-218). Matches JR:338-339.
- DE0Ah: called once in monitor_init; requires both bases 8-aligned, master >= 8,
  slave >= 32, both <= 248, distinct, not 30h, not F0h (host/monitor.asm:219-247);
  cached in mon_master/mon_slave and used for the IDT IRQ gates (host/monitor.asm:
  320-348) and 0400h (host/dpmi.asm:859-862). The master range below 32 is shared with
  exceptions; the shared stubs tell an IRQ from an exception by the master ISR bit and,
  for 0Dh, by the stack depth (host/monitor.asm:494-527).
- DE0Bh: not called and not intercepted. The host never remaps the physical PICs and
  emulates the client's PIC writes instead (host/pic.asm:206-356).
- DE00h is answered AH=84h while no client runs and the host is not dormant, to push
  extenders onto DPMI (host/dpmi.asm:79-94). Matches VCPI:313.

Implications when a client remaps the PICs (Inference):
- Dormant mode: the game's extender talks VCPI to JemmEx directly and may remap and
  call DE0Bh. VCPI obliges it to restore before exit (VCPI:604-605). uCDD reads DE0Ah
  only at install, so a client that leaves the PICs remapped (or a TSR VCPI client)
  would leave the host's gates on stale vectors at the next DPMI start. Re-reading
  DE0Ah in dpmi_client_init would close that gap.
- While a uCDD DPMI client runs, the host does not let it remap (D-5).
- The Jemm IRQ slot uCDD takes is entry IRQ+8 of Jemm's table (audio/host_jemm_init.asm:
  157-160), and its ISR test reads the master only (audio/host_jemm.asm:276-286). That
  holds because the SB IRQ is limited to 5 or 7 (setup/config_file.asm:305-306). Whether
  Jemm indexes the table by vector (then the +8 assumes base 08h) is not documented.

VCPI interrupt-flag detail. **harmless.** DE0Ch from V86 requires IF=0 (VCPI:615).
mon_callback_done issues it without CLI after a real-mode call that may have returned
with IF=1 (host/monitor.asm:1671-1699), and so does audio/host_jemm_init.asm:83-85.
Inference: JemmEx enters its INT 67h handler through a ring-0 gate with IF clear, and
an IRQ in the V86 window is taken by the bridge, which saves the full monitor state
(host/bridge.asm:336-400), so no failure is expected.

## 3. XMS 3.5 and EMS 4.0 as they bear on the driver

Doc: the library copy of XMS covers only the 3.5 additions: C8h/C9h/CCh super-extended
query/alloc/lock, CBh move with 40-bit offsets, version 0350h (XMS:70-110); E820h
filtering of memory above 4 GB (XMS:113-117); INT 15h AH=87h extension used by the
XMM in V86 mode, JemmEx 5.80+ only (XMS:120-141). The 2.0/3.0 base functions (A20,
UMB 10h/11h, 09h/0Ah/0Bh/0Ch) are not in this library; their semantics below come
from the code and from general knowledge.

Code, XMS allocations (all from the 0-4 GB pool, AH=09h with KB in DX):
- CD audio queue: 512 KB (audio/mounted.asm:5, 89-104), moves with AH=0Bh
  (audio/mounted.asm:1039-1062); freed with 0Ah (audio/mounted.asm:1209-1215).
- CD read cache: CD_CACHE_KIB (audio/disk_cache.asm:6, 17-19).
- MDM disc list backup (src/mdm.asm:60-74).
- Resident host image: allocated and then locked with AH=0Ch for its physical address
  (host/resident.asm:350-372); unlocked (0Dh) and freed at removal
  (host/resident.asm:641-655).
- No A20 calls anywhere. Inference: under JemmEx the host runs on Jemm's page table 0
  snapshot from DE01h; whether 100000h-10FFEFh wraps follows Jemm's A20 emulation at that
  time. DPMI clients that want the HMA must enable A20 through XMS before entering
  (D09:664-676).

Code, UMBs: uCDD uses DOS, not XMS 10h: link UMBs with 5803h=1 and allocate with
strategy 40h high-only (driver.asm:1724-1760) or 80h high-first for the bridge segment
(host/bridge.asm:48-85), and restores the caller's strategy and link
state. JR:357-362: Jemm hands UMBs out through the XMS API from a table of at most 8
blocks, so DOS=UMB must be active for these calls to find upper memory (Inference).

EMS (optional EMS_QUEUE build): 40h status, 41h frame, 43h allocate 16K pages
(audio/mounted.asm:107-123); each transfer saves the map with 47h, maps logical pages
into physical page 0 with 44h, copies, restores with 48h (audio/mounted.asm:1087-1160);
45h frees (audio/mounted.asm:1194-1205).
- Doc: 47h/48h hold one context per handle and only the LIM 3.x 64K frame
  (EMS:528-541, 1353-1360); a second save on the same handle fails with 8Dh
  (EMS:1413-1415); resident code must save before mapping (EMS:1337-1346).
- Code handles this: a failed save marks an error and skips restore
  (audio/mounted.asm:1093-1101, 1145-1160). Inference: a nested transfer on the same
  handle would fail cleanly with 8Dh, not corrupt the game's map. Only physical page 0
  is used, which is inside the 3.x frame, so 47h/48h cover it. **harmless.**
- JR:316-327: with NOEMS the device is EMMQXXX0 and no frame exists; 41h then fails and
  the EMS queue cannot be used. host_jemm_init.asm:19-26 already tries both names.

## 4. Jemm QPI port trapping

### 4.1 As documented
- QPIEMU (a JLM) implements: AH=03h GetVersion, 1A00h UntrappedIORead, 1A01h
  UntrappedIOWrite, 1A04h UntrappedIO, 1A06h GetIOCallback, 1A07h SetIOCallback,
  1A08h GetPortTrap, 1A09h SetPortTrap, 1A0Ah ClearPortTrap; since 1.2 also 5000h
  (EDX = physical address of Jemm page table 0) (QPI:36-49). Real-mode API with seg:off
  addresses (QPI:33-34).
- Entry point: INT 2Fh AX=1684h BX=4354h, success AL=0, ES:DI = entry (QPI:51-53).
- v1.1: "bit 1 of CH holds IF" (QPI:59).
- Register conventions (QEMM, RBIL.P): 1A00h DX=port, returns BL (RBIL.P:5930-5936);
  1A01h BL=value, DX=port (5938-5944); 1A04h BX=value, CX bit 2 = output, bit 3 =
  word, DX=port, returns BX (5965-5974); 1A06h returns ES:DI (5983-5988); 1A07h
  ES:DI=callback (5990-5995); callback gets AL/AX=data, CL=direction (00h IN, else
  OUT), DX=port, returns CF clear if handled, CF set if not; all other registers go
  back to the program (5997-6007); 1A08h DX=port, returns BL=0/1 (6009-6015); 1A09h
  and 1A0Ah DX=port, CF clear (6017-6028).
- Not documented anywhere in the library: a limit on the number of trapped ports, and
  what happens to a word or dword IN/OUT. Jemm itself does not offer Emm386's trap API
  (JR:355) and its EMMXXXX0 IOCTL interface differs from Emm386 (JR:351-353).

### 4.2 What uCDD does
uCDD does not use QPIEMU. It installs its own QPI provider inside JemmEx and refuses
to start when QPIEMU answers 1684h/4354h (audio/host_jemm_init.asm:6-17). It reads
Jemm internals with IOCTL 4402h on EMMXXXX0/EMMQXXX0, accepting only two version
words, 5605h and 5705h (audio/host_jemm_init.asm:19-56); that interface is undocumented
in the library (JR:351-353), so a new Jemm release can break it (Inference). It hooks
Jemm's I/O handler and V86 API gate (audio/host_jemm_init.asm:115-125), uses the TSS
I/O bitmap (127-140) and the IRQ slot table (141-165), and answers 1684h/4354h
itself (audio/host_jemm.asm:23-32).

Provider (audio/host_jemm.asm:35-146) against the doc:
- 1A00h/1A01h: DX from client EDX, value in BL (lines 70-73, 89-92). Matches.
- 1A06h/1A07h: ES:DI get/set (lines 93-104). Matches.
- 1A09h: up to 64 ports (lines 15-16, 106-108); duplicates fail with CF=1 (110-116);
  sets the bitmap bit and remembers whether Jemm had it set (118-122). QEMM returns CF
  clear (RBIL.P:6017-6022). **harmless** (trap.asm never traps a port twice).
- 1A0Ah: clears the bit only if Jemm had not trapped the port (lines 124-146). Good:
  Jemm's own DMA traps survive.
- AH=03h, 1A04h, 1A08h, 5000h: not provided (non-1Ah chains to Jemm's gate at
  lines 42-43, 66-69; other 1Axxh set CF at 60-61). trap.asm uses none of them.
  **harmless.** 1A0Bh is a private "remove provider" call (lines 74-88,
  audio/host_jemm.asm:368-386).
- Callback dispatch host_io (lines 148-195): only an exact DX match is routed
  (155-161); CH = IF in bit 1 (169-171, matches QPI:59); IF and TF cleared for the call
  (173); CL is passed as Jemm gives it. The callback's CF is never examined
  (175-190): a "not handled" return is not executed physically. Inference: trap.asm
  returns CF=1 only when callback_set is 0 (audio/trap.asm:239-245), which never
  overlaps live traps, so **harmless**.
- Word/dword: Jemm traps a wide access if any covered bitmap bit is set (Inference,
  standard 386 behaviour). A wide access whose first port is not in the list chains to
  Jemm's previous handler (audio/host_jemm.asm:191-195).

Consumer (audio/trap.asm):
- Install: 1A06h must return 0:0 (no other virtualizer), 1A07h, then 1A09h per port
  (audio/trap.asm:6-37). Stepping aside releases and re-traps all but 60h
  (audio/trap.asm:44-80). Removal 1A0Ah per port and restores the old callback
  (audio/trap.asm:81-112). Consistent with the doc.
- Port count: at most 38 (all options, audio/ports.inc:15-45), under the provider's 64.
- Callback ABI: CL bit 2 = OUT and bits 3/4 = word/dword (audio/trap.asm:256, 261,
  338-342). RBIL documents only "CL=0 IN, else OUT" (RBIL.P:6001); the width bits match
  the 1A04h CX layout (RBIL.P:5968-5970). Inference: this is Jemm's internal I/O
  convention, which QPIEMU also passes on. Only a word OUT to base+4 (mixer index and
  data) is handled; other wide accesses set `fault` and are dropped
  (audio/trap.asm:338-356). **could matter** only for a game that uses word I/O on SB
  ports.

## 5. MSCDEX 2.1 device driver interface

### 5.1 Doc summary
- Header: next, attributes (15 char, 14 IOCTL, 11 open/close/RM), strategy, interrupt,
  name, reserved, drive letter (MSCDEX writes it), units (MSC:199-252, 264-270).
  Request header and status: 15 error, 9 busy, 8 done, low byte code (MSC:298-318);
  busy = audio playing, head-moving requests should fail busy+error (MSC:319-328);
  codes (MSC:333-349).
- Commands (MSC:354-381): 0, 3, 7, 11, 12, 13, 14, 128, 130-136. Unknown Command for 1, 2,
  4, 5, 6, 8, 9, 10, 15, 16, 129 and, read-only, 11/134/135 (MSC:383-386); 7 is not on the
  list. Media change = error 0Fh (MSC:388-391). Minimum: cooked Mode 1, HSG
  (MSC:393-395). "WRITE LONG VERIFY Command code = 136" is a typo for 135 (MSC:1159-1161).
- IOCTL input codes/lengths (MSC:461-481): 0 header (5), 1 head (6), 4 channel info (9),
  5 drive bytes (130), 6 status (5), 7 sector size (4), 8 volume size (5), 9 media
  changed (2), 10 disk info (7), 11 track info (7), 12 Q-channel (11), 13 sub-channel
  (13), 14 UPC (11), 15 audio status (11). Status bits (MSC:549-586), RBIL adds 10
  playing, 11 no disc, 12 R-W (RBIL.G:677-690). Sector size 2048/2352 (MSC:588-596).
  Volume size = lead-out MIN*4500+SEC*75+FRAME (MSC:598-608); vendors differ
  (RBIL.G:622-627). Media changed 1/0/FFh (MSC:610-646). Disk info: binary tracks,
  Red Book lead-out (MSC:651-669). Track info: Red Book start, CONTROL high nibble, ADR
  low (MSC:671-695). Q-channel: CONTROL/ADR, TNO, POINT/index unconverted (TNO is BCD
  as on disc), times binary, valid even when idle (MSC:697-726). UPC: Unknown Command
  or Sector Not Found (MSC:751-770). Audio status: paused bit, start/end (MSC:772-783).
- IOCTL output (MSC:785-898): 0 eject, 1 lock, 2 reset, 3 channel control (no-swap
  drives keep channels, MSC:876-877), 4 control string, 5 close tray.
- Addressing: HSG = LBN; Red Book bytes frame/second/minute, binary;
  Sector = M*4500 + S*75 + F - 150 (MSC:922-939). READ LONG +0Dh mode, +0Eh buffer,
  +12h count, +14h start, +18h cooked/raw (MSC:900-975). PLAY = start + sector count
  (MSC:1030-1045). STOP/RESUME state machine (MSC:1060-1119).
- INT 2Fh 15xxh (MSC:1226-1247): 00h, 01h, 02h-04h, 05h, 08h, 0Bh (BX=ADADh, MSC:
  1419-1430), 0Ch, 0Dh, 0Eh, 0Fh, 10h send device request (RBIL.K:6183-6201). SHSUCDX
  extras: 1100h/BABEh and 150Fh CL=-1/-2 (SHSU:190-235).
- What games query (Inference, following MSC:319-328 and MSC:715-717): 1510h with IOCTL
  10/11 for the TOC, 132/133/136 for music, IOCTL 12 and the busy bit to follow play,
  IOCTL 15 for pause/resume, IOCTL 6 and 9 for disc state.

### 5.2 uCDD dispatch check (driver.asm)
uCDD is the device driver only; it implements none of INT 2Fh 15xxh and relies on
MSCDEX or SHSUCDX. It uses 150Bh itself, checking BX=ADADh (audio/stream.asm:77-84).
It links itself after NUL from a program (driver.asm:1397-1413), so command 0 never
arrives. Header: attribute 0C800h, name, units at offset 21 (driver.asm:6-13).

Dispatch (driver.asm:63-149, commands at 103-123): 3, 12, 13, 14 (success), 128, 130
(success), 131-133, 136. Request length < 13 gives 8105h (driver.asm:86-93, 140-147);
a reentered call gets 810Ch (driver.asm:182-187). Busy bit is ORed into successful results while audio plays
(driver.asm:150-163).

Missing or deviating:
- M-1 IOCTL input 1, 4, 12 and output 3 answer Unknown Command on a unit without CD
  audio (plain 2048-byte ISO, audio/resident.asm:59-63), because audio_request only
  accepts SEEK/STOP there (driver.asm:230-235, 380-381, 423-432). Doc: Q-channel must
  answer even when nothing plays (MSC:715-717). **could matter**: a game that polls
  Q-channel or head position on a data-only image gets an error.
- M-2 Commands 7 and 11 are Unknown Command (driver.asm:103-123). 7 is not on the
  allowed-unknown list (MSC:383-386). **harmless.**
- M-3 READ LONG raw mode is refused with Unknown Command (driver.asm:451-452) while
  IOCTL 7 returns 2352 for raw (driver.asm:299-307). Status bit 2 is clear, which is
  consistent (driver.asm:281-298). **harmless.**
- M-4 Volume size returns the lead-out LBA (driver.asm:322-327), 150 less than the
  spec's MSF formula (MSC:598-608); common practice per RBIL.G:622-627. **harmless.**
- M-5 Device status: bit 9 Red Book only with audio (driver.asm:290-293), though
  read_sectors accepts Red Book (driver.asm:455-476); bit 10 "playing" never set;
  bit 11 set with no image (driver.asm:287-289). **harmless.**
- M-6 No error 0Fh on media change; IOCTL 9 reports FFh once, then 1
  (driver.asm:222-229, 309-321). MSC:388-391. **harmless** (MSCDEX polls IOCTL 9).
- M-7 Reads during play succeed with busy set instead of busy+error (driver.asm:150-163,
  437-597) vs MSC:322-325. **harmless**, friendlier.
- M-8 PLAY with a zero count or touching a data track fails 810Ch
  (audio/mounted.asm:442-481). Spec silent. **harmless.**
- Correct: IOCTL 0, 6, 7, 8, 9, 10, 11, 15 (driver.asm:240-374); IOCTL 13 and 14 answer
  Unknown Command (allowed, MSC:767-770 for UPC); eject refused while locked
  (driver.asm:390-391); Red Book conversion with range checks and 8108h past the end
  (driver.asm:455-482, 595-597).

Audio (audio/mounted.asm:213-560):
- Q-channel: CONTROL|ADR=1, TNO in BCD via AAM, index 1 or 0 in the pregap with the
  distance counting down, track and disc MSF in binary (lines 334-385). Matches
  MSC:697-726.
- STOP while playing: paused, start = current MSF; STOP while not playing clears pause
  and locations (lines 415-433). RESUME only when paused, else 810Ch (434-441). PLAY
  records start/end MSF (442-531). Matches MSC:1060-1119.
- Audio status: paused word, start/end in Red Book (lines 299-314). Channel control:
  inputs 2/3 silence, no swapping (lines 270-289), allowed by MSC:876-877. Channel info
  reports 0->0, 1->1 and 2/3 at volume 0 (lines 403-414).
- SEEK stops play and clears pause (lines 386-402); a RESUME after SEEK fails.
  Spec silent. **harmless.**

### 5.3 ISO 9660 fields read when mounting (driver.asm:1039-1135)
- Volume descriptors from sector 16 on (driver.asm:1039; ECMA:713); 192 bytes read each
  (driver.asm:1055-1060).
- Byte 0 type (1 PVD, FFh terminator ends the search with a reject, others skipped),
  bytes 1-5 "CD001", byte 6 version 1 (driver.asm:1061-1076; ECMA:1182-1185, 1084-1093).
- 80/84 Volume Space Size both-byte, must match (driver.asm:1081-1090; ECMA:1190,
  975-980). 128 Logical Block Size = 2048 both-byte as 00080800h (driver.asm:1079;
  ECMA:1194, 954-958).
- Root directory record at 156 (ECMA:1206): LEN_DR >= 34 (156), extent 158/162 both
  ways, data length 166/170 both ways, flags 181 bit 1 = directory, LEN_FI 188 <= 1,
  identifier 189 <= 1 (driver.asm:1098-1131; ECMA:1651-1661, 1715-1727, 1065).
  The 0/1 tolerance on LEN_FI and the name is lenient on purpose (driver.asm:1102-1107).
- High Sierra discs ("CDROM" at offset 9) are rejected; MSCDEX supports them
  (MSC:1512-1560 gives the HSG record). **harmless** for 1990s games.

## 6. Ranked list
- bug: D-1 0202h returns selector 0 (host/vectors.asm:44-53, host/dpmi.asm:620-622).
- could matter: D-2 soft INT 08h-0Fh/70h-77h fatal (host/monitor.asm:320-348, 1164);
  D-3 nested callback fatal (host/callback.asm:410-453); M-1 no Q-channel/head on
  data-only images (driver.asm:230-235, 423-432); D-4 exceptions 0/7 not reflected
  (host/monitor.asm:1449-1455); D-5 PIC ICW1 fatal (host/pic.asm:228-230); D-6 no 000Dh
  (host/dpmi.asm:761); wide SB port I/O dropped (audio/trap.asm:338-356); DE0Ah read once
  (host/monitor.asm:219-247).
