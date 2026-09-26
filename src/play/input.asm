; SPDX-FileCopyrightText: 2026 vorvek
; SPDX-License-Identifier: GPL-3.0-only

; Keyboard and mouse.

read_keys:
    mov ah, 11h
    int 16h
    jz .done
    mov ah, 10h
    int 16h
    call handle_key
    jmp read_keys
.done:
    ret

; AX = BIOS key.
handle_key:
    cmp byte [help_active], 0
    je .browser
    mov byte [help_active], 0
    ret
.browser:
    cmp byte [browser_active], 0
    jne browser_key
    cmp al, 0
    je .scan
    cmp al, 0e0h
    je .scan
    mov bx, key_table
.char:
    cmp byte [bx], 0
    je .digit
    cmp al, [bx]
    je .found
    add bx, 3
    jmp .char
.found:
    jmp [bx+1]
.digit:
    cmp al, '0'
    jb .done
    cmp al, '9'
    ja .done
    sub al, '0'
    jnz .track
    mov al, 10
.track:
    jmp play_track
.scan:
    mov bx, scan_table
.code:
    cmp byte [bx], 0
    je .done
    cmp ah, [bx]
    je .found
    add bx, 3
    jmp .code
.done:
    ret

; AL = button. Show the button as pushed.
flash:
    movzx bx, al
    mov byte [button_flash+bx], FLASH_FRAMES
    ret

key_quit:
    mov byte [quit], 1
    ret
key_play:
    mov al, 1
    call flash
    jmp play_pause
key_enter:
    mov al, 1
    call flash
    cmp byte [disc_present], 0
    je no_disc
    mov al, [track]
    jmp play_track
key_stop:
    mov al, 2
    call flash
    jmp stop
key_previous:
    xor al, al
    call flash
    jmp previous_track
key_next:
    mov al, 3
    call flash
    jmp next_track
key_shuffle:
    mov al, 4
    call flash
    jmp toggle_shuffle
key_repeat:
    mov al, 5
    call flash
    jmp cycle_repeat
key_open:
    mov al, 6
    call flash
    jmp browser_open
key_eject:
    mov al, 7
    call flash
    jmp eject
key_drive:
    jmp next_unit
key_equalizer:
    cmp byte [eq_slow], 0
    jne slow_message
    xor byte [eq_on], 1
    jmp eq_apply
slow_message:
    mov si, message_slow
    jmp show_message
key_preset:
    mov al, [preset]
    inc al
    jmp eq_preset
key_visual:
    jmp select_visual
key_up_gain:
    mov ah, 1
    jmp key_gain
key_down_gain:
    mov ah, -1
key_gain:
    mov al, [eq_band]
    jmp eq_change
key_band:
    inc byte [eq_band]
    cmp byte [eq_band], SLIDERS
    jb .done
    mov byte [eq_band], 0
.done:
    ret
key_band_back:
    dec byte [eq_band]
    jns .done
    mov byte [eq_band], SLIDERS-1
.done:
    ret
key_back:
    mov ax, -10
    jmp seek
key_forward:
    mov ax, 10
    jmp seek
key_help:
    mov byte [help_active], 1
    ret
key_volume_up:
    mov al, [volume]
    add al, 8
    jnc set_volume
    mov al, 255
    jmp set_volume
key_volume_down:
    mov al, [volume]
    sub al, 8
    jnc set_volume
    xor al, al
    jmp set_volume

init_mouse:
    xor ax, ax
    int 33h
    cmp ax, 0ffffh
    jne .done
    mov byte [mouse_present], 1
    mov ax, 7
    xor cx, cx
    mov dx, 639
    int 33h
    mov ax, 8
    xor cx, cx
    mov dx, 199
    int 33h
    mov ax, 4
    mov cx, 320
    mov dx, 100
    int 33h
.done:
    ret

read_mouse:
    cmp byte [mouse_present], 0
    je .done
    mov ax, 3
    int 33h
    shr cx, 1
    mov [mouse_x], cx
    mov [mouse_y], dx
    and bl, 1
    mov al, [mouse_buttons]
    mov [mouse_buttons], bl
    test bl, bl
    jz .release
    test al, al
    jz mouse_press
    jmp mouse_drag
.release:
    mov byte [drag_mode], DRAG_NONE
.done:
    ret

; CX, DX = position. SI = rectangle x0, y0, x1, y1. ZF when inside.
inside:
    cmp cx, [si]
    jl .no
    cmp dx, [si+2]
    jl .no
    cmp cx, [si+4]
    jg .no
    cmp dx, [si+6]
    jg .no
    cmp ax, ax
    ret
.no:
    or si, si
    ret

mouse_press:
    cmp byte [help_active], 0
    je .browser
    mov byte [help_active], 0
    ret
.browser:
    cmp byte [browser_active], 0
    jne browser_click
    ; Buttons.
    cmp dx, BUTTON_Y0
    jl .panels
    cmp dx, BUTTON_Y1
    jg .panels
    xor bx, bx
.button:
    mov ax, [button_table+bx]
    cmp cx, ax
    jl .next_button
    add ax, [button_table+bx+2]
    cmp cx, ax
    jge .next_button
    shr bx, 1
    jmp [button_actions+bx]
.next_button:
    add bx, 4
    cmp bx, BUTTON_COUNT*4
    jb .button
    ret
.panels:
    mov si, click_regions
.region:
    cmp word [si], -1
    je .done
    call inside
    je .hit
    add si, 10
    jmp .region
.hit:
    jmp [si+8]
.done:
    ret

click_slider:
    mov ax, cx
    sub ax, SLIDER_X0-SLIDER_STEP/2
    jl .done
    xor dx, dx
    mov bx, SLIDER_STEP
    div bx
    cmp ax, SLIDERS
    jae .done
    mov [eq_band], al
    mov byte [drag_mode], DRAG_SLIDER
    jmp mouse_drag
.done:
    ret

click_volume:
    mov byte [drag_mode], DRAG_VOLUME
    mov [drag_y], dx
    ret

click_calendar:
    mov ax, cx
    sub ax, CALENDAR_X-2
    xor dx, dx
    mov bx, 14
    div bx
    mov cx, ax
    mov ax, [mouse_y]
    sub ax, CALENDAR_Y-1
    mov bl, 6
    div bl
    mov ah, 10
    mul ah
    add ax, cx
    inc ax
    cmp ax, 20
    ja .done
    jmp play_track
.done:
    ret

click_progress:
    cmp byte [play_state], STOPPED
    je .done
    movzx eax, cx
    sub eax, PROGRESS_X
    shl eax, 16
    xor edx, edx
    mov ecx, PROGRESS_CELLS*4
    div ecx
    jmp seek_fraction
.done:
    ret

mouse_drag:
    cmp byte [drag_mode], DRAG_SLIDER
    je .slider
    cmp byte [drag_mode], DRAG_VOLUME
    je .volume
    ret
.slider:
    mov ax, SLIDER_ZERO
    sub ax, dx
    cmp ax, -12
    jge .low
    mov ax, -12
.low:
    cmp ax, 12
    jle .high
    mov ax, 12
.high:
    movzx bx, byte [eq_band]
    cmp al, [eq_gain+bx]
    je .done
    jmp eq_set_gain
.volume:
    mov ax, [drag_y]
    sub ax, dx
    jz .done
    mov [drag_y], dx
    imul ax, ax, 6
    movzx bx, byte [volume]
    add ax, bx
    jns .above
    xor ax, ax
.above:
    cmp ax, 255
    jbe .set
    mov ax, 255
.set:
    jmp set_volume
.done:
    ret
