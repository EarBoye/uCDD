; SPDX-FileCopyrightText: 2026 vorvek
; SPDX-License-Identifier: GPL-3.0-only

%include "audio/sb_state.inc"

trap_install:
    mov ax, 1a06h
    call far [qpi]
    jc .fail
    mov [old_callback], di
    mov [old_callback+2], es
    ; This experiment must not replace an existing sound virtualizer.
    mov ax, es
    or ax, di
    jnz .fail
    push cs
    pop es
    mov di, port_callback
    mov ax, 1a07h
    call far [qpi]
    jc .fail
    mov byte [callback_set], 1
    mov si, trap_ports
.next:
    lodsw
    test ax, ax
    jz .done
    mov dx, ax
    mov ax, 1a09h
    call far [qpi]
    jc .fail
    inc word [trapped_count]
    jmp .next
.done:
    clc
    ret
.fail:
    stc
    ret
; Stepping aside (audio_release): give back every trapped port but the
; keyboard's, which the hotkeys read; the callback stays installed.
; trap_engage traps them again. Both walk the list, not trapped_count, which
; stays the install's figure for trap_remove.
trap_release:
    mov si, trap_ports
.next:
    lodsw
    test ax, ax
    jz .done
%ifdef MDM_SUPPORT
    cmp ax, 60h
    je .next
%endif
    mov dx, ax
    mov ax, 1a0ah
    call far [qpi]
    jmp .next
.done:
    ret
trap_engage:
    mov si, trap_ports
.next:
    lodsw
    test ax, ax
    jz .done
%ifdef MDM_SUPPORT
    cmp ax, 60h
    je .next
%endif
    mov dx, ax
    mov ax, 1a09h
    call far [qpi]
    jc .fail
    jmp .next
.done:
    clc
    ret
.fail:
    stc
    ret
trap_remove:
    mov byte [trap_remove_failed], 0
    mov si, trap_ports
    mov cx, [trapped_count]
    jcxz .callback
.next:
    lodsw
    mov dx, ax
    mov ax, 1a0ah
    call far [qpi]
    jnc .next_port
    mov byte [trap_remove_failed], 1
.next_port:
    loop .next
.callback:
    cmp byte [callback_set], 0
    je .status
    mov byte [callback_set], 0
    les di, [old_callback]
    mov ax, 1a07h
    call far [qpi]
    jnc .status
    mov byte [trap_remove_failed], 1
.status:
    cmp byte [trap_remove_failed], 0
    je .ok
    stc
    ret
.ok:
    clc
    ret

output_clock:
    mov cx, 8
.retry:
    call .count_pair
    cmp bx, RING_WORDS-1
    ja .again
    cmp ax, RING_WORDS-1
    ja .again
    sub bx, ax
    and bx, RING_WORDS-1
    cmp bx, 32
    jbe .stable
.again:
    loop .retry
%ifdef MOUNTED_AUDIO
    mov byte [fault], 2
%else
    mov byte [fault], 1
%endif
    mov eax, [last_clock]
    ret
.stable:
    ; The frame the card plays: [periods] gives the period it started, the
    ; DMA position how far it is past that start, modulo the ring. Right
    ; while the card is less than RING_PERIODS periods past [periods]: a
    ; later period interrupt resyncs [periods] from this clock.
    movzx eax, ax
    mov ebx, RING_WORDS-1
    sub ebx, eax
    shr ebx, 1
    mov eax, [periods]
    shl eax, OUTPUT_SHIFT
    sub ebx, eax
    and ebx, RING_PERIODS*PERIOD_FRAMES-1
    add eax, ebx
    mov [last_clock], eax
    ret
; BX = the first read of the ring's count, AX = the second, each in ring
; words. Both reads in one call into JemmEx's API (host_gate 1A20h,
; ISSUES.md IRQCOST): six port accesses, one trip. CX is kept (the retry
; count); DX changed.
.count_pair:
%ifdef DIRECT_OUTPUT
    call .count
    mov bx, ax
    jmp .count
%else
    push cx
    mov cx, 0d8h
%ifdef RESIDENT_AUDIO
    cmp byte [sound_card], 0
    je .pair_flip_flop
    mov cx, 0ch
.pair_flip_flop:
%endif
    mov dx, [dma_count_port]
    mov ax, 1a20h
    call far [qpi]
    mov ax, bx
    call .units
    xchg ax, cx
    call .units
    mov bx, cx
    pop cx
    ret
%endif
%ifdef DIRECT_OUTPUT
; One read of the count, port by port (the build without JemmEx's API).
.count:
    push bx
    mov al, 0
    mov dx, 0d8h
%ifdef RESIDENT_AUDIO
    cmp byte [sound_card], 0
    je .reset_dma
    mov dx, 0ch
.reset_dma:
%endif
    call physical_write
    mov dx, [dma_count_port]
    call physical_read
    mov bl, al
    call physical_read
    mov ah, al
    mov al, bl
    pop bx
%endif
; AX = a count read of the card's DMA channel, made ring words.
.units:
%ifdef RESIDENT_AUDIO
    cmp byte [sound_card], 2
    jne .pro_count
    ; At half rate one byte of the ring stands for one word of the mix.
    or al, [ess_half]
    cmp byte [ess_half], 0
    jne .count_ready
    shr ax, 1
    jmp .count_ready
.pro_count:
    cmp byte [sound_card], 3
    jne .stereo_count
    shl ax, 2
    or ax, 3
    jmp .count_ready
.stereo_count:
    cmp byte [sound_card], 1
    jne .count_ready
    shl ax, 1
    or ax, 1
.count_ready:
%endif
    ret

; The position of the game's transfer: EAX = output frames since its start
; (game_started). game_elapsed reads the output clock first; EBX, ECX and EDX
; changed (output_clock), SI and DI kept.
game_elapsed:
    call output_clock
; Called from game_elapsed and from virtual_irq_tick (irq.asm), whose two
; callers (audio_irq at .acknowledged, sb_patch) have just read the clock:
; EAX = that read, so the period handler makes no second trip to the 8237.
game_elapsed_at:
    cmp byte [game_start_pending], 1
    je .zero
    cmp byte [game_source], 0
    jne .output
    cmp byte [sb_single], 0
    jne .output
    ; Auto-init: one position for the count and the block interrupt, the
    ; card's fetch point (vsb-spec 7.8, F8): the frame being heard plus one
    ; period, never past what the mix has taken, never back within the
    ; transfer, held while paused. A real card's count sits on the boundary
    ; at the block interrupt; the interrupt that followed the mix came one to
    ; two periods before this count reached it. Single-cycle keeps the mix
    ; for its interrupt (virtual_irq_tick): a game restarting from its
    ; handler must still find sb_patch's one-period window open.
    cmp byte [sb_paused], 0
    jne .held
    add eax, PERIOD_FRAMES
    sub eax, [game_started]
    js .held
    cmp eax, [game_mix_frame]
    jbe .taken
    mov eax, [game_mix_frame]
.taken:
    cmp eax, [game_position]
    jb .held
    mov [game_position], eax
    ret
.held:
    mov eax, [game_position]
    ret
.output:
    cmp byte [sb_paused], 0
    je .sb_clock
    mov eax, [sb_pause_clock]
.sb_clock:
%ifdef WSS_INPUT
    cmp byte [game_source], 1
    jne .clock_ready
    cmp byte [wss_paused], 0
    je .clock_ready
    mov eax, [wss_pause_clock]
.clock_ready:
%endif
    sub eax, [game_started]
    cmp byte [game_start_pending], 2
    jne .done
    test eax, eax
    js .zero
    mov byte [game_start_pending], 0
    ret
.zero:
    xor eax, eax
.done:
    ret

; The JemmEx port trap entry (far call): DX=port, CL=the access kind and
; width, AL or AX=the value written. DS, ES and FS are unknown; the flags are
; the game's with IF and TF clear and DF as the game left it (sb_patch and the
; mixer clear it under their own saves); the stack is the caller's. BP indexes
; the PUSHAD frame: [ss:bp+28] is the AL returned to the game. Every answer
; joins at .result or .done.
port_callback:
%ifdef RESIDENT_AUDIO
    cmp byte [cs:callback_set], 0
    jne .active
    stc
    retf
.active:
%endif
    pushad
    movzx ebp, sp
    push ds
    push es
    push fs
    push cs
    pop ds
    DRV_TSC_BEGIN trap
    inc dword [port_calls]
%ifdef VIRTUAL_IRQ
    call f2h_service
    ; An output interrupt lost behind the MPU-401's (sb16.asm).
    call sb16_line_check
%endif
%ifdef ESS_FIFO_MODEL
    call ess_fifo_service
%endif
    test cl, 18h
    jnz .wide
%ifdef MDM_SUPPORT
    cmp dx, 60h
    jne .not_keyboard
    test cl, 4
    jnz .keyboard_write
    mov dx, 64h
    call physical_read
    mov bl, al
    mov dx, 60h
    call physical_read
    and bl, 21h
    cmp bl, 1
    jne .result
    cmp byte [mdm_key_active], 0
    jne .result
    call mdm_scan
    jmp .result
.keyboard_write:
    call physical_write
    jmp .done
.not_keyboard:
%endif
%ifdef WSS_INPUT
    push dx
    sub dx, [virtual_wss_base]
    cmp dx, 7
    pop dx
    jbe .wss_port
%endif
    cmp dx, 200h
    jb .dma_port
    mov bx, dx
    sub bx, [guest_base]
    cmp bx, 0fh
    ja .not_sb_port
    lea dx, [bx+220h]
%ifdef ESS_CARD
    ; The virtual ESS is its own card (audio/ess/card.asm): none of its
    ; ports reach the Sound Blaster code below.
    cmp byte [virtual_model], 4
    je ess_port
%endif
    ; The cards before the SB16 decode the DSP's ports without bit 0: 2x7h
    ; is 2x6h, 2xBh 2xAh, 2xDh 2xCh and 2xFh 2xEh. The mixer's two ports
    ; are apart. (DOSBox-X, confirmed on an SB 2.0 and an SB Pro; 86Box.)
    cmp byte [virtual_model], 0
    je .not_sb_port
    cmp dl, 24h
    je .not_sb_port
    cmp dl, 25h
    je .not_sb_port
    and dl, 0feh
.not_sb_port:
    jmp .dispatch
.dma_port:
    call dma_port
.dispatch:
    test cl, 4
    jz .read
%ifdef VIRTUAL_IRQ
    cmp dx, 20h
    je .pic_write
    cmp dx, 21h
    je .pic_write
%endif
%ifdef SB_CARDS
    cmp dx, 226h
    je .reset
    cmp dx, 22ch
    je .command
    ; 2xAh, 2xEh and 2xFh are read only; 2x7h, 2xBh and 2xDh are nothing on
    ; the SB16 (the cards before it read them as their aliases, above).
    cmp dx, 22ah
    jb .not_dsp_write
    cmp dx, 22fh
    jbe .done
.not_dsp_write:
    cmp dx, 227h
    je .done
    cmp dx, 224h
    je .mixer_index
    cmp dx, 225h
    je .mixer_data
%endif
    cmp dx, 0ch
    je .flip_reset
    cmp dx, 0eh
    je .clear_mask
    cmp dx, 8
    je .dma_command
    cmp dx, 0dh
    je .master_clear
    cmp dx, 0fh
    je .all_mask
    cmp dx, 0ah
    je .mask
    cmp dx, 0bh
    je .mode
    cmp dx, 83h
    je .page
    cmp dx, 2
    je .address
    cmp dx, 3
    je .count
    jmp .unsupported
.wide:
    mov bl, cl
    and bl, 1ch
    cmp bl, 0ch
    jne .unsupported
    mov bx, dx
    sub bx, [guest_base]
    cmp bx, 4
    jne .unsupported
%ifdef ESS_CARD
    jmp ess_port.word
