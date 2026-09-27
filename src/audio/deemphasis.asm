; SPDX-FileCopyrightText: 2026 vorvek
; SPDX-License-Identifier: GPL-3.0-only

; 50/15 us CD de-emphasis at 44100 Hz, before queueing and resampling.
; Q14 coefficients, unity DC gain, less than 0.02 dB error at 20 Hz to 20 kHz.
cd_deemphasis:
    cmp byte [cd_pre], 0
    je .off
    cmp byte [cd_silence], 0
    jne .off
    pushad
    cmp byte [cd_deemphasis_on], 0
    jne .ready
    xor eax, eax
    mov [cd_deemphasis_state], eax
    mov [cd_deemphasis_state+4], eax
    mov [cd_deemphasis_state+8], eax
    mov [cd_deemphasis_state+12], eax
    mov [cd_deemphasis_state+16], eax
    mov [cd_deemphasis_state+20], eax
    mov byte [cd_deemphasis_on], 1
.ready:
    mov si, cd_stage
    mov bp, [cd_read_size]
    shr bp, 1
    xor bx, bx
.sample:
    movsx eax, word [es:si]
    imul eax, 7543
    movsx edx, word [cd_deemphasis_state+bx]
    imul edx, 1312
    add eax, edx
    movsx edx, word [cd_deemphasis_state+bx+2]
    imul edx, -643
    add eax, edx
    movsx edx, word [cd_deemphasis_state+bx+4]
    imul edx, 4281
    add eax, edx
    movsx edx, word [cd_deemphasis_state+bx+6]
    imul edx, 3891
    add eax, edx
    add eax, [cd_deemphasis_state+bx+8]
    mov ecx, eax
    add eax, 8192
    sar eax, 14
    mov dx, [cd_deemphasis_state+bx]
    mov [cd_deemphasis_state+bx+2], dx
    mov dx, [es:si]
    mov [cd_deemphasis_state+bx], dx
    mov dx, [cd_deemphasis_state+bx+4]
    mov [cd_deemphasis_state+bx+6], dx
    mov [cd_deemphasis_state+bx+4], ax
    mov [es:si], ax
    shl eax, 14
    sub ecx, eax
    mov [cd_deemphasis_state+bx+8], ecx
    add si, 2
    xor bx, 12
    dec bp
    jnz .sample
    popad
    ret
.off:
    mov byte [cd_deemphasis_on], 0
    ret

cd_deemphasis_on db 0
; Each channel: x[n-1], x[n-2], y[n-1], y[n-2], Q14 rounding remainder.
cd_deemphasis_state times 24 db 0
