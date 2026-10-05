; SPDX-FileCopyrightText: 2026 vorvek
; SPDX-License-Identifier: GPL-3.0-only

%include "audio/wss_codec.asm"

wss_start:
    cmp byte [ess_native], 0
    jne ess_setup
    call wss_ready
    jc .fail
    mov al, 9
    call wss_read
    test al, 3
    jnz .fail
    xor bx, bx
.save:
    mov al, bl
    call wss_read
    mov [wss_saved+bx], al
    inc bx
    cmp bx, 16
    jb .save
    mov byte [wss_saved_valid], 1
    mov ax, 0c49h
    call indexed_write
    mov ax, 5b48h
    call indexed_write
    call wss_calibrate
    jc .restore_fail
    mov ah, [master_register]
    mov al, 6
    call indexed_write
    mov al, 7
    call indexed_write
    mov ax, 020ah
    call indexed_write
    mov ax, ((PERIOD_FRAMES-1) & 0ffh)*256+15
    call indexed_write
    mov ax, ((PERIOD_FRAMES-1) >> 8)*256+14
    call indexed_write
.dma:
    call output_prepare
    cli
    xor bx, bx
    mov cx, RING_BYTES-1
    mov ah, 58h
    cmp byte [ess_native], 0
    je .program
    ; Demand mode: the controller keeps the bus for all bytes of one request.
    mov ah, 18h
    cmp byte [ess_half], 0
    je .program
    mov cx, RING_BYTES/2-1
.program:
    call pro_dma
    mov byte [sb_running], 1
    cmp byte [ess_native], 0
    je .codec_go
    ; Enable the voice input, then start the auto-initialize DAC transfer.
    mov al, 0d1h
    call dsp_write
    mov ax, 05b8h
    call ess_write
    sti
    jnc .started
    call wss_stop
    stc
.started:
    ret
.codec_go:
    mov dx, [sb_base]
    add dx, 6
    xor al, al
    call physical_write
    mov ax, 0d09h
    call indexed_write
    sti
    clc
    ret
.restore_fail:
    call wss_restore
.fail:
    stc
    ret
wss_stop:
    cmp byte [sb_running], 0
    je .done
    cmp byte [ess_native], 0
    je .codec_stop
    mov ax, 00b8h
    call ess_write
    jmp .mask
.codec_stop:
    mov ax, 0c09h
    call indexed_write
.mask:
    mov dx, 0ah
    mov al, [dma_channel]
    or al, 4
    call physical_write
    cmp byte [ess_native], 0
    je .codec_status
    ; A reset returns the chip to Sound Blaster compatibility mode.
    call physical_reset
    jmp .stopped
.codec_status:
    mov dx, [sb_base]
    add dx, 6
    xor al, al
    call physical_write
.stopped:
    mov dx, 21h
    mov al, [saved_pic]
    call physical_write
    push ds
    lds dx, [old_irq]
    mov al, [sb_irq]
    add al, 8
    mov ah, 25h
    int 21h
    pop ds
    mov byte [sb_running], 0
    call wss_restore
.done:
    ret
wss_restore:
    cmp byte [wss_saved_valid], 0
    je .done
    mov al, 49h
    mov ah, [wss_saved+9]
    call indexed_write
    mov al, 48h
    mov ah, [wss_saved+8]
    call indexed_write
    call wss_calibrate
    xor bx, bx
.register:
    cmp bl, 8
    je .next
    cmp bl, 9
    je .next
    cmp bl, 11
    je .next
    cmp bl, 12
    je .next
    mov al, bl
    mov ah, [wss_saved+bx]
    call indexed_write
.next:
    inc bx
    cmp bx, 16
    jb .register
    mov byte [wss_saved_valid], 0
.done:
    ret
wss_saved times 16 db 0
wss_saved_valid db 0

; ESS AudioDrive extended mode: 16-bit signed stereo through the first audio
; channel, on the 8-bit DMA channel, with the same ring as the WSS codec.
ess_native db 0
; Auto-initialize DAC, demand transfer of four bytes, 16-bit signed stereo.
ess_table:
    db 0b8h,04h, 0b9h,02h, 0b6h,00h, 0b7h,71h, 0b7h,0bch
; 795.5 kHz / 18 = 44194 Hz, taken as 44100: the chip has no closer rate and
; the 0.2% is not audible. Filter clock 7.16 MHz / 5. One interrupt for each
; period.
    db 0a1h,0eeh, 0a2h,0fbh
    db 0a4h,(-PERIOD_BYTES) & 0ffh, 0a5h,((-PERIOD_BYTES) >> 8) & 0ffh
; Half rate: 795.5 kHz / 36. The mixer averages each pair of frames.
    db 0a1h,0dch, 0a2h,0f6h
    db 0a4h,(-PERIOD_BYTES/2) & 0ffh, 0a5h,((-PERIOD_BYTES/2) >> 8) & 0ffh
ess_half db 0
; SI=table of register and value pairs, CX=count.
ess_list:
    lodsw
    call ess_write
    loop ess_list
    ret
; AL=register, AH=value.
ess_write:
    call dsp_write
    mov al, ah
    jmp dsp_write
; AL=register. Keep the bits of CH and set the bits of CL.
ess_modify:
    mov bl, al
    mov al, 0c0h
    call dsp_write
    mov al, bl
    call dsp_write
    jc .done
    push cx
    mov cx, 65535
    mov dx, [sb_base]
    add dx, 0eh
.wait:
    call physical_read
    test al, 80h
    loopz .wait
    pop cx
    jz .fail
    sub dx, 4
    call physical_read
    and al, ch
    or al, cl
    mov ah, al
    mov al, bl
    jmp ess_write
.fail:
    stc
.done:
    ret
ess_setup:
    ; Reset with bit 1 set to clear the FIFO, then enable the extended commands.
    mov al, 3
    call physical_reset.value
    jc ess_modify.done
    mov al, 0c6h
    call dsp_write
    mov si, ess_table
    mov cx, 5
    call ess_list
    cmp byte [ess_half], 0
    je .rate
    add si, 8
.rate:
    mov cl, 4
    call ess_list
    ; Stereo, then the interrupt and DMA request enables.
    mov al, 0a8h
    mov cx, 0f401h
    call ess_modify
    mov al, 0b1h
    mov cx, 0f50h
    call ess_modify
    mov al, 0b2h
    call ess_modify
    jc ess_modify.done
    ; Audio 1 play volume in the mixer.
    mov ax, 0ff14h
    call indexed_write
    mov al, 22h
    mov ah, [master_register]
    call indexed_write
    jmp wss_start.dma
