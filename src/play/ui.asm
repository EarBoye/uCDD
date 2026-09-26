; SPDX-FileCopyrightText: 2026 vorvek
; SPDX-License-Identifier: GPL-3.0-only

; The main screen. Each frame starts from a copy of the faceplate.

render:
    mov es, [back_seg]
    mov fs, [face_seg]
    mov gs, [extra_seg]
    call copy_face
    call clip_full
    call draw_logo_window
    call draw_vu
    call draw_lcd
    call draw_analyzer
    call draw_eq
    call draw_buttons
    call draw_bottom
    call clip_full
    cmp byte [browser_active], 0
    je .help
    call browser_draw
.help:
    cmp byte [help_active], 0
    je .cursor
    call help_draw
.cursor:
    cmp byte [mouse_present], 0
    je .done
    mov ax, [mouse_x]
    add ax, 2
    mov bx, [mouse_y]
    add bx, 2
    mov cx, CURSOR_W
    mov dx, CURSOR_H
    mov si, A_CURSOR
    call shade_sprite
    sub ax, 2
    sub bx, 2
    call draw_sprite
.done:
    ret

; AL = digit or DIGIT_MINUS, BX = x.
draw_digit:
    pusha
    movzx si, al
    imul si, si, DIGIT_BYTES
    add si, A_DIGITS
    mov ax, bx
    mov bx, DIGIT_Y
    mov cx, DIGIT_W
    mov dx, DIGIT_H
    call draw_sprite
    popa
    ret

; AL = 0 to 99. Write two digits at DI and a 0 after them.
two_digits:
    aam
    xchg al, ah
    add ax, '00'
    mov [di], ax
    mov byte [di+2], 0
    ret

; EAX = frames. Write M:SS or MM:SS at DI.
format_time:
    xor edx, edx
    mov ecx, 75
    div ecx
    xor edx, edx
    mov ecx, 60
    div ecx
    cmp eax, 99
    jbe .minutes
    mov eax, 99
.minutes:
    push dx
    call two_digits
    mov byte [di+2], ':'
    pop ax
    add di, 3
    call two_digits
    sub di, 3
    ret

draw_lcd:
    cmp byte [disc_present], 0
    jne .disc
    mov al, DIGIT_MINUS
    mov si, digit_x
.dash:
    mov bx, [si]
    call draw_digit
    add si, 2
    cmp si, digit_x+12
    jb .dash
    mov byte [draw_color], C_LCD_ON
    mov ax, 120
    mov bx, 69
    mov si, text_no_disc
    call draw_tiny
    jmp .drive
.disc:
    mov al, [track]
    aam
    push ax
    mov al, ah
    mov bx, [digit_x]
    call draw_digit
    pop ax
    mov bx, [digit_x+2]
    call draw_digit
    ; Time: the track length when stopped, else the position.
    cmp byte [play_state], STOPPED
    jne .position
    mov al, [track]
    call track_end
    movzx bx, byte [track]
    shl bx, 2
    sub edx, [track_start+bx]
    mov eax, edx
    jmp .time
.position:
    mov eax, [relative]
.time:
    mov byte [time_minus], 0
    test eax, eax
    jns .positive
    neg eax
    mov byte [time_minus], 1
.positive:
    xor edx, edx
    mov ecx, 75
    div ecx
    xor edx, edx
    mov ecx, 60
    div ecx
    cmp eax, 99
    jbe .minutes
    mov eax, 99
.minutes:
    push dx
    aam
    cmp byte [time_minus], 0
    je .tens
    mov ah, DIGIT_MINUS
.tens:
    push ax
    mov al, ah
    mov bx, [digit_x+4]
    call draw_digit
    pop ax
    mov bx, [digit_x+6]
    call draw_digit
    pop ax
    aam
    push ax
    mov al, ah
    mov bx, [digit_x+8]
    call draw_digit
    pop ax
    mov bx, [digit_x+10]
    call draw_digit
    ; Totals.
    mov di, number_text
    mov al, [last_track]
    call two_digits
    mov byte [draw_color], C_LCD_ON
    mov ax, 138
    mov bx, 59
    mov si, number_text
    call draw_tiny
    mov byte [draw_color], C_LCD_PRINT
    mov ax, 138
    mov bx, 65
    mov si, text_tracks
    call draw_tiny
    mov eax, [leadout]
    mov di, number_text
    call format_time
    mov byte [draw_color], C_LCD_ON
    mov ax, 120
    mov bx, 69
    mov si, number_text
    call draw_tiny
.drive:
    ; Colon: steady, or blinking in pause.
    cmp byte [play_state], PAUSED
    jne .colon
    test byte [frame], 32
    jnz .drive_letter
.colon:
    mov byte [draw_color], C_LCD_ON
    mov ax, COLON_X
    mov bx, DIGIT_Y+5
    mov cx, 2
    mov dx, 2
    call fill_rect
    add bx, 7
    call fill_rect
