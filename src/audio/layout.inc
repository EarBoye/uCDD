; SPDX-FileCopyrightText: 2026 vorvek
; SPDX-License-Identifier: GPL-3.0-only

%ifndef OUTPUT_SHIFT
%define OUTPUT_SHIFT 12
%endif
%if OUTPUT_SHIFT < 5 || OUTPUT_SHIFT > 12
%error OUTPUT_SHIFT must be 5 to 12.
%endif
%define PERIOD_FRAMES (1 << OUTPUT_SHIFT)
%define PERIOD_BYTES (PERIOD_FRAMES * 4)
%define CD_PREFETCH_BYTES 1028
%define CD_HALF_BYTES (PERIOD_BYTES+PERIOD_BYTES/32+4)
%if CD_HALF_BYTES < CD_PREFETCH_BYTES
%undef CD_HALF_BYTES
%define CD_HALF_BYTES CD_PREFETCH_BYTES
%endif
; The output ring holds RING_PERIODS periods. The mixer fills every period
; behind the DMA position, so an IRQ may be RING_PERIODS-1 periods late.
%ifndef RING_PERIODS
%define RING_PERIODS 3
%endif
%if RING_PERIODS < 2 || RING_PERIODS > 8
%error RING_PERIODS must be 2 to 8.
%endif
%define RING_FRAMES (PERIOD_FRAMES * RING_PERIODS)
%define RING_BYTES (PERIOD_BYTES * RING_PERIODS)
%define RING_WORDS (RING_BYTES / 2)
%define RING_PARAS (RING_BYTES / 16)
%define PERIOD_SCALE (4096 / PERIOD_FRAMES)
%define DMA_FLIP 0
%define DMA_MASK 1
%define DMA_PAGE 2
%define DMA_ADDRESS 4
%define DMA_COUNT 6
%define DMA_SNAPSHOT 8
%define DMA_POSITION 10
%define DMA_MODE 14

%ifdef RESIDENT_AUDIO
%define OUTPUT_RATE dword [output_rate]
%else
%define OUTPUT_RATE 44100
%endif
