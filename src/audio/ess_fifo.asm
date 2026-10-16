; SPDX-FileCopyrightText: 2026 the uCDD contributors
; SPDX-License-Identifier: GPL-3.0-only

; The virtual ESS's FIFO and DAC (docs/ess-fifo.md), for both modes: the
; 256-byte hardware FIFO of Extended Mode and the 64-byte firmware FIFO of
; compatibility mode (SPEC 6), started by audio/ess/card.asm.
;
; ES1868 data sheet: "a 256-byte FIFO is used as an intermediary between the
; ISA bus and the ADC and DAC"; the DMA counter "will be incremented after
; each successful byte is transferred via DMA", reloads from A4h/A5h at each
; overflow and requests an interrupt there when B1h bit 6 is set; in Normal
; Mode the requests stop at the overflow. So the block interrupt and the DMA
; count lead the DAC by the FIFO, and a game may rewrite any byte behind the
; count. Measured on the ES1868F (15 Oct 2026): the block interrupt at
; (bytes - 256) at the frame rate, the FIFO full about 0.96 ms after the
; start, the frame size from B7h.
;
; The virtual DMA copies game bytes into ess_fifo as the chip's DMA would
; move them; the virtual DAC takes one frame per sample-clock tick into
; ess_dac, a ring indexed by time; the mixer reads ess_dac ESS_DELAY_FRAMES
; output frames behind the DAC clock, so it only reads what has passed
; through the FIFO. ess_fifo_service brings the model up to the output
; clock; the trap calls it on every access and the output interrupt on every
; period.

%ifdef ESS_FIFO_MODEL

ESS_FIFO_BYTES equ 256
ESS_COMPAT_FIFO_BYTES equ 64
; The DAC ring holds the output delay (at most two and a half periods) plus
; a period at up to 48 kHz 16-bit stereo: 16 bytes per output frame of the
; period.
ESS_DAC_BYTES equ 16*PERIOD_FRAMES
; The FIFO's copy follows the ring in the same allocation.
ESS_FIFO_OFFSET equ ESS_DAC_BYTES
; The mixer reads the DAC ring two output periods behind the DAC clock; with
; the physical ESS at half rate it needs half a period more (Descent 2 on the
; virtual ESS: 38 clicks/s at two periods, 1.1 at two and a half, the floor).
ESS_DELAY_FRAMES equ 2*PERIOD_FRAMES
ESS_DELAY_HALF_RATE equ 5*PERIOD_FRAMES/2
; Bytes per millisecond the ES1868F's DMA moved into an empty FIFO with the
; single transfer type (B9h=0): half full at 0.5 ms, full at 0.96 ms.
ESS_DMA_PER_MS equ 267

; The write that sets B8h bit 0 with no stream running, after the trap's
; common start has taken the format, rate and DMA channel. DS=CS. CF set: the
; stream stays on the previous path (a DMA buffer the model cannot read).
ess_fifo_start:
    pushad
    push es
    cmp word [game_dma], dma8
    jne .refuse
    cmp word [ess_dac_segment], 0
    je .refuse
%ifdef OWN_HOST
    cmp dword [game_physical], 0
    jne .refuse
%endif
    xor eax, eax
    mov [ess_k], eax
    mov [ess_k0], eax
    mov [ess_q], eax
    mov [ess_d], eax
    mov [ess_seg_start], eax
    mov [ess_idle], eax
    mov [ess_credit], eax
    mov si, dma8
    call ess_fifo_source
    call ess_fifo_block
    mov al, [game_frame_shift]
    mov [ess_shift], al
    ; The mode's FIFO, its block-end interrupt (2xCh bit 0, the counter's,
    ; or bit 2, the processor's), and the compatibility mode's 8-bit stereo,
    ; right channel first (SPEC 6, 7.2, 8.4).
    mov dword [ess_fifo_size], ESS_FIFO_BYTES
    mov byte [ess_block_latch], 1
    mov byte [ess_swap], 0
    cmp byte [ess_compat], 0
    je .mode_ready
    mov dword [ess_fifo_size], ESS_COMPAT_FIFO_BYTES
    mov byte [ess_block_latch], 4
    cmp al, 1
    jne .mode_ready
    test byte [game_format], 1
    jnz .mode_ready
    mov byte [ess_swap], 1
