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
    mov byte [virtual_dsp_irq], 0
    mov byte [virtual_pic_request], 0
    mov dword [virtual_block_seen], 0
    ret

virtual_irq_tick:
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
    je .position
    push eax
    mov eax, [game_block_bytes]
    cmp si, dma16
    jne .single_units
    shr eax, 1
.single_units:
    add eax, [si+DMA_POSITION]
    movzx ecx, word [si+DMA_COUNT]
    inc ecx
    test byte [si+DMA_MODE], 10h
    jz .single_position
    xor edx, edx
    div ecx
    mov eax, edx
.single_position:
    mov [si+DMA_POSITION], eax
    mov bx, [si+DMA_COUNT]
    sub bx, ax
    mov [si+DMA_SNAPSHOT], bx
    cmp bx, 0ffffh
    jne .single_done
    mov byte [si+3], 1
.single_done:
    mov byte [sb_finished], 1
    pop eax
    mov eax, [game_block_bytes]
    jmp .byte_position
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
    cmp byte [virtual_dsp_irq], 0
    jne .signalled
    mov al, [game_irq_bit]
    mov [virtual_dsp_irq], al
.raise:
    mov byte [virtual_irq_stale], 0
    mov al, [guest_irq_bit]
    mov [virtual_pic_request], al
.done:
    ret
.signalled:
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
    jae .raise
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
    or byte [virtual_dsp_irq], 1
    mov al, [guest_irq_bit]
    mov [virtual_pic_request], al
.done:
    ret

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
    cmp al, 0ch
    jne .command
    ; Poll: the next read answers like the request register.
    mov al, 0ah
.command:
    cmp al, 0ah
    je .select
    cmp al, 0bh
    je .select
    mov ah, al
    and ah, 0f8h
    ; Set priority, and special mask mode: the physical controller keeps its
    ; own, as it serves the mixer as well.
    cmp ah, 0c0h
    je .done
    cmp al, 40h
    je .done
    cmp al, 48h
    je .done
    cmp al, 68h
    je .done
    ; The rotate forms end the service like their plain forms.
    and ah, 7fh
    and al, 7fh
    ; 20h to 27h are all the non-specific EOI: the level bits only count in
    ; the specific forms (8259A data sheet, OCW2).
    cmp ah, 20h
    jne .not_eoi
    mov al, 20h
    jmp .eoi
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
virtual_pic_mask db 0ffh
; ICW bytes still to come on port 21h after an ICW1.
pic_icw_pending db 0
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
; Set when the virtual interrupt reaches the game's handler (the real-mode
; jump in audio_irq, or the DPMI host's delivery), cleared by its EOI.
virtual_pic_delivered db 0
; Periods during which a signalled interrupt sat unacknowledged with nothing
; requested or in service.
virtual_irq_stale db 0
DRV_PROFILE_DATA


; CDF2 exposes these offsets to the protected host.
cdf2_service_check equ 1 / ((virtual_pic_service-virtual_pic_request) = 1)
cdf2_visible_check equ 1 / ((pic_visible_bits-virtual_pic_request) = 8)
cdf2_mode_check equ 1 / ((physical_pic_read-virtual_pic_request) = 9)
