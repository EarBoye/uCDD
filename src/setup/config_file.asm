; SPDX-FileCopyrightText: 2026 vorvek
; SPDX-License-Identifier: GPL-3.0-only

LOAD_OK equ 0
LOAD_MISSING equ 1
LOAD_OLD equ 2
LOAD_INVALID equ 3
LOAD_UNREADABLE equ 4
; The author's version 4 record (0.9.4-a1 to a6).
AUTHOR_V4_SIZE equ 42

; Return AL: LOAD_OK, LOAD_MISSING, LOAD_OLD, LOAD_INVALID, or LOAD_UNREADABLE.
; Every result except LOAD_OK leaves settings that the user must examine.
config_load:
    mov dx, config_path
    mov ax, 3d00h
    int 21h
    jnc .read
    cmp ax, 2
    je .missing
    cmp ax, 3
    je .missing
    jmp .unreadable
.read:
    mov bx, ax
    mov dx, file_buffer
    mov cx, CONFIG_SIZE+1
    mov ah, 3fh
    int 21h
    pushf
    push ax
    mov ah, 3eh
    int 21h
    pop ax
    popf
    jc .unreadable
    cmp dword [file_buffer], 'uCDD'
    jne .invalid
    cmp ax, 12
    je .old
    cmp ax, CONFIG_SIZE
    je .size_ok
    ; Older files, told apart by their size: version 2 at 36 bytes (the
    ; author's 0.9.3b), the fork's versions 3 and 4 at 37 and 38 (its bytes
    ; in the old pad byte and after it), the author's version 4 at 42 (eleven
    ; keys and the FM level). Each is brought to version 5: the author's
    ; version 4 record, then the fork's three bytes.
    cmp ax, AUTHOR_V4_SIZE
    je .author_v4
    cmp ax, 36
    jb .invalid
    cmp ax, 38
    ja .invalid
    mov bl, al
    sub bl, 34
    cmp [file_buffer+4], bl
    jne .invalid
    ; The fork's bytes from offset 35 (a version 2 file's pad byte, 0), the
    ; missing ones as 0, kept aside while the author's conversion moves the
    ; record.
    push ds
    pop es
    mov di, file_buffer
    add di, ax
    mov cx, 38
    sub cx, ax
    xor al, al
    cld
    rep stosb
    mov ax, [file_buffer+35]
    mov dl, [file_buffer+37]
    push ax
    push dx
    call .five_keys
    pop dx
    pop ax
    mov [file_buffer+AUTHOR_V4_SIZE], ax
    mov [file_buffer+AUTHOR_V4_SIZE+2], dl
    jmp .version_set
.author_v4:
    cmp byte [file_buffer+4], 4
    jne .invalid
    mov word [file_buffer+AUTHOR_V4_SIZE], 0
    mov byte [file_buffer+AUTHOR_V4_SIZE+2], 0
.version_set:
    mov byte [file_buffer+4], CONFIG_VERSION
    jmp .copy
.size_ok:
    cmp byte [file_buffer+4], CONFIG_VERSION
    jne .invalid
.copy:
    mov si, file_buffer
    mov di, config_data
    mov cx, CONFIG_SIZE
    rep movsb
    mov byte [config_ready], 0
    call config_valid
    jc .invalid
    mov al, LOAD_OK
    ret
.old:
    cmp byte [file_buffer+4], 1
    jne .invalid
    cmp byte [file_buffer+11], 0
    jne .invalid
    call config_defaults
    mov si, file_buffer+5
    mov di, sound_card
    mov cx, 6
    rep movsb
    call physical_valid
    jc .invalid
    mov al, LOAD_OLD
    ret
.missing:
    call config_defaults
    mov al, LOAD_MISSING
    ret
.invalid:
    call config_defaults
    mov al, LOAD_INVALID
    ret
.unreadable:
    call config_defaults
    mov al, LOAD_UNREADABLE
    ret
.five_keys:
    ; A record of five keys and no FM level (version 2, and the fork's 3 and
    ; 4 before the merge) in the author's version 4 layout. The volume keys
    ; take the current defaults. The other settings stay.
    mov byte [file_buffer+35], 100
    std
    mov si, file_buffer+35
    mov di, file_buffer+AUTHOR_V4_SIZE-1
    mov cx, 12
    rep movsb
    cld
    mov si, config_default+22
    mov di, file_buffer+22
    mov cx, 8
    rep movsb
    ; A kept key that equals a default volume key turns that volume key off.
    mov di, file_buffer+22
.conflict:
    mov al, [di]
    cmp al, [file_buffer+19]
    je .off
    cmp al, [file_buffer+20]
    je .off
    cmp al, [file_buffer+21]
    jne .kept
.off:
    mov byte [di], 0
.kept:
    inc di
    cmp di, file_buffer+30
    jb .conflict
    ret

config_defaults:
    mov si, config_default
    mov di, config_data
    mov cx, CONFIG_SIZE
    rep movsb
    ret

