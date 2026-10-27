# ESSOUT: native ESS AudioDrive output

Plays μCDD's output through an ESS AudioDrive chip in its own extended
mode, 16-bit stereo at 44.1 kHz, where an ESS could only stand in as a Sound
Blaster Pro before. Developed on the EarBoye/uCDD fork, where it has run on
an ES1868 since 5 Oct 2026, and ported here onto Beta 0.9.4-a6. On this
base it is built and not yet run.

## Why

ESS AudioDrive chips (ES688, ES1688, ES1868, ES1869, ES1878 and others)
were common on sound cards and motherboards. As a physical card for μCDD an
ESS could only run as a Sound Blaster Pro: 8-bit stereo at a nominal 22.05
kHz, with CD audio cut down to fit. In its extended mode the same chip plays
16-bit stereo at 44.1 kHz through its first audio channel, on the 8-bit DMA
channel: the same output ring the driver already uses for a WSS codec.

## The change

UCDDSET offers "ESS AudioDrive" as a physical card (model 4). The driver
then plays 44.1 kHz 16-bit stereo through the chip's extended mode, and
the rest of the driver treats it as the WSS ring (`sb_model` turns model 4
into ring type 2 with `ess_native` set).

- `src/audio/wss_output.asm`: `ess_setup` resets the chip with bit 1 (the
  FIFO cleared), enables the extended commands (C6h), and programs
  auto-initialize DAC, demand transfers of four bytes, 16-bit signed
  stereo, the rate divider and the filter clock, one interrupt a period,
  stereo, and the IRQ and DRQ enables. It saves the mixer registers it
  writes (14h, 22h, 26h), sets the voice level and the master level from
  UCDDSET, then starts the DMA (demand mode) and the DAC. `wss_stop` stops
  the DAC, resets the chip back to Sound Blaster mode and puts the mixer
  back.
- The rate: the chip divides 795.5 kHz, so 44.1 kHz comes out at 44194 Hz.
  The ES1868 and ES1878 can trim their clock to make it exact (register
  BAh bit 6, set only when the chip answers mixer register 40h with 18h,
  then 68h or 78h, as both data sheets describe). On any other chip the
  driver tells the mixer the real rate (44192 Hz), so games and CD audio
  keep time, at the cost of interpolating every CD frame.
- `src/audio/sb16.asm`: `sb_model`; `physical_reset` takes the reset byte
  (`.value`); the interrupt handler acknowledges the ESS by its status
  (2xCh bit 0, then a read of 2xEh).
- `src/audio/pro_output.asm`: `output_prepare` (the DMA ports, the vector
  and the IRQ unmask) for the ESS start; `pro_start` keeps its own copy.
- `src/audio/resident_init.asm`, `src/audio/speaker.asm`: the model is
  mapped before the ring is sized; the speaker test puts the setting back
  after it.
- UCDDSET: the fifth physical model; the ESS mixer takes the Sound Blaster
  Pro master register. Detect does not identify an ESS: it is selected by
  hand.

A second commit on this branch fixes `wss_stop` itself, which the ESS stop
goes through: it read the IRQ number after `LDS` had loaded DS with the old
handler's segment, so the old handler went back on whatever vector that
byte named. `pro_stop` and `sb_stop` already read it first.

Not in this branch:
- The half-rate mode ("ESS AudioDrive (fast)": 22.05 kHz, half the DMA
  traffic and less CPU time). It needs the mixer to make half-rate frames,
  which the 0.9.4-a6 mixer does not.
- The game's FM level on an ESS (0.9.4-a6 sets it for the SB16 and SB Pro).
- A virtual ESS for games set to an ESS, which the fork has but which
  depends on its virtual Sound Blaster work.

## What was tested

On the fork's own line:
- The real PC (Pentium MMX 233, 430HX, ES1868F): native output at the full
  and the half rate since 5 Oct 2026, the clock trim applied since the
  identification fix of 13 Oct. Mixing CD audio cost 1.8 percent of the
  Pentium on the exact-rate path, and 4.8 percent interpolating, which is
  what an ESS without the trim pays.
- Only the ES1868 has been run on hardware. The ES688 and ES1688 are not
  known to report the interrupt source bit the driver relies on; the other
  chips follow their data sheets.

On this branch (the change ported onto 0.9.4-a6): built at 128 and 32
frames and without resident audio. Not run yet.
