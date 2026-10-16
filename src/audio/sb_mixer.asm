; SPDX-License-Identifier: GPL-3.0-only

; The virtual Sound Blaster mixers (Creative's Hardware Programming Guide,
; chapter 4; vsb/SPEC.md section 9): none on the SB 2.0, the CT1345 on the
; SB Pro, the CT1745 on the SB16. The virtual ESS has its own mixer
; (audio/ess/card.asm).
;
; virtual_mixer holds what each register reads back on the presented chip,
; FFh where the chip has no register. On every model the gains the mixing
; code uses sit at 30h-37h in the CT1745's form: master, voice, MIDI and CD,
; left then right, the level in bits 7:3. On the SB16 those are the chip's
; own registers. On the SB Pro, whose 30h-3Fh read as 20h-2Fh, the CT1345's
; volume registers set them as the CT1745's compatibility registers do. The
; SB 2.0 leaves them at 0 dB. The host answers the SB16's mixer reads itself
; from this array (host/resident.asm, resident_io .data); for the other
; models every read comes here.

; The value written to 2x5h in AL; the register is virtual_mixer_index. DS=CS.
virtual_mixer_write:
    pushad
    movzx bx, byte [virtual_mixer_index]
    cmp byte [virtual_model], 1
    je .pro
    ja .done                        ; the SB 2.0: no mixer
    ; The CT1745. 00h resets; 80h-82h are read only (80h and 81h are the
    ; card's IRQ and DMA, which "should only be changed by system software",
    ; SBG:1047-1052).
    test bl, bl
    jz .reset
    cmp bl, 0ah
    je .sb16_mic
    mov cx, 5
    call mixer_pair
    jnc .sb16_compat
    cmp bl, 30h
    jb .done
    cmp bl, 47h
    ja .done
    mov [virtual_mixer+bx], al
    cmp bl, 3ah
    je .sb16_mic_view
    ja .done
    ; 30h-39h: the compatibility register shows the top four bits of each
    ; channel's level.
    and bl, 0feh
    mov al, [virtual_mixer+bx]
    and al, 0f0h
    mov ah, [virtual_mixer+bx+1]
    shr ah, 4
    or al, ah
    mov si, bx
    shr si, 1
    movzx si, byte [sb16_views+si-18h]
    mov [virtual_mixer+si], al
    jmp .gains
.sb16_compat:
    ; 04h, 22h, 26h, 28h and 2Eh: four bits a channel, mapped onto the new
    ; registers with the fifth bit, the lowest, set (SBG:2658-2677).
    mov [virtual_mixer+bx], al
    mov ah, al
    and al, 0f0h
    or al, 8
    mov [virtual_mixer+di], al
    shl ah, 4
    or ah, 8
    mov [virtual_mixer+di+1], ah
    jmp .gains
.sb16_mic:
    ; 0Ah: three bits, the top three of 3Ah.
    and al, 7
    mov [virtual_mixer+0ah], al
    shl al, 5
    or al, 10h
    mov [virtual_mixer+3ah], al
    jmp .done
.sb16_mic_view:
    shr al, 5
    mov [virtual_mixer+0ah], al
    jmp .done
.pro:
    ; The CT1345 decodes only bit 5 and the low four bits of the register
    ; number below 40h: 10h-1Fh are 00h-0Fh and 30h-3Fh are 20h-2Fh;
    ; 40h-FFh are nothing; 00h and 01h reset (DOSBox-X's notes from a
    ; CT1600).
    cmp bl, 40h
    jae .done
    and bl, 0efh
    cmp bl, 1
    jbe .reset
    cmp bl, 0fh
    jne .pro_register
    mov bl, 0eh
.pro_register:
    cmp bl, 0eh
    je .pro_output
    cmp bl, 0ch
    je .pro_store
    cmp bl, 0ah
    je .pro_mic
    cmp bl, 2eh
    je .pro_level
    mov cx, 4
    call mixer_pair
    jc .done
    ; 04h, 22h, 26h, 28h: three bits a channel in bits 7:5 and 3:1, made
    ; gains as the CT1745's four-bit registers are.
    mov dl, al
    and al, 0e0h
    or al, 8
    mov [virtual_mixer+di], al
    mov al, dl
    shl al, 4
    and al, 0e0h
    or al, 8
    mov [virtual_mixer+di+1], al
    mov al, dl
    or al, 11h
    mov [virtual_mixer+bx], al
    jmp .gains
