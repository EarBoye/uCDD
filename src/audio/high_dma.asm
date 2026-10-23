; SPDX-FileCopyrightText: 2026 vorvek
; SPDX-License-Identifier: GPL-3.0-only

%include "audio/diag.inc"
; SI: source offset of a high source. Points FS:SI at a copy of its 256-byte page and the next
; 8 bytes, so a frame can cross the page end. Jemm maps the physical source for
; INT 15h/87h.
sb_high_map:
    pushf
    pushad
    push ds
    push es
    push gs
    movzx edi, si
    add edi, [game_physical]
    mov ebx, edi
    xor bl, bl
    cmp ebx, [sb_high_tag]
    je .cached
    mov [sb_high_source], bx
    mov eax, ebx
    shr eax, 16
    mov [sb_high_source+2], al
    movzx eax, word [cd_half_segment]
    add eax, (CD_HALF_BYTES+15)/16
    mov [sb_high_segment], ax
    shl eax, 4
    mov [sb_high_destination], ax
    shr eax, 16
    mov [sb_high_destination+2], al
    push ds
    pop es
    mov si, sb_high_table
    mov cx, 132
    mov ax, 8700h
    push ebx
    int 15h
    push cs
    pop ds
    pop ebx
    jc .failed
    mov [sb_high_tag], ebx
    jmp .cached
.failed:
    FAULT_SET 2, 3
    mov byte [game_active], 0
.cached:
    pop gs
    pop es
    pop ds
    popad
    popf
    mov fs, [sb_high_segment]
    add si, [game_physical]
    and si, 255
    ret

sb_high_tag dd -1
sb_high_segment dw 0
sb_high_table:
    times 16 db 0
    dw 0ffffh
sb_high_source:
    dw 0
    db 0,93h,0,0
    dw 0ffffh
sb_high_destination:
    dw 0
    db 0,93h,0,0
    times 16 db 0
