; SPDX-FileCopyrightText: 2026 vorvek
; SPDX-License-Identifier: GPL-3.0-only

audio_activate:
%ifndef OWN_HOST
    mov word [audio_error_text], dpmi_host_message
    mov ax, 1687h
    int 2fh
    test ax, ax
    jnz .bad
    test bl, 1
    jz .bad
%endif
    mov word [audio_error_text], port_trap_missing_message
    call host_install
    jc .bad
    mov eax, [host_api_entry]
    mov [qpi], eax
    mov word [audio_error_text], memory_control_message
    call cd_memory_low
    jc .cleanup
    call sb_model
    ; The part of the ring the card plays: all of it for 16-bit output, a
    ; quarter for the SB Pro, an eighth for the SB 2.0, half for the ESS at
    ; half rate. Always a power of two.
    mov bx, RING_PARAS
    cmp byte [sound_card], 3
    jne .pro_size
    shr bx, 1
.pro_size:
    test byte [sound_card], 1
    jz .half_size
    shr bx, 2
.half_size:
    mov cl, [ess_half]
    shr bx, cl
    mov word [audio_error_text], dma_memory_message
    push bx
    ; The SB Pro start plays one byte from just past the ring (pro_start).
    cmp byte [sound_card], 1
    jne .allocate
    inc bx
.allocate:
    mov ah, 48h
    int 21h
    pop bx
    jc .cleanup
    ; DMA cannot cross a 64 KB page. A block that does is replaced by one of
    ; twice the size, and the ring starts at a multiple of its size in it.
    mov dx, ax
    add dx, bx
    dec dx
    xor dx, ax
    test dh, 0f0h
%ifndef TEST_RING_CROSS
    jz .dma_block
%endif
    mov es, ax
    mov ah, 49h
    int 21h
    jc .cleanup
    push bx
    shl bx, 1
    mov ah, 48h
    int 21h
    pop bx
    jc .cleanup
    mov [output_allocation], ax
    dec bx
    add ax, bx
    not bx
    and ax, bx
    jmp .dma_ready
.dma_block:
    mov [output_allocation], ax
.dma_ready:
    mov [output_segment], ax
    mov word [audio_error_text], cd_half_memory_message
    call cd_half_allocate
    jc .cleanup
    mov word [audio_error_text], cd_work_memory_message
    call cd_work_allocate
    jc .cleanup
%ifdef ESS_FIFO_MODEL
    call ess_dac_allocate
%endif
%ifdef VERIFY_MIX
    call verify_allocate
%endif
    mov word [audio_error_text], xms_memory_message
%ifdef EMS_QUEUE
    cmp byte [memory_mode], 0
    je .queue_message_ready
    mov word [audio_error_text], ems_memory_message
.queue_message_ready:
%endif
    call cd_open
    jc .cleanup
    call virtual_irq_init
    ; The tick the counters start from (UCDD -STATUS: ticks since). Here at
    ; install only: audio_engage calls virtual_irq_init again later.
    push fs
    push 40h
    pop fs
    mov eax, [fs:6ch]
    pop fs
    mov [irq_ticks], eax
    mov ax, [output_segment]
    mov es, ax
    xor di, di
    call mix_half
    call mix_half
    mov word [audio_error_text], port_trap_rejected_message
    call trap_install
    jc .cleanup
    mov word [audio_error_text], sound_card_message
    call sb_start
    jc .cleanup
%ifdef ESS_CARD
    call ess_card_install
%endif
    call fast_dma_set
    call cd_memory_restore
%ifdef OWN_HOST
    mov word [audio_error_text], internal_host_message
    call own_host_install
    jc .cleanup
    call buffers_promote
    mov al, [guest_irq]
    cmp [sb_irq], al
    jne .dos_vector_ready
    mov eax, [old_irq]
    mov [sb_game_vector], eax
    mov ax, 3521h
    int 21h
    mov [sb_old_dos], bx
    mov [sb_old_dos+2], es
    mov dx, sb_dos_vector
    mov ax, 2521h
    int 21h
.dos_vector_ready:
%endif
    mov ax, 3508h
    int 21h
    mov [cd_old_timer], bx
    mov [cd_old_timer+2], es
    mov ax, 3513h
    int 21h
    mov [cd_old_bios], bx
    mov [cd_old_bios+2], es
    mov dx, cd_bios
    mov ax, 2513h
    int 21h
    mov dx, cd_timer
    mov ax, 2508h
    int 21h
    mov byte [cd_background_set], 1
    ; The hotkeys work without an MDM list.
    call mdm_hooks
    ; Nothing is mounted at install: step aside when the pairing allows it.
    call audio_reconsider
    clc
    ret
