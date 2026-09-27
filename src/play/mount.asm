; SPDX-FileCopyrightText: 2026 vorvek
; SPDX-License-Identifier: GPL-3.0-only

; Mount and eject with the driver control entry, as UCDD -mount does.

; DS:SI = image path. Mount it on the selected drive.
mount_path:
    cmp byte [physical_source], 0
    je .image
    cmp dword [audio_control_entry], 0
    je .no_drive
    push si
    call stop
    call hook_remove
    mov al, [default_unit]
    call select_unit
    call hook_install
    call read_volume
    pop si
.image:
    push si
    push ds
    pop es
    mov di, full_path
    xor ax, ax
    mov cx, INFO_SIZE/2
    rep stosw
    mov word [full_path+INFO_STRIDE], 2048
    mov word [full_path+INFO_COUNT], 1
    mov byte [mount_tracks+TRACK_CONTROL], 40h
    pop si
    mov di, full_path
    mov ax, 6000h
    int 21h
    jc .bad_image
    call mdm_local_path
    jc .bad_source
    call is_mdm
    je .mdm
    call prepare_image
    jc .bad_image
    call mdm_local_path
    jc .bad_source
    call stop
    mov dx, full_path
    mov ax, 1
    call call_control
    test ax, 8000h
    jnz .driver_error
    jmp .refresh
.mdm:
    call prepare_mdm
    jc .bad_mdm
    call stop
    push ds
    mov bl, [subunit]
    mov ds, [mdm_segment]
    xor dx, dx
    mov ax, 7
    call far [cs:control_entry]
    pop ds
    push ax
    mov es, [mdm_segment]
    mov ah, 49h
    int 21h
    pop ax
    test ax, 8000h
    jnz .driver_error
.refresh:
    call refresh_drive
    jc .refresh_error
    call read_disc
    call read_volume
    mov si, message_mounted
    jmp show_message
.bad_image:
    mov si, message_bad_image
    jmp show_message
.bad_source:
    mov si, message_bad_source
    jmp show_message
.bad_mdm:
    mov si, message_bad_mdm
    jmp show_message
.driver_error:
    cmp ax, 8007h
    je .bad_mdm
    cmp ax, 8004h
    je .bad_image
    cmp ax, 8003h
    je .bad_image
    mov si, message_in_use
    jmp show_message
.refresh_error:
    call read_disc
    mov si, message_refresh
    jmp show_message
.no_drive:
    mov si, message_mount_drive
    jmp show_message

eject:
    cmp byte [physical_source], 0
    jne .physical
    xor ax, ax
    call call_control
    test ax, 8000h
    jnz mount_path.driver_error
    test ax, ax
    jz .empty
    call stop
    mov ax, 2
    call call_control
    test ax, 8000h
    jnz mount_path.driver_error
    call refresh_drive
    jc mount_path.refresh_error
    call read_disc
    mov si, message_unmounted
    jmp show_message
.empty:
    mov si, message_empty
    jmp show_message
.physical:
    call stop
    xor al, al
    mov cx, 1
    call ioctl_output
    jc .error
    jmp read_disc
.error:
    mov si, message_eject_error
    jmp show_message

; Tell the redirector that the image changed. CF on error.
refresh_drive:
    mov al, 9
    mov cx, 2
    call ioctl_input
    jc .done
    cmp byte [control_block+1], 0ffh
    je .done
    stc
.done:
    ret
