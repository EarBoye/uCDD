; SPDX-FileCopyrightText: 2026 vorvek
; SPDX-License-Identifier: GPL-3.0-only

; Carry clear when the physical card can stand in for the virtual one at the
; same port, IRQ and DMA channels: the rule the driver steps aside by, and
; the rule UCDDSET greys its "always on" box by. Shared by both.
card_pairing:
    mov ax, [sb_base]
    cmp ax, [virtual_base]
    jne .no
    mov al, [sb_irq]
    cmp al, [virtual_irq]
    jne .no
    mov al, [sb_dma8]
    cmp al, [virtual_dma8]
    jne .no
    ; AL physical model (0 SB16, 1 SB Pro, 2 WSS or ESS, 3 SB 1.5/2.0, 4 and 5
    ; ESS before sb_model), AH virtual model (0 SB16, 1 SB Pro, 3 SB 1.5/2.0).
    mov al, [sound_card]
    mov ah, [virtual_model]
    test al, al
    jnz .not_sb16
    ; An SB16 is every virtual model; its own needs the high channel too.
    test ah, ah
    jnz .pro_or_sb
    mov al, [sb_dma16]
    cmp al, [virtual_dma16]
    jne .no
    jmp .yes
.not_sb16:
    cmp al, 1
    je .pro_or_sb
    cmp al, 3
    jne .wss_or_ess
    ; An SB 1.5/2.0 is only itself.
    cmp ah, 3
    je .yes
    jmp .no
.wss_or_ess:
    cmp al, 4
    jae .ess
    cmp al, 2
    jne .no
    ; A WSS codec is nothing a Sound Blaster driver finds; an ESS is an SB
    ; Pro with a DSP 3.01, and itself.
    cmp byte [ess_native], 0
    je .no
.ess:
    cmp ah, 4
    je .yes
.pro_or_sb:
    cmp ah, 1
    je .yes
    cmp ah, 3
    je .yes
.no:
    stc
    ret
.yes:
    clc
    ret

