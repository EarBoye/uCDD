; SPDX-FileCopyrightText: 2026 vorvek
; SPDX-License-Identifier: GPL-3.0-only

; Vertical faders in the SNDMIXER style. Up and Down change the level in
; steps of 5 percent. A half cell shows the odd step.

mixer_screen:
    form_save
    call page_begin
    mov word [form_title], mixer_title
    mov word [form_items], mixer_items
    mov word [form_count], MIXER_ITEMS
    mov word [form_selected], 0
    mov word [form_draw], mixer_draw
    mov word [form_keys], mixer_keys
    mov word [form_notes], mixer_notes
    mov word [form_status_row], 0113h
    call form_run
    form_restore
    mov byte [form_done], 0
    ret

mixer_draw:
    mov si, fader_names
.name:
    lodsw
    test ax, ax
    jz .done
    mov dx, ax
    mov bl, A_BOX
    push si
    mov si, [si]
    call put_text
    pop si
    add si, 2
    jmp .name
.done:
    ret

mixer_keys:
    cmp al, 27
    jne .done
    call page_cancel
    stc
    ret
.done:
    clc
    ret

; The SB 1.5/2.0 has no mixer, so its master fader shows an asterisk.
format_fader:
    mov si, [bx+ITEM_DATA]
    call fader_unused
    jnc .value
    mov byte [item_disabled], 1
    mov si, star_text
    jmp copy_text
.value:
    movzx ax, byte [si]
    jmp text_percent

; SI level. Return CF set if the card does not use it.
fader_unused:
    cmp si, config_master_volume
    jne .used
    cmp byte [sound_card], 3
    jne .used
    stc
    ret
.used:
    clc
    ret

; CX +1 or -1. Change the level by 5 percent.
adjust_volume:
    mov si, [bx+ITEM_DATA]
    call fader_unused
    jc .done
    mov al, [si]
    test cx, cx
    js .down
    add al, 5
    cmp al, 100
    jbe .store
    mov al, 100
    jmp .store
.down:
    sub al, 5
    jnc .store
    xor al, al
.store:
    cmp al, [si]
    je .done
    mov [si], al
    mov byte [changed], 1
.done:
    ret

no_action:
    ret

step_list:
    mov si, step_values
    ret

text_step:
    jmp text_percent

MIXER_ITEMS equ 6
mixer_items:
    item 17,13,4,0, ADJUST,ADJUST,NONE,1, format_fader,no_action,adjust_volume,config_cd_volume
    item 17,29,4,0, ADJUST,ADJUST,0,2, format_fader,no_action,adjust_volume,config_game_volume
    item 17,45,4,0, ADJUST,ADJUST,1,3, format_fader,no_action,adjust_volume,config_master_volume
    item 17,61,4,0, ADJUST,ADJUST,2,4, format_choice,choice_popup,choice_cycle,step_choice
    item 20,29,8,0, 0,NONE,3,5, format_label,page_ok,0,ok_label
    item 20,41,8,0, 0,NONE,4,NONE, format_label,page_cancel,0,cancel_label
step_choice:
    choice config_volume_step,1,step_list,text_step,0
step_values db 4
    dw 5,10,20,25
mixer_notes dw cd_note,0,master_note,0,0,0
fader_names dw 120ch,cd_name,121ch,wave_name,122dh,master_name,123ah,step_name,0

mixer_title db 'uCDD Mixer',0
cd_name db 'CD AUDIO',0
wave_name db 'WAVE OUT',0
master_name db 'MASTER',0
step_name db 'HOTKEY STEP',0
cd_note db 'The volume hotkeys change this level during a game.',0
master_note db 'An SB 1.5/2.0 has no master volume.',0
