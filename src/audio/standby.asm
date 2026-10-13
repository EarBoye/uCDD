; SPDX-FileCopyrightText: 2026 vorvek
; SPDX-License-Identifier: GPL-3.0-only

; Stepping aside. While no mounted image is bound for CD audio and the
; virtual card is one the physical card can be at the same port, IRQ and DMA
; channels, the driver has nothing to add to the game's sound: the physical
; output stops, the card's and the controllers' ports are untrapped, and the
; host neither offers DPMI nor hides VCPI, so a game talks to the real card
; and runs as it does without the driver. The state changes only from the
; control entry, at a mount or an eject, and at the end of the install, never
; while a game runs. config_audio_always keeps the output on.

audio_engaged db 1

; Carry clear when the physical card can stand in for the virtual one.
audio_pairing:
    cmp byte [config_audio_always], 0
    jne .no
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
    jae .pro_or_sb
    cmp al, 2
    jne .no
    ; A WSS codec is nothing a Sound Blaster driver finds; an ESS is an SB
    ; Pro with a DSP 3.01.
    cmp byte [ess_native], 0
    je .no
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

; From the control entry after a mount or an eject, and from the end of the
; install: engage or step aside as the bound disc and the pairing require.
; DS=CS, the driver's stack, interrupts on, InDOS clear (the control entry
; checks it) or inside dos_enter. Engaging must not fail where the install
; succeeded: the same calls run on the same card.
audio_reconsider:
    call audio_pairing
    jc .engage
    cmp word [cd_handle], 0ffffh
    jne .engage
%ifdef MDM_SUPPORT
    cmp byte [mdm_audio], 0
    jne .engage
%endif
    cmp byte [audio_engaged], 0
    je .done
    ; Not while a game streams through the virtual card or a client runs
    ; under the host: the next mount or eject decides again.
    cmp byte [game_active], 0
    jne .done
%ifdef OWN_HOST
    cmp word [own_host_active+2], 0
    je .release
    les di, [own_host_active]
    cmp byte [es:di], 0
    jne .done
.release:
%endif
    call audio_release
.done:
    ret
.engage:
    cmp byte [audio_engaged], 0
    jne .done
    call audio_engage
    ret

; The inverse of the install's tail: output stopped (the vector and the PIC
; mask put back, the mixer registers restored, the DSP reset), the ports
; given back, the host dormant. The keyboard port stays trapped for the
; hotkeys, and the timer and BIOS disk hooks stay: they do nothing while
; nothing is bound.
audio_release:
    call sb_stop
    call virtual_irq_reset
    mov byte [virtual_pic_service], 0
    mov byte [virtual_pic_delivered], 0
    call trap_release
    call host_dormant
    mov byte [audio_engaged], 0
    ret

; The install's tail again: the virtual PIC's view of the mask, two silent
; halves in the ring, the ports, the card, the host.
audio_engage:
    call virtual_irq_init
    mov ax, [output_segment]
    mov es, ax
    xor di, di
    call mix_half
    call mix_half
    call trap_engage
    jc .failed
    call sb_start
    jc .failed
    call host_wake
    mov byte [audio_engaged], 1
    ret
.failed:
    ; Stepped aside with a disc bound: silent CD audio. audio_report shows
    ; the fault byte.
    or byte [fault], 80h
    ret

; The host's dormant byte: with it set, INT 2Fh AX=1687h chains (no DPMI
; offered) and INT 67h AX=DE00h chains (VCPI visible), so a protected-mode
; game runs under its own extender, as without the driver.
host_dormant:
    mov al, 1
    jmp host_dormant_set
host_wake:
    xor al, al
host_dormant_set:
%ifdef OWN_HOST
    cmp word [own_host_active+2], 0
    je .done
    les di, [own_host_active]
    mov [es:di+4], al
.done:
%endif
    ret
