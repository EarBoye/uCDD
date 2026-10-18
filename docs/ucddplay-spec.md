# UCDDPLAY against the reference library

Status: 18 Oct 2026. The player (src/play.asm and src/play/) read against
the documents on `reference-library`, then made faster without changing
anything it shows or plays. The shared code it includes (cue.asm,
mdm_helper.asm, audio/deemphasis.asm) belongs to the driver and is out of
scope.

Evidence grades as in ISSUES.md: **sheet** (a document says so),
**emulator**, **hardware**. Nothing here has run on the real PC yet.

## 1. Documents

- CD-ROM/MSCDEX21.txt (MSC), CD-ROM/shsucdx.txt.
- Sound_Blaster_Series_Hardware_Programming_Guide.txt (SBG), with the
  Developer Kit reference, which says the same a few lines earlier.
- 8237A.txt, 8259A.txt, the 82C206 sheet (206).
- Ralf Brown's Interrupt List: INTERRUP.A, D, F, G, J, K, N; PORTS.A, B;
  MEMORY.LST.
- notes/hosts-and-cdrom.md, notes/sound-cards.md, notes/timers-pic-dma.md.

The physical-disc path programs whatever card BLASTER names, and the player
refuses to start it unless uCDD with audio is installed. In the setup the
README describes, that card is uCDD's virtual SB16, so the SB16 rows below
are read against Creative's documents, which the virtual card follows.

## 2. Fixed

| ID | Code | Document | Finding | Evidence |
| --- | --- | --- | --- | --- |
| P-1 | physical.asm `physical_fill` | MSC:905-912, error 5 at MSC:340 | READ LONG is 27 bytes: header, mode, address, count, start, read mode, interleave size, interleave skip. The player sent 26, and byte 26 was `control_block+0`, the last IOCTL code. Now 27, with both interleave bytes 0 | Emulator: the request as INT 2Fh AX=1510h receives it, before `1A ... 01 00 0B`, after `1B ... 01 00 00` |
| P-2 | physical.asm `physical_config` | SBG:1111-1115, 2260-2262 | Mixer 80h bits 7:4 are reserved; "Mask them out when testing". The player compared the whole byte, so a card with any reserved bit set was refused. Now `and al, 0Fh` first; IRQ 2 and 10 stay refused (the handler ends only the master PIC) | Emulator, a scripted SB16: 80h = F2h and F4h refused before, IRQ 5 and 7 after; 02h, 04h, 08h, 06h, 01h as before |
| P-3 | physical.asm `physical_volume` | SBG:2606-2607, 2685-2687, 2273 | 32h/33h hold 5 bits of level; "always set the reserved bit to zero". The player wrote the whole 0-255 volume. Now the low 3 bits are cleared | Emulator: writes FFh before, F8h after, at full volume |
| P-4 | eq.asm `eq_calibrate` | MEMORY.LST:640-643, INTERRUP.D:5776 | The tick count is a dword that goes back to 0 after 1800AFh. The timing loop compared low words, so a start within four ticks of midnight ended the loop at once and set `eq_slow`: the equalizer stayed off for the session. Now the dword, with 1800B0h added on a borrow, as `physical_poll` already does | Emulator, the tick advanced as the loop polls it: started at 1800AEh, `eq_slow` set before, not after; started at 10000h, the same both ways |
| P-5 | play.asm `start` | INTERRUP.N:5401-5402, 5410-5411 | INT 33h functions 7 and 8 truncate the ranges to the character cell in text modes. The player set them before switching to mode 13h, so a mouse driver that does not reset them at the mode switch kept 0-632 and 0-192. `init_mouse` now runs after the mode set | Sheet. DOSBox-X: the cursor follows the mouse in the new order |
| P-6 | play.asm `emergency_exit` | INTERRUP.J:8865-8867, G:5128-5129 | DOS jumps to the PSP's terminate address with the parent's registers; EXEC promises the parent only BX and DX destroyed. The handler changed AX, CX, SI, DI, BP, DS and ES before its jump. They are kept now | Sheet. Not exercised: the path needs a critical error answered with abort |

## 3. Recorded, not fixed

