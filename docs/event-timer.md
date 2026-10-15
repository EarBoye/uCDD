# A virtual card with real-card timing: the event timer design

Status: design, nothing built. Branch `event-timer` carries this document
only. Written against `fixes` d6148e8 and the rig's local branches
ess-position 76c90de, miles-irq 4c4448a, virtual-timing 5c90d13.

## 1. The problem in one sentence

The virtual card has exactly one asynchronous event source, the physical
card's period interrupt, and it is 5.8 ms long on the ES1868 build; every
other virtual event is delivered either at that tick or at the exit of a
trapped port access, so nothing can happen "a few microseconds later" while
the game spins without touching a port.

Everything that has gone wrong with timing so far is one face of this:

| Symptom | Cause in the time model |
| --- | --- |
| Miles ESS driver fails its F2h interrupt test (two F2h writes 3 us apart, one interrupt expected after the DSP's 13 us latency, a 0.5 ms spin) | The virtual interrupt is delivered at the F2h trap exit, so the first F2h is taken and acknowledged before the second is written; the counter reaches 2 and the "== 1" wait times out. The 0.5 ms spin never meets a 5.8 ms tick |
| Descent 2 crackle on the ESS (fixed on virtual-timing) | The 8237 count showed the mix position, one to two periods ahead of what had played |
| Block-end interrupt and the count disagree (open, item 3) | The interrupt is raised when the mix crosses the block boundary; the count now shows the played position, which crosses one to two periods later |
| Auto-init blocks shorter than two periods are refused; DMX on a virtual SB Pro is silent at 256 frames, Apogee's 256-frame blocks fall below the limit at 22 kHz | The mixer runs only at the period tick and must have the game's data two periods ahead of play |
| A single-cycle transfer's completion interrupt | Raised at the next period tick, up to 5.8 ms late. No game failure traced to it yet; any card-speed test that times one would see it |

The read-ahead itself is not the fault. A real ESS has a 256-byte FIFO
(ES1868 data sheet, "Data Buffer with 256-byte FIFO"), which is 1.45 ms of
16-bit stereo at 44.1 kHz; a Sound Blaster 16 has a smaller one. At a
32-frame period our two-period read-ahead is 64 frames, 256 bytes, the same
figure. At 256 frames it is 2048 frames, 11.6 ms, eight times a real FIFO.
The fault is that the read-ahead and the event resolution are both tied to
the physical period, and the ES1868 needs a long one.

## 2. What the hardware does that games depend on

From the CT1741 firmware (S95Sedan), the SB hardware programming guide and
the ESS sheets:

- A DSP command is processed by a firmware loop. F2h sets the interrupt
  request a few microseconds after the write; DOSBox-X models 13 us, the
  bare run measured the acknowledge at 13 us. A second F2h while the request
  is still set does nothing: the request is a level, cleared by the 22Eh
  read, not a counter.
- The 8237 count moves one unit per sample at the programmed rate, and the
  block-end interrupt is raised when it wraps (auto-init) or expires
  (single-cycle), at the same instant. A handler that reads the count sees it
  just past the boundary.
- E2h writes its answer byte through the DMA channel without an interrupt
  (already matched: sb_identify, verified by E2TEST).
- Reset, version and status reads answer within microseconds and games poll
  them; instant answers are indistinguishable.
- PCM playback is paced by the DMA request, ADPCM and 80h silence by the
  firmware's own timer.

So the behaviours to reproduce are two: a short fixed latency between a
command and its interrupt, and an interrupt at the sample where the count
wraps. Both need an event source finer than the output period.

## 3. Event sources on a 386 to Pentium III PC

| Source | Resolution | Who owns it | Verdict |
| --- | --- | --- | --- |
| Physical card period IRQ | one period, 0.7 to 5.8 ms | ours | What we have. Keeps the `periods` counter and the clock sync; cannot be made finer without shrinking the period, which the ES1868 refuses |
| Physical 8237 count (output_clock) | one frame, 22.7 us at 44.1 kHz | ours | The right clock. Already sample-accurate. A clock, not an event source |
| PIT channel 0 | 0.84 us | the game | Virtualising it means modelling the counter for games that read 40h for timing (Build engine, Descent) as well as the reload rate. Large and fragile; every emulator's PIT model is a cautionary tale. The host already trap-counts 40h/43h for the refill hint, so reading it as a clock would be possible, but we do not need a second clock |
| PIT channels 1, 2 | | board, speaker | No interrupt |
| RTC periodic interrupt, IRQ 8 (MC146818, RBIL CMOS.LST tables C0001 to C0003) | 122 us to 500 ms in powers of two; 976.6 us default | nobody in DOS games, to a first approximation | The candidate. One index port, three status registers, a flag read per interrupt. Present on every AT-class board from 1984 on, so platform-agnostic within the project's range |
| The physical DSP's own F2h | the chip's latency | ours | Exact for the F2h case only; audio_irq must then tell an F2h interrupt from a period tick, which the SB16 can do through mixer 82h and the SB Pro and ESS only through the DMA position. Rejected as the general mechanism; kept as a possible refinement once the timer exists |
| A second physical channel (SB16 8-bit path during 16-bit output, ES1868 Audio 2, 80h silence as a timer) | programmable | ours | Card-specific, so it fails the pairing matrix; the ES1868 sheet ties Audio 2 to the first channel's rate. Rejected |
| TSC, local APIC timer, HPET | fine | | Pentium only, disabled on uniprocessor boards, or absent in the period. Rejected |

The RTC is the only source that is fine, ours to take, and the same on every
board the project targets.

## 4. The design: an event timer on IRQ 8

### 4.1 Clock

`output_clock` stays the one time axis: output frames since the stream
started, from `periods` and the physical 8237 position. Every deadline is a
frame count on this axis. No PIT reads: the 8237 position is already finer
than any latency we model, and reading it in a trap context is already
proven (the .dma_read path).

### 4.2 Deadlines

A small table of pending events, each a deadline in frames and a kind:

| Kind | Deadline | Today |
| --- | --- | --- |
| F2h, F3h (8-bit and 16-bit interrupt request) | now + 2 frames (45 us at 44.1 kHz; never less than one frame has to pass, so two F2h writes 3 us apart cannot straddle it) | trap exit, instantly |
| Block end, auto-init | the frame where the played position wraps the block | mix tick, when the mix crosses |
| Block end, single-cycle | start + count in frames | next period tick |
| 80h silence end | start + length | period tick |
| WSS block end | the same, on the played position | period tick |

One rule for all of them: a deadline is met when `output_clock` has reached
it, checked at three places: a trap exit (host_io_irq and port_callback,
free), the period tick (free), and the timer tick (section 4.3). Delivery
then goes through the existing paths: virtual_pic_request, host_io_irq's
frame rewrite or audio_irq's tail jump through sb_real_vector, or the host
bridge for a protected-mode handler. Nothing new in delivery; only the time
at which the request is raised changes. Everything the rig built on
miles-irq (real-mode-call delivery, the delivered mark) is used as is.

The block-end kind closes item 3 by definition: the interrupt and the count
come from the same position.

### 4.3 The timer tick

IRQ 8 is taken with the RTC's periodic interrupt at two rates:

- Coarse: 1024 Hz (register A rate 0110b, the power-on default, 976.6 us).
  Runs whenever the virtual card is engaged with a stream open. Each tick:
  read register C (mandatory, or no further interrupt comes), EOI slave
  (A0h) and master (20h) through physical_write, read output_clock, deliver
  every met deadline. In phase 1 this is all it does.
- Fast: 8192 Hz (rate 0011b, 122 us). Entered when the nearest deadline
  lies before the next coarse tick; left at the tick that meets it. A rate
  change takes effect on the divider chain's next boundary at the new rate,
  so the first fast tick comes within 122 us of the switch, and a deadline
  is met within one fast tick. Cost per event: at most eight fast ticks.

Why not fast only, on demand: enabling the periodic interrupt from off
gives a first tick anywhere within one period, the same as a rate switch,
so "off until needed" buys nothing over "coarse until needed" and loses the
regular tick the mixer wants in phase 2. Why not fast always: 8192
interrupts a second is a fifth of a Pentium through the host's real-mode
reflection (26 us each, ISSUES "What the driver costs Doom"), and about half
of a 386.

Register access (RBIL PORTS.A 0070h): write the index to 70h with bit 7
clear so NMI stays as the BIOS left it, follow every 70h write with the 71h
access, interrupts off around the pair. Register A: keep bits 6:4 at 010b
(32768 Hz base), write only bits 3:0. Register B: set bit 6 only; bits 0 to
2 and 7 are the BIOS's time format and stay. Register C is read, never
written.

### 4.4 Taking IRQ 8 without breaking what uses it

The first draft assumed nobody in DOS games uses the RTC. The survey in
section 9 proved that wrong: about twenty titles run the periodic interrupt,
and the BIOS does too for INT 15h AH=83h and 86h. So the virtual RTC is not
an optional courtesy; it has to be complete, and the design below is sized
to the survey.

**Taking the interrupt.** IRQ 8 is taken in Jemm's IRQ slot table (the one
host_irq_dispatch already uses for the card's IRQ, indexed by vector and
called before Jemm reflects through the IVT), at vector 70h. That makes the
timer independent of who owns IVT entry 70h: a game that hooks it through
INT 21h, writes the IVT directly (Future Dimension), or restores it on exit
(Lords of the Realm) changes only where our reflection goes, not whether we
see the tick. Under the DPMI host the same IRQ is singled out the way the
card's IRQ is (a byte in the CDF block, like dpmi_audio_irq).

