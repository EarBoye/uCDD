; SPDX-License-Identifier: GPL-3.0-only

; ADPCM on the virtual Sound Blasters (Creative's guide, "ADPCM DMA mode";
; vsb/SPEC.md 7.5). Creative documents the commands but not the decoding,
; so this follows the DSP's own firmware: the CT1741 4.05 (the 4.13's
; decoders are the same) and the SB Pro 2's 3.02, which run the same engine (S95Sedan's disassembly, CT1741_DSP on
; GitHub) [fw]. The virtual ESS decodes its ADPCM as the emulators do
; (ess_fifo.asm); the families differ (rule 6).
;
; The firmware's engine runs on its sample clock. Each tick it takes the
; next code of the byte it holds, or, with the byte's codes used up, fetches
; the next byte by DMA and takes its first code; when the block's bytes are
; used up, it ends the block, or in auto-init fetches the next block's first
; byte and decodes nothing that tick. A command with the reference byte
; fetches it at once: it sets the level and the step (1) and takes no sample
; time. One without fetches its first byte at once and counts it as holding
; one code less than it does (3 for 2-bit, 2 for 2.6-bit), or for 4-bit as
; holding 3 codes, so that byte's codes come out short or one twice. The same
; holds for the first byte of each later auto-init block.
;
; Here the mix position drives the clock: the stream is counted in bytes,
; game_rate being bytes a second, so the DMA count and the block interrupts
; work as for 8-bit PCM; each frame, the engine runs the ticks the position
; has passed. A block with the reference byte so ends up to 3 sample periods
; after the firmware's, one without up to 2 before (about 0.3 ms at the
; guide's rates).

; The engine's state, as the firmware's registers.
sb_adpcm_level db 80h       ; r2: the DAC's level
sb_adpcm_step db 1          ; r5: the step size
sb_adpcm_byte db 0          ; r6: the byte, its next code at the top
sb_adpcm_count db 0         ; r3: ticks to the next byte
sb_adpcm_left dw 0          ; bytes still to fetch in the block, less 1
sb_adpcm_block dw 0         ; the auto-init block's length, less 1 (48h)
sb_adpcm_kind db 0          ; 1 4-bit, 2 2.6-bit, 3 2-bit: the codes a byte, less 1
sb_adpcm_auto db 0          ; auto-init (cleared by DAh)
sb_adpcm_stopped db 0       ; the block ended
; The DMA's place in the buffer, and the buffer's size (bytes).
sb_adpcm_at dw 0
sb_adpcm_size dw 0
; The mix position's code, as of the last frame, and the codes the buffer
; holds, for the ticks between frames.
sb_adpcm_position dd 0
sb_adpcm_codes dd 0

; At a block's start, after the stream's start (trap.asm .validate_start),
; with FS=game_segment: the command's own fetch. AL=1 with the
; reference byte. AH=the kind. DX=the block's length less 1 (48h's for
; auto-init); CX=1 for auto-init. EBX=the buffer's size (bytes). SI=the DMA's
; place in it. Every register is kept.
sb_adpcm_start:
    pushad
    mov [sb_adpcm_kind], ah
    mov [sb_adpcm_left], dx
    mov [sb_adpcm_block], dx
    mov [sb_adpcm_auto], cl
    mov byte [sb_adpcm_stopped], 0
    mov [sb_adpcm_size], bx
    mov [sb_adpcm_at], si
    movzx ecx, ah
    inc ecx
    movzx eax, si
    imul eax, ecx
    mov [sb_adpcm_position], eax
    imul ebx, ecx
    mov [sb_adpcm_codes], ebx
    popad
    pushad
    push ax
    call sb_adpcm_fetch
    pop dx
    test dl, dl
    jz .plain
    mov [sb_adpcm_level], al
    mov byte [sb_adpcm_step], 1
    mov byte [sb_adpcm_count], 1
    popad
    ret
