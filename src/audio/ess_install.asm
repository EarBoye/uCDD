; SPDX-FileCopyrightText: 2026 vorvek
; SPDX-License-Identifier: GPL-3.0-only

; Experimental. The ESS start code. It runs once, at installation or in the
; UCDDSET test. The driver keeps it in the part that DOS releases after the
; installation, and calls it with a far call (ess_install_entry) with DS set
; to the resident segment. Its own data is addressed with CS.

; Models 4 and 5 are the ESS AudioDrive. They use the ring of model 2.
; Callers that size the ring run this first.
sb_model:
    mov al, [sound_card]
    sub al, 4
    jb .done
    mov [ess_half], al
    mov byte [sound_card], 2
    mov byte [ess_native], 1
%ifdef RESIDENT_AUDIO
    mov word [ess_install_far], ess_install_entry
    mov [ess_install_far+2], cs
%endif
.done:
    ret

%ifdef RESIDENT_AUDIO
ess_install_entry:
    call ess_start_body
    retf
ess_start_body:
%else
ess_start:
%endif
    call ess_probe
    jc .fail
    mov si, ess_table
    mov cx, 1
    call ess_list
    ; Stereo: only bits 1 and 0 change.
    mov al, 0a8h
    mov cx, 0fc01h
    call ess_modify
    jc .fail
    mov cx, 4
    call ess_list
    cmp byte [ess_half], 0
    je .rate
    add si, 8
.rate:
    mov cl, 4
    call ess_list
    cmp byte [cs:ess_adjust], 0
    je .interrupts
    ; A reset clears the clock adjust, so it is set here.
    mov al, 0bah
    mov cx, 2040h
    call ess_modify
    jc .fail
.interrupts:
    mov al, 0b1h
    mov cx, 0f50h
    call ess_modify
    jc .fail
    mov al, 0b2h
    call ess_modify
    jc .fail
    call ess_resources
    jc .fail
    call ess_mixer_save
    mov ax, 0ff14h
    call indexed_write
    mov al, 22h
    mov ah, [master_register]
    call indexed_write
%ifdef RESIDENT_AUDIO
    mov al, [ess_saved+2]
    mov ah, al
    shl ah, 4
    and al, 0f0h
    call fm_init
%endif
    call dma8_output_hook
    mov byte [sb_running], 1
    mov es, [output_segment]
    xor bx, bx
    mov cx, RING_BYTES-1
    cmp byte [ess_half], 0
    je .program
    mov cx, RING_BYTES/2-1
.program:
    mov ah, 18h
    call pro_dma
    ; The data sheet asks for 100 ms before D1h, to prevent a pop.
    mov cx, 3
    call ess_ticks
    call dsp_speaker_on
    jc .stop
    mov ax, 05b8h
    call ess_write
    jc .stop
    mov cx, 3
    call ess_ticks_irq
    jc .no_interrupt
%ifdef RESIDENT_AUDIO
    call ess_measure
    jc .stop
%endif
    clc
    ret
.no_interrupt:
    ESS_ERROR ess_interrupt_message
.stop:
    call ess_stop
.fail:
    call physical_reset
    stc
    ret

; Reset the chip, enable the extended commands, and check that it answers as
; an ESS AudioDrive: E7h gives 68h and then 8xh. Chips with the mixer
; identification of the ES1868 and ES1878 have the clock adjust in BAh.
ess_probe:
    mov al, 3
    call physical_reset.value
    jc .absent
    mov al, 0c6h
    call dsp_write
    jc .absent
    mov al, 0e7h
    call dsp_write
    jc .absent
    call ess_reply
    jc .absent
    cmp al, 68h
    jne .absent
    call ess_reply
    jc .absent
    and al, 0f0h
    cmp al, 80h
    jne .absent
%ifdef TEST_ESS_ID
    mov byte [cs:ess_adjust], 1
%else
    call ess_identify
    setnc byte [cs:ess_adjust]
%endif
    clc
    ret
.absent:
    ESS_ERROR ess_answer_message
    stc
    ret

%ifdef RESIDENT_AUDIO
; EBX: the output rate in Hz.
ess_set_rate:
    mov [output_rate], ebx
    mov eax, 44100*65536
    xor edx, edx
    div ebx
    mov [cd_step], eax
    mov [cd_step_remainder], edx
    ret
%endif

; CF clear for an ES1868 or ES1878. With index 40h written once, four reads of
; the mixer data port give 18h, then 68h or 78h, and the configuration address.
; The ES1869 gives 69h and has no clock adjust. The ES1887 and ES1888 use 40h as
; a configuration register and do not match. physical_read changes AX, so CL
; holds the first byte.
ess_identify:
    mov al, 40h
    call wss_read
    mov cl, al
    call physical_read
    mov bl, al
    call physical_read
    call physical_read
    cmp cl, 18h
    jne .other
    cmp bl, 68h
    je .known
    cmp bl, 78h
    je .known
.other:
    stc
    ret
.known:
    clc
    ret

; Returns AX: the BIOS tick count.
ess_tick:
    push es
    push 40h
    pop es
    mov ax, [es:6ch]
    pop es
    ret

; CX: BIOS ticks to wait, at least. The wait is more than CX-1 whole ticks.
ess_ticks:
    call ess_tick
    mov bx, ax
.wait:
    call ess_tick
    sub ax, bx
    cmp ax, cx
    jb .wait
    ret

; CX: BIOS ticks. CF set when the output sends no period interrupt in that time.
ess_ticks_irq:
    call ess_tick
    mov bx, ax
.wait:
    cmp dword [periods], 0
    jne .ready
    call ess_tick
    sub ax, bx
    cmp ax, cx
    jb .wait
    stc
    ret
.ready:
    clc
    ret

