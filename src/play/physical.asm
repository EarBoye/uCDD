; SPDX-FileCopyrightText: 2026 vorvek
; SPDX-License-Identifier: GPL-3.0-only

%define PHY_SECTORS 6
%define PHY_HALF (2352*PHY_SECTORS)
%define PHY_BYTES (PHY_HALF*2)

; EAX = first sector, EDX = end. All reads stay before the end.
physical_play:
    cmp edx, eax
    jbe .bad_range
    cmp edx, [leadout]
    ja .bad_range
    push eax
    push edx
    call physical_stop
    pop edx
    pop eax
    mov [phy_start], eax
    mov [phy_lba], eax
    mov [position], eax
    mov [range_end], edx
    sub edx, eax
    lea eax, [edx+PHY_SECTORS-1]
    xor edx, edx
    mov ecx, PHY_SECTORS
    div ecx
    mov [phy_limit], eax
    mov dword [phy_irqs], 0
    mov dword [phy_refills], 0
    mov dword [phy_processed], 0
    mov byte [phy_deemphasis_on], 0
    mov word [phy_offset], 0
    call physical_config
    jc .output
    cmp word [phy_allocation], 0
    jne .prime
    mov bx, (PHY_BYTES*2+15)/16
    mov ah, 48h
    int 21h
    jc .memory
    mov [phy_allocation], ax
    mov [phy_segment], ax
    movzx eax, ax
    shl eax, 4
    movzx edx, ax
    add edx, PHY_BYTES
    cmp edx, 10000h
    jbe .buffer
    add word [phy_segment], 0fffh
    and word [phy_segment], 0f000h
.buffer:
    cmp word [phy_segment], (0a0000h-PHY_BYTES)/16
    jbe .prime
    mov es, [phy_allocation]
    mov ah, 49h
    int 21h
    mov word [phy_allocation], 0
    jmp .memory
.prime:
    call physical_fill
    jc .read
    mov word [phy_offset], PHY_HALF
    call physical_fill
    jc .read
    call physical_start
    jc .output
    mov byte [play_state], PLAYING
    mov byte [replan], 0
    clc
    ret
.bad_range:
    mov si, message_play_error
    jmp .error
.output:
    mov si, message_physical_output
    jmp .error
.memory:
    mov si, message_physical_memory
    jmp .error
.read:
    mov si, message_physical_read
.error:
    push si
    call physical_stop
    pop si
    mov byte [play_state], STOPPED
    call show_message
    stc
    ret

physical_fill:
    mov es, [phy_segment]
    mov di, [phy_offset]
    mov cx, PHY_HALF/2
    xor ax, ax
    rep stosw
    mov eax, [range_end]
    sub eax, [phy_lba]
    jbe .done
    cmp eax, PHY_SECTORS
    jbe .count
    mov ax, PHY_SECTORS
.count:
    mov [phy_count], ax
    mov al, 80h
    mov cl, 26
    call new_request
    mov ax, [phy_offset]
    mov [request+14], ax
    mov ax, [phy_segment]
    mov [request+16], ax
    mov ax, [phy_count]
    mov [request+18], ax
    mov eax, [phy_lba]
    mov [request+20], eax
    mov byte [request+24], 1
    call send_request
    jc .bad
    mov ax, [phy_count]
    cmp [request+18], ax
    jne .bad
    call physical_deemphasis
    mov ax, [phy_count]
    movzx eax, ax
    add [phy_lba], eax
    imul ax, 2352
    mov cx, ax
    push gs
    mov gs, [phy_segment]
    mov bx, [phy_offset]
    mov edx, [phy_processed]
    push cs
    call eq_hook
    pop gs
    movzx eax, word [phy_count]
    imul eax, 2352
    add [phy_processed], eax
.done:
    clc
    ret
.bad:
    stc
    ret

