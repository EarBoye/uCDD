; SPDX-FileCopyrightText: 2026 vorvek
; SPDX-License-Identifier: GPL-3.0-only

; Eight perspective cubes follow separate frequency bands.
draw_cubes:
    mov word [clip_left], SCROLL_X0
    mov word [clip_right], SCROLL_X1
    mov word [clip_top], SCROLL_Y0
    mov word [clip_bottom], SCROLL_Y1
    mov word [cube_index], 0
.cube:
    imul ax, [cube_index], ANA_BARS
    add ax, ANA_BARS/2
    shr ax, 3
    mov bx, ax
    movzx ax, byte [bar_level+bx]
    cmp ax, BAR_HEIGHT
    jbe .level
    mov ax, BAR_HEIGHT
.level:
    imul ax, ax, 3
    xor dx, dx
    mov cx, BAR_HEIGHT
    div cx
    add ax, 2
    mov [cube_radius], ax
    imul ax, [frame], 3
    imul bx, [cube_index], 96
    add ax, bx
    push ax
    call sine
    mov [cube_yaw_s], ax
    pop ax
    call cosine
    mov [cube_yaw_c], ax
    imul ax, [frame], 2
    imul bx, [cube_index], 64
    add ax, bx
    push ax
    call sine
    mov [cube_pitch_s], ax
    pop ax
    call cosine
    mov [cube_pitch_c], ax
    xor bp, bp
    mov di, cube_vertices
.vertex:
    mov ebx, -64
    test bp, 1
    jz .x
    neg ebx
.x:
    mov ecx, -64
    test bp, 2
    jz .y
    neg ecx
.y:
    mov edx, -64
    test bp, 4
    jz .z
    neg edx
.z:
    movsx eax, word [cube_yaw_c]
    imul eax, ebx
    movsx esi, word [cube_yaw_s]
    imul esi, edx
    add eax, esi
    sar eax, 15
    push eax
    movsx eax, word [cube_yaw_c]
    imul eax, edx
    movsx esi, word [cube_yaw_s]
    imul esi, ebx
    sub eax, esi
    sar eax, 15
    mov edx, eax
    movsx eax, word [cube_pitch_c]
    imul eax, ecx
    movsx esi, word [cube_pitch_s]
    imul esi, edx
    sub eax, esi
    sar eax, 15
    mov ebx, eax
    movsx eax, word [cube_pitch_c]
    imul eax, edx
    movsx esi, word [cube_pitch_s]
    imul esi, ecx
    add eax, esi
    sar eax, 15
    mov [di+4], ax
    lea ecx, [eax+512]
    movzx esi, word [cube_radius]
    pop eax
    imul eax, esi
    shl eax, 4
    cdq
    idiv ecx
    imul dx, [cube_index], 37
    add ax, dx
    add ax, SCROLL_X0+18
    mov [di], ax
    mov eax, ebx
    imul eax, esi
    shl eax, 3
    cdq
    idiv ecx
    add ax, (SCROLL_Y0+SCROLL_Y1)/2
    mov [di+2], ax
    add di, 6
    inc bp
    cmp bp, 8
    jb .vertex
    xor bp, bp
.edge:
    movzx si, byte [cube_edges+bp]
    imul si, si, 6
    movzx di, byte [cube_edges+bp+1]
    imul di, di, 6
    mov ax, [cube_vertices+si+4]
    add ax, [cube_vertices+di+4]
    mov dx, [cube_index]
    and dl, 7
    add dl, C_SPECTRUM
    test ax, ax
    jns .color
    add dl, 8
.color:
    mov [draw_color], dl
    mov ax, [cube_vertices+si]
    mov bx, [cube_vertices+si+2]
    mov cx, [cube_vertices+di]
    mov dx, [cube_vertices+di+2]
    call draw_line
    add bp, 2
    cmp bp, 24
    jb .edge
    inc word [cube_index]
    cmp word [cube_index], 8
    jb .cube
    jmp clip_full
