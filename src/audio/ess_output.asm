; SPDX-FileCopyrightText: 2026 vorvek
; SPDX-License-Identifier: GPL-3.0-only

; Experimental. The ESS AudioDrive output in extended mode plays 16-bit stereo
; through audio channel 1 on the 8-bit DMA channel, with the ring of the WSS
; codec. It is backported from the EarBoye/uCDD fork.
; This file holds the code that stays in memory. The start code runs only at
; installation and is in ess_install.asm, which the resident driver keeps in
; its transient part.

%macro ESS_ERROR 1
%ifdef RESIDENT_AUDIO
    mov word [audio_error_text], %1
%endif
%endmacro

%ifdef RESIDENT_AUDIO
; The start code is in the installation image. With a relocated driver it is
; a far call; the caller's DS is the resident segment.
ess_start:
    call far [ess_install_far]
    ret
ess_install_far dd 0
%endif

ess_stop:
    mov ax, 00b8h
    call ess_write
    call output_irq_mask
    ; A reset puts the chip back into the compatible mode.
    mov al, 3
    call physical_reset.value
    call output_halt
    call ess_mixer_restore
    mov byte [sb_running], 0
    ret

; AL: the register. AH: the value.
ess_write:
    call dsp_write
    mov al, ah
    jmp dsp_write

; A reset does not touch the mixer, so the stop puts the registers back.
ess_mixer_restore:
    cmp byte [ess_saved_valid], 0
    je .done
    mov byte [ess_saved_valid], 0
    xor bx, bx
.register:
    mov al, [ess_registers+bx]
    mov ah, [ess_saved+bx]
    call indexed_write
    inc bx
    cmp bx, 3
    jb .register
.done:
    ret

ess_native db 0
; The 22.05 kHz model: the mixer averages each pair of frames.
ess_half db 0
ess_saved_valid db 0
ess_registers db 14h,22h,26h
ess_saved times 3 db 0
