; SPDX-FileCopyrightText: 2026 vorvek
; SPDX-License-Identifier: GPL-3.0-only

; The CUE sheet parser uses these. They work as in helper.asm, but a quote
; without an end gives CF instead of the usage text.

; DS:SI = text. Return BX = next token with a 0 end, or CF at the end.
token:
.space:
    mov al, [si]
    cmp al, ' '
    je .skip
    cmp al, 9
    jne .start
.skip:
    inc si
    jmp .space
.start:
    test al, al
    jz .end
    cmp al, '"'
    jne .plain
    inc si
    mov bx, si
.quoted:
    mov al, [si]
    test al, al
    jz .end
    inc si
    cmp al, '"'
    jne .quoted
    mov byte [si-1], 0
    cmp byte [si], 0
    je .ready
    cmp byte [si], ' '
    je .ready
    cmp byte [si], 9
    jne .end
    jmp .ready
.plain:
    mov bx, si
.scan:
    mov al, [si]
    test al, al
    jz .ready
    cmp al, ' '
    je .terminate
    cmp al, 9
    je .terminate
    inc si
    jmp .scan
.terminate:
    mov byte [si], 0
    inc si
.ready:
    clc
    ret
.end:
    stc
    ret

; DS:BX = text, DS:DI = uppercase word. ZF when equal.
option_equal:
    push bx
    push di
.next:
    mov al, [bx]
    cmp al, 'a'
    jb .compare
    cmp al, 'z'
    ja .compare
    sub al, 32
.compare:
    cmp al, [di]
    jne .done
    test al, al
    jz .done
    inc bx
    inc di
    jmp .next
.done:
    pop di
    pop bx
    ret
