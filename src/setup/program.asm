; SPDX-FileCopyrightText: 2026 vorvek
; SPDX-License-Identifier: GPL-3.0-only

; The Program button. A jumperless Sound Blaster 16 (DSP 4.xx, CT2290 and
; later) takes its IRQ and DMA channels from mixer registers 80h and 81h.
; Write the physical settings into them, so that the card listens where
; UCDD.CFG says.
program_action:
    call resident_audio_present
    jnc .free
    mov word [status], resident_test_message
    ret
.free:
    cmp byte [sound_card], 0
    je .model_ok
    mov word [status], program_model_message
    ret
.model_ok:
    ; One bit each: IRQ 2, 5, 7 or 10; DMA 0, 1 or 3; DMA 5, 6 or 7.
    movzx bx, byte [sb_irq]
    cmp bx, 10
    ja .bad_values
    mov al, [program_irq_bits+bx]
    test al, al
    jz .bad_values
    mov [program_irq], al
    movzx bx, byte [sb_dma8]
    cmp bx, 3
    ja .bad_values
    mov al, [program_dma_bits+bx]
    test al, al
    jz .bad_values
    movzx bx, byte [sb_dma16]
    cmp bx, 7
    ja .bad_values
    mov ah, [program_dma_bits+bx]
    test ah, ah
    jz .bad_values
    or al, ah
    mov [program_dma], al
    ; A DSP 4.xx must answer at the port.
    mov dx, [sb_base]
    call det_reset
    jc .no_card
    mov al, 0e1h
    call det_write
    jc .no_card
    call det_read
    jc .no_card
    mov ah, al
    call det_read
    jc .no_card
    cmp ah, 4
    jb .no_card
    mov dx, [sb_base]
    add dx, 4
    mov al, 80h
    mov ah, [program_irq]
    call .mixer_write
    mov al, 81h
    mov ah, [program_dma]
    call .mixer_write
    mov al, 80h
    call .mixer_read
    cmp al, [program_irq]
    jne .refused
    mov al, 81h
    call .mixer_read
    cmp al, [program_dma]
    jne .refused
    mov di, status_buffer
    mov si, program_done_text
    call copy_text
    movzx ax, byte [sb_irq]
    call text_decimal
    mov si, program_dma_text
    call copy_text
    movzx ax, byte [sb_dma8]
    call text_decimal
    mov si, program_and_text
    call copy_text
    movzx ax, byte [sb_dma16]
    call text_decimal
    mov si, program_end_text
    call copy_text
    mov word [status], status_buffer
    ret
.bad_values:
    mov word [status], program_values_message
    ret
.no_card:
    mov word [status], program_no_card_message
    ret
.refused:
    mov word [status], program_refused_message
    ret
; DX mixer index port. AL register, AH value.
.mixer_write:
    out dx, al
    inc dx
    mov al, ah
    out dx, al
    dec dx
    ret
; DX mixer index port. AL register. Return AL value.
.mixer_read:
    out dx, al
    inc dx
    in al, dx
    dec dx
    ret

program_irq db 0
program_dma db 0
; Mixer 80h: bit 0 IRQ 2, bit 1 IRQ 5, bit 2 IRQ 7, bit 3 IRQ 10.
program_irq_bits db 0,0,1,0,0,2,0,4,0,0,8
; Mixer 81h: bits 0, 1 and 3 DMA 0, 1 and 3; bits 5 to 7 DMA 5 to 7.
program_dma_bits db 1,2,0,8,0,20h,40h,80h
program_label db 'Program',0
program_note db 'Write the IRQ and DMA channels into a jumperless Sound Blaster 16.',0
program_model_message db 'Program sets a Sound Blaster 16. Select that model first.',0
program_values_message db 'A Sound Blaster 16 takes IRQ 2, 5, 7 or 10, DMA 0, 1 or 3, and 5, 6 or 7.',0
program_no_card_message db 'No Sound Blaster 16 answers at the port.',0
program_refused_message db 'The card did not take the settings.',0
program_done_text db 'The card is set to IRQ ',0
program_dma_text db ', DMA ',0
program_and_text db ' and ',0
program_end_text db '. Save to keep the settings.',0
