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

- Install: at audio_engage, read register B. If bit 6 (periodic) is already
  set, somebody has the RTC; do not install, fall back to today's behaviour
  and note it in the status word UCDDSET shows. Otherwise hook vector 70h,
  set the rate, set bit 6, unmask IRQ 8 at the slave (A1h bit 0) and make
  sure the cascade IRQ 2 is unmasked at the master (21h bit 2; the BIOS
  leaves it so, a game's mask write through our virtual PIC must not hide
  it: extend pic_visible_bits' trick to the cascade bit). Restore all of it
  at audio_release and at the driver's exit.
- Trap 70h and 71h (two more ports; nobody polls CMOS, so no steady cost)
  and A0h and A1h (likewise rare). The game's view: register A rate and
  register B bit 6 as the game last wrote them, register C showing the
  periodic flag on the game's ticks, slave mask with bit 0 as the game wrote
  it. If a game turns the periodic interrupt on at rate R, the real RTC
  runs at the faster of R and ours, and the game's handler (the vector it
  installed, chained from ours) is called every ours/R ticks with its
  register C flag set. Reading 70h/71h and A1h back gives the game its own
  values. This is a small virtual RTC, about the size of the virtual PIC's
  mask handling, and it is what makes the timer safe under any game. Games
  that use IRQ 8 at all are rare (a few demos and some protected-mode
  schedulers); games that read the CMOS clock registers do so through
  INT 1Ah, which is untouched.
- Under the DPMI host: IRQ 8 arrives in protected mode. The host already
  singles out the sound card's IRQ (dpmi_audio_irq, twelve sites) and lets
  disk and RTC interrupts through its refill wait (monitor.asm .disk_irq,
  bridge.asm). The timer IRQ gets the same treatment as the audio IRQ: a
  byte in the CDF pointer block names it, the host reflects it to the
  driver's real-mode handler ahead of the client, and the handler's EOIs
  are not counted as the client's. A client that installs a protected-mode
  handler for IRQ 8 is handed the game's ticks the way its IRQ 7 handler
  is handed the virtual card's.
- Under Jemm alone (real-mode game): Jemm reflects IRQ 8 through the IVT
  to our handler. host_io_irq is unchanged.
- Delivery from the timer handler of a virtual IRQ 7 to the game: EOI the
  real IRQ 8 first, then take the virtual interrupt into service and jump
  to the game's handler with the interrupted frame, exactly audio_irq's
  .real_tail. The PIC sees nothing in service; the virtual PIC tracks the
  virtual line. A second timer tick during the game's handler finds the
  virtual line in service and leaves it alone.

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
a game that uses IRQ 8 if we can find one (the rig's 147-game survey can
answer this: grep the binaries for the 70h/71h index writes 0Ah and 0Bh);
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
3. The rig should first run the IRQ 8 survey over the game set before any
   code, so the virtual RTC in 4.4 is sized by evidence.

## 8. References used

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
