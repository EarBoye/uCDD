; SPDX-FileCopyrightText: 2026 vorvek
; SPDX-License-Identifier: GPL-3.0-only

; The image requester and the baroque frame for requesters.

browser_open:
    cmp byte [browse_path], 0
    jne .scan
    mov ah, 19h
    int 21h
    call browser_drive_ok
    jnc .current
    mov al, 2
    call browser_next_drive
    jc .none
    jmp .scan
.current:
    mov dl, al
    add al, 'A'
    mov [browse_path], al
    mov word [browse_path+1], ':\'
    mov si, browse_path+3
    inc dl
    mov ah, 47h
    int 21h
    jc .root
    cmp byte [browse_path+3], 0
    je .root
    mov di, browse_path
    call string_end
    mov word [di], '\'
.scan:
    call browser_scan
    mov byte [browser_active], 1
    ret
.root:
    mov byte [browse_path+3], 0
    jmp .scan
.none:
    mov si, message_no_hard_disk
    jmp show_message

; DI = text. Return DI at the 0 end.
string_end:
    cmp byte [di], 0
    je .done
    inc di
    jmp string_end
.done:
    ret

; AL = drive number (0 = A). CF when it is not a local hard disk.
browser_drive_ok:
    cmp al, 2
    jb .bad
    cmp al, 25
    ja .bad
    push ax
    push bx
    push cx
    push si
    xor si, si
.cd:
    cmp si, [drive_count]
    jae .local
    cmp al, [drive_list+si]
    je .cd_bad
    inc si
    jmp .cd
.local:
    mov bl, al
    inc bl
    mov ax, 4409h
    int 21h
    jc .cd_bad
    test dx, 1000h
    jnz .cd_bad
    pop si
    pop cx
    pop bx
    pop ax
    clc
    ret
.cd_bad:
    pop si
    pop cx
    pop bx
    pop ax
.bad:
    stc
    ret

; AL = first drive to test. Set browse_path to the next local hard disk.
browser_next_drive:
    mov cx, 26
.next:
    cmp al, 25
    jbe .test
    mov al, 2
.test:
    call browser_drive_ok
    jnc .found
    inc al
    loop .next
    stc
    ret
.found:
    add al, 'A'
    mov [browse_path], al
    mov word [browse_path+1], ':\'
    mov byte [browse_path+3], 0
    clc
    ret

browser_scan:
    mov word [entry_count], 0
    mov word [entry_selected], 0
    mov word [entry_top], 0
    mov es, [work_seg]
    cmp byte [browse_path+3], 0
    je .search
    mov di, ENTRIES
    mov byte [es:di+ENTRY_TYPE], ENTRY_UP
    mov dword [es:di+ENTRY_NAME], '..'
    inc word [entry_count]
.search:
    mov dx, dta
    mov ah, 1ah
    int 21h
    mov si, browse_path
    mov di, browse_pattern
    push ds
    pop es
.copy:
    lodsb
    stosb
    test al, al
    jnz .copy
    mov dword [di-1], '*.*'
    mov dx, browse_pattern
    mov cx, 10h
    mov ah, 4eh
    int 21h
.entry:
    jc .sort
    cmp word [entry_count], ENTRY_MAX
    jae .sort
    cmp byte [dta+1eh], '.'
    je .find_next
    test byte [dta+15h], 10h
    jnz .dir
    mov si, dta+1eh
    call image_extension
    jne .find_next
    mov al, ENTRY_FILE
    jmp .add
.dir:
    mov al, ENTRY_DIR
.add:
    mov es, [work_seg]
    imul di, [entry_count], ENTRY_SIZE
    add di, ENTRIES
    stosb
    mov si, dta+1eh
    mov cx, 13
    rep movsb
    mov eax, [dta+1ah]
    add eax, 524287
    shr eax, 20
    stosw
    inc word [entry_count]
.find_next:
    mov ah, 4fh
    int 21h
    jmp .entry