%else
    mov [virtual_mixer_index], al
    mov al, ah
    jmp .mixer_data
%endif
.unsupported:
%ifdef MOUNTED_AUDIO
    mov byte [fault], 3
%else
    mov byte [fault], 1
%endif
    jmp .done
; A refused DSP command or argument ends its argument sequence, so that the
; bytes the game writes next are read as commands again.
.command_unsupported:
    mov byte [arguments], 0
    jmp .unsupported
%ifdef SB_CARDS
.reset:
    ; A 1 stops the DSP and holds it in reset; the 0 that follows ends the
    ; reset, and AAh is ready (SBG:881-896). A 0 alone does nothing.
    test al, 1
    jnz .reset_hold
    cmp byte [sb_reset_held], 0
    je .done
    mov byte [sb_reset_held], 0
    mov al, 0aah
    jmp .one_reply
.reset_hold:
    mov byte [sb_reset_held], 1
    ; The reset returns the DSP to its default state (SBG:900-901), the
    ; firmware's cold start; in high-speed and UART modes it only ends the
    ; mode and the DSP's parameters stay (SBG:1352-1354, 2827-2829), the
    ; firmware's warm start.
    cmp byte [sb_warm], 0
    jne .warm_reset
    call sb_cold_start
.warm_reset:
    mov byte [sb_warm], 0
    mov byte [sb_hung], 0
    mov byte [sb_highspeed], 0
    mov byte [sb_midi_uart], 0
    mov byte [sb_dac_enabled], 0
    mov byte [sb_tail_mode], 0
    mov byte [sb_tail_valid], 0
%ifdef RESIDENT_AUDIO
    mov byte [sb_patch_available], 0
%endif
    mov byte [sb_finished], 0
    mov byte [sb_paused], 0
    mov byte [sb_exit_pending], 0
    mov byte [sb_single], 0
    mov byte [sb_input], 0
    mov byte [sb_queued], 0
    mov byte [sb_filter_legacy], 0
    mov byte [game_active], 0
    mov byte [game_start_pending], 0
    mov dword [game_exit_frame], 0
%ifdef VIRTUAL_IRQ
    mov byte [sb_silence], 0
    call virtual_irq_reset
%endif
    inc word [virtual_resets]
    mov byte [reply_count], 0
    mov byte [reply_head], 0
    mov word [reply_pointer], 0
    mov byte [arguments], 0
    jmp .done
.mixer_index:
    mov [virtual_mixer_index], al
    jmp .done
.mixer_data:
    call virtual_mixer_write
    jmp .done
%endif
.flip_reset:
    mov byte [si+DMA_FLIP], 0
    call dma_shared_write
    jmp .done
.mask:
    mov ah, al
    and ah, 3
    mov bx, [guest_dma8]
    cmp si, dma8
    je .mask_channel
    mov bx, [guest_dma16]
    sub bl, 4
.mask_channel:
    cmp ah, bl
    jne .unowned_dma
    and al, 4
    mov [si+DMA_MASK], al
    ; An unmask lets an E2h byte the SB16 holds go.
    test al, al
    jnz .mask_kept
    call sb_identify_release
.mask_kept:
%ifdef WSS_INPUT
    test al, al
    jnz .done
    cmp si, dma8
    je .wss_arm
%endif
    jmp .done
.mode:
    mov ah, al
    and ah, 3
    mov bx, [guest_dma8]
    cmp si, dma8
    je .mode_channel
    mov bx, [guest_dma16]
    sub bl, 4
.mode_channel:
    cmp ah, bl
    jne .unowned_dma
    and al, 0fch
    or al, 1
    ; Bits 7:6 the request mode: demand and block differ from single only
    ; in how many transfers go per request, which the emulation does not
    ; model (it moves data a period at a time), so both are kept as the
    ; single mode of the same kind; the virtual ESS is programmed with
    ; demand mode (B9h). Cascade is refused, as are verify (bits 3:2 00) and
    ; decrement (bit 5) below (8237A data sheet, mode register).
    mov ah, al
    and ah, 0c0h
    cmp ah, 0c0h
    je .unsupported
    and al, 3fh
    or al, 40h
.mode_value:
    cmp al, 49h
    je .set_mode
    cmp al, 59h
    je .set_mode
    cmp al, 45h
    je .set_mode
    cmp al, 55h
    jne .unsupported
.set_mode:
    mov [si+DMA_MODE], al
    jmp .done
.clear_mask:
    mov byte [si+DMA_MASK], 0
    call sb_identify_release
    mov dx, 0ah
    mov bx, [guest_dma8]
    cmp si, dma8
    je .clear_channels
    mov bx, [guest_dma16]
    sub bl, 4
.clear_channels:
    xor al, al
.clear_channel:
    cmp al, bl
    je .next_channel
    call dma_unowned_write
.next_channel:
    inc al
    cmp al, 4
    jb .clear_channel
    jmp .done
.unowned_dma:
    call dma_unowned_write
    jmp .done
.dma_command:
    ; The command register is the controller's. Its disable bit would stop
    ; the output ring too.
    call dma_ring_controller
    jnc .command_write
    and al, 0fbh
.command_write:
    call dma_shared_write
    jmp .done
.master_clear:
    ; Master clear resets the flip-flop and masks every channel. The owned
    ; channel follows in the emulation; the output ring's channel is unmasked
    ; again right after.
    mov byte [si+DMA_FLIP], 0
    mov byte [si+DMA_MASK], 4
    call dma_shared_write
    call dma_ring_controller
    jnc .done
    mov al, [sb_dma8]
    cmp byte [sound_card], 0
    jne .ring_channel
    mov al, [sb_dma16]
    and al, 3
.ring_channel:
    push dx
    mov dx, 0ah
    call dma_shared_write
    pop dx
    jmp .done
.all_mask:
    ; The all-mask register sets the four mask bits at once. Each bit goes
    ; the way of a single-mask write, so that the owned channel stays
    ; virtual and the output ring's channel stays protected.
    mov bx, [guest_dma8]
    cmp si, dma8
    je .all_mask_channel
    mov bx, [guest_dma16]
    sub bl, 4
.all_mask_channel:
    mov ah, al
    xor cl, cl
.all_mask_bit:
    mov al, cl
    test ah, 1
    jz .all_mask_value
    or al, 4
.all_mask_value:
    cmp cl, bl
    jne .all_mask_other
    and al, 4
    mov [si+DMA_MASK], al
    jmp .all_mask_next
.all_mask_other:
    ; dma_unowned_write takes a single-mask write: port 0Ah, not 0Fh.
    push ax
    push bx
    push cx
    push dx
    mov dx, 0ah
    call dma_unowned_write
    pop dx
    pop cx
    pop bx
    pop ax
.all_mask_next:
    shr ah, 1
    inc cl
    cmp cl, 4
    jb .all_mask_bit
    cmp byte [si+DMA_MASK], 0
    jne .all_mask_done
    call sb_identify_release
.all_mask_done:
%ifdef WSS_INPUT
    cmp si, dma8
    jne .done
    cmp byte [si+DMA_MASK], 0
    jne .done
    jmp .wss_arm
%else
    jmp .done
%endif
.page:
    mov [si+DMA_PAGE], al
    jmp .done
.address:
    mov bx, DMA_ADDRESS
    jmp .dma_word
.count:
    mov byte [si+3], 0
    mov bx, DMA_COUNT
.dma_word:
    mov dword [si+DMA_POSITION], 0
    mov byte [si+3], 0
    mov byte [sb_finished], 0
    movzx cx, byte [si+DMA_FLIP]
    add bx, cx
    mov [si+bx], al
    xor byte [si+DMA_FLIP], 1
    jmp .done
