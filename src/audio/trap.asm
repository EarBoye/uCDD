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
    call .count
    mov bx, ax
    call .count
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
    movzx eax, ax
    mov ebx, RING_WORDS-1
    sub ebx, eax
    shr ebx, 1
    mov eax, [periods]
    shl eax, OUTPUT_SHIFT
    mov edx, eax
    xor edx, ebx
    test edx, PERIOD_FRAMES
    jz .same_half
    add eax, PERIOD_FRAMES
.same_half:
    and ebx, PERIOD_FRAMES-1
    add eax, ebx
    mov [last_clock], eax
    ret
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
    pop bx
    ret

game_elapsed:
    cmp byte [game_start_pending], 1
    je .zero
    cmp byte [game_source], 0
    jne .output
    cmp byte [sb_single], 0
    jne .output
    mov eax, [game_mix_frame]
    cmp byte [sb_paused], 0
    je .done
    mov eax, [sb_pause_mix_frame]
    ret
.output:
    call output_clock
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
    cmp dx, 226h
    je .reset
    cmp dx, 22ch
    je .command
    cmp dx, 22ah
    je .done
    cmp dx, 224h
    je .mixer_index
    cmp dx, 225h
    je .mixer_data
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
    mov [virtual_mixer_index], al
    mov al, ah
    jmp .mixer_data
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
.reset:
    mov byte [sb_id_value], 0aah
    mov byte [sb_id_phase], 0
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
    mov byte [sb_speaker], 1
    mov byte [sb_speaker_flag], 1
    mov byte [sb_filter_legacy], 0
    mov byte [game_active], 0
    mov byte [game_start_pending], 0
    mov dword [game_exit_frame], 0
%ifdef VIRTUAL_IRQ
    mov byte [sb_silence], 0
    call virtual_irq_reset
%endif
    inc word [virtual_resets]
    mov word [reply], 0aah
    mov byte [reply_count], 1
    mov word [reply_pointer], 0
    mov byte [arguments], 0
    jmp .done
.mixer_index:
    mov [virtual_mixer_index], al
    jmp .done
.mixer_data:
    movzx bx, byte [virtual_mixer_index]
    cmp bl, 0fh
    je .done
    cmp bl, 80h
    je .done
    cmp bl, 81h
    je .done
    test bl, bl
    jz .mixer_reset
.mixer_store:
    mov [virtual_mixer+bx], al
    cmp bl, 0eh
    jne .mixer_volume
    and al, 20h
    mov [sb_filter_bypass], al
    jmp .done
.mixer_volume:
    ; 14h is the ESS's full-width twin of 04h, on every model. The ESS's
    ; other twins (32h master, 36h FM, 38h CD) are routed above.
    cmp bl, 14h
    je .voice_pair
    cmp bl, 22h
    je .master_pair
    cmp bl, 28h
    je .cd_pair
    cmp bl, 26h
    je .fm_pair
    cmp bl, 4
    jne .volume16
.voice_pair:
    mov bx, 32h
    jmp .volume_pair
.master_pair:
    mov bx, 30h
    jmp .volume_pair
.cd_pair:
    mov bx, 36h
    jmp .volume_pair
.fm_pair:
    mov bx, 34h
.volume_pair:
    mov ah, al
    and al, 0f0h
    or al, 8
    mov [virtual_mixer+bx], al
    shl ah, 4
    or ah, 8
    mov [virtual_mixer+bx+1], ah
    jmp .volume_update
.volume16:
    cmp bl, 30h
    jb .done
    cmp bl, 37h
    ja .done
    and bl, 0feh
    mov al, [virtual_mixer+bx]
    and al, 0f0h
    mov ah, [virtual_mixer+bx+1]
    shr ah, 4
    or al, ah
    cmp bl, 30h
    jne .cd_view
    mov [virtual_mixer+22h], al
    jmp .volume_update
