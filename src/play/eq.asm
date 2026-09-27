; SPDX-FileCopyrightText: 2026 vorvek
; SPDX-License-Identifier: GPL-3.0-only

; The 10-band equalizer. The driver calls eq_hook at audio IRQ time with the
; CD samples of one mixer period. The hook filters them in place and copies
; them to the sample ring for the analyzer.
; Each band is a band-pass resonator. Its output, times the band gain minus 1,
; is added to the input. Bands at 0 dB cost nothing. The four lowest bands run
; at 1/8 of the rate. A delay line of EQ_DELAY frames aligns the other paths
; with them. src/play/art/assets.py has the same method in Python.

; GS:BX = 16-bit stereo frames, CX = bytes, EDX = bytes since the play start.
; The output is EQ_DELAY frames late. The mixer does not interpolate CD frames
; at its 44.1 kHz output rate, so it does not mix the next frame with them.
eq_hook:
    push ds
    push cs
    pop ds
    mov [hook_offset], bx
    shr cx, 2
    mov [hook_frames], cx
    test edx, edx
    jnz .continued
    call hook_reset
.continued:
    mov si, [eq_set]
    cmp si, [hook_set]
    je .chunk
    call hook_new_set
.chunk:
    mov cx, [hook_frames]
    jcxz .done
    cmp cx, EQ_CHUNK
    jbe .size
    mov cx, EQ_CHUNK
.size:
    mov [chunk_frames], cx
    shl cx, 2
    mov [chunk_bytes], cx
    mov di, eq_state
    mov word [chunk_channel], 0
    call eq_block
    mov di, eq_state+CHANNEL_SIZE
    mov word [chunk_channel], 2
    call eq_block
    mov bx, [hook_offset]
    mov cx, [chunk_frames]
    mov di, [ring_pos]
.ring:
    mov eax, [gs:bx]
    shl di, 2
    mov [ring+di], eax
    shr di, 2
    inc di
    and di, RING_FRAMES-1
    add bx, 4
    loop .ring
    mov [ring_pos], di
    mov [hook_offset], bx
    mov ax, [chunk_frames]
    sub [hook_frames], ax
    jmp .chunk
.done:
    pop ds
    retf

; SI = new set or 0. A band that starts to work starts from rest.
hook_new_set:
    xor ax, ax
    test si, si
    jz .mask
    mov ax, [si+SET_MASK]
.mask:
    mov dx, [hook_mask]
    not dx
    and dx, ax
    mov [hook_mask], ax
    mov [hook_set], si
    xor bx, bx
.band:
    shr dx, 1
    jnc .next
    mov di, bx
    shl di, 3
    xor eax, eax
    mov [eq_state+CH_V+di], eax
    mov [eq_state+CH_V+di+4], eax
    mov [eq_state+CHANNEL_SIZE+CH_V+di], eax
    mov [eq_state+CHANNEL_SIZE+CH_V+di+4], eax
.next:
    inc bx
    cmp bx, EQ_BANDS
    jb .band
    ret

; One channel of a chunk. DI = channel state.
eq_block:
    mov bx, [hook_offset]
    add bx, [chunk_channel]
    mov [block_input], bx
    xor si, si
.input:
    mov bx, [block_input]
    movsx eax, word [gs:bx]
    add word [block_input], 4
    shl eax, 4
    add [di+CH_ACC], eax
    inc word [di+CH_COUNT]
    cmp word [di+CH_COUNT], EQ_DECIM
    jb .between
    mov word [di+CH_COUNT], 0
    push eax
    push si
    call eq_low
    pop si
    pop eax
    jmp .delay
.between:
    mov edx, [di+CH_STEP]
    add [di+CH_VALUE], edx
.delay:
    mov bx, [di+CH_POS]
    mov edx, [di+bx+CH_DELAY]
    mov [di+bx+CH_DELAY], eax
    add bx, 4
    cmp bx, EQ_DELAY*4
    jb .position
    xor bx, bx
.position:
    mov [di+CH_POS], bx
    mov eax, edx
    sub eax, [di+CH_T2]
    mov [block_t+si], eax
    mov eax, [di+CH_T1]
    mov [di+CH_T2], eax
    mov [di+CH_T1], edx
    add edx, [di+CH_VALUE]
    mov [block_y+si], edx
    add si, 4
    cmp si, [chunk_bytes]
    jb .input
    cmp word [hook_set], 0
    je .output
    ; The bands at the full rate, each over the whole chunk.
    mov [block_state], di
    mov cx, EQ_LOW