Behaviour changes, or deviations no current setup can reach. Each has a
proposed fix; none is made here.

| ID | Code | Document | Finding | Proposal |
| --- | --- | --- | --- | --- |
| M-1 | mount.asm `refresh_drive`, `read_disc` | MSC:623-625, 643-646; RBIL.K:6183-6189 | After a mount, the player sends IOCTL 9 through 1510h and gets FFh; the driver then holds FEh, which answers FFh until an IOCTL input other than 9 or a sector read (driver.asm `ioctl_input` and `read_sectors`, "another request than the media check means the redirector has re-read the disc"). The player itself then sends IOCTL 10 and 11 (`read_disc`) and 4 (`read_volume`), so the driver takes the redirector's re-read as done, and MSCDEX's own next media check gets 1, "not changed": it may keep the old image's directory. `UCDD -mount` sends the same IOCTL 9 and exits at once, so it is not affected; nor is an eject from the player, after which `read_disc` stops at the driver's describe call and sends no IOCTL input. Sheet only | Do not send IOCTL 9 from the player: the mount and eject already set CHANGED to FFh, which survives any other request until a media check. Test in 86Box with MSCDEX and SHSUCDX: mount image A from UCDD, then B from UCDDPLAY, quit, DIR the drive |
| M-2 | drive.asm `send_request` | RBIL.K:6190-6199, MSC:330-331 | 1510h sets CF when the driver was not called and leaves the request unchanged; the player tests only status bit 15, so such a request counts as done with a stale `control_block` | `clc` before the INT (Windows 95 leaves CF as it was), fail on CF or on bit 8 (done) clear |
| M-3 | drive.asm `play_range` | MSC:320-326 | PLAY AUDIO is sent while the drive plays; the spec lets a drive fail requests that move the head while playing, and prescribes STOP AUDIO first. Only uCDD units get PLAY AUDIO from the player (a physical drive plays through READ LONG), and uCDD takes it | STOP first when `play_state` is PLAYING |
| M-4 | drive.asm `read_position` | MSC:722-726 | Q-channel times are used without checking ADR = 1. uCDD always answers ADR 1 (mounted.asm sets bit 0 over a control byte whose low nibble is 0) | Skip the update when the low nibble of byte 1 is not 1 |
| M-5 | drive.asm `set_volume`, `new_request` | MSC:529-531, 865-866, RBIL.K:6197-6198 | Output channels 2 and 3 get volume 0 (the default is FFh; drives without four channels may ignore them). The subunit byte is left to MSCDEX, which NWCDEX before 12/94 did not fill | Harmless with MSCDEX and SHSUCDX |
| M-6 | physical.asm | MSC:960-962, 563-564 | Raw READ LONG of CD-DA is outside MSCDEX 2.1, and IOCTL 6 bit 2 (raw reading) is not checked first. A drive that cannot fails cleanly with the read message | None needed |
| S-1 | physical.asm `physical_irq` | SBG:1026-1032, 1070-1079 | Every interrupt on the line counts as a finished half: mixer 82h is not read and the handler never chains. An MPU-401 or 8-bit interrupt on the same line would refill the half that is playing | Read 82h: bit 1 set, acknowledge, count, EOI; else chain to the old vector without an EOI. Then the mixer index writes elsewhere need CLI |
| S-2 | physical.asm `physical_irq` | 8259A:784-797 | With the card on IRQ 7 a spurious IR7 counts as a half. `physical_stop` reads 2xFh with interrupts on, which can raise one | For IRQ 7, OCW3 0Bh, read port 20h, no count and no EOI when bit 7 is clear |
| S-3 | physical.asm `physical_stop` | SBG:3973-3978, 4024, 2172-2186 | D5h is "Pause"; the documented ends of auto-init are D9h, at the end of the block, or programming a single-cycle transfer. The DSP stays paused in auto-init at exit. Every play resets the DSP first, so the player itself is not affected | D9h before the pause, or reset the DSP after D5h and the mask (a reset is not among the guide's ways for 16-bit auto-init) |
| S-4 | physical.asm `physical_start`, `physical_stop` | none | The whole PIC mask saved at the start is written back at the stop, undoing other programs' changes meanwhile; the start's read-modify-write runs with interrupts on | Under CLI, restore only the card's bit |
| S-5 | physical.asm `phy_commands` | SBG:3920, 3924 | D1h "has no practical effect" on DSP 4.xx, and may hold busy up to 112 ms, longer than the 65535-poll wait | Drop D1h |
| S-6 | physical.asm `physical_position` | 8237A:365-367 | The current count is read in two bytes while the transfer runs, and the sheet describes no latch, so (an inference, not a sentence of the sheet) the bytes can come from either side of a borrow, 256 words apart. Only the displayed position and the pause point move, by less than a sector | Read twice until the high bytes agree |
| S-7 | physical.asm `physical_config` | SBG:944-951, 881-882 | The reset gives up at the first byte that is not AAh, where the guide keeps polling; the delay reads 2x6h, which is write-only | Poll until AAh or the timeout; delay on another port |
| S-8 | physical.asm `physical_config` | SBG:475-487 | Any letter A in BLASTER is taken as the address, not only one that starts a setting | Match A after a space or at the start |
| S-9 | physical.asm `physical_start` | INTERRUP.N:8330 | The buffer's physical address is segment × 16, right only while conventional memory is identity-mapped. VDS exists for this | Lock the buffer through VDS when INT 4Bh offers it |
| B-1 | input.asm `init_mouse` | INTERRUP.N:5317-5319 | INT 33h is called without checking the vector for 0000:0000 or an IRET | Check with INT 21h AX=3533h first |
| B-2 | input.asm `read_keys` | INTERRUP.D:512, 523-524, 527; MEMORY.LST:1076 | INT 16h AH=10h/11h are enhanced-keyboard functions, used without a check | Test 0040:0096h bit 4, else AH=00h/01h |
| B-3 | play.asm `exit` | INTERRUP.A:1101-1102, 2405-2408, 3936 | Mode 3 is set at exit, though a mono VGA (BL = 7, accepted) runs mode 7 | Save the mode from AH=0Fh, restore it |
| B-4 | vis.asm `draw_label` | MEMORY.LST:640-643 | The label's timer has the same midnight wrap as P-4: the label leaves early. Cosmetic | As P-4 |
| B-5 | gfx.asm `wait_retrace` | PORTS.B:7360-7361, 4395 | 3DAh is the colour status port; mode 13h is a colour mode, so this holds | None needed |

## 4. Matched

MSCDEX: request headers of IOCTL input and output (26 bytes, transfer
address at 14, count at 18, MSC:445-453, 790-798), PLAY AUDIO (22, HSG at
13, MSC:1035-1041), STOP and RESUME (13, MSC:1052, 1065); the control
block lengths of codes 4, 9, 10, 11, 12, 15 and output 0 and 3 (MSC:469-480,
808-811); media changed 1/0/FFh (MSC:623-625); track numbers binary and the
Red Book lead-out (MSC:654-661); start and control byte of code 11, bit 40h
data, 10h pre-emphasis (MSC:673-691); TNO in BCD and AMIN/ASEC/AFRAME at
8-10 (MSC:709-723); the paused bit of code 15 (MSC:774-777); busy as
playing (MSC:319-328, 1042-1044); STOP and RESUME as the spec orders them
(MSC:1088-1115); Red Book to HSG (MSC:939); 1500h, 1501h, 150Dh, 1510h
(MSC:1265-1287, 1453-1455, 1594; RBIL.K:5986-5991, 6098-6102).

DOS and BIOS: 19h, 47h, 4409h, 1Ah, 4Eh/4Fh, 6000h, 48h/49h/4Ah
(INTERRUP.F, G, H); the INT 23h IRET and the INT 24h fail answer
(INTERRUP.J:8886, 9032, 8943); DOS restores INT 23h/24h from the PSP
(INTERRUP.F:4502-4503); the command tail and the environment block
(INTERRUP.F:4506, 4537-4539, 4578-4584); 1A00h (INTERRUP.A:3916, 3936);
the retrace bit (PORTS.B:7425) and the DAC write order, with no delay asked
(PORTS.B:5346-5360); INT 33h functions 0, 3, 4, 7 and 8 (INTERRUP.N:5309-5411).

SB16 and the controllers: the reset and its timeout, E1h, 41h high byte
first, B6h with mode 30h, the length as samples less one (SBG:908-1001,
2132-2163, 3575-3577, 3840-3864, 4055-4056); mixer 81h (SBG:1121-1135); the
8237 mask, flip-flop, mode 58h, word address and count ports and page
ports for channels 5-7 (PORTS.A:8318-8320, 9398-9422; 8237A:357-361,
578-603; 206:1709-1712); the 64 KB check, stricter than the 16-bit
channels' 128 KB (SBG:1309-1310); acknowledge on 2xFh, then the specific EOI
(SBG:1055, 1543-1546; 8259A:541, 593-595); the start order ISR, unmask, DMA,
rate, command (SBG:2115-2140); the stop order (SBG:2191-2193).

## 5. Speed

Nothing the player shows or plays changes. Every change was checked
against the unchanged build (f585c30) in an emulator harness (below).

| Change | What it was | What it is |
| --- | --- | --- |
| `present` | 64000 bytes to video memory every frame | A copy of the screen in a 64000-byte block: only the dwords that changed are written, and 4 rows always, so the whole screen is rewritten every 50 frames. The block is taken only when the physical buffer and a disc list could still be had beside it (8453 paragraphs free); without it, the whole frame as before |
| The logo | The generic sprite routine twice a frame (shadow, then logo): 8900 pixels, each with a multiply and four tests | At start, the 210 stretches where the logo is opaque over glass, for each of the two positions. Each frame shades the shadow's 1899 pixels and copies the logo's with REP MOVSB. A logo with more than 256 stretches uses the old routine |
| Sprites | A multiply and four tests a pixel | The columns clipped once, the row offset once a row, one of four inner loops (plain, glass only, shaded, both) |
| FFT | A DIV and two table calls per twiddle, a call per window sample, every value through memory, four IMULs a butterfly | The window as a table; the twiddle angle stepped instead of divided; cos and sin in registers; the 0 and 90 degree twiddles (1534 of 5120 butterflies) without IMUL, as (x << 15) - x, chosen by the table's own values; the others with three IMULs, m = cos (re + im), then m - im (cos - sin) and m - re (cos + sin), the same integers |
| Equalizer | The input pointer, delay position and decimation count read and written in memory each sample; the bypass test in the output loop | Those three in registers for the chunk; the test outside the loop |
| Copper bars, fire, waterfall, plasma | A byte and two tests a pixel over glass | Four pixels at a time where all four are glass. The fire's blur keeps a running sum of the three pixels below (the rows are one run in memory, and a pixel reads only later ones), and its colours and the plasma's are made four at a time while drawing, not into a buffer first |
| Analyzer | Two DIVs and a `fill_rect` call per bar row | The row colours as a table built by the assembler; 5 bytes written |
| Text, label | A call and a bounds test per pixel | The row offset once a glyph row, empty rows skipped |
| Scroller | Two passes over the 296 columns (shadows, then text), each finding the column's character, bit and wave again, two `put_masked` calls a pixel | One pass: a column's shadow, then its text; a shadow lands two columns right, so the text still comes after it. The window's constants keep every pixel on the screen, checked by the assembler |
| Lines | A `put_pixel` call a pixel | The pixel written in place, after the same clip and screen tests |
| `fill_rect`, `shade_rect`, frames | A byte at a time; the frame's whole shadow shaded, then painted over | Dwords; two pixels a turn through XLAT; only the shadow strips that show |
| `pixel_offset` | IMUL by 320 | (y × 4 + y) << 6, the same 16-bit result for every y |

Measured per frame, averaged over 12 to 60 frames; the clock counts are
estimates from the i386 and Pentium tables, for ranking, not timing.

| On the screen (12 frames each) | 386 clocks | Pentium clocks | Video memory written |
| --- | --- | --- | --- |
| Warp speed, playing, the display's name fading | 3.00 M to 1.76 M | 0.98 M to 0.60 M | 64000 to 2218 bytes |
| Fire, playing, the name fading | 4.43 M to 2.90 M | 1.61 M to 1.08 M | 64000 to 9053 |
| Plasma, playing, the name fading | 4.37 M to 2.88 M | 1.60 M to 1.10 M | 64000 to 3728 |
| A message over the stars, playing | 3.22 M to 1.97 M | 1.10 M to 0.72 M | 64000 to 1666 |
| Paused, stars, the name fading | 1.70 M to 0.78 M | 0.52 M to 0.25 M | 64000 to 1862 |
| The requester with the help over it, playing | 8.33 M to 3.85 M | 2.88 M to 1.23 M | 64000 to 1687 |
| The help, playing | 6.48 M to 3.25 M | 2.26 M to 1.10 M | 64000 to 1946 |

On average over a frame the screen changes in 389 of its 16000 dwords
(median 235); a change of display or an overlay opening rewrites up to
11546.

Second round (the scroller, three-IMUL butterflies, lines), each display
held with nothing over it, 10 frames, f585c30 to now:

| On the screen | 386 clocks | Pentium clocks |
| --- | --- | --- |
| Stopped, the scroller | 1.91 M to 0.72 M | 0.59 M to 0.24 M |
| Warp speed, playing | 2.56 M to 1.40 M | 0.85 M to 0.49 M |
| Plasma, playing | 3.00 M to 1.54 M | 1.04 M to 0.54 M |
| Fire, playing | 3.38 M to 1.88 M | 1.21 M to 0.68 M |

DOSBox-X 2024.03.01, the same disc image, the time the 210-frame start-up
message stays up (the loop waits for every retrace, so the rate is 70 / n):

| CPU (cycles) | before | after |
| --- | --- | --- |
| 4000 | 10.0 frames/s | 17.5 |
| 10000 | 23.3 | 34.8 |
| 20000 | 34.9 | 69.9 |

DOSBox-X does not charge for video memory writes (its `vmemdelay` at 300 ns
changed neither build), so these figures leave out the larger saving on an
ISA card, the 62 KB a frame no longer written.

A faster equalizer moves the calibration: `eq_calibrate` times the real
code, so a CPU that was just too slow for the equalizer before may now keep
it on. The threshold is unchanged.

The program needs 4.6 KB more in its segment (58426 of 65534 bytes, most of
it tables) and, when there is room, the 64000-byte screen copy.

## 6. How it was checked

With scripts/playcheck (its README says how to run it). An emulator
harness (Unicorn) loads UCDDPLAY.EXE's image as DOS would and
runs the player's own routines over a scripted session of 1500 frames: CD
audio through `eq_hook` in driver-sized pieces (64 frames mostly, odd sizes
too, and full-scale square waves), every bottom display, the scroller, the
label, the messages, the requester, the help over the requester, play, pause and stop,
no disc, EQ changes and presets, the cursor across every screen edge. After
each frame it compares the screen, the back buffer, the palette writes, the
equalizer's output, the work segment and every variable by name. 1500 of
1500 frames identical, also with the screen copy refused and with the logo
tables refused. Not compared, with the reason in the harness: three
temporaries every user sets before reading (`sprite_rows`, `fft_half`,
`fft_k`), the fire's colour buffer, and the plasma's rows while plasma is
showing (both written and read in the same frame before; `set_visual`
clears them).

The pixel routines (sprites, shaded sprites, `masked_span`, `fill_rect`,
`shade_rect`, `put_pixel`, `put_masked`, `pixel_offset`, `draw_text`,
`draw_tiny`, `draw_line` with random clips) were also called 4000 to 5000 times with random arguments on random
buffers, coordinates far off the screen and wrapping included: same pixels,
same registers. `analyze` ran on 300 random rings (noise, full-scale
squares, sweeps): the same FFT arrays, bars and needles.

DOSBox-X ran both builds on a mixed-mode CUE image under its own MSCDEX:
the same screens for the start, play (with the expected SB16 message, no
uCDD there), help, the requester and exit.

Not run: the physical-disc path end to end, any of it on the real PC, a
mouse driver that does not follow mode switches, the critical-error exit.
