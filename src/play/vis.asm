; SPDX-FileCopyrightText: 2026 vorvek
; SPDX-License-Identifier: GPL-3.0-only

; The logo window and the bottom window.

; SI = star table, CX = count, star_x0..star_y1 = the window.
; A star is x in 1/16 pixels, y, and a layer from 0 to 2.
init_stars:
.star:
    call random
    xor dx, dx
    mov bx, [star_x1]
    sub bx, [star_x0]
    inc bx
    div bx
    add dx, [star_x0]
    shl dx, 4
    mov [si], dx
    call random
    xor dx, dx
    mov bx, [star_y1]
    sub bx, [star_y0]
    inc bx
    div bx
    add dx, [star_y0]
    mov [si+2], dl
    call random
    xor dx, dx
    mov bx, 3
    div bx
    mov [si+3], dl
    add si, STAR_SIZE
    loop .star
    ret

; SI = star table, CX = count, star_boost = speed in 1/16.
; Fast stars draw as streaks.
draw_stars:
    pusha
.star:
    movzx ax, byte [si+3]
    inc ax
    add ax, ax
    mul word [star_boost]
    shr ax, 4
    mov bp, ax
    mov ax, [si]
    sub ax, bp
    mov dx, [star_x0]
    shl dx, 4
    cmp ax, dx
    jge .inside
    mov dx, [star_x1]
    sub dx, [star_x0]
    inc dx
    shl dx, 4
    add ax, dx
.inside:
    mov [si], ax
    movzx bx, byte [si+2]
    mov dl, [si+3]
    add dl, C_STARS
    mov [draw_color], dl
    shr ax, 4
    shr bp, 4
    inc bp
.streak:
    cmp ax, [star_x1]
    ja .next
    call put_masked
    inc ax
    dec bp
    jnz .streak
.next:
    add si, STAR_SIZE
    loop .star
    popa
    ret

set_logo_rect:
    mov word [star_x0], LOGO_X0
    mov word [star_y0], LOGO_Y0
    mov word [star_x1], LOGO_X1
    mov word [star_y1], LOGO_Y1
    ret

set_bottom_rect:
    mov word [star_x0], SCROLL_X0
    mov word [star_y0], SCROLL_Y0
    mov word [star_x1], SCROLL_X1
    mov word [star_y1], SCROLL_Y1
    ret

init_visuals:
    call set_logo_rect
    mov si, logo_stars
    mov cx, LOGO_STARS
    call init_stars
    call set_bottom_rect
    mov si, bottom_stars
    mov cx, BOTTOM_STARS
    call init_stars
    ret

draw_logo_window:
    call set_logo_rect
    mov word [star_boost], 8
    mov si, logo_stars
    mov cx, LOGO_STARS
    call draw_stars
    xor bp, bp
.bar:
    mov ax, [frame]
    lea cx, [bp+3]
    mul cx
    mov cx, bp
    imul cx, cx, 341
    add ax, cx
    call sine
    movsx eax, ax
    imul eax, 11
    sar eax, 15
    add ax, (LOGO_Y0+LOGO_Y1)/2-4
    mov bx, ax
    imul dx, bp, COPPER_SHADES
    add dl, C_COPPER
    mov cx, COPPER_SHADES
.shade:
    cmp bx, LOGO_Y0
    jl .skip
    cmp bx, LOGO_Y1
    jg .skip
    mov [draw_color], dl
    push cx
    mov ax, LOGO_X0
    mov cx, LOGO_X1-LOGO_X0+1
    call masked_span
    pop cx
.skip:
    inc bx
    inc dl
    loop .shade
    inc bp
    cmp bp, 3
    jb .bar
    mov byte [sprite_mask], 1
    mov ax, (LOGO_X0+LOGO_X1+1-LOGO_W)/2+2
    mov bx, (LOGO_Y0+LOGO_Y1+1-LOGO_H)/2+2
    mov cx, LOGO_W
    mov dx, LOGO_H
    mov si, A_LOGO
    call shade_sprite
    sub ax, 2
    sub bx, 2
    call draw_sprite
    mov byte [sprite_mask], 0
    ret

; Set the copper bar and rainbow colors for this frame.
animate_palette:
    push es
    push ds
    pop es
    mov di, dynamic_palette
    xor bp, bp
.bar:
    mov ax, [frame]
    shr ax, 1
    imul cx, bp, 21
    add ax, cx
    and ax, 63
    imul si, ax, 3
    add si, A_RAINBOW
    mov bx, copper_profile
.shade:
    push si
    mov cx, 3