.plain:
    mov [sb_adpcm_byte], al
    ; 3 for 2.6-bit, 4 for 2-bit and 4-bit (the 4-bit byte holds 2).
    mov byte [sb_adpcm_count], 4
    cmp dh, 2
    jne .counted
    mov byte [sb_adpcm_count], 3
.counted:
    popad
    ret

; From the general mix loop: AX=the byte the mix position is in, EBP the
; position (16.16 bytes). Returns AL=the level. Every other register is
; kept. The engine reads the buffer at game_segment:game_offset.
sb_adpcm_sample:
    push ebx
    push ecx
    push edx
    push eax
    movzx ecx, byte [sb_adpcm_kind]
    inc cx
    movzx eax, ax
    imul eax, ecx
    movzx edx, bp
    imul edx, ecx
    shr edx, 16
    add eax, edx
    ; The ticks since the last frame, around the buffer's end. A position
    ; behind the last one, by less than half the buffer, is a block's start
    ; mixed again (sb_patch): no tick.
    mov edx, eax
    sub edx, [sb_adpcm_position]
    jae .ahead
    add edx, [sb_adpcm_codes]
.ahead:
    lea ebx, [edx+edx]
    cmp ebx, [sb_adpcm_codes]
    ja .level
    ; At most 256 a frame: a long gap (the speaker off, a pause) is made up
    ; over the next frames.
    cmp edx, 256
    jbe .advance
    mov edx, 256
.advance:
    mov eax, [sb_adpcm_position]
    add eax, edx
    cmp eax, [sb_adpcm_codes]
    jb .advanced
    sub eax, [sb_adpcm_codes]
.advanced:
    mov [sb_adpcm_position], eax
    test edx, edx
    jz .level
    push fs
    mov fs, [game_segment]
.tick:
    call sb_adpcm_tick
    dec edx
    jnz .tick
    pop fs
.level:
    pop eax
    mov al, [sb_adpcm_level]
    pop edx
    pop ecx
    pop ebx
    ret

; When a single-cycle block ends (irq.asm, virtual_irq_tick), and at an ADPCM
; command (trap.asm .adpcm) should it not have: the ticks the block still had
; when the mix stopped at its end frame, run while the buffer still holds its
; bytes, so the next block goes on from the state the firmware's would. DS=CS;
; every register is kept.
sb_adpcm_close:
    test byte [game_format], 8
    jz .done
    cmp byte [sb_adpcm_stopped], 0
    jne .done
    pushad
    push fs
    mov fs, [game_segment]
    ; A block ends within a few ticks of its last byte; 16 is the bound.
    mov cx, 16
.tick:
    call sb_adpcm_tick
    cmp byte [sb_adpcm_stopped], 0
    jne .closed
    loop .tick
.closed:
    pop fs
    popad
.done:
    ret

; One tick of the firmware's sample clock (vector_dma_dac_adpcm2, ...4,
; ...2_6). Changes AX, BX.
sb_adpcm_tick:
    cmp byte [sb_adpcm_stopped], 0
    jne .done
    dec byte [sb_adpcm_count]
    jnz sb_adpcm_decode
    cmp word [sb_adpcm_left], 0
    je .block_end
    dec word [sb_adpcm_left]
    call .next_byte
    jmp sb_adpcm_decode
.block_end:
    cmp byte [sb_adpcm_auto], 0
    je .stop
    ; Auto-init: the next block's first byte; no code this tick.
    mov ax, [sb_adpcm_block]
    mov [sb_adpcm_left], ax
.next_byte:
    call sb_adpcm_fetch
    mov [sb_adpcm_byte], al
    mov al, [sb_adpcm_kind]
    inc al
    mov [sb_adpcm_count], al
.done:
    ret
.stop:
    mov byte [sb_adpcm_stopped], 1
    ret

; AL=the next byte from the buffer at the DMA's place, which moves on (and
; wraps at the buffer's end). BX changed.
sb_adpcm_fetch:
    mov bx, [sb_adpcm_at]
    push bx
    add bx, [game_offset]
    mov al, [fs:bx]
    pop bx
    inc bx
    cmp bx, [sb_adpcm_size]
    jb .in_buffer
    xor bx, bx