**When it is held.** Only while the driver is engaged, never while it has
stepped aside, and the slot is installed at audio_engage and removed at
audio_release. Most of the surveyed users are floppy titles that run with no
disc mounted, so the step-aside already leaves them alone. If a game sends
ICW1 to the slave PIC (Inner Worlds remaps it from 70h to 28h), the vector
the slot watches is gone: the timer stands down until audio_release and
deadlines fall back to trap exits and period ticks.

**Two modes.** The cost of trapping 70h and 71h is set by the game's
interrupt handler, not its set-up: each game tick costs two or three RTC
port accesses plus a slave EOI. The rig measured over 40 s, at 26 us a
trap from a protected-mode game:

| Game | Traps a second | Pentium share | Timer held? |
| --- | --- | --- | --- |
| Future Dimension | 4,734 | 12.3 % | yes, CD audio |
| Galactix | 4,096 | 10.6 % | no, floppy |
| A.G.E. | 3,072 | 8.0 % | no, floppy |
| Space Max | 2,998 | 7.8 % | no, floppy |
| Zack (MIDPAK) | 640 | 1.7 % | no, data disc |
| Stronghold (MIDPAK) | 384 | 1.0 % | no, data disc |

Trapping every access is too expensive for a game at 1024 Hz, so the timer
has two modes and moves between them as the game's use changes. Jemm's QPI
traps and untraps single ports (1A06h, 1A07h), so a switch costs a few
calls.

