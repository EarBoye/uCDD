; SPDX-FileCopyrightText: 2026 vorvek
; SPDX-License-Identifier: GPL-3.0-only

; A key identifier is the set 1 make code. Bit 7 marks an E0 key. The E0 and
; keypad forms of Home to Insert use one identifier, as in the driver.

hotkeys_screen:
    form_save
    call page_begin
    mov word [form_title], hotkeys_title
    mov word [form_items], hotkey_items
    mov word [form_count], HOTKEY_ITEMS
    mov word [form_selected], 0
    mov word [form_draw], hotkeys_draw
    mov word [form_keys], hotkeys_keys
    mov word [form_notes], hotkey_notes
    mov word [form_status_row], 0112h
    call form_run
    form_restore
    mov byte [form_done], 0
    ret

hotkeys_draw:
    mov dx, 0504h
    mov si, modifiers_heading
    mov bl, A_TITLE
    call put_text
    mov dx, 0608h
    mov si, ctrl_name
    mov bl, A_BOX
    call put_text
    mov dl, 20
    mov si, alt_name
    call put_text
    mov dl, 31
    mov si, shift_name
    call put_text
    mov dl, 44
    mov si, win_name
    call put_text
    mov dx, 0704h
    mov si, modifiers_text
    call put_text
    mov dx, 0904h
    mov si, hotkeys_header
    mov bl, A_TITLE
    call put_text
    mov dx, 0a04h
    mov cx, 68
    mov al, 0c4h
    mov bl, A_BOX
    call put_repeat
    mov dx, 0b04h
    mov si, hotkey_labels
    call put_text
    mov dx, 1104h
    mov si, hotkeys_text
    call put_text
    ret

hotkeys_keys:
    cmp ah, 53h
    jne .escape
    cmp al, '.'
    je .done
    ; Items 5 to 9 are the keys.
    push ax
    mov ax, bx
    sub ax, hotkey_items
    shr ax, 4
    sub ax, 5
    cmp ax, HOTKEY_COUNT
    pop ax
    jae .done
    movzx di, byte [bx+ITEM_PARAM]
    mov byte [config_keys+di], 0
    mov byte [changed], 1
    stc
    ret
.escape:
    cmp al, 27
    jne .done
    call page_cancel
    stc
    ret
.done:
    clc
    ret

format_modifier:
    mov cl, [bx+ITEM_PARAM]
    mov al, 1
    shl al, cl
    mov ah, ' '
    test [config_modifiers], al
    jz .store
    mov ah, 'X'
.store:
    mov [di], ah
    mov byte [di+1], 0
    ret

toggle_modifier:
    mov cl, [bx+ITEM_PARAM]
    mov al, 1
    shl al, cl
    xor [config_modifiers], al
    jnz .done
    xor [config_modifiers], al
    mov word [status], modifier_message
    ret
.done:
    mov byte [changed], 1
    ret

format_key:
    movzx si, byte [bx+ITEM_PARAM]
    mov al, [config_keys+si]
    jmp text_key

; AX key identifier. Write its name, or Off.
text_key:
    mov si, off_text
    test al, al
    jz .copy
    call key_name
    jnc .copy
    mov si, unknown_key_text
.copy:
    jmp copy_text

; AL key identifier. Return SI name, or CF set for a key that cannot be used.
key_name:
    mov si, key_names
.entry:
    cmp byte [si], 0
    je .none
    cmp [si], al
    je .found
.skip:
    inc si
    cmp byte [si], 0
    jne .skip
    inc si
    jmp .entry
.found:
    inc si
    clc
    ret
.none:
    stc
    ret

; AL key identifier, DL hotkey index or 0FFh. Return CF set if another
; hotkey or the disc keys use the key.
key_conflict:
    push cx
    push si
    call disc_key
    jc .done
    xor si, si
.other:
    cmp si, HOTKEY_COUNT
    jae .free
    cmp si, dx
    je .next
    cmp [config_keys+si], al
    je .used
.next:
    inc si
    jmp .other
.free:
    clc
    jmp .done
.used:
    stc
.done:
    pop si
    pop cx
    ret

; AL key identifier. Return CF set if the selected disc keys include it.
disc_key:
    push ax
    mov ah, 2
    cmp byte [config_disc_keys], 1
    je .range
    mov ah, 3bh
    cmp byte [config_disc_keys], 2
    jne .free
.range:
    sub al, ah
    cmp al, 10
    jb .used
.free:
    pop ax
    clc
    ret
.used:
    pop ax
    stc
    ret