.mode_ready:
    mov eax, [game_step]
    mov [ess_step], eax
    ; The DMA's fill rate in 1/256 bytes per DAC frame.
    mov eax, ESS_DMA_PER_MS*1000*256
    xor edx, edx
    movzx ecx, word [game_rate]
    div ecx
    mov [ess_credit_step], eax
    ; Silence in the game's own format: unsigned 8-bit 80h, unsigned 16-bit
    ; 8000h, signed zero. The DAC ring starts silent.
    mov ax, 8080h
    test byte [game_format], 4
    jz .eight_ready
    xor ax, ax
.eight_ready:
    cmp byte [game_frame_shift], 2
    je .sixteen
    test byte [game_format], 1
    jz .silence_ready
.sixteen:
    mov ax, 8000h
    test byte [game_format], 2
    jnz .silence_ready
    xor ax, ax
.silence_ready:
    mov [ess_silence], ax
    mov es, [ess_dac_segment]
    xor di, di
    mov cx, ESS_DAC_BYTES/2
    cld
    rep stosw
    ; The DAC clock starts now. The mixer's frames count from the same
    ; moment, with nothing pending.
    call output_clock
    mov [ess_t0], eax
    mov [game_started], eax
    mov byte [game_start_pending], 0
    ; The mixer reads the DAC ring as an auto-initialised buffer, starting
    ; ESS_DELAY_FRAMES output frames behind the DAC clock.
    mov ax, [ess_dac_segment]
    mov [game_segment], ax
    mov word [game_offset], 0
    mov cl, [ess_shift]
    mov eax, ESS_DAC_BYTES
    shr eax, cl
    shl eax, 16
    mov [game_limit], eax
    mov ecx, eax
    mov eax, ESS_DELAY_FRAMES
    cmp byte [ess_half], 0
    je .delay
    mov eax, ESS_DELAY_HALF_RATE
.delay:
    mov [ess_delay], eax
    mul dword [ess_step]
    div ecx
    mov eax, ecx
    sub eax, edx
    cmp eax, ecx
    jb .origin
    xor eax, eax
.origin:
    mov [game_origin], eax
    mov dword [game_exit_frame], 0
    mov byte [sb_single], 0
    mov byte [sb_tail_mode], 0
    mov byte [sb_tail_valid], 0
    mov byte [sb_single_hold], 0
    mov byte [ess_dma_on], 1
    mov byte [ess_dma_paused], 0
    mov byte [ess_fifo_on], 1
    pop es
    popad
    clc
    ret
.refuse:
    pop es
    popad
    stc
    ret

; B8h bit 0 set again while the DAC still runs: the DMA resumes into the same
; stream from the 8237's current state and the reloaded counter. DS=CS.
ess_fifo_continue:
    pushad
    mov si, dma8
    call ess_fifo_source
    mov eax, [ess_d]
    mov [ess_seg_start], eax
    call ess_fifo_block
    mov byte [ess_dma_on], 1
    mov byte [ess_dma_paused], 0
    popad
    ret

; SI=dma8: the 8237's buffer for the stream from here on.
ess_fifo_source:
    movzx eax, byte [si+DMA_PAGE]
    shl eax, 16
    movzx ecx, word [si+DMA_ADDRESS]
    add eax, ecx
    mov [ess_src], eax
    movzx eax, word [si+DMA_COUNT]
    inc eax
    mov [ess_src_len], eax
    mov eax, [si+DMA_POSITION]
    mov [ess_src_pos], eax
    mov al, [si+DMA_MODE]
    and al, 10h
    mov [ess_src_wrap], al
    ret

