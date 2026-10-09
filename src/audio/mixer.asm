; SPDX-FileCopyrightText: 2026 vorvek
; SPDX-License-Identifier: GPL-3.0-only

; BX selects a stereo source. SI selects its channel.
sb_mixer_gain:
    push ebx
    push edx
    mov al, [virtual_mixer+bx+si]
    call sb_mixer_level
    mov edx, eax
    mov al, [virtual_mixer+30h+si]
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
    movzx ecx, byte [config_game_volume]
    imul eax, ecx
    xor edx, edx
    mov ecx, 100
    div ecx
%endif
    movzx ebx, si
    mov [sb_pcm_gain+ebx*4], eax
    inc si
    cmp si, 2
    jb .channel
    popad
    ret

%ifdef RESIDENT_AUDIO
; The game's FM and master levels, set on the physical card's FM volume as a
; real card would apply them: SB16 34h/35h, SB Pro and ESS 26h. The WSS codec
; and the SB 2.0 have no FM volume of their own and are left alone.
fm_update:
    pushad
    cmp byte [sound_card], 0
    je .sb16
    cmp byte [sound_card], 1
    je .pro
    cmp byte [sound_card], 2
    jne .done
    cmp byte [ess_native], 0
    je .done
.pro:
    xor si, si
    xor cx, cx
.pro_channel:
    mov bx, 34h
    call sb_mixer_gain
    mov di, sb_pcm_levels
    mov dl, 7
    call fm_level
    ; 3 bits a channel, the unused low bit set as Creative's defaults have it.
    shl cl, 4
    lea cx, [ecx+eax*2+1]
    inc si
    cmp si, 2
    jb .pro_channel
    mov ah, cl
    mov al, 26h
    call fm_write
    jmp .done
.sb16:
    xor si, si
.sb16_channel:
    mov bx, 34h
    call sb_mixer_gain
    mov di, sb16_levels
    mov dl, 31
    call fm_level
    shl al, 3
    mov ah, al
    mov dx, si
    mov al, 34h
    add al, dl
    call fm_write
    inc si
    cmp si, 2
    jb .sb16_channel
.done:
    popad
    ret
; EAX=gain, DI=level table, DL=last index. Returns EAX=the index whose level
; is nearest the gain in decibels: the highest index whose geometric mean with
; the one below is at most the gain.
fm_level:
    push ecx
    push esi
    movzx edi, di
    movzx esi, dl
    mul eax
    mov ebx, eax
.find:
    test esi, esi
    jz .found
    mov eax, [edi+esi*4]
    mul dword [edi+esi*4-4]
    cmp ebx, eax
    jae .found
    dec esi
    jmp .find
.found:
    mov eax, esi
    pop esi
    pop ecx
    ret
; AL=register, AH=value. No interrupt between the index and the data.
fm_write:
    pushf
    cli
    call indexed_write
    popf
    ret
%endif

sb_pcm_levels dd 164,2067,3276,5193,8230,13045,20675,32768
sb16_levels dd 26,32,41,51,65,82,103,130,164,206,260,327,412,519,653,823
    dd 1036,1304,1642,2067,2602,3276,4125,5193,6538,8230,10362,13045,16422,20675,26028,32768