; Return CF set if the hotkey settings are not valid.
hotkeys_valid:
    mov al, [config_modifiers]
    test al, al
    jz .bad
    test al, 0f0h
    jnz .bad
    cmp byte [config_disc_keys], 2
    ja .bad
    xor dx, dx
.key:
    mov bx, dx
    mov al, [config_keys+bx]
    test al, al
    jz .next
    call key_name
    jc .bad
    call key_conflict
    jc .bad
.next:
    inc dx
    cmp dx, HOTKEY_COUNT
    jb .key
    clc
    ret
.bad:
    stc
    ret

; Check a new disc key row against the hotkeys.
disc_keys_changed:
    xor bx, bx
.key:
    mov al, [config_keys+bx]
    test al, al
    jz .next
    call disc_key
    jc .used
.next:
    inc bx
    cmp bx, HOTKEY_COUNT
    jb .key
    clc
    ret
.used:
    mov word [status], disc_keys_message
    stc
    ret

disc_keys_list:
    mov si, disc_keys_values
    ret

text_disc_keys:
    mov si, disc_keys_off
    test al, al
    jz .copy
    mov si, disc_keys_numbers
    cmp al, 1
    je .copy
    mov si, disc_keys_functions
.copy:
    jmp copy_text

; Read a new key for the hotkey item in BX.
key_capture:
    mov si, press_message
    call status_now
    call capture_start
.wait:
    call capture_read
    test al, al
    jz .wait
    push ax
    call capture_stop
    pop ax
    mov word [status], empty_text
    cmp al, 1
    je .done
    movzx dx, byte [bx+ITEM_PARAM]
    call key_name
    jc .reserved
    call key_conflict
    jc .used
    mov di, dx
    mov [config_keys+di], al
    mov byte [changed], 1
.done:
    ret
.reserved:
    mov word [status], reserved_key_message
    ret
.used:
    mov word [status], used_key_message
    ret

capture_start:
    push bx
    push es
    mov ax, 3509h
    int 21h
    mov [capture_old], bx
    mov [capture_old+2], es
    pop es
    mov word [capture_head], 0
    mov word [capture_tail], 0
    mov byte [capture_prefix], 0
    mov byte [capture_skip], 0
    mov dx, capture_int9
    mov ax, 2509h
    int 21h
    pop bx
    ret

capture_stop:
    push ds
    lds dx, [capture_old]
    mov ax, 2509h
    int 21h
    pop ds
.flush:
    mov ah, 1
    int 16h
    jz .done
    xor ah, ah
    int 16h
    jmp .flush
.done:
    ret

capture_int9:
    push ax
    push bx
    in al, 60h
    mov bx, [cs:capture_head]
    mov [cs:capture_buffer+bx], al
    inc bx
    and bx, 15
    mov [cs:capture_head], bx
    pop bx
    pop ax
    jmp far [cs:capture_old]

; Return AL key identifier of a new key press, or 0.
capture_read:
    push bx
    cli
    mov bx, [capture_tail]
    cmp bx, [capture_head]
    je .empty
    mov al, [capture_buffer+bx]
    inc bx
    and bx, 15
    mov [capture_tail], bx
    sti
    cmp byte [capture_skip], 0
    je .prefix
    dec byte [capture_skip]
    jmp .none
.prefix:
    cmp al, 0e1h
    jne .extended
    mov byte [capture_skip], 5
    jmp .none
.extended:
    cmp al, 0e0h
    jne .code
    mov byte [capture_prefix], 1
    jmp .none
.code:
    mov ah, [capture_prefix]
    mov byte [capture_prefix], 0
    test al, 80h
    jnz .none
    test ah, ah
    jz .modifier
    cmp al, 2ah
    je .none
    cmp al, 36h
    je .none
    cmp al, 47h
    jb .e0
    cmp al, 53h
    jbe .modifier
.e0:
    or al, 80h
.modifier:
    mov bx, modifier_keys
.check:
    cmp byte [bx], 0
    je .done
    cmp [bx], al
    je .none
    inc bx
    jmp .check
.empty:
    sti
.none:
    xor al, al
.done:
    pop bx
    ret

HOTKEY_ITEMS equ 12
hotkey_items:
    item 6,4,1,0, NONE,4,NONE,1, format_modifier,toggle_modifier,0,0
    item 6,16,1,1, NONE,4,0,2, format_modifier,toggle_modifier,0,0
    item 6,27,1,2, NONE,4,1,3, format_modifier,toggle_modifier,0,0
    item 6,40,1,3, NONE,4,2,NONE, format_modifier,toggle_modifier,0,0
    item 11,34,12,0, 0,5,NONE,NONE, format_choice,choice_popup,choice_cycle,disc_keys_choice
    item 12,34,12,0, 4,6,NONE,NONE, format_key,key_capture,0,0
    item 13,34,12,1, 5,7,NONE,NONE, format_key,key_capture,0,0
    item 14,34,12,2, 6,8,NONE,NONE, format_key,key_capture,0,0
    item 15,34,12,3, 7,9,NONE,NONE, format_key,key_capture,0,0
    item 16,34,12,4, 8,10,NONE,NONE, format_key,key_capture,0,0
    item 20,29,8,0, 9,NONE,NONE,11, format_label,page_ok,0,ok_label
    item 20,41,8,0, 9,NONE,10,NONE, format_label,page_cancel,0,cancel_label
