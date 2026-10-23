; SPDX-FileCopyrightText: 2026 vorvek
; SPDX-License-Identifier: GPL-3.0-only

%ifdef OWN_HOST
CD_REFILL_URGENT equ CD_READ_BYTES*2
; About 190 ms of output periods without a timer call.
CD_TIMER_STARVED equ 8192/PERIOD_FRAMES
; About 370 ms of output periods without a host refill.
CD_HOST_STARVED equ CD_TIMER_STARVED*2
%endif
CD_TIMER_READS equ 4
CD_TIMER_MAX_READS equ 32

cd_timer:
    mov word [cs:cd_timer_missed], 0
    pushf
    call far [cs:cd_old_timer]
; The audio IRQ enters here when a game timer handler does not chain.
cd_timer_refill:
    pushad
    push ds
    push es
    push fs
    push gs
    push cs
    pop ds
    cli
%ifdef OWN_HOST
    mov al, 0
    xchg al, [cd_irq_entry]
    mov [cd_irq_forced], al
%endif
    cmp byte [cd_started], 1
    jne .done
    cmp byte [cd_error], 0
    jne .done
    cmp dword [cd_remaining], 0
    je .done
    mov eax, [cd_produced]
    sub eax, [cd_consumed]
    cmp eax, CD_QUEUE_BYTES-65536
    ja .done
    ; Between refills the read limit is the timer budget. Each tick adds a
    ; few reads, and a tick that cannot read keeps its share.
    cmp byte [cd_background_reads], CD_TIMER_MAX_READS-CD_TIMER_READS
    ja .budget
    add byte [cd_background_reads], CD_TIMER_READS
.budget:
    cmp byte [busy], 0
    jne .done
    cmp byte [cd_bios_busy], 0
    jne .done
%ifdef RESIDENT_AUDIO
    ; The game is between the bytes of a DSP command (Prototype).
    call cd_dsp_wait
    jc .done
%endif
    call physical_pic_isr
    or al, [virtual_pic_service]
    jnz .done
    les bx, [cd_indos]
    cmp word [es:bx-1], 0
    jne .done
%ifdef OWN_HOST
    cmp byte [own_host_refill], 1
    jne .synchronous
    les bx, [own_host_active]
    cmp byte [es:bx], 1
    jne .synchronous
    ; With a protected-mode client, real-mode code runs inside a host call.
    ; A refill from this IRQ nests DOS and the BIOS in that call and breaks
    ; JEMMEX's nested execution (Earthworm Jim). The host refills when the
    ; call returns.
    mov byte [cd_refill_pending], 1
    jmp .done
.synchronous:
%endif
    call cd_refill_run
.done:
    pop gs
    pop fs
    pop es
    pop ds
    popad
    iret

%ifdef OWN_HOST
cd_deferred_refill:
    pushf
    pushad
    push ds
    push es
    push fs
    push gs
    push cs
    pop ds
    cli
    cmp byte [cd_refill_pending], 0
    je .done
    cmp byte [busy], 0
    jne .done
    cmp byte [cd_bios_busy], 0
    jne .done
    call cd_dsp_wait
    jc .done
    call physical_pic_isr
    or al, [virtual_pic_service]
    jnz .done
    cmp byte [cd_started], 1
    jne .cancel
    cmp byte [cd_error], 0
    jne .cancel
    cmp dword [cd_remaining], 0
    je .cancel
    les bx, [cd_indos]
    cmp word [es:bx-1], 0
    jne .done
    mov eax, [cd_produced]
    sub eax, [cd_consumed]
    cmp eax, CD_QUEUE_BYTES-65536
    ja .cancel
    mov byte [cd_refill_pending], 0
    mov word [cd_host_missed], 0
    mov byte [cd_background_reads], 1
    call cd_refill_run
    jmp .done
.cancel:
    mov byte [cd_refill_pending], 0
.done:
    pop gs
    pop fs
    pop es
    pop ds
    popad
    popf
    retf
cd_refill_pending db 0
%endif

; Run the refill on the CD stack. Interrupts are off.
cd_refill_run:
    mov byte [busy], 1
    mov [cd_call_ss], ss
    mov [cd_call_sp], sp
%ifdef EXTERNAL_CD_BUFFERS
    mov ax, [cd_work_segment]
%else
    mov ax, cs
%endif
    mov ss, ax
    mov sp, cd_stack_top
%ifdef RESIDENT_AUDIO
    call cd_refill_mask
%endif
    sti
    cld
    call cd_foreground
    cli
%ifdef RESIDENT_AUDIO
    call cd_refill_unmask
%endif
    mov byte [cd_background_reads], 0
    mov ss, [cd_call_ss]
    mov sp, [cd_call_sp]
    mov byte [busy], 0
    ret

cd_bios:
    pushf
    inc byte [cs:cd_bios_busy]
    popf
%ifdef RESIDENT_AUDIO
    call cd_cache_bios
%else
    pushf
    call far [cs:cd_old_bios]
%endif
    pushf
    dec byte [cs:cd_bios_busy]
    popf
    retf 2

cd_background_remove:
%ifdef OWN_HOST
    mov byte [cd_refill_pending], 0
%endif
    cmp byte [cd_background_set], 0
    je .done
    push ds
    lds dx, [cd_old_timer]
    mov ax, 2508h
    int 21h
    push cs
    pop ds
    lds dx, [cd_old_bios]
    mov ax, 2513h
    int 21h
    pop ds
    mov byte [cd_background_set], 0
.done:
    ret

%ifdef RESIDENT_AUDIO
; A refill runs on top of the interrupted game code. A game keyboard handler
; that does not return (Prototype skips its intro so) leaves the refill and
; DOS busy. Hold the keyboard IRQ until the refill ends.
cd_refill_mask:
    mov dx, 21h
    call physical_read
    mov [cd_refill_old_mask], al
    or al, 2
    jmp physical_write

cd_refill_unmask:
    mov dx, 21h
    call physical_read
    mov ah, [cd_refill_old_mask]
    or ah, 0fdh
    and al, ah
    jmp physical_write

cd_refill_old_mask db 0

; CF set: wait until the game sends the rest of a DSP command, for a few calls.
cd_dsp_wait:
    cmp byte [dsp_arguments], 0
    je .free
    cmp byte [cd_dsp_waits], 8
    jae .free
    inc byte [cd_dsp_waits]
    stc
    ret
.free:
    mov byte [cd_dsp_waits], 0
    clc
    ret

cd_dsp_waits db 0
%endif

cd_old_timer dd 0
cd_old_bios dd 0
cd_bios_busy db 0
cd_timer_missed dw 0
cd_irq_refill db 0
cd_irq_entry db 0
cd_irq_forced db 0
cd_host_missed dw 0
cd_background_set db 0
cd_background_reads db 0

%ifdef RESIDENT_AUDIO
%include "audio/disk_cache.asm"
%endif
