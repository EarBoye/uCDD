; SPDX-FileCopyrightText: 2026 the uCDD contributors
; SPDX-License-Identifier: GPL-3.0-only

; The virtual ESS AudioDrive, written from the ESS data sheets: its ports,
; commands, extension registers and mixer. It is not a Sound Blaster with ESS
; commands in front: virtual model 4 never reaches the Sound Blaster parser.
; The behaviour, section by section with its sources, is in docs/vess-spec.md
; (SPEC below); the FIFO and DAC are audio/ess_fifo.asm.
;
; Shared with the rest of the driver: the port trap, the 8237 emulation
; (dma8), the virtual PIC (virtual_dsp_raise, virtual_f2h), the mixer that
; reads the DAC ring, CD audio, and the gain functions, which ask
; ess_mixer_gain for model 4.

%ifdef ESS_CARD

; Models, as bits in the command table (SPEC 7.1, "By model").
ES1868 equ 01h
ES1869 equ 02h
ES1878 equ 04h
ES1887 equ 08h
ES1888 equ 10h
ES_ALL equ 1Fh
ES_NOT1878 equ ES_ALL & ~ES1878
ES_488 equ ES1868 | ES1888        ; the ES488 commands D5h-DFh

; ----------------------------------------------------------------------------
; The port entry: port_callback hands over 220h-22Fh (the guest base made
; 22xh) when the virtual card is the ESS. DX=port, CL=the access (bit 2 a
; write), AL=the byte written. Exits through port_callback.result with AL
; for a read, or port_callback.done; ports the card does not own go on to
; port_callback.dispatch as before (the FM synthesizer's).
ess_port:
    test cl, 4
    jz .read
    cmp dx, 22ch
    je .command
    cmp dx, 224h
    je .index
    cmp dx, 225h
    je .data
    cmp dx, 226h
    je .reset
    cmp dx, 227h
    je .power
    cmp dx, 22ah
    je .ignore
    cmp dx, 22eh
    je .ignore
    cmp dx, 22fh
    je .ignore                             ; programmed I/O: SPEC 15
    jmp port_callback.dispatch
.read:
    cmp dx, 22ch
    je .status
    cmp dx, 22eh
    je .acknowledge
    cmp dx, 22ah
    je .reply
    cmp dx, 225h
    je .data_read
    cmp dx, 224h
    je .index_read
    cmp dx, 226h
    je .reset_read
    cmp dx, 227h
    je .power_read
    cmp dx, 22fh
    je .pio_read
    jmp port_callback.dispatch
.command:
    and byte [ess_activity], 0dfh          ; a 2xCh write: bit 5
    call ess_dsp_write
    jmp port_callback.done
.index:
    mov [virtual_mixer_index], al
    mov byte [ess_id_phase], 0
    jmp port_callback.done
.data:
    movzx bx, byte [virtual_mixer_index]
    call ess_mixer_write
    jmp port_callback.done
; A word written to 2x4h: the ISA bus writes the low byte there and the high
; byte to 2x5h (port_callback .wide).
.word:
    mov [virtual_mixer_index], al
    mov byte [ess_id_phase], 0
    mov al, ah
    jmp .data
.reset:
    and byte [ess_activity], 0dfh          ; a 2x6h write: bit 5
    call ess_reset_port
.ignore:
    jmp port_callback.done
.power:
    call ess_power_write
    jmp port_callback.done
.status:
    ; 2xCh: the FIFO and interrupt status (SPEC 5.3). Busy is not modelled:
    ; a trapped access takes longer than the chip's 5-7 us (DESIGN 5).
    and byte [ess_activity], 0bfh          ; a 2xCh read: bit 6
    call ess_status
    jmp port_callback.result
.acknowledge:
    ; 2xEh: bits 5:0 of the status, bit 7 a reply waiting; any read clears
    ; the interrupt request (SPEC 5.2) [sheet, hw]. Bit 6 with a reply
    ; waiting is open (SPEC 16, the QUIRKS script).
    and byte [ess_activity], 0bfh          ; a 2xEh read: bit 6
    call ess_status
    and al, 3fh
    cmp byte [ess_reply_count], 0
    je .cleared
    or al, 80h
.cleared:
    mov byte [ess_status_latch], 0
    and byte [virtual_dsp_irq], 0feh
    jmp port_callback.result
.reply:
    and byte [ess_activity], 0dfh          ; a 2xAh read: bit 5
    call ess_reply_get
    jmp port_callback.result
.data_read:
    movzx bx, byte [virtual_mixer_index]
    call ess_mixer_read
    jmp port_callback.result
.index_read:
    ; Readable on the ESS, unlike the SB Pro (SPEC 3); the ES1888 gives
    ; bits 5:1, bit 0 "MXD" unknown (open question 10) [sheet].
    mov al, [virtual_mixer_index]
    test byte [ess_model_bit], ES1888
    jz port_callback.result
    and al, 3eh
    jmp port_callback.result
.reset_read:
    call ess_reset_read
    jmp port_callback.result
.power_read:
    mov al, [ess_power]
    jmp port_callback.result
.pio_read:
    xor al, al                             ; programmed I/O: SPEC 15
    jmp port_callback.result

; ----------------------------------------------------------------------------
; Replies: the bytes 2xAh returns, flagged by 2xEh bit 7 and 2xCh bit 6.

; AL=a byte for the reply queue.
ess_reply_put:
    movzx bx, byte [ess_reply_count]
    cmp bl, 4
    jae .done
    add bl, [ess_reply_head]
    and bl, 3
    mov [ess_reply_queue+bx], al
    inc byte [ess_reply_count]
.done:
    ret

; AL=the next reply byte, or the last one again when none waits.
ess_reply_get:
    cmp byte [ess_reply_count], 0
    je .last
    movzx bx, byte [ess_reply_head]
    mov al, [ess_reply_queue+bx]
    mov [ess_reply_last], al
    inc bl
    and bl, 3
    mov [ess_reply_head], bl
    dec byte [ess_reply_count]
    ret
.last:
    mov al, [ess_reply_last]
    ret

; ----------------------------------------------------------------------------
; Reset (SPEC 4). 2x6h bit 0 holds the chip in reset, releasing it resets;
; bit 1 holds the FIFO in reset.
ess_reset_port:
    mov ah, [ess_reset_bits]
    and al, 3
    mov [ess_reset_bits], al
    test al, 2
    jz .fifo_ready
    call ess_fifo_flush
.fifo_ready:
    test ah, 1
    jz .done
    test al, 1
    jnz .done
    call ess_software_reset
    mov al, 0aah
    call ess_reply_put
.done:
    ret

; 2x6h read (SPEC 3) [sheet]: bits 7:5 activity, set by this read and
; cleared by activity (7 FM or MPU-401, 6 reads of 2xCh/2xEh, 5 DMA and
; writes of 2x6h/2xCh, reads of 2xAh); bit 3 clear when powered down (FDh);
; bit 2 MIDI mode; bits 1:0 the reset bits. FM and the MPU-401 are the
; physical chip's, so bit 7 is the physical chip's own when it is an ESS.
ess_reset_read:
    mov al, [ess_activity]
    cmp byte [ess_dma_on], 0
    je .dma_ready
    and al, 0dfh                           ; the DMA moves bytes: bit 5
.dma_ready:
    cmp byte [ess_native], 0
    je .fm_ready
    push dx
    mov bl, al
    mov dx, [sb_base]
    add dx, 6
    call physical_read
    pop dx
    and al, 80h
    and bl, 7fh
    or al, bl
.fm_ready:
    and al, 0e0h
    cmp byte [ess_powered_down], 0
    jne .power_ready
    or al, 8
.power_ready:
    cmp byte [ess_midi], 0
    je .midi_ready
    or al, 4
.midi_ready:
    or al, [ess_reset_bits]
    mov byte [ess_activity], 0e0h
    ret

; 2x7h write (SPEC 3, 15): stored and read back; bit 5, the FM reset, goes
; to the physical chip, whose FM it is. The power-down and suspend requests
; are not acted on [design decision].
ess_power_write:
    mov ah, [ess_power]
    mov [ess_power], al
    xor ah, al
    test ah, 20h
    jz .done
    cmp byte [ess_native], 0
    je .done
    push ax
    mov dx, [sb_base]
    add dx, 7
    call physical_read
    pop cx
    and al, 0dfh
    and cl, 20h
    or al, cl
    call physical_write
.done:
    ret

; What any reset does (SPEC 4.2); the mixer is left alone. Also called at
; install.
ess_software_reset:
    push cs
    pop es
    mov byte [ess_extended], 0
    mov byte [ess_b8_running], 0
    mov si, ess_reset_values
    mov di, ess_virtual_regs
    mov cx, 32
    cld
    rep movsb
    call ess_irq_dma_codes
    call ess_fifo_reset
    mov byte [game_active], 0
    mov byte [ess_silence_on], 0
%ifdef VIRTUAL_IRQ
    call virtual_irq_reset
%endif
    mov byte [sb_speaker], 0               ; voice to the mixer off
    mov dword [ess_compat_rate], 8000      ; the timer reset for 8 kHz
    mov word [ess_block48], 2048
    mov byte [ess_gain], 8
    mov byte [ess_midi], 0
    mov byte [ess_powered_down], 0
    mov byte [ess_adpcm], 0
    mov byte [ess_adpcm_next], 0
    mov byte [ess_adpcm_ref_pending], 0
    mov byte [ess_adpcm_left], 0
    mov byte [ess_adpcm_level], 0
    mov byte [ess_adpcm_ref], 80h
    mov byte [sb_id_value], 0aah           ; E2h's running byte (SPEC 7.1)
    mov byte [sb_id_phase], 0
    mov byte [ess_args_left], 0
    mov byte [ess_reply_count], 0
    mov byte [ess_reply_head], 0
    ret

; B1h and B2h bits 3:0 for the virtual IRQ and DMA (SPEC 8.3): the decode
; the ES1868 reads (the same two-bit code in bits 3:2 and 1:0).
ess_irq_dma_codes:
    mov al, [guest_irq]
    mov si, ess_irq_codes
    call .code
    or [ess_virtual_regs+0b1h-0a0h], al
    mov al, [guest_dma8]
    mov si, ess_dma_codes
    call .code
    or [ess_virtual_regs+0b2h-0a0h], al
    ret
.code:
    ; AL=the number, SI=its table of (number, code) ended by FFh: AL=code.
    mov dl, al
.find:
    mov al, [si]
    cmp al, 0ffh
    je .none
    cmp al, dl
    je .hit
    add si, 2
    jmp .find
.hit:
    mov al, [si+1]
    ret
.none:
    xor al, al
    ret

; ----------------------------------------------------------------------------
; Commands (SPEC 7.1). AL=the byte written to 2xCh.
ess_dsp_write:
    cmp byte [ess_midi], 0
    je .not_midi
    ; MIDI input (30h/31h) ends at the next write; UART (34h/35h) only at
    ; a reset (Table 10). Nothing is sent: MIDI is the physical card's.
    cmp byte [ess_midi], 1
    jne .done
    mov byte [ess_midi], 0
    ret
.not_midi:
    cmp byte [ess_args_left], 0
    jne .argument
    mov [ess_command], al
    mov byte [ess_args_got], 0
    cmp byte [ess_extended], 0
    je .table
    cmp al, 0a0h
    jb .table
    cmp al, 0c0h
    ja .table
    ; Axh, Bxh and C0h: one byte, the value or the register to read.
    mov byte [ess_args_left], 1
    ret
.table:
    mov si, ess_commands
.find:
    cmp byte [si], 0ffh
    je .quiet
    cmp [si], al
    je .found
    add si, 5
    jmp .find
.quiet:
    mov si, ess_quiet_commands
    mov word [ess_handler], ess_cmd_none
.quiet_find:
    cmp byte [si], 0ffh
    je .done                               ; not a command of this model
    cmp [si], al
    je .quiet_found
    add si, 3
    jmp .quiet_find
.quiet_found:
    mov ah, [si+2]
    test ah, [ess_model_bit]
    jz .done
    mov al, [si+1]
    mov [ess_args_left], al
    ret
.found:
    mov ah, [si+2]
    test ah, [ess_model_bit]
    jz .done
    mov ax, [si+3]
    mov [ess_handler], ax
    mov al, [si+1]
    mov [ess_args_left], al
    test al, al
    jnz .done
    jmp [ess_handler]
.argument:
    movzx bx, byte [ess_args_got]
    mov [ess_args+bx], al
    inc byte [ess_args_got]
    dec byte [ess_args_left]
    jnz .done
    mov al, [ess_command]
    cmp byte [ess_extended], 0
    je .run
    cmp al, 0a0h
    jb .run
    cmp al, 0bfh
    jbe ess_register_write
    cmp al, 0c0h
    je ess_register_read
.run:
    jmp [ess_handler]
.done:
    ret

; The command table: command, argument bytes, models, handler.
%macro cmd 4
    db %1, %2, %3
    dw %4
%endmacro
ess_commands:
    cmd 10h, 1, ES_ALL, ess_cmd_direct8
    cmd 11h, 2, ES_ALL, ess_cmd_direct16
    cmd 14h, 2, ES_ALL, ess_cmd_14
    cmd 15h, 2, ES_ALL, ess_cmd_15
    cmd 1ch, 0, ES_ALL, ess_cmd_1c
    cmd 1dh, 0, ES_ALL, ess_cmd_1d
    cmd 20h, 0, ES_ALL, ess_cmd_adc8
    cmd 21h, 0, ES_ALL, ess_cmd_adc16
    cmd 30h, 0, ES_ALL, ess_cmd_midi_in
    cmd 31h, 0, ES_ALL, ess_cmd_midi_in
    cmd 34h, 0, ES_ALL, ess_cmd_uart
    cmd 35h, 0, ES_ALL, ess_cmd_uart
    cmd 40h, 1, ES_ALL, ess_cmd_40
    cmd 41h, 1, ES_ALL, ess_cmd_41
    cmd 48h, 2, ES_ALL, ess_cmd_48
    cmd 64h, 2, ES_ALL, ess_cmd_espcm
    cmd 65h, 2, ES_ALL, ess_cmd_espcm
    cmd 66h, 2, ES_ALL, ess_cmd_espcm
    cmd 67h, 2, ES_ALL, ess_cmd_espcm
    cmd 74h, 2, ES_ALL, ess_cmd_adpcm
    cmd 75h, 2, ES_ALL, ess_cmd_adpcm
    cmd 76h, 2, ES_ALL, ess_cmd_adpcm
    cmd 77h, 2, ES_ALL, ess_cmd_adpcm
    cmd 7ah, 2, ES_ALL, ess_cmd_adpcm
    cmd 7bh, 2, ES_ALL, ess_cmd_adpcm
    cmd 80h, 2, ES_ALL, ess_cmd_80
    cmd 90h, 0, ES_ALL, ess_cmd_1c
    cmd 91h, 0, ES_ALL, ess_cmd_91
    cmd 0c6h, 0, ES_ALL, ess_cmd_c6
    cmd 0c7h, 0, ES_ALL, ess_cmd_c7
    cmd 0ceh, 0, ES_NOT1878, ess_cmd_ce
    cmd 0cfh, 1, ES_NOT1878, ess_cmd_cf
    cmd 0d0h, 0, ES_ALL, ess_fifo_pause
    cmd 0d1h, 0, ES_ALL, ess_cmd_d1
    cmd 0d3h, 0, ES_ALL, ess_cmd_d3
    cmd 0d4h, 0, ES_ALL, ess_fifo_unpause
    cmd 0d5h, 0, ES_488, ess_cmd_d5
    cmd 0d6h, 0, ES_488, ess_cmd_zero
    cmd 0d8h, 0, ES_ALL, ess_cmd_d8
    cmd 0dch, 0, ES_NOT1878, ess_cmd_dc
    cmd 0ddh, 1, ES_NOT1878, ess_cmd_dd
    cmd 0deh, 0, ES_488, ess_cmd_zero
    cmd 0e1h, 0, ES_ALL, ess_cmd_e1
    cmd 0e2h, 1, ES_ALL, ess_cmd_e2
    cmd 0e7h, 0, ES_NOT1878, ess_cmd_e7
    cmd 0f2h, 0, ES_NOT1878, ess_cmd_f2
    cmd 0fdh, 0, ES_NOT1878, ess_cmd_fd
    db 0ffh
; Commands that only take their argument bytes: recording, ESPCM
; (SPEC 15), MIDI output, the filter clock (the mixer's own), resume,
; power-down (not modelled). ESPCM 6Ah/6Bh (the sheet's 2.5-bit) take
; their arguments and play nothing until the chip's timing is measured.
; Command, argument bytes, models.
ess_quiet_commands:
    db 24h, 2, ES_ALL
    db 25h, 2, ES_ALL
    db 2ch, 0, ES_ALL
    db 2dh, 0, ES_ALL
    db 38h, 1, ES_ALL
    db 42h, 1, ES_ALL
    db 6ah, 2, ES_ALL
    db 6bh, 2, ES_ALL
    db 6eh, 2, ES_ALL
    db 6fh, 2, ES_ALL
    db 98h, 0, ES_ALL
    db 99h, 0, ES_ALL
    db 0c1h, 0, ES_ALL
    db 0d7h, 1, ES_488
    db 0dfh, 1, ES_488
    db 0ffh

ess_cmd_none:
    ret

ess_cmd_direct8:
    mov al, [ess_args]
    jmp sb_dac_write

ess_cmd_direct16:
    mov al, [ess_args+1]
    jmp sb_dac_write

; Direct ADC: nothing is recorded (SPEC 15); a mid-level sample, so a
; program waiting for the reply gets one [inference].
ess_cmd_adc8:
    mov al, 80h
    jmp ess_reply_put

ess_cmd_adc16:
    xor al, al
    call ess_reply_put
    mov al, 80h
    jmp ess_reply_put

ess_cmd_midi_in:
    mov byte [ess_midi], 1
    ret

ess_cmd_uart:
    mov byte [ess_midi], 2
    ret

; Timer (SPEC 7.1): 40h at 1 MHz, 41h at 1.5 MHz, rate = clock / (256 - X).
ess_cmd_40:
    mov eax, 1000000
    jmp ess_time_constant
ess_cmd_41:
    mov eax, 1500000
ess_time_constant:
    movzx ecx, byte [ess_args]
    neg ecx
    add ecx, 256
    xor edx, edx
    div ecx
    mov [ess_compat_rate], eax
    ret

ess_cmd_48:
    mov ax, [ess_args]
    inc ax
    mov [ess_block48], ax
    ret

; Compatibility-mode playback (SPEC 7.2): 14h/15h a block of the count
; given, 1Ch/1Dh/90h auto-initialised and 91h a block, of the 48h size.
ess_cmd_14:
    xor bl, bl
    jmp ess_compat_normal
ess_cmd_15:
    mov bl, 1
ess_compat_normal:
    mov ax, [ess_args]
    jmp ess_compat_counted
ess_cmd_91:
    xor bl, bl
    mov ax, [ess_block48]
    dec ax
ess_compat_counted:
    movzx eax, ax
    inc eax
    xor bh, bh
    jmp ess_compat_start
ess_cmd_1c:
    xor bl, bl
    jmp ess_compat_auto
ess_cmd_1d:
    mov bl, 1
ess_compat_auto:
    movzx eax, word [ess_block48]
    mov bh, 1
    jmp ess_compat_start

; ADPCM DMA to the DAC (Table 10): 74h/75h 4-bit, 76h/77h 2.6-bit, 7Ah/7Bh
; 2-bit, the odd codes with a reference byte (the block's first byte, the
; starting level; the step back to its smallest). A block of compressed
; bytes, mono, at the timer's rate per decoded sample. The sheet calls it
; the ADPCM "supported by many other sound cards": Creative's, whose
; decoding the emulators give (ess_fifo.asm ess_adpcm_decode) [sheet,
; emu].
ess_cmd_adpcm:
    mov al, [ess_command]
    mov ah, al
    sub al, 74h
    shr al, 1                              ; 0, 1, or 3 for 7Ah/7Bh
    cmp al, 3
    jne .kind
    dec al
.kind:
    inc al                                 ; 1 4-bit, 2 2.6-bit, 3 2-bit
    mov [ess_adpcm_next], al
    test ah, 1
    jz .start
    mov byte [ess_adpcm_ref_pending], 1
    mov byte [ess_adpcm_level], 0
.start:
    xor bl, bl
    mov ax, [ess_args]
    jmp ess_compat_counted

; ESPCM 64h/65h (4.3-bit) and 66h/67h (3.4-bit): ESS's own compression,
; documented nowhere we have. 86Box decodes it from tables its author calls
; part guesswork; its packing, 19 samples in 10 or 8 bytes, agrees with the
; author's encoder and is all the card takes from it [emu]: the block plays
; at that rate as silence, so its DMA and its interrupt keep the chip's
; time and a game does not wait for ever (SPEC 15).
ess_cmd_espcm:
    mov al, [ess_command]
    and al, 2                              ; 0 64h/65h, 2 66h/67h
    shr al, 1
    add al, 4                              ; kinds 4 and 5
    mov [ess_adpcm_next], al
    xor bl, bl
    mov ax, [ess_args]
    jmp ess_compat_counted

; 80h: a silence of the count plus one samples at the timer's rate, then the
; processor interrupt (Table 10).
ess_cmd_80:
    movzx eax, word [ess_args]
    inc eax
    mov ecx, OUTPUT_RATE
    mul ecx
    div dword [ess_compat_rate]
    push eax
    call output_clock
    pop ecx
    add eax, ecx
    mov [ess_silence_end], eax
    mov byte [ess_silence_on], 1
    ret

ess_cmd_c6:
    mov byte [ess_extended], 1
    ret
ess_cmd_c7:
    mov byte [ess_extended], 0
    ret

ess_cmd_ce:
    mov al, [ess_gpo]
    jmp ess_reply_put
ess_cmd_cf:
    mov al, [ess_args]
    mov [ess_gpo], al
    ret

; D1h/D3h: the voice input to the mixer, which gates the game's audio
; (E69 Table 21 note a).
ess_cmd_d1:
    mov byte [sb_speaker], 1
    ret
ess_cmd_d3:
    mov byte [sb_speaker], 0
    ret
ess_cmd_d8:
    mov al, [sb_speaker]
    neg al
    jmp ess_reply_put

ess_cmd_d5:
    mov al, 1
    jmp ess_reply_put
ess_cmd_zero:
    xor al, al                             ; the value: [inference]
    jmp ess_reply_put

ess_cmd_dc:
    mov al, [ess_gain]
    jmp ess_reply_put
ess_cmd_dd:
    mov al, [ess_args]
    and al, 0fh
    mov [ess_gain], al
    ret

ess_cmd_e1:
    mov al, 3
    call ess_reply_put
    mov al, 1
    jmp ess_reply_put

; E2h: Creative's DMA identification. Not in the ESS command tables, but the
; ES1868F answers it as a Sound Blaster does: one byte written by DMA when the
; 8-bit channel is ready, else a reply [hw, 86Box]. Miles' ESS driver uses it
; to find the DMA channel. The driver's 8237 emulation does the work
; (trap.asm sb_identify); a reply byte goes to the ESS queue.
ess_cmd_e2:
    mov al, [ess_args]
    call sb_identify
    jc .done                               ; a stream is running: no answer
    test ah, ah
    jz .done
    jmp ess_reply_put
.done:
    ret

; E7h: the physical chip's own bytes (SPEC 2).
ess_cmd_e7:
    mov al, [ess_physical_id]
    call ess_reply_put
    mov al, [ess_physical_id+1]
    jmp ess_reply_put

; FDh: forced power-down until a reset (Table 10). Only 2x6h bit 3 shows
; it; the rest of the power-down is not modelled [design decision].
ess_cmd_fd:
    mov byte [ess_powered_down], 1
    ret

ess_cmd_f2:
%ifdef VIRTUAL_IRQ
    jmp virtual_f2h
%else
    ret
%endif

; ----------------------------------------------------------------------------
; Extension registers (SPEC 8.1, 8.3). AL=the register (A0h-BFh).
ess_register_read:
    mov al, [ess_args]
    sub al, 0a0h
    cmp al, 1fh
    mov ah, 0
    ja .reply
    movzx bx, al
    mov ah, [ess_virtual_regs+bx]
.reply:
    mov al, ah
    jmp ess_reply_put

ess_register_write:
    sub al, 0a0h
    movzx bx, al
    mov al, [ess_args]
    mov ah, [ess_virtual_regs+bx]
    cmp bl, 0b1h-0a0h
    je .b1
    cmp bl, 0b2h-0a0h
    jne .store
    ; B2h bits 3:0: read-only decodes on the ES1868, 1869 and 1878; bits
    ; 3:2 a writable select on the 1887 and 1888 (SPEC 8.1a) [sheet].
    test byte [ess_model_bit], ES1887 | ES1888
    jnz .select
    and al, 0f0h
    jmp .low
.b1:
    ; B1h: bit 7 takes no write (ES1868F) [hw]; bits 3:0 read-only on the
    ; ES1868 and 1869, bits 3:2 a select on the 1878, 1887, 1888 [sheet].
    and al, 7fh
    test byte [ess_model_bit], ES1878 | ES1887 | ES1888
    jnz .select
    and al, 70h
.low:
    and ah, 0fh
    or al, ah
    jmp .store
.select:
    ; The two-bit code in bits 3:2, repeated in bits 1:0 as the decode
    ; reads (SPEC 8.3).
    and al, 0fch
    mov ah, al
    shr ah, 2
    and ah, 3
    or al, ah
.store:
    mov [ess_virtual_regs+bx], al
    cmp bl, 0a1h-0a0h
    je .rate
    cmp bl, 0bah-0a0h
    je .rate
    cmp bl, 0b8h-0a0h
    jne .done
    ; B8h: bit 0 starts and stops the transfer (SPEC 8.2).
    mov cl, al
    mov ah, [ess_b8_running]
    and al, 1
    mov [ess_b8_running], al
    cmp al, ah
    jne .transition
    ; Running on: bit 2 cleared stops the DMA after the current block,
    ; set it carries on (SPEC 8.2 step 8) [sheet].
    test al, al
    jz .done
    cmp byte [ess_compat], 0
    jne .done
    shr cl, 2
    and cl, 1
    cmp cl, [ess_auto]
    je .done
    mov al, cl
    jmp ess_fifo_kind
.transition:
    test al, al
    jz ess_fifo_stop_dma
    jmp ess_extended_start
.rate:
    ; A1h (or the trim) is the running stream's rate at once: the sheet
    ; latches it nowhere (SPEC 8.1) [sheet; the model agrees].
    cmp byte [ess_b8_running], 0
    je .done
    cmp byte [ess_compat], 0
    jne .done
    cmp byte [ess_fifo_on], 0
    je .done
    call ess_ext_rate
    cmp eax, 4000
    jb .done
    cmp eax, 48000
    ja .done
    jmp ess_fifo_rate
.done:
    ret

; B8h bit 0 set: an extended-mode stream (SPEC 8.4). The format from B7h,
; the rate from A1h, the block from A4h/A5h, the kind from B8h bit 2.
ess_extended_start:
    test byte [ess_virtual_regs+0b8h-0a0h], 0ah
    jnz .refused                           ; recording: SPEC 15
    ; B7h: bit 2 16-bit, bit 3 stereo, bit 5 signed. game_format: bit 0
    ; 16-bit mono, bit 1 unsigned 16-bit, bit 2 signed 8-bit.
    mov al, [ess_virtual_regs+0b7h-0a0h]
    xor bl, bl
    xor cl, cl
    test al, 8
    jz .channels
    inc cl
.channels:
    test al, 4
    jz .eight
    inc cl
    test al, 8
    jnz .sign16
    or bl, 1
.sign16:
    test al, 20h
    jnz .format
    or bl, 2
    jmp .format
.eight:
    test al, 20h
    jz .format
    or bl, 4
.format:
    call ess_ext_rate
    movzx edx, word [ess_virtual_regs+0a4h-0a0h]
    neg edx
    and edx, 0ffffh
    jnz .block
    mov edx, 10000h
.block:
    mov ch, [ess_virtual_regs+0b8h-0a0h]
    shr ch, 2
    and ch, 1
    mov byte [ess_compat], 0
    mov byte [ess_adpcm], 0
    jmp ess_stream_start
.refused:
    ret

; The Extended Mode sample rate (SPEC 8.1): A1h 397.7 kHz/(128-x) with bit
; 7 clear, 795.5 kHz/(256-x) with it set; the clock trim (BAh bit 6) slows
; it 0.25% [hw]. EAX=the rate in Hz; EDX, ESI changed.
ess_ext_rate:
    movzx esi, byte [ess_virtual_regs+0a1h-0a0h]
    mov eax, 397700
    test si, 80h
    jz .divider
    mov eax, 795500
    sub si, 128
.divider:
    neg esi
    add esi, 128
    xor edx, edx
    div esi
    test byte [ess_virtual_regs+0bah-0a0h], 40h
    jz .done
    imul eax, 399
    xor edx, edx
    mov esi, 400
    div esi
.done:
    ret

; A compatibility-mode start. EAX=the block in bytes, BL=1 for 16-bit
; (unsigned), BH=1 auto-initialised. Stereo from mixer 0Eh bit 1, at half
; the timer's rate per channel; 8-bit stereo comes right channel first, the
; real cards' known quirk (SPEC 7.2) [sheet].
ess_compat_start:
    mov edx, eax
    mov ch, bh
    xor cl, cl
    mov al, [ess_adpcm_next]               ; ADPCM for this block, or 0
    mov [ess_adpcm], al
    mov byte [ess_adpcm_next], 0
    mov al, bl
    xor bl, bl
    test al, al
    jz .eight
    mov bl, 3                              ; 16-bit, unsigned
    inc cl
.eight:
    mov eax, [ess_compat_rate]
    cmp byte [ess_adpcm], 0
    jne .mono                              ; ADPCM is mono
    test byte [ess_mixer+0eh], 2
    jz .mono
    shr eax, 1
    inc cl
    and bl, 2                              ; stereo 16-bit: not "16-bit mono"
.mono:
    mov byte [ess_compat], 1
; Joined from both modes. EAX=rate (Hz), BL=game_format, CL=frame shift,
; EDX=block bytes, CH=1 auto-initialised. Refused (nothing starts) for a
; rate outside 4-48 kHz or a buffer the model cannot read.
ess_stream_start:
    cmp eax, 4000
    jb .refused
    cmp eax, 48000
    ja .refused
    mov [ess_block_len], edx
    mov [ess_auto], ch
    mov [game_rate], ax
    shl eax, 16
    xor edx, edx
    push ecx
    mov ecx, OUTPUT_RATE
    div ecx
    pop ecx
    ; A stream still playing continues with its DAC clock when the rate and
    ; format match (a normal-mode block restarted) [sheet].
    cmp byte [ess_fifo_on], 0
    je .fresh
    cmp eax, [ess_step]
    jne .restart
    cmp cl, [ess_shift]
    jne .restart
    cmp bl, [game_format]
    jne .restart
    jmp ess_fifo_continue
.restart:
    push eax
    call ess_fifo_reset
    pop eax
.fresh:
    mov [game_step], eax
    mov [game_format], bl
    mov [game_frame_shift], cl
    xor eax, eax
    mov [sb_sign8], eax
    mov [sb_sign16], ax
    test bl, 4
    jz .sign8
    mov byte [sb_sign8], 80h
.sign8:
    test bl, 2
    jz .sign16
    mov byte [sb_sign16+1], 80h
.sign16:
    mov word [game_dma], dma8
    mov byte [game_irq_bit], 1
    mov byte [game_source], 0
    mov byte [sb_input], 0
    mov byte [sb_filter_legacy], 0
%ifdef OWN_HOST
    mov dword [game_physical], 0
%endif
    mov dword [sb_filter_state], 0
    mov dword [sb_filter_state+4], 0
    mov dword [sb_filter_state+8], 0
    mov dword [sb_filter_state+12], 0
    mov byte [sb_tail_mode], 0
    mov byte [sb_tail_valid], 0
    mov dword [sb_tail_consumed], 0
    ; The DMA buffer must be in the first megabyte for the model to read it.
    movzx eax, byte [dma8+DMA_PAGE]
    cmp al, 0fh
    ja .refused
    mov byte [game_active], 1
    inc word [virtual_starts]
    call ess_fifo_start
    jnc .done
    mov byte [game_active], 0
.refused:
.done:
    ret

; ----------------------------------------------------------------------------
; The silence of 80h, timed on the output clock. Called by ess_fifo_service.
ess_card_service:
    cmp byte [ess_silence_on], 0
    je .done
    push eax
    push ebx
    push ecx
    push edx
    call output_clock
    cmp eax, [ess_silence_end]
    jb .waiting
    mov byte [ess_silence_on], 0
    mov al, 1
    call virtual_dsp_raise
.waiting:
    pop edx
    pop ecx
    pop ebx
    pop eax
.done:
    ret

; ----------------------------------------------------------------------------
; Mixer (SPEC 10). BX=the register (the index), AL=the value written.
ess_mixer_write:
    cmp bx, 80h
    jae .done
    test bx, bx
    jz .reset
    call ess_mixer_exists
    jnc .done
    cmp bl, 22h
    je .master
    cmp bl, 32h
    je .master
    cmp bl, 0ah
    je .mic
    cmp bl, 1eh
    je .stereo_twin
    cmp bl, 40h
    je .done                               ; the identification: read-only
    mov si, ess_twins
.twin:
    cmp byte [si], 0
    je .store
    cmp [si], bl
    je .sb_pro
    add si, 2
    jmp .twin
.sb_pro:
    ; Bits 0 and 4 of an SB Pro address are cleared by a write, and the
    ; value is the extended twin's; 0Ch only has bit 0 stuck (SPEC 10.1).
    cmp bl, 0ch
    je .record
    and al, 0eeh
    jmp .twin_store
.record:
    and al, 0feh
.twin_store:
    mov bl, [si+1]
.store:
    mov [ess_mixer+bx], al
    jmp ess_gains
.stereo_twin:
    mov bl, 0eh
    jmp .store
.mic:
    ; 0Ah sets the 4-bit-per-channel 1Ah from its bits 2:1 (SPEC 10.1).
    shr al, 1
    and al, 3
    mov ah, 55h
    mul ah
    mov [ess_mixer+1ah], al
    ret
.master:
    ; SB Pro master volume emulation into the hardware counters, unless
    ; 64h bit 0 makes the SB Pro master read-only (SPEC 10.2).
    test byte [ess_mixer+64h], 1
    jnz .done
    cmp bl, 22h
    jne .nibbles
    and al, 0eeh
.nibbles:
    mov ah, al
    shr al, 4
    call .counter
    mov [ess_mixer+60h], al
    mov al, ah
    and al, 0fh
    call .counter
    mov [ess_mixer+62h], al
    jmp ess_gains
.counter:
    movzx si, al
    mov al, [ess_master_write+si]
    ret
.reset:
    call ess_mixer_reset
    jmp ess_gains
.done:
    ret

; BX=the register: AL=what a read returns.
ess_mixer_read:
    cmp bl, 40h
    jne .not_id
    ; The identification sequence, restarted by an index write (SPEC 2).
    movzx si, byte [ess_id_phase]
    mov al, [ess_physical_mixer_id+si]
    mov ah, [ess_id_phase]
    inc ah
    and ah, 3
    mov [ess_id_phase], ah
    ret
.not_id:
    cmp bx, 80h
    jae .absent
    call ess_mixer_exists
    jnc .absent
    cmp bl, 22h
    je .master
    cmp bl, 32h
    je .master
    cmp bl, 0ah
    je .mic
    cmp bl, 0ch
    je .record
    cmp bl, 1eh
    je .stereo_twin
    mov si, ess_twins
.twin:
    cmp byte [si], 0
    je .stored
    cmp [si], bl
    je .sb_pro
    add si, 2
    jmp .twin
.sb_pro:
    movzx bx, byte [si+1]
    mov al, [ess_mixer+bx]
    or al, 11h
    ret
.stored:
    mov al, [ess_mixer+bx]
    ret
.absent:
    xor al, al                             ; open question 8 [inference]
    ret
.stereo_twin:
    mov al, [ess_mixer+0eh]
    ret
.record:
    mov al, [ess_mixer+1ch]
    or al, 1
    ret
.mic:
    mov al, [ess_mixer+1ah]
    shr al, 1
    and al, 6
    or al, 1
    ret
.master:
    ; The counters read back as 4 bits a channel (E69 Table 19); through
    ; 22h with bits 0 and 4 set.
    mov al, [ess_mixer+60h]
    call .nibble
    mov ah, al
    shl ah, 4
    mov al, [ess_mixer+62h]
    call .nibble
    or al, ah
    cmp bl, 22h
    jne .done
    or al, 11h
.done:
    ret
.nibble:
    test al, 40h
    jnz .muted
    and al, 3fh
    mov si, ess_master_read
    xor cl, cl
.bound:
    cmp al, [si]
    jbe .found
    inc si
    inc cl
    cmp cl, 15
    jb .bound
.found:
    mov al, cl
    inc al
    ret
.muted:
    xor al, al
    ret

; BX=a register below 80h: CF set when the presented model has it. All
; registers kept (the caller's AL is the value being written).
ess_mixer_exists:
    push ax
    push bx
    push cx
    mov cx, bx
    shr bx, 3
    and cl, 7
    mov al, [ess_mixer_map+bx]
    shr al, cl
    shr al, 1
    pop cx
    pop bx
    pop ax
    ret

; A mixer reset (a write to 00h): the reset values of SPEC 10.2.
ess_mixer_reset:
    push cs
    pop es
    mov di, ess_mixer
    mov cx, 64
    xor ax, ax
    cld
    rep stosw
    mov byte [ess_mixer+14h], 88h
    mov byte [ess_mixer+36h], 88h
    mov byte [ess_mixer+60h], 36h
    mov byte [ess_mixer+62h], 36h
    ret

; The driver's gains from the ESS mixer: voice, FM, CD (sb_pcm_update,
; fm_update, cd_gain_update read them through ess_mixer_gain).
ess_gains:
    call sb_pcm_update
%ifdef RESIDENT_AUDIO
    call fm_update
%endif
%ifdef MOUNTED_AUDIO
    call cd_gain_update
%endif
    ret

; sb_mixer_gain for model 4. BX=the SB16 gain slot asked for (32h voice,
; 34h FM, 36h CD), SI=the channel (0 left, 1 right). EAX=the gain, Q15,
; source times master. The 4-bit levels follow E69 Table 21 by input; the
; 6-bit master counters are 0.75 dB a step, 3Fh at 0 dB [emu: 86Box].
ess_mixer_gain:
    push ebx
    push ecx
    push edx
    ; The three inputs share one law, offset: music (FM) as the table,
    ; voice 9 dB below it, CD and line 7.5 dB below (E69 Table 21).
    mov cl, 14h
    mov dx, 11627                          ; -9 dB, Q15
    cmp bl, 32h
    je .source
    mov cl, 36h
    mov dx, 32768-1
    cmp bl, 34h
    je .source
    mov cl, 38h
    mov dx, 13818                          ; -7.5 dB, Q15
.source:
    mov di, ess_level_music
    movzx bx, cl
    mov al, [ess_mixer+bx]
    test si, si
    jnz .right
    shr al, 4
.right:
    and ax, 0fh
    shl ax, 1
    add di, ax
    movzx eax, word [di]
    movzx edx, dx
    mul edx
    shrd eax, edx, 14                      ; the table holds half the gain
    ; The master counter of the same channel: 0.75 dB a step below 3Fh
    ; (one step is the factor 30057/32768).
    mov bl, [ess_mixer+60h]
    test si, si
    jz .master
    mov bl, [ess_mixer+62h]
.master:
    test bl, 40h
    jnz .muted
    and bl, 3fh
    mov cl, 3fh
    sub cl, bl
    jz .done
.step:
    mov edx, 30057
    mul edx
    shrd eax, edx, 15
    dec cl
    jnz .step
    jmp .done
.muted:
    xor eax, eax
.done:
    pop edx
    pop ecx
    pop ebx
    ret

; ----------------------------------------------------------------------------
; At install: the presented model from the physical chip's identification,
; the reset state, and the physical chip's mixer levels as UNISOUND left
; them, so the virtual card starts where the real one stands. DS=CS.
ess_card_install:
    cmp byte [virtual_model], 4
    jne .done
    mov al, [ess_physical_mixer_id+1]
    mov si, ess_model_ids
.model:
    lodsw
    test al, al
    jz .found                              ; not identified: an ES1868
    cmp al, [ess_physical_mixer_id+1]
    jne .model
.found:
    mov [ess_identified], al
    ; AH: the model's bit; the map follows it in ess_model_maps.
    mov [ess_model_bit], ah
    mov si, ess_model_maps
    cmp ah, ES1869
    jne .map
    add si, 16
.map:
    push cs
    pop es
    mov di, ess_mixer_map
    mov cx, 16
    cld
    rep movsb
    call ess_mixer_reset
    mov si, ess_physical_levels
.level:
    lodsb
    test al, al
    jz .levels_done
    mov bl, al
    call .physical
    movzx bx, bl
    mov [ess_mixer+bx], al
    jmp .level
.levels_done:
    ; The master: the counters 60h/62h of an identified ES1868 or later. An
    ; older or unidentified chip may have none (the ES688/1688, 86Box's card,
    ; read 0Ah there), so its SB Pro master, which every model has, gives
    ; them through Table 20, as a write to 32h would [sheet].
    cmp byte [ess_identified], 0
    je .from_sb_pro
    mov bl, 60h
    call .physical
    mov [ess_mixer+60h], al
    mov bl, 62h
    call .physical
    mov [ess_mixer+62h], al
    jmp .master_done
.from_sb_pro:
    mov bl, 32h
    call .physical
    mov cl, al
    shr al, 4
    mov bx, ess_master_write
    xlatb
    mov [ess_mixer+60h], al
    mov al, cl
    and al, 0fh
    xlatb
    mov [ess_mixer+62h], al
.master_done:
    ; The CD level the virtual card starts with: 0 dB (13 on the aux law).
    mov byte [ess_mixer+38h], 0ddh
    call ess_software_reset
    call ess_gains
.done:
    ret
; BL=a physical mixer register: AL=its value.
.physical:
    mov al, bl
    mov dx, [sb_base]
    add dx, 4
    call physical_write
    inc dx
    jmp physical_read

; ----------------------------------------------------------------------------
; Data

ess_reset_values:
    db 00h, 0dch, 0e7h, 00h, 00h, 0f8h, 00h, 00h      ; A0h-A7h [hw]
    db 02h, 0ch, 00h, 00h, 00h, 00h, 00h, 00h         ; A8h-AFh
    db 00h, 10h, 10h, 00h, 0ffh, 00h, 80h, 44h        ; B0h-B7h
    db 00h, 00h, 00h, 00h, 76h, 00h, 00h, 00h         ; B8h-BFh
ess_irq_codes db 2, 0, 9, 0, 5, 5, 7, 0ah, 10, 0fh, 0ffh, 0
ess_dma_codes db 0, 5, 1, 0ah, 3, 0fh, 0ffh, 0
ess_twins db 04h, 14h, 22h, 32h, 26h, 36h, 28h, 38h, 2eh, 3eh, 0ch, 1ch, 0
; Table 20: the counter a written 4-bit master value sets (bit 6 mute).
ess_master_write db 58h, 24, 30, 34, 38, 42, 46, 50, 54, 55, 56, 58, 59, 61
    db 62, 63
; Table 19: the highest counter each 4-bit read value covers.
ess_master_read db 24, 30, 34, 38, 42, 46, 50, 54, 55, 57, 58, 60, 61, 62, 63
; The models by the second byte of the mixer 40h sequence, and their bits;
; an unknown chip is taken as the ES1868 [inference].
ess_model_ids db 68h, ES1868, 69h, ES1869, 78h, ES1878, 0, ES1868
; Mixer maps, a bit per register 00h-7Fh (vess/model/models.py): the ES1868
; (also the ES1878, ES1887, ES1888 until their maps are extracted), the
; ES1869.
ess_model_maps:
    db 11h, 54h, 10h, 14h, 44h, 41h, 44h, 41h         ; ES1868
    db 55h, 51h, 00h, 00h, 55h, 00h, 50h, 05h
    db 11h, 54h, 10h, 14h, 44h, 41h, 44h, 55h         ; ES1869
    db 55h, 55h, 05h, 50h, 7fh, 0ffh, 57h, 0b5h
; Registers read from the physical chip at install: voice, mic, record
; source, FM, master. Not CD or line: UNISOUND mutes the physical CD input
; (/VC00) because uCDD mixes CD audio digitally, and the virtual card's CD
; level must not follow it.
ess_physical_levels db 14h, 1ah, 1ch, 36h, 0
ess_identified db 0
; The music input's 4-bit levels (E69 Table 21) [sheet], as half the Q15
; gain: 0 dB at 8, +10.5 dB at 15.
ess_level_music dw 0, 1460, 2062, 2914, 4116, 5814, 8212, 11599
    dw 16384, 19473, 23143, 27506, 32691, 38853, 46177, 54881

ess_compat_rate dd 8000
ess_silence_end dd 0
ess_block48 dw 2048
ess_handler dw 0
ess_mixer_map times 16 db 0
ess_mixer times 128 db 0
ess_virtual_regs times 32 db 0
ess_reply_queue times 4 db 0
ess_reply_head db 0
ess_reply_count db 0
ess_reply_last db 0aah
ess_args times 2 db 0
; ADPCM (ess_cmd_adpcm): the kind of the stream (0 none, 1 4-bit, 2 2.6-bit,
; 3 2-bit), the next block's, the decoder's level and step, a reference
; byte still to come.
ess_adpcm db 0
ess_adpcm_next db 0
ess_adpcm_ref db 80h
ess_adpcm_level db 0
ess_adpcm_ref_pending db 0
ess_adpcm_byte db 0
ess_adpcm_left db 0
; 2x6h bits 7:5 (ess_reset_read), 2x7h, FDh.
ess_activity db 0e0h
ess_power db 0
ess_powered_down db 0
ess_args_got db 0
ess_args_left db 0
ess_command db 0
ess_extended db 0
ess_reset_bits db 0
ess_b8_running db 0
ess_compat db 0
ess_silence_on db 0
ess_midi db 0
ess_gain db 8
ess_gpo db 0
ess_id_phase db 0
ess_model_bit db ES1868

%endif