- Owned mode: the game's PIE is off, or its rate is slower than ours. The
  timer runs the chip at its own rate, 70h and 71h are trapped, and the
  game sees the virtual RTC below. A 128 Hz MIDPAK costs 1 to 2 percent
  here; a game with PIE off costs nothing but its rare accesses.
- Shared mode: the game's PIE is on and its rate is at least ours (1024 Hz
  and up). The chip runs at the game's rate, 70h, 71h, A0h and A1h are
  untrapped, the game reads register C and sends its own slave EOI, and
  the timer takes each tick from Jemm's slot without touching the chip.
  The game's handler then costs what it costs with no driver. The timer's
  fast burst is not available here unless the game's own rate is 8192 Hz,
  so deadlines are met within one game tick (976 us at 1024 Hz): Miles's
  0.5 ms F2h test would still fail in shared mode, which takes an RTC game
  that also uses the Miles ESS driver with CD audio, none known.

Leaving shared mode: the timer cannot see a rate or PIE write with the
ports untrapped, so it watches its own ticks instead. At every period tick
it checks the time since the last slot tick; if no tick came within two of
its own coarse intervals, or the interval has grown, the game slowed or
stopped the chip. The timer traps the four ports again, reads register A
and B from the chip into the game's copies (the game's rate and PIE as it
left them), restores its own rate and PIE, and continues in owned mode.
One period at most is lost to the coarse fallback. Entering shared mode
happens at the trapped register B write that turns the game's PIE on at a
fast enough rate, or at a register A write that raises the rate while PIE
is on.

