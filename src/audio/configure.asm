; SPDX-FileCopyrightText: 2026 vorvek
; SPDX-License-Identifier: GPL-3.0-only

; UCDDSET reads UCDD.CFG, shows its menu if the file needs attention, and
; copies the checked settings to config_data.
audio_configure:
    call config_path_init
    mov dx, config_path_message
    jc .error
    mov bx, [config_directory_end]
    mov dword [bx+4], 'SET.'
    mov dword [bx+8], 'EXE'
    mov ax, cs
    mov di, setup_segment
    call config_hex
    mov ax, config_data
    mov di, setup_offset
    call config_hex
    call config_run_setup
    jc .error
    mov dx, setup_exit_message
    cmp byte [config_ready], 1
    jne .error
    clc
    ret
.error:
    mov [audio_error_text], dx
    stc
    ret

; AX value. Write four hexadecimal digits at DI.
config_hex:
    mov cx, 4
.digit:
    rol ax, 4
    mov bl, al
    and bl, 15
    add bl, '0'
    cmp bl, '9'
    jbe .store
    add bl, 7
.store:
    mov [di], bl
    inc di
    loop .digit
    ret

config_run_setup:
    mov ax, 5800h
    int 21h
    jc .failed
    mov [setup_strategy], ax
    mov ax, 5802h
    int 21h
    jc .failed
    mov [setup_umb], al
    xor bx, bx
    mov ax, 5801h
    int 21h
    jc .restore_failed
    xor bx, bx
    mov ax, 5803h
    int 21h
    jc .restore_failed
    mov [setup_exec+4], cs
    mov [setup_exec+8], cs
    mov [setup_exec+12], cs
    push cs
    pop es
    mov bx, setup_exec
    mov dx, config_path
    mov [setup_sp], sp
    mov [setup_ss], ss
    mov ax, 4b00h
    int 21h
    cli
    mov ss, [cs:setup_ss]
    mov sp, [cs:setup_sp]
    sti
    push cs
    pop ds
    cld
    jc .restore_failed
    mov ah, 4dh
    int 21h
    push ax
    call .restore
    pop ax
    test ax, ax
    mov dx, setup_exit_message
    jnz .bad
    clc
    ret
.restore_failed:
    call .restore
.failed:
    mov dx, setup_exec_message
.bad:
    stc
    ret
.restore:
    mov bx, [setup_strategy]
    mov ax, 5801h
    int 21h
    movzx bx, byte [setup_umb]
    mov ax, 5803h
    int 21h
    ret

setup_exec dw 0, setup_tail, 0, setup_fcb, 0, setup_fcb, 0
setup_tail db setup_tail_end-setup_tail-1,' -INSTALL '
setup_segment db '0000:'
setup_offset db '0000'
setup_tail_end db 13
setup_fcb times 37 db 0
setup_sp dw 0
setup_ss dw 0
setup_strategy dw 0
setup_umb db 0
config_path_message db 'The program directory cannot be read.',13,10,'$'
setup_exec_message db 'UCDDSET.EXE cannot be started.',13,10,'$'
setup_exit_message db 'Sound setup did not complete. The audio driver is not installed.',13,10,'$'