.cleanup:
    call audio_cleanup
.bad:
    stc
    ret

audio_activate_far:
    call audio_activate
    retf

cd_half_allocate:
    mov bx, CD_HALF_PARAS
    mov ah, 48h
    int 21h
    jc .bad
    mov [cd_half_allocation], ax
    mov [cd_half_segment], ax
    clc
    ret
.bad:
    stc
    ret

cd_work_allocate:
    mov bx, CD_WORK_PARAS
    mov ah, 48h
    int 21h
    jc .bad
    mov [cd_work_allocation], ax
    mov [cd_work_segment], ax
    clc
    ret
.bad:
    stc
    ret

cd_half_promote:
    mov bx, CD_HALF_PARAS
    mov si, cd_half_allocation
    mov di, cd_half_segment
    mov bp, cd_read_address+2
    jmp cd_buffer_promote

cd_work_promote:
    mov bx, CD_WORK_PARAS
    mov si, cd_work_allocation
    mov di, cd_work_segment
    mov bp, cd_write_address+2

cd_buffer_promote:
    push bx
    mov ax, 5800h
    int 21h
    jc .discard
    mov [cd_buffer_strategy], ax
    mov ax, 5802h
    int 21h
    jc .discard
    mov [cd_buffer_umb], al
    mov ax, 5803h
    mov bx, 1
    int 21h
    jc .discard
    ; High only, last fit: at the top of upper memory, so the free space the
    ; install code leaves behind joins the free memory after it (a 19 KB
    ; hole otherwise, 86Box, 16 Oct 2026).
    mov ax, 5801h
    mov bx, 42h
    int 21h
    jc .restore_umb_discard
    pop bx
    mov ah, 48h
    int 21h
    pushf
    push ax
    mov bx, [cd_buffer_strategy]
    mov ax, 5801h
    int 21h
    movzx bx, byte [cd_buffer_umb]
    mov ax, 5803h
    int 21h
    pop ax
    popf
    jc .done
    mov es, [si]
    push ax
    mov ah, 49h
    int 21h
    pop ax
    mov [si], ax
    mov [di], ax
    mov [ds:bp], ax
.done:
    ret
.restore_umb_discard:
    movzx bx, byte [cd_buffer_umb]
    mov ax, 5803h
    int 21h
.discard:
    pop bx
    ret

; The CPU-only buffers to upper memory, the lowest first, stopping at the
; first that does not fit there. Each one moved then joins the free memory
; below it; one moved from between two that stay would be left as a hole
; (3 KB below COMMAND.COM before this order, 86Box, 16 Oct 2026).
buffers_promote:
    mov byte [promote_done], 0
.next:
    mov dx, 0a000h                         ; only conventional ones move
    xor di, di
    mov si, promote_table
    mov cl, 1
.scan:
    cmp word [si], 0
    je .scanned
    test [promote_done], cl
    jnz .skip
    mov bx, [si]
    mov ax, [bx]                           ; the buffer's segment
    test ax, ax
    jz .skip
    cmp ax, dx
    jae .skip
    mov dx, ax
    mov di, si
    mov ch, cl
.skip:
    add si, 4
    shl cl, 1
    jmp .scan
.scanned:
    test di, di
    jz .done
    or [promote_done], ch
    call [di+2]
    jnc .next
.done:
    ret
; Each buffer: its segment variable and its promotion.
promote_table:
    dw cd_half_segment, cd_half_promote
    dw cd_work_segment, cd_work_promote
%ifdef ESS_FIFO_MODEL
    dw ess_dac_segment, ess_dac_promote
%endif
    dw 0
promote_done db 0

%ifdef ESS_FIFO_MODEL
; The virtual ESS's DAC ring: only the CPU reads and writes it, so upper
; memory serves; it was allocated low with the rest, before the host freed
; its loading buffer. Freed low, it joins the free space below it (it is the
; lowest of the driver's blocks at the top of conventional memory).
ess_dac_promote:
    cmp word [ess_dac_segment], 0
    je .done
    mov bx, (ESS_DAC_BYTES+ESS_FIFO_BYTES)/16
    mov si, ess_dac_segment
    mov di, si
    mov bp, ess_dac_spare
    jmp cd_buffer_promote
.done:
    ret
ess_dac_spare dw 0
%endif

cd_buffer_strategy dw 0
cd_buffer_umb db 0

%include "audio/host_jemm_init.asm"
host_install:
    jmp host_jemm_install
%ifdef OWN_HOST
%include "audio/resident_host_init.asm"
%endif
