; SPDX-License-Identifier: GPL-3.0-only

; Test build only. For every half that mix_run can take, run it into a
; scratch buffer, put the driver's state back, run the general loop for
; real, then compare the samples and a sum over the whole resident image.
; Sound always comes from the general loop. Counters are read from memory
; (signature MIXVERIF).

VERIFY_STACK_LOW equ irq_stack_top-1024
VERIFY_OUT_PARAS equ 48h         ; one half of output, 1024 bytes at most
VERIFY_SUM equ 1024              ; in the scratch segment, after the output

verify_block:
    db 'MIXVERIF'
verify_calls dd 0           ; halves that reached the general loop's entry
verify_eligible dd 0        ; of those, halves mix_run could take
verify_checked dd 0
verify_bad_samples dd 0
verify_bad_state dd 0
verify_skipped dd 0         ; eligible, not on the interrupt stack
verify_unchecked dd 0       ; eligible, no memory for the check
verify_first times 32 db 0  ; first difference: see verify_compare
verify_loops times 144 dd 0 ; checked halves by source, middle and store
verify_reasons times 16 dd 0 ; halves left to the general loop, by cause
verify_seg dw 0             ; output and sum
verify_high dw 0            ; image above the stack
verify_low dw 0             ; image below the stack
verify_limit dw 0
verify_stage db 0
verify_handler dw 0
verify_ebp dd 0
verify_cx dw 0
verify_bx dw 0
verify_di dw 0
verify_es dw 0
verify_fs dw 0
verify_end_ebp dd 0
verify_end_bx dw 0
verify_end_len dw 0
verify_end_fs dw 0
verify_flags dw 0

; A copy of the resident image in two blocks (below and above the interrupt
; stack) and one half of output, from upper memory when it has the room:
; games need the conventional memory.
verify_allocate:
    movzx ax, byte [unit_count]
    imul ax, UNIT_SIZE
    add ax, [units_base]
    add ax, 15
    and ax, 0fff0h
    mov [verify_limit], ax
    mov ax, 5800h
    int 21h
    push ax
    mov ax, 5802h
    int 21h
    xor ah, ah
    push ax
    mov ax, 5803h
    mov bx, 1
    int 21h
    mov ax, 5801h
    mov bx, 80h
    int 21h
    mov bx, [verify_limit]
    sub bx, irq_stack_top-15
    shr bx, 4
    mov ah, 48h
    int 21h
    jc .none
    mov [verify_high], ax
    mov bx, VERIFY_STACK_LOW+15
    shr bx, 4
    mov ah, 48h
    int 21h
    jc .none
    mov [verify_low], ax
    mov bx, VERIFY_OUT_PARAS
    mov ah, 48h
    int 21h
    jc .none
    mov [verify_seg], ax
.none:
    pop bx
    mov ax, 5803h
    int 21h
    pop bx
    mov ax, 5801h
    int 21h
    clc
    ret

; AX=entry. Registers are those of the general loop's entry.
mix_verify_begin:
    inc dword [verify_eligible]
    cmp word [verify_seg], 0
    jne .memory
    inc dword [verify_unchecked]
    jmp mix_half.frame_loop
.memory:
    push ax
    push bx
    mov ax, ss
    mov bx, cs
    cmp ax, bx
    pop bx
    pop ax
    jne .skip
    cmp sp, VERIFY_STACK_LOW+128
    jb .skip
    cmp sp, irq_stack_top
    ja .skip
    pushf
    pop word [verify_flags]
    cli
    mov [verify_handler], ax
    mov [verify_ebp], ebp
    mov [verify_cx], cx
    mov [verify_bx], bx
    mov [verify_di], di
    mov [verify_es], es
    mov [verify_fs], fs
    mov byte [verify_stage], 1
    call verify_save
    mov ax, [verify_handler]
    mov es, [verify_seg]
    xor di, di
    jmp ax
.skip:
    inc dword [verify_skipped]
    jmp mix_half.frame_loop

; A pass finished while a check is in progress.
mix_verify_stage:
    mov [verify_end_ebp], ebp
    mov [verify_end_bx], bx
    mov [verify_end_fs], fs
    cmp byte [verify_stage], 2
    je .second
    mov [verify_end_len], di
    call verify_sum
    mov es, [verify_seg]
    mov [es:VERIFY_SUM], eax
    call verify_restore
    mov byte [verify_stage], 2
    mov ebp, [verify_ebp]
    mov cx, [verify_cx]
    mov bx, [verify_bx]
    mov di, [verify_di]
    mov es, [verify_es]
    mov fs, [verify_fs]
    jmp mix_half.frame_loop
.second:
    mov ax, di
    sub ax, [verify_di]
    mov [verify_end_len], ax
    mov byte [verify_stage], 1
    call verify_compare
    mov byte [verify_stage], 0
    push word [verify_flags]
    popf
    jmp mix_half.half_resume