**The game's view in owned mode: a virtual RTC on ports 70h and 71h.**

- Index latch: the game's last index (and its NMI bit 7) is kept. Required:
  Future Dimension selects 0Ch once and its handler then only reads 71h
  (about 110k reads with no 70h write); Galactix's handler ends by
  selecting 0Dh. The
  timer's own handler selects register C and then writes the game's index
  back before it returns, so a game interrupted between its 70h write and
  its 71h access reads the register it selected.
- Register A: bits 6:4 pass through; bits 3:0 (the rate) are the game's,
  stored. Bit 7 is the chip's update-in-progress flag on every read, never
  the bit the game wrote: The Horde writes A9h and then polls bit 7, which
  ends within about 2 ms on a real chip and never if the written bit is
  echoed. The chip runs at the faster of the game's rate and ours.
- Register B: bit 6 (PIE) is the game's, stored, and a read returns the
  stored bit: MIDPAK reads register B about every 7 ms, and the MIDPAK and
  Lords of the Realm libraries test bit 6 to see whether the RTC is already
  taken. The chip's PIE is ours while the timer is held. Every other bit passes through, including SET
  (bit 7) and the time format bits, so clock writes reach the chip (The
  Horde writes register B SET and time registers 00h, 02h, 04h). The
  MC146818 keeps the periodic interrupt running while SET holds updates.
- Register C: the chip's register C is read only by the timer's handler,
  once per hardware tick (it must be, or no further interrupt comes). The
  bits it returns other than PF (AF, UF, from a BIOS alarm or an
  update-ended interrupt) are kept for the game; PF is set in the game's
  copy at each of the game's virtual ticks whether or not its PIE is on
  (the chip sets PF regardless of PIE; no surveyed game polls PF with PIE
  off, but the chip does it, so the copy does). A read with nothing pending
  returns 00h and is not an error: Future Dimension's handler is entered
  about 1,478 times a second, half of them with nothing pending, probably
  because it also calls INT 70h itself. A game's read of register C returns
  its copy and clears it, with bit 7 (IRQF) set when an enabled flag is.
- Registers D and the clock and CMOS bytes (00h to 09h, 0Dh up): pass
  through.

**Tick splitting.** The handler keeps the game's rate as a period in units
of the hardware tick. Each hardware tick adds one tick's time to the game's
accumulator; when it reaches the game's period, the game's PF is set and,
if the game's PIE is set and the game's slave mask bit 0 is clear, the tick
is reflected to the game's IVT 70h entry (or its protected-mode handler)
with the interrupted frame, after our EOIs. The accumulator is in 122 us
units, so it survives our own rate switches (section 4.3) without
disturbing the game's phase. A game at 8192 Hz (IAS) runs the chip at 8192
Hz; every tick is the game's, and ours piggyback on it.

**Order.** Games set up the RTC, the vector and the mask in every order
(Lords of the Realm: B, A, B, vector, C, A1h; MIDPAK: A, vector, C, A1h, B
last; Future Dimension: A, B, A1h, C; Galactix: vector, A, B, A1h). Each
write takes effect on the game's copy at once and the decision to deliver
is made per tick from the copies, so no order is special.

