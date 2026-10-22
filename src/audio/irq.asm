; SPDX-FileCopyrightText: 2026 vorvek
; SPDX-License-Identifier: GPL-3.0-only

%include "audio/sb_state.inc"

; One virtual, edge-triggered master-PIC input.
virtual_irq_init:
    mov dx, 21h
    call physical_read
    mov [virtual_pic_mask], al
    mov [physical_pic_initial], al
    mov cl, [sb_irq]
    mov al, 1
    shl al, cl
    mov [physical_irq_bit], al
    or al, [guest_irq_bit]
    not al
    mov [pic_visible_bits], al
    ret

virtual_irq_reset:
    ; The MPU-401's request (bit 2) is not the DSP's to clear.
    and byte [virtual_dsp_irq], 4
    jnz .mpu_held
    mov byte [virtual_pic_request], 0
.mpu_held:
    mov byte [f2h_held], 0
    mov byte [f2h_seen], 0
    mov dword [virtual_block_seen], 0
    ret

virtual_irq_tick:
    call virtual_mpu_refresh
%ifdef ESS_CARD
    ; The virtual ESS keeps its own time (audio/ess/card.asm, ess_fifo.asm).
    cmp byte [virtual_model], 4
    jne .not_ess
    call ess_fifo_service
    ret
.not_ess:
%endif
    cmp byte [game_active], 0
    je .done
    mov si, [game_dma]
    cmp byte [si+DMA_MASK], 0
    jne .done
    call game_elapsed
%ifdef RESIDENT_AUDIO
    cmp byte [sb_single], 0
    je .elapsed_ready
    cmp byte [game_start_pending], 1
    je .done
    mov eax, [game_mix_frame]
.elapsed_ready:
%endif
    cmp dword [game_exit_frame], 0
    je .position
    cmp eax, [game_exit_frame]
    jb .position
%ifdef RESIDENT_AUDIO
    cmp byte [sb_single], 0
    je .no_patch
    add eax, [game_started]
    mov [sb_patch_limit], eax
    mov eax, [game_exit_frame]
    add eax, [game_started]
    mov [sb_patch_clock], eax
    mov byte [sb_patch_available], 1
.no_patch:
%endif
    mov eax, [game_exit_frame]
    mov byte [game_active], 0
    cmp byte [sb_single], 0
    jne .single_end
%ifdef SB_CARDS
    ; An auto-init transfer that a queued single-cycle command ends: the
    ; controller stops after its last block, where the queued transfer goes
    ; on (trap.asm, sb_queued). The transfer started at the buffer's base.
    cmp byte [sb_queued], 0
    je .position
    push eax
    mov dword [si+DMA_POSITION], 0
    mov eax, [sb_exit_frames]
    mov cl, [game_frame_shift]
    shl eax, cl
    call .controller_stop
    pop eax
%endif
    jmp .position
.single_end:
    push eax
    mov eax, [game_block_bytes]
    call .controller_stop
    mov byte [sb_finished], 1
    ; 91h leaves high-speed mode at the end of its block (SBG:1349-1350); a
    ; reset after it is a cold start again (trap.asm, sb_warm).
    mov byte [sb_highspeed], 0
    mov byte [sb_warm], 0
%ifdef SB_CARDS
    ; An ADPCM block's last ticks, run while the buffer still holds its
    ; bytes (sb_adpcm.asm).
    call sb_adpcm_close
%endif
    pop eax
    mov eax, [game_block_bytes]
    jmp .byte_position
; EAX=the bytes a transfer moved: the controller's position and count after
; them, from its position at the start. SI=the channel. EAX, BX, ECX, EDX
; changed.
.controller_stop:
    cmp si, dma16
    jne .units
    shr eax, 1
.units:
    add eax, [si+DMA_POSITION]
    movzx ecx, word [si+DMA_COUNT]
    inc ecx
    test byte [si+DMA_MODE], 10h
    jz .stop_position
    xor edx, edx
    div ecx
    mov eax, edx
.stop_position:
    mov [si+DMA_POSITION], eax
    mov bx, [si+DMA_COUNT]
    sub bx, ax
    mov [si+DMA_SNAPSHOT], bx
    cmp bx, 0ffffh
    jne .stopped
    mov byte [si+3], 1