.cd_view:
    cmp bl, 36h
    jne .fm_view
    mov [virtual_mixer+28h], al
    jmp .volume_update
.fm_view:
    cmp bl, 34h
    jne .voice_view
    mov [virtual_mixer+26h], al
    jmp .volume_update
.voice_view:
    mov [virtual_mixer+4], al
.volume_update:
%ifdef MOUNTED_AUDIO
    call cd_gain_update
%endif
%ifdef RESIDENT_AUDIO
    call fm_update
%endif
.voice_gain:
    call sb_pcm_update
    jmp .done
.mixer_reset:
    ; Register 00h restores the SB16 defaults.
    push cs
    pop es
    mov di, virtual_mixer
    mov cx, 40h
    xor eax, eax
    cld
    rep stosw
    mov [sb_filter_bypass], al
    mov al, 0cch
    mov [virtual_mixer+4], al
    mov [virtual_mixer+22h], al
    mov [virtual_mixer+26h], al
    mov [virtual_mixer+28h], al
    mov eax, 0c0c0c0c0h
    mov [virtual_mixer+30h], eax
    mov [virtual_mixer+34h], ax
    mov [virtual_mixer+36h], ax
    mov dword [virtual_mixer+3ch], 0b151fh
    mov dword [virtual_mixer+44h], 80808080h
    jmp .volume_update
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
    ; The virtual ESS is programmed with demand-mode transfers (B9h): the
    ; emulation moves data a period at a time whatever the request mode, so
    ; demand mode is kept as the single mode of the same kind.
    cmp byte [virtual_model], 4
    jne .mode_value
    test al, 0c0h
    jnz .mode_value
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
.command:
    cmp byte [arguments], 0
    jne .argument
    ; The DSP sends a string reply one byte at a time and waits for each
    ; read, so it takes no command until the string is read and its write
    ; port reads busy meanwhile (.ready). A command written anyway is
    ; dropped here; the chip would hold it in its mailbox.
    cmp word [reply_pointer], 0
    jne .done
    mov [dsp_command], al
.common_command:
    cmp al, 10h
    je .time_constant
    cmp al, 41h
    je .rate
    cmp al, 42h
    je .input_rate
    cmp al, 40h
    je .time_constant
    cmp al, 48h
    je .rate
    cmp al, 14h
    je .rate
    cmp al, 24h
    je .rate
    cmp al, 1ch
    je .legacy_start
    cmp al, 90h
    je .legacy_start
    cmp al, 91h
    je .legacy_start
    cmp al, 0c6h
    je .play
    cmp al, 0c4h
    je .play
    cmp al, 0c0h
    je .play
    cmp al, 0c2h
    je .play
    cmp al, 0b0h
    je .play
    cmp al, 0b2h
    je .play
    cmp al, 0b6h
    je .play
    cmp al, 0b4h
    je .play
    cmp al, 0d0h
    je .pause8
    cmp al, 0d5h
    je .pause16
    cmp al, 0dah
    je .exit8
    cmp al, 0d9h
    je .exit16
    cmp al, 0d4h
    je .resume8
    cmp al, 0d6h
    je .resume16
    cmp al, 0d3h
    je .speaker_off
    cmp al, 0d1h
    je .speaker_on
    cmp al, 0d8h
    je .speaker_status
    cmp al, 0e0h
    je .time_constant
    cmp al, 0e4h
    je .time_constant
    cmp al, 0e2h
    je .time_constant
    cmp al, 0e8h
    je .test_read
    cmp al, 0f2h
    je .force_irq
%ifdef VIRTUAL_IRQ
    cmp al, 80h
    je .rate
%endif
    ; Input modes of the SB Pro: nothing to set up for output.
    cmp al, 0a0h
    je .done
    cmp al, 0a8h
    je .done
    cmp al, 20h
    je .direct_input
    cmp al, 0f8h
    je .zero_reply
    cmp al, 0f3h
    je .force_irq16
    cmp al, 0e3h
    je .copyright
    cmp al, 0e1h
    jne .command_unsupported
    mov ax, [virtual_dsp_version]
    mov [reply], ax
    mov byte [reply_count], 2
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
    mov [reply], al
    mov byte [reply_count], 1
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
.input_rate:
    ; The SB16 uses one sample rate for output and input.
    mov byte [dsp_command], 41h
