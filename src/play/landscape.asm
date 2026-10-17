; SPDX-FileCopyrightText: 2026 vorvek
; SPDX-License-Identifier: GPL-3.0-only

; Spectrum history moves from the horizon toward the listener.
draw_landscape:
    push gs
    mov gs, [work_seg]
    cmp byte [land_phase], 0
    jne .clear
    mov al, [land_head]
    inc ax
    and ax, LAND_ROWS-1
    mov [land_head], al
    imul di, ax, LAND_COLS
    add di, W_FIRE
    push es
    mov es, [work_seg]
    mov si, bar_level
    mov cx, LAND_COLS
    rep movsb
    pop es
.clear:
    push es
    mov es, [work_seg]
    mov di, LAND_PIXELS
    mov cx, SCROLL_W*SCROLL_H/2
    xor ax, ax
    rep stosw
    mov di, LAND_HORIZON
    mov cx, SCROLL_W
    dec al
    rep stosb
    pop es
    mov byte [land_have_previous], 0
    mov bp, LAND_RIDGES-1
.row:
    mov ax, bp
    shl ax, 2
    movzx dx, byte [land_phase]
    add ax, dx
    mov [land_depth], ax
    imul ax, ax, 116
    xor dx, dx
    mov cx, 48
    div cx
    add ax, 32
    mov [land_span], ax
    mov dx, SCROLL_W/2
    sub dx, ax
    shl dx, 6
    mov [land_x], dx
    shl ax, 7
    xor dx, dx
    mov cx, LAND_COLS-1
    div cx
    mov [land_xstep], ax
    imul ax, [land_depth], 18
    xor dx, dx
    mov cx, 48
    div cx
    add ax, 3
    mov [land_ybase], ax
    imul ax, [land_depth], 11
    xor dx, dx
    div cx
    add ax, 3
    mov [land_height], ax
    movzx si, byte [land_head]
    sub si, bp
    and si, LAND_ROWS-1
    imul si, si, LAND_COLS
    add si, W_FIRE
    mov di, LAND_POINTS
    mov cx, LAND_COLS
.point:
    movzx ax, byte [gs:si]
    cmp ax, BAR_HEIGHT
    jbe .level
    mov ax, BAR_HEIGHT
.level:
    imul ax, [land_height]
    xor dx, dx
    mov bx, BAR_HEIGHT
    div bx
    mov bx, [land_ybase]
    sub bx, ax
    mov ax, [land_x]
    sar ax, 6
    mov [gs:di], ax
    mov [gs:di+2], bx
    mov ax, [land_xstep]
    add [land_x], ax
    inc si
    add di, 4
    loop .point
    cmp byte [land_have_previous], 0
    je .ridge
    mov byte [land_ridge], 0
    mov byte [draw_color], C_LCD_PRINT
    xor si, si
.link:
    mov ax, [gs:LAND_PREVIOUS+si]
    mov bx, [gs:LAND_PREVIOUS+si+2]
    mov cx, [gs:LAND_POINTS+si]
    mov dx, [gs:LAND_POINTS+si+2]
    call land_line
    add si, 8
    cmp si, LAND_COLS*4
    jb .link
.ridge:
    mov byte [land_ridge], 1
    mov ax, bp
    add al, C_SPECTRUM+2
    mov [draw_color], al
    mov si, LAND_POINTS
    mov ax, [gs:si]
    mov bx, [gs:si+2]
    mov di, LAND_COLS-1
.edge:
    add si, 4
    mov cx, [gs:si]
    mov dx, [gs:si+2]
    call land_line
    mov ax, cx
    mov bx, dx
    dec di
    jnz .edge
    mov si, LAND_POINTS
    mov di, LAND_PREVIOUS
    mov cx, LAND_COLS
.copy:
    mov eax, [gs:si]
    mov [gs:di], eax
    add si, 4
    add di, 4
    loop .copy
    mov byte [land_have_previous], 1
    dec bp
    jns .row
    inc byte [land_phase]
    and byte [land_phase], 3
    pop gs
    mov si, LAND_PIXELS
    jmp draw_buffer

; AX,BX to CX,DX in window coordinates. Clip behind nearer ridges.
land_line:
    pusha
    mov [line_x1], cx
    mov [line_y1], dx
    mov si, 1
    sub cx, ax
    jge .dx
    neg cx
    neg si
.dx:
    mov [line_dx], cx
    mov [line_sx], si
    mov si, 1
    sub dx, bx
    jge .dy
    neg dx
    neg si
.dy:
    neg dx
    mov [line_dy], dx
    mov [line_sy], si
    mov si, cx
    add si, dx
.point:
    call land_pixel
    cmp ax, [line_x1]
    jne .move
    cmp bx, [line_y1]
    je .done
.move:
    mov di, si
    add di, di
    cmp di, [line_dy]
    jl .no_x
    add si, [line_dy]
    add ax, [line_sx]
.no_x:
    cmp di, [line_dx]
    jg .point
    add si, [line_dx]
    add bx, [line_sy]
    jmp .point
.done:
    popa
    ret

land_pixel:
    cmp ax, SCROLL_W
    jae .done
    cmp bx, SCROLL_H
    jae .done
    push ax
    push di
    mov di, ax
    cmp bl, [gs:LAND_HORIZON+di]
    ja .skip
    cmp byte [land_ridge], 0
    je .color
    mov [gs:LAND_HORIZON+di], bl
.color:
    imul di, bx, SCROLL_W
    add di, ax
    mov al, [draw_color]
    mov [gs:LAND_PIXELS+di], al
.skip:
    pop di
    pop ax
.done:
    ret