; B1h and B2h show the IRQ and the DMA channel of the chip in bits 3:2. They
; must be the UCDDSET settings: IRQ 5 is 1 and IRQ 7 is 2, DMA 0 is 1, DMA 1
; is 2, and DMA 3 is 3.
ess_resources:
    mov al, 0b1h
    call ess_read
    jc .done
    and al, 0ch
    mov ah, 4
    cmp byte [sb_irq], 5
    je .irq
    mov ah, 8
.irq:
    cmp al, ah
    jne .mismatch
    mov al, 0b2h
    call ess_read
    jc .done
    and al, 0ch
    mov ah, [sb_dma8]
    inc ah
    cmp ah, 4
    jne .dma
    dec ah
.dma:
    shl ah, 2
    cmp al, ah
    jne .mismatch
    clc
.done:
    ret
.mismatch:
    ESS_ERROR ess_resource_message
    stc
    ret

%ifdef RESIDENT_AUDIO
; Measure the real rate with up to 3 tries. A try that the timer makes
; unreliable is repeated.
ess_measure:
    push bp
    push 3
    mov bp, sp
.try:
    call ess_rate_once
    jnc .done
    dec word [bp]
    jnz .try
.done:
    pop ax
    pop bp
    jnc .ok
    ESS_ERROR ess_rate_message
.ok:
    ret

; The output clock counts mixed frames. Between two reads 5 BIOS ticks apart
; the timer gives the exact time, so a late interrupt does not matter. The
; result sets the rate for the mixer. A rate more than 1 percent away from
; both 44100 and 44192 Hz is an error. CF set on error.
ess_rate_once:
    push bp
    call ess_tick
    mov bx, ax
.edge:
    call ess_tick
    cmp ax, bx
    je .edge
    push ax
    call ess_sample
    push edx
    push eax
.span:
    call ess_tick
    mov bp, sp
    sub ax, [bp+8]
    cmp ax, 5
    jb .span
    call ess_sample
    pop ecx
    pop ebx
    add sp, 2
    pop bp
    sub eax, ecx
    sub edx, ebx
    mov ecx, edx
    cmp ecx, 500000
    jb .bad
    cmp ecx, 800000
    ja .bad
    mov edx, 2*1193182
    mul edx
    div ecx
    cmp eax, 43659
    jb .bad
    cmp eax, 44634
    ja .bad
    mov ebx, 44100
    cmp eax, 44146
    jb .set
    mov ebx, 44192
.set:
    call ess_set_rate
    clc
    ret
.bad:
    stc
    ret

; Returns EAX: the output clock, EDX: the time in half cycles of the timer
; clock. Both are read with interrupts off. Timer channel 0 counts down by 2
; in mode 3 (the BIOS mode), twice in each tick, and the output pin shows
; which half. In mode 2 it counts down by 1 once.
ess_sample:
    pushf
    cli
    mov al, 0c2h
    out 43h, al
    in al, 40h
    mov bl, al
    xor al, al
    out 43h, al
    in al, 40h
    mov cl, al
    in al, 40h
    mov ch, al
    neg cx
    movzx ecx, cx
    test bl, 2
    jnz .mode3
    add ecx, ecx
    jmp .time
.mode3:
    test bl, 80h
    jnz .time
    add ecx, 10000h
.time:
    call ess_tick
    movzx eax, ax
    shl eax, 17
    add ecx, eax
    push ecx
    call output_clock
    pop edx
    popf
    ret
%endif

; SI: a table of register and value pairs. CX: the pair count.
ess_list:
    cs lodsw
    call ess_write
    loop ess_list
    ret
; AL: the register. CH: the bits to keep. CL: the bits to set.
ess_modify:
    mov bl, al
    call ess_read
    jc .done
    and al, ch
    or al, cl
    mov ah, al
    mov al, bl
    jmp ess_write
.done:
    ret
; AL: the register. Returns AL: the value. CF is set when the chip is silent.
ess_read:
    push ax
    mov al, 0c0h
    call dsp_write
    pop ax
    call dsp_write
    jc ess_reply.none
; Returns AL: the next DSP reply byte. CF is set when none comes in time.
ess_reply:
    push cx
    mov cx, 65535
    mov dx, [sb_base]
    add dx, 0eh
.wait:
    call physical_read
    test al, 80h
    loopz .wait
    pop cx
    jz .none
    sub dx, 4
    call physical_read
    clc
    ret
.none:
    stc
    ret

; The mixer registers the start writes.
ess_mixer_save:
    xor bx, bx
.register:
    mov al, [ess_registers+bx]
    call wss_read
    mov [ess_saved+bx], al
    inc bx
    cmp bx, 3
    jb .register
    mov byte [ess_saved_valid], 1
    ret

ess_adjust db 0
; B8h: auto-initialize DAC. Next: B9h four bytes for each DMA request, B6h and
; B7h 16-bit signed stereo. Then A1h and A2h: 795.5 kHz divided by 18, which is
; 44194 Hz (the chip adjusts it to 44100 Hz with BAh), and the filter clock; and
; A4h and A5h: one interrupt for each period. The second set is the half rate:
; the divider is 36, and the mixer averages each pair of frames.
ess_table:
    db 0b8h,04h
    db 0b9h,02h, 0b6h,00h, 0b7h,71h, 0b7h,0bch
    db 0a1h,0eeh, 0a2h,0fbh
    db 0a4h,(-PERIOD_BYTES) & 0ffh, 0a5h,((-PERIOD_BYTES) >> 8) & 0ffh
    db 0a1h,0dch, 0a2h,0f6h
    db 0a4h,(-PERIOD_BYTES/2) & 0ffh, 0a5h,((-PERIOD_BYTES/2) >> 8) & 0ffh