.rate:
    mov byte [arguments], 2
    jmp .done
.play:
    ; Both FIFO modes use the same PCM conversion and block interrupts.
    or byte [dsp_command], 2
    mov byte [arguments], 3
    jmp .done
.time_constant:
    mov byte [arguments], 1
    jmp .done
.legacy_start:
    mov ax, [legacy_block]
.legacy_format:
    push ax
    mov byte [pending_frame_shift], 0
    mov byte [pending_format], 0
    cmp byte [dsp_command], 24h
    je .legacy_mono
    test ax, ax
    jz .legacy_mono
    mov ax, [legacy_rate]
    test byte [virtual_mixer+0eh], 2
    jz .legacy_rate
    mov byte [pending_frame_shift], 1
    shr ax, 1
    jmp .legacy_rate
.legacy_mono:
    mov ax, [legacy_rate]
.legacy_rate:
    mov [game_rate], ax
    movzx eax, ax
    shl eax, 16
    xor edx, edx
    mov ecx, OUTPUT_RATE
    div ecx
    mov [game_step], eax
    pop ax
    jmp .validate_start
.argument:
    cmp byte [dsp_command], 10h
    jne .normal_argument
    call sb_dac_write
    jmp .argument_done
.normal_argument:
    cmp byte [dsp_command], 0e2h
    jne .invert_argument
    call sb_identify
    jc .command_unsupported
    jmp .argument_done
.invert_argument:
    cmp byte [dsp_command], 0e0h
    jne .test_argument
    not al
    mov [reply], al
    mov byte [reply_count], 1
    jmp .argument_done
.test_argument:
    cmp byte [dsp_command], 0e4h
    jne .pcm_argument
    mov [sb_test_register], al
    jmp .argument_done
.pcm_argument:
    ; Only the virtual ESS leaves 42h here (.input_or_ess): its one byte
    ; is the filter clock.
    cmp byte [dsp_command], 42h
    je .argument_done
    cmp byte [dsp_command], 14h
    je .length
%ifdef VIRTUAL_IRQ
    cmp byte [dsp_command], 80h
    je .silence
%endif
    cmp byte [dsp_command], 24h
    je .length
    cmp byte [dsp_command], 40h
    je .set_time_constant
    cmp byte [dsp_command], 48h
    je .legacy_length
    cmp byte [dsp_command], 41h
    jne .play_argument
    cmp byte [arguments], 2
    jne .rate_low
    mov [rate_pending+1], al
    jmp .argument_done
.rate_low:
    mov [rate_pending], al
.set_rate:
    ; The rate is checked before it replaces game_rate, which divides later.
    cmp word [rate_pending], 4000
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
    test byte [virtual_mixer+0eh], 2
    jz .legacy_rate_store
    cmp ax, 32768
    jae .legacy_rate_store
    shl ax, 1
.legacy_rate_store:
    mov [legacy_rate], ax
    movzx eax, word [game_rate]
    shl eax, 16
    xor edx, edx
    mov ecx, OUTPUT_RATE
    div ecx
    mov [game_step], eax
    jmp .argument_done
.play_argument:
    cmp byte [arguments], 3
    jne .length
    mov byte [pending_frame_shift], 0
    mov byte [pending_format], 0
    cmp byte [dsp_command], 0b2h
    je .format16
    cmp byte [dsp_command], 0b6h
    jne .mono_mode
.format16:
    test al, 0cfh
    jnz .command_unsupported
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
    jmp .argument_done
.stereo16:
    mov byte [pending_frame_shift], 2
    jmp .argument_done
