; SPDX-FileCopyrightText: 2026 vorvek
; SPDX-License-Identifier: GPL-3.0-only

; UCDDSET checked the virtual card and the volumes in config_data.
guest_configure:
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
    movzx edi, byte [config_game_volume]
    cmp di, 100
    je .levels
    mov ebx, 100
    mov si, sb_pcm_gain
    mov cx, 2
    call guest_scale
%ifdef WSS_INPUT
    mov si, wss_attenuation
    mov cx, 64
    call guest_scale
%endif
.levels:
    call guest_ports_init
    call virtual_mixer_install
    call cd_gain_update
    ret

; SI dword table, CX count, EDI percent, EBX 100.
guest_scale:
    mov eax, [si]
    imul eax, edi
    xor edx, edx
    div ebx
    mov [si], eax
    add si, 4
    loop guest_scale
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
