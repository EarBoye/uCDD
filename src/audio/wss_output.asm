; SPDX-FileCopyrightText: 2026 vorvek
; SPDX-License-Identifier: GPL-3.0-only

%include "audio/wss_codec.asm"

wss_start:
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
    mov dx, [sb_base]
    add dx, 6
    xor al, al
    call physical_write
    call dma8_output_hook
    cli
    mov dx, 0ah
    mov al, [dma_channel]
    or al, 4
    call physical_write
    mov dx, 0ch
    xor al, al
    call physical_write
    movzx eax, word [output_segment]
    shl eax, 4
    mov ebx, eax
    mov dx, [dma_address_port]
    call physical_write
    mov al, ah
    call physical_write
    shr ebx, 16
    mov al, bl
    mov dx, [dma_page_port]
    call physical_write
    mov ax, RING_BYTES-1
    mov dx, [dma_count_port]
    call physical_write
    mov al, ah
    call physical_write
    mov al, [dma_channel]
    or al, 58h
    mov dx, 0bh
    call physical_write
    mov al, [dma_channel]
    mov dx, 0ah
    call physical_write
    mov ax, 0d09h
    call indexed_write
    mov byte [sb_running], 1
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
    mov ax, 0c09h
    call indexed_write
    mov dx, 0ah
    mov al, [dma_channel]
    or al, 4
    call physical_write
    mov dx, [sb_base]
    add dx, 6
    xor al, al
    call physical_write
    call output_unhook
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
