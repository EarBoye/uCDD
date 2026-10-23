; SPDX-FileCopyrightText: 2026 vorvek
; SPDX-License-Identifier: GPL-3.0-only

%include "audio/sb_state.inc"

; Configuration selects the physical card resources.
physical_read:
%ifdef DIRECT_OUTPUT
    in al, dx
%else
    push bx
    push cx
    mov ax, 1a00h
    call far [qpi]
    mov al, bl
    pop cx
    pop bx
%endif
    ret
physical_write:
%ifdef DIRECT_OUTPUT
    out dx, al
%else
    push ax
    push bx
    push cx
    mov bl, al
    mov ax, 1a01h
    call far [qpi]
    pop cx
    pop bx
    pop ax
%endif
    ret
dsp_write:
    cmp byte [dsp_failed], 0
    jne .failed
    push ax
    push cx
    mov cx, 65535
    mov dx, [sb_base]
    add dx, 0ch
.wait:
    call physical_read
    test al, 80h
    jz .ready
    loop .wait
%ifdef MOUNTED_AUDIO
    mov byte [fault], 4
%else
    mov byte [fault], 1
%endif
    mov byte [dsp_failed], 1
    mov dx, 0d4h
    cmp byte [sound_card], 0
    je .mask
    mov dx, 0ah
.mask:
    mov al, [dma_channel]
    or al, 4
    call physical_write
    pop cx
    pop ax
.failed:
    stc
    ret
.ready:
    pop cx
    pop ax
    call physical_write
    clc
    ret
physical_reset:
    mov al, 1
; AL=reset value. The ESS extended mode sets bit 1 to clear the FIFO.
.value:
    mov byte [dsp_failed], 0
    mov dx, [sb_base]
    add dx, 6
    call physical_write
    mov cx, 64
.delay:
    call physical_read
    loop .delay
    xor al, al
    call physical_write
    mov cx, 65535
.ready:
    mov dx, [sb_base]
    add dx, 0eh
    call physical_read
    test al, 80h
    jnz .data
    loop .ready
    stc
    ret
.data:
    mov dx, [sb_base]
    add dx, 0ah
    call physical_read
    cmp al, 0aah
    je .success
    loop .ready
    stc
    ret
.success:
    clc
    ret
; Models 4 and 5 are the ESS AudioDrive in extended mode, on the WSS ring.
; Callers that size the ring run this before they read the model.
sb_model:
    mov al, [sound_card]
    sub al, 4
    jb .done
%ifdef RESIDENT_AUDIO
    ; Model 5 played at half rate. The author's mixer, merged on 24 Oct 2026,
    ; does not make half-rate frames yet (ISSUES.md UPA6), so model 5 plays
    ; at full rate as model 4 until it does: ess_half stays 0.
%endif
    mov byte [sound_card], 2
    mov byte [ess_native], 1
.done:
    ret
sb_start:
    call sb_model
    cmp byte [sound_card], 2
    je wss_start
    cmp byte [sound_card], 0
%ifdef RESIDENT_AUDIO
    jne pro_start
%elifdef DIRECT_OUTPUT
    jne pro_start
%else
    jne .fail
%endif
    movzx bx, byte [sb_dma16]
    mov al, [dma_pages+bx-5]
    mov [dma_page_port], al
    mov ax, bx
    sub ax, 4
    mov [dma_channel], al
    shl ax, 2
    add ax, 0c0h
    mov [dma_address_port], ax
    add ax, 2
    mov [dma_count_port], ax
    call physical_reset
    jc .fail
    mov si, mixer_registers
    mov di, mixer_saved
    mov cx, 6
.mixer:
    mov dx, [sb_base]
    add dx, 4
    lodsb
    call physical_write
    inc dx
    call physical_read
    mov [di], al
    inc di
    ; Registers 34h and 35h hold the FM level, which fm_init sets below.
    ; Registers 30h and 31h hold the master volume.
    cmp cx, 4
    ja .next
    mov al, 0f8h
    cmp cx, 2
    jbe .level
    mov al, [master_register]
