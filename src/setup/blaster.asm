; SPDX-FileCopyrightText: 2026 vorvek
; SPDX-License-Identifier: GPL-3.0-only

%define BLASTER_MAX 96

; Read BLASTER from the UCDDSET environment. The values are hints for card
; detection. A missing field stays 0.
blaster_parse:
    push es
    xor ax, ax
    mov [hint_port], ax
    mov [hint_irq], ax
    mov [hint_dma16], al
    mov es, [psp]
    mov ax, [es:2ch]
    test ax, ax
    jz .done
    mov es, ax
    xor si, si
.variable:
    cmp si, 7f00h
    jae .done
    cmp byte [es:si], 0
    je .done
    cmp dword [es:si], 'BLAS'
    jne .skip
    cmp dword [es:si+4], 'TER='
    je .found
.skip:
    inc si
    cmp byte [es:si-1], 0
    jne .skip
    jmp .variable
.found:
    add si, 8
.token:
    mov dl, [es:si]
    inc si
    test dl, dl
    jz .done
    cmp dl, ' '
    je .token
    and dl, 0dfh
    mov bx, 10
    cmp dl, 'A'
    jne .number
    mov bx, 16
.number:
    xor ax, ax
.digit:
    movzx cx, byte [es:si]
    cmp cl, ' '
    je .value
    test cl, cl
    jz .value
    sub cl, '0'
    cmp cl, 9
    jbe .valid_digit
    and cl, 0dfh
    sub cl, 7
.valid_digit:
    cmp cx, bx
    jae .done
    imul ax, bx
    add ax, cx
    inc si
    jmp .digit
.value:
    mov di, hint_port
    cmp dl, 'A'
    je .word
    mov di, hint_irq
    cmp dl, 'I'
    je .byte
    mov di, hint_dma8
    cmp dl, 'D'
    je .byte
    mov di, hint_dma16
    cmp dl, 'H'
    jne .token
.byte:
    mov [di], al
    jmp .token
.word:
    mov [di], ax
    jmp .token
.done:
    pop es
    ret

; DI output, with ES equal to DS. Write the value for the virtual card. FS:SI
; is an old value or SI is 0. Keep the old fields other than A, I, D, H, and T.
blaster_build:
    mov al, 'A'
    stosb
    mov ax, [virtual_base]
    call text_hex3
    mov ax, ' I'
    stosw
    mov al, [virtual_irq]
    add al, '0'
    stosb
    mov ax, ' D'
    stosw
    mov al, [virtual_dma8]
    add al, '0'
    stosb
    cmp byte [virtual_model], 0
    jne .fields
    mov ax, ' H'
    stosw
    mov al, [virtual_dma16]
    add al, '0'
    stosb
.fields:
    test si, si
    jz .type
.field:
    mov al, [fs:si]
    test al, al
    jz .type
    cmp al, ' '
    jne .start
    inc si
    jmp .field
.start:
    and al, 0dfh
    mov ah, 1
    cmp al, 'A'
    je .copy
    cmp al, 'I'
    je .copy
    cmp al, 'D'
    je .copy
    cmp al, 'H'
    je .copy
    cmp al, 'T'
    je .copy
    xor ah, ah
    cmp di, blaster_value+BLASTER_MAX-12
    jae .skip_field
    mov al, ' '
    stosb
.copy:
    mov al, [fs:si]
    test al, al
    jz .type
    cmp al, ' '
    je .field
    inc si
    test ah, ah
    jnz .copy
    stosb
    jmp .copy
.skip_field:
    mov ah, 1
    jmp .copy
.type:
    mov ax, ' T'
    stosw
    movzx bx, byte [virtual_model]
    movzx ax, byte [blaster_types+bx]
    stosw
    dec di
    ret

; BLASTER T by model: SB16 6, SB Pro 2 4, unused, SB 2.0 3.
blaster_types db '64 3'

; Set BLASTER in the environment of the program that started UCDD. Return
; CF set if that environment cannot be changed.
blaster_update:
    push es
    mov es, [psp]
    mov ax, [es:16h]
    mov es, ax
    mov bx, [es:16h]
    test bx, bx
    jz .fail
    cmp bx, ax
    je .fail
    mov es, bx
    mov ax, [es:2ch]
    test ax, ax
    jnz .block
    ; Some shells keep the environment in the block after their PSP.
    lea ax, [bx-1]
    mov es, ax
    add ax, [es:3]
    inc ax
    mov es, ax
    cmp [es:1], bx
    jne .fail
    inc ax
.block:
    mov [env_segment], ax
    dec ax
    mov es, ax
    cmp byte [es:0], 'M'
    je .size
    cmp byte [es:0], 'Z'
    jne .fail
.size:
    mov ax, [es:3]
    cmp ax, 1000h
    jae .fail
    shl ax, 4
    mov [env_size], ax
    mov es, [env_segment]
    xor di, di
    mov word [env_entry], 0ffffh
.entry:
    cmp di, [env_size]
    jae .fail
    cmp byte [es:di], 0
    je .end
    push di
    mov si, blaster_name
    mov cx, 8
    repe cmpsb
    pop di
    jne .next
    mov [env_entry], di
.next:
    mov cx, [env_size]
    sub cx, di
    xor al, al
    repne scasb
    jne .fail
    jmp .entry
.end:
    mov [env_end], di
    xor si, si
    cmp word [env_entry], 0ffffh
    je .build
    mov si, [env_entry]
    add si, 8
.build:
    mov fs, [env_segment]
    push ds
    pop es
    mov di, blaster_value
    call blaster_build
    mov es, [env_segment]
    sub di, blaster_value
    mov [blaster_length], di
    xor ax, ax
    cmp word [env_entry], 0ffffh
    je .space
    mov di, [env_entry]
    mov cx, [env_end]
    sub cx, di
    xor al, al
    repne scasb
    mov ax, di
    sub ax, [env_entry]
.space:
    ; AX old entry size. The new entry needs the name, the value, and NUL.
    mov [env_old], ax
    mov cx, [env_end]
    sub cx, ax
    add cx, [blaster_length]
    add cx, 10
    cmp cx, [env_size]
    ja .fail
    cmp word [env_entry], 0ffffh
    je .append
    push ds
    mov di, [env_entry]
    mov si, di
    add si, [env_old]
    mov cx, [env_end]
    sub cx, si
    push es
    pop ds
    rep movsb
    pop ds
    mov [env_end], di
.append:
    mov di, [env_end]
    mov si, blaster_name
    mov cx, 8
    rep movsb
    mov si, blaster_value
    mov cx, [blaster_length]
    rep movsb
    xor ax, ax
    stosw
    pop es
    clc
    ret
.fail:
    pop es
    stc
    ret

hint_port dw 0
hint_irq db 0
hint_dma8 db 0
hint_dma16 db 0
env_segment dw 0
env_size dw 0
env_entry dw 0
env_end dw 0
env_old dw 0
blaster_length dw 0
blaster_name db 'BLASTER='
blaster_value times BLASTER_MAX db 0
