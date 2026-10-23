; SPDX-FileCopyrightText: 2026 vorvek
; SPDX-License-Identifier: GPL-3.0-only

; A chorus line of gold and chrome vector dancers with linked arms. A wave of
; kicks moves along the line. Louder frequency bands give higher kicks.
draw_dancers:
    call clip_scroll
    mov ax, SCROLL_X0
    mov bx, SCROLL_Y1
.floor:
    mov dl, C_GOLD
    test al, 2
    jz .floor_color
    mov dl, C_GOLD_LO
.floor_color:
    mov [draw_color], dl
    call put_pixel
    inc ax
    cmp ax, SCROLL_X1
    jbe .floor
    imul ax, [frame], 24
    call sine
    not ax
    rol ax, 1
    and ax, 1
    mov [dancer_wave], ax
    xor bp, bp
.place:
    imul ax, bp, -73
    imul bx, [frame], 10
    add ax, bx
    call sine
    mov si, bp
    add si, si
    mov [dancer_kick+si], ax
    mov di, bp
    shl di, 3
    imul cx, bp, 37
    shr cx, 1
    add cx, SCROLL_X0+9
    mov [dancer_pos+di], cx
    ; The body leans and rises with the kick.
    mov dx, SCROLL_Y0+12
    cmp ax, 16384
    jl .not_right
    inc cx
    dec dx
.not_right:
    cmp ax, -16384
    jg .lean
    dec cx
    dec dx
.lean:
    mov [dancer_pos+di+2], dx
    mov [dancer_pos+di+4], cx
    sub dx, 6
    mov [dancer_pos+di+6], dx
    inc bp
    cmp bp, DANCERS
    jb .place
    xor bp, bp
.dancer:
    mov di, bp
    shl di, 3
    mov ax, C_GOLD_HI*256+C_GOLD
    test bp, 1
    jz .colors
    mov ax, C_WHITE*256+C_KNOB+1
.colors:
    mov [draw_color], al
    mov [dancer_hi], ah
    mov ax, [dancer_pos+di]
    mov bx, [dancer_pos+di+2]
    mov cx, [dancer_pos+di+4]
    mov dx, [dancer_pos+di+6]
    call draw_line
    mov ax, cx
    mov bx, dx
    sub bx, 2
    mov dl, [dancer_hi]
    call dancer_dot
    mov dl, [draw_color]
    dec ax
    call dancer_dot
    add ax, 2
    call dancer_dot
    dec ax
    dec bx
    call dancer_dot
    add bx, 2
    call dancer_dot
    mov word [dancer_side], -1
    call dancer_arm
    mov word [dancer_side], 1
    call dancer_arm
    ; The kick angle: 6 to 106 degrees, from the kick phase and the level.
    mov si, bp
    add si, si
    mov ax, [dancer_kick+si]
    mov word [dancer_side], -1
    test ax, ax
    jle .kick_side
    mov word [dancer_side], 1
.kick_side:
    cwd
    xor ax, dx
    sub ax, dx
    mov cx, 284
    mul cx
    shl ax, 1
    rcl dx, 1
    movzx ecx, dx
    imul ax, bp, ANA_BARS
    xor dx, dx
    mov bx, DANCERS
    div bx
    mov bx, ax
    movzx ax, byte [bar_level+bx]
    cmp ax, BAR_HEIGHT
    jbe .level
    mov ax, BAR_HEIGHT
.level:
    imul ax, ax, 55
    add ax, 45*BAR_HEIGHT
    movzx eax, ax
    imul eax, ecx
    xor edx, edx
    mov ecx, 100*BAR_HEIGHT
    div ecx
    add ax, 17
    call dancer_leg
    neg word [dancer_side]
    mov ax, 17
    call dancer_leg
    inc bp
    cmp bp, DANCERS
    jb .dancer
    jmp clip_full

; DI = dancer offset, BP = dancer, [dancer_side] = -1 or 1. The arm goes over
; the shoulder of the next dancer. The dancers at the ends wave.
dancer_arm:
    pusha
    mov ax, [dancer_pos+di+4]
    mov bx, [dancer_pos+di+6]
    mov si, bp
    add si, [dancer_side]
    cmp si, DANCERS
    jae .free
    shl si, 3
    mov cx, [dancer_pos+si+4]
    add cx, ax
    sar cx, 1
    mov dx, [dancer_pos+si+6]
    add dx, bx
    sar dx, 1
    add dx, 2
    inc bx
    call draw_line
    popa
    ret
.free:
    imul cx, [dancer_side], 3
    add cx, ax
    mov dx, bx
    sub dx, 2
    inc bx
    call draw_line
    mov ax, cx
    mov bx, dx
    add cx, [dancer_side]
    sub dx, 3
    sub dx, [dancer_wave]
    call draw_line
    popa
    ret

; AX = angle from the vertical (1024 = full turn), DI = dancer offset,
; [dancer_side] = -1 or 1.
dancer_leg:
    pusha
    imul ax, [dancer_side]
    neg ax
    add ax, 256
    mov bp, ax
    mov cx, 8
    call dancer_polar
    mov si, [dancer_pos+di]
    mov bx, [dancer_pos+di+2]
    add dx, si
    add ax, bx
    push dx
    push ax
    mov cx, dx
    mov dx, ax
    mov ax, si
    call draw_line
    imul ax, [dancer_side], -24
    add ax, bp
    mov cx, 9
    call dancer_polar
    pop bx
    pop si
    add dx, si
    add ax, bx
    mov cx, dx
    mov dx, ax
    mov ax, si
    call draw_line
    mov ax, cx
    add ax, [dancer_side]
    mov bx, dx
    mov dl, [dancer_hi]
    call dancer_dot
    popa
    ret

; AX = angle (1024 = full turn), CX = length in half pixels.
; Return DX = x offset and AX = y offset in pixels.
dancer_polar:
    push bx
    push si
    mov bx, ax
    call cosine
    imul cx
    add ax, 8000h
    adc dx, 0
    mov si, dx
    mov ax, bx
    call sine
    imul cx
    add ax, 8000h
    adc dx, 0
    mov ax, dx
    mov dx, si
    pop si
    pop bx
    ret

; AX = x, BX = y, DL = color. Draw one pixel inside the clip window.
dancer_dot:
    push word [draw_color]
    mov [draw_color], dl
    push cx
    push dx
    ; A line of one point uses the clip test of draw_line.
    mov cx, ax
    mov dx, bx
    call draw_line
    pop dx
    pop cx
    pop word [draw_color]
    ret