.sort:
    push ds
    mov ds, [work_seg]
    mov cx, [cs:entry_count]
    mov dx, 1
.outer:
    cmp dx, cx
    jae .sorted
    imul di, dx, ENTRY_SIZE
    add di, ENTRIES
.inner:
    cmp di, ENTRIES
    je .next_outer
    lea bx, [di-ENTRY_SIZE]
    call entry_compare
    jbe .next_outer
    push cx
    push di
    mov cx, ENTRY_SIZE/2
.swap:
    mov ax, [di]
    xchg ax, [bx]
    mov [di], ax
    add di, 2
    add bx, 2
    loop .swap
    pop di
    pop cx
    sub di, ENTRY_SIZE
    jmp .inner
.next_outer:
    inc dx
    jmp .outer
.sorted:
    pop ds
    ret

; DS = entries. Compare the entry at BX with the entry at DI. Flags as for BX - DI.
entry_compare:
    push bx
    push cx
    push di
    mov al, [bx+ENTRY_TYPE]
    cmp al, [di+ENTRY_TYPE]
    jne .done
    add bx, ENTRY_NAME
    add di, ENTRY_NAME
    mov cx, 13
.char:
    mov al, [bx]
    cmp al, [di]
    jne .done
    test al, al
    jz .done
    inc bx
    inc di
    loop .char
.done:
    pop di
    pop cx
    pop bx
    ret

; DS:SI = file name. ZF when it is an image or a disc list.
image_extension:
    push si
.dot:
    lodsb
    test al, al
    jz .no
    cmp al, '.'
    jne .dot
    mov eax, [si]
    and eax, 0ffffffh
    or eax, 202020h
    cmp eax, 'cue'
    je .yes
    cmp eax, 'iso'
    je .yes
    cmp eax, 'bin'
    je .yes
    cmp eax, 'mdm'
.yes:
    pop si
    ret
.no:
    or al, 1
    pop si
    ret

; Read entry AX into entry_buffer.
entry_read:
    push ds
    push es
    push si
    push di
    push cx
    push ds
    pop es
    imul si, ax, ENTRY_SIZE
    add si, ENTRIES
    mov di, entry_buffer
    mov cx, ENTRY_SIZE
    mov ds, [work_seg]
    rep movsb
    pop cx
    pop di
    pop si
    pop es
    pop ds
    ret

; Open the selected entry.
browser_enter:
    cmp word [entry_count], 0
    je .done
    mov ax, [entry_selected]
    call entry_read
    cmp byte [entry_buffer+ENTRY_TYPE], ENTRY_UP
    je browser_up
    mov di, browse_path
    call string_end
    mov si, entry_buffer+ENTRY_NAME
    push ds
    pop es
    cmp byte [entry_buffer+ENTRY_TYPE], ENTRY_DIR
    je .dir
    mov di, select_path
    mov si, browse_path
.copy_path:
    lodsb
    test al, al
    jz .name
    stosb
    jmp .copy_path
.name:
    mov si, entry_buffer+ENTRY_NAME
.copy_name:
    lodsb
    stosb
    test al, al
    jnz .copy_name
    mov byte [browser_active], 0
    mov si, select_path
    jmp mount_path
.dir:
    mov ax, di
    sub ax, browse_path
    cmp ax, 110
    ja .done
.copy_dir:
    lodsb
    test al, al
    jz .dir_end
    stosb
    jmp .copy_dir
.dir_end:
    mov word [di], '\'
    jmp browser_scan
.done:
    ret

browser_up:
    cmp byte [browse_path+3], 0
    je .done
    mov di, browse_path
    call string_end
    dec di
.back:
    dec di
    cmp byte [di], '\'
    jne .back
    mov byte [di+1], 0
    jmp browser_scan
.done:
    ret

browser_drive:
    mov al, [browse_path]
    sub al, 'A'-1
    call browser_next_drive
    jc .done
    jmp browser_scan