; The block (ess_block_len: A4h/A5h in Extended Mode, the command's count in
; compatibility mode) and the transfer kind (ess_auto), from the current
; position.
ess_fifo_block:
    mov eax, [ess_block_len]
    mov [ess_block], eax
    add eax, [ess_d]
    mov [ess_next_overflow], eax
    mov dword [ess_d_cap], 0ffffffffh
    cmp byte [ess_auto], 0
    jne .ready
    mov [ess_d_cap], eax
.ready:
    ret

; A new rate while the stream plays (A1h or BAh written). EAX=Hz. The DAC
; clock carries on from the frame it has reached; the mixer's read position
; carries on from where the next half starts, at the new step. The frames
; already in the ring (the output delay) play at the new step too.
; DS=CS; all registers kept.
ess_fifo_rate:
    pushad
    push eax
    call ess_fifo_service
    pop eax
    mov [game_rate], ax
    shl eax, 16
    xor edx, edx
    mov ecx, OUTPUT_RATE
    div ecx
    mov edi, eax                           ; the new step
    ; The DAC: frame ess_k at this moment, then the new step.
    mov eax, [ess_k]
    mov [ess_k0], eax
    call output_clock
    mov [ess_t0], eax
    mov [ess_step], edi
    ; The mixer: its position at the next half's first frame becomes the
    ; origin, counted from that frame.
    mov ebx, [sb_dac_frame]
    add ebx, PERIOD_FRAMES
    cmp byte [game_start_pending], 0
    jne .step
    mov eax, ebx
    sub eax, [game_started]
    jbe .step                              ; nothing mixed yet: no rebase
    mul dword [game_step]
    add eax, [game_origin]
    adc edx, 0
    div dword [game_limit]
    mov [game_origin], edx
    mov [game_started], ebx
.step:
    mov [game_step], edi
    ; The DMA's fill rate per DAC frame follows the rate.
    mov eax, ESS_DMA_PER_MS*1000*256
    xor edx, edx
    movzx ecx, word [game_rate]
    div ecx
    mov [ess_credit_step], eax
    popad
    ret

; B8h bit 2 changed while the DMA runs (SPEC 8.2 step 8). AL=1: auto-
; initialise on past the current block; 0: the requests stop at its
; overflow, as a normal-mode block's do. DS=CS.
ess_fifo_kind:
    mov [ess_auto], al
    mov dword [ess_d_cap], 0ffffffffh
    test al, al
    jnz .done
    push eax
    mov eax, [ess_next_overflow]
    mov [ess_d_cap], eax
    pop eax
.done:
    ret

; D0h: the DMA pauses where it is; the DAC plays out the FIFO (data sheet,
; Table 10). D4h continues it, the counter and the block unchanged. Only a
; running DMA pauses.
ess_fifo_pause:
    cmp byte [ess_dma_on], 0
    je .done
    mov byte [ess_dma_on], 0
    mov byte [ess_dma_paused], 1
.done:
    ret
ess_fifo_unpause:
    cmp byte [ess_dma_paused], 0
    je .done
    mov byte [ess_dma_paused], 0
    mov byte [ess_dma_on], 1
.done:
    ret

; B8h bit 0 cleared: the DMA stops; the DAC plays out the FIFO.
ess_fifo_stop_dma:
    mov byte [ess_dma_on], 0
    mov byte [ess_dma_paused], 0
    call ess_fifo_position
    ret

; At install: the DAC ring, when the virtual card is the ESS. A failed
; allocation only leaves the model off. DS=CS.
ess_dac_allocate:
    cmp byte [virtual_model], 4
    jne .done
    mov bx, (ESS_DAC_BYTES+ESS_FIFO_BYTES)/16
    mov ah, 48h
    int 21h
    jc .done
    mov [ess_dac_segment], ax
.done:
    ret

; At removal: the DAC ring back to DOS. DS=CS.
ess_dac_free:
    cmp word [ess_dac_segment], 0
    je .done
    push es
    mov es, [ess_dac_segment]
    mov ah, 49h
    int 21h
    pop es
    mov word [ess_dac_segment], 0