.channel:
    movzx ax, byte [gs:si]
    mul byte [bx]
    shr ax, 6
    cmp bx, copper_profile+4
    jne .store
    mov dx, 63
    sub dx, ax
    shr dx, 1
    add ax, dx
.store:
    stosb
    inc si
    loop .channel
    pop si
    inc bx
    cmp bx, copper_profile+COPPER_SHADES
    jb .shade
    inc bp
    cmp bp, 3
    jb .bar
    xor bx, bx
.rainbow:
    mov ax, bx
    shl ax, 2
    add ax, [frame]
    and ax, 63
    imul si, ax, 3
    add si, A_RAINBOW
    mov cx, 3
.copy:
    mov al, [gs:si]
    stosb
    inc si
    loop .copy
    inc bx
    cmp bx, 16
    jb .rainbow
    pop es
    mov si, dynamic_palette
    mov al, C_COPPER
    mov cx, 3*COPPER_SHADES+16
    jmp set_palette

; SI = message. Show it in the bottom window for three seconds.
show_message:
    mov [message_text], si
    mov word [message_timer], 210
    mov byte [label_active], 0
    ret

; Return AX = the low word of the BIOS tick count.
bios_ticks:
    push ds
    push 40h
    pop ds
    mov ax, [6ch]
    pop ds
    ret

; The level for the effects: 0 to 255.
effect_level:
    movzx ax, byte [vu_level]
    movzx dx, byte [vu_level+1]
    add ax, dx
    shr ax, 1
    ret

draw_bottom:
    call set_bottom_rect
    call bottom_content
    jmp draw_label

bottom_content:
    cmp word [message_timer], 0
    je .visual
    dec word [message_timer]
    call slow_stars
    jmp draw_message
.visual:
    cmp byte [play_state], PLAYING
    je .playing
    cmp byte [label_active], 0
    je draw_scroller
    jmp slow_stars
.playing:
    cmp byte [vis_choice], VIS_RANDOM
    jne .mode
    inc word [vis_timer]
    cmp word [vis_timer], VIS_FRAMES
    jb .mode
    call random_visual
.mode:
    movzx bx, byte [vis_mode]
    add bx, bx
    jmp [visual_table+bx]

slow_stars:
    mov word [star_boost], 4
    mov si, bottom_stars
    mov cx, BOTTOM_STARS
    jmp draw_stars

; Select the next display, or RANDOM after the last one. Show its name.
select_visual:
    mov word [message_timer], 0
    mov al, [vis_choice]
    inc ax
    cmp al, VIS_RANDOM
    jbe .choice
    xor al, al
.choice:
    mov [vis_choice], al
    cmp al, VIS_RANDOM
    je .label
    call set_visual
.label:
    mov word [vis_timer], 0
    movzx bx, byte [vis_choice]
    add bx, bx
    mov ax, [visual_names+bx]
    mov [label_text], ax
    call bios_ticks
    mov [label_start], ax
    mov byte [label_active], 1
    ret

; Change to a different display at random.
random_visual:
    call random
    xor dx, dx
    mov cx, VIS_COUNT-1
    div cx
    mov al, dl
    cmp al, [vis_mode]
    jb set_visual
    inc ax

; AL = display. Start it with empty buffers.
set_visual:
    mov [vis_mode], al
    mov word [vis_timer], 0
    push es
    push ds
    pop es
    mov di, bubbles
    mov cx, BUBBLES*BUBBLE_SIZE/2
    xor ax, ax
    rep stosw
    mov es, [work_seg]
    mov di, W_FIRE
    mov cx, (FIRE_ROWS+SCROLL_H)*SCROLL_W/2
    rep stosw
    pop es
    ret

; The name of the selected display. It dissolves in and out.
draw_label:
    cmp byte [label_active], 0
    je .done
    call bios_ticks
    sub ax, [label_start]
    cmp ax, LABEL_TICKS
    jb .visible
    mov byte [label_active], 0
.done:
    ret
.visible:
    mov bx, ax
    mov ax, LABEL_TICKS
    sub ax, bx
    shl ax, 4
    xor dx, dx
    mov cx, LABEL_FADE
    div cx
    inc bx
    shl bx, 2
    cmp ax, bx
    jb .level
    mov ax, bx
.level:
    cmp ax, 16
    jbe .store
    mov ax, 16
.store:
    mov [label_level], al
    mov si, [label_text]
    mov di, si
    call string_end
    sub di, si
    shl di, 3
    mov ax, (SCROLL_X0+SCROLL_X1+1)/2
    sub ax, di
    mov [label_x], ax
    mov byte [draw_color], C_BLACK
    mov word [scroll_shadow], 2
    call label_pass
    mov word [scroll_shadow], 0