.stopped:
    ret
.position:
    cmp byte [sb_tail_mode], 0
    je .render_position
    mov eax, [sb_tail_consumed]
    jmp .byte_position
.render_position:
    movzx ecx, word [game_rate]
    mul ecx
    mov ecx, OUTPUT_RATE
    div ecx
    mov cl, [game_frame_shift]
    shl eax, cl
%ifdef WSS_INPUT
    cmp byte [game_source], 1
    jne .block_position
    sub eax, [wss_block_origin]
.block_position:
%endif
.byte_position:
    xor edx, edx
    mov ecx, [game_block_bytes]
    div ecx
    cmp eax, [virtual_block_seen]
    je .done
    mov [virtual_block_seen], eax
%ifdef WSS_INPUT
    cmp byte [game_source], 1
    jne .sb
    test byte [wss_status], 1
    jnz .done
    or byte [wss_status], 1
    call wss_hold
    test byte [wss_registers+10], 2
    jz .done
    mov ax, [wss_guest_irq]
    mov [wss_irq_event], ax
    ret
.sb:
%endif
%ifdef ESS_FIFO_MODEL
    ; A Compatibility Mode block ends on the ESS processor: 2xCh bit 2.
    cmp byte [virtual_model], 4
    jne .latch_ready
    or byte [ess_status_latch], 4
.latch_ready:
%endif
    ; The block's bit joins the others at 82h. The line is already high
    ; when another is set: no new edge, as on the card.
    mov al, [game_irq_bit]
    cmp byte [virtual_dsp_irq], 0
    jne .signalled
    mov [virtual_dsp_irq], al
.raise:
    inc dword [irq_raised]
    mov byte [virtual_irq_stale], 0
    mov al, [guest_irq_bit]
    mov [virtual_pic_request], al
.done:
    ret
.signalled:
    inc dword [irq_overrun]
    or [virtual_dsp_irq], al
    ; The interrupt was delivered and ended but never acknowledged (no 22Eh
    ; or 22Fh read): a handler that took it for a spurious one. A card holds
    ; its request until the acknowledge; raise it again after a whole period
    ; with nothing requested or in service, so one refused interrupt does
    ; not stop the stream for good.
    mov al, [virtual_pic_request]
    or al, [virtual_pic_service]
    jnz .fresh
    inc byte [virtual_irq_stale]
    cmp byte [virtual_irq_stale], 2
    jb .stale_wait
    inc dword [irq_reraised]
    jmp .raise
.stale_wait:
    ret
.fresh:
    mov byte [virtual_irq_stale], 0
    ret

; Command 80h: signal the 8-bit interrupt once the silence has played.
sb_silence_tick:
    cmp byte [sb_silence], 0
    je .done
    mov eax, [periods]
    shl eax, OUTPUT_SHIFT
    sub eax, [sb_silence_end]
    js .done
    mov byte [sb_silence], 0
    mov al, 1
    call virtual_dsp_raise
.done:
    ret

; AL=the DSP interrupt bits to set (1 the 8-bit, 2 the 16-bit). The DSP's
; interrupt line is a level, held until the game reads 2xEh or 2xFh, and
; the 8259 takes an edge: while any DSP request is still unacknowledged
; the line is already high, so a new one only adds its bit, as the bare
; SB16 and ES1688 do (F2TEST: one interrupt for F2h twice without the
; acknowledge). A request to the controller only from a clear line.
virtual_dsp_raise:
%ifdef ESS_FIFO_MODEL
    ; F2h, F3h and the 80h silence end are the ESS processor's: 2xCh bit 2.
    cmp byte [virtual_model], 4
    jne virtual_dsp_raise_line
    or byte [ess_status_latch], 4
%endif
; The same without the ESS status bit: the model's DMA counter overflow.
virtual_dsp_raise_line:
    call virtual_mpu_refresh
    cmp byte [virtual_dsp_irq], 0
    jne .held
    inc dword [irq_raised]
    or [virtual_dsp_irq], al
    mov al, [guest_irq_bit]
    mov [virtual_pic_request], al
    ret
.held:
    or [virtual_dsp_irq], al
    ret