%ifdef SB_CARDS
.command:
    ; A DSP held in reset takes nothing. In high-speed mode the DSP 2.01 and
    ; 3.xx "will not accept any other commands" (SBG:1346-1347): only a
    ; reset ends it.
    cmp byte [sb_reset_held], 0
    jne .done
    cmp byte [sb_highspeed], 0
    jne .done
    ; A halted DSP (sb_hung) takes nothing until a reset, or while it holds
    ; an E2h byte, until the DMA takes it.
    cmp byte [sb_hung], 0
    jne .done
    ; In the SB-MIDI UART modes every write is MIDI data (SBG:2820-2832);
    ; in the MIDI input modes a write ends the mode and is dropped.
    cmp byte [sb_midi_uart], 0
    jne .midi_byte
    cmp byte [arguments], 0
    jne .argument
    ; The DSP sends a string reply one byte at a time and waits for each
    ; read, so it takes no command until the string is read and its write
    ; port reads busy meanwhile (.ready). A command written anyway is
    ; dropped here; the chip would hold it in its mailbox.
    cmp word [reply_pointer], 0
    jne .done
    ; FDh reads the command before it (the 4.05's and 4.13's command_reg).
    mov ah, al
    xchg ah, [sb_command_byte]
    mov [sb_previous_command], ah
    call sb_decode
    ; On the SB 2.0, 41h to 47h are 40h (DOSBox-X: an SB Pro demo depends
    ; on it; the SB Pro's 3.02 decodes them so, sb_decode).
    cmp byte [virtual_model], 3
    jne .model_command
    cmp al, 41h
    jb .model_command
    cmp al, 47h
    ja .model_command
    mov al, 40h
.model_command:
    mov [dsp_command], al
    mov byte [arguments_got], 0
    ; Bxh and Cxh: the SB16's 16-bit and 8-bit transfers, a mode byte and a
    ; length (SBG:3837-3894). Bit 3 input, bit 2 auto-init, bit 1 the
    ; FIFO (no difference here), bit 0 not used.
    mov ah, al
    and ah, 0f0h
    cmp ah, 0b0h
    je .sb16_transfer
    cmp ah, 0c0h
    jne .table
.sb16_transfer:
    cmp byte [virtual_model], 0
    jne .table
    mov word [dsp_handler], .play
    mov byte [arguments], 3
    jmp .done
.table:
    ; The command table: command, argument bytes, models, handler.
    mov si, sb_commands
.find:
    cmp byte [si], 0ffh
    je .command_unsupported
    cmp [si], al
    jne .next_command
    ; A command of another model only: like an unknown one, it takes no
    ; argument and does nothing (DOSBox-X's tables by model, the firmware).
    mov ah, [si+2]
    mov cl, [virtual_model]
    shr ah, cl
    test ah, 1
    jnz .found
.next_command:
    add si, 5
    jmp .find
.found:
    mov ax, [si+3]
    mov [dsp_handler], ax
    mov al, [si+1]
    mov [arguments], al
    test al, al
    jnz .done
    jmp [dsp_handler]
.argument:
    movzx bx, byte [arguments_got]
    mov [dsp_args+bx], al
    inc byte [arguments_got]
    dec byte [arguments]
    jnz .done
    jmp [dsp_handler]
.midi_byte:
    cmp byte [sb_midi_uart], 2
    je .midi_input_end
    call sb_midi_out
    jmp .done
.midi_input_end:
    mov byte [sb_midi_uart], 0
    jmp .done
; 30h-33h: MIDI input by polling or interrupt (SBG:3426-3456). No input
; arrives here; the next write ends the mode and is dropped ("send the
; command 31h again"; the 4.05, 4.13 and 3.02 drop any byte).
.midi_input:
    mov byte [sb_midi_uart], 2
    jmp .done
; 38h: one byte of MIDI output (SBG:3537-3548).
.midi_out:
    mov al, [dsp_args]
    call sb_midi_out
    jmp .done
; 34h-37h: the UART modes, which only a reset ends (SBG:3461-3532). MIDI
; input is the physical card's: nothing arrives here.
.midi_uart:
    mov byte [sb_midi_uart], 1
    mov byte [sb_warm], 1
    jmp .done
; A0h, A8h: the SB Pro's input mode, mono or stereo (SBG:3806-3832).
.input_mono:
    mov byte [sb_input_stereo], 0
    jmp .done
.input_stereo:
    mov byte [sb_input_stereo], 1
    jmp .done
; Commands that only take their argument bytes.
.ignore:
    jmp .done
; The SB16's commands for the CSP (the ASP), which the card may lack: reads
; of the absent chip's ports give FFh (a ViBRA without one, DOSBox-X); the
; 4.05 and 4.13 answer as follows [fw]. 01h, an upload: 00h at once, then the
; length; the program, its checksum and its name after it are not taken.
.csp_upload:
    mov word [dsp_handler], .ignore
    mov byte [arguments], 2
    jmp .zero_reply
; 03h, 08h, 0Fh: a read of the chip.
.csp_read:
    mov al, 0ffh
    jmp .one_reply
; 09h: the uploaded program's name, two bytes, none uploaded.
.csp_name:
    xor ax, ax
    jmp .two_replies
; 0Ah: the upload lock count (0), then a read of the chip.
.csp_lock:
    mov ax, 0ff00h
    jmp .two_replies
; The 4.05 and 4.13 after 0Bh's or 0Ch's length, waiting for the chip, and the 3.02
; at 08h-0Fh: the DSP takes nothing until a reset [fw].
.halt:
    mov byte [sb_hung], 1
    jmp .done
; 4Eh: the DSP's timer, once, from two bytes; 4Fh: the timer started from
; two bytes, or stopped when it runs. Nothing outside the DSP follows it
; (it toggles a port pin of its own) [fw].
.timer_once:
    mov byte [sb_timer], 0
    jmp .done
.timer_switch:
    xor byte [sb_timer], 1
    jz .done
    mov word [dsp_handler], .ignore
    mov byte [arguments], 2
    jmp .done
; F4h on the 4.13: two fixed bytes, A4h 6Fh (the 4.05's are 7Dh 1Bh) [fw;
; the CT2290].
.dsp_signature:
    mov ax, 6fa4h
    jmp .two_replies
; F9h, FAh: the 4.05's and 4.13's internal RAM, laid out alike there [fw]. The bytes that hold this card's
; state here are the 8-bit block length (0Eh, 0Fh), the test register
; (2Ah) and the last two commands (20h, 30h); the others read 00h and take
; no write.
.ram_read:
    call sb_ram_byte
    jc .zero_reply
    mov al, [bx]
    jmp .one_reply
.ram_write:
    call sb_ram_byte
    jc .done
    mov al, [dsp_args+1]
    mov [bx], al
    jmp .done
; FBh: the 4.05's and 4.13's status byte: bit 4 the speaker flag, bit 6 the timer's
; reload [fw]; the DMA handshake bits are only set within a command.
.dsp_status:
    mov al, [sb_speaker_flag]
    shl al, 4
    cmp byte [sb_timer], 0
    je .one_reply
    or al, 40h
    jmp .one_reply
; FCh: the 4.05's and 4.13's auxiliary byte: bit 2 an 8-bit, bit 4 a 16-bit auto-init
; transfer running that no exit command ends [fw].
.dsp_auxiliary:
    xor al, al
    cmp byte [game_active], 0
    jne .auxiliary_kind
    cmp byte [sb_paused], 0
    je .one_reply
.auxiliary_kind:
    cmp byte [sb_single], 0
    jne .one_reply
    cmp byte [sb_exit_pending], 0
    jne .one_reply
    cmp dword [game_exit_frame], 0
    jne .one_reply
    mov al, 4
    cmp byte [game_irq_bit], 2
    jne .one_reply
    mov al, 10h
    jmp .one_reply
; FDh: the command before it [fw].
.last_command:
    mov al, [sb_previous_command]
    jmp .one_reply
; 04h on the SB Pro (the 3.02's status register, 04h-07h [fw]): bit 0 the
; speaker, bit 1 stereo input, and the transfer that runs or is paused: bit 2
; input, 3 silence, 4 2-bit ADPCM, 5 2.6-bit, 6 4-bit, 7 8-bit output (not a
; high-speed one). The bits a transfer sets stay until it ends.
.pro_status:
    mov al, [sb_speaker_flag]
    and al, 1
    cmp byte [sb_input_stereo], 0
    je .pro_kind
    or al, 2
.pro_kind:
%ifdef VIRTUAL_IRQ
    cmp byte [sb_silence], 0
    je .pro_transfer
    or al, 8
.pro_transfer:
%endif
    cmp byte [game_active], 0
    jne .pro_running
    cmp byte [sb_paused], 0
    je .one_reply
.pro_running:
    mov ah, 4
    cmp byte [sb_input], 0
    jne .pro_bit
    cmp byte [sb_highspeed], 0
    jne .one_reply
    mov ah, 80h
    test byte [game_format], 8
    jz .pro_bit
    ; The ADPCM kinds 1, 2, 3 (4-bit, 2.6-bit, 2-bit) are bits 6, 5, 4.
    mov cl, [sb_adpcm_kind]
    shr ah, cl
.pro_bit:
    or al, ah
    jmp .one_reply
; 04h on the SB 2.0: 88h (DOSBox-X; no firmware to read).
.sb20_status:
    mov al, 88h
    jmp .one_reply
; F1h on the SB Pro: the DSP's port 2 [fw]: bit 0 high with the speaker
; off, bit 3 with stereo input; bits 1, 4 and 5 rest high, 2 low (ACh-AFh
; would set it), 6 and 7 are the mailbox flags, clear here.
.pro_port:
    mov al, 32h
    cmp byte [sb_speaker_flag], 0
    jne .pro_port_input
    or al, 1
.pro_port_input:
    cmp byte [sb_input_stereo], 0
    je .one_reply
    or al, 8
    jmp .one_reply
.version:
    mov ax, [virtual_dsp_version]
; AL, then AH, to the reply queue.
.two_replies:
    call sb_reply_put
    mov al, ah
    jmp .one_reply
.direct_dac:
    mov al, [dsp_args]
    call sb_dac_write
    jmp .done
.identify:
    mov al, [dsp_args]
    call sb_identify
    jc .command_unsupported
    test ah, ah
    jz .done
    jmp .one_reply
.invert:
    mov al, [dsp_args]
    not al
    jmp .one_reply
.test_write:
    mov al, [dsp_args]
    mov [sb_test_register], al
    jmp .done
.copyright:
    ; E3h: the DSP 4.xx firmware sends its copyright notice with the zero
    ; that ends it; the 3.xx firmware carries the string but no command
    ; sends it.
    cmp byte [virtual_dsp_version], 4
    jb .command_unsupported
    mov word [reply_pointer], copyright_text
    mov byte [reply_count], copyright_length
    jmp .done
.speaker_off:
    mov byte [sb_speaker_flag], 0
    ; On DSP 4.xx the speaker commands only set the flag that D8h reports.
    cmp byte [virtual_dsp_version], 4
    jae .done
    mov byte [sb_speaker], 0
    jmp .done
.speaker_on:
    mov byte [sb_speaker], 1
    mov byte [sb_speaker_flag], 1
    jmp .done
.speaker_status:
    mov al, [sb_speaker_flag]
    neg al
    jmp .one_reply
.test_read:
    mov al, [sb_test_register]
.one_reply:
    call sb_reply_put
    jmp .done
.direct_input:
    ; Direct ADC: silence.
    mov al, 80h
    jmp .one_reply
.zero_reply:
    xor al, al
    jmp .one_reply
.force_irq16:
%ifdef VIRTUAL_IRQ
    mov al, 2
    call virtual_dsp_raise
%endif
    jmp .done
.force_irq:
%ifdef VIRTUAL_IRQ
    ; F2h adds the 8-bit request; a 16-bit one already pending stays. One
    ; close behind another waits its turn (irq.asm, virtual_f2h).
    call virtual_f2h
%endif
    jmp .done
.resume8:
    cmp byte [game_irq_bit], 2
    je .done
    jmp .resume
.resume16:
    cmp byte [game_irq_bit], 2
    jne .done
.resume:
    cmp byte [sb_paused], 0
    je .done
    call output_clock
    sub eax, [sb_pause_clock]
    add [game_started], eax
    mov eax, [sb_pause_mix_frame]
    mov [game_mix_frame], eax
    mov byte [sb_paused], 0
    mov byte [game_active], 1
    cmp byte [sb_exit_pending], 0
    je .done
    mov byte [sb_exit_pending], 0
    jmp .exit_block
.exit8:
    cmp byte [game_irq_bit], 2
    je .done
    ; The ADPCM engine stops at the block's end too (sb_adpcm.asm).
    mov byte [sb_adpcm_auto], 0
    jmp .exit_block
.exit16:
    cmp byte [game_irq_bit], 2
    jne .done
.exit_block:
    cmp byte [game_active], 0
    jne .exit_active
    ; The DSP latches the request while the stream is paused: the block ends
    ; after the resume.
    cmp byte [sb_paused], 0
    je .done
    mov byte [sb_exit_pending], 1
    jmp .done
.exit_active:
    cmp dword [game_exit_frame], 0
    jne .done
    cmp byte [sb_tail_mode], 0
    je .exit_clock
    mov eax, [sb_tail_consumed]
    xor edx, edx
    div dword [game_block_bytes]
    inc eax
    mul dword [game_block_bytes]
    mov cl, [game_frame_shift]
    shr eax, cl
    mov [sb_exit_frames], eax
    mov edx, eax
    shr edx, 16
    shl eax, 16
    div dword [game_step]
    test edx, edx
    jz .exit_store
    inc eax
    jmp .exit_store
.exit_clock:
    call game_elapsed
    movzx ecx, word [game_rate]
    mul ecx
    mov ecx, OUTPUT_RATE
    div ecx
    mov ebx, [game_block_bytes]
    mov cl, [game_frame_shift]
    shr ebx, cl
    xor edx, edx
    div ebx
    inc eax
    mul ebx
    mov [sb_exit_frames], eax
    mov ecx, OUTPUT_RATE
    mul ecx
    movzx ecx, word [game_rate]
    div ecx
    test edx, edx
    jz .exit_store
    inc eax
.exit_store:
    mov [game_exit_frame], eax
    jmp .done
.pause8:
    cmp byte [game_irq_bit], 2
    je .done
    jmp .pause
.pause16:
    cmp byte [game_irq_bit], 2
    jne .done
.pause:
    cmp byte [game_active], 0
    je .done
    call output_clock
    mov [sb_pause_clock], eax
    mov eax, [game_mix_frame]
    mov [sb_pause_mix_frame], eax
    mov eax, [sb_tail_consumed]
    cmp byte [sb_tail_mode], 0
    jne .pause_bytes
    call game_elapsed
    movzx ecx, word [game_rate]
    mul ecx
    mov ecx, OUTPUT_RATE
    div ecx
    mov cl, [game_frame_shift]
    shl eax, cl
.pause_bytes:
    mov si, [game_dma]
    cmp si, dma16
    jne .pause_units
    shr eax, 1
.pause_units:
    cmp byte [sb_single], 0
    je .pause_count
    add eax, [si+DMA_POSITION]
.pause_count:
    movzx ecx, word [si+DMA_COUNT]
    inc ecx
    xor edx, edx
    div ecx
    mov ax, [si+DMA_COUNT]
    sub ax, dx
    mov [si+DMA_SNAPSHOT], ax
    mov byte [sb_paused], 1
    mov byte [game_active], 0
    jmp .done
; 41h, 42h, and on the 4.13 43h: the rate, high byte first (SBG:3573-3599);
; one rate for output and input. The DSP keeps it as its rate register
; (sb16_rate_register) and plays that register's step, so 22050 Hz plays
; at 22083 Hz, as time constant D3h does [fw; the CT2290 plays the two
; alike].
.rate:
    mov ah, [dsp_args]
    mov al, [dsp_args+1]
    call sb16_rate_register
    call sb16_register_rate
    mov [rate_pending], ax
.set_rate:
    ; The rate is checked before it replaces game_rate, which divides later.
    ; Time constant 00h is 3906 Hz, 1953 Hz a channel in stereo.
    cmp word [rate_pending], 1953
    jb .command_unsupported
    ; Games can request a little more than the documented 45000 Hz.
    cmp word [rate_pending], 48000
    ja .command_unsupported
    mov ax, [rate_pending]
    mov [game_rate], ax
    ; The DSP has one rate: a legacy command that follows plays at it. The
    ; time constant form counts both channels of a stereo stream.
    cmp byte [dsp_command], 40h
    jne .rate_command
    mov ax, [legacy_pending]
    jmp .legacy_rate_store
.rate_command:
    test byte [sb_pro_stereo], 2
    jz .legacy_rate_store
    cmp ax, 32768
    jae .legacy_rate_store
    shl ax, 1
.legacy_rate_store:
    mov [legacy_rate], ax
    call sb_game_step
    jmp .done
; 40h: the time constant (SBG:3553-3568). The SB Pro and the SB 2.0 count
; it as the guide's formula has it, 1000000/(256-TC) bytes a second. The
; SB16 looks it up in its firmware's table of rate registers instead
; (sb16_time_table), whose entries round down: D3h, 22222 Hz by the
; formula, plays at 22083 Hz [fw; the CT2290 plays it as 41h 22050].
.time_constant:
    movzx ecx, byte [dsp_args]
    cmp byte [virtual_model], 0
    jne .time_value
    ; EBh and above read as EBh.
    cmp cl, 0ebh
    jb .time_lookup
    mov cl, 0ebh
.time_lookup:
    mov bx, cx
    mov al, [sb16_time_table+bx]
    call sb16_register_rate
    jmp .time_rate
.time_value:
    neg ecx
    add ecx, 256
    mov eax, 1000000
    xor edx, edx
    div ecx
    cmp eax, 65535
    ja .command_unsupported
.time_rate:
    mov [legacy_pending], ax
    test byte [sb_pro_stereo], 2
    jz .time_mono
    shr ax, 1
.time_mono:
    mov [rate_pending], ax
    jmp .set_rate
; 48h: the block size for auto-init and high speed (SBG:3604-3616).
.block_size:
    mov ax, [dsp_args]
    mov [legacy_block], ax
    jmp .done
; ADPCM (SBG:1360-1377, 3289-3714): 74h-77h 4-bit and 3-bit, 16h, 17h 2-bit
; single-cycle with the length; 7Dh, 7Fh, 1Fh auto-init from 48h's. The odd
; commands start with the reference byte. Kinds: 1 4-bit, 2 3-bit, 3 2-bit
; (audio/sb_adpcm.asm). The time constant gives the sample rate; the stream is
; counted in bytes, a byte holding 2, 3 or 4 codes.
.adpcm:
    call sb_adpcm_close
    mov al, [dsp_command]
    mov ah, 3
    cmp al, 20h
    jb .adpcm_kind
    mov ah, 2
    cmp al, 7eh
    jae .adpcm_kind
    mov ah, 1
    cmp al, 7ch
    jae .adpcm_kind
    test al, 2
    jz .adpcm_kind
    inc ah
.adpcm_kind:
    and al, 1
    mov [pending_adpcm_ref], al
    mov [pending_adpcm], ah
    mov byte [pending_input], 0
    mov byte [pending_frame_shift], 0
    mov byte [pending_format], 8
    movzx cx, ah
    inc cx
    mov ax, [legacy_rate]
    xor dx, dx
    div cx
    mov [game_rate], ax
    call sb_game_step
    mov ax, [dsp_args]
    cmp byte [dsp_command], 1fh
    je .adpcm_auto
    cmp byte [dsp_command], 7ch
    jb .validate_start
.adpcm_auto:
    mov ax, [legacy_block]
    jmp .validate_start
; 14h, 24h: an 8-bit single-cycle block, the length from the command.
.single8:
    mov ax, [dsp_args]
    jmp .legacy_format
; 1Ch, 90h, 91h, and for input 2Ch, 98h, 99h: the length from 48h.
.legacy_start:
    mov ax, [legacy_block]
.legacy_format:
    push ax
    mov byte [pending_frame_shift], 0
    mov byte [pending_format], 0
    ; 24h, 2Ch, 98h and 99h record; 14h, 1Ch, 90h and 91h play.
    mov bl, [dsp_command]
    cmp bl, 98h
    jae .legacy_input
    and bl, 0f0h
    cmp bl, 20h
    je .legacy_input
    xor bl, bl
    jmp .legacy_direction
.legacy_input:
    mov bl, 8
.legacy_direction:
    mov [pending_input], bl
    ; Stereo: the mixer's switch for output (SBG:2476-2481), A8h for input
    ; (SBG:3820-3825), and the high-speed input only (SBG:1446-1456).
    mov cl, [sb_pro_stereo]
    test bl, bl
    jz .legacy_kind
    mov cl, [sb_input_stereo]
    cmp byte [dsp_command], 90h
    jb .legacy_mono
.legacy_kind:
    test cl, cl
    jz .legacy_mono
    test ax, ax
    jz .legacy_mono
    mov ax, [legacy_rate]
    mov byte [pending_frame_shift], 1
    shr ax, 1
    jmp .legacy_rate
.legacy_mono:
    mov ax, [legacy_rate]
.legacy_rate:
    mov [game_rate], ax
    call sb_game_step
    pop ax
    jmp .validate_start
; Bxh, Cxh on the SB16: the mode byte, then the length.
.play:
    ; Bit 3: input. Both FIFO modes use the same PCM conversion and block
    ; interrupts.
    mov al, [dsp_command]
    and al, 8
    mov [pending_input], al
    or byte [dsp_command], 2
    and byte [dsp_command], 0f6h
    mov byte [pending_frame_shift], 0
    mov byte [pending_format], 0
    mov al, [dsp_args]
    test al, 0cfh
    jnz .command_unsupported
    test byte [dsp_command], 10h
    jz .mono_mode
    cmp al, 30h
    je .stereo16
    test al, 10h
    jnz .signed16
    or byte [pending_format], 2
.signed16:
    test al, 20h
    jnz .stereo16
    or byte [pending_format], 1
    mov byte [pending_frame_shift], 1
    jmp .play_length
.stereo16:
    mov byte [pending_frame_shift], 2
    jmp .play_length
.mono_mode:
    test al, 10h
    jz .unsigned8
    or byte [pending_format], 4
.unsigned8:
    test al, 20h
    jz .play_length
    mov byte [pending_frame_shift], 1
.play_length:
    call sb_game_step
    mov ax, [dsp_args+1]
    jmp .validate_start
%ifdef VIRTUAL_IRQ
; 80h: no output for the given number of samples less one at the current
; rate, then the 8-bit interrupt. Signalled from the output interrupt.
.silence:
    movzx eax, word [dsp_args]
    inc eax
    imul eax, OUTPUT_RATE
    movzx ecx, word [game_rate]
    add eax, ecx
    dec eax
    xor edx, edx
    div ecx
    push eax
    call output_clock
    pop ecx
    add eax, ecx
    mov [sb_silence_end], eax
    mov byte [sb_silence], 1
    jmp .done
%endif
.validate_start:
    call sb_queue_check
    jnc .start
    ; Queued (sb_queue_check): an auto-init transfer ends with the current
    ; block, as DAh ends it.
    cmp byte [sb_single], 0
    jne .done
    mov byte [sb_adpcm_auto], 0
    jmp .exit_block
.start:
    mov byte [sb_finished], 0
    mov byte [sb_exit_pending], 0
    mov byte [sb_single], 0
    mov bl, [pending_input]
    mov [sb_input], bl
    ; Single-cycle: B2h, C2h (the SB16's, FIFO bit set, input bit clear),
    ; 14h, 24h, 91h, 99h. The others loop.
    mov bl, [dsp_command]
    cmp bl, 0b2h
    je .single
    cmp bl, 0c2h
    je .single
    cmp bl, 14h
    je .single
    cmp bl, 24h
    je .single
    cmp bl, 91h
    je .single
    cmp bl, 99h
    je .single
    ; ADPCM: all but 1Fh, 7Dh and 7Fh are single-cycle.
    test byte [pending_format], 8
    jz .start_kind
    cmp bl, 1fh
    je .start_kind
    cmp bl, 7ch
    jae .start_kind
.single:
    mov byte [sb_single], 1
.start_kind:
%ifdef WSS_INPUT
    mov byte [wss_paused], 0
    and byte [wss_registers+9], 0feh
%endif
    mov byte [game_source], 0
    mov si, dma8
    mov cl, 0
    cmp byte [pending_frame_shift], 2
    je .wide_dma
    test byte [pending_format], 1
    jz .dma_selected
.wide_dma:
    mov si, dma16
    mov cl, 1
.dma_selected:
    cmp byte [sb_input], 0
    je .direction_ready
    mov bl, [si+DMA_MODE]
    and bl, 0efh
    cmp bl, 45h
    jne .command_unsupported
.direction_ready:
    cmp byte [sb_single], 0
    je .block_length
    cmp ax, [si+DMA_COUNT]
    ja .command_unsupported
.block_length:
    movzx edx, ax
    inc edx
    shl edx, cl
%endif
.validate_dma:
    cmp byte [sb_single], 1
    je .single_buffer
    movzx ebx, word [si+DMA_COUNT]
    inc ebx
    shl ebx, cl
    cmp edx, 512
    jae .large_block
    ; Detection code loops one short block over the whole buffer.
    cmp edx, ebx
    jne .short_block
    mov cl, [pending_frame_shift]
    mov eax, 1
    shl eax, cl
    dec eax
    test edx, eax
    jnz .command_unsupported
    jmp .buffer_address
.short_block:
    ; A short block must last two output periods.
    mov cl, [pending_frame_shift]
    mov eax, edx
    shr eax, cl
    imul eax, OUTPUT_RATE
    movzx ecx, word [game_rate]
    imul ecx, PERIOD_FRAMES*2
    cmp eax, ecx
    jb .command_unsupported
.large_block:
    cmp ebx, 512
    jb .command_unsupported
    cmp ebx, 32768
    ja .command_unsupported
    mov cl, [pending_frame_shift]
    mov eax, 1
    shl eax, cl
    dec eax
    test ebx, eax
    jnz .command_unsupported
    ; A block longer than the buffer only means the game polls the DMA
    ; position (below), so its length need not be whole frames: HMI's ESS
    ; driver programs the two's complement of 0FFFh, 61441 bytes, over a
    ; 4 KB buffer of 8-bit stereo, and a real card just counts bytes.
    cmp edx, ebx
    ja .block_aligned
    test edx, eax
    jz .block_aligned
    jmp .command_unsupported
.block_aligned:
    cmp edx, ebx
    je .buffer_address
%ifdef WSS_INPUT
    cmp byte [game_source], 1
    je .buffer_address
%endif
    mov eax, ebx
    sub eax, edx
    jae .free_bytes
    ; A block longer than the buffer: the game polls the DMA position.
    mov eax, ebx
.free_bytes:
    mov cl, [pending_frame_shift]
    shr eax, cl
    imul eax, OUTPUT_RATE
    movzx ecx, word [game_rate]
    imul ecx, PERIOD_FRAMES*2
    cmp eax, ecx
    jb .command_unsupported
    jmp .buffer_address
.single_buffer:
    movzx ebx, word [si+DMA_COUNT]
    inc ebx
    cmp si, dma16
    jne .single_size
    shl ebx, 1
    cmp ebx, 65536
    ja .command_unsupported
.single_size:
    test byte [si+DMA_MODE], 10h
    jnz .buffer_address
    mov eax, [si+DMA_POSITION]
    cmp si, dma16
    jne .single_position
    shl eax, 1
.single_position:
    cmp eax, ebx
    ja .command_unsupported
    neg eax
    add eax, ebx
    cmp edx, eax
    ja .command_unsupported
.buffer_address:
    movzx eax, word [si+DMA_ADDRESS]
    cmp si, dma16
    jne .byte_address
    shl eax, 1
    ; High DMA uses a 128 KiB window; page bit zero is ignored.
    movzx ecx, byte [si+DMA_PAGE]
    and cl, 0feh
    shl ecx, 16
    jmp .address_window
.byte_address:
    movzx ecx, byte [si+DMA_PAGE]
    shl ecx, 16
.address_window:
    add ecx, eax
    add eax, ebx
    cmp si, dma16
    je .word_window
    cmp eax, 65536
    ja .command_unsupported
    jmp .address_limit
.word_window:
    cmp eax, 131072
    ja .command_unsupported
.address_limit:
    cmp byte [sb_single], 0
    je .linear_limit
    cmp si, dma16
    jne .linear_limit
    mov eax, ecx
    and eax, 15
    add eax, ebx
    cmp eax, 65536
    ja .command_unsupported
.linear_limit:
    mov eax, ecx
    add eax, ebx
    cmp eax, 0a0000h
%ifdef OWN_HOST
    jbe .low_source
    cmp ecx, 100000h
    jb .command_unsupported
    cmp eax, 1000000h
    ja .command_unsupported
    cmp byte [sb_single], 1
    jne .command_unsupported
    cmp byte [pending_frame_shift], 0
    jne .command_unsupported
    cmp byte [sb_input], 0
    jne .command_unsupported
    test byte [pending_format], 8
    jnz .command_unsupported
    mov [game_physical], ecx
    jmp .source_ready
.low_source:
    mov dword [game_physical], 0
.source_ready:
%else
    ja .command_unsupported
%endif
    mov [game_dma], si
    mov esi, ecx
    mov [game_block_bytes], edx
    mov cl, [pending_frame_shift]
    mov [game_frame_shift], cl
    mov al, [pending_format]
    mov [game_format], al
    mov dword [sb_sign8], 0
    mov word [sb_sign16], 0
    test al, 4
    jz .sign8_ready
    mov byte [sb_sign8], 80h
.sign8_ready:
    test al, 2
    jz .sign16_ready
    mov byte [sb_sign16+1], 80h
.sign16_ready:
    mov al, 1
    cmp cl, 2
    je .wide_irq
    cmp word [game_dma], dma16
    jne .irq_bit
.wide_irq:
    inc al
.irq_bit:
    mov [game_irq_bit], al
    ; CH: DMA units per frame as a shift. A mono frame is one unit on either
    ; channel, a byte on 8-bit DMA and a word on 16-bit DMA.
    mov ch, cl
    sub ch, al
    inc ch
    mov dword [game_origin], 0
    cmp byte [sb_single], 0
    je .origin_ready
    test ch, ch
    jnz .origin_ready
    mov di, [game_dma]
    mov eax, [di+DMA_POSITION]
    shl eax, 16
    mov [game_origin], eax
.origin_ready:
    shr ebx, cl
    shl ebx, 16
    mov [game_limit], ebx
    cmp byte [sb_single], 0
    je .ring_ready
    test ch, ch
    jz .ring_ready
    mov dword [game_limit], 0
.ring_ready:
    mov byte [sb_dac_enabled], 0
    mov bx, si
    and bx, 15
    mov [game_offset], bx
    shr esi, 4
    mov [game_segment], si
%ifdef SB_CARDS
    ; ADPCM: the firmware's first fetch (sb_adpcm.asm), from the block's
    ; start in the buffer.
    test byte [game_format], 8
    jz .pcm_started
    pushad
    push fs
    mov fs, si
    mov ebx, [game_limit]
    shr ebx, 16
    mov esi, [game_origin]
    shr esi, 16
    mov dx, [dsp_args]
    xor cx, cx
    cmp byte [sb_single], 0
    jne .adpcm_single
    mov dx, [legacy_block]
    inc cx
.adpcm_single:
    mov al, [pending_adpcm_ref]
    mov ah, [pending_adpcm]
    call sb_adpcm_start
    pop fs
    popad
.pcm_started:
%endif
    mov byte [game_start_pending], 1
    mov dword [game_exit_frame], 0
    mov dword [game_position], 0
    mov byte [sb_paused], 0
    cmp byte [sb_single], 0
    je .duration_ready
    mov eax, [game_block_bytes]
    mov ecx, OUTPUT_RATE
    mul ecx
    movzx ebx, word [game_rate]
    mov cl, [game_frame_shift]
    shl ebx, cl
    mov ecx, ebx
    div ecx
    test edx, edx
    jz .duration
    inc eax
.duration:
    mov [game_exit_frame], eax
.duration_ready:
    mov al, [sb_filter_legacy]
    mov byte [sb_filter_legacy], 0
    cmp byte [dsp_command], 0a0h
    jae .filter_clear
    cmp byte [sb_input], 0
    jne .filter_clear
    ; The switchable 3.2 kHz output filter is the SB Pro's mixer's (SBG:
    ; 2385-2388). The SB 2.0 has none: its DAC output is not filtered
    ; (DOSBox-X, from a CT1350B). The SB16's filter follows the sample rate,
    ; for legacy commands too.
    cmp byte [virtual_model], 1
    jne .filter_clear
    mov byte [sb_filter_legacy], 1
    ; A block that follows a filtered block is the same output stream. Keep the
    ; filter state: the response to the last block has not ended.
    test al, al
    jnz .filter_ready
.filter_clear:
    mov dword [sb_filter_state], 0
    mov dword [sb_filter_state+4], 0
    mov dword [sb_filter_state+8], 0
    mov dword [sb_filter_state+12], 0
.filter_ready:
    mov byte [sb_tail_mode], 0
    mov byte [sb_tail_valid], 0
    mov dword [sb_tail_consumed], 0
%ifdef VIRTUAL_IRQ
    call virtual_irq_reset
%endif
    ; 90h, 91h, 98h and 99h: high-speed mode, where a reset keeps the DSP's
    ; parameters (sb_warm). On the SB 2.0 and the SB Pro it takes no
    ; command until a reset, or until a single-cycle block ends
    ; (SBG:1346-1351); the SB16's 4.05 and 4.13 go on taking them [fw].
    mov al, [dsp_command]
    and al, 0f6h
    cmp al, 90h
    jne .speed_ready
    mov byte [sb_warm], 1
    cmp byte [virtual_model], 0
    je .speed_ready
    mov byte [sb_highspeed], 1
.speed_ready:
    mov bl, [game_active]
    mov byte [game_active], 1
    inc word [virtual_starts]
%ifdef RESIDENT_AUDIO
    ; An output interrupt can be pending when this write returns. The game
    ; must run before a block that starts a stream can end.
    mov byte [sb_single_hold], 0
    cmp byte [sb_single], 0
    je .hold_ready
    cmp byte [sb_patch_available], 1
    je .hold_ready
    mov byte [sb_single_hold], 1
.hold_ready:
    test bl, bl
    jnz .patch
    call sb_patch_initial
.patch:
    call sb_patch
%endif
%ifdef WSS_INPUT
    cmp byte [game_source], 1
    jne .sb_started
    call wss_hold
    jmp .done
.sb_started:
%endif
    cmp byte [dsp_command], 1ch
    je .done
    cmp byte [dsp_command], 90h
    je .done
    cmp byte [dsp_command], 91h
    je .done
.argument_done:
    jmp .done
%ifdef WSS_INPUT
%include "audio/wss_input.inc"
%endif
.read:
    cmp dx, 226h
    je .reset_read
    cmp dx, 227h
    je .reset_read                         ; the bus reads FFh
%ifdef VIRTUAL_IRQ
    cmp dx, 20h
    je .pic_read
    cmp dx, 21h
    je .pic_read
%endif
%ifdef SB_CARDS
    cmp dx, 22ch
    je .ready
    cmp dx, 22eh
    je .status
    cmp dx, 22fh
    je .status16
    cmp dx, 22ah
    je .reply
    cmp dx, 225h
    je .mixer_read
    cmp dx, 224h
    je .index_read
%endif
    ; 2xBh and 2xDh on the SB16 (the others alias them, above).
    cmp dx, 22bh
    je .reset_read
    cmp dx, 22dh
    je .reset_read
    cmp dx, 3
    je .dma_read
    cmp dx, 2
    je .dma_read
    cmp dx, 8
    je .dma_status
    cmp dx, 83h
    je .page_read
    ; The other controller registers are write-only: the bus reads FFh.
    cmp dx, 10h
    jb .reset_read
    jmp .unsupported
.page_read:
    mov al, [si+DMA_PAGE]
    jmp .result
.dma_status:
    ; The controller's status, with the output ring's channel hidden and the
    ; owned channel's terminal count from the emulation.
    push dx
    cmp si, dma16
    jne .status_port
    mov dx, 0d0h
.status_port:
    call physical_read
    pop dx
    call dma_ring_controller
    jnc .status_owned
    mov cl, [sb_dma8]
    cmp byte [sound_card], 0
    jne .status_hide
    mov cl, [sb_dma16]
    and cl, 3
.status_hide:
    mov ah, 11h
    shl ah, cl
    not ah
    and al, ah
.status_owned:
    mov bx, [guest_dma8]
    cmp si, dma8
    je .status_channel
    mov bx, [guest_dma16]
    sub bl, 4
.status_channel:
    mov cl, bl
    mov ah, 11h
    shl ah, cl
    not ah
    and al, ah
    cmp byte [si+3], 0
    je .result
    mov ah, 1
    shl ah, cl
    or al, ah
    jmp .result
.reset_read:
    mov al, 0ffh
    jmp .result
%ifdef SB_CARDS
.index_read:
    ; 2x4h is write only (SBG:2221). The SB Pro reads back the index
    ; (DOSBox-X, 86Box); the SB16 reads FFh (86Box; DOSBox-X reads the
    ; index: the CT2290 decides) and the SB 2.0 has nothing there.
    mov al, 0ffh
    cmp byte [virtual_model], 1
    jne .result
    mov al, [virtual_mixer_index]
    jmp .result
.ready:
    ; Only bit 7 is defined (SBG:940-943). The other bits read 7Fh on the
    ; SB16 and 2Ah before it (DOSBox-X, "observed on SB 2.0"; 86Box). Busy
    ; in reset, in high-speed mode, and while a string reply waits to be
    ; read.
    cmp byte [sb_reset_held], 0
    jne .reset_read
    call dsp_status_base
    cmp byte [sb_highspeed], 0
    jne .busy
    cmp word [reply_pointer], 0
    je .result
.busy:
    or al, 80h
    jmp .result
.status:
%ifdef VIRTUAL_IRQ
    and byte [virtual_dsp_irq], 0feh
    call virtual_line_dropped
%endif
    ; Bit 7: a reply waits (SBG:924-926); the other bits as at 2xCh.
    call dsp_status_base
    cmp byte [sb_reset_held], 0
    jne .result
    cmp byte [reply_count], 0
    je .result
    or al, 80h
    jmp .result
.status16:
%ifdef VIRTUAL_IRQ
    and byte [virtual_dsp_irq], 0fdh
    call virtual_line_dropped
%endif
    mov al, 0ffh
    jmp .result
.reply:
    ; With nothing waiting the port reads its last byte again (DOSBox-X,
    ; from a demo that depends on it; 86Box).
    mov al, [reply_last]
    cmp byte [reply_count], 0
    je .result
    call .reply_byte
    mov [reply_last], al
    jmp .result
.reply_byte:
    ; A string reply (reply_pointer set) reads from memory; the others from
    ; the queue (sb_reply_put).
    mov bx, [reply_pointer]
    test bx, bx
    jz .reply_queued
    mov al, [bx]
    inc word [reply_pointer]
    dec byte [reply_count]
    jnz .reply_done
    mov word [reply_pointer], 0
.reply_done:
    ret
.reply_queued:
    movzx bx, byte [reply_head]
    mov al, [reply_queue+bx]
    inc bl
    and bl, REPLY_QUEUE-1
    mov [reply_head], bl
    dec byte [reply_count]
    ret
.mixer_read:
    call virtual_mixer_read
    jmp .result
%endif
.dma_read:
    cmp byte [si+DMA_FLIP], 0
    jne .count_high
    push dx
%ifdef ESS_FIFO_MODEL
    ; While the virtual ESS's stream runs, the count is the bytes its DMA
    ; has moved into the FIFO.
    cmp byte [ess_fifo_on], 0
    je .count_model_off
    cmp si, dma8
    jne .count_model_off
    call ess_fifo_count
    jmp .snapshot
.count_model_off:
%endif
    cmp si, [game_dma]
    jne .idle_count
    cmp byte [game_active], 0
    je .idle_count
    mov eax, [sb_tail_consumed]
    cmp byte [sb_tail_mode], 0
    jne .count_bytes
    ; An auto-initialised transfer's count is the card's fetch point, the
    ; frame being heard plus one period, the position its block interrupt
    ; follows too (game_elapsed, vsb-spec 7.8). It moves sample by sample,
    ; not in the mix's whole periods, and never passes the mix: HMI's drivers
    ; rewrite the buffer right up to the count, and a count past what had
    ; been taken made Descent 2 click on the virtual ESS (5e3f364).
    call game_elapsed
    movzx ecx, word [game_rate]
    mul ecx
    mov ecx, OUTPUT_RATE
    div ecx
    mov cl, [game_frame_shift]
    shl eax, cl
.count_bytes:
    cmp si, dma16
    jne .count_units
    shr eax, 1
    cmp byte [sb_single], 0
    je .count_units
    mov ecx, [game_block_bytes]
    shr ecx, 1
    cmp eax, ecx
    jbe .count_units
    mov eax, ecx
.count_units:
    cmp byte [sb_single], 0
    je .cyclic_count
    add eax, [si+DMA_POSITION]
    test byte [si+DMA_MODE], 10h
    jnz .cyclic_count
    movzx ebx, word [si+DMA_COUNT]
    cmp eax, ebx
    ja .terminal_count
    sub ebx, eax
    jmp .snapshot
.terminal_count:
    mov bx, 0ffffh
    jmp .snapshot
.cyclic_count:
    movzx ecx, word [si+DMA_COUNT]
    inc ecx
    xor edx, edx
    div ecx
    ; The position moves one period at a time, so after each lap it rests on
    ; the first unit of the buffer until the next period is mixed. A real
    ; channel is hardly ever read there. HMI's mixer follows the position and
    ; takes what lies behind it as played: read at the very start, it clears
    ; the first frames of the buffer, which are not mixed yet. Report the
    ; last unit of the lap before instead.
    test dx, dx
    jnz .lap_ready
    test eax, eax
    jz .lap_ready
    cmp byte [sb_single], 0
    jne .lap_ready
    mov dx, cx
    dec dx
.lap_ready:
    mov bx, [si+DMA_COUNT]
    sub bx, dx
    jmp .snapshot
.idle_count:
    cmp si, [game_dma]
    jne .idle_snapshot
    cmp byte [sb_finished], 0
    jne .held_count
    cmp byte [sb_paused], 0
    je .idle_snapshot
.held_count:
    mov bx, [si+DMA_SNAPSHOT]
    jmp .snapshot
.idle_snapshot:
    mov bx, [si+DMA_COUNT]
    sub bx, [si+DMA_POSITION]
    cmp byte [si+3], 0
    je .snapshot
    mov bx, 0ffffh
.snapshot:
    mov [si+DMA_SNAPSHOT], bx
    pop dx
.dma_value:
    cmp dx, 3
    je .count_value
    ; The current address is the start address plus the transferred units.
    mov ax, [si+DMA_ADDRESS]
    add ax, [si+DMA_COUNT]
    sub ax, bx
    mov bx, ax
.count_value:
    mov al, bl
    cmp byte [si+DMA_FLIP], 0
    je .count_result
    mov al, bh
    jmp .count_result
.count_high:
    mov bx, [si+DMA_SNAPSHOT]
    jmp .dma_value
.count_result:
    xor byte [si+DMA_FLIP], 1
    jmp .result
%ifdef VIRTUAL_IRQ
.pic_write:
    call virtual_pic_write
    jmp .done
.pic_read:
    call virtual_pic_read
%endif
; .result: joined from every read and every register answer with AL=the value
; for the game. .done: joined from .result and from the writes that answer
; nothing. On both: the trap's frame as at entry, DS=CS.
.result:
    mov [ss:bp+28], al
.done:
%ifdef SB_CARDS
    ; A queued single-cycle command starts once the transfer before it has
    ; ended, at the first trapped access after (the game's acknowledge,
    ; as a rule); the byte that access read is in the frame already.
    cmp byte [sb_queued], 0
    je .queue_done
    cmp byte [game_active], 0
    jne .queue_done
    cmp byte [sb_paused], 0
    jne .queue_done
    mov byte [sb_queued], 0
    mov al, [sb_queue_command]
    mov [dsp_command], al
    mov ax, [sb_queue_args]
    mov [dsp_args], ax
    mov al, [sb_queue_args+2]
    mov [dsp_args+2], al
    jmp [sb_queue_handler]
.queue_done:
%endif
    DRV_TSC_END trap
%ifdef RESIDENT_AUDIO
    ; Time the hold from the end of the write that started the block. On a
    ; slow CPU this trap lasts longer than an output period.
    cmp byte [sb_single_hold], 1
    jne .restore
    call output_clock
    mov [sb_hold_clock], eax
    mov byte [sb_single_hold], 2
.restore:
%endif
    pop fs
    pop es
    pop ds
    popad
    clc
    retf

; E2h, DMA identification (the virtual ESS's too): AL=the argument. The
; firmware's sequence byte goes by DMA when the 8-bit channel is ready for a
; transfer to memory (AH=0). When it is not, the SB16's DSP writes the byte
; to its DMA latch and waits there, taking no command, until the channel
; takes it or a reset comes; nothing shows at 22Ah [fw: the 4.13's
; cmd_dsp_dma_id; the CT2290]: sb_hung 2, AH=0, and sb_identify_release
; sends it when the game unmasks the channel. The other models reply
; instead, AL with AH=1 (the 3.02 waits too, but whether its byte shows at
; 22Ah is not known). CF set, and no answer, while a stream runs. BX, SI,
; DI, ES changed.
sb_identify:
    movzx bx, byte [sb_id_phase]
    xor al, [.masks+bx]
    add [sb_id_value], al
    inc bl
    and bl, 3
    mov [sb_id_phase], bl
    call sb_identify_dma
    jnc .sent
    test ah, ah
    jnz .failed
    mov al, [sb_id_value]
    cmp byte [virtual_model], 0
    jne .reply
    mov byte [sb_hung], 2
.sent:
    xor ah, ah
    clc
    ret
.reply:
    mov ah, 1
    clc
    ret
.failed:
    stc
    ret
.masks db 96h,0a5h,69h,5ah

; sb_id_value to memory through the virtual 8-bit channel. CF clear when it
; went; CF set with AH=0 when the channel is masked, not set for a write or
; at its terminal count; CF set with AH=1 while a stream runs or when the
; buffer lies above the first megabyte. BX, SI, DI, ES changed.
sb_identify_dma:
    mov si, dma8
    xor ah, ah
    cmp byte [si+DMA_MASK], 0
    jne .refused
    cmp byte [si+3], 0
    jne .refused
    mov al, [si+DMA_MODE]
    and al, 0ch
    cmp al, 4
    jne .refused
    mov ah, 1
    cmp byte [game_active], 0
    jne .refused
    cmp byte [si+DMA_PAGE], 10h
    jae .refused
    movzx ax, byte [si+DMA_PAGE]
    shl ax, 12
    mov es, ax
    mov bx, [si+DMA_ADDRESS]
    mov di, [si+DMA_POSITION]
    test byte [si+DMA_MODE], 20h
    jz .forward
    sub bx, di
    jmp .store
.forward:
    add bx, di
.store:
    mov al, [sb_id_value]
    mov [es:bx], al
    inc dword [si+DMA_POSITION]
    movzx eax, word [si+DMA_COUNT]
    cmp [si+DMA_POSITION], eax
    jbe .sent
    test byte [si+DMA_MODE], 10h
    jz .terminal
    mov dword [si+DMA_POSITION], 0
    jmp .sent
.terminal:
    mov byte [si+3], 1
.sent:
    clc
    ret
.refused:
    stc
    ret

; SI=the controller whose owned channel the game just unmasked. An E2h byte
; the SB16 holds (sb_hung 2) goes now, and its DSP takes commands again.
; Every register kept.
sb_identify_release:
    cmp byte [sb_hung], 2
    jne .done
    cmp si, dma8
    jne .done
    pushad
    push es
    call sb_identify_dma
    jc .held
    mov byte [sb_hung], 0
.held:
    pop es
    popad
.done:
    ret

%ifdef SB_CARDS
; AL=a byte of SB-MIDI output (38h, or a write in UART mode). It goes out of
; the physical card's MIDI port through its DSP's 38h where that DSP takes
; commands while the driver plays: the SB16 and the SB 2.0, not the SB Pro
; in high-speed mode. Elsewhere it is dropped. Every register is kept.
sb_midi_out:
    pushad
    cmp byte [sound_card], 0
    je .physical
    cmp byte [sound_card], 3
    jne .done
.physical:
    mov ah, al
    mov al, 38h
    call .write
    jc .done
    mov al, ah
    call .write
.done:
    popad
    ret
; AL to the physical DSP once its write buffer is free, within about 2 ms;
; CF set when it was not. Not dsp_write, which treats a timeout as a dead
; card and stops the output.
.write:
    push ax
    mov dx, [sb_base]
    add dx, 0ch
    mov cx, 2000
.wait:
    call physical_read
    test al, 80h
    jz .ready
    loop .wait
    pop ax
    stc
    ret
.ready:
    pop ax
    call physical_write
    clc
    ret

; The command the DSP runs for the byte in AL (vsb/SPEC.md 5.2). The SB16's
; DSP 4.xx and the SB Pro 2's 3.02 decode most commands by their low bits
; within the group, so that a group's undocumented members run as one of
; its documented commands; the 4.xx looks groups 0, 4, 5, 6 and A-F up in
; tables whose unused entries do nothing (S95Sedan's disassembly of the
; firmwares, CT1741_DSP; the virtual SB16 runs the 4.13's tables, which add
; 43h and DCh to the 4.05's). sb_commands holds the commands as they run. The
; SB 2.0's DSP 2.01 is not dumped: its commands stay as written. BX changed.
sb_decode:
    movzx bx, al
    shr bl, 4
    cmp byte [virtual_model], 1
    je .group
    ja .done
    ; The 4.xx: groups 1, 2, 3, 7, 8 and 9 by bits.
    bt word [.sb16_groups], bx
    jnc .done
.group:
    shl bx, 1
    jmp [.groups+bx]
.sb16_groups dw 0000001110001110b
.groups dw .group0, .group1, .group2, .group3, .group4, .done, .done, .group7
    dw .group8, .group9, .groupA, .done, .done, .groupD, .groupEF, .groupEF
; 00h-03h nothing, 04h-07h the status, 08h-0Fh a halt (the 3.02).
.group0:
    test al, 8
    jz .and4
    mov al, 8
    ret
.and4:
    and al, 4
    ret
; 10h-13h the direct DAC; bit 2 single-cycle, bit 3 auto-init, bit 1 2-bit
; ADPCM, bit 0 its reference byte: 14h, 16h, 17h, 1Ch, 1Eh, 1Fh.
.group1:
    test al, 0ch
    jnz .transfer
    mov al, 10h
    ret
.transfer:
    mov bh, 0bh
    test al, 2
    jnz .kind
    mov bh, 8
.kind:
    and al, bh
    or al, 14h
    ret
; 20h-23h the direct ADC, 24h-27h single-cycle, 28h-2Fh auto-init input.
.group2:
    test al, 8
    jz .and24
    mov al, 2ch
    ret
.and24:
    and al, 24h
    ret
; 30h-33h MIDI input, 34h-37h the UART modes, 38h-3Fh MIDI output.
.group3:
    test al, 8
    jz .and34
    mov al, 38h
    ret
.and34:
    and al, 34h
    ret
; The 3.02: 40h-47h the time constant, 48h-4Fh the block size.
.group4:
    and al, 48h
    ret
; ADPCM: single-cycle with bit 2 alone, else auto-init; bit 1 2.6-bit (else
; 4-bit), bit 0 the reference byte: 74h-77h, 7Ch-7Fh.
.group7:
    mov bh, al
    and al, 3
    or al, 7ch
    test bh, 8
    jnz .done
    test bh, 4
    jz .done
    and al, 77h
    ret
.group8:
    mov al, 80h
    ret
; Bit 3 input, bit 0 single-cycle: 90h, 91h, 98h, 99h.
.group9:
    and al, 99h
    ret
; The 3.02: A0h-A7h mono input, A8h-AFh stereo.
.groupA:
    and al, 0a8h
    ret
; The 3.02: bit 2 continues (D4h); bit 3 the speaker's status (D8h) or, with
; bit 1, ends auto-init (DAh); bit 0 the speaker on (D1h) or off (D3h);
; neither pauses (D0h).
.groupD:
    test al, 4
    jz .speaker
    mov al, 0d4h
    ret
.speaker:
    test al, 8
    jz .switch
    and al, 0dah
    ret
.switch:
    test al, 1
    jz .pause
    and al, 0d3h
    ret
.pause:
    mov al, 0d0h
    ret
; The 3.02: the highest of bits 3-0 picks the command: E8h, E4h, E2h, E1h,
; E0h; F8h, F4h, F2h, F1h, F0h.
.groupEF:
    mov bh, 8
.bit:
    test al, bh
    jnz .found
    shr bh, 1
    jnz .bit
.found:
    and al, 0f0h
    or al, bh
.done:
    ret

; The DSP's defaults, set by the firmware's cold start (port_callback
; .reset_hold) and at install [fw]: a time constant of 9Ch (10000 Hz; the
; SB16's rate register 38h), the 8-bit block length 07FFh, the identification
; (E2h) sequence from its start, mono input, the timer off, and the speaker
; off: on the SB Pro and SB 2.0 its output too, on the SB16 only the flag D8h
; reads (SBG:3920-3926). DS=CS; EAX, ECX, EDX changed.
sb_cold_start:
    mov word [legacy_rate], 10000
    mov word [game_rate], 10000
    call sb_game_step
    mov word [legacy_block], 07ffh
    mov byte [sb_id_value], 0aah
    mov byte [sb_id_phase], 0
    mov byte [sb_input_stereo], 0
    mov byte [sb_timer], 0
    mov byte [sb_speaker_flag], 0
    cmp byte [virtual_model], 0
    je .done
    mov byte [sb_speaker], 0
.done:
    ret

; CF set when the command being started (port_callback .validate_start)
; waits for the transfer running: a single-cycle command during an auto-init
; transfer of the same width takes effect at the end of the current block,
; where "the DSP will exit from auto-initialize DMA mode and continue to
; transfer using the specified single-cycle DMA mode" (SBG:1318-1323,
; 3335-3338); the 4.05 and 4.13 no longer queue once DAh has ended auto-init. The
; SB Pro's 3.02 queues one behind any transfer that runs, a single-cycle one
; too [fw]. High-speed commands start at once. The command is kept in
; sb_queue_command, sb_queue_args and sb_queue_handler. Every register is
; kept (AX holds the block's length).
sb_queue_check:
    push ax
    ; Single-cycle: 14h, 24h, Bxh and Cxh without bit 2 (dsp_command has
    ; the FIFO bit set by now), and the ADPCM commands without bit 3.
    mov al, [dsp_command]
    cmp al, 14h
    je .single
    cmp al, 24h
    je .single
    test byte [pending_format], 8
    jnz .adpcm
    mov ah, al
    and ah, 0f0h
    cmp ah, 0b0h
    je .sb16
    cmp ah, 0c0h
    jne .start
.sb16:
    test al, 4
    jnz .start
    ; Cxh on the 8-bit interrupt, Bxh on the 16-bit one.
    mov ah, 1
    cmp al, 0c0h
    jae .width
    inc ah
    jmp .width
.adpcm:
    test al, 8
    jnz .start
.single:
    mov ah, 1
.width:
    cmp byte [virtual_model], 1
    jne .auto_only
    cmp byte [game_active], 0
    je .start
    jmp .queue
.auto_only:
    cmp byte [game_active], 0
    jne .running
    cmp byte [sb_paused], 0
    je .start
.running:
    cmp byte [sb_single], 0
    jne .start
    cmp byte [sb_exit_pending], 0
    jne .start
    cmp dword [game_exit_frame], 0
    jne .start
    cmp ah, [game_irq_bit]
    jne .start
.queue:
    mov al, [dsp_command]
    mov [sb_queue_command], al
    mov ax, [dsp_args]
    mov [sb_queue_args], ax
    mov al, [dsp_args+2]
    mov [sb_queue_args+2], al
    mov ax, [dsp_handler]
    mov [sb_queue_handler], ax
    mov byte [sb_queued], 1
    pop ax
    stc
    ret
.start:
    pop ax
    clc
    ret

; AL to the reply queue. The DSP writes a reply into its one-byte output
; latch and waits for the program to read the one before (the firmware's
; dsp_data_write) [fw]: a reply waits behind those not yet read. A queue
; that is full drops the byte. BX changed.
sb_reply_put:
    movzx bx, byte [reply_count]
    cmp bl, REPLY_QUEUE
    jae .full
    add bl, [reply_head]
    and bl, REPLY_QUEUE-1
    mov [reply_queue+bx], al
    inc byte [reply_count]
.full:
    ret

; game_step from game_rate. EAX, ECX, EDX changed.
sb_game_step:
    movzx eax, word [game_rate]
    shl eax, 16
    xor edx, edx
    mov ecx, OUTPUT_RATE
    div ecx
    mov [game_step], eax
    ret

; F9h, FAh: BX=the byte that holds the 4.13's internal RAM byte dsp_args
; names, CF set when none here does (port_callback .ram_read).
sb_ram_byte:
    mov al, [dsp_args]
    mov bx, sb_ram_map
.next:
    cmp byte [bx], 0ffh
    je .none
    cmp [bx], al
    je .found
    add bx, 3
    jmp .next
.found:
    mov bx, [bx+1]
    clc
    ret
.none:
    stc
    ret
sb_ram_map:
    db 0eh
    dw legacy_block
    db 0fh
    dw legacy_block+1
    db 20h
    dw sb_command_byte
    db 2ah
    dw sb_test_register
    db 30h
    dw sb_previous_command
    db 0ffh

; The virtual Sound Blasters' commands by model (vsb/SPEC.md section 5),
; as they run (sb_decode): command, argument bytes, models, handler. A byte
; can run differently on each model. A command missing here, or not of the
; presented model, takes no argument and does nothing. Bxh and Cxh are the
; SB16's alone (port_callback .sb16_transfer).
SB_16 equ 1
SB_PRO equ 2
SB_20 equ 8
SB_ALL equ SB_16 | SB_PRO | SB_20
%macro dsp 4
    db %1, %2, %3
    dw port_callback.%4
%endmacro
sb_commands:
    dsp 01h, 0, SB_16, csp_upload
    dsp 02h, 1, SB_16, ignore
    dsp 03h, 0, SB_16, csp_read
    dsp 04h, 1, SB_16, ignore
    dsp 04h, 0, SB_PRO, pro_status
    dsp 04h, 0, SB_20, sb20_status
    dsp 05h, 2, SB_16, ignore
    dsp 08h, 0, SB_16, csp_read
    dsp 08h, 0, SB_PRO, halt
    dsp 09h, 0, SB_16, csp_name
    dsp 0ah, 0, SB_16, csp_lock
    dsp 0bh, 1, SB_16, halt
    dsp 0ch, 1, SB_16, halt
    dsp 0eh, 2, SB_16, ignore
    dsp 0fh, 1, SB_16, csp_read
    dsp 10h, 1, SB_ALL, direct_dac
    dsp 14h, 2, SB_ALL, single8
    dsp 16h, 2, SB_ALL, adpcm
    dsp 17h, 2, SB_ALL, adpcm
    dsp 1ch, 0, SB_ALL, legacy_start
    dsp 1eh, 0, SB_16 | SB_PRO, adpcm
    dsp 1fh, 0, SB_ALL, adpcm
    dsp 20h, 0, SB_ALL, direct_input
    dsp 24h, 2, SB_ALL, single8
    dsp 2ch, 0, SB_ALL, legacy_start
    dsp 30h, 0, SB_ALL, midi_input
    dsp 31h, 0, SB_20, midi_input
    dsp 34h, 0, SB_ALL, midi_uart
    dsp 35h, 0, SB_20, midi_uart
    dsp 36h, 0, SB_20, midi_uart
    dsp 37h, 0, SB_20, midi_uart
    dsp 38h, 1, SB_ALL, midi_out
    dsp 40h, 1, SB_ALL, time_constant
    dsp 41h, 2, SB_16, rate
    dsp 42h, 2, SB_16, rate
    dsp 43h, 2, SB_16, rate
    dsp 48h, 2, SB_ALL, block_size
    dsp 4ch, 2, SB_16, ignore
    dsp 4dh, 1, SB_16, zero_reply
    dsp 4eh, 2, SB_16, timer_once
    dsp 4fh, 0, SB_16, timer_switch
    dsp 74h, 2, SB_ALL, adpcm
    dsp 75h, 2, SB_ALL, adpcm
    dsp 76h, 2, SB_ALL, adpcm
    dsp 77h, 2, SB_ALL, adpcm
    dsp 7ch, 0, SB_16 | SB_PRO, adpcm
    dsp 7dh, 0, SB_ALL, adpcm
    dsp 7eh, 0, SB_16 | SB_PRO, adpcm
    dsp 7fh, 0, SB_ALL, adpcm
%ifdef VIRTUAL_IRQ
    dsp 80h, 2, SB_ALL, silence
%endif
    dsp 90h, 0, SB_ALL, legacy_start
    dsp 91h, 0, SB_ALL, legacy_start
    dsp 98h, 0, SB_ALL, legacy_start
    dsp 99h, 0, SB_ALL, legacy_start
    dsp 0a0h, 0, SB_PRO, input_mono
    dsp 0a8h, 0, SB_PRO, input_stereo
    dsp 0d0h, 0, SB_ALL, pause8
    dsp 0d1h, 0, SB_ALL, speaker_on
    dsp 0d3h, 0, SB_ALL, speaker_off
    dsp 0d4h, 0, SB_ALL, resume8
    dsp 0d5h, 0, SB_16, pause16
    dsp 0d6h, 0, SB_16, resume16
    dsp 0d8h, 0, SB_ALL, speaker_status
    dsp 0d9h, 0, SB_16, exit16
    dsp 0dah, 0, SB_ALL, exit8
    dsp 0dch, 1, SB_16, ignore
    dsp 0e0h, 1, SB_ALL, invert
    dsp 0e1h, 0, SB_ALL, version
    dsp 0e2h, 1, SB_ALL, identify
    dsp 0e3h, 0, SB_16, copyright
    dsp 0e4h, 1, SB_ALL, test_write
    dsp 0e8h, 0, SB_ALL, test_read
    dsp 0f1h, 0, SB_PRO, pro_port
    dsp 0f2h, 0, SB_ALL, force_irq
    dsp 0f3h, 0, SB_16, force_irq16
    dsp 0f4h, 0, SB_16, dsp_signature
    dsp 0f8h, 0, SB_ALL, zero_reply
    dsp 0f9h, 1, SB_16, ram_read
    dsp 0fah, 2, SB_16, ram_write
    dsp 0fbh, 0, SB_16, dsp_status
    dsp 0fch, 0, SB_16, dsp_auxiliary
    dsp 0fdh, 0, SB_16, last_command
    db 0ffh
%unmacro dsp 4

; AL=2xCh's and 2xEh's value with bit 7 clear: 7Fh on the SB16, 2Ah on the
; cards before it (port_callback .ready, .status).
dsp_status_base:
    mov al, 7fh
    cmp byte [virtual_model], 0
    je .done
    mov al, 2ah
.done:
    ret

; AX=a rate in hertz: AL=the SB16's rate register for it, AH=0, as the DSP
; 4.13 works it out (X09a7): 1Ch below 4864 Hz, FFh from 45312 Hz, else 23 x
; rate / 4096 rounded, with the low byte's product cut to its high byte
; first. (The 4.05 drops a carry in that sum, so 1652 rates play 2849 Hz
; slow on it; the 4.13 keeps it [fw; the CT2290 plays 22900 Hz right].)
sb16_rate_register:
    cmp ah, 13h
    jb .floor
    cmp ah, 0b1h
    jae .ceiling
    push bx
    push cx
    mov cl, al
    movzx bx, ah
    imul bx, bx, 23
    mov al, 23
    mul cl
    movzx ax, ah
    add ax, bx
    ; Rounded: the last bit shifted out is added back.
    shr ax, 3
    inc ax
    shr ax, 1
    pop cx
    pop bx
    ret
.floor:
    mov ax, 1ch
    ret
.ceiling:
    mov ax, 0ffh
    ret

; AL=a rate register: AX=the rate it plays, its count times 4096/23 Hz (the
; firmware's step; the CT2290 measured a little slower, 176.9-177.9 Hz a
; step, to be measured finer). Other registers kept.
sb16_register_rate:
    push ecx
    push edx
    movzx eax, al
    shl eax, 12
    xor edx, edx
    mov ecx, 23
    div ecx
    pop edx
    pop ecx
    ret

; The rate register for each time constant 00h-EBh, the DSP 4.13's
; samplerate_table. The 4.05's has C8h at C8h, 35617 Hz, where this one has
; 64h, 17809 Hz [fw; the CT2290 plays C8h near 17.8 kHz].
sb16_time_table:
    db 15h, 16h, 16h, 16h, 16h, 16h, 16h, 16h, 16h, 16h, 16h, 16h
    db 17h, 17h, 17h, 17h, 17h, 17h, 17h, 17h, 17h, 17h, 18h, 18h
    db 18h, 18h, 18h, 18h, 18h, 18h, 18h, 18h, 19h, 19h, 19h, 19h
    db 19h, 19h, 19h, 19h, 1ah, 1ah, 1ah, 1ah, 1ah, 1ah, 1ah, 1ah
    db 1bh, 1bh, 1bh, 1bh, 1bh, 1bh, 1bh, 1bh, 1ch, 1ch, 1ch, 1ch
    db 1ch, 1ch, 1ch, 1dh, 1dh, 1dh, 1dh, 1dh, 1dh, 1eh, 1eh, 1eh
    db 1eh, 1eh, 1eh, 1fh, 1fh, 1fh, 1fh, 1fh, 1fh, 20h, 20h, 20h
    db 20h, 20h, 21h, 21h, 21h, 21h, 21h, 22h, 22h, 22h, 22h, 22h
    db 23h, 23h, 23h, 23h, 24h, 24h, 24h, 24h, 25h, 25h, 25h, 25h
    db 26h, 26h, 26h, 26h, 27h, 27h, 27h, 27h, 28h, 28h, 28h, 29h
    db 29h, 29h, 29h, 2ah, 2ah, 2ah, 2bh, 2bh, 2bh, 2ch, 2ch, 2dh
    db 2dh, 2dh, 2eh, 2eh, 2eh, 2fh, 2fh, 30h, 30h, 30h, 31h, 31h
    db 32h, 32h, 33h, 33h, 34h, 34h, 35h, 35h, 36h, 36h, 37h, 37h
    db 38h, 38h, 39h, 39h, 3ah, 3bh, 3bh, 3ch, 3dh, 3dh, 3eh, 3fh
    db 3fh, 40h, 41h, 42h, 42h, 43h, 44h, 45h, 46h, 47h, 48h, 49h
    db 49h, 4ah, 4bh, 4dh, 4eh, 4fh, 50h, 51h, 52h, 53h, 55h, 56h
    db 57h, 59h, 5ah, 5ch, 5dh, 5fh, 60h, 62h, 64h, 66h, 68h, 6ah
    db 6ch, 6eh, 70h, 72h, 75h, 77h, 7ah, 7ch, 7fh, 82h, 85h, 89h
    db 8ch, 90h, 93h, 97h, 9ch, 0a0h, 0a5h, 0aah, 0afh, 0b5h, 0bbh, 0c1h
    db 0c8h, 0d0h, 0d8h, 0e0h, 0eah, 0f4h, 0ffh, 0ffh

%endif

dma_unowned_write:
%ifdef RESIDENT_AUDIO
    cmp byte [sb_running], 0
    je dma_shared_write
    mov ah, al
    and ah, 3
    cmp byte [sound_card], 0
    je .high_output
    cmp si, dma8
    jne dma_shared_write
    cmp ah, [sb_dma8]
    je .done
    jmp dma_shared_write
.high_output:
    cmp si, dma16
    jne dma_shared_write
    add ah, 4
    cmp ah, [sb_dma16]
    jne dma_shared_write
.done:
    ret
%else
    jmp dma_shared_write
%endif

%include "audio/direct_write.asm"

; CF set when the controller of SI carries the physical output ring.
dma_ring_controller:
%ifdef RESIDENT_AUDIO
    cmp byte [sb_running], 0
    je .no
    cmp byte [sound_card], 0
    je .high_ring
    cmp si, dma8
    jne .no
    stc
    ret
.high_ring:
    cmp si, dma16
    jne .no
    stc
    ret
.no:
%endif
    clc
    ret

dma_shared_write:
    push dx
    cmp si, dma16
    jne .write
    sub dx, 0ah
    shl dx, 1
    add dx, 0d4h
.write:
    call physical_write
    pop dx
    ret

dma_port:
    mov si, dma8
    cmp dx, [guest_dma_ports+4]
    je .low_page
    cmp dx, [guest_dma_ports]
    je .low_address
    cmp dx, [guest_dma_ports+2]
    je .low_count
    cmp dx, [guest_dma_ports+10]
    je .page
    cmp dx, [guest_dma_ports+6]
    je .address
    cmp dx, [guest_dma_ports+8]
    je .count
    cmp dx, 0d0h
    jb .done
    cmp dx, 0deh
    ja .done
    test dl, 1
    jnz .done
    sub dx, 0c0h
    shr dx, 1
    jmp .high
.low_page:
    mov dx, 83h
    ret
.low_address:
    mov dx, 2
    ret
.low_count:
    mov dx, 3
    ret
.page:
    mov dx, 83h
    jmp .high
.address:
    mov dx, 2
    jmp .high
.count:
    mov dx, 3
.high:
    mov si, dma16
.done:
    ret

trap_ports:
%include "audio/ports.inc"
    dw 0
trapped_count dw 0
callback_set db 0
trap_remove_failed db 0
old_callback dd 0
port_calls dd 0
last_clock dd 0
game_start_pending db 0 ; 1: wait for mixing, 2: wait for output.
game_dma dw dma8
game_frame_shift db 0
game_source db 0
pending_frame_shift db 0
game_irq_bit db 1
; Bit 0: 16-bit mono. Bit 1: unsigned 16-bit. Bit 2: signed 8-bit.
game_format db 0
pending_format db 0
; E3h on a DSP 4.xx: the text the CT1741 firmware sends, zero included. While
; reply_pointer is set the write port reads busy and commands are dropped.
reply_pointer dw 0
%ifdef SB_CARDS
copyright_text db 'COPYRIGHT (C) CREATIVE TECHNOLOGY LTD, 1992.',0
copyright_length equ $-copyright_text
%endif
game_block_bytes dd 4096
game_exit_frame dd 0
game_mix_frame dd 0
; The last auto-init position game_elapsed gave, output frames since the
; start: the count never moves back within a transfer (vsb-spec 7.8).
game_position dd 0
virtual_resets dw 0
virtual_starts dw 0
virtual_mixer_index db 0
%include "audio/mixer.asm"
%include "audio/sb_mixer.asm"
; The register image (audio/sb_mixer.asm): set at install, FFh where the
; chip has nothing; the gains at 30h-37h start at 0 dB.
virtual_mixer:
    times 30h db 0ffh
    times 8 db 0f8h
    times 256-38h db 0ffh
dma8 db 0,1,0,0
    dw 0,0,0
    dd 0
    db 49h
dma16 db 0,1,0,0
    dw 0,0,0
    dd 0
    db 59h
dsp_command db 0
; Argument bytes still to come, and those taken so far into dsp_args.
arguments db 0
arguments_got db 0
dsp_args times 3 db 0
; The handler the command runs once its arguments are in (sb_commands).
dsp_handler dw 0
rate_pending dw 0
legacy_pending dw 0
block_low db 0
legacy_block dw 07ffh
legacy_rate dw 10000
; The replies waiting at 2xAh (sb_reply_put), oldest at reply_head; while a
; string reply is read (reply_pointer), reply_count counts its bytes.
REPLY_QUEUE equ 8
reply_queue times REPLY_QUEUE db 0
reply_head db 0
reply_count db 0
; The last byte read from 2xAh, which it reads again with nothing waiting.
reply_last db 0aah
; Set between a reset's 1 and its 0.
sb_reset_held db 0
; Set while a high-speed transfer (90h, 91h) runs on the SB 2.0 or SB Pro.
sb_highspeed db 0
; Set in the SB-MIDI UART modes (34h-37h).
sb_midi_uart db 0
; 8 when the command being started records (24h, 2Ch, 98h, 99h, Bxh and Cxh
; with bit 3), else 0.
pending_input db 0
; The SB Pro's input mode: A8h stereo, A0h mono.
sb_input_stereo db 0
; The ADPCM command being started: its kind (audio/sb_adpcm.asm) and 1
; when it starts with the reference byte.
pending_adpcm db 0
pending_adpcm_ref db 0
sb_id_value db 0aah
sb_id_phase db 0
; Set in high-speed and UART modes, where a reset is the firmware's warm
; start (port_callback .reset_hold); a single-cycle block's end clears it.
sb_warm db 0
; Set while the DSP takes nothing: 1 until a reset (port_callback .halt), 2
; until the DMA takes an E2h byte or a reset (sb_identify).
sb_hung db 0
; The SB16 DSP's timer (4Eh, 4Fh) runs with reload.
sb_timer db 0
; The command byte last written and the one before it (FDh, F9h).
sb_command_byte db 0
sb_previous_command db 0
; A single-cycle command waiting for the transfer before it to end
; (sb_queue_check): its byte, arguments and handler.
sb_queued db 0
sb_queue_command db 0
sb_queue_args times 3 db 0
sb_queue_handler dw 0
; An auto-init transfer's frames at the end of the block it is to end with.
sb_exit_frames dd 0
%ifdef WSS_INPUT
%include "audio/wss_state.inc"
%else
; The host's pointer to the WSS interrupt to deliver (resident_host_init):
; none in a build without the virtual codec.
wss_irq_event dw 0
%endif