; Draw the label in the 2x font, or its shadow.
label_pass:
    mov si, [label_text]
    mov cx, [label_x]
    add cx, [scroll_shadow]
.char:
    lodsb
    test al, al
    jz .done
    movzx bx, al
    sub bx, 32
    shl bx, 3
    add bx, A_FONT8
    mov dx, SCROLL_Y0+2
    add dx, [scroll_shadow]
    mov bp, 8
.row:
    mov ah, [gs:bx]
    push cx
.bit:
    shl ah, 1
    jnc .next_bit
    call label_block
.next_bit:
    add cx, 2
    test ah, ah
    jnz .bit
    pop cx
    inc bx
    add dx, 2
    dec bp
    jnz .row
    add cx, 16
    jmp .char
.done:
    ret

; CX = x, DX = y. A 2x2 block of the label.
label_block:
    pusha
    mov bx, dx
    call .pair
    inc bx
    call .pair
    popa
    ret
.pair:
    mov ax, cx
    call label_pixel
    inc ax

; AX = x, BX = y. The Bayer matrix removes pixels while the label fades.
label_pixel:
    push bx
    and bx, 3
    shl bx, 2
    mov di, ax
    and di, 3
    mov dl, [bayer+bx+di]
    pop bx
    cmp dl, [label_level]
    jae .done
    cmp word [scroll_shadow], 0
    jne .put
    mov dx, bx
    sub dx, SCROLL_Y0
    and dx, 15
    add dl, C_RAINBOW
    mov [draw_color], dl
.put:
    jmp put_masked
.done:
    ret

; The message has one or two lines. A | character starts the second line.
draw_message:
    mov si, [message_text]
    mov di, si
.find:
    mov al, [di]
    test al, al
    jz .one
    cmp al, '|'
    je .two
    inc di
    jmp .find
.one:
    mov bx, SCROLL_Y0+7
    jmp message_line
.two:
    push di
    mov bx, SCROLL_Y0+2
    call message_line
    pop si
    inc si
    mov di, si
    call string_end
    mov bx, SCROLL_Y0+12

; SI = start, DI = end, BX = y. Draw the line in the center of the window.
message_line:
    push bx
    mov bx, message_buffer
.copy:
    cmp si, di
    jae .end
    mov al, [si]
    mov [bx], al
    inc si
    inc bx
    jmp .copy
.end:
    mov byte [bx], 0
    sub bx, message_buffer
    shl bx, 2
    mov ax, (SCROLL_X0+SCROLL_X1+1)/2
    sub ax, bx
    pop bx
    mov si, message_buffer
    mov byte [draw_color], C_GOLD_HI
    jmp draw_text_shadow

draw_scroller:
    mov word [star_boost], 16
    mov si, bottom_stars
    mov cx, BOTTOM_STARS
    call draw_stars
    mov byte [draw_color], C_BLACK
    mov word [scroll_shadow], 2
    call .pass
    mov word [scroll_shadow], 0
    call .pass
    add word [scroll_offset], 2
    mov ax, [scroll_length]
    shl ax, 4
    cmp [scroll_offset], ax
    jb .done
    sub [scroll_offset], ax
.done:
    ret
.pass:
    mov cx, SCROLL_X0
.column:
    mov ax, cx
    sub ax, SCROLL_X0
    add ax, [scroll_offset]
    mov dx, ax
    shr ax, 4
    cmp ax, [scroll_length]
    jb .char
    sub ax, [scroll_length]
.char:
    mov bx, ax
    movzx bx, byte [scroll_text+bx]
    sub bx, 32
    shl bx, 3
    add bx, A_FONT8
    shr dx, 1
    and dl, 7
    mov dh, 80h
    xchg cl, dl
    shr dh, cl
    xchg cl, dl
    push cx
    mov ax, cx
    shl ax, 3
    mov si, [frame]
    shl si, 3
    add ax, si
    call sine
    movsx eax, ax
    imul eax, 3
    sar eax, 15
    add ax, SCROLL_Y0+2
    add ax, [scroll_shadow]
    mov si, ax
    pop cx
    mov bp, 8
.row:
    test [gs:bx], dh
    jz .next_row
    mov ax, cx
    add ax, [scroll_shadow]
    push bx
    mov bx, si
    cmp word [scroll_shadow], 0
    jne .color_ready
    mov di, bx
    sub di, SCROLL_Y0
    and di, 15
    add di, C_RAINBOW
    xchg ax, di
    mov [draw_color], al
    xchg ax, di