physical_poll:
    mov eax, [phy_irqs]
    cmp eax, [phy_limit]
    jae .end
    sub eax, [phy_refills]
    cmp eax, 1
    ja .late
    jne .waiting
    push es
    mov ax, 40h
    mov es, ax
    mov eax, [es:6ch]
    pop es
    mov [phy_tick], eax
    mov eax, [phy_refills]
    and ax, 1
    imul ax, PHY_HALF
    mov [phy_offset], ax
    mov eax, [phy_irqs]
    mov [phy_before], eax
    call physical_fill
    jc physical_play.read
    mov eax, [phy_before]
    cmp eax, [phy_irqs]
    jne .late
    inc dword [phy_refills]
.position:
    jmp physical_position
.waiting:
    push es
    mov ax, 40h
    mov es, ax
    mov eax, [es:6ch]
    pop es
    sub eax, [phy_tick]
    jnc .elapsed
    add eax, 1800b0h
.elapsed:
    cmp eax, 19
    jb .position
    mov si, message_physical_stalled
    jmp physical_play.error
.end:
    call physical_position
    call physical_stop
    jmp play_end
.late:
    mov si, message_physical_slow
    jmp physical_play.error

physical_position:
    xor esi, esi
    mov ecx, [phy_irqs]
    cmp byte [phy_running], 0
    je .whole
    pushf
    cli
    mov ecx, [phy_irqs]
    mov dx, 0d8h
    xor al, al
    out dx, al
    mov dx, [phy_address_port]
    add dx, 2
    in al, dx
    mov bl, al
    in al, dx
    mov bh, al
    popf
    movzx ebx, bx
    inc ebx
    mov eax, PHY_HALF
    sub eax, ebx
    jc .whole
    xor edx, edx
    mov ebx, PHY_HALF/2
    div ebx
    xor eax, ecx
    test al, 1
    jnz .whole
    mov eax, edx
    xor edx, edx
    mov ebx, 2352/2
    div ebx
    mov esi, eax
.whole:
    mov eax, ecx
    imul eax, PHY_SECTORS
    add eax, esi
    add eax, [phy_start]
    cmp eax, [range_end]
    jb .track
    mov eax, [range_end]
    dec eax
.track:
    mov [position], eax
    movzx bx, byte [first_track]
.next:
    cmp bl, [last_track]
    jae .found
    mov si, bx
    inc si
    shl si, 2
    cmp eax, [track_start+si]
    jb .found
    inc bx
    jmp .next
.found:
    mov [track], bl
    shl bx, 2
    sub eax, [track_start+bx]
    mov [relative], eax
    ret

physical_changed:
    mov al, 9
    mov cx, 2
    call ioctl_input
    jc .empty
    cmp byte [control_block+1], 0ffh
    je .changed
    cmp byte [control_block+1], 0
    je .toc
    cmp byte [disc_present], 0
    jne .same
.toc:
    mov al, 10
    mov cx, 7
    call ioctl_input
    jc .empty
    cmp byte [disc_present], 0
    je .changed
    mov al, [control_block+1]
    cmp al, [first_track]
    jne .changed
    mov al, [control_block+2]
    cmp al, [last_track]
    jne .changed
    mov si, control_block+3
    call redbook_sector
    cmp eax, [leadout]
    je .same
.changed:
    stc
    ret
.empty:
    cmp byte [disc_present], 0
    jne .changed
.same:
    clc
    ret

; Get the virtual base from BLASTER, and IRQ/DMA from the SB16 mixer.
physical_config:
    mov dx, audio_report
    mov ax, 6
    call audio_control
    test ax, ax
    jnz .bad
    mov es, [psp_seg]
    mov es, [es:2ch]
    xor di, di
.env:
    cmp di, 7f00h
    ja .bad
    cmp byte [es:di], 0
    je .bad
    cmp dword [es:di], 'BLAS'
    jne .skip
    cmp dword [es:di+4], 'TER='
    je .value
.skip:
    cmp byte [es:di], 0
    je .next_env
    inc di
    cmp di, 7f00h
    jb .skip
    jmp .bad
.next_env:
    inc di
    jmp .env
.value:
    add di, 8