.done:
    ret

; AX = new selection.
browser_select:
    cmp word [entry_count], 0
    je .done
    test ax, ax
    jns .low
    xor ax, ax
.low:
    cmp ax, [entry_count]
    jl .high
    mov ax, [entry_count]
    dec ax
.high:
    mov [entry_selected], ax
    cmp ax, [entry_top]
    jge .below_top
    mov [entry_top], ax
.below_top:
    sub ax, LIST_ROWS-1
    cmp ax, [entry_top]
    jle .done
    mov [entry_top], ax
.done:
    ret

; AL = key character. Select the next entry that starts with it.
browser_letter:
    cmp al, 'a'
    jb .upper
    cmp al, 'z'
    ja .upper
    sub al, 32
.upper:
    mov dl, al
    mov cx, [entry_count]
    mov bx, [entry_selected]
.next:
    jcxz .done
    inc bx
    cmp bx, [entry_count]
    jb .test
    xor bx, bx
.test:
    mov ax, bx
    call entry_read
    cmp [entry_buffer+ENTRY_NAME], dl
    je .found
    dec cx
    jmp .next
.found:
    mov ax, bx
    jmp browser_select
.done:
    ret

; Keys in the requester. AX = BIOS key.
browser_key:
    cmp al, 27
    je .close
    cmp al, 13
    je browser_enter
    cmp al, 8
    je browser_up
    cmp al, 9
    je browser_drive
    cmp ah, 48h
    je .up
    cmp ah, 50h
    je .down
    cmp ah, 49h
    je .page_up
    cmp ah, 51h
    je .page_down
    cmp ah, 47h
    je .home
    cmp ah, 4fh
    je .end
    cmp al, '0'
    jb .done
    jmp browser_letter
.close:
    mov byte [browser_active], 0
.done:
    ret
.up:
    mov ax, [entry_selected]
    dec ax
    jmp browser_select
.down:
    mov ax, [entry_selected]
    inc ax
    jmp browser_select
.page_up:
    mov ax, [entry_selected]
    sub ax, LIST_ROWS
    jmp browser_select
.page_down:
    mov ax, [entry_selected]
    add ax, LIST_ROWS
    jmp browser_select
.home:
    xor ax, ax
    jmp browser_select
.end:
    mov ax, [entry_count]
    jmp browser_select

; Mouse click at CX, DX in the requester.
browser_click:
    cmp dx, REQ_BUTTON_Y
    jb .list
    cmp dx, REQ_BUTTON_Y+12
    ja .done
    mov si, request_buttons
.button:
    mov ax, [si]
    test ax, ax
    jz .done
    cmp cx, ax
    jb .next_button
    add ax, [si+2]
    cmp cx, ax
    jae .next_button
    jmp [si+4]
.next_button:
    add si, 8
    jmp .button
.list:
    cmp cx, SCROLL_BAR_X
    jae .bar
    cmp cx, LIST_X0
    jb .done
    mov ax, dx
    sub ax, LIST_Y0+1
    jb .done
    mov bl, 9
    div bl
    movzx ax, al
    cmp ax, LIST_ROWS
    jae .done
    add ax, [entry_top]
    cmp ax, [entry_count]
    jae .done
    cmp ax, [entry_selected]
    je browser_enter
    jmp browser_select
.bar:
    cmp cx, SCROLL_BAR_X+5
    ja .done
    mov ax, [entry_selected]
    cmp dx, LIST_Y0+LIST_ROWS*9/2
    jb .bar_up
    add ax, LIST_ROWS
    jmp browser_select
.bar_up:
    sub ax, LIST_ROWS
    jmp browser_select
.done:
    ret

browser_close:
    mov byte [browser_active], 0
    ret

