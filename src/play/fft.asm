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
    ; The Hann window: (1 - cos) / 2 in Q15.
    lea ax, [bx+256]
    call sine
    movsx ecx, ax
    neg ecx
    add ecx, 32767
    shr ecx, 1
    mov [fft_window+si], cx
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

; Clamp EAX to -32767..32767.
%macro CLAMP_SHORT 0
    cmp eax, 32767
    jle %%low
    mov eax, 32767
%%low:
    cmp eax, -32767
    jge %%done
    mov eax, -32767
%%done:
%endmacro

; The butterflies of one twiddle, from BX to the end of the arrays. BX is the
; first bin of a pair and DI the second, in bytes. %1 = 0: EBP = cos, ESI = sin.
; %1 = 1: cos 32767, sin 0. %1 = 2: cos 0, sin 32767. A product by 32767 is
; (x << 15) - x, exactly as IMUL gives it.
%macro BUTTERFLIES 1
%%next:
    mov di, bx
    add di, [fft_half]
%if %1 == 0
    mov eax, [es:W_RE+di]
    imul eax, ebp
    mov edx, [es:W_IM+di]
    imul edx, esi
    add eax, edx
    sar eax, 15
    mov ecx, [es:W_IM+di]
    imul ecx, ebp
    mov edx, [es:W_RE+di]
    imul edx, esi
    sub ecx, edx
    sar ecx, 15
%elif %1 == 1
    mov eax, [es:W_RE+di]
    mov edx, eax
    shl eax, 15
    sub eax, edx
    sar eax, 15
    mov ecx, [es:W_IM+di]
    mov edx, ecx
    shl ecx, 15
    sub ecx, edx
    sar ecx, 15
%else
    mov eax, [es:W_IM+di]
    mov edx, eax
    shl eax, 15
    sub eax, edx
    sar eax, 15
    mov ecx, [es:W_RE+di]
    mov edx, ecx
    shl ecx, 15
    sub ecx, edx
    neg ecx
    sar ecx, 15
%endif
    mov edx, [es:W_RE+bx]
    sub edx, eax
    sar edx, 1
    mov [es:W_RE+di], edx
    add eax, [es:W_RE+bx]
    sar eax, 1
    mov [es:W_RE+bx], eax
    mov edx, [es:W_IM+bx]
    sub edx, ecx
    sar edx, 1
    mov [es:W_IM+di], edx
    add ecx, [es:W_IM+bx]
    sar ecx, 1
    mov [es:W_IM+bx], ecx
    add bx, [fft_half]
    add bx, [fft_half]
    cmp bx, FFT_SIZE*4
    jb %%next
    jmp .twiddle_next
%endmacro

analyze:
    push es
    mov es, [work_seg]
    mov bx, [ring_pos]
    xor si, si
.load:
    movzx ecx, word [fft_window+si]
    mov di, bx
    shl di, 2
    movsx eax, word [ring+di]
    movsx edx, word [ring+di+2]
    add eax, edx
    sar eax, 1
    imul eax, ecx
    sar eax, 15
    mov di, [es:W_BITREV+si]
    mov [es:W_RE+di], eax
    mov dword [es:W_IM+di], 0
    inc bx
    and bx, RING_FRAMES-1
    add si, 2
    cmp si, FFT_SIZE*2
    jb .load
    ; The butterflies. fft_half and fft_k are in bytes of the work arrays
    ; (4 a bin); fft_step and fft_angle in bytes of the sine table, so the
    ; angle of twiddle k is k * 512 / half, as a sine table index.
    mov word [fft_half], 4
    mov word [fft_step], 1024
.stage:
    mov word [fft_k], 0
    mov word [fft_angle], 0
.twiddle:
    mov bx, [fft_angle]
    movsx esi, word [gs:A_SINE+bx]
    movsx ebp, word [gs:A_SINE+512+bx]
    mov bx, [fft_k]
    ; A twiddle of 0 or 90 degrees multiplies by 32767 and 0 only.
    cmp ebp, 32767
    jne .not_zero
    test esi, esi
    jz .zero
.not_zero:
    cmp esi, 32767
    jne .general
    test ebp, ebp
    jz .quarter
.general:
    BUTTERFLIES 0
.zero:
    BUTTERFLIES 1
.quarter:
    BUTTERFLIES 2
.twiddle_next:
    mov ax, [fft_step]
    add [fft_angle], ax
    add word [fft_k], 4
    mov ax, [fft_k]
    cmp ax, [fft_half]
    jb .twiddle
    shr word [fft_step], 1
    shl word [fft_half], 1
    cmp word [fft_half], FFT_SIZE*4
    jb .stage
    ; Bars: the largest bin power in each band.
    xor bp, bp
.bar:
    mov si, bp
    add si, si
    mov bx, [gs:A_BARS+si]
    mov cx, [gs:A_BARS+si+2]
    shl bx, 2
    shl cx, 2
    xor edi, edi
.bin:
    mov eax, [es:W_RE+bx]
    CLAMP_SHORT
    imul eax, eax
    mov edx, eax
    mov eax, [es:W_IM+bx]
    CLAMP_SHORT
    imul eax, eax
    add eax, edx
    cmp eax, edi
    jbe .smaller
    mov edi, eax
.smaller:
    add bx, 4
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
    mov di, [ring_pos]
    sub di, VU_FRAMES
    and di, RING_FRAMES-1
    shl di, 2
    add di, si
    xor edx, edx
    mov cx, VU_FRAMES
.frame:
    movsx eax, word [ring+di]
    test eax, eax
    jns .positive
    neg eax
.positive:
    add edx, eax
    add di, 4
    and di, RING_FRAMES*4-1
    dec cx
    jnz .frame
    mov eax, edx
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