.token:
    mov al, [es:di]
    test al, al
    jz .bad
    inc di
    cmp di, 7f00h
    ja .bad
    and al, 0dfh
    cmp al, 'A'
    jne .token
    xor bx, bx
    mov cx, 3
.hex:
    mov al, [es:di]
    inc di
    sub al, '0'
    cmp al, 9
    ja .bad
    shl bx, 4
    movzx ax, al
    add bx, ax
    loop .hex
    cmp bx, 220h
    jb .bad
    cmp bx, 280h
    ja .bad
    test bl, 1fh
    jnz .bad
    mov al, [es:di]
    test al, al
    jz .base
    cmp al, ' '
    jne .bad
.base:
    mov [phy_base], bx
    lea dx, [bx+6]
    mov al, 1
    out dx, al
    mov cx, 64
.delay:
    in al, dx
    loop .delay
    xor al, al
    out dx, al
    call physical_reply
    jc .bad
    cmp al, 0aah
    jne .bad
    mov al, 0e1h
    call physical_dsp
    jc .bad
    call physical_reply
    jc .bad
    cmp al, 4
    jne .bad
    call physical_reply
    jc .bad
    mov al, 80h
    call physical_mixer_read
    mov byte [phy_irq], 5
    cmp al, 2
    je .irq
    cmp al, 4
    jne .bad
    mov byte [phy_irq], 7
.irq:
    mov al, 81h
    call physical_mixer_read
    and al, 0e0h
    mov byte [phy_dma], 5
    cmp al, 20h
    je .dma
    mov byte [phy_dma], 6
    cmp al, 40h
    je .dma
    mov byte [phy_dma], 7
    cmp al, 80h
    jne .bad
.dma:
    movzx bx, byte [phy_dma]
    sub bx, 5
    mov al, [phy_pages+bx]
    mov [phy_page_port], al
    shl bx, 2
    add bx, 0c4h
    mov [phy_address_port], bx
    clc
    ret
.bad:
    stc
    ret

physical_reply:
    push cx
    mov dx, [phy_base]
    add dx, 0eh
    mov cx, 65535
.wait:
    in al, dx
    test al, 80h
    jnz .read
    loop .wait
    pop cx
    stc
    ret
.read:
    sub dx, 4
    in al, dx
    pop cx
    clc
    ret

physical_dsp:
    push ax
    push cx
    mov dx, [phy_base]
    add dx, 0ch
    mov cx, 65535
.wait:
    in al, dx
    test al, 80h
    jz .write
    loop .wait
    pop cx
    pop ax
    stc
    ret
.write:
    pop cx
    pop ax
    out dx, al
    clc
    ret

physical_mixer_read:
    mov dx, [phy_base]
    add dx, 4
    out dx, al
    inc dx
    in al, dx
    ret

; AL = mixer register, AH = value.
physical_mixer_write:
    mov dx, [phy_base]
    add dx, 4
    out dx, al
    inc dx
    mov al, ah
    out dx, al
    ret

physical_volume:
    cmp byte [phy_running], 0
    je .done
    mov ah, [volume]
    mov al, 32h
    call physical_mixer_write
    mov ah, [volume]
    mov al, 33h
    call physical_mixer_write
.done:
    ret

physical_start:
    mov ax, 40h
    mov es, ax
    mov eax, [es:6ch]
    mov [phy_tick], eax
    mov al, [phy_irq]
    add al, 8
    mov ah, 35h
    int 21h
    mov [phy_old_irq], bx
    mov [phy_old_irq+2], es
    mov al, [phy_irq]
    add al, 8
    mov ah, 25h
    mov dx, physical_irq
    int 21h
    in al, 21h
    mov [phy_old_pic], al
    mov cl, [phy_irq]
    mov ah, 1
    shl ah, cl
    not ah
    and al, ah
    out 21h, al
    mov al, 32h
    call physical_mixer_read
    mov [phy_old_volume], al
    mov al, 33h
    call physical_mixer_read
    mov [phy_old_volume+1], al
    mov byte [phy_running], 1
    call physical_volume
    pushf
    cli
    mov dx, 0d4h
    mov al, [phy_dma]
    out dx, al
    mov dx, 0d8h
    xor al, al
    out dx, al
    movzx eax, word [phy_segment]
    shl eax, 4
    mov ebx, eax
    shr eax, 1
    mov dx, [phy_address_port]
    out dx, al
    mov al, ah
    out dx, al
    shr ebx, 16
    mov al, bl
    movzx dx, byte [phy_page_port]
    out dx, al
    mov dx, [phy_address_port]
    add dx, 2
    mov ax, PHY_HALF-1
    out dx, al
    mov al, ah
    out dx, al
    mov dx, 0d6h
    mov al, [phy_dma]
    sub al, 4
    or al, 58h
    out dx, al
    mov dx, 0d4h
    mov al, [phy_dma]
    sub al, 4
    out dx, al
    popf
    mov si, phy_commands