; After an acknowledge (2xEh, 2xFh): with no source left the line is low, and
; a request the controller has not yet given to the CPU goes away with it,
; as at an 8259 whose input falls before the interrupt is taken. Flags only.
virtual_line_dropped:
    cmp byte [virtual_dsp_irq], 0
    jne .done
    mov byte [virtual_pic_request], 0
.done:
    ret

; Bit 2 of virtual_dsp_irq is the MPU-401's request on the virtual SB16's
; line (sb16.asm, sb16_mpu_irq). The game ends it by reading 330h, which the
; driver does not see: the bit follows the physical card's 82h bit 2, read
; whenever the virtual line or 82h is looked at. Every register is kept.
virtual_mpu_refresh:
    test byte [virtual_dsp_irq], 4
    jnz .look
    ret
.look:
    push ax
    push dx
    mov dx, [sb_base]
    add dx, 4
    mov al, 82h
    call physical_write
    inc dx
    call physical_read
    test al, 4
    jnz .done
    and byte [virtual_dsp_irq], 0fbh
.done:
    pop dx
    pop ax
    ret

; F2h. The chip runs its commands in turn and raises each F2h's interrupt
; 11.7 to 14.2 us after the command (ES1868F, F2TEST 15 Oct 2026), while
; the program runs on: two F2h a few microseconds apart give two interrupts
; one after the other. The Miles ESS driver depends on that: it sends F2h
; twice, then waits for its interrupt count to read exactly 1, then 2.
; A trap cannot interrupt the program later on its own, so the first F2h
; raises at once (the trap itself takes about as long as the chip). One
; that comes within F2H_CALLS trapped port accesses and F2H_FRAMES output
; frames of the last one raised is held: in the chip's latency a program
; makes only a few port accesses. Counting accesses keeps the rule the same
; on a 386 and a Pentium. f2h_service raises the held ones, one at each
; later trapped access or output interrupt.
F2H_CALLS equ 8
F2H_FRAMES equ 128
virtual_f2h:
    pushad
    cmp byte [f2h_held], 0
    jne .hold
    call output_clock
    cmp byte [f2h_seen], 0
    je .raise
    mov edx, [port_calls]
    sub edx, [f2h_calls]
    cmp edx, F2H_CALLS
    jae .raise
    mov edx, eax
    sub edx, [f2h_last]
    cmp edx, F2H_FRAMES
    jb .hold
.raise:
    mov [f2h_last], eax
    mov byte [f2h_seen], 1
    call f2h_raise
    popad
    ret
.hold:
    cmp byte [f2h_held], 0ffh
    je .done
    inc byte [f2h_held]
.done:
    popad
    ret

f2h_service:
    cmp byte [f2h_held], 0
    jne .due
    ret
.due:
    pushad
    call output_clock
    mov [f2h_last], eax
    dec byte [f2h_held]
    call f2h_raise
    popad
    ret

f2h_raise:
    mov eax, [port_calls]
    mov [f2h_calls], eax
    mov al, 1
    jmp virtual_dsp_raise

; Far entry (RETF). Called with CS pushed from sb_patch's hold check, and by
; the host's real-mode call through the CDF pointer block (the host takes the
; virtual interrupt before it delivers it). DS is unknown on entry and set to
; CS here; BX, CX and DX are saved. AX=1 when the virtual interrupt went into
; service, 0 when it was masked, already in service, not requested, or a
; higher line is in service at the controller.
virtual_irq_take:
    push ds
    push bx
    push cx
    push dx
    push cs
    pop ds
    xor bx, bx
    mov al, [guest_irq_bit]
    test [virtual_pic_mask], al
    jnz .done
    cmp byte [virtual_pic_service], 0
    jne .done
    cmp byte [virtual_pic_request], 0
    je .done
    call physical_pic_isr
    test al, [guest_irq_priority]
    jnz .done
    mov byte [virtual_pic_request], 0
    mov byte [virtual_pic_delivered], 0
    mov al, [guest_irq_bit]
    mov [virtual_pic_service], al
    inc dword [irq_taken]
    inc bx
.done:
    mov ax, bx
    pop dx
    pop cx
    pop bx
    pop ds
    retf

physical_pic_isr:
    mov dx, 20h
    mov al, 0bh
    call physical_write
    call physical_read
    push ax
    mov al, [physical_pic_read]
    call physical_write
    pop ax
    ret