; Return CF set if a setting is not valid.
config_valid:
    call physical_valid
    jc .done
    mov ax, [virtual_base]
    mov si, sb_port_values
    call value_listed
    jc .done
    movzx ax, byte [virtual_irq]
    mov si, irq_values
    call value_listed
    jc .done
    movzx ax, byte [virtual_dma8]
    mov si, dma8_values
    call value_listed
    jc .done
    movzx ax, byte [virtual_dma16]
    mov si, dma16_values
    call value_listed
    jc .done
    movzx ax, byte [virtual_model]
    call virtual_model_list
    call value_listed
    jc .done
    mov ax, [virtual_wss_base]
    mov si, wss_port_values
    call value_listed
    jc .done
    movzx ax, byte [virtual_wss_irq]
    mov si, wss_irq_values
    call value_listed
    jc .done
    call hotkeys_valid
    jc .done
    movzx ax, byte [config_disk_irq]
    mov si, disk_irq_values
    call value_listed
    jc .done
    cmp byte [config_cd_volume], 100
    ja .bad
    cmp byte [config_game_volume], 100
    ja .bad
    cmp byte [config_master_volume], 100
    ja .bad
    cmp byte [config_audio_always], 1
    ja .bad
    cmp byte [config_fast_dma], 1
    ja .bad
    cmp byte [config_fm_volume], 100
    ja .bad
    movzx ax, byte [config_volume_step]
    mov si, step_values
    call value_listed
.done:
    ret
.bad:
    stc
    ret

; Check the physical card. A card without a high DMA channel keeps H5.
physical_valid:
    cmp byte [sound_card], 5
    ja .bad
    cmp byte [sound_card], 0
    je .port
    movzx ax, byte [sb_dma16]
    mov si, dma16_values
    call value_listed
    jnc .port
    mov byte [sb_dma16], 5
.port:
    call port_list
    mov ax, [sb_base]
    call value_listed
    jc .done
    movzx ax, byte [sb_irq]
    mov si, irq_values
    call value_listed
    jc .done
    movzx ax, byte [sb_dma8]
    mov si, dma8_values
    call value_listed
    jc .done
    movzx ax, byte [sb_dma16]
    mov si, dma16_values
    call value_listed
.done:
    ret
.bad:
    stc
    ret

; AX value, SI list. Return CF set if the list does not include the value.
value_listed:
    push cx
    push si
    movzx cx, byte [si]
    inc si
    jcxz .missing
.value:
    cmp [si], ax
    je .found
    add si, 2
    loop .value
.missing:
    stc
    jmp .done
.found:
    clc
.done:
    pop si
    pop cx
    ret

; Set the physical mixer value for the selected card.
config_derive:
    movzx ax, byte [config_master_volume]
    mov bl, [sound_card]
    ; The ESS mixer keeps the Sound Blaster Pro master register.
    cmp bl, 4
    jb .model
    mov bl, 1
.model:
    cmp bl, 3
    jae .none
    cmp bl, 2
    je .wss
    mov cx, 31
    cmp bl, 1
    jne .scale
    mov cx, 15
.scale:
    push cx
    mul cx
    add ax, 50
    mov cl, 100
    div cl
    pop cx
    cmp cx, 15
    je .pro
    shl al, 3
    jmp .store
.pro:
    mov ah, 11h
    mul ah
    jmp .store
.wss:
    test ax, ax
    jz .mute
    mov cx, 63
    mul cx
    add ax, 50
    mov cl, 100
    div cl
    mov ah, al
    mov al, 63
    sub al, ah
    jmp .store
.mute:
    mov al, 80h
    jmp .store
.none:
    xor al, al
.store:
    mov [master_register], al
    movzx bx, byte [virtual_model]
    shl bx, 1
    mov ax, [dsp_versions+bx]
    mov [virtual_dsp_version], ax
    ret

; DSP version replies by model: 4.13, 3.02, unused, 2.01, ESS 3.01.
dsp_versions dw 0d04h,0203h,0,0102h,0103h

; Write UCDD.CF$, then replace UCDD.CFG with it. A failed write keeps the
; old file. status_buffer holds the temporary path.
config_save:
    call config_derive
    mov byte [config_ready], 0
    mov si, config_path
    mov di, status_buffer
    call copy_text
    mov byte [di-1], '$'
    mov dx, status_buffer
    xor cx, cx
    mov ah, 3ch
    int 21h
    jc .done
    mov bx, ax
    mov dx, config_data
    mov cx, CONFIG_SIZE
    mov ah, 40h
    int 21h
    pushf
    push ax
    mov ah, 3eh
    int 21h
    pop dx
    pop cx
    jc .remove
    test cl, 1
    jnz .remove
    cmp dx, CONFIG_SIZE
    jne .remove
    mov dx, config_path
    mov ah, 41h
    int 21h
    mov dx, status_buffer
    mov di, config_path
    mov ah, 56h
    int 21h
    ret
.remove:
    mov dx, status_buffer
    mov ah, 41h
    int 21h
    stc
.done:
    ret

; Return SI port list for the physical card.
port_list:
    mov si, sb_port_values
    cmp byte [sound_card], 2
    jne .done
    mov si, wss_port_values
.done:
    ret

sb_port_values db 4
    dw 220h,240h,260h,280h
wss_port_values db 4
    dw 530h,604h,0e80h,0f40h
irq_values db 2
    dw 5,7
wss_irq_values db 4
    dw 7,9,10,11
dma8_values db 2
    dw 1,3
dma16_values db 3
    dw 5,6,7
config_default times CONFIG_SIZE db 0
file_buffer times CONFIG_SIZE+1 db 0