.mono_mode:
    test al, 0cfh
    jnz .command_unsupported
    test al, 10h
    jz .unsigned8
    or byte [pending_format], 4
.unsigned8:
    test al, 20h
    jz .argument_done
    mov byte [pending_frame_shift], 1
    jmp .argument_done
.set_time_constant:
    movzx ecx, al
    neg ecx
    add ecx, 256
    mov eax, 1000000
    xor edx, edx
    div ecx
    cmp eax, 65535
    ja .command_unsupported
    mov [legacy_pending], ax
    test byte [virtual_mixer+0eh], 2
    jz .time_mono
    shr ax, 1
.time_mono:
    mov [rate_pending], ax
    jmp .set_rate
%ifdef VIRTUAL_IRQ
.silence:
    ; 80h: no output for the given number of samples less one at the current
    ; rate, then the 8-bit interrupt. Signalled from the output interrupt.
    cmp byte [arguments], 2
    jne .silence_length
    mov [block_low], al
    jmp .argument_done
.silence_length:
    mov ah, al
    mov al, [block_low]
    movzx eax, ax
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
    jmp .argument_done
%endif
.legacy_length:
    cmp byte [arguments], 2
    jne .legacy_high
    mov [legacy_block], al
    jmp .argument_done
.legacy_high:
    mov [legacy_block+1], al
    jmp .argument_done
.length:
    cmp byte [arguments], 2
    jne .start
    mov [block_low], al
    jmp .argument_done
.start:
    mov ah, al
    mov al, [block_low]
    cmp byte [dsp_command], 24h
    je .legacy_format
    cmp byte [dsp_command], 14h
    jne .validate_start
    jmp .legacy_format
.validate_start:
    mov byte [sb_finished], 0
    mov byte [sb_exit_pending], 0
    mov byte [sb_single], 0
    mov byte [sb_input], 0
    cmp byte [dsp_command], 24h
    jne .output_kind
    mov byte [sb_input], 1
    jmp .single
.output_kind:
    cmp byte [dsp_command], 0b2h
    je .single
    cmp byte [dsp_command], 0c2h
    je .single
    cmp byte [dsp_command], 14h
    je .single
    cmp byte [dsp_command], 91h
    jne .start_kind
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
    mov byte [game_start_pending], 1
    mov dword [game_exit_frame], 0
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
    ; The switchable 3.2 kHz output filter belongs to the SB and SB Pro. The
    ; SB16's output filter follows the sample rate, for legacy commands too.
    cmp byte [virtual_dsp_version], 4
    jae .filter_clear
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
    dec byte [arguments]
    jmp .done
%ifdef WSS_INPUT
%include "audio/wss_input.inc"
%endif
.read:
    cmp dx, 226h
    je .reset_read
%ifdef VIRTUAL_IRQ
    cmp dx, 20h
    je .pic_read
    cmp dx, 21h
    je .pic_read
%endif
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
.ready:
    ; Only bit 7 is defined; a card reads the other bits as set. Busy while
    ; a string reply waits to be read.
    mov al, 7fh
    cmp word [reply_pointer], 0
    je .result
    or al, 80h
    jmp .result
.status:
%ifdef VIRTUAL_IRQ
    and byte [virtual_dsp_irq], 0feh
%endif
    mov al, 7fh
    cmp byte [reply_count], 0
    je .result
    mov al, 0ffh
    jmp .result
.status16:
%ifdef VIRTUAL_IRQ
    and byte [virtual_dsp_irq], 0fdh
%endif
    mov al, 0ffh
    jmp .result
.reply:
    mov al, [reply]
    cmp byte [reply_count], 0
    je .result
    ; A string reply (reply_pointer set) reads from memory; the others from
    ; the reply word, low byte first.
    mov bx, [reply_pointer]
    test bx, bx
    jz .reply_word
    mov al, [bx]
    inc word [reply_pointer]
    dec byte [reply_count]
    jnz .result
    mov word [reply_pointer], 0
    jmp .result
