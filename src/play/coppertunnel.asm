; SPDX-FileCopyrightText: 2026 vorvek
; SPDX-License-Identifier: GPL-3.0-only

; Copper rings rush out of a dark center. Tables of depth, angle, and fog for
; the upper half of a wide window are built once. A sideways shift of the
; center is a shift of the table column. Bass speeds the rings, brightens
; them, and kicks the center.
draw_coppertunnel:
    cmp byte [tn_ready], 0
    jne .ready
    call tn_build
    mov byte [tn_ready], 1
.ready:
    mov byte [tn_flag], 1
    call tn_audio
    call tn_luts
    jmp tn_render

; The bass level against its running average, as for the fireworks.
tn_audio:
    xor cx, cx
    xor si, si
.bass:
    movzx ax, byte [bar_level+si]
    add cx, ax
    inc si
    cmp si, 3
    jb .bass
    mov ax, [tn_avg]
    mov dx, ax
    shr dx, 4
    sub ax, dx
    add ax, cx
    mov [tn_avg], ax
    mov dx, ax
    shr dx, 3
    add dx, ax
    add dx, 48
    shl cx, 4
    cmp cx, dx
    jbe .decay
    mov word [tn_flash], 96
    mov word [tn_kick], 14
    cmp word [tn_shift], 0
    jge .decay
    neg word [tn_kick]
.decay:
    mov ax, [tn_flash]
    mov dx, ax
    shr dx, 3
    sub ax, dx
    dec ax
    jns .flash
    xor ax, ax
.flash:
    mov [tn_flash], ax
    shr ax, 4
    add ax, 5
    add [tn_z], ax
    mov ax, [tn_kick]
    mov dx, ax
    sar dx, 3
    sub ax, dx
    test ax, ax
    jz .kick
    jg .toward
    inc ax
    jmp .kick
.toward:
    dec ax
.kick:
    mov [tn_kick], ax
    imul ax, [frame], 3
    call sine
    sar ax, 10
    add ax, [tn_kick]
    cmp ax, TN_SWING
    jle .low
    mov ax, TN_SWING
.low:
    cmp ax, -TN_SWING
    jge .shift
    mov ax, -TN_SWING
.shift:
    mov [tn_shift], ax
    ret

; The segment stripe for the upper and lower rows, and the palette index
; for each fog and stripe value.
tn_luts:
    mov bx, [frame]
    shr bx, 1
    and bx, 31
    xor si, si
.seg:
    lea ax, [bx+si]
    shr ax, 4
    and al, 1
    shl al, 4
    mov [tn_seg+si], al
    mov ax, 192
    sub ax, si
    add ax, bx
    shr ax, 4
    and al, 1
    shl al, 4
    mov [tn_seg+128+si], al
    inc si
    cmp si, 97
    jb .seg
    xor si, si
.fog:
    mov ax, si
    and ax, 15
    mov cx, 20
    test si, 16
    jz .scale
    mov cx, 16
.scale:
    imul ax, cx
    test ax, ax
    jz .level
    add ax, [tn_flash]
.level:
    shr ax, 6
    cmp ax, 5
    jbe .step
    mov ax, 5
.step:
    neg ax
    add ax, 5
    imul ax, ax, 5
    add al, C_TUNNEL
    mov [tn_lvl+si], al
    inc si
    cmp si, 32
    jb .fog
    ret

; Draw the window. The lower rows mirror the upper rows.
tn_render:
    push gs
    mov gs, [work_seg]
    mov dx, [tn_z]
    xor dh, dh
.row:
    movzx ax, dh
    sub ax, SCROLL_H/2
    mov bp, tn_seg
    jle .above
    add bp, 128
    jmp .have_row
.above:
    neg ax
.have_row:
    imul ax, ax, TN_COLS
    add ax, TN_SWING
    sub ax, [tn_shift]
    mov si, ax
    movzx bx, dh
    imul bx, bx, 320
    add bx, SCROLL_Y0*320+SCROLL_X0
    mov cx, SCROLL_W
.pixel:
    cmp byte [fs:bx], C_KEY
    jne .skip
    movzx di, byte [gs:si+TN_ANGLE]
    mov al, [bp+di]
    add al, [gs:si+TN_FOG]
    movzx di, al
    mov al, [tn_lvl+di]
    mov ah, [gs:si+TN_DEPTH]
    add ah, dl
    shr ah, 5
    movzx di, ah
    add al, [tn_tri+di]
    mov [es:bx], al
.skip:
    inc bx
    inc si
    dec cx
    jnz .pixel
    inc dh
    cmp dh, SCROLL_H
    jb .row
    pop gs
    ret

; Fill the tables for the rows from the middle up. The left half of each row
; is the mirror of the right half.
tn_build:
    push es
    mov es, [work_seg]
    mov word [tn_k], 0
.row:
    imul ax, [tn_k], 7
    mov [tn_ay], ax
    shl ax, 4
    mov [tn_r], ax
    mov word [tn_j], 0
.col:
    ; The radius in sixteenths. It only grows along the row.
    movzx eax, word [tn_j]
    imul eax, eax
    movzx edx, word [tn_ay]
    imul edx, edx
    add eax, edx
    shl eax, 8
    mov esi, eax
    movzx ecx, word [tn_r]
.grow:
    lea edx, [ecx+1]
    imul edx, edx
    cmp edx, esi
    ja .grown
    inc ecx
    jmp .grow
.grown:
    mov [tn_r], cx
    add ecx, 8
    mov eax, 15360*16
    xor edx, edx
    div ecx
    mov [tn_depth], al
    sub ecx, 96
    jl .near
    imul ecx, ecx, 35
    shr ecx, 12
    cmp ecx, 15
    jbe .fog
    mov ecx, 15
    jmp .fog
.near:
    xor ecx, ecx
.fog:
    mov [tn_fog], cl
    ; The angle from the +x axis in 96ths of a half turn.
    mov ax, [tn_j]
    mov bx, [tn_ay]
    xor si, si
    cmp ax, bx
    jb .steep
    test ax, ax
    jz .angle
    mov cx, ax
    mov ax, bx
    shl ax, 6
    xor dx, dx
    div cx
    mov bx, ax
    movzx si, byte [tn_atan+bx]
    jmp .angle
.steep:
    shl ax, 6
    xor dx, dx
    div bx
    mov bx, ax
    movzx si, byte [tn_atan+bx]
    neg si
    add si, 48
.angle:
    mov ax, 96
    sub ax, si
    imul bx, [tn_k], TN_COLS
    add bx, TN_CENTER
    mov di, bx
    add di, [tn_j]
    sub bx, [tn_j]
    mov dl, 96
    sub dl, al
    mov [es:bx+TN_ANGLE], dl
    mov [es:di+TN_ANGLE], al
    mov dl, [tn_depth]
    mov dh, [tn_fog]
    mov [es:bx+TN_DEPTH], dl
    mov [es:di+TN_DEPTH], dl
    mov [es:bx+TN_FOG], dh
    mov [es:di+TN_FOG], dh
    inc word [tn_j]
    cmp word [tn_j], TN_CENTER
    jbe .col
    inc word [tn_k]
    cmp word [tn_k], TN_HALF
    jb .row
    pop es
    ret