.band:
    bt [hook_mask], cx
    jnc .next
    mov [block_band], cx
    imul si, cx, 12
    add si, [hook_set]
    mov eax, [si+SET_COEFS]
    mov [band_a1], eax
    mov eax, [si+SET_COEFS+4]
    mov [band_a2], eax
    mov eax, [si+SET_COEFS+8]
    mov [band_gain], eax
    mov bx, cx
    shl bx, 3
    add bx, di
    add bx, CH_V
    mov [block_v], bx
    mov edi, [bx+4]
    mov ebx, [bx]
    xor si, si
.frame:
    mov eax, ebx
    imul dword [band_a1]
    mov ecx, eax
    mov ebp, edx
    mov eax, edi
    imul dword [band_a2]
    add ecx, eax
    adc ebp, edx
    add ecx, 1 << 27
    adc ebp, 0
    shrd ecx, ebp, 28
    add ecx, [block_t+si]
    mov edi, ebx
    mov ebx, ecx
    mov eax, ecx
    imul dword [band_gain]
    shrd eax, edx, 28
    add [block_y+si], eax
    add si, 4
    cmp si, [chunk_bytes]
    jb .frame
    mov si, [block_v]
    mov [si], ebx
    mov [si+4], edi
    mov di, [block_state]
    mov cx, [block_band]
.next:
    inc cx
    cmp cx, EQ_BANDS
    jb .band
    mov si, [hook_set]
    mov eax, [si+SET_PREAMP]
    mov [band_gain], eax
.output:
    mov bx, [hook_offset]
    add bx, [chunk_channel]
    xor si, si
.sample:
    mov eax, [block_y+si]
    cmp word [hook_set], 0
    je .round
    imul dword [band_gain]
    shrd eax, edx, 14
.round:
    add eax, 8
    sar eax, 4
    cmp eax, 32767
    jle .low
    mov eax, 32767
.low:
    cmp eax, -32768
    jge .store
    mov eax, -32768
.store:
    mov [gs:bx], ax
    add bx, 4
    add si, 4
    cmp si, [chunk_bytes]
    jb .sample
    ret

; The four lowest bands, once for each EQ_DECIM frames. DI = channel state.
eq_low:
    mov eax, [di+CH_ACC]
    mov dword [di+CH_ACC], 0
    mov ebp, eax
    sub ebp, [di+CH_D2]
    mov edx, [di+CH_D1]
    mov [di+CH_D2], edx
    mov [di+CH_D1], eax
    mov dword [eq_sum], 0
    cmp word [hook_set], 0
    je .ready
    xor cx, cx
.band:
    bt word [hook_mask], cx
    jnc .next
    mov bx, cx
    shl bx, 3
    add bx, di
    add bx, CH_V
    imul si, cx, 12
    add si, [hook_set]
    add si, SET_COEFS
    push cx
    call resonate
    pop cx
    add [eq_sum], eax
.next:
    inc cx
    cmp cx, EQ_LOW
    jb .band
.ready:
    mov eax, [di+CH_CURRENT]
    mov [di+CH_VALUE], eax
    mov edx, [eq_sum]
    mov [di+CH_CURRENT], edx
    sub edx, eax
    sar edx, 3
    mov [di+CH_STEP], edx
    ret

; EBP = input difference, BX = v1 and v2, SI = coefficients. Return EAX.
resonate:
    push di
    mov eax, [bx]
    imul dword [si]
    mov ecx, eax
    mov edi, edx
    mov eax, [bx+4]
    imul dword [si+4]
    add ecx, eax
    adc edi, edx
    add ecx, 1 << 27
    adc edi, 0
    shrd ecx, edi, 28
    pop di
    add ecx, ebp
    mov eax, [bx]
    mov [bx+4], eax
    mov [bx], ecx
    mov eax, ecx
    imul dword [si+8]
    shrd eax, edx, 28
    ret

hook_reset:
    push es
    push ds
    pop es
    mov di, eq_state
    mov cx, 2*CHANNEL_SIZE/4
    xor eax, eax
    rep stosd
    pop es
    ret

; Make the coefficient set from eq_gain and give it to the hook.
eq_apply:
    cmp byte [eq_on], 0
    je .bypass
    cmp byte [eq_slow], 0
    jne .bypass
    mov si, eq_gain
    mov cx, EQ_BANDS+1
.any:
    cmp byte [si], 0
    jne .build
    inc si
    loop .any
.bypass:
    mov word [eq_set], 0
    ret