.pro_level:
    ; Bits 4 and 0 of the volume registers read as set (DOSBox-X, from a
    ; CT1600; the ES1868's sheet says the same of its SB Pro registers).
    or al, 11h
    jmp .pro_store
.pro_mic:
    ; Two bits, 2:1 (SBG:2439-2442).
    and al, 6
.pro_store:
    mov [virtual_mixer+bx], al
    jmp .done
.pro_output:
    ; Bit 1 the stereo switch, bit 5 the output filter off (SBG:2476-2487);
    ; the other bits read 1 in each nibble.
    mov ah, al
    and ah, 2
    mov [sb_pro_stereo], ah
    mov ah, al
    and ah, 20h
    mov [sb_filter_bypass], ah
    and al, 22h
    or al, 11h
    mov [virtual_mixer+0eh], al
    jmp .done
.reset:
    call virtual_mixer_reset
.gains:
%ifdef MOUNTED_AUDIO
    call cd_gain_update
%endif
%ifdef RESIDENT_AUDIO
    call fm_update
%endif
    call sb_pcm_update
.done:
    popad
    ret

; BL=a register, CX=the number of mixer_pairs entries to look in. CF clear
; and DI=the first of the gain pair it sets; CF set when it sets none.
mixer_pair:
    mov si, mixer_pairs
.next:
    cmp bl, [si]
    je .found
    add si, 2
    loop .next
    stc
    ret
.found:
    movzx di, byte [si+1]
    clc
    ret

; Returns AL=the register virtual_mixer_index reads back. DS=CS.
virtual_mixer_read:
    push bx
    movzx bx, byte [virtual_mixer_index]
    mov al, 0ffh
    cmp byte [virtual_model], 1
    je .pro
    ja .done                        ; the SB 2.0: nothing at 2x5h
    cmp bl, 82h
    jne .register
    ; Bits 2:0 the sources (SBG:969-982), bit 5 the DSP's revision as a
    ; DSP 4.05 reads it (86Box; DOSBox-X sets the same bit on every SB16).
    call virtual_mpu_refresh
    mov al, [virtual_dsp_irq]
    or al, 20h
    jmp .done
.pro:
    cmp bl, 40h
    jae .done
    and bl, 0efh
    cmp bl, 1
    jbe .pro_output
    cmp bl, 0fh
    jne .register
.pro_output:
    ; 0Eh shows at 00h, 01h and 0Fh too.
    mov bl, 0eh
.register:
    mov al, [virtual_mixer+bx]
.done:
    pop bx
    ret

; The mixer's reset (register 00h, SBG:2329, 2434, 2655): the guide's reset
; values. 80h and 81h keep the card's settings. The SB 2.0 has no mixer.
virtual_mixer_reset:
    pushad
    push es
    cmp byte [virtual_model], 1
    ja .done
    push cs
    pop es
    cld
    mov di, virtual_mixer
    mov cx, 128
    mov ax, 0ffffh
    rep stosw
    mov si, sb16_reset
    cmp byte [virtual_model], 0
    je .values
    mov si, pro_reset
.values:
    ; Pairs of register and value, ended by FFh.
    lodsw
    cmp al, 0ffh
    je .settings
    movzx bx, al
    mov [virtual_mixer+bx], ah
    jmp .values
.settings:
    mov byte [sb_pro_stereo], 0
    mov byte [sb_filter_bypass], 0
    call virtual_mixer_card
.done:
    pop es
    popad
    ret

; 80h and 81h, the CT1745's IRQ and DMA select (SBG:1028-1046), as the
; virtual card is set.
virtual_mixer_card:
    cmp byte [virtual_model], 0
    jne .done
    mov al, 1
    cmp byte [guest_irq], 2
    je .irq
    cmp byte [guest_irq], 9
    je .irq
    mov al, 2
    cmp byte [guest_irq], 5
    je .irq
    mov al, 4
    cmp byte [guest_irq], 7
    je .irq
    mov al, 8
.irq:
    mov [virtual_mixer+80h], al
    mov cl, [guest_dma8]
    mov al, 1
    shl al, cl
    mov cl, [guest_dma16]
    mov ah, 1
    shl ah, cl
    or al, ah
    mov [virtual_mixer+81h], al
.done:
    ret

; The SB16's reset values (SBG:2658-2752): register, value.
sb16_reset:
    db 00h,00h, 04h,0cch, 0ah,00h, 22h,0cch, 26h,0cch, 28h,00h, 2eh,00h
    db 30h,0c0h, 31h,0c0h, 32h,0c0h, 33h,0c0h, 34h,0c0h, 35h,0c0h
    db 36h,0, 37h,0, 38h,0, 39h,0, 3ah,0, 3bh,0, 3ch,1fh, 3dh,15h, 3eh,0bh
    db 3fh,0, 40h,0, 41h,0, 42h,0, 43h,0, 44h,80h, 45h,80h, 46h,80h, 47h,80h
    db 0ffh,0ffh
; The SB Pro's (SBG:2439-2506), as the registers read with bits 4 and 0 set,
; and the gains they make at 30h-37h.
pro_reset:
    db 04h,99h, 0ah,00h, 0ch,00h, 0eh,11h, 22h,99h, 26h,99h, 28h,11h, 2eh,11h
    db 30h,88h, 31h,88h, 32h,88h, 33h,88h, 34h,88h, 35h,88h, 36h,08h, 37h,08h
    db 0ffh,0ffh
; The volume registers of the CT1345 and the CT1745's compatibility ones,
; with the gain pair each sets (SBG:2658-2677). Line in, the fifth, maps
; onto 38h/39h on the CT1745 only, and no gain of the driver's follows it.
mixer_pairs db 04h,32h, 22h,30h, 26h,34h, 28h,36h, 2eh,38h
; The CT1745's compatibility register that shows each pair, 30h to 39h.
sb16_views db 22h,04h,26h,28h,2eh
sb_pro_stereo db 0