.level:
    call physical_write
.next:
    loop .mixer
%ifdef RESIDENT_AUDIO
    mov al, [mixer_saved]
    mov ah, [mixer_saved+1]
    call fm_init
%endif
    mov al, [sb_irq]
    add al, 8
    mov ah, 35h
    int 21h
    mov [old_irq], bx
    mov [old_irq+2], es
    mov dx, audio_irq
    mov al, [sb_irq]
    add al, 8
    mov ah, 25h
    int 21h
    mov dx, 21h
    call physical_read
    mov [saved_pic], al
    mov cl, [sb_irq]
    mov ah, 1
    shl ah, cl
    not ah
    and al, ah
    call physical_write
    cli
    mov al, [dma_channel]
    or al, 4
    mov dx, 0d4h
    call physical_write
    xor al, al
    mov dx, 0d8h
    call physical_write
    movzx eax, word [output_segment]
    shl eax, 4
    mov ebx, eax
    shr eax, 1
    mov dx, [dma_address_port]
    call physical_write
    mov al, ah
    call physical_write
    shr ebx, 16
    mov al, bl
    mov dx, [dma_page_port]
    call physical_write
    mov al, (RING_WORDS-1) & 0ffh
    mov dx, [dma_count_port]
    call physical_write
    mov al, (RING_WORDS-1) >> 8
    call physical_write
    mov al, [dma_channel]
    or al, 58h
    mov dx, 0d6h
    call physical_write
    mov al, [dma_channel]
    mov dx, 0d4h
    call physical_write
    sti
    mov byte [sb_running], 1
    mov al, 41h
    call dsp_write
    mov al, 0ach
    call dsp_write
    mov al, 44h
    call dsp_write
    mov al, 0b6h
    call dsp_write
    mov al, 30h
    call dsp_write
    mov al, (PERIOD_FRAMES*2-1) & 0ffh
    call dsp_write
    mov al, (PERIOD_FRAMES*2-1) >> 8
    call dsp_write
    jc .start_failed
    clc
    ret
.start_failed:
    call sb_stop
.fail:
    stc
    ret
sb_stop:
    cmp byte [sound_card], 2
    je wss_stop
    test byte [sound_card], 1
    jnz pro_stop
    cmp byte [sb_running], 0
    je .done
    mov al, 0d5h
    call dsp_write
    mov al, [dma_channel]
    or al, 4
    mov dx, 0d4h
    call physical_write
    mov dx, [sb_base]
    add dx, 0fh
    call physical_read
    ; Leave the DSP reset, not paused in auto-initialize mode.
    call physical_reset
    mov al, [saved_pic]
    mov dx, 21h
    call physical_write
    push ds
    mov al, [sb_irq]
    add al, 8
    lds dx, [old_irq]
    mov ah, 25h
    int 21h
    pop ds
    mov si, mixer_registers
    mov di, mixer_saved
    mov cx, 6
.mixer:
    mov dx, [sb_base]
    add dx, 4
    lodsb
    call physical_write
    inc dx
    mov al, [di]
    inc di
    call physical_write
    loop .mixer
    mov byte [sb_running], 0
.done:
    ret
audio_irq:
    push ds
    push ax
    mov ax, cs
    mov ds, ax
    cmp byte [audio_irq_busy], 0
    jne .nested
    ; IRQ 7 is where the 8259 delivers a spurious interrupt: a request that
    ; went away before it was acknowledged. Its in-service bit stays clear,
    ; and it takes no end-of-interrupt.
    cmp byte [sb_irq], 7
    jne .owned_irq
    push dx
    mov dx, 20h
    mov al, 0bh
    call physical_write
    call physical_read
    mov ah, al
%ifdef VIRTUAL_IRQ
    ; Put back the read register the game selected.
    mov al, [physical_pic_read]
%else
    mov al, 0ah
%endif
    call physical_write
    pop dx
    test ah, 80h
    jz .spurious
    ; The check above used AX: the stack switch below needs CS in it.
    mov ax, cs