**Slave PIC mask, port A1h.** Trapped while the timer is held. Bit 0 is the
game's, stored; the chip's bit 0 stays clear. Every other bit passes
through. Lords of the Realm sets bit 0 on exit; without this trap the timer
would stop for whatever ran next. A game's ICW sequence on A0h/A1h stands
the timer down as above, since the mask bits then mean another vector base.

**Port A0h.** Trapped only to see ICW1 and EOIs. A game's EOI to the slave
for its own virtual tick goes to the chip only if the chip's IRQ 8 is in
service for the game, the same delivered-mark rule the virtual PIC applies
to IRQ 7; the timer handler sends its own EOIs before it reflects, so the
game's are normally stray and must be swallowed. The A0h and 20h EOI pair
from a game's INT 70h handler is the common pattern (BIOS included).

**The BIOS's own use.** INT 15h AH=83h and 86h (RBIL INTERRUP.C: "many BIOSes
use the 1/1024 second fast interrupt from the AT real-time clock chip which
is available on INT 70") set PIE and the rate through ports 70h and 71h and
count in their own INT 70h handler. Under Jemm that BIOS code runs in
virtual 8086 mode, so its port accesses are trapped like a game's, and its
INT 70h handler receives the virtual ticks at the rate it asked for. Nothing
special is needed, but a static scan cannot find these users, so the
acceptance set must include a game that calls INT 15h AH=86h.

### 4.5 Degradation

Every failure mode falls back to the current behaviour, not worse: RTC
already in use, IRQ 8 masked by a game that writes A1h before we trap it,
the host too busy. The deadlines are still checked at trap exits and period
ticks. The design adds a finer tick; it never removes one.

## 5. Phases, each its own branch, each with an acceptance run

### Phase 1: the timer and the deadlines (the F2h fix and item 3)

Build the tick (4.3), the ownership (4.4), the deadline table (4.2), and
move F2h/F3h, both block-end kinds and 80h onto it. Mixing is untouched.

Acceptance, on the rig: SBT16 S0 to S8 and SADUMP byte-identical on the six
pairings and the virtual ESS; verify-mix 0 bad; E2TEST; a new F2TEST (two
F2h writes 3 us apart, count the interrupts, measure the latency with the
8237 count: expect one interrupt, 23 to 45 us); Theme Hospital's
AUDIODRV.DIG on the virtual ESS plays; Descent 2 click rate unchanged
(about 1/s); Doom, Duke, Heretic, Wolf3D, Witchaven, Warcraft II unchanged;
the RTC users from the survey (section 9) that have CD audio, so the
driver is engaged while they run: Future Dimension (direct IVT 70h write,
1024 and 64 Hz switches for the whole run, so it crosses between shared and
owned mode many times a minute; its cost while engaged must be within noise
of the driver without the timer), The Horde (128 Hz measurement at
start-up, then register B SET and clock writes), Capitalism Plus with its
RTC MIDPAK chosen (128 Hz); the BIOS wait users with CD audio: The Secret of
Monkey Island CD (SCUMM, INT 15h AH=86h waits of 976 us) and Rayman (INT 15h
AH=83h); one RTC user with no audio tracks run with the driver aside, to
confirm the step-aside leaves it alone (A.G.E., whose set-up is an 88k-access
burst); Lords of the Realm followed by a second program,
to confirm A1h bit 0 on exit does not stop the timer; the clock and date
(INT 1Ah and DOS) correct after each run;
realtics on the Pentium and the 386 within noise; CMOS registers A and B
byte-identical before install and after exit.

### Phase 2: the mixer on the timer (the 256-frame limit)

With the coarse tick running, the mixer can fill the ring in slices at every
tick instead of two periods at every period: mix from the last mixed
position up to the played position plus a lead of two coarse ticks (about 2
ms), while the physical DMA period stays whatever the card wants. The
read-ahead becomes 2 ms on every card, a real FIFO's worth, and the shortest
accepted block drops from two periods (11.6 ms at 256 frames) to two ticks.
DMX on a virtual SB Pro at 256 frames, the Apogee 44 kHz case and the
whole "output period decides which games have sound" table go away; the
period becomes a cost knob only.

