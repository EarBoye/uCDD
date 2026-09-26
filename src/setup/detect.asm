; SPDX-FileCopyrightText: 2026 vorvek
; SPDX-License-Identifier: GPL-3.0-only

; Find the physical card. An SB16 wins over a WSS codec. A WSS codec wins
; over an older Sound Blaster. BLASTER supplies a value only when a test fails.

%define DET_BYTES 32
%define NOTE_BOARD 1
%define NOTE_IRQ_HINT 2
%define NOTE_IRQ_MISSING 4
%define NOTE_DMA_HINT 8
%define NOTE_DMA_MISSING 16
%define NOTE_UNUSABLE 32

detect_action:
    call resident_audio_present
    jnc .free
    mov word [status], resident_detect_message
    ret
.free:
    mov si, detect_wait_message
    call status_now
    call blaster_parse
    mov si, sound_card
    mov di, detect_saved
    mov cx, 6
    rep movsb
    mov byte [detect_notes], 0
    call detect_sb
    jc .wss
    cmp byte [dsp_major], 4
    jb .wss
    call detect_sb16
    jmp .report
.wss:
    call detect_wss
    jnc .report
    cmp word [dsp_port], 0
    je .none
    call detect_sb_legacy
.report:
    mov byte [changed], 1
    jmp detect_report
.none:
    mov si, detect_saved
    mov di, sound_card
    mov cx, 6
    rep movsb
    mov word [status], detect_none_message
    ret

; Find a DSP. Try the BLASTER port first.
detect_sb:
    mov word [dsp_port], 0
    mov ax, [hint_port]
    mov si, sb_port_values
    call value_listed
    jc .scan
    call .probe
    jnc .done
.scan:
    mov si, sb_port_values+1
    mov cx, 4
.port:
    lodsw
    call .probe
    jnc .done
    loop .port
    stc
.done:
    ret
.probe:
    push cx
    push si
    mov dx, ax
    call det_reset
    jc .absent
    mov al, 0e1h
    call det_write
    jc .absent
    call det_read
    jc .absent
    mov ah, al
    call det_read
    jc .absent
    mov [dsp_major], ah
    mov [dsp_port], dx
    mov [sb_base], dx
    clc
.absent:
    pop si
    pop cx
    ret

; The SB16 mixer shows the IRQ and DMA settings.
detect_sb16:
    mov byte [sound_card], 0
    mov dx, [sb_base]
    add dx, 4
    mov al, 80h
    out dx, al
    inc dx
    in al, dx
    mov ah, 5
    test al, 2
    jnz .irq
    mov ah, 7
    test al, 4
    jnz .irq
    or byte [detect_notes], NOTE_UNUSABLE
    jmp .dma
.irq:
    mov [sb_irq], ah
.dma:
    dec dx
    mov al, 81h
    out dx, al
    inc dx
    in al, dx
    mov ah, 1
    test al, 2
    jnz .low
    mov ah, 3
    test al, 8
    jnz .low
    or byte [detect_notes], NOTE_UNUSABLE
    jmp .high
.low:
    mov [sb_dma8], ah
.high:
    mov ah, 5
    test al, 20h
    jnz .high_found
    mov ah, 6
    test al, 40h
    jnz .high_found
    mov ah, 7
    test al, 80h
    jnz .high_found
    or byte [detect_notes], NOTE_UNUSABLE
    ret
.high_found:
    mov [sb_dma16], ah
    ret

; A DSP before version 4 needs an interrupt test and a DMA test.
detect_sb_legacy:
    mov dx, [dsp_port]
    mov [sb_base], dx
    mov byte [sound_card], 1
    cmp byte [dsp_major], 3
    je .model
    mov byte [sound_card], 3
.model:
    call det_hook
    mov ax, [sb_base]
    add ax, 0eh
    mov [det_ack], ax
    mov byte [det_wss], 0
    mov byte [det_hit], 0
    mov dx, [sb_base]
    mov al, 0f2h
    call det_write
    call det_wait
    mov al, [det_hit]
    test al, al
    jnz .irq
    call hint_irq_value
    jmp .dma
.irq:
    mov [sb_irq], al
.dma:
    mov al, 1
    call det_sb_dma
    jnc .dma_found
    mov al, 3
    call det_sb_dma
    jnc .dma_found
    call hint_dma_value
    jmp .done
.dma_found:
    mov [sb_dma8], al
.done:
    call det_unhook
    mov dx, [sb_base]
    jmp det_reset

hint_irq_value:
    movzx ax, byte [hint_irq]
    mov si, irq_values
    call value_listed
    jc .missing
    mov [sb_irq], al
    or byte [detect_notes], NOTE_IRQ_HINT
    ret
.missing:
    or byte [detect_notes], NOTE_IRQ_MISSING
    ret

hint_dma_value:
    movzx ax, byte [hint_dma8]
    mov si, dma8_values
    call value_listed
    jc .missing
    mov [sb_dma8], al
    or byte [detect_notes], NOTE_DMA_HINT
    ret
.missing:
    or byte [detect_notes], NOTE_DMA_MISSING
    ret

