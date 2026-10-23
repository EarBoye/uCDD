; SPDX-FileCopyrightText: 2026 vorvek
; SPDX-License-Identifier: GPL-3.0-only

pro_start:
    call physical_reset
    jc .fail
    cmp byte [sound_card], 3
    je .dma
    mov si, pro_registers
    mov di, pro_saved
    mov cx, 4
.save:
    mov dx, [sb_base]
    add dx, 4
    lodsb
    call physical_write
    inc dx
    call physical_read
    mov [di], al
    inc di
    loop .save
    mov al, 22h
    mov ah, [master_register]
    call indexed_write
    mov ax, 0ff04h
    call indexed_write
    mov al, 0eh
    mov ah, [pro_saved+2]
    or ah, 22h
    call indexed_write
%ifdef RESIDENT_AUDIO
    mov al, [pro_saved+3]
    mov ah, al
    shl ah, 4
    and al, 0f0h
    call fm_init
%endif
.dma:
    call dma8_output_hook
    mov byte [sb_running], 1
    cmp byte [sound_card], 3
    je .mono
    mov byte [pro_priming], 1
    mov es, [output_spare]
    mov byte [es:0], 80h
    xor bx, bx
    xor cx, cx
    mov ah, 48h
    call pro_dma
    call dsp_speaker_on
    mov al, 14h
    call dsp_write
    xor al, al
    call dsp_write
    xor al, al
    call dsp_write
    jc .stop_failed
    ; Wait at least two BIOS ticks for the priming IRQ.
    push 40h
    pop es
    mov cx, [es:6ch]
.prime:
    cmp byte [pro_priming], 0
    je .start
    mov ax, [es:6ch]
    sub ax, cx
    cmp ax, 3
    jb .prime
    call pro_stop
    stc
    ret
.start:
    mov es, [output_segment]
    xor bx, bx
    mov cx, RING_BYTES/4-1
    mov ah, 58h
    call pro_dma
    mov al, 40h
    call dsp_write
    mov al, 233
    call dsp_write
    mov al, 48h
    call dsp_write
    mov al, (PERIOD_BYTES/4-1) & 0ffh
    call dsp_write
    mov al, (PERIOD_BYTES/4-1) >> 8
    call dsp_write
    mov al, 90h
    call dsp_write
    jc .stop_failed
    clc
    ret
.mono:
    mov es, [output_segment]
    xor bx, bx
    mov cx, RING_BYTES/8-1
    mov ah, 58h
    call pro_dma
    mov al, 40h
    call dsp_write
    mov al, 211
    call dsp_write
    call dsp_speaker_on
    call sb_mono_next
    jc .stop_failed
    clc
    ret
.stop_failed:
    call pro_stop
.fail:
    stc
    ret

; D1h, then its time: the DSP may need up to 112 ms for it.
dsp_speaker_on:
    mov al, 0d1h
    call dsp_write
    jc .done
    mov dx, [sb_base]
    add dx, 0ch
    mov bx, 4
.round:
    mov cx, 65535
.busy:
    call physical_read
    test al, 80h
    jz .done
    loop .busy
    dec bx
    jnz .round
.done:
    ret

sb_mono_next:
    mov al, 14h
    call dsp_write
    mov al, (PERIOD_BYTES/8-1) & 0ffh
    call dsp_write
    mov al, (PERIOD_BYTES/8-1) >> 8
    jmp dsp_write

; ES:BX: the buffer. CX: the count less one. AH: the mode.
pro_dma:
    pushf
    cli
    push ax
    mov dx, 0ah
    mov al, [dma_channel]
    or al, 4
    call physical_write
    mov dx, 0ch
    xor al, al
    call physical_write
    mov ax, es
    movzx eax, ax
    shl eax, 4
    movzx ebx, bx
    add eax, ebx
    mov ebx, eax
    mov dx, [dma_address_port]
    call physical_write
    mov al, ah
    call physical_write
    shr ebx, 16
    mov al, bl
    mov dx, [dma_page_port]
    call physical_write
    mov ax, cx
    mov dx, [dma_count_port]
    call physical_write
    mov al, ah
    call physical_write
    pop ax
    mov al, [dma_channel]
    or al, ah
    mov dx, 0bh
    call physical_write
    mov al, [dma_channel]
    mov dx, 0ah
    call physical_write
    popf
    ret

pro_stop:
    cmp byte [sb_running], 0
    je .done
    ; Mask the IRQ before the reset, so that no block end runs the handler.
    pushf
    cli
    mov dx, 21h
    call physical_read
    mov cl, [sb_irq]
    mov ah, 1
    shl ah, cl
    or al, ah
    call physical_write
    popf
    call physical_reset
    mov al, 0d3h
    call dsp_write
    mov dx, 0ah
    mov al, [dma_channel]
    or al, 4
    call physical_write
    mov dx, [sb_base]
    add dx, 0eh
    call physical_read
    call output_unhook
    cmp byte [sound_card], 3
    je .stopped
    xor bx, bx
.restore:
    mov al, [pro_registers+bx]
    mov ah, [pro_saved+bx]
    call indexed_write
    inc bx
    cmp bx, 4
    jb .restore
.stopped:
    mov byte [sb_running], 0
.done:
    ret

pro_registers db 22h,04h,0eh,26h
pro_saved times 4 db 0
pro_priming db 0