.done:
    ret

; 2x6h bit 1: the FIFO emptied (SPEC 3).
ess_fifo_flush:
    push eax
    mov eax, [ess_d]
    mov [ess_q], eax
    pop eax
    ret

; A software reset ends the stream.
ess_fifo_reset:
    mov byte [ess_fifo_on], 0
    mov byte [ess_dma_on], 0
    mov byte [ess_dma_paused], 0
    mov byte [ess_status_latch], 0
    ret

; Bring the model up to the output clock. DS=CS; all registers kept.
ess_fifo_service:
    call ess_card_service
    cmp byte [ess_fifo_on], 0
    jne .run
    ret
.run:
    pushad
    push fs
    call output_clock
    sub eax, [ess_t0]
    jns .elapsed
    xor eax, eax
.elapsed:
    mul dword [ess_step]
    shrd eax, edx, 16
    add eax, [ess_k0]
    mov [ess_k_target], eax
    mov byte [ess_raise], 0
.frame:
    ; Each sample clock the DAC takes a frame, and the DMA refills the FIFO
    ; behind it within microseconds: between ticks the FIFO reads full, as
    ; the ES1868F's 2xCh does.
    mov eax, [ess_k]
    cmp eax, [ess_k_target]
    jae .frames_done
    call ess_dac_frame
    cmp byte [ess_dma_on], 0
    je .next
    ; B2h bit 6 enables the DRQ for Extended Mode DMA; clear, the chip
    ; requests nothing (data sheet, B2h). Compatibility-mode DMA runs
    ; without it, as on the chip after a reset (B2h 1Ah).
    cmp byte [ess_compat], 0
    jne .dma
    test byte [ess_virtual_regs+0b2h-0a0h], 40h
    jz .next
.dma:
    call ess_dma_frame
.next:
    inc dword [ess_k]
    jmp .frame
.frames_done:
    ; With the DMA stopped and the FIFO empty for longer than the output
    ; delay, the stream has played out.
    cmp byte [ess_dma_on], 0
    jne .raise
    ; A DMA paused by D0h is still the stream's.
    cmp byte [ess_dma_paused], 0
    jne .raise
    mov eax, [ess_d]
    cmp eax, [ess_q]
    jne .raise
    mov eax, [ess_delay]
    shl eax, 1
    mul dword [ess_step]
    shrd eax, edx, 16
    inc eax
    cmp [ess_idle], eax
    jb .raise
    mov byte [ess_fifo_on], 0
    mov byte [game_active], 0
.raise:
    cmp byte [ess_raise], 0
    je .done
    ; Extended Mode: B1h bit 6 enables an interrupt for each overflow of
    ; the DMA counter. A compatibility-mode block end always interrupts.
    cmp byte [ess_compat], 0
    jne .signal
    test byte [ess_virtual_regs+0b1h-0a0h], 40h
    jz .done
.signal:
    mov al, [game_irq_bit]
    call virtual_dsp_raise_line
.done:
    pop fs
    popad
    ret

; One DAC frame's worth of DMA: up to the FIFO's room, the block's end and
; the fill rate.
ess_dma_frame:
    mov eax, [ess_credit]
    add eax, [ess_credit_step]
    mov ecx, [ess_fifo_size]
    shl ecx, 8
    cmp eax, ecx
    jbe .credit
    mov eax, ecx
.credit:
    mov [ess_credit], eax
    shr eax, 8
    mov ecx, [ess_q]
    add ecx, [ess_fifo_size]
    sub ecx, [ess_d]
    cmp eax, ecx
    jbe .room
    mov eax, ecx
.room:
    mov ecx, [ess_d_cap]
    sub ecx, [ess_d]
    cmp eax, ecx
    jbe .amount
    mov eax, ecx
.amount:
    test eax, eax
    jz .overflow
    mov ecx, eax
    shl eax, 8
    sub [ess_credit], eax
    call ess_move_bytes
