; SPDX-FileCopyrightText: 2026 vorvek
; SPDX-License-Identifier: GPL-3.0-only

; Spectrum bars and VU levels from the sample ring.

init_bitreverse:
    push es
    mov es, [work_seg]
    xor bx, bx
.entry:
    mov ax, bx
    xor dx, dx
    mov cx, 10
.bit:
    shr ax, 1
    rcl dx, 1
    loop .bit
    shl dx, 2
    mov si, bx
    add si, si
    mov [es:W_BITREV+si], dx
    inc bx
    cmp bx, FFT_SIZE
    jb .entry
    pop es
    ret

; Return EAX = log2(EAX) in 1/8 steps.
log2_8:
    test eax, eax
    jz .done
    bsr ecx, eax
    cmp cl, 3
    jb .small
    sub cl, 3
    shr eax, cl
    add cl, 3
    jmp .fraction
.small:
    neg cl
    add cl, 3
    shl eax, cl
    neg cl
    add cl, 3
.fraction:
    and eax, 7
    movzx ecx, cl
    lea eax, [eax+ecx*8]
.done:
    ret

analyze:
    push es
    mov es, [work_seg]
    mov bx, [ring_pos]
    xor si, si
.load:
    mov ax, si
    call cosine
    movsx ecx, ax
    neg ecx
    add ecx, 32767
    shr ecx, 1
    mov di, bx
    shl di, 2
    movsx eax, word [ring+di]
    movsx edx, word [ring+di+2]
    add eax, edx
    sar eax, 1
    imul eax, ecx
    sar eax, 15
    mov di, si
    add di, di
    mov di, [es:W_BITREV+di]
    mov [es:W_RE+di], eax
    mov dword [es:W_IM+di], 0
    inc bx
    and bx, RING_FRAMES-1
    inc si
    cmp si, FFT_SIZE
    jb .load
    mov word [fft_half], 1
.stage:
    mov word [fft_k], 0
.twiddle:
    mov ax, 512
    xor dx, dx
    div word [fft_half]
    mul word [fft_k]
    push ax
    call sine
    movsx eax, ax
    mov [fft_sin], eax
    pop ax
    call cosine
    movsx eax, ax
    mov [fft_cos], eax
    mov bx, [fft_k]
.butterfly:
    mov di, bx
    add di, [fft_half]
    shl di, 2
    push bx
    shl bx, 2
    mov eax, [es:W_RE+di]
    imul eax, [fft_cos]
    mov edx, [es:W_IM+di]
    imul edx, [fft_sin]
    add eax, edx
    sar eax, 15
    mov ecx, [es:W_IM+di]
    imul ecx, [fft_cos]
    mov edx, [es:W_RE+di]
    imul edx, [fft_sin]
    sub ecx, edx
    sar ecx, 15
    mov edx, [es:W_RE+bx]
    mov esi, edx
    sub edx, eax
    sar edx, 1
    mov [es:W_RE+di], edx
    add esi, eax
    sar esi, 1
    mov [es:W_RE+bx], esi
    mov edx, [es:W_IM+bx]
    mov esi, edx
    sub edx, ecx
    sar edx, 1
    mov [es:W_IM+di], edx
    add esi, ecx
    sar esi, 1
    mov [es:W_IM+bx], esi
    pop bx
    add bx, [fft_half]
    add bx, [fft_half]
    cmp bx, FFT_SIZE
    jb .butterfly
    inc word [fft_k]
    mov ax, [fft_k]
    cmp ax, [fft_half]
    jb .twiddle
    shl word [fft_half], 1
    cmp word [fft_half], FFT_SIZE
    jb .stage
    ; Bars: the largest bin power in each band.
    xor bp, bp
.bar:
    mov si, bp
    add si, si
    mov bx, [gs:A_BARS+si]
    mov cx, [gs:A_BARS+si+2]
    xor edi, edi
.bin:
    push bx
    shl bx, 2
    mov eax, [es:W_RE+bx]
    call clamp_short
    imul eax, eax
    mov edx, eax
    mov eax, [es:W_IM+bx]
    call clamp_short
    imul eax, eax
    add eax, edx
    pop bx
    cmp eax, edi
    jbe .smaller
    mov edi, eax
.smaller:
    inc bx
    cmp bx, cx
    jb .bin
    mov eax, edi
    call log2_8
    sub eax, BAR_FLOOR
    jge .positive
    xor eax, eax
.positive:
    imul eax, BAR_HEIGHT
    xor edx, edx
    mov ecx, BAR_RANGE
    div ecx
    cmp eax, BAR_HEIGHT
    jbe .height
    mov eax, BAR_HEIGHT
.height:
    call bar_update
    inc bp
    cmp bp, ANA_BARS
    jb .bar
    pop es
    ; VU levels from the recent frames.
    mov si, 0
    call vu_measure
    mov [vu_target], al
    mov si, 2
    call vu_measure
    mov [vu_target+1], al
    ret

; EAX = signed value. Clamp it to a short.
clamp_short:
    cmp eax, 32767
    jle .low
    mov eax, 32767
.low:
    cmp eax, -32767
    jge .done
    mov eax, -32767
.done:
    ret

; AL = new height of bar BP.
bar_update:
    mov ah, [bar_level+bp]
    cmp al, ah
    jae .set
    mov al, ah
    sub al, 1
    jnc .set
    xor al, al
.set:
    mov [bar_level+bp], al
    cmp al, [bar_peak+bp]
    jb .fall
    mov [bar_peak+bp], al
    mov byte [bar_hold+bp], 24
    ret
.fall:
    cmp byte [bar_hold+bp], 0
    je .drop
    dec byte [bar_hold+bp]
    ret
.drop:
    dec byte [bar_peak+bp]
    ret

; Let the bars and needles fall when there is no sound.
analyze_idle:
    xor bp, bp
.bar:
    xor al, al
    call bar_update
    inc bp
    cmp bp, ANA_BARS
    jb .bar
    mov word [vu_target], 0
    ret

; SI = 0 for left, 2 for right. Return AL = needle position 0 to 255.
vu_measure:
    mov bx, [ring_pos]
    sub bx, VU_FRAMES
    xor edi, edi
    mov cx, VU_FRAMES
.frame:
    and bx, RING_FRAMES-1
    push bx
    shl bx, 2
    add bx, si
    movsx eax, word [ring+bx]
    pop bx
    test eax, eax
    jns .positive
    neg eax
.positive:
    add edi, eax
    inc bx
    loop .frame
    mov eax, edi
    shr eax, 9
    call log2_8
    sub eax, VU_FLOOR
    jge .above
    xor eax, eax
.above:
    imul eax, 255
    xor edx, edx
    mov ecx, VU_RANGE
    div ecx
    cmp eax, 255
    jbe .done
    mov eax, 255
.done:
    ret

; Move the needles toward their targets.
vu_move:
    xor bx, bx
.needle:
    movzx ax, byte [vu_target+bx]
    movzx dx, byte [vu_level+bx]
    sub ax, dx
    jl .fall
    sar ax, 2
    jmp .move
.fall:
    sar ax, 3
    jnz .move
    dec ax
    cmp byte [vu_level+bx], 0
    jne .move
    xor ax, ax
.move:
    add [vu_level+bx], al
    inc bx
    cmp bx, 2
    jb .needle
    ret
