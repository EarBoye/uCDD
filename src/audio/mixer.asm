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

sb_pcm_levels dd 164,2067,3276,5193,8230,13045,20675,32768
sb16_levels dd 26,32,41,51,65,82,103,130,164,206,260,327,412,519,653,823
    dd 1036,1304,1642,2067,2602,3276,4125,5193,6538,8230,10362,13045,16422,20675,26028,32768