.overflow:
    mov eax, [ess_d]
    cmp eax, [ess_next_overflow]
    jb .end
    mov al, [ess_block_latch]
    or [ess_status_latch], al
    mov byte [ess_raise], 1
    ; Extended Mode: the counter reloads from A4h/A5h at every overflow, so
    ; a new block length takes effect from the next block (SPEC 8.4) [sheet].
    cmp byte [ess_compat], 0
    jne .next_block
    movzx eax, word [ess_virtual_regs+0a4h-0a0h]
    neg eax
    and eax, 0ffffh
    jnz .reload
    mov eax, 10000h
.reload:
    mov [ess_block], eax
.next_block:
    mov eax, [ess_block]
    add [ess_next_overflow], eax
    jmp .overflow
.end:
    mov eax, [ess_d]
    cmp eax, [ess_d_cap]
    jb .done
    ; Normal Mode: the requests stop at the overflow until B8h bit 0 is
    ; cleared and set again.
    mov byte [ess_dma_on], 0
    call ess_fifo_position
.done:
    ret

; ECX bytes from the game's buffer into the FIFO, from stream byte ess_d.
ess_move_bytes:
    push es
    mov es, [ess_dac_segment]
.byte:
    mov eax, [ess_d]
    sub eax, [ess_seg_start]
    add eax, [ess_src_pos]
    cmp byte [ess_src_wrap], 0
    je .linear
    xor edx, edx
    div dword [ess_src_len]
    mov eax, edx
    jmp .address
.linear:
    ; A single-mode 8237 at its terminal count gives no more bytes.
    cmp eax, [ess_src_len]
    jb .address
    mov byte [ess_dma_on], 0
    call ess_fifo_position
    pop es
    ret
.address:
    add eax, [ess_src]
    mov edx, eax
    shr edx, 4
    mov fs, dx
    and ax, 15
    mov si, ax
    mov al, [fs:si]
    mov bx, [ess_d]
    and bx, ESS_FIFO_BYTES-1
    mov [es:ESS_FIFO_OFFSET+bx], al
    inc dword [ess_d]
    dec ecx
    jnz .byte
    pop es
    ret

; One DAC frame: from the FIFO when it holds a whole frame, else silence.
ess_dac_frame:
    push es
    mov es, [ess_dac_segment]
    mov cl, [ess_shift]
    mov edx, 1
    shl edx, cl
    mov eax, [ess_k]
    shl eax, cl
    and eax, ESS_DAC_BYTES-1
    mov di, ax
    mov eax, [ess_d]
    sub eax, [ess_q]
    cmp eax, edx
    jb .empty
    mov dword [ess_idle], 0
    cmp byte [ess_swap], 0
    jne .swapped
    mov ecx, edx
.copy:
    mov bx, [ess_q]
    and bx, ESS_FIFO_BYTES-1
    mov al, [es:ESS_FIFO_OFFSET+bx]
    mov [es:di], al
    inc di
    inc dword [ess_q]
    dec ecx
    jnz .copy
    pop es
    ret
.swapped:
    ; Compatibility-mode 8-bit stereo: the first byte is the right channel's;
    ; the ring holds left first.
    mov bx, [ess_q]
    and bx, ESS_FIFO_BYTES-1
    mov al, [es:ESS_FIFO_OFFSET+bx]
    mov [es:di+1], al
    inc bx
    and bx, ESS_FIFO_BYTES-1
    mov al, [es:ESS_FIFO_OFFSET+bx]
    mov [es:di], al
    add dword [ess_q], 2
    pop es
    ret
.empty:
    mov ecx, edx
    xor bx, bx
.silence:
    mov al, [ess_silence+bx]
    mov [es:di], al
    inc di
    xor bx, 1
    dec ecx
    jnz .silence
    cmp byte [ess_dma_on], 0
    jne .done
    inc dword [ess_idle]
.done:
    pop es
    ret