; Joined from the entry (card not on IRQ 7) and from the IRQ 7 check above.
; On both paths: interrupts off, DS=CS, AX=CS, the interrupted code's SS:SP
; still loaded with its DS and AX pushed on it, DX as the interrupted code
; left it. Nothing before this label may leave anything else in AX.
.owned_irq:
    mov byte [audio_irq_busy], 1
    mov [irq_ss], ss
    mov [irq_sp], sp
    mov ss, ax
    mov sp, irq_stack_top
    pushad
    push es
    push fs
    cld
    DRV_TSC_BEGIN pirq
    cmp byte [sound_card], 0
    je .sb16
    call audio_irq_mask
    cmp byte [sound_card], 2
    je .wss
    jmp .pro
.sb16:
    ; Mixer 82h names the card's sources on the line (Creative's Hardware
    ; Programming Guide, "Sharing of Interrupts"): bit 1 the 16-bit DMA
    ; that plays the output, bit 2 the MPU-401, bit 0 the 8-bit DMA and
    ; SB-MIDI. A reflected game IRQ shows none of them and must not advance
    ; the physical output buffer. The mask, the 82h read and, with the
    ; MPU-401 quiet, the 16-bit acknowledge come in one call
    ; (audio_irq_enter16); AH says whether 2xFh was read.
    call audio_irq_enter16
%ifdef VIRTUAL_IRQ
    test al, 4
    jz .no_mpu
    call sb16_mpu_irq
.no_mpu:
%endif
    test al, 2
    jz .not_output16
    test ah, ah
    jz .output16
    jmp .acknowledged
.not_output16:
    test al, 5
    jz .unowned
    ; The MPU-401 alone: the game reads its byte at 330h, which ends the
    ; request; nothing is mixed. The line is the card's, so the interrupt
    ; ends here: the vector from before the driver is the BIOS's on most
    ; machines, and its handler masks the IRQ it does not know, which
    ; stopped the output (Settlers II with General MIDI, 16 Oct 2026).
    test al, 1
    jz .eoi
    ; The 8-bit DMA's request: the driver plays no 8-bit DMA on the SB16 and
    ; the game's DSP commands go to the virtual card, so it is a stray. The
    ; 2xEh read acknowledges it.
    mov dx, [sb_base]
    add dx, 0eh
    call physical_read
    jmp .eoi
.output16:
    mov dx, [sb_base]
    add dx, 0fh
    call physical_read
; Joined from the SB16 path above (acknowledged in audio_irq_enter16 or at
; .output16) and from .pro_audio, .wss and .codec below, once the card's own
; interrupt is acknowledged. On every path: the handler's
; stack with PUSHAD, ES and FS saved, DS=CS, DF clear, the IRQ masked at the
; controller; ES and DI are not set yet; EBX holds nothing needed after here
; (the lateness check below uses it).
.acknowledged:
%ifdef RESIDENT_AUDIO
    call sb_patch
%endif
%ifdef MOUNTED_AUDIO
    ; The DMA position gives the period that plays, also after a late IRQ.
    call output_clock
    ; How late this interrupt is: on time, the clock has just entered the
    ; period after the last interrupt's. Past half of it: late by over half
    ; a period. In the next one: a whole period late (mix_catch_up mixes the
    ; periods the ring still holds ahead; the ones the card has passed are
    ; lost). EBX is free on every path into here.
    mov ebx, eax
    shr ebx, OUTPUT_SHIFT
    ; [periods] still names the period of the last interrupt: on time, the
    ; clock is one period past it.
    dec ebx
    cmp ebx, [periods]
    jb .late_done
    ja .late_whole
    test eax, PERIOD_FRAMES/2
    jz .late_done
    inc dword [irq_late_half]
    jmp .late_done
.late_whole:
    inc dword [irq_late_whole]
.late_done:
    shr eax, OUTPUT_SHIFT
    mov [periods], eax
%else
    inc dword [periods]
