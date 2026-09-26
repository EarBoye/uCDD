; SPDX-FileCopyrightText: 2026 vorvek
; SPDX-License-Identifier: GPL-3.0-only

; Constants of UCDDPLAY.

; drive
%define STOPPED 0
%define PLAYING 1
%define PAUSED 2
%define REPEAT_OFF 0
%define REPEAT_ONE 1
%define REPEAT_ALL 2

; browser
%define ENTRY_TYPE 0
%define ENTRY_NAME 1
%define ENTRY_MB 14
%define ENTRY_SIZE 16
%define ENTRY_UP 0
%define ENTRY_DIR 1
%define ENTRY_FILE 2
%define ENTRY_MAX 400
%define LIST_ROWS 8
%define REQ_X0 40
%define REQ_Y0 42
%define REQ_X1 279
%define REQ_Y1 188
%define LIST_X0 (REQ_X0+10)
%define LIST_Y0 (REQ_Y0+38)
%define LIST_X1 (REQ_X1-18)
%define SCROLL_BAR_X (REQ_X1-15)
%define REQ_BUTTON_Y (REQ_Y1-22)
%define PATH_CHARS 25

; eq
%define EQ_BANDS 10
%define SET_MASK 0
%define SET_PREAMP 2
%define SET_COEFS 6
%define SET_SIZE (SET_COEFS+EQ_BANDS*12)
%define BAND_TABLE (8+25*4)
%define EQ_LOW 4
%define EQ_DECIM 8
%define EQ_DELAY 12
%define EQ_CHUNK 64
%define CH_DELAY 0
%define CH_POS (EQ_DELAY*4)
%define CH_COUNT (CH_POS+2)
%define CH_T1 (CH_POS+4)
%define CH_T2 (CH_T1+4)
%define CH_ACC (CH_T2+4)
%define CH_D1 (CH_ACC+4)
%define CH_D2 (CH_D1+4)
%define CH_VALUE (CH_D2+4)
%define CH_STEP (CH_VALUE+4)
%define CH_CURRENT (CH_STEP+4)
%define CH_V (CH_CURRENT+4)
%define CHANNEL_SIZE (CH_V+EQ_BANDS*8)
%define RING_FRAMES 1024

; fft
%define FFT_SIZE 1024
%define BAR_FLOOR 72
%define BAR_RANGE 136
%define BAR_HEIGHT (ANA_BOTTOM-ANA_TOP+1)
%define VU_FLOOR 60
%define VU_RANGE 66
%define VU_FRAMES 512

; vis
%define STAR_SIZE 4
%define LOGO_STARS 40
%define BOTTOM_STARS 48
%define SCROLL_W (SCROLL_X1-SCROLL_X0+1)
%define SCROLL_H (SCROLL_Y1-SCROLL_Y0+1)
%define FIRE_ROWS (SCROLL_H+3)
%define VIS_COUNT 5
%define VIS_RANDOM VIS_COUNT
%define VIS_FRAMES 1050
%define LABEL_TICKS 55
%define LABEL_FADE 24
%define BUBBLES 96
%define BUBBLE_SIZE 8
%define B_X 0
%define B_Y 2
%define B_SPEED 4
%define B_RADIUS 5
%define B_MAX 6
%define B_COLOR 7
%define BUBBLE_Y (SCROLL_Y1+1)

; ui
%define DIGIT_BYTES (DIGIT_W*DIGIT_H)
%define DIGIT_MINUS 10
%define SLIDER_ZERO ((SLIDER_TOP+SLIDER_BOTTOM)/2)
%define BUTTON_COUNT 8

; input
%define DRAG_NONE 0
%define DRAG_SLIDER 1
%define DRAG_VOLUME 2
%define FLASH_FRAMES 6

; text
%define PRESET_SIZE 19
%define PRESET_COUNT ((presets_end-presets)/PRESET_SIZE)