; The 8237's position and terminal count from the bytes the DMA has moved,
; for the reads after the stream (the trap's idle count).
ess_fifo_position:
    push eax
    push edx
    mov eax, [ess_d]
    sub eax, [ess_seg_start]
    add eax, [ess_src_pos]
    cmp byte [ess_src_wrap], 0
    je .single
    xor edx, edx
    div dword [ess_src_len]
    mov eax, edx
    jmp .store
.single:
    cmp eax, [ess_src_len]
    jb .store
    mov eax, [ess_src_len]
    mov byte [dma8+3], 1
.store:
    mov [dma8+DMA_POSITION], eax
    pop edx
    pop eax
    ret

; The count a read of the 8237 returns while the model runs: the bytes moved
; so far. BX=the count register's value. DS=CS.
ess_fifo_count:
    push eax
    push edx
    call ess_fifo_service
    mov eax, [ess_d]
    sub eax, [ess_seg_start]
    add eax, [ess_src_pos]
    cmp byte [ess_src_wrap], 0
    je .single
    xor edx, edx
    div dword [ess_src_len]
    mov eax, edx
    jmp .count
.single:
    cmp eax, [ess_src_len]
    jb .count
    mov bx, 0ffffh
    jmp .done
.count:
    mov bx, [dma8+DMA_COUNT]
    sub bx, ax
.done:
    pop edx
    pop eax
    ret

; The status port 2xCh as the chip reads it (data sheet, port table): bit 6
; data available, 5 FIFO full, 4 empty, 3 half-empty (under 128 bytes), 2 the
; processor's interrupt, 0 the DMA counter's. Bit 7, busy, is the caller's.
; AL=the value. DS=CS.
ess_status:
    push ebx
    call ess_fifo_service
    xor ebx, ebx
    cmp byte [ess_fifo_on], 0
    je .fill
    ; Compatibility mode has no FIFO flags (Table 8): the extended FIFO
    ; reads empty [inference; the TIMES script measures 2xCh then].
    cmp byte [ess_compat], 0
    jne .fill
    mov ebx, [ess_d]
    sub ebx, [ess_q]
.fill:
    xor al, al
    cmp ebx, ESS_FIFO_BYTES
    jb .not_full
    or al, 20h
.not_full:
    test ebx, ebx
    jnz .not_empty
    or al, 10h
.not_empty:
    cmp ebx, ESS_FIFO_BYTES/2
    jae .half
    or al, 8
.half:
    or al, [ess_status_latch]
    cmp byte [ess_reply_count], 0
    je .done
    or al, 40h
.done:
    pop ebx
    ret

align 4
ess_t0 dd 0
ess_step dd 0
; The output frames the mixer reads behind the DAC clock.
ess_delay dd ESS_DELAY_FRAMES
ess_k dd 0
; The DAC frame at ess_t0 (a rate change rebases the clock there).
ess_k0 dd 0
ess_k_target dd 0
ess_q dd 0
ess_d dd 0
ess_d_cap dd 0
ess_seg_start dd 0
ess_src dd 0
ess_src_pos dd 0
ess_src_len dd 0
ess_block dd 0
ess_next_overflow dd 0
ess_idle dd 0
ess_credit dd 0
ess_credit_step dd 0
ess_block_len dd 2048
ess_fifo_size dd ESS_FIFO_BYTES
ess_silence dw 8080h
ess_shift db 0
ess_src_wrap db 0
ess_fifo_on db 0
ess_dma_on db 0
; Set by D0h while the DMA ran, cleared by D4h, B8h and a reset.
ess_dma_paused db 0
ess_raise db 0
ess_auto db 0
ess_block_latch db 1
ess_swap db 0
; 2xCh bits 0 (DMA counter overflow) and 2 (processor interrupt) until a 2xEh
; read.
ess_status_latch db 0
; The DAC ring, a DOS allocation at install when the virtual card is the ESS
; (ess_dac_allocate), or 0: the stream then keeps the previous path.
ess_dac_segment dw 0

%endif