.build:
    mov di, eq_set_a
    cmp word [eq_set], di
    jne .buffer
    mov di, eq_set_b
.buffer:
    movsx bx, byte [eq_gain]
    add bx, 12
    shl bx, 2
    mov eax, [gs:A_PREAMP+bx]
    mov [di+SET_PREAMP], eax
    xor dx, dx
    xor bx, bx
.band:
    movsx ax, byte [eq_gain+bx+1]
    test ax, ax
    jz .next
    bts dx, bx
    add ax, 12
    shl ax, 2
    imul si, bx, BAND_TABLE
    add si, A_EQ
    push di
    imul cx, bx, 12
    add di, cx
    mov ecx, [gs:si]
    mov [di+SET_COEFS], ecx
    mov ecx, [gs:si+4]
    mov [di+SET_COEFS+4], ecx
    add si, ax
    mov ecx, [gs:si+8]
    mov [di+SET_COEFS+8], ecx
    pop di
.next:
    inc bx
    cmp bx, EQ_BANDS
    jb .band
    mov [di+SET_MASK], dx
    mov [eq_set], di
    ret

; AL = preset number.
eq_preset:
    cmp al, PRESET_COUNT
    jb .ready
    xor al, al
.ready:
    mov [preset], al
    movzx si, al
    imul si, si, PRESET_SIZE
    add si, presets
    mov di, eq_gain
    push ds
    pop es
    mov cx, EQ_BANDS+1
    rep movsb
    mov [preset_name], si
    mov byte [eq_on], 1
    jmp eq_apply

; AL = slider (0 is the preamp), AH = signed change.
eq_change:
    movzx bx, al
    mov al, [eq_gain+bx]
    add al, ah
    cmp al, -12
    jge .low
    mov al, -12
.low:
    cmp al, 12
    jle .high
    mov al, 12
.high:
    ; AL = new value.
eq_set_gain:
    mov [eq_gain+bx], al
    mov word [preset_name], text_user
    mov byte [eq_on], 1
    jmp eq_apply

; Before the hook is installed, time all bands on noise for four timer ticks.
; Set eq_slow when the equalizer would need more than 75 percent of the free
; CPU time. 30280 / count is the percentage.
eq_calibrate:
    push gs
    mov di, ring
    mov cx, RING_FRAMES*2
.noise:
    call random
    mov [di], ax
    add di, 2
    loop .noise
    mov si, eq_gain
    mov di, eq_saved
    push ds
    pop es
    mov cx, EQ_BANDS+1
    rep movsb
    mov di, eq_gain+1
    mov al, 3
    mov cx, EQ_BANDS
    rep stosb
    call eq_apply
    mov si, [eq_set]
    call hook_new_set
    push ds
    pop gs
    mov word [chunk_frames], EQ_CHUNK
    mov word [chunk_bytes], EQ_CHUNK*4
    mov word [chunk_channel], 0
    push ds
    push 40h
    pop ds
    mov bx, [6ch]
.edge:
    cmp bx, [6ch]
    je .edge
    mov bx, [6ch]
    pop ds
    xor bp, bp
.run:
    mov word [hook_offset], ring
    mov di, eq_state
    push bp
    push bx
    call eq_block
    pop bx
    pop bp
    inc bp
    push ds
    push 40h
    pop ds
    mov ax, [6ch]
    pop ds
    sub ax, bx
    cmp ax, 4
    jb .run
    cmp bp, 404
    jae .fast
    mov byte [eq_slow], 1
.fast:
    mov si, eq_saved
    mov di, eq_gain
    push ds
    pop es
    mov cx, EQ_BANDS+1
    rep movsb
    xor si, si
    call hook_new_set
    call hook_reset
    call eq_apply
    mov di, ring
    mov cx, RING_FRAMES*2
    xor ax, ax
    rep stosw
    pop gs
    ret

; Install the hook in the driver. CF when the driver has no hook.
hook_install:
    cmp byte [physical_source], 0
    jne .local
    mov dx, eq_hook
    mov ax, 9
    call call_control
    test ax, ax
    jnz .none
.local:
    mov byte [hook_active], 1
    clc
    ret
.none:
    stc
    ret

hook_remove:
    cmp byte [hook_active], 0
    je .done
    cmp byte [physical_source], 0
    jne .clear
    push ds
    xor dx, dx
    mov ds, dx
    mov ax, 9
    mov bl, [cs:subunit]
    call far [cs:control_entry]
    pop ds
    test ax, ax
    jnz .done
.clear:
    mov byte [hook_active], 0
.done:
    ret