Cost: 1024 ticks a second with a mix slice in each. The mixing work is the
same total; the per-tick entry is about 15 us on the Pentium without the
host's reflection and about 40 us through it, which is 1.5 to 4 percent.
On a 386 it is more, so the tick rate becomes a configuration byte (512,
1024, 2048) and the 386 keeps 512 or stays on period mixing. Measure before
deciding the default.

Acceptance: the phase 1 set, plus Doom on a virtual SB Pro at 256 frames
with sound, Apogee at 44 kHz, realtics against phase 1 at each tick rate,
and the CD audio mix (verify-mix with a disc) at 256 frames.

### Phase 3: refinements, only if a game demands them

The physical DSP's F2h for exact latency; sub-frame delivery for a test that
measures F2h at under 20 us (none known); the 22Ch busy bit held for a few
microseconds after a command (none known to need it).

## 6. What this does not do

- It does not shrink the ES1868's physical period; phase 2 makes the period
  irrelevant to the game instead.
- It does not change how the game's buffer is read: a game that rewrites
  samples inside the read-ahead window still loses them, as it would inside
  a real FIFO. Phase 2 makes the window hardware-sized.
- It does not model the DSP's command processing time (22Ch busy). Nothing
  found needs it.
- It is not the IRQ 5/7 split. That remains worth doing for its own
  reasons and is independent.

## 7. Open questions for Michael

1. Phase 1 alone fixes Theme Hospital and item 3 at near-zero steady cost.
   Phase 2 is the one that changes the project's shape (the mixer's cadence
   leaves the physical card). Approve phase 1 now and decide phase 2 on its
   measurements, or commit to both?
2. The tick rate default for phase 2: 1024 Hz is the RTC's power-on rate
   and the one every BIOS leaves behind, so it is the least surprising.
3. Done: the survey is in section 9 and section 4.4 is sized to it.

## 8. References used