; Frame for requesters: frame_x0..frame_y1, title in SI.
draw_frame:
    push si
    mov ax, [frame_x0]
    add ax, 3
    mov bx, [frame_y0]
    add bx, 3
    mov cx, [frame_x1]
    sub cx, [frame_x0]
    inc cx
    mov dx, [frame_y1]
    sub dx, [frame_y0]
    inc dx
    call shade_rect
    mov si, frame_rings
    xor bp, bp
.ring:
    mov al, [si]
    mov [draw_color], al
    mov ax, [frame_x0]
    add ax, bp
    mov bx, [frame_y0]
    add bx, bp
    mov cx, [frame_x1]
    sub cx, [frame_x0]
    sub cx, bp
    sub cx, bp
    inc cx
    mov dx, 1
    call fill_rect
    mov cx, 1
    mov dx, [frame_y1]
    sub dx, [frame_y0]
    sub dx, bp
    sub dx, bp
    inc dx
    call fill_rect
    mov al, [si+1]
    mov [draw_color], al
    mov ax, [frame_x1]
    sub ax, bp
    call fill_rect
    mov ax, [frame_x0]
    add ax, bp
    mov bx, [frame_y1]
    sub bx, bp
    mov cx, [frame_x1]
    sub cx, [frame_x0]
    sub cx, bp
    sub cx, bp
    inc cx
    mov dx, 1
    call fill_rect
    add si, 2
    inc bp
    cmp bp, 6
    jb .ring
    ; Fill with a navy band for each quarter of the height.
    mov bx, [frame_y0]
    add bx, 6
.fill:
    mov ax, bx
    sub ax, [frame_y0]
    shl ax, 2
    mov cx, [frame_y1]
    sub cx, [frame_y0]
    xor dx, dx
    div cx
    add al, C_NAVY0
    mov [draw_color], al
    mov ax, [frame_x0]
    add ax, 6
    mov cx, [frame_x1]
    sub cx, [frame_x0]
    sub cx, 11
    mov dx, 1
    call fill_rect
    ; Studs as on the faceplate.
    mov byte [draw_color], C_STUD
    mov dx, bx
    and dx, 7
    mov ax, 4
    cmp dx, 2
    je .studs
    xor ax, ax
    cmp dx, 6
    jne .fill_next
.studs:
    add ax, [frame_x0]
    add ax, 8
    and ax, 0fff8h
    add ax, 4
    cmp dx, 6
    jne .stud
    sub ax, 4
.stud:
    mov cx, [frame_x1]
    sub cx, 8
    cmp ax, cx
    jae .fill_next
    call put_pixel
    add ax, 8
    jmp .stud
.fill_next:
    inc bx
    mov ax, [frame_y1]
    sub ax, 6
    cmp bx, ax
    jbe .fill
    ; Gold curls in the corners.
    mov byte [draw_color], C_GOLD
    mov ax, [frame_x0]
    add ax, 10
    mov bx, [frame_y0]
    add bx, 10
    mov cx, 1
    mov dx, 1
    call draw_curl
    mov ax, [frame_x1]
    sub ax, 10
    mov cx, -1
    call draw_curl
    mov bx, [frame_y1]
    sub bx, 10
    mov dx, -1
    call draw_curl
    mov ax, [frame_x0]
    add ax, 10
    mov cx, 1
    call draw_curl
    pop si
    ; Title plate.
    push si
    mov di, si
    call string_end
    sub di, si
    shl di, 3
    mov ax, [frame_x0]
    add ax, [frame_x1]
    sub ax, di
    shr ax, 1
    mov [title_x], ax
    sub ax, 8
    mov bx, [frame_y0]
    add bx, 8
    lea cx, [di+16]
    mov dx, 12
    mov si, burgundy_rows
