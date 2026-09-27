; SPDX-FileCopyrightText: 2026 vorvek
; SPDX-License-Identifier: GPL-3.0-only

; UCDDPLAY: a CD player for uCDD drives in VGA mode 13h.
; The EXE image is the assets followed by this segment. CS, DS, and SS are
; this segment. The assets start at PSP+10h: the faceplate, then the rest.

bits 16
cpu 386
org 0

%include "disc.inc"
%include "play/assets.inc"
%include "play/defs.inc"

%define W_RE 0
%define W_IM 4096
%define W_BITREV 8192
%define W_FIRE 10240
%define ENTRIES 23808
%define WORK_BYTES (ENTRIES+ENTRY_MAX*ENTRY_SIZE)
%define STACK_BYTES 2048

    jmp strict near start
    ; The build reads this offset. The zero data after it is not in the file.
    dw bss_start

start:
    cld
    mov ax, cs
    mov ds, ax
    mov dx, es
    push ds
    pop es
    mov di, bss_start
    mov cx, stack_bottom-bss_start
    xor al, al
    rep stosb
    mov [psp_seg], dx
    call parse_arguments
    mov es, [psp_seg]
    mov bx, cs
    sub bx, [psp_seg]
    add bx, (stack_top-$$+15)/16
    mov ah, 4ah
    int 21h
    mov bx, 4000
    mov ah, 48h
    int 21h
    jc no_memory
    mov [back_seg], ax
    mov bx, (WORK_BYTES+15)/16
    mov ah, 48h
    int 21h
    jc no_memory
    mov [work_seg], ax
    mov ax, [psp_seg]
    add ax, 10h
    mov [face_seg], ax
    mov fs, ax
    add ax, 4000
    mov [extra_seg], ax
    mov gs, ax
    call find_units
    jc no_drives
    mov al, [default_unit]
    cmp byte [wanted_drive], 0ffh
    je .unit
    xor al, al
.find:
    movzx bx, al
    mov dl, [unit_letters+bx]
    cmp dl, [wanted_drive]
    je .unit
    inc al
    cmp al, [unit_total]
    jb .find
    mov dx, drive_error_message
    jmp error_exit
.unit:
    call select_unit
    mov ax, 1a00h
    int 10h
    cmp al, 1ah
    jne no_vga
    cmp bl, 7
    jb no_vga
    cmp bl, 8
    ja no_vga
    push ds
    push 40h
    pop ds
    mov eax, [6ch]
    pop ds
    mov [random_seed], eax
    call init_bitreverse
    call init_visuals
    call read_disc
    call read_volume
    xor al, al
    call eq_preset
    call eq_calibrate
    mov dx, audio_report
    mov ax, 6
    call audio_control
    mov si, message_no_audio
    test ax, ax
    jnz .report
    call hook_install
    jnc .slow
    mov si, message_no_filter
.report:
    call show_message
    jmp .vectors
.slow:
    cmp byte [eq_slow], 0
    je .vectors
    mov si, message_slow
    call show_message
.vectors:
    mov ax, 2523h
    mov dx, break_handler
    int 21h
    mov ax, 2524h
    mov dx, critical_handler
    int 21h
    mov es, [psp_seg]
    mov eax, [es:0ah]
    mov [saved_terminate], eax
    mov word [es:0ah], emergency_exit
    mov [es:0ch], cs
    call init_mouse
    mov ax, 13h
    int 10h
    push ds
    mov ds, [extra_seg]
    mov si, A_PALETTE
    xor al, al
    mov cx, 256
    call set_palette
    pop ds

main_loop:
    call read_keys
    call read_mouse
    cmp byte [quit], 0
    jne exit
    call poll_drive
    test byte [frame], 1
    jnz .render
    cmp byte [play_state], PLAYING
    jne .idle
    cmp byte [hook_active], 0
    je .idle
    call analyze
    jmp .render
.idle:
    call analyze_idle
.render:
    call render
    call wait_retrace
    call animate_palette
    call present
    inc word [frame]
    jmp main_loop

exit:
    call stop
    call hook_remove
    mov ax, 3
    int 10h
    mov es, [psp_seg]
    mov eax, [saved_terminate]
    mov [es:0ah], eax
    mov ax, 4c00h
    int 21h

; DOS ended the program after an error. Remove the filter and restore the
; text screen. The memory of the program is free but not changed yet.
emergency_exit:
    push cs
    pop ds
    call physical_stop
    call hook_remove
    mov ax, 3
    int 10h
    jmp far [cs:saved_terminate]

break_handler:
    iret

critical_handler:
    mov al, 3
    iret

; ES = PSP. Read /? or a drive letter.
parse_arguments:
    mov byte [wanted_drive], 0ffh
    push ds
    mov es, [psp_seg]
    mov si, 81h
    movzx cx, byte [es:80h]
.space:
    jcxz .done
    mov al, [es:si]
    cmp al, ' '
    je .skip
    cmp al, 9
    jne .word
.skip:
    inc si
    dec cx
    jmp .space
.word:
    cmp al, '/'
    je .usage
    and al, 0dfh
    sub al, 'A'
    cmp al, 25
    ja .usage
    mov [wanted_drive], al
    inc si
    dec cx
    jcxz .done
    cmp byte [es:si], ':'
    jne .end
    inc si
    dec cx
.end:
    jcxz .done
    cmp byte [es:si], ' '
    je .done
    cmp byte [es:si], 13
    jne .usage
.done:
    pop ds
    ret
.usage:
    pop ds
    mov dx, usage_message
    mov ah, 9
    int 21h
    mov dx, license_notice
    mov ah, 9
    int 21h
    mov ax, 4c00h
    int 21h