hotkey_notes dw 0,0,0,0,disc_keys_note
    dw key_note,key_note,key_note,key_note,key_note,0,0
disc_keys_choice:
    choice config_disc_keys,1,disc_keys_list,text_disc_keys,disc_keys_changed
disc_keys_values db 3
    dw 1,2,0

capture_old dd 0
capture_head dw 0
capture_tail dw 0
capture_prefix db 0
capture_skip db 0
capture_buffer times 16 db 0
modifier_keys db 1dh,38h,2ah,36h,9dh,0b8h,0dbh,0dch,0

hotkeys_title db 'uCDD Hotkeys',0
modifiers_heading db 'Modifier keys',0
ctrl_name db 'Ctrl',0
alt_name db 'Alt',0
shift_name db 'Shift',0
win_name db 'Win',0
modifiers_text db 'Hold the selected modifier keys, then press the hotkey.',0
hotkeys_header db 'Action'
    times 25 db ' '
    db 'Key',0
hotkey_labels db 'Select disc 1 to 10',10
    db 'Next disc',10
    db 'Previous disc',10
    db 'Eject the disc',10
    db 'CD audio volume up',10
    db 'CD audio volume down',0
hotkeys_text db 'The game also receives each key. The key names are for a US keyboard.',0
disc_keys_note db 'KEYB also uses Ctrl+Alt+F1 and F2.',0
key_note db 'Del turns this hotkey off.',0
disc_keys_numbers db '1 to 0',0
disc_keys_functions db 'F1 to F10',0
disc_keys_off db 'Off',0
off_text db 'Off',0
unknown_key_text db '?',0
press_message db 'Press the new key. Press Esc to cancel.',0
reserved_key_message db 'You cannot use this key as a hotkey.',0
used_key_message db 'Another hotkey uses this key.',0
disc_keys_message db 'A hotkey uses one of these keys. Change that hotkey first.',0
modifier_message db 'Select one or more modifier keys.',0

; Names of the keys that a hotkey can use.
key_names:
    db 02h,'1',0,03h,'2',0,04h,'3',0,05h,'4',0,06h,'5',0
    db 07h,'6',0,08h,'7',0,09h,'8',0,0ah,'9',0,0bh,'0',0
    db 0ch,'-',0,0dh,'=',0,0eh,'Backspace',0,0fh,'Tab',0
    db 10h,'Q',0,11h,'W',0,12h,'E',0,13h,'R',0,14h,'T',0
    db 15h,'Y',0,16h,'U',0,17h,'I',0,18h,'O',0,19h,'P',0
    db 1ah,'[',0,1bh,']',0,1ch,'Enter',0
    db 1eh,'A',0,1fh,'S',0,20h,'D',0,21h,'F',0,22h,'G',0
    db 23h,'H',0,24h,'J',0,25h,'K',0,26h,'L',0
    db 27h,';',0,28h,"'",0,29h,'`',0,2bh,'\',0
    db 2ch,'Z',0,2dh,'X',0,2eh,'C',0,2fh,'V',0,30h,'B',0
    db 31h,'N',0,32h,'M',0,33h,',',0,34h,'.',0,35h,'/',0
    db 37h,'Keypad *',0,39h,'Space',0
    db 3bh,'F1',0,3ch,'F2',0,3dh,'F3',0,3eh,'F4',0,3fh,'F5',0
    db 40h,'F6',0,41h,'F7',0,42h,'F8',0,43h,'F9',0,44h,'F10',0
    db 47h,'Home',0,48h,'Up',0,49h,'PgUp',0,4ah,'Keypad -',0
    db 4bh,'Left',0,4ch,'Keypad 5',0,4dh,'Right',0,4eh,'Keypad +',0
    db 4fh,'End',0,50h,'Down',0,51h,'PgDn',0,52h,'Insert',0
    db 56h,'Key 102',0,57h,'F11',0,58h,'F12',0
    db 9ch,'Keypad Enter',0,0b5h,'Keypad /',0,0b7h,'PrtSc',0
    db 0ddh,'Menu',0
    db 0