.drive_letter:
    mov al, [drive_letter]
    add al, 'A'
    mov [drive_text], al
    mov byte [draw_color], C_LCD_ON
    mov ax, 120
    mov bx, 57
    mov si, drive_text
    call draw_text
    ; Status words.
    mov byte [draw_color], C_LCD_ON
    mov bx, ANNUNCIATOR_Y
    mov al, [play_state]
    mov si, text_play
    mov cx, 14
    cmp al, PLAYING
    je .state
    mov si, text_pause
    mov cx, 32
    cmp al, PAUSED
    je .state
    mov si, text_stop
    mov cx, 54
.state:
    mov ax, cx
    call draw_tiny
    cmp byte [shuffle], 0
    je .repeat
    mov ax, 72
    mov si, text_shuffle
    call draw_tiny
.repeat:
    cmp byte [repeat_mode], REPEAT_OFF
    je .progress
    mov ax, 90
    mov si, text_repeat
    call draw_tiny
    mov ax, 102
    mov si, text_one
    cmp byte [repeat_mode], REPEAT_ONE
    je .repeat_mode
    mov ax, 108
    mov si, text_all
.repeat_mode:
    call draw_tiny
.progress:
    cmp byte [disc_present], 0
    je .done
    cmp byte [play_state], STOPPED
    je .calendar
    mov al, [track]
    call track_end
    movzx bx, byte [track]
    shl bx, 2
    sub edx, [track_start+bx]
    jbe .calendar
    mov ecx, edx
    mov eax, [relative]
    test eax, eax
    js .calendar
    imul eax, PROGRESS_CELLS
    xor edx, edx
    div ecx
    cmp ax, PROGRESS_CELLS
    jbe .cells
    mov ax, PROGRESS_CELLS
.cells:
    mov cx, ax
    jcxz .calendar
    mov ax, PROGRESS_X
    mov bx, PROGRESS_Y
    mov dx, 2
.cell:
    push cx
    mov cx, 3
    call fill_rect
    pop cx
    add ax, 4
    loop .cell
.calendar:
    mov cl, 1
.number:
    cmp cl, [last_track]
    ja .done
    movzx bx, cl
    cmp byte [track_data+bx], 0
    jne .next_number
    mov al, cl
    dec al
    aam
    ; AH = row, AL = column.
    movzx dx, al
    imul dx, dx, 14
    add dx, CALENDAR_X
    movzx bx, ah
    imul bx, bx, 6
    add bx, CALENDAR_Y
    mov di, number_text
    mov al, cl
    cmp al, 10
    jae .two
    add al, '0'
    mov [di], al
    mov byte [di+1], 0
    add dx, 4
    jmp .text
.two:
    call two_digits
.text:
    mov ax, dx
    mov byte [draw_color], C_LCD_MID
    cmp cl, [track]
    jne .plain
    push cx
    mov byte [draw_color], C_LCD_ON
    sub ax, 1
    dec bx
    mov cx, 9
    mov dx, 7
    call fill_rect
    inc ax
    inc bx
    pop cx
    mov byte [draw_color], C_BLACK
.plain:
    mov si, number_text
    call draw_tiny
.next_number:
    inc cl
    cmp cl, 20
    jbe .number
.done:
    ret

draw_vu:
    call vu_move
    xor bp, bp
.needle:
    mov ax, VU_L_X0
    test bp, bp
    jz .x
    mov ax, VU_R_X0
.x:
    mov [clip_left], ax
    add ax, VU_W-1
    mov [clip_right], ax
    mov word [clip_top], VU_Y0
    mov word [clip_bottom], VU_Y1
    sub ax, (VU_W-1)/2
    mov [needle_x], ax
    movzx ax, byte [vu_level+bp]
    imul ax, ax, 193
    xor dx, dx
    mov cx, 255
    div cx
    sub ax, 97
    push ax
    call sine
    movsx eax, ax
    imul eax, VU_RADIUS+4
    sar eax, 15
    add ax, [needle_x]
    mov cx, ax
    pop ax
    call cosine
    movsx eax, ax
    imul eax, (VU_RADIUS+4)*5
    sar eax, 15
    xor dx, dx
    mov bx, 6
    cwd
    idiv bx
    mov dx, VU_Y1+VU_PIVOT_DY
    sub dx, ax
    mov ax, [needle_x]
    mov bx, VU_Y1+VU_PIVOT_DY
    mov byte [draw_color], C_BLACK
    call draw_line
    inc bp
    cmp bp, 2
    jb .needle
    jmp clip_full

draw_analyzer:
    xor bp, bp
.bar:
    imul ax, bp, ANA_STEP
    add ax, ANA_BAR_X0
    mov cx, ANA_BAR_W
    mov dx, 1
    movzx si, byte [bar_level+bp]
    mov bx, ANA_BOTTOM
    xor di, di
.level:
    cmp di, si
    jae .peak
    push ax
    mov ax, di
    push dx
    xor dx, dx
    push bx
    mov bx, 3
    div bx
    pop bx
    cmp dx, 2
    pop dx
    pop ax
    je .gap
    push ax
    mov ax, di
    shl ax, 4
    push dx
    xor dx, dx
    push cx
    mov cx, BAR_HEIGHT+1
    div cx
    pop cx
    pop dx
    add al, C_SPECTRUM
    mov [draw_color], al
    pop ax
    call fill_rect