.plate:
    mov dl, [si]
    mov [draw_color], dl
    mov dx, 1
    call fill_rect
    inc si
    inc bx
    cmp si, burgundy_rows+12
    jb .plate
    mov byte [draw_color], C_GOLD_LO
    dec bx
    call fill_rect
    mov byte [draw_color], C_GOLD_HI
    sub bx, 11
    call fill_rect
    mov byte [draw_color], C_GOLD
    dec ax
    mov cx, 1
    mov dx, 12
    call fill_rect
    add ax, di
    add ax, 17
    call fill_rect
    pop si
    mov ax, [title_x]
    mov bx, [frame_y0]
    add bx, 10
    mov byte [draw_color], C_GOLD_HI
    jmp draw_text_shadow

; AX, BX = center. CX, DX = x and y direction (1 or -1).
draw_curl:
    pushad
    mov si, curl_points
    mov [curl_x], ax
    mov [curl_y], bx
.point:
    movsx ax, byte [si]
    imul ax, cx
    add ax, [curl_x]
    movsx bx, byte [si+1]
    imul bx, dx
    add bx, [curl_y]
    call put_pixel
    add si, 2
    cmp si, curl_points_end
    jb .point
    popad
    ret

; AX = x, BX = y, CX = width, SI = label. A chrome button with a gold edge.
draw_button:
    pusha
    mov di, button_rows
    mov dx, 1
.row:
    mov bp, dx
    mov dl, [di]
    mov [draw_color], dl
    mov dx, bp
    call fill_rect
    inc bx
    inc di
    cmp di, button_rows+13
    jb .row
    sub bx, 14
    mov byte [draw_color], C_GOLD
    call fill_rect
    add bx, 14
    mov byte [draw_color], C_GOLD_LO
    call fill_rect
    sub bx, 13
    dec ax
    push cx
    mov cx, 1
    mov dx, 13
    mov byte [draw_color], C_GOLD
    call fill_rect
    pop cx
    add ax, cx
    inc ax
    push cx
    mov cx, 1
    mov byte [draw_color], C_GOLD_LO
    call fill_rect
    pop cx
    sub ax, cx
    ; Center the label.
    mov di, si
    call string_end
    sub di, si
    shl di, 3
    sub cx, di
    shr cx, 1
    add ax, cx
    add bx, 3
    mov byte [draw_color], C_ENGRAVE
    call draw_text
    popa
    ret

browser_draw:
    mov word [frame_x0], REQ_X0
    mov word [frame_y0], REQ_Y0
    mov word [frame_x1], REQ_X1
    mov word [frame_y1], REQ_Y1
    mov al, [drive_letter]
    add al, 'A'
    mov [browse_title_drive], al
    mov si, browse_title
    call draw_frame
    ; Directory field.
    mov byte [draw_color], C_LABEL
    mov ax, REQ_X0+10
    mov bx, REQ_Y0+25
    mov si, text_dir
    call draw_tiny_shadow
    mov ax, REQ_X0+24
    mov bx, REQ_Y0+23
    mov cx, REQ_X1-REQ_X0-33
    mov dx, 10
    call draw_field
    mov di, browse_path
    call string_end
    mov si, browse_path
    sub di, si
    cmp di, PATH_CHARS
    jbe .path
    add si, di
    sub si, PATH_CHARS
.path:
    mov byte [draw_color], C_TEXT
    mov ax, REQ_X0+26
    mov bx, REQ_Y0+24
    call draw_text
    ; List.
    mov ax, LIST_X0
    mov bx, LIST_Y0
    mov cx, LIST_X1-LIST_X0+1
    mov dx, LIST_ROWS*9+2
    call draw_field
    xor bp, bp
.row:
    mov ax, [entry_top]
    add ax, bp
    cmp ax, [entry_count]
    jae .rows_done
    push ax
    call entry_read
    pop ax
    imul bx, bp, 9
    add bx, LIST_Y0+2
    cmp ax, [entry_selected]
    jne .text
    push bx
    dec bx
    mov si, select_rows
.bar:
    mov al, [si]
    mov [draw_color], al
    mov ax, LIST_X0+1
    mov cx, LIST_X1-LIST_X0-1
    mov dx, 1
    call fill_rect
    inc bx
    inc si
    cmp si, select_rows+9
    jb .bar
    pop bx
    mov byte [draw_color], C_DARKTEXT
    jmp .name