.reply_word:
    shr word [reply], 8
    dec byte [reply_count]
    jmp .result
.mixer_read:
    movzx bx, byte [virtual_mixer_index]
    ; Reserved on the SB16. Writable storage here causes false mixer detection.
    cmp bx, 0fh
    mov al, 0ffh
    je .result
%ifdef VIRTUAL_IRQ
    cmp bx, 82h
    jne .mixer_value
    mov al, [virtual_dsp_irq]
    jmp .result
.mixer_value:
%endif

    mov al, [virtual_mixer+bx]
    jmp .result
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
    call game_elapsed
    ; An auto-initialised transfer's count follows the output clock, the
    ; frame being heard, as a real card's DMA counter does, rather than the
    ; mix, which runs one to two periods ahead in whole periods. HMI's
    ; drivers follow the count closely and rewrite the buffer right up to
    ; it: at the mix they caught frames not yet played (Descent 2 on the
    ; virtual ESS clicked about 40 times a second). The clock is never past
    ; the mix, so everything behind it has been read.
    cmp byte [sb_single], 0
    jne .elapsed_ready
    cmp byte [game_source], 0
    jne .elapsed_ready
    cmp byte [game_start_pending], 0
    jne .elapsed_ready
    push eax
    call output_clock
    cmp byte [sb_paused], 0
    je .played_clock
    mov eax, [sb_pause_clock]
.played_clock:
    sub eax, [game_started]
    jns .played_ready
    xor eax, eax
.played_ready:
    pop ecx
    cmp eax, ecx
    jbe .elapsed_ready
    mov eax, ecx
.elapsed_ready:
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

sb_identify:
    movzx bx, byte [sb_id_phase]
    xor al, [.masks+bx]
    add [sb_id_value], al
    inc bl
    and bl, 3
    mov [sb_id_phase], bl
    mov si, dma8
    cmp byte [si+DMA_MASK], 0
    jne .reply
    cmp byte [si+3], 0
    jne .reply
    mov al, [si+DMA_MODE]
    and al, 0ch
    cmp al, 4
    jne .reply
    cmp byte [game_active], 0
    jne .failed
    cmp byte [si+DMA_PAGE], 10h
    jae .failed
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
    jbe .done
    test byte [si+DMA_MODE], 10h
    jz .terminal
    mov dword [si+DMA_POSITION], 0
    jmp .done
.terminal:
    mov byte [si+3], 1
    jmp .done
.reply:
    mov al, [sb_id_value]
    mov [reply], al
    mov byte [reply_count], 1
.done:
    clc
    ret
.failed:
    stc
    ret
.masks db 96h,0a5h,69h,5ah

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
copyright_text db 'COPYRIGHT (C) CREATIVE TECHNOLOGY LTD, 1992.',0
copyright_length equ $-copyright_text
game_block_bytes dd 4096
game_exit_frame dd 0
game_mix_frame dd 0
virtual_resets dw 0
virtual_starts dw 0
virtual_mixer_index db 0
%include "audio/mixer.asm"
virtual_mixer:
    times 4 db 0
    db 0ffh
    times 22h-5 db 0
    db 0ffh
    times 26h-23h db 0
    db 0ffh
    db 0
    db 0ffh
    times 30h-29h db 0
    times 8 db 0f8h
    times 256-38h db 0
dma8 db 0,1,0,0
    dw 0,0,0
    dd 0
    db 49h
dma16 db 0,1,0,0
    dw 0,0,0
    dd 0
    db 59h
dsp_command db 0
arguments db 0
rate_pending dw 0
legacy_pending dw 0
block_low db 0
legacy_block dw 0
legacy_rate dw 22050
reply dw 0
reply_count db 0
sb_id_value db 0aah
sb_id_phase db 0
%ifdef RESIDENT_AUDIO
%endif
%ifdef WSS_INPUT
%include "audio/wss_state.inc"
%endif