virtual_pic_read:
    cmp dx, 21h
    je .read
    mov al, [physical_pic_read]
    call physical_write
.read:
    call physical_read
    cmp dx, 21h
    je .mask
    and al, [pic_visible_bits]
    cmp byte [physical_pic_read], 0bh
    je .service
    or al, [virtual_pic_request]
    ret
.service:
    or al, [virtual_pic_service]
    ret
.mask:
    and al, [pic_visible_bits]
    mov ah, [pic_visible_bits]
    not ah
    and ah, [virtual_pic_mask]
    or al, ah
    ret

virtual_pic_write:
    cmp dx, 21h
    je .mask
    ; ICW1 starts an initialisation, which is not emulated. The ICW2 to ICW4
    ; bytes that follow on port 21h are not mask writes: count them off.
    test al, 10h
    jz .not_icw1
    mov ah, 1
    test al, 2
    jnz .single
    inc ah
.single:
    test al, 1
    jz .icw_counted
    inc ah
.icw_counted:
    mov [pic_icw_pending], ah
    jmp .fault
.not_icw1:
    ; OCW3 (bits 7 and 4 clear, bit 3 set): bit 1 with bit 0 selects what
    ; port 20h reads, 0Ah the request register, 0Bh the in-service register;
    ; bit 2 polls; bits 6:5 set or clear special mask mode, which the
    ; physical controller keeps for itself as it serves the mixer as well;
    ; with none of them it does nothing (8259A data sheet, OCW3).
    mov ah, al
    and ah, 98h
    cmp ah, 08h
    jne .ocw2
    test al, 4
    jz .read_select
    ; Poll: the next read answers like the request register.
    mov al, 0ah
    jmp .select
.read_select:
    test al, 2
    jz .done
    and al, 0bh
    jmp .select
.ocw2:
    ; OCW2, by bits 6:5 (bit 7 adds a rotation, which the physical
    ; controller keeps for itself, as it does the automatic rotation, 00,
    ; and set priority, 10 with bit 7; 10 alone does nothing): 01 the
    ; non-specific EOI, whatever the level bits, which count only in the
    ; specific form, 11.
    mov ah, al
    and ah, 60h
    cmp ah, 20h
    jne .not_plain_eoi
    mov al, 20h
    jmp .eoi
.not_plain_eoi:
    cmp ah, 60h
    jne .done
    and al, 7fh
    mov ah, 60h
.not_eoi:
    cmp al, [guest_eoi]
    je .guest_eoi
    cmp ah, 60h
    je .physical
.fault:
%ifdef MOUNTED_AUDIO
    mov byte [fault], 5
%else
    mov byte [fault], 1
%endif
.done:
    ret
.select:
    mov [physical_pic_read], al
.physical:
    call physical_write
    ret
; OCW2 on port 20h with an EOI code, from a real-mode game's write through
; port_callback or forwarded by the host (dpmi_pic_eoi .plain_forward decides
; the cases with nothing virtual to end before it calls down). AL=the command
; byte, DX=20h, DS=CS. .guest_eoi below is the specific EOI for the guest
; line and shares .virtual_eoi and .physical with this path.
.eoi:
%ifdef RESIDENT_AUDIO
    ; The DPMI host ended this interrupt at the controller before it ran the
    ; real-mode handler, so the handler's EOI is spent (CDF5).
    cmp byte [sb_stray_eoi], 0
    je .eoi_live
    mov byte [sb_stray_eoi], 0
    inc dword [irq_stray]
    ret
.eoi_live:
%endif
    ; With no virtual interrupt in service the EOI is the hardware's. A
    ; non-specific EOI with nothing in service does nothing, so it can go
    ; through without a look at the in-service register.
    cmp byte [virtual_pic_service], 0
    je .physical_eoi
    ; A virtual interrupt taken but not yet delivered is not in service for
    ; the game: an EOI from another handler meanwhile is not its own. The
    ; DPMI host ends the IRQs it queues at the controller before their
    ; handlers run, so the in-service register cannot tell that case apart.
    cmp byte [virtual_pic_delivered], 0
    je .physical_eoi
    call physical_pic_isr
    test al, [guest_irq_higher]
    jnz .physical_eoi
