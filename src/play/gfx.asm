; SPDX-FileCopyrightText: 2026 vorvek
; SPDX-License-Identifier: GPL-3.0-only

; Mode 13h drawing into the back buffer. ES is the back buffer, FS the
; faceplate, and GS the other assets. Colors come from draw_color.

; DI = y * 320 + x for AX = x, BX = y, as pixel_offset gives it.
%macro PIXEL_OFFSET 0
    mov di, bx
    shl di, 2
    add di, bx
    shl di, 6
    add di, ax
%endmacro

; AX = x, BX = y. Return DI = offset: y * 320 + x, without a multiply.
pixel_offset:
    PIXEL_OFFSET
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

; Copy the back buffer to the screen. With the screen copy in shadow_seg,
; write only the dwords that changed, and a band of REFRESH_DWORDS always, so
; that the whole screen is rewritten every 16000 / REFRESH_DWORDS frames.
present:
    mov dx, [shadow_seg]
    test dx, dx
    jz .whole
    mov bx, [refresh_offset]
    mov cx, REFRESH_DWORDS
    lea ax, [bx+REFRESH_DWORDS*4]
    cmp ax, 64000
    jb .band
    xor ax, ax
.band:
    mov [refresh_offset], ax
    cmp byte [shadow_valid], 0
    jne .copy
    mov byte [shadow_valid], 1
    xor bx, bx
    mov cx, 16000
.copy:
    push ds
    push es
    push fs
    push es
    pop ds
    mov es, dx
    push 0a000h
    pop fs
    ; DS = back buffer, ES = screen copy, FS = screen.
    push cx
    mov si, bx
    mov di, bx
    rep movsd
    pop cx
    mov si, bx
.band_screen:
    mov eax, [si]
    mov [fs:si], eax
    add si, 4
    dec cx
    jnz .band_screen
    xor si, si
    xor di, di
    mov cx, 16000
.compare:
    repe cmpsd
    je .done
    mov eax, [si-4]
    mov [es:di-4], eax
    mov [fs:di-4], eax
    test cx, cx
    jnz .compare
.done:
    pop fs
    pop es
    pop ds
    ret
.whole:
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
    mov ah, al
    mov bx, ax
    shl eax, 16
    mov ax, bx
    mov bx, cx
.row:
    ; Bytes to a dword boundary, then dwords, then the rest.
    push di
    push bx
    mov cx, di
    neg cx
    and cx, 3
    cmp cx, bx
    jb .head
    mov cx, bx
.head:
    sub bx, cx
    rep stosb
    mov cx, bx
    shr cx, 2
    rep stosd
    mov cx, bx
    and cx, 3
    rep stosb
    pop bx
    pop di
    add di, 320
    dec dx
    jnz .row
    popad
    ret

; AX = x, BX = y, CX = width, 1 or more, DX = height. Darken the pixels.
shade_rect:
    pushad
    call pixel_offset
    mov bx, A_SHADE
.row:
    push cx
    push di
    shr cx, 1
    jnc .pairs
    mov al, [es:di]
    gs xlatb
    stosb
.pairs:
    jcxz .next
.pair:
    mov ax, [es:di]
    gs xlatb
    xchg al, ah
    gs xlatb
    xchg al, ah
    stosw
    dec cx
    jnz .pair
.next:
    pop di
    pop cx
    add di, 320
    dec dx
    jnz .row
    popad
    ret

; AL = color. Write it at DI over window glass, and step DI.
%macro MASKED_PIXEL 0
    cmp byte [fs:di], C_KEY
    jne %%skip
    mov [es:di], al
%%skip:
    inc di
%endmacro

; AX = x, BX = y, CX = width, 1 or more. Write only over window glass,
; four pixels at a time where all four are glass.
masked_span:
    pushad
    call pixel_offset
    mov al, [draw_color]
    mov ah, al
    mov dx, ax
    shl eax, 16
    mov ax, dx
.head:
    test di, 3
    jz .body
    MASKED_PIXEL
    dec cx
    jnz .head
    jmp .done