.command:
    lodsb
    call physical_dsp
    jc .fail
    cmp si, phy_commands_end
    jb .command
    clc
    ret
.fail:
    stc
    ret

physical_stop:
    cmp byte [phy_running], 0
    je .done
    mov al, 0d5h
    call physical_dsp
    mov dx, 0d4h
    mov al, [phy_dma]
    out dx, al
    mov dx, [phy_base]
    add dx, 0fh
    in al, dx
    mov al, [phy_old_pic]
    out 21h, al
    mov ah, [phy_old_volume]
    mov al, 32h
    call physical_mixer_write
    mov ah, [phy_old_volume+1]
    mov al, 33h
    call physical_mixer_write
    push ds
    mov al, [phy_irq]
    add al, 8
    mov ah, 25h
    lds dx, [phy_old_irq]
    int 21h
    pop ds
    mov byte [phy_running], 0
.done:
    ret

physical_irq:
    push ax
    push dx
    mov dx, [cs:phy_base]
    add dx, 0fh
    in al, dx
    inc dword [cs:phy_irqs]
    mov al, [cs:phy_irq]
    or al, 60h
    out 20h, al
    pop dx
    pop ax
    iret

physical_deemphasis:
    mov eax, [phy_lba]
    mov cx, [phy_count]
    mov bx, [phy_offset]
    shr bx, 4
    add bx, [phy_segment]
    mov es, bx
.sector:
    movzx bx, byte [first_track]
.track:
    cmp bl, [last_track]
    jae .filter
    mov si, bx
    inc si
    shl si, 2
    cmp eax, [track_start+si]
    jb .filter
    inc bx
    jmp .track
.filter:
    mov dl, [track_pre+bx]
    mov [phy_pre], dl
    call phy_deemphasis
    mov bx, es
    add bx, 2352/16
    mov es, bx
    inc eax
    loop .sector
    ret

%define cd_deemphasis phy_deemphasis
%define cd_deemphasis_on phy_deemphasis_on
%define cd_deemphasis_state phy_deemphasis_state
%define cd_pre phy_pre
%define cd_silence phy_silence
%define cd_read_size phy_sector_bytes
%define cd_stage 0
%include "audio/deemphasis.asm"
%undef cd_deemphasis
%undef cd_deemphasis_on
%undef cd_deemphasis_state
%undef cd_pre
%undef cd_silence
%undef cd_read_size
%undef cd_stage

phy_commands db 0d1h,41h,0ach,44h,0b6h,30h
    dw PHY_HALF/2-1
phy_commands_end:
phy_pages db 8bh,89h,8ah
phy_base dw 0
phy_dma db 0
phy_irq db 0
phy_page_port db 0
phy_address_port dw 0
phy_allocation dw 0
phy_segment dw 0
phy_offset dw 0
phy_count dw 0
phy_start dd 0
phy_lba dd 0
phy_limit dd 0
phy_irqs dd 0
phy_refills dd 0
phy_before dd 0
phy_processed dd 0
phy_old_irq dd 0
phy_old_pic db 0
phy_old_volume dw 0
phy_running db 0
phy_tick dd 0
phy_pre db 0
phy_silence db 0
phy_sector_bytes dw 2352
