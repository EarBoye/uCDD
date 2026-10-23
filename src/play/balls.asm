; SPDX-FileCopyrightText: 2026 vorvek
; SPDX-License-Identifier: GPL-3.0-only

; A gold and a chrome strand of vector balls turn as a double helix. Each
; ball follows the frequency band under it: louder bands make the helix wider
; and the balls larger.
draw_balls:
    mov si, ball_colors
    mov di, ball_colors+4
    call .back_colors
    mov si, ball_colors+8
    mov di, ball_colors+12
    call .back_colors
    mov byte [ball_pass], 0
.pass:
    mov word [ball_strand], 0
.strand:
    mov word [ball_index], 0
.ball:
    imul ax, [ball_index], 2048/BALLS
    imul bx, [frame], 5
    add ax, bx
    imul bx, [ball_strand], 512
    add ax, bx
    push ax
    call cosine
    mov [ball_depth], ax
    ; The back balls are drawn in the first pass.
    cmp byte [ball_pass], 0
    jne .front
    test ax, ax
    jns .skip
    jmp .level
.front:
    test ax, ax
    js .skip
.level:
    imul ax, [ball_index], ANA_BARS
    xor dx, dx
    mov cx, BALLS
    div cx
    mov bx, ax
    movzx cx, byte [bar_level+bx]
    cmp cx, BAR_HEIGHT
    jbe .loud
    mov cx, BAR_HEIGHT
.loud:
    pop ax
    call sine
    ; Height: 3.6 to 7.2 pixels.
    imul bx, cx, 7
    shr bx, 1
    add bx, 130
    movsx eax, ax
    movsx ebx, bx
    imul eax, ebx
    sar eax, 15
    cdq
    mov ebx, BAR_HEIGHT
    idiv ebx
    add ax, (SCROLL_Y0+SCROLL_Y1)/2
    push ax
    ; Radius: 3 to 5 pixels, from depth and level.
    movsx eax, word [ball_depth]
    add eax, 32768
    imul eax, eax, 6
    shr eax, 15
    imul dx, cx, 10
    push ax
    mov ax, dx
    xor dx, dx
    mov bx, BAR_HEIGHT
    div bx
    pop dx
    add ax, dx
    add ax, 34
    mov bl, 10
    div bl
    movzx cx, al
    cmp cx, 5
    jbe .radius
    mov cx, 5
.radius:
    imul ax, [ball_index], SCROLL_W-12
    xor dx, dx
    mov bx, BALLS-1
    div bx
    add ax, SCROLL_X0+6
    pop bx
    imul si, [ball_strand], 8
    add si, ball_colors
    cmp byte [ball_pass], 0
    jne .draw
    add si, 4
.draw:
    call draw_ball
    jmp .next
.skip:
    pop ax
.next:
    inc word [ball_index]
    cmp word [ball_index], BALLS
    jb .ball
    inc word [ball_strand]
    cmp word [ball_strand], 2
    jb .strand
    inc byte [ball_pass]
    cmp byte [ball_pass], 2
    jb .pass
    ret

; SI = front colors, DI = back colors. A back ball is one shade darker.
.back_colors:
    movzx bx, byte [si]
    mov al, [gs:A_SHADE+bx]
    mov [di], al
    mov ax, [si]
    mov [di+1], ax
    mov al, [si+2]
    mov [di+3], al
    ret

; AX = x, BX = y of the center, CX = radius (3 to 5), SI = four colors.
draw_ball:
    pusha
    mov bp, cx
    add bp, bp
    inc bp
    sub ax, cx
    sub bx, cx
    mov [ball_left], ax
    mov di, cx
    sub di, 3
    add di, di
    mov dx, [ball_shape_table+di]
    mov word [ball_row], 0
.row:
    cmp bx, SCROLL_Y0
    jl .next_row
    cmp bx, SCROLL_Y1
    jg .done
    imul ax, bx, 320
    mov [ball_base], ax
    xor cx, cx
.pixel:
    mov di, dx
    add di, cx
    mov al, [ball_shapes+di]
    test al, al
    jz .next_pixel
    mov di, [ball_left]
    add di, cx
    cmp di, SCROLL_X0
    jl .next_pixel
    cmp di, SCROLL_X1
    jg .next_pixel
    add di, [ball_base]
    cmp byte [fs:di], C_KEY
    jne .next_pixel
    push bx
    movzx bx, al
    mov al, [si+bx-1]
    pop bx
    mov [es:di], al
.next_pixel:
    inc cx
    cmp cx, bp
    jb .pixel
.next_row:
    add dx, bp
    inc bx
    inc word [ball_row]
    cmp [ball_row], bp
    jb .row
.done:
    popa
    ret