verify_save:
    pushad
    push es
    mov es, [verify_low]
    xor si, si
    xor di, di
    mov cx, VERIFY_STACK_LOW
    call verify_copy
    mov es, [verify_high]
    mov si, irq_stack_top
    xor di, di
    mov cx, [verify_limit]
    sub cx, si
    call verify_copy
    pop es
    popad
    ret

verify_restore:
    pushad
    push es
    push ds
    mov dx, [verify_limit]
    mov bx, [verify_high]
    mov ax, [verify_low]
    push cs
    pop es
    mov ds, ax
    xor si, si
    xor di, di
    mov cx, VERIFY_STACK_LOW
    call verify_copy
    mov ds, bx
    xor si, si
    mov di, irq_stack_top
    mov cx, dx
    sub cx, di
    call verify_copy
    pop ds
    pop es
    popad
    ret

; rep movsb, a doubleword at a time.
verify_copy:
    push cx
    shr cx, 2
    rep movsd
    pop cx
    and cx, 3
    rep movsb
    ret

; EAX=a sum over the resident image that depends on every byte's place.
verify_sum:
    push ebx
    push cx
    push si
    xor ebx, ebx
    xor si, si
    mov cx, VERIFY_STACK_LOW
    call .run
    mov si, irq_stack_top
    mov cx, [verify_limit]
    sub cx, si
    call .run
    mov eax, ebx
    pop si
    pop cx
    pop ebx
    ret
.run:
    push cx
    shr cx, 2
    jz .tail
.dword:
    mov eax, [si]
    add si, 4
    rol ebx, 5
    add ebx, eax
    loop .dword
.tail:
    pop cx
    and cx, 3
    jz .done
.byte:
    movzx eax, byte [si]
    inc si
    rol ebx, 5
    add ebx, eax
    loop .byte
.done:
    ret

verify_compare:
    pushad
    push es
    push fs
    xor bp, bp
    mov dx, 0ffffh
    call verify_sum
    mov es, [verify_seg]
    cmp eax, [es:VERIFY_SUM]
    jne .record
    mov fs, [verify_es]
    mov si, [verify_di]
    xor di, di
    mov cx, [verify_end_len]
    jcxz .good
.sample:
    mov al, [fs:si]
    cmp al, [es:di]
    jne .sample_bad
    inc si
    inc di
    loop .sample
.good:
    inc dword [verify_checked]
    ; Index: source*16 + middle*4 + store.
    xor bx, bx
    cmp word [verify_handler], mix_run_idle
    je .source_found
    mov ax, [mix_run_source]
    mov bx, 2
.source:
    cmp ax, [verify_sources+bx-2]
    je .source_found
    add bx, 2
    cmp bx, 16
    jbe .source
    jmp .leave
.source_found:
    shr bx, 1
    shl bx, 4
    mov ax, [mix_run_next]
    cmp ax, mix_run_clip
    jne .not_clip
    add bx, 4
.not_clip:
    cmp ax, mix_run_disc
    jne .not_disc
    add bx, 8
.not_disc:
    cmp ax, mix_run_disc_rate
    jne .not_rate
    add bx, 12
.not_rate:
    mov ax, [mix_run_store]
    cmp ax, mix_run_store_word
    je .counted_loop
    inc bx
    cmp ax, mix_run_store_half
    je .counted_loop
    inc bx
    cmp ax, mix_run_store_pro
    je .counted_loop
    inc bx
.counted_loop:
    shl bx, 2
    inc dword [verify_loops+bx]
.leave:
    pop fs
    pop es
    popad
    ret
.sample_bad:
    mov dx, di
    mov bp, 0ffffh
.record:
    cmp dx, 0ffffh
    je .count_state
    inc dword [verify_bad_samples]
    jmp .counted
.count_state:
    inc dword [verify_bad_state]
.counted:
    cmp word [verify_first], 0
    jne .good
    mov ax, [verify_handler]
    mov [verify_first], ax
    mov [verify_first+2], bp
    mov [verify_first+4], dx
    mov ax, [verify_cx]
    mov [verify_first+6], ax
    mov eax, [verify_ebp]
    mov [verify_first+8], eax
    mov eax, [game_step]
    mov [verify_first+12], eax
    mov eax, [game_limit]
    mov [verify_first+16], eax
    mov al, [game_frame_shift]
    mov [verify_first+20], al
    mov al, [game_format]
    mov [verify_first+21], al
    mov al, [cd_valid]
    mov [verify_first+22], al
    mov al, [ess_half]
    mov [verify_first+23], al
    mov ax, [mix_run_source]
    mov [verify_first+24], ax
    mov ax, [mix_run_next]
    mov [verify_first+26], ax
    mov ax, [mix_run_store]
    mov [verify_first+28], ax
    mov al, [sound_card]
    mov [verify_first+30], al
    jmp .good
verify_sources:
    dw mix_run_constant, mix_run_filter, mix_run_mono8, mix_run_mono8_filter
    dw mix_run_stereo8, mix_run_stereo8_filter, mix_run_mono16, mix_run_stereo16