- docs/references/inter61*.zip: INTERRUP.C INT 15h AH=83h and 86h (the
  BIOS's use of the periodic interrupt).

- docs/references/inter61b.zip: CMOS.LST tables C0001 to C0003 (registers
  A, B, C), PORTS.A 0070h (index port, NMI bit, the 71h follow-up rule).
- docs/references/8259A.pdf: cascade on IRQ 2, priority, EOI to both
  controllers.
- docs/references/ES1868 AudioDrive.pdf: the 256-byte FIFO; B1h bit 6 (DMA
  counter interrupt), the extended-mode programming sequences.
- S95Sedan's CT1741_DSP: F2h as a level request, E2h, the firmware-paced
  commands.
- ISSUES.md: the output period table, the Pentium cost breakdown, the Type F
  measurements.
- The rig's DOSBox-X port log of Theme Hospital on a bare ESS688
  (rig86/runs/dbx/th_iolog.txt) for the F2h timing figures.

## 9. The RTC survey (86Box rig, static scan and DOSBox-X port logs)

Scope: 790 games, 13,636 unique files, 4,950 of them code. 571 of 762
compressed executables unpacked and rescanned; 191 files in 117 games
(PKLITE 154, UPX 13, some odd LZEXE and EXEPACK) not scanned. 34 runtime
logs on 70h, 71h, A0h, A1h and IVT 70h. Full report: rig86/rtc_survey.md.

| Group | Titles | Behaviour |
| --- | --- | --- |
| Periodic interrupt users, confirmed | A.G.E., Galactix, Space Max | 1024 Hz; A.G.E. sets up in one 106 ms burst of about 6,300 repetitions (read B, read A twice, A=26h, read B, B=4Bh, A1h), then only its handler runs |
| | Future Dimension | IVT 70h written directly; 1024 and 64 Hz switched many times a minute |
| | Capitalism, Zack, Stronghold | 128 Hz from MIDPAK's RTC builds (PMIDPAK, TMIDPAK and some MIDPAK.COM do not use the RTC) |
| | Lords of the Realm | 256 Hz; on exit restores the vector and sets A1h bit 0 |
| | The Horde | 128 Hz for about 1 s (a timing measurement), then register B SET and clock writes |
| Same code, not confirmed at runtime | KKND, Lost Vikings 2 (128 Hz), Alien Logic, IAS (8192 Hz), Perfect General II's MIDPAK, the RTC MIDPAK in Ultima III to V, Simon 2, Capitalism Plus | Failed under DOSBox-X or stopped at copy protection |
| | Ultima VII, Serpent Isle | Program 8192 Hz. Their memory manager refuses an EMM, so they never run under the driver |
| Code present, never used | Blood, Redneck Rampage, Shadow Warrior (Build), Seek and Destroy, Puyo Puyo 2's GPS.COM, UniVBE's speed test | No RTC access at runtime |
| Extenders | DOS/4GW, Phar Lap, Borland DPMI16 | Only CMOS 0Fh (shutdown byte) and a PIC mask around a 286-style reset, and only without a VCPI host, so never under JEMMEX. CauseWay, PMODE/W, CWSDPMI, DOS/32A: no RTC code |
| | Inner Worlds' extender | Remaps the slave PIC base from 70h to 28h |
| The five oldest games | Donkey, Softporn, Wizardry I, Ball, Zork I | No RTC or IRQ 8 access |

What it changed in the design: the timer has an owned and a shared mode
(the handlers' trap cost, measured at up to 12 percent of a Pentium, rules
out trapping a 1024 Hz game); the virtual RTC is complete rather than a
stand-down check (register C semantics, tick splitting, rate switching at
the game's pace); the timer takes IRQ 8 in Jemm's slot, not the IVT; A1h
bit 0 is virtualised; clock writes pass through; a slave PIC remap stands
the timer down; and the timer is held only while the driver is engaged.
Confidence: high for the confirmed list, medium for completeness (the
unscanned files and code a byte scan cannot see).

Games on the library's discs with CD audio among the RTC users: Future
Dimension (14 tracks), The Horde (11), Alien Logic (5, static only),
Capitalism Plus (8, only with the RTC MIDPAK). The others (KKND, Lords of
the Realm, Lost Vikings 2, Perfect General II, Capitalism, Simon 2) are data
discs, so the driver has stepped aside while they run.

**BIOS wait users** (static scan of the same files, INT 15h AH=86h and 83h):

| Call | Titles | Notes |
| --- | --- | --- |
| AH=86h, 11 games | Double Dragon 3, IAS, Jill of the Jungle 1 to 3, Liero, Protostar's SETUP, Hannibal's HANSOUND, The Secret of Monkey Island (floppy and CD), Day of the Tentacle, The Patrician, Sword of Aragon, Ultima 0's STUBIT | SCUMM waits 976 us (one 1024 Hz tick); Jill 50 ms; The Patrician 30 ms |
| AH=83h, 6 games | Rayman and Rayman Forever (game, editor and SETSOUND), Space Max, Strife's AVI.EXE (cancel only), Wizardry I, III, V SCANCODE.COM | |
| DPMI 0300h for INT 15h | none | Slipstream 5000 hooks INT 15h rather than calling it |

With CD audio: Monkey Island CD (24 tracks), Rayman (24), Rayman Forever
(19). Whether the calls are reached at runtime is not yet known; only 86Box
can show it, since DOSBox-X implements INT 15h without the RTC.

A BIOS wait counts in its own INT 70h handler by the microseconds a tick is
worth at the rate it set (976 at 1024 Hz). The tick splitting in 4.4 gives
it exactly its own rate whatever the chip runs at, which is the property
these games depend on; a tick delivered at our rate instead would make a
SCUMM wait eight times short during a fast burst.