.body:
    ; CX = the pixels left minus 4.
    sub cx, 4
    jb .tail
.dword:
    cmp dword [fs:di], C_KEY*01010101h
    jne .mixed
    mov [es:di], eax
    add di, 4
    sub cx, 4
    jae .dword
    jmp .tail
.mixed:
    MASKED_PIXEL
    MASKED_PIXEL
    MASKED_PIXEL
    MASKED_PIXEL
    sub cx, 4
    jae .dword
.tail:
    add cx, 4
    jz .done
.last:
    MASKED_PIXEL
    dec cx
    jnz .last
.done:
    popad
    ret

; AX = x, BX = y.
put_pixel:
    cmp ax, 319
    ja .done
    cmp bx, 199
    ja .done
    push di
    PIXEL_OFFSET
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
    PIXEL_OFFSET
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
    ; CX = the x distance, SI = the error, DL = the color.
    mov dl, [draw_color]
.point:
    cmp ax, [clip_left]
    jl .step
    cmp ax, [clip_right]
    jg .step
    cmp bx, [clip_top]
    jl .step
    cmp bx, [clip_bottom]
    jg .step
    ; As put_pixel.
    cmp ax, 319
    ja .step
    cmp bx, 199
    ja .step
    PIXEL_OFFSET
    mov [es:di], dl
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
    cmp di, cx
    jg .point
    add si, cx
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

; One row of a glyph: the set bits of CH from x = AX, at y = BX, as put_pixel
; would draw them one by one.
%macro GLYPH_ROW 0
    test ch, ch
    jz %%done
    cmp bx, 199
    ja %%done
    push ax
    push di
    PIXEL_OFFSET
    mov cl, [draw_color]
%%bit:
    shl ch, 1
    jnc %%clear
    cmp ax, 319
    ja %%clear
    mov [es:di], cl
%%clear:
    inc ax
    inc di
    test ch, ch
    jnz %%bit
    pop di
    pop ax
%%done:
%endmacro

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
    GLYPH_ROW
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
    ; The glyph is in the top 3 bits.
    mov ch, [gs:di]
    and ch, 0e0h
    inc di
    GLYPH_ROW
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

; The rows of a clipped sprite. %1 set: darken the pixels under it. %2 set:
; only over window glass. DX = y, BP = x, SI = first source pixel, BX = A_SHADE.
%macro SPRITE_ROWS 2
%%row:
    cmp dx, 199
    ja .done
    imul di, dx, 320
    add di, bp
    push si
    mov cx, [sprite_count]
%%pixel:
    mov al, [gs:si]
    cmp al, C_TRANSPARENT
    je %%next
%if %2
    cmp byte [fs:di], C_KEY
    jne %%next
%endif
%if %1
    mov al, [es:di]
    gs xlatb
%endif
    mov [es:di], al
%%next:
    inc si
    inc di
    dec cx
    jnz %%pixel
    pop si
    add si, [sprite_stride]
    inc dx
    dec word [sprite_rows]
    jnz %%row
    jmp .done
%endmacro

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
    ; Clip the columns once: a pixel is drawn when its x is 0 to 319, and
    ; the rows end at the first one below 0 or past 199.
    mov [sprite_rows], dx
    mov [sprite_stride], cx
    test ax, ax
    jns .left
    add cx, ax
    jle .done
    sub si, ax
    xor ax, ax
.left:
    cmp ax, 319
    ja .done
    mov bp, 320
    sub bp, ax
    cmp cx, bp
    jbe .width
    mov cx, bp
.width:
    mov [sprite_count], cx
    mov bp, ax
    mov dx, bx
    mov bx, A_SHADE
    cmp byte [sprite_shade], 0
    jne .shade
    cmp byte [sprite_mask], 0
    jne .mask
    SPRITE_ROWS 0, 0
.mask:
    SPRITE_ROWS 0, 1
.shade:
    cmp byte [sprite_mask], 0
    jne .shade_mask
    SPRITE_ROWS 1, 0
.shade_mask:
    SPRITE_ROWS 1, 1
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
