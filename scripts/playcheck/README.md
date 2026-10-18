# playcheck: UCDDPLAY against an earlier build of itself

UCDDPLAY's own routines, run in an emulator on its own image, to show that
a change to the player leaves what it shows and plays bit for bit the same,
and to see where its time goes. It does not replace a run in 86Box or on the
PC: the keyboard, the mouse, the drive and DOS are not in it, and its clock
counts are estimates.

Needs Python 3, NASM, and the Python packages `unicorn` (all commands),
`capstone` (profile) and `Pillow` (shot):

    pip install unicorn capstone pillow

Run from anywhere in the repository; builds go to `build/playcheck`.

    python scripts/playcheck/playcheck.py compare f585c30
    python scripts/playcheck/playcheck.py fuzz f585c30
    python scripts/playcheck/playcheck.py hardware f585c30 work
    python scripts/playcheck/playcheck.py profile work --state fire,1
    python scripts/playcheck/playcheck.py shot work 140,660 shot.png

A revision is built from `git archive`, the working tree as it stands
("work"). `compare` and `fuzz` exit with 1 on any difference.

## How it runs the player

`player.py` assembles src/play.asm with a symbol map, places the assets and
the program as DOS places UCDDPLAY.EXE, gives the back buffer, work segment
and screen copy their segments, and calls routines by name with the
segments the player's start code sets up. Port writes are recorded (the
palette); port 3DAh reads as in retrace.

## compare

A scripted session of 1500 frames, each one turn of `main_loop` without the
keyboard, the mouse and the drive: CD audio through the real `eq_hook` in
driver-sized pieces (64 frames mostly, odd sizes too, full-scale squares at
times), every bottom display, the scroller, the display's name fading, the
messages, the requester, the help over the requester, play, pause and stop,
no disc, EQ changes and presets, the cursor across every screen edge.

After each frame it compares the screen, the back buffer, the port writes,
the equalizer's output, the work segment and every variable of the zero area
and the mutable data, by name: the layout may move between builds. Addresses
held in variables are compared as symbol and offset. The session runs three
times on the working tree: as built, without the screen copy (DOS had no
room), and without the logo tables (the generic sprite path).

Left out of the comparison, each with its reason in `player.py`: three
temporaries that every user sets before reading (`SCRATCH`), the fire's
colour buffer, and the plasma's rows while plasma is showing. The last two
were written and read within one frame by the old code; the new code draws
without them.

A change that alters the session's coverage, or a new temporary, belongs in
`player.py` with its reason. A difference is never made to go away by
widening these lists without one.

## fuzz

The pixel routines (`draw_sprite`, `shade_sprite`, `masked_span`,
`pixel_offset`, `put_pixel`, `put_masked`, `fill_rect`, `shade_rect`,
`draw_text`, `draw_tiny`, `draw_line` with random clips) with random
arguments on random back buffers, coordinates far off the screen and
wrapping included: the same pixels and registers. `analyze` on random rings
(noise, full-scale squares, sweeps): the same FFT arrays, bars and needle
targets.

## hardware

Not a comparison: what each build does against a scripted machine. A Sound
Blaster 16 at 220h with mixer registers 80h/81h in several forms, the volume
writes, the READ LONG request as MSCDEX receives it, and the equalizer
calibration started mid-day and two ticks before midnight.

## profile

Instructions per routine per frame, with clock estimates from the 386 and
Pentium tables (no wait states, no pairing, mid-range for data-dependent
instructions: good for ranking, not for timing), and the bytes written to
the screen. `--state DISPLAY,PLAY` holds a display and a play state with
nothing over it.