.color_ready:
    call put_masked
    inc bx
    call put_masked
    pop bx
.next_row:
    inc bx
    add si, 2
    dec bp
    jnz .row
    inc cx
    cmp cx, SCROLL_X1
    jbe .column
    ret

; AX = x, BX = top, DX = bottom. A vertical span over window glass.
masked_vspan:
    cmp bx, dx
    jle .ready
    xchg bx, dx
.ready:
    call put_masked
    inc bx
    cmp bx, dx
    jle .ready
    ret

draw_scope:
    call slow_stars
    mov byte [draw_color], C_STRIPE_PRE
    mov word [scope_channel], 2
    call .channel
    mov byte [draw_color], C_STRIPE
    mov word [scope_channel], 0
.channel:
    mov si, [ring_pos]
    sub si, SCROLL_W*2
    mov ax, SCROLL_X0
    mov word [scope_last], (SCROLL_Y0+SCROLL_Y1)/2
.point:
    and si, RING_FRAMES-1
    mov di, si
    shl di, 2
    add di, [scope_channel]
    movsx dx, byte [ring+di+1]
    sar dx, 4
    neg dx
    add dx, (SCROLL_Y0+SCROLL_Y1)/2
    mov bx, [scope_last]
    mov [scope_last], dx
    push dx
    call masked_vspan
    pop dx
    add si, 2
    inc ax
    cmp ax, SCROLL_X1
    jbe .point
    ret

draw_waterfall:
    push es
    mov es, [work_seg]
    ; Move the rows one pixel to the left and add a column from the bars.
    push ds
    push es
    pop ds
    mov di, W_FIRE
    mov bx, SCROLL_H
.shift:
    lea si, [di+1]
    mov cx, SCROLL_W-1
    rep movsb
    inc di
    dec bx
    jnz .shift
    pop ds
    xor bx, bx
.new:
    mov ax, SCROLL_H-1
    sub ax, bx
    imul ax, ax, ANA_BARS
    xor dx, dx
    mov cx, SCROLL_H
    div cx
    mov si, ax
    movzx ax, byte [bar_level+si]
    imul ax, ax, 15
    mov cl, BAR_HEIGHT
    div cl
    add al, C_HEAT
    imul di, bx, SCROLL_W
    mov [es:W_FIRE+di+SCROLL_W-1], al
    inc bx
    cmp bx, SCROLL_H
    jb .new
    pop es
    jmp draw_fire_buffer

draw_fire:
    push es
    mov es, [work_seg]
    call effect_level
    add ax, 128
    mov [fire_heat], ax
    mov di, W_FIRE+(FIRE_ROWS-2)*SCROLL_W
    mov cx, 2*SCROLL_W
.seed:
    call random
    xor ah, ah
    mul word [fire_heat]
    mov al, ah
    test dx, dx
    jz .store
    mov al, 255
.store:
    stosb
    loop .seed
    mov di, W_FIRE
    mov bx, FIRE_ROWS-2
.row:
    mov cx, SCROLL_W
.pixel:
    movzx ax, byte [es:di+SCROLL_W]
    movzx dx, byte [es:di+SCROLL_W-1]
    add ax, dx
    movzx dx, byte [es:di+SCROLL_W+1]
    add ax, dx
    movzx dx, byte [es:di+2*SCROLL_W]
    add ax, dx
    shr ax, 2
    sub ax, 2
    jnc .heat
    xor ax, ax
.heat:
    stosb
    loop .pixel
    dec bx
    jnz .row
    push ds
    push es
    pop ds
    mov si, W_FIRE
    mov di, W_FIRE+FIRE_ROWS*SCROLL_W
    mov cx, SCROLL_W*SCROLL_H
.map:
    lodsb
    shr al, 4
    add al, C_HEAT
    stosb
    loop .map
    pop ds
    pop es
    mov si, W_FIRE+FIRE_ROWS*SCROLL_W
    jmp draw_buffer

draw_fire_buffer:
    mov si, W_FIRE
; SI = color buffer in the work segment, one byte for each window pixel.
draw_buffer:
    push ds
    mov ds, [work_seg]
    mov di, SCROLL_Y0*320+SCROLL_X0
    mov bx, SCROLL_H
.row:
    mov cx, SCROLL_W
.pixel:
    lodsb
    cmp byte [fs:di], C_KEY
    jne .skip
    mov [es:di], al
.skip:
    inc di
    loop .pixel
    add di, 320-SCROLL_W
    dec bx
    jnz .row
    pop ds
    ret

draw_warp:
    call effect_level
    shr ax, 1
    add ax, 16
    mov [star_boost], ax
    mov si, bottom_stars
    mov cx, BOTTOM_STARS
    jmp draw_stars

; Bubbles rise from each analyzer band. A louder band makes more bubbles,
; and they are larger and redder.
draw_bubbles:
    xor bp, bp
.band:
    movzx dx, byte [bar_level+bp]
    test dx, dx
    jz .next_band
    call random
    xor ah, ah
    shr ax, 1
    cmp ax, dx
    jae .next_band
    call new_bubble
.next_band:
    inc bp
    cmp bp, ANA_BARS
    jb .band
    mov si, bubbles
    mov cx, BUBBLES
.bubble:
    cmp byte [si+B_RADIUS], 0
    je .next
    movzx ax, byte [si+B_SPEED]
    sub [si+B_Y], ax
    mov bx, [si+B_Y]
    shr bx, 4
    ; The bubble grows while it rises.
    mov ax, BUBBLE_Y+1
    sub ax, bx
    shr ax, 1
    inc ax
    cmp al, [si+B_MAX]
    jb .radius
    mov al, [si+B_MAX]
.radius:
    mov [si+B_RADIUS], al
    movzx di, al
    dec di
    imul di, di, 6
    mov ax, [bubble_table+di+4]
    shr ax, 1
    add ax, bx
    cmp ax, SCROLL_Y0
    jge .draw
    mov byte [si+B_RADIUS], 0
    jmp .next
.draw:
    mov ax, [si+B_X]
    imul ax, ax, 40
    mov dx, [frame]
    shl dx, 4
    add ax, dx
    call sine
    sar ax, 14
    add ax, [si+B_X]
    mov dl, [si+B_COLOR]
    call draw_bubble
.next:
    add si, BUBBLE_SIZE
    loop .bubble
    ret

; BP = band, DX = its level. Start a bubble below the band.
new_bubble:
    mov di, bubbles
    mov cx, BUBBLES
.find:
    cmp byte [di+B_RADIUS], 0
    je .found
    add di, BUBBLE_SIZE
    loop .find
    ret
.found:
    mov byte [di+B_RADIUS], 1
    mov word [di+B_Y], BUBBLE_Y*16
    ; Most music stays below the top of the bars. 1.5 times the level
    ; gives large red bubbles for loud bands.
    imul bx, dx, 3
    shr bx, 1
    cmp bx, BAR_HEIGHT
    jbe .level
    mov bx, BAR_HEIGHT
.level:
    imul ax, bx, 15
    mov cl, BAR_HEIGHT
    div cl
    add al, C_SPECTRUM
    mov [di+B_COLOR], al
    call random
    and ax, 31
    imul dx, bx, BUBBLE_RADII-1
    add ax, dx
    mov cl, BAR_HEIGHT+1
    div cl
    inc ax
    mov [di+B_MAX], al
    call random
    and al, 15
    add al, 8
    add al, [di+B_MAX]
    add al, [di+B_MAX]
    mov [di+B_SPEED], al
    call random
    xor dx, dx
    mov cx, SCROLL_W
    div cx
    imul ax, bp, SCROLL_W
    add ax, dx
    xor dx, dx
    mov cx, ANA_BARS
    div cx
    add ax, SCROLL_X0
    mov [di+B_X], ax
    ret

; AX = x, BX = y of the center, DI = bubble_table entry, DL = color.
draw_bubble:
    pusha
    mov [bubble_color], dl
    push bx
    movzx bx, dl
    mov dl, [gs:A_SHADE+bx]
    mov [bubble_fill], dl
    pop bx
    mov cx, [bubble_table+di+2]
    mov bp, [bubble_table+di+4]
    mov si, [bubble_table+di]
    mov dx, cx
    shr dx, 1
    sub ax, dx
    mov dx, bp
    shr dx, 1
    sub bx, dx
    call pixel_offset
.row:
    push cx
    push di
.pixel:
    mov al, [gs:si]
    inc si
    test al, al
    jz .skip
    cmp byte [fs:di], C_KEY
    jne .skip
    mov dl, [bubble_color]
    cmp al, 1
    je .put
    mov dl, [bubble_fill]
    cmp al, 3
    je .put
    mov dl, C_WHITE
.put:
    mov [es:di], dl
.skip:
    inc di
    loop .pixel
    pop di
    pop cx
    add di, 320
    dec bp
    jnz .row
    popa
    ret