no_memory:
    mov dx, memory_message
    jmp error_exit
no_drives:
    mov dx, no_drives_message
    jmp error_exit
no_vga:
    mov dx, vga_message
error_exit:
    mov ah, 9
    int 21h
    mov ax, 4c01h
    int 21h

%include "play/gfx.asm"
%include "play/drive.asm"
%include "play/physical.asm"
%include "play/mount.asm"
%include "play/browser.asm"
%include "play/eq.asm"
%include "play/fft.asm"
%include "play/vis.asm"
%include "play/ui.asm"
%include "play/input.asm"
%include "play/text.asm"
%include "notice.inc"
%include "play/token.asm"
%include "mdm_helper.asm"
%include "cue.asm"

    align 16, db 0
bss_start:
psp_seg dw 0
back_seg dw 0
work_seg dw 0
face_seg dw 0
extra_seg dw 0
saved_terminate dd 0
wanted_drive db 0
quit db 0
frame dw 0

; Graphics.
draw_color db 0
sprite_mask db 0
sprite_shade db 0
sprite_rows dw 0
text_x dw 0
line_dx dw 0
line_dy dw 0
line_sx dw 0
line_sy dw 0
line_x1 dw 0
line_y1 dw 0
clip_left dw 0
clip_top dw 0
clip_right dw 0
clip_bottom dw 0

; Drives and play state.
unit_total db 0
unit db 0
drive_letter db 0
subunit db 0
control_entry dd 0
audio_control_entry dd 0
audio_subunit db 0
default_unit db 0
physical_source db 0
unit_letters times 26 db 0
unit_subunits times 26 db 0
unit_controls times 26 dd 0
drive_count dw 0
drive_list times 26 db 0
device_list times 26*5 db 0
request times 26 db 0
control_block times 16 db 0
disc_present db 0
first_track db 0
last_track db 0
first_audio db 0
audio_count db 0
play_state db 0
track db 0
replan db 0
shuffle db 0
repeat_mode db 0
order_count db 0
order_index db 0
order times MAX_TRACKS+1 db 0
track_data times MAX_TRACKS+2 db 0
track_pre times MAX_TRACKS+2 db 0
    align 4, db 0
track_start times MAX_TRACKS+2 dd 0
track_index0 times MAX_TRACKS+2 dd 0
leadout dd 0
position dd 0
relative dd 0
range_end dd 0
random_seed dd 0
disc_info times INFO_SIZE db 0
probe_info times INFO_SIZE db 0
full_path times INFO_SIZE db 0
mount_tracks equ full_path+INFO_TRACKS

; Requester.
browser_active db 0
help_active db 0
entry_count dw 0
entry_selected dw 0
entry_top dw 0
frame_x0 dw 0
frame_y0 dw 0
frame_x1 dw 0
frame_y1 dw 0
title_x dw 0
curl_x dw 0
curl_y dw 0
entry_buffer times 16 db 0
number_text times 16 db 0
dta times 44 db 0
browse_path times 132 db 0
browse_pattern times 136 db 0
select_path times 150 db 0

; Equalizer and hook.
    align 4, db 0
eq_gain times 12 db 0
preset db 0
hook_active db 0
eq_set dw 0
hook_set dw 0
hook_offset dw 0
hook_frames dw 0
    align 4, db 0
eq_set_a times SET_SIZE db 0
    align 4, db 0
eq_set_b times SET_SIZE db 0
    align 4, db 0
eq_state times 2*CHANNEL_SIZE db 0
eq_sum dd 0
hook_mask dw 0
eq_slow db 0
audio_report times 26 db 0
eq_saved times EQ_BANDS+1 db 0
chunk_frames dw 0
chunk_bytes dw 0
chunk_channel dw 0
block_input dw 0
block_state dw 0
block_band dw 0
block_v dw 0
    align 4, db 0
band_a1 dd 0
band_a2 dd 0
band_gain dd 0
block_t times EQ_CHUNK dd 0
block_y times EQ_CHUNK dd 0
ring_pos dw 0
    align 4, db 0
ring times RING_FRAMES*4 db 0

; Analysis.
fft_half dw 0
fft_k dw 0
fft_sin dd 0
fft_cos dd 0
bar_level times ANA_BARS db 0
bar_peak times ANA_BARS db 0
bar_hold times ANA_BARS db 0
vu_target times 2 db 0
vu_level times 2 db 0

; Visuals.
star_x0 dw 0
star_y0 dw 0
star_x1 dw 0
star_y1 dw 0
star_boost dw 0
logo_stars times LOGO_STARS*STAR_SIZE db 0
bottom_stars times BOTTOM_STARS*STAR_SIZE db 0
dynamic_palette times (3*COPPER_SHADES+16)*3 db 0
message_timer dw 0
message_text dw 0
message_buffer times 48 db 0
vis_timer dw 0
vis_mode db 0
label_active db 0
label_level db 0
label_start dw 0
label_text dw 0
label_x dw 0
bubble_color db 0
bubble_fill db 0
bubbles times BUBBLES*BUBBLE_SIZE db 0
scroll_offset dw 0
scroll_shadow dw 0
scope_channel dw 0
scope_last dw 0
fire_heat dw 0
time_minus db 0
needle_x dw 0
button_flash times BUTTON_COUNT db 0

; Input.
mouse_present db 0
mouse_buttons db 0
mouse_x dw 0
mouse_y dw 0
drag_mode db 0
drag_y dw 0

stack_bottom:
    times STACK_BYTES db 0
stack_top:
