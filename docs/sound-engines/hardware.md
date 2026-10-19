# The hardware every engine talks to

A quick reference to the parts of a Sound Blaster-era PC that the game sound
engines in this library program. Each engine page describes its own sequences
in these terms. Sources: Creative's *Sound Blaster Series Hardware Programming
Guide* (cited as SBG with a line number, as in [vsb-spec.md](../vsb-spec.md)), the Intel 8237A and
8259A data sheets, and what the engine traces in this library show (86Box,
through uCDD's port trap; see [method](README.md#how-these-notes-were-made)).

## The Sound Blaster DSP

The DSP sits at base+6 to base+Fh (base 220h, sometimes 240h).

| Port | Read | Write |
|---|---|---|
| base+6 | | Reset: write 1, wait 3 us, write 0; then read AAh from base+Ah (SBG:900-921) |
| base+Ah | Data byte from the DSP (a reply, a version byte, a MIDI byte) | |
| base+Ch | Write status: bit 7 set = busy, wait before writing | Command or argument byte |
| base+Eh | Read status: bit 7 set = a byte is waiting at base+Ah. **Reading it acknowledges an 8-bit DMA interrupt** (SBG:1016) | |
| base+Fh | **Reading it acknowledges a 16-bit DMA interrupt** (SB16 only, SBG:1084) | |
| base+4 / base+5 | Mixer index / data (SB Pro and SB16) | |

### The DSP commands engines actually use

| Command | What it does | Arguments | Cards |
|---|---|---|---|
| D1h / D3h | Speaker (DAC output) on / off | | all; on 4.xx only a flag that D8h reports, the output stays on (SBG:3914-3953); on 1.xx they also pause the DMA |
| E1h | DSP version: two reply bytes, major then minor (SBG:448) | | all |
| E0h | Identify: returns the argument inverted | 1 | 2.0 and later |
| E2h | DMA identification (writes a byte by DMA) | 1 | all (undocumented, used by some probes) |
| F2h | Force an 8-bit interrupt: the card raises its IRQ once. **Used by engines to find the IRQ** | | all |
| F3h | Force a 16-bit interrupt | | SB16 |
| 40h | Time constant: rate = 1,000,000 / (256 - TC) for mono, half for stereo | 1 | all |
| 41h / 42h | Output / input sampling rate in Hz, high byte first (SBG:2050-2061, 3564-3599) | 2 | SB16 (4.xx) |
| 48h | Block size for auto-init and high-speed modes, minus 1, low byte first | 2 | 2.0 and later |
| 10h | Direct 8-bit output: one sample, no DMA | 1 | all |
| 14h | 8-bit single-cycle DMA output, length minus 1 | 2 | all |
| 1Ch | 8-bit auto-init DMA output (length from 48h) | | 2.0 and later |
| 90h / 91h | 8-bit high-speed auto-init / single-cycle output (length from 48h) | | 2.01 and later, SB Pro |
| 74h-77h, 16h, 17h, 1Fh, 7Dh, 7Fh | ADPCM output (4-, 2.6- and 2-bit) | | all |
| D0h / D4h | Pause / continue 8-bit DMA | | all |
| D5h / D6h | Pause / continue 16-bit DMA | | SB16 |
| DAh / D9h | Exit 8-bit / 16-bit auto-init after the current block | | 2.0 and later / SB16 |
| B0h-BFh | 16-bit DMA I/O: bit 3 input, bit 2 auto-init, bit 1 FIFO on; then a mode byte and the length minus 1 (SBG:3837-3888) | 3 | SB16 |
| C0h-CFh | 8-bit DMA I/O, the same layout | 3 | SB16 |

The **mode byte** after a Bxh or Cxh command (SBG:2079-2085): bit 4 =
signed samples, bit 5 = stereo. So 00h is 8-bit mono unsigned, 20h 8-bit
stereo unsigned, 10h 16-bit mono signed, 30h 16-bit stereo signed.

**SB Pro stereo** has no mode byte: the game sets mixer register 0Eh bit 1,
sends the time constant for twice the rate, and plays a silent byte first
(the "priming" byte) so the channels start in step.

### Interrupt acknowledge, the SB16 way

On an SB16 the 8-bit DMA, the 16-bit DMA and the MPU-401 share one IRQ line.
An interrupt handler reads **mixer register 82h** to see which one fired
(SBG:1030-1084): bit 0 = 8-bit DMA, bit 1 = 16-bit DMA, bit 2 = MPU-401. Then
it reads base+Eh (8-bit) or base+Fh (16-bit) to acknowledge, and sends the
EOI to the interrupt controller. Older engines, written for one interrupt
source, skip 82h and just read base+Eh.

## The 8237 DMA controllers

Sound uses an 8-bit channel (0 to 3, almost always 1) and, on the SB16, a
16-bit channel (5 to 7, almost always 5). Programming one channel:

| Step | 8-bit channel n | 16-bit channel n |
|---|---|---|
| Mask the channel | 0Ah: 04h + n | D4h: 04h + (n - 4) |
| Clear the byte flip-flop | 0Ch: any | D8h: any |
| Mode | 0Bh: 48h + n single-cycle, 58h + n auto-init (read = memory to card) | D6h: the same with n - 4 |
| Address | 2n: low, then high byte | C0h + 4(n - 4): **word** address, low then high |
| Page | 87h, 83h, 81h, 82h for channels 0 to 3 | 8Bh, 89h, 8Ah for 5 to 7 (bits 17-23; bit 16 ignored) |
| Count minus 1 | 2n + 1: low, then high | C2h + 4(n - 4): in **words** |
| Unmask | 0Ah: n | D4h: n - 4 |

A transfer may not cross a 64 KB page (8-bit) or 128 KB page (16-bit).
The **current count** reads back from the count port (clear the flip-flop
first, then low byte, then high byte); engines read it to see how far the
card has played, often twice in a row until two reads agree (the count can
change between the low and the high byte).

Mode byte bits: 7-6 mode (01 single, 00 demand, 10 block), 5 address
decrement, 4 auto-init, 3-2 transfer (10 read = memory to device), 1-0
channel. 19h is therefore channel 1, single, auto-init, read; 49h channel 1,
single-cycle, read.

## The 8259 interrupt controllers

Master at 20h/21h (IRQ 0-7, vectors 08h-0Fh), slave at A0h/A1h (IRQ 8-15,
vectors 70h-77h). A sound handler ends with **EOI**: 20h to port 20h (and to
A0h first for IRQ 8-15). Port 21h is the mask (bit set = line masked).
Engines find the card's IRQ by unmasking candidate lines one at a time (or
all at once) and forcing an interrupt with DSP F2h; the trace of Doom shows
the masks stepping B0h, A0h, 80h, 00h. IRQ 2 on an SB means IRQ 9 (vector
71h) on an AT.

## FM synthesis (OPL2 / OPL3)

AdLib-compatible FM at 388h/389h (index, data), duplicated at base+8/base+9
on Sound Blasters; the SB Pro and SB16 have a second bank at base+0/1 (left)
and base+2/3 (right) for OPL3. Detection: timer 1 and timer 2 tricks through
register 04h, read the status port. Music engines write register pairs
directly, many times per timer tick; no DMA and no interrupt from the chip.

## MIDI: MPU-401

Data at 330h, status/command at 331h. Engines send FFh (reset) then 3Fh
(UART mode) and read FEh (acknowledge); after that every MIDI byte goes to
330h after waiting for bit 6 of 331h to clear. Intelligent mode (the MPU's
own sequencer) is used by a few early drivers (Sierra's MT32.DRV era); most
engines in this library use UART mode.

## The timer (PIT channel 0)

Port 40h (counter 0), 43h (control). Engines reprogram channel 0 to a faster
rate (70 Hz to over 1 kHz) to drive music and mixing, keep calling the
BIOS's 18.2 Hz handler at the right moments, and read the counter (latch
with 00h to 43h, then two reads of 40h) to build fine clocks.
