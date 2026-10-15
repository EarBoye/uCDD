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

; Carry clear when stepping aside is allowed: the switch off and the cards
; paired (audio/pairing.asm, shared with UCDDSET).
audio_pairing:
    cmp byte [config_audio_always], 0
    jne .no
    jmp card_pairing
.no:
    stc
    ret

%include "audio/pairing.asm"

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
    ; Cleared first: sb_stop puts the old vector back through INT 21h, and
    ; sb_dos_vector must let that call through (it takes a set of the guest
    ; vector for a game's while the driver is engaged).
    mov byte [audio_engaged], 0
    call sb_stop
    call fast_dma_clear
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
    ; sb_start hooks the vector through INT 21h while the byte is still
    ; clear, so the call reaches DOS.
    call sb_start
    jc .failed
    call fast_dma_set
    call host_wake
    mov byte [audio_engaged], 1
    ret
.failed:
    ; Stepped aside with a disc bound: silent CD audio. audio_report shows
    ; the fault byte.
    or byte [fault], 80h
    ret

; Type F ISA DMA on the output channel (82371FB data sheet, MBDMA0 at PCI
; configuration offset 76h of the ISA bridge: bit 7 fast, bits 2:0 the
; channel, bits 6:3 kept as read since the PIIX3 and PIIX4 hold a reserved
; bit there, except that the PIIX's bit 3 is set). Type F serves the
; output, which reads memory; the PIIX has no Type F for transfers that
; write it. Only with the UCDDSET switch on and a PIIX found at install;
; set when the output starts, the old byte put back when it stops. The
; register is read and written through the PCI BIOS.
fast_dma_set:
    cmp byte [config_fast_dma], 0
    je .done
    cmp byte [fast_dma_present], 0
    je .done
    cmp byte [fast_dma_active], 0
    jne .done
    mov bx, [fast_dma_bridge]
    mov di, 76h
    mov ax, 0b108h
    int 1ah
    jc .done
    test ah, ah
    jnz .done
    mov [fast_dma_saved], cl
    and cl, 78h
    or cl, 80h
    ; On the PIIX, bit 3 (DMC) picks the ISA slot's DREQ and DACK# over the
    ; motherboard pair for the channel; left at 0, the card is cut off (PIIX
    ; and PIIX3 data sheet, MBDMA registers). The PIIX3 and PIIX4 keep it
    ; reserved, so the read value stays there.
    cmp word [fast_dma_device], 122eh
    jne .fast_bits
    or cl, 8
.fast_bits:
    ; The output channel: the high one on an SB16, the low one elsewhere.
    mov al, [sb_dma8]
    cmp byte [sound_card], 0
    jne .channel
    mov al, [sb_dma16]
.channel:
    and al, 7
    or cl, al
    mov ax, 0b10bh
    int 1ah
    jc .done
    test ah, ah
    jnz .done
    mov byte [fast_dma_active], 1
.done:
    ret
fast_dma_clear:
    cmp byte [fast_dma_active], 0
    je .done
    mov byte [fast_dma_active], 0
    mov bx, [fast_dma_bridge]
    mov di, 76h
    mov cl, [fast_dma_saved]
    mov ax, 0b10bh
    int 1ah
.done:
    ret
; Set at install by fast_dma_scan (disk_scan.asm).
fast_dma_bridge dw 0
; The bridge's PCI device ID (fast_dma_scan).
fast_dma_device dw 0
fast_dma_present db 0
fast_dma_active db 0
fast_dma_saved db 0

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