; AL channel. Return CF clear if a short 8-bit output used the channel.
det_sb_dma:
    push ax
    call det_dma_program
    mov dx, [sb_base]
    call det_reset
    mov al, 40h
    call det_write
    mov al, 0d3h
    call det_write
    mov al, 14h
    call det_write
    mov al, DET_BYTES-1
    call det_write
    xor al, al
    call det_write
    mov byte [det_hit], 0
    call det_wait
    pop ax
    jmp det_dma_done

; Find a WSS codec.
detect_wss:
    mov si, wss_port_values+1
    mov cx, 4
.port:
    lodsw
    push cx
    push si
    mov [sb_base], ax
    call wss_probe
    pop si
    pop cx
    jnc .found
    loop .port
    mov ax, [detect_saved+1]
    mov [sb_base], ax
    stc
    ret
.found:
    mov byte [sound_card], 2
    mov dx, [sb_base]
    add dx, 3
    in al, dx
    and al, 3fh
    cmp al, 4
    jne .codec
    ; The board register is write-only.
    or byte [detect_notes], NOTE_BOARD
    clc
    ret
.codec:
    call det_hook
    mov ax, [sb_base]
    add ax, 6
    mov [det_ack], ax
    mov byte [det_wss], 1
    mov al, 1
    call det_wss_dma
    jnc .dma
    mov al, 3
    call det_wss_dma
    jnc .dma
    or byte [detect_notes], NOTE_DMA_MISSING
    jmp .irq
.dma:
    mov [sb_dma8], al
.irq:
    mov al, [det_hit]
    test al, al
    jz .no_irq
    mov [sb_irq], al
    jmp .done
.no_irq:
    or byte [detect_notes], NOTE_IRQ_MISSING
.done:
    call det_unhook
    clc
    ret

; Return CF clear if a codec answers at sb_base+4.
wss_probe:
    mov dx, [sb_base]
    add dx, 4
    in al, dx
    cmp al, 0ffh
    je .absent
    call wss_ready
    jc .absent
    xor al, al
    call wss_read
    mov [det_saved], al
    mov ah, al
    and ah, 0f0h
    or ah, 0ah
    xor al, al
    call indexed_write
    xor al, al
    call wss_read
    and al, 0fh
    cmp al, 0ah
    jne .restore
    mov ah, [det_saved]
    and ah, 0f0h
    or ah, 5
    xor al, al
    call indexed_write
    xor al, al
    call wss_read
    and al, 0fh
    cmp al, 5
    jne .restore
    mov ah, [det_saved]
    xor al, al
    call indexed_write
    clc
    ret
.restore:
    mov ah, [det_saved]
    xor al, al
    call indexed_write
.absent:
    stc
    ret

; AL channel. Play a short 8 kHz block. Return CF clear if the codec used
; the channel.
det_wss_dma:
    push ax
    call det_dma_program
    mov ax, 0449h
    call indexed_write
    mov ax, 0048h
    call indexed_write
    mov dx, [sb_base]
    add dx, 4
    xor al, al
    out dx, al
    call wss_ready
    mov ax, 020ah
    call indexed_write
    mov ax, (DET_BYTES-1)*256+15
    call indexed_write
    mov ax, 000eh
    call indexed_write
    mov dx, [sb_base]
    add dx, 6
    xor al, al
    out dx, al
    mov byte [det_hit], 0
    mov ax, 0509h
    call indexed_write
    call det_wait
    mov ax, 0409h
    call indexed_write
    mov ax, 000ah
    call indexed_write
    mov dx, [sb_base]
    add dx, 6
    xor al, al
    out dx, al
    pop ax
    jmp det_dma_done

; DX base. Return CF set if no DSP answers.
det_reset:
    push cx
    push dx
    add dx, 6
    mov al, 1
    out dx, al
    mov cx, 16
.delay:
    in al, dx
    loop .delay
    xor al, al
    out dx, al
    add dx, 8
    mov cx, 2000h
.poll:
    in al, dx
    test al, 80h
    jz .again
    sub dx, 4
    in al, dx
    add dx, 4
    cmp al, 0aah
    je .found
.again:
    loop .poll
    pop dx
    pop cx
    stc
    ret
.found:
    pop dx
    pop cx
    clc
    ret

; DX base, AL value.
det_write:
    push cx
    push dx
    push ax
    add dx, 0ch
    mov cx, 0ffffh
.wait:
    in al, dx
    test al, 80h
    jz .ready
    loop .wait
    pop ax
    pop dx
    pop cx
    stc
    ret
.ready:
    pop ax
    out dx, al
    pop dx
    pop cx
    clc
    ret

; DX base. Return AL value.
det_read:
    push cx
    push dx
    add dx, 0eh
    mov cx, 0ffffh
.wait:
    in al, dx
    test al, 80h
    jnz .ready
    loop .wait
    pop dx
    pop cx
    stc
    ret
.ready:
    sub dx, 4
    in al, dx
    pop dx
    pop cx
    clc
    ret

