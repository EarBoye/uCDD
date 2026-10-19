# The smaller engines

Libraries and in-house systems with a handful of games each. One section
per engine: what the trace showed, and what the files say. Grades as in
the [README](README.md#evidence-grades). See [inventory](inventory.md)
for the games.

## DSMI (Digital Sound and Music Interface, Otto Chrons)

A module (MOD/S3M) player library, 1993-1995: C-Dogs, Cyberdogs,
Screamer 2, Screamer Rally, Disney's Sound Source titles.

C-Dogs, SB Pro path on the virtual SB16 [trace]: E1h, D1h, mixer 0Eh=22h
(stereo, output filter off), **time constant E9h** (43478 Hz, so 21739 Hz
per channel), **48h with 61440 and 90h**: high-speed auto-init with one
huge block; the DMA buffer is much smaller, so the card's interrupt
almost never comes. The engine **polls the 8237 count**: 1121 byte reads
(about 560 counts) in 640 accesses, the flip-flop cleared with FFh.

Cyberdogs, SB16 path [trace]: E1h twice, D1h, **42h** (the input-rate
command, 22222 Hz) as its only rate command, then **B6h mode 30h with a
block of 60001 samples** against a DMA buffer of 1024 words: again one
interrupt in a long while, the position from the count (D8h written FFh,
C6h read). C-Dogs sets the timer to 100 Hz and then 560 Hz, its mixing
rate [trace]. On a 4.xx, 42h sets the same rate register as 41h, so this
works on a real SB16 (vsb-spec.md section 13); the virtual SB16 takes 42h
as 41h.

## MIDAS Sound System (Sahara Surfers)

Star Dust [trace]: E1h, 41h 22050 Hz, **B4h mode 10h** (16-bit mono,
**FIFO off**) with a block of 65521 samples, DMA 5; mixer registers
30h-47h all written (levels, 41h/42h input/output gain 80h, 44h-47h
treble and bass 80h); **176 reads of the reset port 2x6h** (a delay
loop); the position by polling channel 5's count (409 byte reads), D8h
cleared before each. Like DSMI, the interrupt is almost unused.

## Allegro (Shawn Hargreaves)

A-Pac [trace]: E1h, D1h, **41h with 22727 Hz** (Allegro's SB16 rate),
DMA 5 mode 59h; reads mixer 22h, 04h, 26h first. The run ended before
the transfer. Guild of Thieves' "Allegro" match is a false hit of the
scan (a 1987 game).

## Loudness Sound System (Tyrian)

Tyrian [trace]: E1h, PIC mask 08h (every line open but IRQ 3), D0h, time
constant C4h, **80h with length 0010h**: a 17-sample silence whose
interrupt names the IRQ (the line then opened alone: 28h). Then time
constant A5h (10989 Hz) and **single-cycle 14h blocks of 384 bytes**
(35 ms), chained from the handler, with an occasional long block (5248
bytes). Music: the timer at 69.6 Hz, the OPL2 written about 300 times a
second with no status reads, mostly levels and pitches (software
envelopes) [trace].

## MicroProse

Darklands, Pirates! Gold [trace]: D3h, E1h, time constant BDh (14925 Hz),
a **2-byte 14h probe** for the IRQ, then single-cycle 14h blocks of 614
and 756 bytes chained from the handler. The 8237 mode is written 59h
(auto-init) once, then 49h (single) per block. Music (Darklands): the
timer at 70.1 Hz (mode 2), OPL3 with the second bank mostly levels, 25
status reads per write [trace].

## Sound Images

Cadaver [trace]: time constant 9Ch (10000 Hz), an **8-byte 14h** probe,
D1h, and the master PIC mask written **00h** (every line open). Mortal
Kombat II did not get past its CD check in the run.

## Melodix

Alien Breed [trace]: D3h, E0h AAh, E1h, **E2h 98h, E2h F6h** (Creative's
DMA identification, twice), the 8237 in mode 45h (write) for it.

## Vision Sound Library

Seek and Destroy [trace]: a stray 00h to the DSP, then the SB Pro mixer
set-up: 00h=00h (reset), 0Eh=02h (stereo), 22h=FFh, 04h=DDh, 26h=AAh,
each read back.

## DiamondWare Sound Toolkit

Found in Carmageddon, GTA, Twinsen's Odyssey and SHCRT [file].
GTA's trace shows Miles 3.5's SB16 sequence (the one-sample probe, B6h
mode 10h, 1024 samples) [trace], so GTA plays its digital sound through
Miles; DiamondWare's part was not seen. Carmageddon and Twinsen did not
run in the 86Box tests.

## AdLib's driver (SOUND.COM, "SOUND-DRIVER-AD-LIB")

Golden Axe, Ghostbusters II, Scorched Earth, Monty Python, Rick Dangerous
2 and others [file]. FM music only, at 388h/389h, which the trace build
does not capture (uCDD passes the OPL straight to the card); no digital
traffic in the runs.

## CMS, Tandy, Covox

Game Blaster/CMS (Bad Blood, Ultima VI, Prince of Persia 2), Tandy
3-voice (port C0h), Covox and Disney Sound Source (the printer port):
not Sound Blaster devices, and not traced. Listed in the inventory for
completeness.

## Liero (own code)

Liero [trace]: E1h, **41h with 22025 Hz**, B6h mode 10h (16-bit mono,
FIFO on), 512 samples a block, DMA 5.

## Battle Race 95 (own code)

Battle Race [trace]: E1h, 41h 22050 Hz, **B6h mode 30h with a block of
61440 samples**, DMA 5 with a buffer of 113Fh+1 words; mixer 26h, 04h,
00h, 0Ah set; it then polls the count with the flip-flop cleared by FFh.
Its loading-screen stop under uCDD is the "two reads agree" loop
recorded in host-cdrom-spec.md section 10.