.virtual_eoi:
    mov byte [virtual_pic_service], 0
    mov byte [virtual_pic_delivered], 0
    inc dword [irq_ended]
    ret
.guest_eoi:
    ; A specific EOI for the guest line ends the virtual interrupt once it
    ; is delivered; before that it is the hardware line's.
    cmp byte [virtual_pic_delivered], 0
    je .physical
    jmp .virtual_eoi
.physical_eoi:
    mov al, 20h
    jmp .physical
.mask:
    cmp byte [pic_icw_pending], 0
    je .mask_write
    dec byte [pic_icw_pending]
    ret
.mask_write:
    mov [virtual_pic_mask], al
    mov ah, [guest_irq_bit]
    not ah
    and al, ah
    mov ah, [physical_pic_initial]
    and ah, [guest_irq_bit]
    or al, ah
    mov ah, [physical_irq_bit]
    not ah
    and al, ah
    or al, [audio_irq_mask_bit]
    jmp .physical

virtual_dsp_irq db 0
f2h_last dd 0
f2h_calls dd 0
f2h_held db 0
f2h_seen db 0
virtual_pic_mask db 0ffh
; ICW bytes still to come on port 21h after an ICW1.
pic_icw_pending db 0
; The interrupt counters UCDD -STATUS prints (driver.asm, control 10): the
; virtual interrupt's whole life, so a fault shows on the PC with the
; release build (an EOI swallowed as the game's, a handler never reached,
; blocks ending unacknowledged). Dwords in this order, from installation or
; the last UCDD -STATUS -RESET. Each count is one INC where it happens.
align 4
irq_counters:
irq_periods_base dd 0  ; [periods] at the reset (reported: the periods since)
irq_spurious dd 0      ; IRQ 7 entries with nothing in service (sb16.asm)
irq_late_half dd 0     ; output periods refilled more than half a period
                       ; after their interrupt was due (sb16.asm)
irq_late_whole dd 0    ; refilled a whole period late: the card had already
                       ; played the old half (sb16.asm); two periods or
                       ; more alias and show only against irq_ticks
irq_ticks dd 0         ; the BIOS timer tick at the start (reported: the
                       ; ticks since, 18.2 a second: driver.asm)
irq_raised dd 0        ; requests to the virtual PIC: an edge on the line
irq_taken dd 0         ; virtual interrupts given to a handler
irq_ended dd 0         ; virtual interrupts ended by the game's EOI
irq_overrun dd 0       ; block ends with the line still high (unacknowledged)
irq_reraised dd 0      ; requests raised again after a whole period with
                       ; nothing acknowledged, requested or in service
irq_stray dd 0         ; EOIs swallowed as stray: the DPMI host had ended
                       ; the IRQ at the controller (here and host/pic.asm);
                       ; last, as the host finds it 4 bytes before
                       ; sb_stray_eoi (cdf5_count_check)
IRQ_COUNTERS equ ($-irq_counters)/4
%ifdef RESIDENT_AUDIO
sb_stray_eoi db 0
%endif
virtual_pic_request db 0
virtual_pic_service db 0
virtual_block_seen dd 0
physical_pic_initial db 0ffh
physical_irq_bit db 20h
pic_visible_bits db 0dfh
physical_pic_read db 0ah
; Set when the virtual interrupt reaches the game's handler, cleared by its
; EOI: 1 from the DPMI host's delivery, 2 from the driver's own (the real-mode
; jump in audio_irq, the trap exit) and once audio_irq_reflected has passed
; a host delivery through the guest vector on to the game's handler.
virtual_pic_delivered db 0
; Periods during which a signalled interrupt sat unacknowledged with nothing
; requested or in service.
virtual_irq_stale db 0
DRV_PROFILE_DATA


; CDF2 exposes these offsets to the protected host.
%ifdef RESIDENT_AUDIO
; The host counts the stray EOIs it swallows at the CDF5 byte less 4.
cdf5_count_check equ 1 / ((sb_stray_eoi-irq_stray) = 4)
%endif
cdf2_service_check equ 1 / ((virtual_pic_service-virtual_pic_request) = 1)
cdf2_visible_check equ 1 / ((pic_visible_bits-virtual_pic_request) = 8)
cdf2_mode_check equ 1 / ((physical_pic_read-virtual_pic_request) = 9)