; AL channel 1 or 3. Program a single memory-to-device transfer.
det_dma_program:
    push ax
    mov bl, al
    mov ax, cs
    movzx eax, ax
    shl eax, 4
    add eax, det_buffer
    mov cx, ax
    add cx, DET_BYTES
    jnc .fits
    add eax, DET_BYTES
.fits:
    mov [det_linear], eax
    mov al, bl
    or al, 4
    out 0ah, al
    out 0ch, al
    mov al, bl
    or al, 48h
    out 0bh, al
    movzx dx, bl
    shl dx, 1
    mov eax, [det_linear]
    out dx, al
    mov al, ah
    out dx, al
    shr eax, 16
    mov dx, 83h
    cmp bl, 1
    je .page
    mov dx, 82h
.page:
    out dx, al
    movzx dx, bl
    shl dx, 1
    inc dx
    mov al, DET_BYTES-1
    out dx, al
    xor al, al
    out dx, al
    mov al, bl
    out 0ah, al
    pop ax
    ret

; AL channel. Mask the channel. Return CF clear if the count finished.
det_dma_done:
    push ax
    mov bl, al
    out 0ch, al
    movzx dx, bl
    shl dx, 1
    inc dx
    in al, dx
    mov ah, al
    in al, dx
    xchg al, ah
    mov cx, ax
    mov al, bl
    or al, 4
    out 0ah, al
    pop ax
    cmp cx, 0ffffh
    je .done
    stc
.done:
    ret

det_hook:
    push es
    mov ax, 350dh
    int 21h
    mov [det_old5], bx
    mov [det_old5+2], es
    mov ax, 350fh
    int 21h
    mov [det_old7], bx
    mov [det_old7+2], es
    pop es
    mov dx, det_irq5
    mov ax, 250dh
    int 21h
    mov dx, det_irq7
    mov ax, 250fh
    int 21h
    cli
    in al, 21h
    mov [det_mask], al
    and al, 5fh
    out 21h, al
    sti
    ret

det_unhook:
    cli
    mov al, [det_mask]
    out 21h, al
    sti
    push ds
    lds dx, [det_old5]
    mov ax, 250dh
    int 21h
    pop ds
    push ds
    lds dx, [det_old7]
    mov ax, 250fh
    int 21h
    pop ds
    ret

; Wait up to three timer ticks for an interrupt.
det_wait:
    push es
    push bx
    mov ax, 40h
    mov es, ax
    mov bx, [es:6ch]
.loop:
    sti
    cmp byte [det_hit], 0
    jne .done
    mov ax, [es:6ch]
    sub ax, bx
    cmp ax, 3
    jb .loop
.done:
    pop bx
    pop es
    ret

det_irq5:
    push ax
    mov al, 5
    jmp det_irq
det_irq7:
    push ax
    mov al, 0bh
    out 20h, al
    in al, 20h
    test al, 80h
    jnz .real
    pop ax
    iret
.real:
    mov al, 7
det_irq:
    push dx
    mov [cs:det_hit], al
    mov dx, [cs:det_ack]
    cmp byte [cs:det_wss], 0
    jne .wss
    in al, dx
    jmp .eoi
.wss:
    xor al, al
    out dx, al
.eoi:
    mov al, 20h
    out 20h, al
    pop dx
    pop ax
    iret

; Put the detection result in the status line.
detect_report:
    mov di, status_buffer
    movzx bx, byte [sound_card]
    shl bx, 1
    mov si, [model_names+bx]
    call copy_text
    mov si, at_port_text
    call copy_text
    mov ax, [sb_base]
    call text_hex3
    mov si, found_end_text
    call copy_text
    mov si, note_texts
    mov al, [detect_notes]
    mov cx, 6
.note:
    shr al, 1
    jnc .next
    push si
    push ax
    mov si, [si]
    call copy_text
    pop ax
    pop si
.next:
    add si, 2
    loop .note
    mov word [status], status_buffer
    ret

note_texts dw board_note,irq_hint_note,irq_missing_note
    dw dma_hint_note,dma_missing_note,unusable_note
dsp_port dw 0
dsp_major db 0
detect_notes db 0
detect_saved times 6 db 0
det_saved db 0
det_hit db 0
det_wss db 0
det_mask db 0
det_ack dw 0
det_old5 dd 0
det_old7 dd 0
det_linear dd 0
det_buffer times DET_BYTES*2 db 80h
at_port_text db ' found at port ',0
found_end_text db 'h.',10,0
board_note db 'Detect cannot read the IRQ and DMA of this card. ',0
irq_hint_note db 'The IRQ is from BLASTER. ',0
irq_missing_note db 'IRQ not found. ',0
dma_hint_note db 'The DMA channel is from BLASTER. ',0
dma_missing_note db 'DMA channel not found. ',0
unusable_note db 'The card uses an IRQ or DMA channel that uCDD does not support. ',0
detect_wait_message db 'Detecting the sound card.',0
detect_none_message db 'No sound card found.',0
resident_detect_message db 'The uCDD audio driver uses the card. Start DOS without UCDD -install.',0