.gap:
    dec bx
    inc di
    jmp .level
.peak:
    movzx di, byte [bar_peak+bp]
    test di, di
    jz .reflection
    mov bx, ANA_BOTTOM
    sub bx, di
    mov byte [draw_color], C_WHITE
    call fill_rect
.reflection:
    xor di, di
.mirror:
    imul bx, di, 3
    cmp bx, si
    jae .next
    mov bx, di
    shr bx, 1
    add bl, C_REFLECT
    mov [draw_color], bl
    lea bx, [di+ANA_BOTTOM+2]
    call fill_rect
    add di, 2
    cmp di, 12
    jb .mirror
.next:
    inc bp
    cmp bp, ANA_BARS
    jb .bar
    ret

draw_eq:
    mov byte [draw_color], C_EQ_LINE
    mov si, 1
.line:
    imul ax, si, SLIDER_STEP
    add ax, SLIDER_X0
    movsx bx, byte [eq_gain+si]
    neg bx
    add bx, SLIDER_ZERO
    lea cx, [si+1]
    imul cx, cx, SLIDER_STEP
    add cx, SLIDER_X0
    movsx dx, byte [eq_gain+si+1]
    neg dx
    add dx, SLIDER_ZERO
    call draw_line
    inc si
    cmp si, SLIDERS-1
    jb .line
    ; The selected slider.
    movzx ax, byte [eq_band]
    imul ax, ax, SLIDER_STEP
    add ax, SLIDER_X0-8
    mov byte [draw_color], C_GOLD
    mov bx, SLIDER_TOP-1
.dots:
    call put_pixel
    add ax, 16
    call put_pixel
    sub ax, 16
    add bx, 2
    cmp bx, SLIDER_BOTTOM+1
    jbe .dots
    ; Knobs.
    xor si, si
.knob:
    imul ax, si, SLIDER_STEP
    add ax, SLIDER_X0-6
    movsx bx, byte [eq_gain+si]
    neg bx
    add bx, SLIDER_ZERO-3
    mov cx, KNOB_W
    mov dx, KNOB_H
    push si
    test si, si
    mov si, A_KNOB
    jnz .band
    add si, KNOB_W*KNOB_H
.band:
    call draw_sprite
    pop si
    inc si
    cmp si, SLIDERS
    jb .knob
    ; Volume mark: 135 to 405 degrees.
    movzx ax, byte [volume]
    mov cx, 768
    mul cx
    mov cx, 255
    div cx
    add ax, 384
    push ax
    call cosine
    movsx eax, ax
    imul eax, 7
    sar eax, 15
    add ax, KNOB_X
    mov cx, ax
    pop ax
    call sine
    movsx eax, ax
    imul eax, 6
    sar eax, 15
    add ax, KNOB_Y
    mov bx, ax
    mov ax, cx
    mov cx, 2
    mov dx, 2
    mov byte [draw_color], C_RED
    call fill_rect
    mov byte [draw_color], C_WHITE
    call put_pixel
    ; Jewel and preset.
    cmp byte [eq_on], 0
    je .preset
    cmp byte [eq_slow], 0
    jne .preset
    mov byte [draw_color], C_RED
    mov ax, JEWEL_X-1
    mov bx, JEWEL_Y
    mov cx, 3
    mov dx, 1
    call fill_rect
    inc ax
    dec bx
    mov cx, 1
    mov dx, 3
    call fill_rect
    mov byte [draw_color], C_WHITE
    inc bx
    call put_pixel
.preset:
    mov byte [draw_color], C_ORANGE
    mov ax, 31
    mov bx, 139
    mov si, [preset_name]
    jmp draw_tiny_shadow

draw_buttons:
    xor bp, bp
.button:
    cmp byte [button_flash+bp], 0
    je .next
    dec byte [button_flash+bp]
    mov si, bp
    shl si, 2
    mov ax, [button_table+si]
    mov cx, [button_table+si+2]
    mov bx, BUTTON_Y0
    mov dx, BUTTON_Y1-BUTTON_Y0+1
    call shade_rect
.next:
    inc bp
    cmp bp, BUTTON_COUNT
    jb .button
    ret

help_draw:
    mov word [frame_x0], 32
    mov word [frame_y0], 20
    mov word [frame_x1], 287
    mov word [frame_y1], 192
    mov si, text_help_title
    call draw_frame
    mov si, help_lines
    mov bx, 40
.line:
    cmp byte [si], 0
    je .done
    mov byte [draw_color], C_GOLD_HI
    mov ax, 48
    call draw_tiny_shadow
    call .skip
    mov byte [draw_color], C_TEXT
    mov ax, 104
    call draw_tiny_shadow
    call .skip
    add bx, 7
    jmp .line
.skip:
    lodsb
    test al, al
    jnz .skip
    ret
.done:
    ret