.text:
    mov byte [draw_color], C_FILE
    cmp byte [entry_buffer+ENTRY_TYPE], ENTRY_FILE
    je .name
    mov byte [draw_color], C_DIR
.name:
    mov ax, LIST_X0+4
    mov si, entry_buffer+ENTRY_NAME
    call draw_text
    ; Right column: UP, DIR, or the size.
    call entry_info
    mov di, si
    call string_end
    sub di, si
    shl di, 2
    mov ax, LIST_X1-3
    sub ax, di
    inc bx
    mov dl, C_INFO
    cmp byte [draw_color], C_DARKTEXT
    jne .info_color
    mov dl, C_DARKTEXT
.info_color:
    mov [draw_color], dl
    call draw_tiny
    inc bp
    cmp bp, LIST_ROWS
    jb .row
.rows_done:
    mov byte [draw_color], C_LABEL
    mov ax, LIST_X0+2
    mov bx, LIST_Y0+LIST_ROWS*9+6
    mov si, text_request_keys
    call draw_tiny_shadow
    ; Scroll bar.
    mov ax, SCROLL_BAR_X
    mov bx, LIST_Y0
    mov cx, 6
    mov dx, LIST_ROWS*9+2
    call draw_field
    mov cx, [entry_count]
    cmp cx, LIST_ROWS
    jbe .buttons
    mov ax, LIST_ROWS*9
    mul word [entry_top]
    div cx
    mov bx, ax
    add bx, LIST_Y0+1
    mov ax, LIST_ROWS*LIST_ROWS*9
    xor dx, dx
    div cx
    cmp ax, 4
    jae .thumb
    mov ax, 4
.thumb:
    mov dx, ax
    mov ax, SCROLL_BAR_X
    mov cx, 6
    mov byte [draw_color], C_KNOB+1
    call fill_rect
    mov byte [draw_color], C_KNOB
    mov cx, 2
    call fill_rect
.buttons:
    mov si, request_buttons
.button:
    mov ax, [si]
    test ax, ax
    jz .done
    mov cx, [si+2]
    push si
    mov si, [si+6]
    mov bx, REQ_BUTTON_Y
    call draw_button
    pop si
    add si, 8
    jmp .button
.done:
    ret

; Return SI = the text for the right column of entry_buffer.
entry_info:
    mov si, text_up
    cmp byte [entry_buffer+ENTRY_TYPE], ENTRY_UP
    je .done
    mov si, text_dir
    cmp byte [entry_buffer+ENTRY_TYPE], ENTRY_DIR
    je .done
    mov ax, [entry_buffer+ENTRY_MB]
    test ax, ax
    jz .type
    mov di, number_text
    call format_number
    mov dword [di], ' MB'
    mov si, number_text
.done:
    ret
.type:
    mov si, entry_buffer+ENTRY_NAME
.dot:
    lodsb
    test al, al
    jz .done
    cmp al, '.'
    jne .dot
    ret

; AX = number. Write its digits at DI and return DI after them.
format_number:
    push ax
    push bx
    push cx
    push dx
    mov bx, 10
    xor cx, cx
.divide:
    xor dx, dx
    div bx
    push dx
    inc cx
    test ax, ax
    jnz .divide
.digit:
    pop ax
    add al, '0'
    mov [di], al
    inc di
    loop .digit
    mov byte [di], 0
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; AX = x, BX = y, CX = width, DX = height. A dark sunken field.
draw_field:
    pusha
    mov byte [draw_color], C_FIELD
    call fill_rect
    mov byte [draw_color], C_BLACK
    dec bx
    push dx
    mov dx, 1
    call fill_rect
    pop dx
    add bx, dx
    inc bx
    mov byte [draw_color], C_INFO
    mov dx, 1
    call fill_rect
    popa
    ret
