; SPDX-FileCopyrightText: 2026 vorvek
; SPDX-License-Identifier: GPL-3.0-only

; BX selects a stereo source. SI selects its channel.
sb_mixer_gain:
    push ebx
    push edx
    mov al, [virtual_mixer+bx+si]
    ; Curve bits: 1 voice, 2 master, 4 CD.
    mov ah, 1
    cmp bx, 32h
    je .source
    mov ah, 4
.source:
    call sb_mixer_level
    mov edx, eax
    mov al, [virtual_mixer+30h+si]
    mov ah, 2
    call sb_mixer_level
    imul eax, edx
    shr eax, 15
    pop edx
    pop ebx
    ret

sb_mixer_level:
    movzx ebx, al
    cmp byte [virtual_dsp_version], 4
    jb .pro
    ; The game last wrote the SB Pro register of this channel (AH is its bit).
    test [sb_pro_curve], ah
    jnz .pro
    shr bl, 3
    mov eax, [sb16_levels+ebx*4]
    ret
.pro:
    shr bl, 5
    mov eax, [sb_pcm_levels+ebx*4]
    ret

sb_pcm_update:
    pushad
    xor si, si
.channel:
    mov bx, 32h
    call sb_mixer_gain
%ifdef RESIDENT_AUDIO
    call game_scale
%endif
    movzx ebx, si
    mov [sb_pcm_gain+ebx*4], eax
    inc si
    cmp si, 2
    jb .channel
    popad
    ret

%ifdef RESIDENT_AUDIO
; AL left and AH right FM level in SB16 form. At installation, the virtual
; level starts as the physical card's level, so the FM fader at 100 percent
; keeps the card's setting.
fm_init:
    or ax, 0808h
    mov [virtual_mixer+34h], al
    mov [virtual_mixer+35h], ah
    and al, 0f0h
    shr ah, 4
    or al, ah
    mov [virtual_mixer+26h], al

; Set the physical FM level: the virtual level scaled by the FM fader. An SB16
; uses registers 34h and 35h. An SB Pro uses the two nibbles of register 26h.
; The audio IRQ also selects a mixer index, so the two port writes run with
; interrupts off. An unchanged level writes nothing.
fm_update:
    pushad
    cmp byte [sound_card], 1
    ja .done
    mov al, [virtual_mixer+34h]
    call fm_scale
    mov bl, al
    mov al, [virtual_mixer+35h]
    call fm_scale
    mov bh, al
    cmp bx, [fm_levels]
    je .done
    mov [fm_levels], bx
    pushf
    cli
    cmp byte [sound_card], 0
    jne .pro
    mov ah, bl
    shl ah, 3
    mov al, 34h
    call indexed_write
    mov ah, bh
    shl ah, 3
    mov al, 35h
    call indexed_write
    jmp .written
.pro:
    mov ah, bl
    shr ah, 1
    shl ah, 4
    mov al, bh
    shr al, 1
    or ah, al
    mov al, 26h
    call indexed_write
.written:
    popf
.done:
    popad
    ret

; AL virtual level register. Return AL level 0 to 31 scaled by the FM fader.
fm_scale:
    shr al, 3
    mul byte [config_fm_volume]
    add ax, 50
    mov cl, 100
    div cl
    ret

fm_levels db 0ffh,0ffh

; EAX gain. Return EAX scaled by the PCM fader.
game_scale:
    push ecx
    push edx
    movzx ecx, byte [config_game_volume]
    imul eax, ecx
    xor edx, edx
    mov ecx, 100
    div ecx
    pop edx
    pop ecx
    ret

; Set the physical master level from the master fader. The card formats
; follow UCDDSET: SB16 registers 30h and 31h, SB Pro register 22h, and the
; WSS codec output attenuation registers 6 and 7. AL is the first register,
; CL the second or 0, and AH the value.
master_update:
    pushad
    movzx ax, byte [config_master_volume]
    mov bl, [sound_card]
    cmp bl, 3
    je .done
    cmp bl, 2
    je .wss
    mov cx, 31
    test bl, bl
    jz .scale
    mov cx, 15
.scale:
    mul cx
    add ax, 50
    mov cl, 100
    div cl
    test bl, bl
    jnz .pro
    shl al, 3
    mov ah, al
    mov al, 30h
    mov cl, 31h
    jmp .write
.pro:
    mov ah, 11h
    mul ah
    mov ah, al
    mov al, 22h
    xor cl, cl
    jmp .write
.wss:
    test ax, ax
    jz .mute
    mov cx, 63
    mul cx
    add ax, 50
    mov cl, 100
    div cl
    mov ah, 63
    sub ah, al
    jmp .codec
.mute:
    mov ah, 80h
.codec:
    mov al, 6
    mov cl, 7
.write:
    mov [master_register], ah
    pushf
    cli
    call indexed_write
    test cl, cl
    jz .written
    mov al, cl
    call indexed_write
.written:
    popf
.done:
    popad
    ret

; Apply the PCM fader to the game levels of the virtual cards.
pcm_update:
    call sb_pcm_update
%ifdef WSS_INPUT
    pushad
    mov al, [wss_registers+6]
    call wss_level
    mov [wss_gain], ecx
    mov al, [wss_registers+7]
    call wss_level
    mov [wss_gain+4], ecx
    popad
%endif
    ret
%endif

%ifdef WSS_INPUT
; AL WSS output attenuation register. Return ECX gain, scaled by the PCM
; fader in the resident driver.
wss_level:
    push si
    xor ecx, ecx
    test al, 80h
    jnz .done
    and ax, 3fh
    mov si, ax
    shl si, 2
    mov ecx, [wss_attenuation+si]
%ifdef RESIDENT_AUDIO
    cmp byte [config_game_volume], 100
    je .done
    push eax
    mov eax, ecx
    call game_scale
    mov ecx, eax
    pop eax
%endif
.done:
    pop si
    ret
%endif

sb_pcm_levels dd 164,2067,3276,5193,8230,13045,20675,32768
sb16_levels dd 26,32,41,51,65,82,103,130,164,206,260,327,412,519,653,823
    dd 1036,1304,1642,2067,2602,3276,4125,5193,6538,8230,10362,13045,16422,20675,26028,32768