%endif
%ifdef ESS_FIFO_MODEL
    ; The virtual ESS's DAC ring must reach the output clock before the next
    ; period reads it (ess_fifo.asm: the mixer reads ESS_DELAY_FRAMES behind).
    call ess_fifo_service
%endif
    DRV_TSC_BEGIN mix
    call mix_catch_up
    DRV_TSC_END mix
%ifdef VIRTUAL_IRQ
    call f2h_service
%ifdef RESIDENT_AUDIO
    cmp byte [sb_single_hold], 0
    je .tick
    cmp byte [sb_single_hold], 2
    jne .held
    ; An interrupt that was pending when the start write returned, or that
    ; was taken inside it, comes with no time passed. A later one can signal.
    mov eax, [periods]
    shl eax, OUTPUT_SHIFT
    sub eax, [sb_hold_clock]
    cmp eax, SB_HOLD_FRAMES
    jl .ticked
    mov byte [sb_single_hold], 0
    jmp .tick
.held:
    mov byte [sb_single_hold], 0
    jmp .ticked
.tick:
%endif
    call virtual_irq_tick
%ifdef RESIDENT_AUDIO
.ticked:
%endif
%ifdef OWN_HOST
    mov byte [cd_refill_pending], 0
    cmp byte [cd_started], 1
    jne .refill_ready
    cmp byte [cd_error], 0
    jne .refill_ready
    cmp dword [cd_remaining], 0
    je .refill_ready
    mov eax, [cd_produced]
    sub eax, [cd_consumed]
    ; Above the line where the refill cancels on arrival (background.asm
    ; cd_deferred_refill: the queue within 64 KB of full), asking would cost
    ; the host a bridge for nothing (ISSUES.md IRQCOST): ask nothing. The
    ; queue drains a period at a time, so a later period asks well before
    ; it runs low; the urgent line is far below this one.
    cmp eax, CD_REFILL_CANCEL
    ja .refill_ready
    mov byte [cd_refill_pending], 1
    cmp eax, CD_REFILL_URGENT
    jae .refill_ready
    mov byte [cd_refill_pending], 2
.refill_ready:
    ; The host refills in protected mode. A client that stays in real mode
    ; starves it, and this IRQ then refills.
    cmp byte [cd_refill_pending], 0
    jne .host_wait
    mov word [cd_host_missed], 0
    jmp .host_checked
.host_wait:
    cmp word [cd_host_missed], CD_HOST_STARVED
    jae .host_starved
    inc word [cd_host_missed]
    jmp .host_checked
.host_starved:
    mov byte [cd_irq_refill], 1
.host_checked:
    cmp word [cd_timer_missed], CD_TIMER_STARVED
    jae .timer_starved
    inc word [cd_timer_missed]
    jmp .timer_checked
.timer_starved:
    cmp byte [cd_refill_pending], 2
    jne .timer_checked
    mov byte [cd_irq_refill], 1