.in_buffer:
    mov [sb_adpcm_at], bx
    ret

; The next code of sb_adpcm_byte, decoded into sb_adpcm_level as the firmware
; does it (adpcm_2_decode, adpcm_4_decode, adpcm_2_6_decode). AX, BX
; changed.
sb_adpcm_decode:
    cmp byte [sb_adpcm_kind], 2
    jb .four
    je .two_six
    ; 2-bit: the sign, then one magnitude bit. A 1 adds one and a half
    ; steps and doubles the step up to 32; a 0 halves the step (to no less
    ; than 1) and adds the halved step, or nothing when it was 1.
    mov al, [sb_adpcm_byte]
    shl al, 1
    sbb bh, bh                             ; the sign
    shl al, 1
    mov [sb_adpcm_byte], al
    mov al, [sb_adpcm_step]
    jc .two_large
    shr al, 1
    mov [sb_adpcm_step], al
    jnz .move
    inc byte [sb_adpcm_step]
    ret
.two_large:
    mov ah, al
    shr al, 1
    add al, ah
    call .move
    cmp byte [sb_adpcm_step], 20h
    je .two_done
    shl byte [sb_adpcm_step], 1
.two_done:
    ret
; AL=the delta, BH=FFh to subtract: the level moves, saturating at 0 and
; 255. (In one path, a 2-bit 0 code adding past 255, the 4.05, 4.13 and 3.02
; firmware load the direct byte at FFh, an SFR, where 0FFh was meant; the
; intent is taken.)
.move:
    test bh, bh
    jnz .down
    add al, [sb_adpcm_level]
    jnc .moved
    mov al, 0ffh
    jmp .moved
.down:
    mov ah, [sb_adpcm_level]
    sub ah, al
    jnc .down_ok
    xor ah, ah
.down_ok:
    mov al, ah
.moved:
    mov [sb_adpcm_level], al
    ret
.four:
    ; 4-bit: the high nibble, then the low one. The delta is the magnitude
    ; times the step plus half the step; a magnitude of 0 halves the step
    ; (to no less than 1), 5 or more doubles it up to 8.
    mov al, [sb_adpcm_byte]
    mov bh, al
    sar bh, 7                              ; the sign
    rol al, 4
    mov [sb_adpcm_byte], al
    and al, 7
    mov bl, al                             ; the magnitude
    call .scaled
    test bl, bl
    jz .halve
    cmp bl, 5
    jb .done
    mov al, [sb_adpcm_step]
    shl al, 1
    cmp al, 10h
    jne .stepped
    mov al, 8
.stepped:
    mov [sb_adpcm_step], al
.done:
    ret
.halve:
    mov al, [sb_adpcm_step]
    shr al, 1
    jnz .stepped
    inc al
    jmp .stepped
; BL=the magnitude, BH the sign: the level moves by BL*step + step/2.
.scaled:
    mov al, [sb_adpcm_step]
    mul bl
    mov ah, [sb_adpcm_step]
    shr ah, 1
    add al, ah
    jmp .move
.two_six:
    ; 2.6-bit: three codes a byte, the sign and two magnitude bits, then
    ; the same, then the sign and one magnitude bit (the third code, when
    ; the count reads 1). A magnitude of 0 halves the step (to no less than
    ; 1), 3 doubles it up to 16.
    mov al, [sb_adpcm_byte]
    mov bh, al
    sar bh, 7
    rol al, 2
    cmp byte [sb_adpcm_count], 1
    jne .two_six_full
    and al, 1
    jmp .two_six_code
.two_six_full:
    rol al, 1
.two_six_code:
    mov [sb_adpcm_byte], al
    and al, 3
    mov bl, al
    call .scaled
    test bl, bl
    jz .halve
    cmp bl, 3
    jne .done
    cmp byte [sb_adpcm_step], 10h
    je .done
    shl byte [sb_adpcm_step], 1
    ret
