; SPDX-FileCopyrightText: 2026 vorvek
; SPDX-License-Identifier: GPL-3.0-only

; Mode 13h drawing into the back buffer. ES is the back buffer, FS the
; faceplate, and GS the other assets. Colors come from draw_color.

; AX = x, BX = y. Return DI = offset.
pixel_offset:
    imul di, bx, 320
    add di, ax
    ret

copy_face:
    push ds
    push fs
    pop ds
    xor si, si
    xor di, di
    mov cx, 16000
    rep movsd
    pop ds
    ret

present:
    push ds
    push es
    push es
    pop ds
    push 0a000h
    pop es
    xor si, si
    xor di, di
    mov cx, 16000
    rep movsd
    pop es
    pop ds
    ret

wait_retrace:
    mov dx, 3dah
.end:
    in al, dx
    test al, 8
    jnz .end
.start:
    in al, dx
    test al, 8
    jz .start
    ret

; AL = first color, CX = count, DS:SI = 6-bit RGB values.
set_palette:
    mov dx, 3c8h
    out dx, al
    inc dx
    imul cx, cx, 3
    rep outsb
    ret

; AX = x, BX = y, CX = width, DX = height.
fill_rect:
    pushad
    call pixel_offset
    mov al, [draw_color]
.row:
    push cx
    push di
    rep stosb
    pop di
    pop cx
    add di, 320
    dec dx
    jnz .row
    popad
    ret

shade_rect:
    pushad
    call pixel_offset
.row:
    push cx
    push di
.pixel:
    movzx bx, byte [es:di]
    mov al, [gs:A_SHADE+bx]
    stosb
    loop .pixel
    pop di
    pop cx
    add di, 320
    dec dx
    jnz .row
    popad
    ret

; AX = x, BX = y, CX = width. Write only over window glass.
masked_span:
    pushad
    call pixel_offset
    mov al, [draw_color]
.pixel:
    cmp byte [fs:di], C_KEY
    jne .next
    mov [es:di], al
.next:
    inc di
    loop .pixel
    popad
    ret

; AX = x, BX = y.
put_pixel:
    cmp ax, 319
    ja .done
    cmp bx, 199
    ja .done
    push di
    call pixel_offset
    push ax
    mov al, [draw_color]
    mov [es:di], al
    pop ax
    pop di
.done:
    ret

put_masked:
    cmp ax, 319
    ja .done
    cmp bx, 199
    ja .done
    push di
    call pixel_offset
    cmp byte [fs:di], C_KEY
    jne .skip
    push ax
    mov al, [draw_color]
    mov [es:di], al
    pop ax
.skip:
    pop di
.done:
    ret

; AX,BX to CX,DX. Pixels outside clip_left..clip_bottom are skipped.
draw_line:
    pushad
    mov [line_x1], cx
    mov [line_y1], dx
    mov si, 1
    sub cx, ax
    jge .dx_ready
    neg cx
    neg si
.dx_ready:
    mov [line_dx], cx
    mov [line_sx], si
    mov si, 1
    sub dx, bx
    jge .dy_ready
    neg dx
    neg si
.dy_ready:
    neg dx
    mov [line_dy], dx
    mov [line_sy], si
    mov si, cx
    add si, dx
.point:
    cmp ax, [clip_left]
    jl .step
    cmp ax, [clip_right]
    jg .step
    cmp bx, [clip_top]
    jl .step
    cmp bx, [clip_bottom]
    jg .step
    call put_pixel
.step:
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
    popad
    ret

clip_full:
    mov word [clip_left], 0
    mov word [clip_top], 0
    mov word [clip_right], 319
    mov word [clip_bottom], 199
    ret

; AX = x, BX = y, DS:SI = text ending in 0. Return AX after the text.
draw_text:
    push bx
    push cx
    push dx
    push si
    push di
    mov [text_x], ax
.char:
    lodsb
    test al, al
    jz .done
    movzx di, al
    sub di, 32
    jb .next
    cmp di, 95
    ja .next
    shl di, 3
    add di, A_FONT8
    mov ax, [text_x]
    push bx
    mov dx, 8
.row:
    mov ch, [gs:di]
    inc di
    push ax
    mov cl, 8
.bit:
    shl ch, 1
    jnc .clear
    call put_pixel
.clear:
    inc ax
    dec cl
    jnz .bit
    pop ax
    inc bx
    dec dx
    jnz .row
    pop bx
.next:
    add word [text_x], 8
    jmp .char
.done:
    mov ax, [text_x]
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    ret

; Text with a black shadow one pixel down and right.
draw_text_shadow:
    push ax
    push bx
    push si
    mov dl, [draw_color]
    push dx
    inc ax
    inc bx
    mov byte [draw_color], C_BLACK
    call draw_text
    pop dx
    mov [draw_color], dl
    pop si
    pop bx
    pop ax
    jmp draw_text

; AX = x, BX = y, DS:SI = text. Uses the 3x5 font. Return AX after the text.
draw_tiny:
    push bx
    push cx
    push dx
    push si
    push di
    mov [text_x], ax
.char:
    lodsb
    test al, al
    jz .done
    movzx di, al
    sub di, 32
    jb .next
    cmp di, 95
    ja .next
    imul di, di, 5
    add di, A_TINY
    mov ax, [text_x]
    push bx
    mov dx, 5
.row:
    mov ch, [gs:di]
    inc di
    push ax
    mov cl, 3
.bit:
    shl ch, 1
    jnc .clear
    call put_pixel
.clear:
    inc ax
    dec cl
    jnz .bit
    pop ax
    inc bx
    dec dx
    jnz .row
    pop bx
.next:
    add word [text_x], 4
    jmp .char
.done:
    mov ax, [text_x]
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    ret

draw_tiny_shadow:
    push ax
    push bx
    push si
    mov dl, [draw_color]
    push dx
    inc ax
    inc bx
    mov byte [draw_color], C_BLACK
    call draw_tiny
    pop dx
    mov [draw_color], dl
    pop si
    pop bx
    pop ax
    jmp draw_tiny

; AX = x, BX = y, CX = width, DX = height, SI = sprite offset in GS.
; sprite_mask set: write only over window glass. Pixels off the screen are skipped.
draw_sprite:
    pushad
    mov byte [sprite_shade], 0
    jmp sprite_common

; Darken the pixels under a sprite, for a drop shadow.
shade_sprite:
    pushad
    mov byte [sprite_shade], 1
sprite_common:
    mov bp, ax
    mov [sprite_rows], dx
.row:
    cmp bx, 199
    ja .done
    push cx
    push si
    mov ax, bp
.pixel:
    cmp ax, 319
    ja .next
    mov dl, [gs:si]
    cmp dl, C_TRANSPARENT
    je .next
    call pixel_offset
    cmp byte [sprite_mask], 0
    je .write
    cmp byte [fs:di], C_KEY
    jne .next
.write:
    cmp byte [sprite_shade], 0
    je .color
    push bx
    movzx bx, byte [es:di]
    mov dl, [gs:A_SHADE+bx]
    pop bx
.color:
    mov [es:di], dl
.next:
    inc si
    inc ax
    loop .pixel
    pop si
    pop cx
    add si, cx
    inc bx
    dec word [sprite_rows]
    jnz .row
.done:
    popad
    ret

; AX = angle (1024 steps). Return AX = sine in Q15.
sine:
    push bx
    mov bx, ax
    and bx, 1023
    add bx, bx
    mov ax, [gs:A_SINE+bx]
    pop bx
    ret

cosine:
    add ax, 256
    jmp sine