.timer_checked:
%endif
%endif
; Joined from the mixing paths through .refill_ready, from .pro (the SB Pro
; priming interrupt, nothing mixed) and from the SB16 check (the MPU-401 or
; a stray 8-bit request, nothing mixed). On all: the handler's stack as at
; .acknowledged, DS=CS, the IRQ masked; AL and DX are free.
.eoi:
    DRV_TSC_END pirq
    ; A run from sb16_line_check has no interrupt in service to end, and
    ; the game's interrupt waits for a trap exit or the next output one.
    cmp byte [audio_irq_polled], 0
    jne .polled
    ; A specific EOI (the author's 0.9.4): the output interrupt ends even
    ; while the game has another masked.
    mov al, [sb_irq]
    or al, 60h
    mov dx, 20h
    call physical_write
%ifdef OWN_HOST
    call sb_real_irq
    call host_real_pending
%endif
.polled:
    mov byte [audio_irq_polled], 0
    cli
    call audio_irq_unmask
    mov byte [audio_irq_busy], 0
    pop fs
    pop es
    popad
    mov ss, [irq_ss]
    mov sp, [irq_sp]
    pop ax
    pop ds
%ifdef OWN_HOST
    cmp word [cs:host_pending_irqs], 0
    jne host_pending_tail
.tail:
    cmp byte [cs:sb_real_pending], 0
    jne .real_tail
    cmp byte [cs:cd_irq_refill], 0
    jne .refill_tail
%endif
    iret
%ifdef OWN_HOST
.real_tail:
    mov byte [cs:sb_real_pending], 0
    jmp far [cs:sb_real_vector]
.refill_tail:
    ; This IRQ's return frame becomes the refill's frame.
    mov byte [cs:cd_irq_refill], 0
    mov byte [cs:cd_irq_entry], 1
    jmp cd_timer_refill
%endif
.pro:
    cmp byte [pro_priming], 0
    je .pro_audio
    mov byte [pro_priming], 0
    mov dx, [sb_base]
    add dx, 0eh
    call physical_read
    jmp .eoi
.pro_audio:
%ifdef MOUNTED_AUDIO
    call output_clock
    shr eax, OUTPUT_SHIFT
    cmp eax, [periods]
    je .unowned
%endif
    mov dx, [sb_base]
    add dx, 0eh
    call physical_read
    cmp byte [sound_card], 3
    jne .acknowledged
    cmp byte [sb_mono_auto], 0
    jne .acknowledged
    call sb_mono_next
    jmp .acknowledged
.wss:
    cmp byte [ess_native], 0
    je .codec
    ; Bit 0: the extended mode DMA counter overflowed. Reading 2xEh clears it.
    mov dx, [sb_base]
    add dx, 0ch
    call physical_read
    test al, 1
    jz .unowned
    inc dx
    inc dx
    call physical_read
    jmp .acknowledged
.codec:
    mov dx, [sb_base]
    add dx, 6
    call physical_read
    test al, 1
    jz .unowned
    xor al, al
    call physical_write
    jmp .acknowledged
; Joined from the SB16, .pro_audio, .wss and .codec checks when the interrupt
; is another device's on the shared line. The handler's stack as at
; .acknowledged; the card is not acknowledged and nothing is counted, and the
; old handler gets the interrupt with every register as it was.
.unowned:
    cli
    call audio_irq_unmask
    mov byte [audio_irq_busy], 0
    pop fs
    pop es
    popad
    mov ss, [irq_ss]
    mov sp, [irq_sp]
    pop ax
    pop ds
%ifdef OWN_HOST
    call audio_irq_reflected
    jz audio_irq_to_game
%endif
%ifdef VIRTUAL_IRQ
    pushf
    call far [cs:old_irq]
    ; The guest does not see this IRQ in service. End it if its handler did not.
    push ds
    push ax
    push dx
    mov ax, cs
    mov ds, ax
    call physical_pic_isr
    test al, [physical_irq_bit]
    jz .ended
    mov al, [sb_irq]
    or al, 60h
    ; DX=20h after physical_pic_isr.
    call physical_write
.ended:
    pop dx
    pop ax
    pop ds
    iret
%else
    jmp far [cs:old_irq]
%endif
%ifdef OWN_HOST
audio_irq_to_game:
    jmp far [cs:sb_game_vector]
%endif

audio_irq.nested:
    pop ax
    pop ds
    jmp far [cs:old_irq]
audio_irq.spurious:
    pop ax
    pop ds
%ifdef OWN_HOST
    call audio_irq_reflected
    jz audio_irq_to_game
%endif
%ifdef VIRTUAL_IRQ
    inc dword [cs:irq_spurious]
%endif
    iret

%ifdef OWN_HOST
; The DPMI host delivers the virtual interrupt to a real-mode handler by
; running the guest vector (dpmi.asm, .real_irq). When the guest IRQ is the
; card's own, that vector is this handler and the game's is sb_game_vector:
; with no physical interrupt behind the entry it would end as spurious (IRQ 7)
; or go to the vector before the driver's, and the game's handler never ran
; (the Miles ESS driver in Theme Hospital, IRQ 7 on both). The host's fresh
; delivered mark (1) tells it apart; it becomes 2, still set for the EOI
; credit (virtual_pic_write), so a later physical entry is not taken for it.
; ZF set: go to the game's handler. Flags only; called with DS unknown.
audio_irq_reflected:
    push ax
    cmp byte [cs:virtual_pic_delivered], 1
    jne .done
    mov al, [cs:guest_irq]
    cmp al, [cs:sb_irq]
    jne .done
    cmp word [cs:sb_game_vector+2], 0
    je .not_set
    mov byte [cs:virtual_pic_delivered], 2
    cmp al, al
    jmp .done
.not_set:
    or al, 1
.done:
    pop ax
    ret
%endif

%ifdef VIRTUAL_IRQ
; The output's interrupt for sb16_line_check: the handler run as if the
; card had interrupted, from code with interrupts off and DS=CS. The frame
; is an interrupt's (flags, CS, IP), so the handler's IRET returns here.
audio_irq_poll:
    pushf
    push cs
    call .frame
    ret
.frame:
    push ds
    push ax
    mov ax, cs
    mov ds, ax
    mov byte [audio_irq_polled], 1
    jmp audio_irq.owned_irq

; Called from audio_irq with AL=mixer 82h, which has bit 2 set: the
; MPU-401's request on the SB16's line. AX is kept.
;
; On the virtual SB16 the request is the virtual card's too, as on the real
; card, where the MPU-401 shares the line and 82h tells the game's handler
; (virtual_mpu_refresh keeps the virtual bit as the card has it). The other
; virtual models have no MPU-401 on their line: the game polls it.
;
; The real line stays high until the game reads 330h. An output interrupt
; that comes meanwhile raises no edge at the 8259 and would be lost, so
; sb16_line_check looks for one while sb16_line_held is set.
sb16_mpu_irq:
    push ax
    mov byte [sb16_line_held], 1
    cmp byte [virtual_model], 0
    jne .done
    mov al, 4
    call virtual_dsp_raise_line
.done:
    pop ax
    ret

; From cd_timer and port_callback, with interrupts off and DS=CS. While the
; MPU-401 may hold the SB16's line (sb16_line_held), an output request at the
; card (82h bit 1) with no request and no service for it at the controller
; is one whose edge was lost: run the output for it. Every register is kept.
sb16_line_check:
    cmp byte [sb16_line_held], 0
    jne .held
    ret
.held:
    pushad
    cmp byte [audio_irq_busy], 0
    jne .done
    cmp byte [sb_running], 0
    je .done
    cmp byte [sound_card], 0
    jne .done
    mov dx, [sb_base]
    add dx, 4
    mov al, 82h
    call physical_write
    inc dx
    call physical_read
    test al, 4
    jnz .mpu_waits
    mov byte [sb16_line_held], 0
.mpu_waits:
    test al, 2
    jz .done
    ; The request (IRR) and service (ISR) registers, then the read register
    ; the game selected back in place.
    mov dx, 20h
    mov al, 0ah
    call physical_write
    call physical_read
    mov bl, al
    mov al, 0bh
    call physical_write
    call physical_read
    or bl, al
    mov al, [physical_pic_read]
    call physical_write
    test bl, [physical_irq_bit]
    jnz .done
    call audio_irq_poll
.done:
    popad
    ret
%endif

; The SB16's interrupt entry: what audio_irq_mask, the mixer 82h read and
; the 16-bit acknowledge do, in that order, as one call into JemmEx's API
; (host_gate 1A21h, ISSUES.md IRQCOST: five trips become one); the
; acknowledge is left for later when the MPU-401's bit is set too. AL =
; mixer 82h, AH = 1 when 2xFh was read. BX, CX and DX changed.
audio_irq_enter16:
%ifdef DIRECT_OUTPUT
    call audio_irq_mask
    mov dx, [sb_base]
    add dx, 4
    mov al, 82h
    call physical_write
    inc dx
    call physical_read
    mov ah, al
    and ah, 6
    cmp ah, 2
    mov ah, 0
    jne .entered
    push ax
    mov dx, [sb_base]
    add dx, 0fh
    call physical_read
    pop ax
    mov ah, 1
.entered:
    ret
%else
    mov cl, [sb_irq]
    mov ah, 1
    shl ah, cl
    mov [audio_irq_mask_bit], ah
    mov cl, ah
    mov dx, [sb_base]
    mov ax, 1a21h
    call far [qpi]
    mov [audio_irq_old_mask], bh
    mov al, bl
    mov ah, ch
    ret
%endif

audio_irq_mask:
    mov dx, 21h
    call physical_read
    mov [audio_irq_old_mask], al
    mov cl, [sb_irq]
    mov ah, 1
    shl ah, cl
    mov [audio_irq_mask_bit], ah
    or al, ah
    call physical_write
    ret

audio_irq_unmask:
    ; Nothing else writes the mask while the handler runs with interrupts
    ; off, so the value read at the mask goes back as it was.
    mov dx, 21h
    mov al, [audio_irq_old_mask]
    mov byte [audio_irq_mask_bit], 0
    call physical_write
    ret

; Mix every period from mix_period to the last one the ring holds ahead of
; the period that plays. Periods the DMA passed before their mix are lost.
mix_catch_up:
    mov eax, [periods]
    cmp [mix_period], eax
    ja .ahead
    inc eax
    mov [mix_period], eax
.ahead:
    mov eax, [periods]
    add eax, RING_PERIODS
    cmp [mix_period], eax
    jae .done
    call mix_next
    jmp .ahead
.done:
    ret

; Mix period mix_period into its ring slot.
mix_next:
    mov eax, [mix_period]
    shl eax, OUTPUT_SHIFT
    call ring_offset
    mov di, ax
    mov es, [output_segment]
    call mix_half
    inc dword [mix_period]
    ret

; Mix the whole ring before the output starts.
mix_fill:
    mov dword [periods], 0
    mov dword [mix_period], 0
.next:
    call mix_next
    cmp dword [mix_period], RING_PERIODS
    jb .next
    ret

; EAX: an output frame. Returns AX: its byte offset in the output ring.
ring_offset:
    push edx
    push ecx
    xor edx, edx
    mov ecx, RING_FRAMES
    div ecx
    mov eax, edx
    shl ax, 2
    test byte [sound_card], 1
    jz .done
    shr ax, 2
    and ax, 0fffeh
    cmp byte [sound_card], 3
    jne .done
    shr ax, 1
.done:
    ; The ESS at half rate plays two bytes an output frame.
    mov cl, [ess_half]
    shr ax, cl
    pop ecx
    pop edx
    ret

; AX: a block of two ring sizes. Returns AX: the ring segment, which does not
; cross a 64 KiB page, and DX: the other ring size.
ring_place:
    mov cx, RING_PARAS
    cmp byte [sound_card], 3
    jne .pro
    shr cx, 1
.pro:
    test byte [sound_card], 1
    jz .size_ready
    shr cx, 2
.size_ready:
    cmp byte [ess_half], 0
    je .sized
    shr cx, 1
.sized:
    mov dx, ax
    add dx, cx
    mov bx, ax
    and bx, 0fffh
    add bx, cx
    cmp bx, 1000h
    jbe .done
    xchg ax, dx
.done:
    ret

audio_irq_old_mask db 0
; Set while the MPU-401 may hold the SB16's line high (sb16_mpu_irq).
sb16_line_held db 0
; Set for a handler run from sb16_line_check (audio_irq_poll).
audio_irq_polled db 0
old_irq dd 0
dma_pages db 8bh,89h,8ah
dma_channel db 1
dma_page_port dw 8bh
dma_address_port dw 0c4h
dma_count_port dw 0c6h
irq_ss dw 0
irq_sp dw 0
mix_period dd 0
periods dd 0
saved_pic db 0
sb_running db 0
dsp_failed db 0
mixer_registers db 34h,35h,30h,31h,32h,33h
mixer_saved times 6 db 0

%include "audio/wss_output.asm"
%include "audio/pro_output.asm"
times 1024 db 0
irq_stack_top:
