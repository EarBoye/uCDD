; SPDX-FileCopyrightText: 2026 vorvek
; SPDX-License-Identifier: GPL-3.0-only

; Rockets rise on bass hits and burst into gold, chrome, and burgundy sparks
; that fall and fade. Louder music also starts more rockets.
draw_fireworks:
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
    ; The bass level against its running average.
    xor cx, cx
    xor si, si
.bass:
    movzx ax, byte [bar_level+si]
    add cx, ax
    inc si
    cmp si, 3
    jb .bass
    mov ax, [fw_bass_avg]
    mov dx, ax
    shr dx, 4
    sub ax, dx
    add ax, cx
    mov [fw_bass_avg], ax
    cmp byte [fw_cool], 0
    je .ready
    dec byte [fw_cool]
    jmp .rockets
.ready:
    mov dx, ax
    shr dx, 3
    add dx, ax
    add dx, 48
    shl cx, 4
    cmp cx, dx
    ja .launch
    ; The sum of all bands gives a random chance of a rocket.
    xor cx, cx
    xor si, si
.total:
    movzx ax, byte [bar_level+si]
    add cx, ax
    inc si
    cmp si, ANA_BARS
    jb .total
    shr cx, 1
    call random
    and ax, 1023
    cmp ax, cx
    jae .rockets
.launch:
    call fw_launch
.rockets:
    xor si, si
.rocket:
    cmp byte [fw_rockets+si+7], 0
    je .next_rocket
    sub word [fw_rockets+si+2], 24
    mov ax, [fw_rockets+si+2]
    cmp ax, [fw_rockets+si+4]
    jg .rise
    call fw_burst
    jmp .next_rocket
.rise:
    mov ax, [fw_rockets+si]
    mov bx, [fw_rockets+si+2]
    sar bx, 4
    mov dl, C_WHITE
    call fw_dot
    mov cx, 1
.trail:
    push ax
    call random
    and ax, 3
    jz .straight
    sub ax, 2
.straight:
    mov dx, ax
    pop ax
    push ax
    add ax, dx
    add bx, 1
    mov dl, C_GOLD
    cmp cx, 2
    jbe .trail_color
    mov dl, C_GOLD_LO
.trail_color:
    call fw_dot
    pop ax
    inc cx
    cmp cx, 5
    jbe .trail
.next_rocket:
    add si, 8
    cmp si, FW_ROCKETS*8
    jb .rocket
    xor si, si
.spark:
    cmp byte [fw_sparks+si+8], 0
    je .next_spark
    dec byte [fw_sparks+si+8]
    mov ax, [fw_sparks+si+4]
    add [fw_sparks+si], ax
    mov ax, [fw_sparks+si+6]
    add [fw_sparks+si+2], ax
    test byte [frame], 3
    jnz .moved
    inc word [fw_sparks+si+6]
.moved:
    mov ax, [fw_sparks+si]
    sar ax, 4
    mov bx, [fw_sparks+si+2]
    sar bx, 4
    cmp ax, SCROLL_W
    jae .gone
    cmp bx, SCROLL_H-1
    jge .gone
    ; Bright while new, then darker as the spark fades.
    movzx di, byte [fw_sparks+si+9]
    mov cl, [fw_sparks+si+8]
    cmp cl, 20
    ja .color
    inc di
    cmp cl, 10
    ja .color
    inc di
.color:
    mov dl, [fw_colors+di]
    call fw_dot
    jmp .next_spark
.gone:
    mov byte [fw_sparks+si+8], 0
.next_spark:
    add si, 10
    cmp si, FW_SPARKS*10
    jb .spark
    jmp clip_full

; Start a rocket in a free slot.
fw_launch:
    mov byte [fw_cool], 4
    xor si, si
.slot:
    cmp byte [fw_rockets+si+7], 0
    je .free
    add si, 8
    cmp si, FW_ROCKETS*8
    jb .slot
    ret
.free:
    call random
    xor dx, dx
    mov cx, SCROLL_W-16
    div cx
    add dx, 8
    mov [fw_rockets+si], dx
    mov word [fw_rockets+si+2], (SCROLL_H-2)*16
    call random
    xor dx, dx
    mov cx, 7
    div cx
    add dx, 2
    shl dx, 4
    mov [fw_rockets+si+4], dx
    call random
    xor dx, dx
    mov cx, 3
    div cx
    imul dx, dx, 3
    mov [fw_rockets+si+6], dl
    mov byte [fw_rockets+si+7], 1
    ret

; SI = rocket. Replace it with 20 sparks. Horizontal speed is doubled for
; the wide window.
fw_burst:
    pusha
    mov byte [fw_rockets+si+7], 0
    mov bx, si
    xor bp, bp
.spark:
    movzx di, byte [fw_next]
    imul di, di, 10
    mov ax, [fw_rockets+bx]
    shl ax, 4
    mov [fw_sparks+di], ax
    mov ax, [fw_rockets+bx+2]
    mov [fw_sparks+di+2], ax
    call random
    xor dx, dx
    mov cx, 7
    div cx
    add dx, 4
    mov cx, dx
    call random
    and ax, 31
    imul dx, bp, 1024/20
    add ax, dx
    push ax
    call cosine
    imul cx
    shl ax, 1
    rcl dx, 1
    shl ax, 1
    rcl dx, 1
    mov [fw_sparks+di+4], dx
    pop ax
    call sine
    imul cx
    shl ax, 1
    rcl dx, 1
    mov [fw_sparks+di+6], dx
    call random
    and ax, 15
    add ax, 28
    mov [fw_sparks+di+8], al
    mov al, [fw_rockets+bx+6]
    mov [fw_sparks+di+9], al
    inc byte [fw_next]
    cmp byte [fw_next], FW_SPARKS
    jb .slot
    mov byte [fw_next], 0
.slot:
    inc bp
    cmp bp, 20
    jb .spark
    popa
    ret

; AX = x, BX = y in the window, DL = color. Draw one pixel inside the window.
fw_dot:
    cmp ax, SCROLL_W
    jae .done
    cmp bx, SCROLL_H-1
    jae .done
    push ax
    push bx
    add ax, SCROLL_X0
    add bx, SCROLL_Y0
    mov [draw_color], dl
    call put_pixel
    pop bx
    pop ax
.done:
    ret
