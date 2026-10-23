; SPDX-FileCopyrightText: 2026 vorvek
; SPDX-License-Identifier: GPL-3.0-only

; UCDDSET checked the virtual card and the volumes in config_data.
guest_configure:
%ifdef ESS_CARD
    ; The ESS build presents the virtual ESS AudioDrive, DSP 3.01 (UCDDSET
    ; offers nothing else in it).
    mov byte [virtual_model], 4
    mov word [virtual_dsp_version], 0103h
%else
    ; The Sound Blaster build presents an SB Pro for a configuration made
    ; for the virtual ESS.
    cmp byte [virtual_model], 4
    jne .model_ready
    mov byte [virtual_model], 1
    mov word [virtual_dsp_version], 0203h
.model_ready:
    ; The SB16 is a DSP 4.13 (trap.asm), whatever an older UCDD.CFG holds.
    cmp byte [virtual_model], 0
    jne .version_ready
    mov word [virtual_dsp_version], 0d04h
.version_ready:
%endif
    ; The DSP after power-on, as the firmware's cold start leaves it
    ; (trap.asm, sb_cold_start): 10000 Hz, whose step the first transfer
    ; works out, and the speaker off, on the SB16 only its flag.
    cmp byte [virtual_model], 4
    je .defaults_ready
    mov word [game_rate], 10000
    mov byte [sb_speaker_flag], 0
    cmp byte [virtual_model], 0
    je .defaults_ready
    mov byte [sb_speaker], 0
.defaults_ready:
    mov ax, [virtual_base]
    mov [guest_base], ax
    movzx ax, byte [virtual_irq]
    mov [guest_irq], ax
    mov al, [virtual_dma8]
    mov [guest_dma8], ax
    mov al, [virtual_dma16]
    mov [guest_dma16], ax
%ifdef WSS_INPUT
    ; A game can still select another IRQ in the WSS board register.
    mov al, [virtual_wss_irq]
    mov [wss_guest_irq], ax
%endif
    call guest_ports_init
    call virtual_mixer_install
    ; The game's PCM level through the PCM fader (the author's 0.9.4-a6), once
    ; the virtual mixer holds its reset levels.
    call sb_pcm_update
    call cd_gain_update
    ret

guest_ports_init:
    mov si, guest_dma_ports
    mov cx, 6
.dma_port:
    lodsw
    call guest_port_translate
    mov [si-2], ax
    loop .dma_port
    mov si, trap_ports
.port:
    lodsw
    test ax, ax
    jz .ports_ready
    call guest_port_translate
    mov [si-2], ax
    jmp .port
.ports_ready:
%ifndef OWN_HOST
    mov si, pm_trap_ports
    mov cx, pm_port_count
.pm_port:
    mov ax, [si]
    call guest_port_translate
    mov [si], ax
    add si, 4
    loop .pm_port
%endif
    mov al, [guest_irq]
    add al, 8
    mov [guest_vector], al
    mov cl, [guest_irq]
    mov al, 1
    shl al, cl
    mov [guest_irq_bit], al
    mov ah, al
    dec ah
    mov [guest_irq_higher], ah
    or ah, al
    mov [guest_irq_priority], ah
    mov al, [guest_irq]
    or al, 60h
    mov [guest_eoi], al
    ret

; The virtual mixer at install (audio/sb_mixer.asm): the reset values with
; every level at its top, as the card's own setup program leaves it, and CD
; audio at 0 dB. The SB 2.0 has no mixer and its gains stay at 0 dB.
virtual_mixer_install:
    call virtual_mixer_reset
    mov eax, 0f8f8f8f8h
    mov [virtual_mixer+30h], eax
    mov [virtual_mixer+34h], eax
    cmp byte [virtual_model], 1
    ja .done
    mov al, 0ffh
    mov [virtual_mixer+4], al
    mov [virtual_mixer+22h], al
    mov [virtual_mixer+26h], al
    mov [virtual_mixer+28h], al
.done:
    ret

; AX is a default trap port. Return the selected guest port.
guest_port_translate:
    cmp ax, 224h
    jb .dma
    cmp ax, 22fh
    ja .wss
    sub ax, 220h
    add ax, [guest_base]
    ret
.wss:
    cmp ax, 530h
    jb .done
    cmp ax, 537h
    ja .done
    sub ax, 530h
    add ax, [virtual_wss_base]
    ret
.dma:
    cmp ax, 2
    je .low
    cmp ax, 3
    je .low
    cmp ax, 83h
    je .low_page
    cmp ax, 8bh
    je .high_page
    cmp ax, 0c4h
    je .high
    cmp ax, 0c6h
    jne .done
.high:
    mov bx, [guest_dma16]
    sub bx, 5
    shl bx, 2
    add ax, bx
    ret
.high_page:
    mov bx, [guest_dma16]
    mov al, [guest_dma_pages+bx]
    ret
.low_page:
    mov bx, [guest_dma8]
    mov al, [guest_dma_pages+bx]
    ret
.low:
    mov bx, [guest_dma8]
    dec bx
    shl bx, 1
    add ax, bx
.done:
    ret

guest_dma_pages db 87h,83h,81h,82h,8fh,8bh,89h,8ah
