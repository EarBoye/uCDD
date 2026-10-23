; SPDX-FileCopyrightText: 2026 vorvek
; SPDX-License-Identifier: GPL-3.0-only

%macro trap_range 2
%ifdef PORT_RANGES
    dw %1,%2
%else
%assign port_index 0
%rep %2
    dw %1+port_index
%assign port_index port_index+1
%endrep
%endif
%endmacro
    trap_range 2,2
    trap_range 8,1
    trap_range 0ah,6
%ifdef MDM_SUPPORT
    trap_range 60h,1
%endif
%ifdef VIRTUAL_IRQ
    trap_range 20h,2
%endif
    trap_range 83h,1
    trap_range 8bh,1
    trap_range 0c4h,1
    trap_range 0c6h,1
    trap_range 0d0h,1
    trap_range 0d4h,1
    trap_range 0d6h,1
    trap_range 0d8h,1
    trap_range 0dah,1
    trap_range 0dch,1
    trap_range 0deh,1
%ifdef PORT_MIXER_LABEL
PORT_MIXER_LABEL:
%endif
    trap_range 224h,4
    ; 2xBh and 2xDh too: the cards before the SB16 read them as 2xAh and
    ; 2xCh (trap.asm, port_callback).
    trap_range 22ah,6
%ifdef WSS_INPUT
    trap_range 530h,8
%endif
%unmacro trap_range 2
